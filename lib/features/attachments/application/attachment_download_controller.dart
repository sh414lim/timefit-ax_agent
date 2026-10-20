import 'dart:async';

import 'package:flutter/foundation.dart';

enum AttachmentPreviewKind { image, pdf }

enum AttachmentPreviewError {
  offline,
  accessRevoked,
  expired,
  unsupportedType,
  unavailable,
}

enum AttachmentUrlFailure { offline, forbidden, unavailable }

final class AttachmentUrlException implements Exception {
  const AttachmentUrlException(this.failure);
  final AttachmentUrlFailure failure;
}

final class AttachmentPreviewMetadata {
  const AttachmentPreviewMetadata({
    required this.attachmentId,
    required this.displayName,
    required this.contentType,
  });

  final String attachmentId;
  final String displayName;
  final String contentType;

  AttachmentPreviewKind? get previewKind => switch (contentType) {
    'image/jpeg' || 'image/png' || 'image/webp' => AttachmentPreviewKind.image,
    'application/pdf' => AttachmentPreviewKind.pdf,
    _ => null,
  };

  String get safeDisplayName =>
      displayName.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '\uFFFD');
}

final class SignedAttachmentUrl {
  const SignedAttachmentUrl({required this.url, required this.expiresAt});
  final Uri url;
  final DateTime expiresAt;
}

abstract interface class AttachmentUrlProvider {
  Future<SignedAttachmentUrl> issue({required String attachmentId});
}

abstract interface class AttachmentPreviewTelemetry {
  /// Stable event codes only. Implementations must not accept URLs or paths.
  void record(String eventCode);
}

abstract interface class AttachmentRefreshHandle {
  void cancel();
}

abstract interface class AttachmentRefreshScheduler {
  AttachmentRefreshHandle schedule(Duration delay, void Function() callback);
}

final class TimerAttachmentRefreshScheduler
    implements AttachmentRefreshScheduler {
  const TimerAttachmentRefreshScheduler();

  @override
  AttachmentRefreshHandle schedule(Duration delay, void Function() callback) =>
      _TimerRefreshHandle(Timer(delay, callback));
}

final class _TimerRefreshHandle implements AttachmentRefreshHandle {
  _TimerRefreshHandle(this._timer);
  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final class AttachmentUrlMemoryCache {
  final Map<String, SignedAttachmentUrl> _entries = {};

  SignedAttachmentUrl? usable(
    String attachmentId,
    DateTime now, {
    Duration refreshBefore = const Duration(seconds: 30),
  }) {
    final entry = _entries[attachmentId];
    if (entry == null || !entry.expiresAt.isAfter(now.add(refreshBefore))) {
      _entries.remove(attachmentId);
      return null;
    }
    return entry;
  }

  void put(String attachmentId, SignedAttachmentUrl value) {
    _entries[attachmentId] = value;
  }

  void remove(String attachmentId) => _entries.remove(attachmentId);
  void clear() => _entries.clear();

  @visibleForTesting
  int get length => _entries.length;
}

sealed class AttachmentPreviewState {
  const AttachmentPreviewState();
}

final class AttachmentPreviewIdle extends AttachmentPreviewState {
  const AttachmentPreviewIdle();
}

final class AttachmentPreviewLoading extends AttachmentPreviewState {
  const AttachmentPreviewLoading();
}

final class AttachmentPreviewReady extends AttachmentPreviewState {
  const AttachmentPreviewReady({required this.kind, required this.url});
  final AttachmentPreviewKind kind;
  final Uri url;
}

final class AttachmentPreviewFailed extends AttachmentPreviewState {
  const AttachmentPreviewFailed(this.error);
  final AttachmentPreviewError error;
}

/// Owns ephemeral preview state. Signed URLs live only in [memoryCache] and
/// are never serialized, logged, or copied into attachment metadata.
final class AttachmentDownloadController extends ChangeNotifier {
  AttachmentDownloadController({
    required this.metadata,
    required AttachmentUrlProvider provider,
    required DateTime Function() clock,
    required this.memoryCache,
    AttachmentPreviewTelemetry? telemetry,
    AttachmentRefreshScheduler scheduler =
        const TimerAttachmentRefreshScheduler(),
  }) : _provider = provider,
       _clock = clock,
       _telemetry = telemetry,
       _scheduler = scheduler;

  final AttachmentPreviewMetadata metadata;
  final AttachmentUrlProvider _provider;
  final DateTime Function() _clock;
  final AttachmentUrlMemoryCache memoryCache;
  final AttachmentPreviewTelemetry? _telemetry;
  final AttachmentRefreshScheduler _scheduler;

  AttachmentPreviewState _state = const AttachmentPreviewIdle();
  Future<void>? _active;
  AttachmentRefreshHandle? _refreshHandle;
  int _generation = 0;
  bool _sessionClosed = false;
  bool _accessRevoked = false;
  bool _disposed = false;

