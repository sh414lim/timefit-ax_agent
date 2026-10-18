import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/src/app_environment.dart';
import 'package:timefit_native/src/bootstrap_app.dart';

void main() {
  testWidgets('unsigned bootstrap renders the TimeFit placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TimeFitBootstrapApp(environment: AppEnvironment.dev),
    );

    expect(find.textContaining('TimeFit'), findsOneWidget);
  });
}
