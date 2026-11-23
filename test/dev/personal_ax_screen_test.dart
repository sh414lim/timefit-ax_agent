import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/dev/main_personal_ax.dart';
import 'package:timefit_native/dev/personal_ax_client.dart';

class FakePersonalApi implements PersonalAxApi {
  int sends = 0;
  String? id;
  bool failSend = false;
  String state = 'ready';

  @override
  Future<Map<String, dynamic>> status(String pairing) async => {
    'schemaVersion': 1,
    'testOnly': true,
    'modelProvider': 'chatgpt-siwc',
    'state': state,
    'clientRequestId': id,
    'answer': state == 'complete' ? '실제 답변 자리표시 테스트' : null,
    'cleanup': null,
  };

  @override
  Future<Map<String, dynamic>> greeting(String pairing, String requestId) async {
    sends += 1;
    id = requestId;
    if (failSend) throw const PersonalAxFailure('request_timeout');
    state = 'complete';
    return status(pairing);
  }
}

void main() {
  testWidgets('connection check does not send; one greeting shows answer',
      (tester) async {
    final api = FakePersonalApi();
    await tester.pumpWidget(PersonalAxVerificationApp(api: api));
    await tester.enterText(find.byType(TextField), 'a' * 43);
    await tester.tap(find.text('서버 연결 확인'));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    expect(find.text('상태: ready'), findsOneWidget);

    await tester.tap(find.text('안녕하세요 1회 전송'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(find.text('실제 답변 자리표시 테스트'), findsOneWidget);
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '안녕하세요 1회 전송'),
    );
    expect(send.onPressed, isNull);
  });

  testWidgets('timeout never permits another provider dispatch',
      (tester) async {
    final api = FakePersonalApi()..failSend = true;
    await tester.pumpWidget(PersonalAxVerificationApp(api: api));
    await tester.enterText(find.byType(TextField), 'a' * 43);
    await tester.tap(find.text('서버 연결 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('안녕하세요 1회 전송'));
    await tester.pump();
    expect(api.sends, 1);
    expect(find.textContaining('request_timeout'), findsOneWidget);
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '안녕하세요 1회 전송'),
    );
    expect(send.onPressed, isNull);
  });
}
