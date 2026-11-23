import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/app/dev_chat_shell.dart';

const String _pairing = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  testWidgets('pairing dialog closes without using a disposed controller', (
    WidgetTester tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showPersonalChatPairingDialog(context);
            },
            child: const Text('Mac 서버 연결'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mac 서버 연결'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField), _pairing);
    await tester.tap(find.widgetWithText(FilledButton, '연결'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(result, _pairing);
    expect(tester.takeException(), isNull);
  });
}
