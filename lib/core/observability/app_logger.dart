import 'redaction.dart';

enum AppLogLevel { info, warning, error }

final class AppLogContext {
  AppLogContext({
    required String environment,
    required String app,
    required String build,
  }) : environment = SafeLogText.environment(environment),
       app = SafeLogText.buildValue(app),
       build = SafeLogText.buildValue(build);

  final SafeLogText environment;
  final SafeLogText app;
  final SafeLogText build;
}

final class AppLogRecord {
  AppLogRecord({
    required this.level,
    required SafeLogText eventCode,
    required AppLogContext context,
    required Map<String, Object?> fields,
  }) : export = Map.unmodifiable(<String, Object?>{
         'level': level.name,
         'eventCode': eventCode.toJsonValue(),
         'environment': context.environment.toJsonValue(),
         'app': context.app.toJsonValue(),
         'build': context.build.toJsonValue(),
         'fields': redactForExport(fields),
       });

  final AppLogLevel level;
  final Map<String, Object?> export;
}

abstract interface class AppLogSink {
  void write(AppLogRecord record);
}

final class NoOpAppLogSink implements AppLogSink {
  const NoOpAppLogSink();
  @override
  void write(AppLogRecord record) {}
}

final class FakeAppLogSink implements AppLogSink {
  final List<AppLogRecord> records = <AppLogRecord>[];
  @override
  void write(AppLogRecord record) => records.add(record);
}

final class AppLogger {
  const AppLogger({required AppLogContext context, required AppLogSink sink})
    : _context = context,
      _sink = sink;

  final AppLogContext _context;
  final AppLogSink _sink;

  void record(
    String eventCode, {
    AppLogLevel level = AppLogLevel.info,
    Map<String, Object?> fields = const {},
  }) {
    final record = AppLogRecord(
      level: level,
      eventCode: SafeLogText.stableCode(eventCode),
      context: _context,
      fields: fields,
    );
    try {
      _sink.write(record);
    } on Object {
      // Observability must never change product behavior. There is no print or
      // fallback export because it could disclose the rejected payload.
    }
  }

  void metric(ObservabilityMetric metric) =>
      record(metric.eventCode, fields: metric.fields);
}

sealed class ObservabilityMetric {
  const ObservabilityMetric();
  String get eventCode;
  Map<String, Object?> get fields;
}

final class OutboxAgeMetric extends ObservabilityMetric {
  const OutboxAgeMetric({required this.age, required this.clientMessageId});
  final Duration age;
  final ClientMessageId clientMessageId;
  @override
  String get eventCode => 'outbox_age';
  @override
  Map<String, Object?> get fields => {
    'ageMs': SafeLogNumber(age.inMilliseconds),
    'clientMessageId': clientMessageId,
  };
}

final class SendLatencyMetric extends ObservabilityMetric {
  const SendLatencyMetric({
    required this.latency,
    required this.clientMessageId,
  });
  final Duration latency;
  final ClientMessageId clientMessageId;
  @override
  String get eventCode => 'send_latency';
  @override
  Map<String, Object?> get fields => {
    'latencyMs': SafeLogNumber(latency.inMilliseconds),
    'clientMessageId': clientMessageId,
  };
}

enum UploadStage { queued, copying, uploading, ready, failed }

final class UploadStageMetric extends ObservabilityMetric {
  UploadStageMetric({required this.stage, required this.attachmentId});
  final UploadStage stage;
  final AttachmentId attachmentId;
  @override
  String get eventCode => 'upload_stage';
  @override
  Map<String, Object?> get fields => {
    'stage': SafeLogText.stableCode(stage.name),
    'attachmentId': attachmentId,
  };
}

final class ReconnectMetric extends ObservabilityMetric {
  const ReconnectMetric({required this.attempt});
  final int attempt;
  @override
  String get eventCode => 'reconnect';
  @override
  Map<String, Object?> get fields => {'attempt': SafeLogNumber(attempt)};
}

final class GapCountMetric extends ObservabilityMetric {
  const GapCountMetric({required this.count, required this.eventId});
  final int count;
  final EventId eventId;
  @override
  String get eventCode => 'gap_count';
  @override
  Map<String, Object?> get fields => {
    'count': SafeLogNumber(count),
    'eventId': eventId,
  };
}
