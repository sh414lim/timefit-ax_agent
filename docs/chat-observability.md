# Chat observability local slice

CHAT-071의 현재 범위는 모바일 앱 내부의 개인정보 안전 관측 경계다. 원격 수집은 하지 않으며 기본 sink는 no-op이다.

허용 데이터는 environment, app/build, typed correlation ID, stable event/error code와 숫자·불리언 metric이다. 사용자 식별자의 salt/hash 정책은 미확정이므로 사용자 식별 필드는 수집하지 않는다. 임의 문자열과 허용 목록 밖 key는 중첩 map/list를 포함해 제거 또는 `[REDACTED]` 처리한다. exception 메시지와 stack frame은 로컬 reporter가 읽거나 내보내지 않는다.

각 필드는 이름별 전용 typed value와 UUID 형식을 다시 검사한다. error code는 전용 `ErrorCode`, upload stage는 닫힌 enum만 허용한다. 로컬 test fixture ID는 `message-숫자`, `attachment-숫자`, `event-숫자`만 허용한다. 잘못된 event code와 sink 오류는 앱 흐름을 중단시키거나 fallback 출력으로 전달하지 않는다. map/list는 호출 전체에 공유되는 깊이·항목 방문 예산이 있고, 비유한 숫자는 `[REDACTED]`로 변환한다. 동기 getter 또는 iterator의 `moveNext` 자체가 반환하지 않는 입력은 이 동기 API가 선점할 수 없으므로 안전 보장 범위에 포함하지 않는다.

정의된 metric은 Outbox age, send latency, upload stage, reconnect attempt, gap count다. CHAT-053 attachment preview는 기존 telemetry seam을 `AppLoggerAttachmentPreviewTelemetry`로 연결하며 URL, 경로, query, fragment, userinfo, 파일명은 전달하지 않는다. sink 실패는 앱 흐름에 영향을 주지 않으며 fallback print를 하지 않는다.

dev-local 첨부 흐름은 `DevLocalAttachmentObservability`를 통해 같은 경계를 사용한다. picker 취소, private-copy 준비, draft 복원, 로컬 preview 성공과 실패, private-copy cleanup 실패는 서로 다른 stable event code로 구분한다. export에는 검증된 `clientMessageId`와 `attachmentId`, 닫힌 error code만 포함한다. picker가 준 파일명, private-copy 절대 경로와 URI, query/fragment, 파일 내용은 structured field로 전달하지 않는다. 실패의 exception 객체는 local reporter 호출에 전달될 수 있지만 adapter와 reporter는 해당 객체의 문자열이나 stack을 읽거나 export하지 않는다. cleanup 실패의 사용자 안내도 고정된 로컬 문구만 사용한다. 잘못된 파일명·상관관계 ID 또는 sink/reporter 실패는 앱의 선택·미리보기·정리 동작에 새로운 예외를 만들지 않는다.

기본 dev 앱 조립은 no-op sink와 local reporter를 사용하므로 외부 전송은 발생하지 않는다. 테스트에서는 같은 실제 draft/preview 경로에 fake sink를 주입해 파일명·경로·token canary가 export에 없고, 서로 다른 작업과 상관관계 ID는 보존되는지 확인한다.

미완료 범위는 Crashlytics SDK 및 collection, 사용자 식별 정책, consent·개인정보 정책, backend/web telemetry, dashboard/alert, staging export, production sampling과 배포다. 실제 서비스 연결 전 별도 계약 및 privacy 검토가 필요하다.