  AttachmentPreviewState get state => _state;
  bool get isBusy => _active != null;
  bool get canOpen =>
      !_disposed &&
      !_sessionClosed &&
      !_accessRevoked &&
      _active == null &&
      metadata.previewKind != null;

  Future<void> open() => _load(forceRefresh: false);

  Future<void> refreshAfterForbidden() {
    if (_accessRevoked || _sessionClosed || _disposed) {
      return Future<void>.value();
    }
    _cancelRefresh();
    memoryCache.remove(metadata.attachmentId);
    _telemetry?.record('attachment_url_forbidden_refresh');
    return _load(forceRefresh: true);
  }

  Future<void> _load({required bool forceRefresh}) {
    if (_active case final Future<void> active) return active;
    if (_disposed || _sessionClosed || _accessRevoked) {
      return Future<void>.value();
    }
    final kind = metadata.previewKind;
    if (kind == null) {
      _setState(
        const AttachmentPreviewFailed(AttachmentPreviewError.unsupportedType),
      );
      _telemetry?.record('attachment_preview_unsupported');
      return Future<void>.value();
    }

    final generation = ++_generation;
    _cancelRefresh();
    _setState(const AttachmentPreviewLoading());
    late final Future<void> operation;
    operation =
        Future<void>.sync(() async {
              SignedAttachmentUrl? signed;
              if (!forceRefresh) {
                signed = memoryCache.usable(metadata.attachmentId, _clock());
                if (signed != null)
                  _telemetry?.record('attachment_url_cache_hit');
              }
              signed ??= await _provider.issue(
                attachmentId: metadata.attachmentId,
              );
              if (!_isCurrent(generation)) return;
              if (signed.url.scheme != 'https' ||
                  signed.url.host.isEmpty ||
                  !signed.expiresAt.isAfter(
                    _clock().add(const Duration(seconds: 30)),
                  )) {
                throw const _PreviewExpired();
              }
              memoryCache.put(metadata.attachmentId, signed);
              _telemetry?.record('attachment_url_ready');
              _setState(AttachmentPreviewReady(kind: kind, url: signed.url));
              _scheduleRefresh(signed);
            })
            .catchError((Object error, StackTrace stack) {
              if (!_isCurrent(generation)) return;
              memoryCache.remove(metadata.attachmentId);
              final mapped = switch (error) {
                AttachmentUrlException(failure: AttachmentUrlFailure.offline) =>
                  AttachmentPreviewError.offline,
                AttachmentUrlException(
                  failure: AttachmentUrlFailure.forbidden,
                ) =>
                  AttachmentPreviewError.accessRevoked,
                _PreviewExpired() => AttachmentPreviewError.expired,
                _ => AttachmentPreviewError.unavailable,
              };
              if (mapped == AttachmentPreviewError.accessRevoked) {
                _accessRevoked = true;
              }
              _cancelRefresh();
              _telemetry?.record('attachment_preview_${mapped.name}');
              _setState(AttachmentPreviewFailed(mapped));
            })
            .whenComplete(() {
              if (identical(_active, operation)) _active = null;
              if (_isCurrent(generation)) notifyListeners();
            });
    _active = operation;
    notifyListeners();
    return operation;
  }

  void cancel() {
    if (_disposed) return;
    _cancelRefresh();
    _generation += 1;
    _active = null;
    _setState(const AttachmentPreviewIdle());
    _telemetry?.record('attachment_preview_cancelled');
  }

  void closeSession() {
    if (_disposed || _sessionClosed) return;
    _sessionClosed = true;
    _accessRevoked = true;
    _cancelRefresh();
    _generation += 1;
    _active = null;
    memoryCache.clear();
    _setState(
      const AttachmentPreviewFailed(AttachmentPreviewError.accessRevoked),
    );
  }

  bool _isCurrent(int generation) =>
      !_disposed && !_sessionClosed && generation == _generation;

  void _scheduleRefresh(SignedAttachmentUrl signed) {
    _cancelRefresh();
    final delay = signed.expiresAt
        .subtract(const Duration(seconds: 30))
        .difference(_clock());
    if (delay <= Duration.zero) return;
    _refreshHandle = _scheduler.schedule(delay, () {
      _refreshHandle = null;
      if (_disposed || _sessionClosed || _accessRevoked) return;
      final current = _state;
      if (current is! AttachmentPreviewReady || current.url != signed.url) {
        return;
      }
      unawaited(_load(forceRefresh: true));
    });
  }

  void _cancelRefresh() {
    _refreshHandle?.cancel();
    _refreshHandle = null;
  }

  void _setState(AttachmentPreviewState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRefresh();
    _generation += 1;
    _active = null;
    super.dispose();
  }
}

final class _PreviewExpired implements Exception {
  const _PreviewExpired();
}
