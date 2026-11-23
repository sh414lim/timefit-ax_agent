import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'personal_ax_client.dart';

// Isolated personal Mac/iPhone Simulator experiment, never production.
void main() => runApp(const PersonalAxVerificationApp());

class PersonalAxVerificationApp extends StatelessWidget {
  const PersonalAxVerificationApp({super.key, this.api});
  final PersonalAxApi? api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TimeFit AX personal verification',
    theme: ThemeData(useMaterial3: true),
    home: PersonalAxScreen(api: api ?? const PersonalAxHttpClient()),
  );
}

class PersonalAxScreen extends StatefulWidget {
  const PersonalAxScreen({required this.api, super.key});
  final PersonalAxApi api;

  @override
  State<PersonalAxScreen> createState() => _PersonalAxScreenState();
}

class _PersonalAxScreenState extends State<PersonalAxScreen> {
  final pairing = TextEditingController();
  Timer? poller;
  bool busy = false;
  bool sent = false;
  String state = '미연결';
  String? requestId;
  String? answer;
  String? error;
  String? providerFailureCode;
  bool cleanedUp = false;

  @override
  void dispose() {
    poller?.cancel();
    pairing.dispose();
    super.dispose();
  }

  void apply(Map<String, dynamic> snapshot) {
    final next = snapshot['state'];
    if (next is! String ||
        !const {
          'ready',
          'pending',
          'complete',
          'dispatch_unknown',
        }.contains(next)) {
      error = 'invalid_state';
      return;
    }
    final serverId = snapshot['clientRequestId'];
    if (requestId != null && serverId != null && serverId != requestId) {
      error = 'request_id_mismatch';
      return;
    }
    state = next;
    providerFailureCode = null;
    final failure = snapshot['failure'];
    if (state == 'dispatch_unknown' && failure is Map) {
      final code = failure['code'];
      if (code is String &&
          RegExp(r'^[a-z][a-z0-9_]{0,63}
      requestId ??= serverId;
      sent = true;
    }
    if (state == 'complete') {
      final text = snapshot['answer'];
      if (text is String && text.isNotEmpty) {
        answer = text;
      } else {
        error = 'empty_answer';
      }
    }
    final cleanup = snapshot['cleanup'];
    if (cleanup is Map) {
      cleanedUp =
          cleanup['remoteRevokeConfirmed'] == true &&
          cleanup['localTokensCleared'] == true;
    }
    if (state == 'complete' || state == 'dispatch_unknown') {
      poller?.cancel();
    }
  }

  Future<void> refresh() async {
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final snapshot = await widget.api.status(pairing.text.trim());
      if (mounted) setState(() => apply(snapshot));
    } on PersonalAxFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'status_unavailable');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startPolling() {
    poller?.cancel();
    if (state == 'complete' || state == 'dispatch_unknown') return;
    poller = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> sendGreeting() async {
    if (busy || sent || state != 'ready') return;
    final id = const Uuid().v4();
    setState(() {
      busy = true;
      sent = true; // Never retry an uncertain dispatch with a new UUID.
      requestId = id;
      state = 'pending';
      error = null;
    });
    try {
      final snapshot = await widget.api.greeting(pairing.text.trim(), id);
      if (mounted) setState(() => apply(snapshot));
    } on PersonalAxFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'dispatch_unknown');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        startPolling(); // GET only; does not send a second message.
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TimeFit AX · 개인 GPT 검증')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Mac iPhone 시뮬레이터 전용 · 127.0.0.1:8790'),
          const SizedBox(height: 10),
          const Text('개인 OAuth 1회 테스트. 일반 채팅 및 운영 서비스와 분리됩니다.'),
          const SizedBox(height: 20),
          TextField(
            controller: pairing,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Mac pairing.txt 값',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: busy || sent ? null : refresh,
            child: const Text('서버 연결 확인'),
          ),
          const SizedBox(height: 12),
          Text('상태: ' + state, key: const Key('personal-ax-status')),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: !busy && !sent && state == 'ready' ? sendGreeting : null,
            child: const Text('안녕하세요 1회 전송'),
          ),
          if (sent)
            OutlinedButton(
              onPressed: busy ? null : refresh,
              child: const Text('응답 상태만 재조회'),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              '진단: ' + error! + ' (자동 재전송 없음)',
              key: const Key('personal-ax-error'),
            ),
          if (providerFailureCode != null)
            Text(
              'SIWC 오류 코드: ' + providerFailureCode!,
              key: const Key('personal-ax-provider-failure'),
            ),
          if (requestId != null) Text('요청 ID: ' + requestId!),
          if (answer != null) ...[
            const Divider(height: 32),
            const Text('실제 GPT 답변'),
            SelectableText(answer!, key: const Key('personal-ax-answer')),
          ],
          if (sent) Text('인증 정리 확인: ' + (cleanedUp ? '완료' : '미확인')),
          const SizedBox(height: 24),
          const Text('페어링 값은 앱 메모리에만 보관하며 Git이나 로그에 저장하지 않습니다.'),
        ],
      ),
    ),
  );
}
).hasMatch(code)) {
        providerFailureCode = code;
      }
    }
    if (serverId is String) {
      requestId ??= serverId;
      sent = true;
    }
    if (state == 'complete') {
      final text = snapshot['answer'];
      if (text is String && text.isNotEmpty) {
        answer = text;
      } else {
        error = 'empty_answer';
      }
    }
    final cleanup = snapshot['cleanup'];
    if (cleanup is Map) {
      cleanedUp =
          cleanup['remoteRevokeConfirmed'] == true &&
          cleanup['localTokensCleared'] == true;
    }
    if (state == 'complete' || state == 'dispatch_unknown') {
      poller?.cancel();
    }
  }

  Future<void> refresh() async {
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final snapshot = await widget.api.status(pairing.text.trim());
      if (mounted) setState(() => apply(snapshot));
    } on PersonalAxFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'status_unavailable');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startPolling() {
    poller?.cancel();
    if (state == 'complete' || state == 'dispatch_unknown') return;
    poller = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  Future<void> sendGreeting() async {
    if (busy || sent || state != 'ready') return;
    final id = const Uuid().v4();
    setState(() {
      busy = true;
      sent = true; // Never retry an uncertain dispatch with a new UUID.
      requestId = id;
      state = 'pending';
      error = null;
    });
    try {
      final snapshot = await widget.api.greeting(pairing.text.trim(), id);
      if (mounted) setState(() => apply(snapshot));
    } on PersonalAxFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'dispatch_unknown');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        startPolling(); // GET only; does not send a second message.
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TimeFit AX · 개인 GPT 검증')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Mac iPhone 시뮬레이터 전용 · 127.0.0.1:8790'),
          const SizedBox(height: 10),
          const Text('개인 OAuth 1회 테스트. 일반 채팅 및 운영 서비스와 분리됩니다.'),
          const SizedBox(height: 20),
          TextField(
            controller: pairing,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Mac pairing.txt 값',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: busy || sent ? null : refresh,
            child: const Text('서버 연결 확인'),
          ),
          const SizedBox(height: 12),
          Text('상태: ' + state, key: const Key('personal-ax-status')),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: !busy && !sent && state == 'ready' ? sendGreeting : null,
            child: const Text('안녕하세요 1회 전송'),
          ),
          if (sent)
            OutlinedButton(
              onPressed: busy ? null : refresh,
              child: const Text('응답 상태만 재조회'),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              '진단: ' + error! + ' (자동 재전송 없음)',
              key: const Key('personal-ax-error'),
            ),
          if (requestId != null) Text('요청 ID: ' + requestId!),
          if (answer != null) ...[
            const Divider(height: 32),
            const Text('실제 GPT 답변'),
            SelectableText(answer!, key: const Key('personal-ax-answer')),
          ],
          if (sent) Text('인증 정리 확인: ' + (cleanedUp ? '완료' : '미확인')),
          const SizedBox(height: 24),
          const Text('페어링 값은 앱 메모리에만 보관하며 Git이나 로그에 저장하지 않습니다.'),
        ],
      ),
    ),
  );
}
