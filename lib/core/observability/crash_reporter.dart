import 'app_logger.dart';
import 'redaction.dart';

abstract interface class CrashReporter {
  void record({
    required String stableErrorCode,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, Object?> fields,
  });
}

/// Local-only reporter. Exception text and stack frames are deliberately not
/// inspected or exported.
final class LocalCrashReporter implements CrashReporter {
  const LocalCrashReporter(this._logger);
  final AppLogger _logger;

  @override
  void record({
    required String stableErrorCode,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    _logger.record(
      'app_error',
      level: AppLogLevel.error,
      fields: {'errorCode': SafeLogText.stableCode(stableErrorCode), ...fields},
    );
  }
}
