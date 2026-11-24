import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timefit_native/features/account/presentation/account_preview.dart';

const _email = Key('ax-account-email');
const _password = Key('ax-account-password');
const _submit = Key('ax-account-submit');
const _terms = Key('ax-account-terms');

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AxAccountPreviewPage()));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(_email), 'fixture@example.invalid');
  await tester.enterText(find.byKey(_password), 'fixture-test-only');
}

void main() {
  testWidgets(
    'profile to privacy and back; unavailable actions stay previews',
    (tester) async {
      await _open(tester);
      expect(find.text('데모 사용자'), findsOneWidget);
      expect(find.text('데모 · 미리보기'), findsOneWidget);
      await _tap(tester, find.text('개인정보'));
      expect(find.text('계정 정보'), findsOneWidget);
      expect(find.text('데이터 관리'), findsOneWidget);
      expect(find.text('demo@example.invalid'), findsOneWidget);
      await _tap(tester, find.text('계정 탈퇴 안내'));
      expect(find.text('계정 탈퇴 안내 · 미리보기'), findsOneWidget);
      await _tap(tester, find.text('확인'));
      await _tap(tester, find.byType(BackButton));
      expect(find.text('데모 사용자'), findsOneWidget);
      await _tap(tester, find.text('로그아웃'));
      expect(find.text('로그아웃 · 미리보기'), findsOneWidget);
      await _tap(tester, find.text('확인'));
      expect(find.text('데모 사용자'), findsOneWidget);
    },
  );

  testWidgets(
    'login validates demo-only fields, focuses next and masks input',
    (tester) async {
      await _open(tester);
      await _tap(tester, find.text('로그인 화면'));
      await tester.enterText(find.byKey(_email), 'bad-email');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final passwordInput = find.descendant(
        of: find.byKey(_password),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(passwordInput).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
      await _tap(tester, find.byTooltip('비밀번호 표시'));
      expect(tester.widget<EditableText>(passwordInput).obscureText, isFalse);
      await _tap(tester, find.byKey(_submit));
      expect(find.text('이메일 형식을 확인해 주세요.'), findsOneWidget);
      expect(find.text('로그인 · 미리보기'), findsNothing);
      await tester.enterText(find.byKey(_email), 'fixture@example.com');
      await _tap(tester, find.byKey(_submit));
      expect(
        find.text('미리보기에서는 @example.invalid 주소를 사용해 주세요.'),
        findsOneWidget,
      );
      await _fillForm(tester);
      await _tap(tester, find.byKey(_submit));
      expect(find.text('로그인 · 미리보기'), findsOneWidget);
      await _tap(tester, find.text('확인'));
      expect(
        tester.widget<EditableText>(passwordInput).controller.text,
        isEmpty,
      );
      expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
    },
  );

  testWidgets(
    'large-text login scrolls to active field and preserves preview boundary',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester);
      final list = find.byType(ListView);
      await tester.scrollUntilVisible(
        find.text('로그인 화면').hitTestable(),
        140,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await _tap(tester, find.text('로그인 화면'));
      final email = find.byKey(_email);
      await tester.scrollUntilVisible(
        email.hitTestable(),
        140,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await tester.enterText(email, 'fixture@example.invalid');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final passwordInput = find.descendant(
        of: find.byKey(_password),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(passwordInput).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.getCenter(passwordInput).dy, lessThan(340));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await _tap(tester, find.byType(BackButton));
      expect(find.text('프로필'), findsOneWidget);
    },
  );

  testWidgets(
    'signup consent gates button and keyboard, never creates account',
    (tester) async {
      await _open(tester);
      await _tap(tester, find.text('로그인 화면'));
      await _tap(tester, find.text('회원가입'));
      final button = find.byKey(_submit);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await _fillForm(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('회원가입 · 미리보기'), findsNothing);
      await _tap(tester, find.byKey(_terms));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await _tap(tester, button);
      expect(find.text('회원가입 · 미리보기'), findsOneWidget);
      await _tap(tester, find.text('확인'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await _tap(tester, find.text('이미 계정이 있어요'));
      expect(find.text('비밀번호 재설정'), findsOneWidget);
      expect(find.byKey(_terms), findsNothing);
    },
  );
}
