enum AttachmentFailure {
  invalidCount,
  invalidSize,
  unsupportedType,
  mimeMismatch,
  unsafeName,
  cancelled,
  unsafePath,
}

final class AttachmentException implements Exception {
  const AttachmentException(this.failure);
  final AttachmentFailure failure;
}

final class AttachmentCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Returns a remover so streaming work keeps only one pending listener.
  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }

  void check() {
    if (_cancelled)
      throw const AttachmentException(AttachmentFailure.cancelled);
  }
}

/// Picker-neutral input: adapters pass XFile.openRead or PlatformFile's stream.
/// Picker SDK objects and temporary source paths never enter persisted state.
final class AttachmentInput {
  const AttachmentInput({
    required this.name,
    required this.openRead,
    this.declaredMime,
  });
  final String name;
  final String? declaredMime;
  final Stream<List<int>> Function() openRead;
}

final class PrivateAttachment {
  const PrivateAttachment({
    required this.uri,
    required this.contentType,
    required this.bytesTotal,
    required this.sha256,
  });
  final Uri uri;
  final String contentType;
  final int bytesTotal;
  final String sha256;
}

abstract interface class AttachmentStore {
  Future<PrivateAttachment> copy(
    AttachmentInput input,
    AttachmentCancellation cancellation,
  );
  Future<void> delete(PrivateAttachment attachment);
}

final class AttachmentPolicy {
  static const maximumBytes = 20 * 1024 * 1024;
  static const maximumCount = 5;
  static void count(int count) {
    if (count < 1 || count > maximumCount)
      throw const AttachmentException(AttachmentFailure.invalidCount);
  }

  static String validate(AttachmentInput input, List<int> header, int bytes) {
    if (bytes < 1 || bytes > maximumBytes)
      throw const AttachmentException(AttachmentFailure.invalidSize);
    if (input.name.isEmpty ||
        input.name == '.' ||
        input.name == '..' ||
        input.name.contains(RegExp(r'[\u0000-\u001f\u007f]')) ||
        input.name.contains('/') ||
        input.name.contains('\\') ||
        input.name.contains('\u2215') ||
        input.name.contains('\u2044')) {
      throw const AttachmentException(AttachmentFailure.unsafeName);
    }
    bool prefix(List<int> signature, [int offset = 0]) =>
        header.length >= signature.length + offset &&
        List.generate(
          signature.length,
          (i) => header[i + offset] == signature[i],
        ).every((v) => v);
    final mime = prefix([0xff, 0xd8, 0xff])
        ? 'image/jpeg'
        : prefix([137, 80, 78, 71, 13, 10, 26, 10])
        ? 'image/png'
        : prefix([82, 73, 70, 70]) && prefix([87, 69, 66, 80], 8)
        ? 'image/webp'
        : prefix([37, 80, 68, 70, 45])
        ? 'application/pdf'
        : null;
    const extensions = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'pdf': 'application/pdf',
    };
    final extension = input.name.split('.').last.toLowerCase();
    if (mime == null || !extensions.containsKey(extension))
      throw const AttachmentException(AttachmentFailure.unsupportedType);
    if (extensions[extension] != mime ||
        (input.declaredMime != null &&
            input.declaredMime!.trim().toLowerCase() != mime)) {
      throw const AttachmentException(AttachmentFailure.mimeMismatch);
    }
    return mime;
  }
}
