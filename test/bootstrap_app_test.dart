import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/src/app_environment.dart';
import 'package:timefit_native/src/bootstrap_app.dart';

void main() {
  testWidgets('dev bootstrap renders an explicit environment label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TimeFitBootstrapApp(environment: AppEnvironment.dev),
    );

    expect(find.text('TimeFit Dev'), findsOneWidget);
  });

  testWidgets('staging bootstrap renders an explicit environment label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TimeFitBootstrapApp(environment: AppEnvironment.staging),
    );

    expect(find.text('TimeFit Staging'), findsOneWidget);
  });

  test('production bootstrap fails closed', () {
    expect(
      () => runTimeFitBootstrap(AppEnvironment.production),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'production_configuration_unavailable',
        ),
      ),
    );
  });
}
