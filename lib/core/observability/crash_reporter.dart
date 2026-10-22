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
    try {
      _logger.record(
        'app_error',
        level: AppLogLevel.error,
        fields: {'errorCode': ErrorCode(stableErrorCode), ...fields},
      );
    } on Object {
      // The reporter boundary includes validation and payload construction.
      // Never fall back to printing the rejected exception or fields.
    }
  }
}
