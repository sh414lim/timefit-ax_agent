import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/src/app_environment.dart';

void main() {
  test('dev and staging are runnable non-production configurations', () {
    expect(AppEnvironment.dev.configurationKey, 'dev');
    expect(AppEnvironment.dev.expectedEntrypoint, 'lib/main.dart');
    expect(AppEnvironment.dev.isRunnable, isTrue);
    expect(AppEnvironment.staging.configurationKey, 'staging');
    expect(AppEnvironment.staging.expectedEntrypoint, 'lib/main_staging.dart');
    expect(AppEnvironment.staging.isRunnable, isTrue);
  });

  test('production remains unavailable until identity approval', () {
    expect(AppEnvironment.production.configurationKey, isNull);
    expect(AppEnvironment.production.expectedEntrypoint, isNull);
    expect(AppEnvironment.production.isRunnable, isFalse);
  });
}
