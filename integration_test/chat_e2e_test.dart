import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timefit_native/app/app.dart';
import 'package:timefit_native/app/theme/app_theme.dart';
import 'package:timefit_native/features/home/presentation/business_preview_screen.dart';
import 'package:timefit_native/src/app_environment.dart';

import 'support/chat_fault_fixture.dart';

const String _chat079Capture = String.fromEnvironment(
  'TIMEFIT_CHAT079_CAPTURE',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (_chat079Capture.isNotEmpty) {
    _registerChat079Capture(_chat079Capture);
    return;
  }
  registerLocalChatFaultScenarios();
}

void _registerChat079Capture(String capture) {
  testWidgets('captures the CHAT-079 $capture fidelity fixture', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
    ]);
    addTearDown(
      () => SystemChrome.setPreferredOrientations(DeviceOrientation.values),
    );

    switch (capture) {
      case 'store-analysis':
        await tester.pumpWidget(
          const TimeFitApp(environment: AppEnvironment.dev),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('오늘 매장 현황'), findsOneWidget);
        await tester.tap(find.text('오늘 매장 현황'));
        await tester.pumpAndSettle();
        expect(find.text('매장 분석'), findsOneWidget);
        expect(find.text('오늘 매장 운영 상황을 한눈에 보여줘.'), findsOneWidget);
        expect(find.text('매출과 인건비를 분석했어요.'), findsOneWidget);
        expect(find.text('어제와 비교해서 어떤가요'), findsOneWidget);
        _announceCaptureReady(tester, capture, find.text('매장 분석'));
      case 'approval':
        final TextEditingController draftController = TextEditingController();
        final FocusNode draftFocusNode = FocusNode();
        addTearDown(draftController.dispose);
        addTearDown(draftFocusNode.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: DemoBusinessPreviewScreen.approvals(
              onBack: () {},
              draftController: draftController,
              draftFocusNode: draftFocusNode,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('승인 업무 도우미'), findsOneWidget);
        expect(find.textContaining('연차 요청'), findsOneWidget);
        expect(find.byKey(const Key('approval-deadline-pill')), findsOneWidget);
        _announceCaptureReady(tester, capture, find.text('승인 업무 도우미'));
      default:
        fail('Unsupported CHAT-079 capture fixture.');
    }

    await Future<void>.delayed(const Duration(seconds: 90));
  });
}

void _announceCaptureReady(
  WidgetTester tester,
  String capture,
  Finder screenAnchor,
) {
  final BuildContext context = tester.element(screenAnchor);
  final Size viewport = MediaQuery.sizeOf(context);
  final Orientation orientation = MediaQuery.orientationOf(context);
  debugPrint(
    'TIMEFIT_CHAT079_CAPTURE_READY '
    'fixture=$capture '
    'viewport=${viewport.width}x${viewport.height} '
    'orientation=${orientation.name}',
  );
}
