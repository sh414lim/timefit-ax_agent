# 개인 Mac ↔ iPhone 시뮬레이터 ↔ AX ↔ SIWC GPT (개발 전용)

이 실험은 기본 TimeFit 앱 진입점, Supabase, 운영 데이터 및 일반 채팅을 변경하지 않습니다.
서버는 `timefit-ax-server`의 `personal_roundtrip` 모듈을 재사용하며 고정된 인사 한 번만 허용합니다.
iPhone 시뮬레이터와 Python은 **동일한 Mac**에서 실행해야 합니다.

## 서버

서버 저장소의 `codex/ax-python-g2-service-directory-20261122` 브랜치에서:

```bash
RUN_DIR="$(mktemp -d "$HOME/timefit-ax-e2e.XXXXXX")"
chmod 700 "$RUN_DIR"
uv run --frozen --extra siwc-sdk python -m timefit_ax_agent.personal_roundtrip \
  --personal-live-test --acknowledge-plan-usage \
  --acknowledge-process-kill-limit --openai-sdk \
  --allow-missing-content-type \
  --database "$RUN_DIR/personal.sqlite" \
  --pairing-file "$RUN_DIR/pairing.txt" \
  --host-id-directory "$RUN_DIR/host-id" \
  --model gpt-6.2-sol
```

계정 소유자가 공식 OAuth 동의를 완료한 뒤
`personal.ready loopback=8790 mode=one_greeting`를 확인합니다.
서버가 실행되는 터미널은 종료하지 마세요. 기본 세션 수명은 약 300초입니다.

## Flutter

별도 터미널에서 이 저장소의 개발 브랜치를 체크아웃하고 고정된 Flutter SDK를 사용합니다.

```bash
fvm flutter pub get --enforce-lockfile
fvm dart format lib/dev/main_personal_ax.dart lib/dev/personal_ax_client.dart test/dev/personal_ax_screen_test.dart
bash scripts/ci/test_ios_target_boundaries.sh
fvm flutter test test/dev/personal_ax_screen_test.dart
fvm flutter run --flavor dev -t lib/dev/main_personal_ax.dart -d <iPhone-simulator-id>
```

실제 iPhone 시뮬레이터 장치 ID는 `fvm flutter devices`에서 찾습니다.
Mac 터미널에서 `cat "$RUN_DIR/pairing.txt"`로 일회성 페어링 값을 읽고,
앱의 마스킹된 필드에 입력하세요. 값은 채팅, 터미널 스크린샷, CI, Git에 공유하지 않습니다.
**연결 확인**에서 `ready`를 확인하고 **안녕하세요 1회 전송**을 누릅니다.
응답이 완료되면 화면에 실제 답변과 인증 정리 여부를 표시합니다.

주의: 전송 버튼을 누른 뒤 timeout/응답 유실이 발생하면 새 UUID로 재전송하지 않습니다.
**응답 상태만 재조회**를 사용하세요. 새 시도는 해당 세션을 종료하고 별도 동의를
받은 다음 새 전용 DB·페어링 파일로 시작해야 합니다. 실제 GPT 요청은 플랜 사용량을
발생시킬 수 있습니다.

## iOS Xcode 타깃 경계

기존 iOS 보호 스크립트 `scripts/ci/validate_ios_environment.sh`는
정확한 `lib/dev/main_personal_ax.dart`를 **dev / Debug-dev / iphonesimulator**에서만 허용합니다.
staging, release/profile, 실제 iPhone, 외부 경로와 임의의 Dart 진입점은 계속 거부합니다.
변경된 브랜치가 설치되지 않았으면 Xcode가
`dev does not allow the requested Flutter target and build boundary`로 실패합니다.

```bash
git fetch origin
git pull --ff-only origin codex/personal-ax-loopback-simulator-20261123
bash scripts/ci/test_ios_target_boundaries.sh
```

빌드가 완료된 뒤 개인 OAuth를 새로 승인해 서버의 one-shot 세션이 만료되지 않은 상태로 전송해야 합니다.
별도 터미널에는 서버 측 `RUN_DIR` 변수가 자동으로 전달되지 않습니다.

## 판정 및 제한

- 성공 조건: 앱에서 생성한 UUID가 서버의 개인 SQLite ledger에 일치하고,
  `state=complete`, 비어 있지 않은 실제 답변, 앱 표시 및 토큰 정리가 관측되어야 합니다.
- 기존 2026-11-22 G2 단일 호출은 **모바일 E2E 성공의 증거가 아닙니다**.
- 이 파일과 Flutter 테스트는 아직 실제 iPhone 시뮬레이터↔실계정 E2E를 증명하지 않습니다.
- 개인 로컬 실험 전용이며 운영 연결, 다중 사용자, 영속 세션, WSS, 상용 계정 중계를 지원하지 않습니다.

## 2026-11-23 dispatch_unknown 후속 진단

실제 iPhone 시뮬레이터에서는 앱에서 Python으로 요청이 접수돼 개인 SQLite에 기록되었지만,
답변이 없는 `dispatch_unknown` 상태가 두 차례 관측되었습니다. 토큰 정리 표시는 완료였으며,
이는 **GPT 응답 성공이나 외부 제공자의 요청 수락 확인이 아닙니다**. 기존 코드에서는 원래
내부 실패 원인을 제거했으므로 이전 SQLite만으로 원인을 확정할 수 없습니다.

Python 저장소의 별도 Draft PR [#7](https://github.com/sh414lim/timefit-ax-server/pull/7)은
개인 one-shot 상태에 allowlist로 제한한 `failure.code`를 추가하며,
이번 Flutter 개발 화면은 그 코드가 있을 때만 `SIWC 오류 코드`로 표시합니다.
서버 오류 내용, GPT 답변 원문, OAuth 토큰 및 페어링 값을 표시·저장하지 않습니다.
원인 미확인 요청은 동일 세션에서 다시 보내지 않으며, 새 계정 호출은 오프라인 회귀 검사와
본인 동의를 마친 별도 실험에서만 진행합니다. 앱 코드와 문서 자체는 실제 E2E 성공 증거가 아닙니다.

## 2026-11-23 native iPhone Simulator actual response evidence

The owner supplied an actual iPhone Simulator screen showing a request
transitioning `pending` → `complete`, a nonempty GPT greeting answer
rendered under `실제 GPT 답변`, and `인증 정리 확인: 완료` in
the personal-only app. The previous failed session reported
`live_session_expired` after diagnostics were introduced. The successful
capture followed a new consent/session. This establishes the **one-shot
owner-local native app → Python AX bridge → SIWC GPT → app response-display**
path, not production service integration.

This run does not validate multi-turn conversation, public WSS, customer
subscriptions, operational Supabase ledger or physical-device deployment.
The successful request UUID, model output body, pairing secret, or OAuth
tokens must not be committed. A separate final SQLite ledger query would
strengthen durability proof.
