# 개인 Mac AX 일반 채팅 Outbox 검증

이 경로는 `lib/dev/main_personal_chat.dart`로 명시적으로 실행한 iPhone
시뮬레이터에서만 사용한다. 서버 주소는 코드에 고정된
`http://127.0.0.1:8790`이며 개별 실행에서 생성된 43자 pairing 값이
필수다. staging, production, 실제 iPhone, 외부 호스트, Supabase 운영 DB,
다중 사용자 중계는 이 진입점에 없다.

## 오프라인 수용 검증

실제 OAuth나 모델 호출 없이 먼저 다음을 통과시킨다.

```bash
fvm flutter test test/dev/personal_chat_outbox_integration_test.dart \
  test/dev/personal_ax_screen_test.dart
fvm flutter analyze --fatal-infos --fatal-warnings
bash scripts/ci/test_ios_target_boundaries.sh
```

합성 API 검증은 다음을 고정한다.

- 최초 UUID가 `clientMessageId`/`clientRequestId`/Outbox ID로 계속 사용됨
- POST 결과 불명 후 GET history로 수렴하며 새 UUID를 만들지 않음
- durable acceptance 전에는 사용자 메시지를 `sent`로 바꾸지 않음
- assistant는 서버의 별도 UUID와 `personal-assistant:<UUID>` local ID로
  멱등 upsert됨
- 중간 `pending`에서 재시작해도 기존 Outbox 행 하나와 같은 UUID만
  재사용함
- `dispatch_unknown`은 durable user turn만 ack하고 assistant나 새 요청을
  만들지 않음

## 본인 승인 실제 E2E

이 단계는 본인 Mac에서 새 OAuth 동의와 실계정 사용량 발생을
명시적으로 승인한 후에만 수행한다. 서버는 `--personal-chat`으로
실행하고 새 private DB와 pairing 파일을 사용한다. 서버의
`personal.ready loopback=8790 mode=personal_chat`을 확인한 다음:

```bash
fvm flutter run --flavor dev \
  -t lib/dev/main_personal_chat.dart \
  -d <iPhone-simulator-id>
```

1. 화면 상단의 **Mac 서버 연결**에 pairing 값을 입력한다.
2. 기존 일반 채팅에서 새 대화를 만들고 텍스트를 한 번 보낸다.
3. 사용자 버블이 `전송됨`, assistant 버블이 별도로 나타나는지
   확인한다.
4. 앱을 종료·재실행하여 두 버블이 Drift SQLite에서 복구되는지
   확인한다. 아직 pending이었다면 같은 pairing으로 다시 연결하고
   같은 Outbox ID로 수렴하는지 확인한다.
5. 실제 본문·pairing·OAuth 값을 기록하지 말고 다음 메타데이터만
   대조한다.

```sql
-- Flutter dev SQLite
select local_id, server_id, client_message_id, sequence,
       sender_kind, delivery_state, length(body_text)
from local_messages order by sequence;
select id, client_request_id, state, attempt_count, last_error_code
from outbox_commands order by created_at;

-- Python private SQLite
select sequence, request_id, assistant_message_id, state, length(answer)
from personal_chat_turns order by sequence;
```

성공 판정은 양쪽의 user ID 일치, 별도 assistant ID, 서버 `complete`,
앱 assistant 버블, Outbox `completed`, 재시작 복구를 모두 확인해야 한다.
실제 GPT 호출은 CI와 이 자동 작업에서 실행하지 않는다.
