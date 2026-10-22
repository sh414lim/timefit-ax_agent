import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/core/observability/observability_boundary.dart';

void main() {
  LocalCrashReporter reporter() => LocalCrashReporter(
    AppLogger(
      context: AppLogContext(environment: 'test', app: 'app', build: '1'),
      sink: FakeAppLogSink(),
    ),
  );
  test('QA crash reporter contains invalid code validation', () {
    expect(
      () => reporter().record(
        stableErrorCode: 'https://host/?token=canary',
        exception: StateError('canary'),
      ),
      returnsNormally,
    );
  });
  test('QA crash reporter contains throwing fields getters', () {
    expect(
      () => reporter().record(
        stableErrorCode: 'send_timeout',
        exception: StateError('canary'),
        fields: ThrowMap(),
      ),
      returnsNormally,
    );
  });
}

class ThrowMap extends MapBase<String, Object?> {
  @override
  Iterable<String> get keys => throw StateError('canary-getter');
  @override
  Object? operator [](Object? key) => null;
  @override
  void operator []=(String key, Object? value) => throw UnimplementedError();
  @override
  void clear() => throw UnimplementedError();
  @override
  Object? remove(Object? key) => throw UnimplementedError();
}
