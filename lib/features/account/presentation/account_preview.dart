import 'package:flutter/material.dart';

import '../../home/presentation/widgets/brand_asset_slot.dart';

const _blue = Color(0xFF2463D7);
const _ink = Color(0xFF23344D);
const _muted = Color(0xFF526783);
const _pale = Color(0xFFF1F6FF);
const _line = Color(0xFFE2EAF6);
const _demoEmail = 'demo@example.invalid';

/// Screens 08–11 are standalone UI previews; no account services are loaded.
class AxAccountPreviewPage extends StatelessWidget {
  const AxAccountPreviewPage({super.key});

  @override
  Widget build(BuildContext context) => _Page(
    title: '프로필',
    children: [
      const SizedBox(height: 12),
      const Center(
        child: CircleAvatar(
          radius: 32,
          backgroundColor: _pale,
          foregroundColor: _blue,
          child: Icon(Icons.person_outline_rounded, size: 32),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '데모 사용자',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        _demoEmail,
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 13),
      ),
      const SizedBox(height: 24),
      _Section(
        title: '계정 설정',
        rows: [
          _Row(
            icon: Icons.edit_outlined,
            title: '프로필 편집',
            onTap: () => _notice(context, '프로필 편집'),
          ),
          _Row(
            icon: Icons.shield_outlined,
            title: '개인정보',
            onTap: () => _push(context, const _Privacy()),
          ),
          _Row(
            icon: Icons.notifications_none,
            title: '알림 설정',
            onTap: () => _notice(context, '알림 설정'),
          ),
          _Row(
            icon: Icons.logout,
            title: '로그아웃',
            onTap: () => _notice(context, '로그아웃'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Section(
        title: '인증 화면 미리보기',
        rows: [
          _Row(
            icon: Icons.login,
            title: '로그인 화면',
            onTap: () => _push(context, const _AuthForm()),
          ),
        ],
      ),
    ],
  );
}

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

Future<void> _notice(BuildContext context, String title) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('$title · 미리보기'),
    content: const Text('화면만 확인할 수 있어요. 실제 계정이나 데이터는 변경되지 않습니다.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('확인'),
      ),
    ],
  ),
);

class _Privacy extends StatelessWidget {
  const _Privacy();

  @override
  Widget build(BuildContext context) => _Page(
    title: '개인정보',
    children: [
      const _Hint('아래 정보는 데모용입니다. 실제 계정 정보는 불러오지 않아요.'),
      const SizedBox(height: 16),
      _Section(
        title: '계정 정보',
        rows: [
          const _Row(
            icon: Icons.mail_outline,
            title: '이메일',
            detail: _demoEmail,
          ),
          _Row(
            icon: Icons.lock_outline,
            title: '비밀번호 변경',
            onTap: () => _notice(context, '비밀번호 변경'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Section(
        title: '데이터 관리',
        rows: [
          _Row(
            icon: Icons.description_outlined,
            title: '개인정보 처리방침',
            onTap: () => _notice(context, '개인정보 처리방침'),
          ),
          _Row(
            icon: Icons.person_remove_outlined,
            title: '계정 탈퇴 안내',
            onTap: () => _notice(context, '계정 탈퇴 안내'),
          ),
        ],
      ),
    ],
  );
}

class _AuthForm extends StatefulWidget {
  const _AuthForm({this.signup = false});

  final bool signup;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _form = GlobalKey<FormState>();
  bool _visible = false;
  bool _terms = false;

  bool get _submitEnabled => !widget.signup || _terms;

  void _submit() {
    if (!_submitEnabled || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _form.currentState!.reset();
    if (_visible || _terms) {
      setState(() {
        _visible = false;
        _terms = false;
      });
    }
    _notice(context, widget.signup ? '회원가입' : '로그인');
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: widget.signup ? '회원가입' : '로그인',
    children: [
      const SizedBox(height: 8),
      const Center(
        child: TimeFitAssetSlot(
          kind: TimeFitAssetKind.squareLogo,
          width: 52,
          height: 52,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'TimeFit AX',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 14),
      const _Hint('실제 이메일과 비밀번호를 입력하지 마세요. 예시 값으로 입력 형식만 확인할 수 있어요.'),
      const SizedBox(height: 18),
      Form(
        key: _form,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('ax-account-email'),
                decoration: _input('이메일', hint: _demoEmail),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return '이메일 형식을 확인해 주세요.';
                  }
                  if (!email.toLowerCase().endsWith('@example.invalid')) {
                    return '미리보기에서는 @example.invalid 주소를 사용해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('ax-account-password'),
                decoration: _input(
                  '비밀번호',
                  hint: '테스트용 8자 이상',
                  suffix: IconButton(
                    tooltip: _visible ? '비밀번호 숨기기' : '비밀번호 표시',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                obscureText: !_visible,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => (value?.trim().length ?? 0) < 8
                    ? '테스트 값은 8자 이상 입력해 주세요.'
                    : null,
              ),
              if (widget.signup) ...[
                const SizedBox(height: 10),
                CheckboxListTile(
                  key: const Key('ax-account-terms'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: _blue,
                  title: const Text(
                    '이용약관 및 개인정보 처리 안내 확인 (필수)',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text('미리보기 체크이며 동의는 저장되지 않아요.'),
                  value: _terms,
                  onChanged: (value) => setState(() => _terms = value ?? false),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('ax-account-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _submitEnabled ? _submit : null,
                child: Text(widget.signup ? '가입하기' : '로그인'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      if (widget.signup)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('이미 계정이 있어요'),
        )
      else ...[
        TextButton(
          onPressed: () => _notice(context, '비밀번호 재설정'),
          child: const Text('비밀번호 재설정'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _form.currentState!.reset();
            setState(() => _visible = false);
            _push(context, const _AuthForm(signup: true));
          },
          child: const Text('회원가입'),
        ),
      ],
    ],
  );

  InputDecoration _input(
    String label, {
    required String hint,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    errorMaxLines: 2,
    filled: true,
    fillColor: const Color(0xFFF8FAFE),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _line),
    ),
    suffixIcon: suffix,
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _pale,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      '데모 · 미리보기',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _pale,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, style: const TextStyle(color: _muted, fontSize: 13)),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(color: _line, height: 1),
              rows[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.detail,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    leading: Icon(icon, color: _blue, size: 20),
    title: Text(title, style: const TextStyle(color: _ink, fontSize: 14)),
    subtitle: detail == null
        ? null
        : Text(detail!, style: const TextStyle(color: _muted, fontSize: 12)),
    trailing: onTap == null
        ? null
        : const Icon(Icons.chevron_right, color: _muted, size: 20),
    onTap: onTap,
  );
}
