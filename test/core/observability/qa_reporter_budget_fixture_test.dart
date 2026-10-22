import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  test(
    'QA reporter respects map traversal budget before payload construction',
    () {
      final fields = CountingFields();
      final logger = AppLogger(
        context: AppLogContext(environment: 'test', app: 'app', build: '1'),
        sink: FakeAppLogSink(),
      );
      LocalCrashReporter(logger).record(
        stableErrorCode: 'send_timeout',
        exception: StateError('secret'),
        fields: fields,
      );
      expect(
        fields.visits,
        lessThanOrEqualTo(64),
        reason: 'payload spread must not traverse beyond redaction map budget',
      );
    },
  );
}

class CountingFields extends MapBase<String, Object?> {
  int visits = 0;
  @override
  Iterable<String> get keys sync* {
    for (var i = 0; i < 1000; i++) {
      visits++;
      yield 'unknown$i';
    }
    throw StateError('finite stop');
  }

  @override
  Object? operator [](Object? key) => 'secret';
  @override
  void operator []=(String key, Object? value) => throw UnimplementedError();
  @override
  void clear() => throw UnimplementedError();
  @override
  Object? remove(Object? key) => throw UnimplementedError();
}
