# 개인 Mac ↔ iPhone 시뮬레이터 ↔ AX ↔ SIWC GPT (개발 전용)

이 실험은 기본 TimeFit 앱 진입점, Supabase, 운영 데이터 및 일반 채팅을 변경하지 않습니다.
서버는 \`timefit-ax-server\`의 \`personal_roundtrip\` 모듈을 재사용하며 고정된 인사 한 번만 허용합니다.
iPhone 시뮬레이터와 Python은 **동일한 Mac**에서 실행해야 합니다.

## 서버

서버 저장소의 \`codex/ax-python-g2-service-directory-20261122\` 브랜치에서:

\`\`\`bash
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
\`\`\`

계정 소유자가 공식 OAuth 동의를 완료한 뒤
\`personal.ready loopback=8790 mode=one_greeting\`를 확인합니다.
서버가 실행되는 터미널은 종료하지 마세요. 기본 세션 수명은 약 300초입니다.

## Flutter

별도 터미널에서 이 저장소의 개발 브랜치를 체크아웃하고 고정된 Flutter SDK를 사용합니다.

\`\`\`bash
fvm flutter pub get --enforce-lockfile
fvm flutter test test/dev/personal_ax_screen_test.dart
fvm flutter run --flavor dev -t lib/dev/main_personal_ax.dart -d <iPhone-simulator-id>
\`\`\`

실제 iPhone 시뮬레이터 장치 ID는 \`fvm flutter devices\`에서 찾습니다.
Mac 터미널에서 \`cat "$RUN_DIR/pairing.txt"\`로 일회성 페어링 값을 읽고,
앱의 마스킹된 필드에 입력하세요. 값은 채팅, 터미널 스크린샷, CI, Git에 공유하지 않습니다.
**연결 확인**에서 \`ready\`를 확인하고 **안녕하세요 1회 전송**을 누릅니다.
응답이 완료되면 화면에 실제 답변과 인증 정리 여부를 표시합니다.

주의: 전송 버튼을 누른 뒤 timeout/응답 유실이 발생하면 새 UUID로 재전송하지 않습니다.
**응답 상태만 재조회**를 사용하세요. 새 시도는 해당 세션을 종료하고 별도 동의를
받은 다음 새 전용 DB·페어링 파일로 시작해야 합니다. 실제 GPT 요청은 플랜 사용량을
발생시킬 수 있습니다.

## 판정 및 제한

- 성공 조건: 앱에서 생성한 UUID가 서버의 개인 SQLite ledger에 일치하고,
  \`state=complete\`, 비어 있지 않은 실제 답변, 앱 표시 및 토큰 정리가 관측되어야 합니다.
- 기존 2026-11-22 G2 단일 호출은 **모바일 E2E 성공의 증거가 아닙니다**.
- 이 파일과 Flutter 테스트는 아직 실제 iPhone 시뮬레이터↔실계정 E2E를 증명하지 않습니다.
- 개인 로컬 실험 전용이며 운영 연결, 다중 사용자, 영속 세션, WSS, 상용 계정 중계를 지원하지 않습니다.
