# Chat observability local slice

CHAT-071의 현재 범위는 모바일 앱 내부의 개인정보 안전 관측 경계다. 원격 수집은 하지 않으며 기본 sink는 no-op이다.

허용 데이터는 environment, app/build, typed correlation ID, stable event/error code와 숫자·불리언 metric이다. 사용자 식별자의 salt/hash 정책은 미확정이므로 사용자 식별 필드는 수집하지 않는다. 임의 문자열과 허용 목록 밖 key는 중첩 map/list를 포함해 제거 또는 `[REDACTED]` 처리한다. exception 메시지와 stack frame은 로컬 reporter가 읽거나 내보내지 않는다.

정의된 metric은 Outbox age, send latency, upload stage, reconnect attempt, gap count다. CHAT-053 attachment preview는 기존 telemetry seam을 `AppLoggerAttachmentPreviewTelemetry`로 연결하며 URL, 경로, query, fragment, userinfo, 파일명은 전달하지 않는다. sink 실패는 앱 흐름에 영향을 주지 않으며 fallback print를 하지 않는다.

미완료 범위는 Crashlytics SDK 및 collection, 사용자 식별 정책, consent·개인정보 정책, backend/web telemetry, dashboard/alert, staging export, production sampling과 배포다. 실제 서비스 연결 전 별도 계약 및 privacy 검토가 필요하다.
