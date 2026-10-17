# 2026-10-17 오늘 티켓 실행 계획

## 오늘의 우선 티켓

오늘은 [`REL-001 — 기존 DevGym 레코드 정체성·사용자 0명 증거 감사`](https://trello.com/c/xFoln3Kq)를 최우선으로 진행한다. 현재 티켓은 백로그·미완료이며 이번 단계에서는 source evidence를 정리하고 콘솔·운영 artifact gap을 확정한다.

`timefit-ax_agent`는 기존 계획 문서의 `timefit-mobile`을 대체하는 실제 Flutter 네이티브 앱 저장소다. 기존 `time_fit`과 `tpghks521/dev_manager`는 읽기 전용 참고 대상이며 코드·빌드·배포 파이프라인을 연결하지 않는다.

## 오늘 REL-001 산출물

- [`legacy-app-identity-audit.md`](legacy-app-identity-audit.md)의 source baseline
- Android/iOS identity 후보와 iOS 설정 불일치 목록
- signing, Firebase/push, auth/API/backend와 release pipeline inventory
- 재사용 후보와 secret·legacy 구현의 재사용 금지 목록
- 동일 `as_of` 콘솔·backend·구독/IAP evidence 요청 목록
- `legacyUserMigrationDecision: PENDING`과 REL-001 완료 조건

사용자 0명, store record 동일성, update 가능성과 제품·정책 전환 가능성은 아직 승인하지 않는다.

## 세션별 담당과 현재 실행 범위

| 역할 | 오늘 착수 범위 | 현재 경계 |
| --- | --- | --- |
| 설계·총괄 | 의존성, identity field, 증거 상태와 역할 경계 관리 | 구현·QA 실행·병합·배포를 대신하지 않음 |
| 릴리스·정체성 감사 | App Store/Android 콘솔, 운영 binary, signing/version 근거 수집 | key·비밀번호·인증서 원문을 저장하거나 공유하지 않음 |
| 백엔드 증거 | 동일 `as_of`의 installation, 사용자 연결, push token, 구독/IAP 수치 대조 | DB/schema 변경과 운영 데이터 수정 금지 |
| Flutter 구현 | REL 결과를 소비할 준비와 후보 ID 불일치 검토 | REL-002 승인 전 bootstrap·production ID 입력 금지 |
| QA | update 연속성, 식별자·signing·entitlement 대조와 zero-user evidence 체크리스트 준비 | 앱 구현 테스트 및 store 제출 테스트는 아직 시작하지 않음 |
| 병합·배포 | 승인 증거와 branch/release Gate 검토 준비 | PR 병합, store upload와 운영 배포 금지 |

## 착수 순서

1. `REL-001`: source baseline을 유지하면서 콘솔·운영 artifact evidence를 수집한다.
2. `REL-001` identity field 구조가 승인되면 [`REL-002`](https://trello.com/c/jl0z2Tvd)의 저장소 경계 ADR을 `timefit-ax_agent` 기준으로 정리한다.
3. `REL-002`에서는 private repository, branch protection, CODEOWNERS, secret scanning, dev/staging/production 경계와 CI skeleton을 승인한다.
4. `REL-001`과 `REL-002`가 모두 완료된 뒤에만 [`CHAT-000`](https://trello.com/c/aTapyA3V)의 아키텍처 계약 동결을 시작한다.
5. `CHAT-000` 승인 전에는 후속 CHAT 구현 카드와 production 연결을 시작하지 않는다.

## REL-002 선행조건

- 승인된 identity manifest 필드 구조
- 실제 앱 저장소가 `sh414lim/timefit-ax_agent`라는 문서·티켓 기준 통일
- 모바일·backend code owner와 release owner 지정
- production ID를 source에 하드코딩하지 않는 주입·검증 원칙
- 기존 `time_fit`의 DB/RLS/RPC/Realtime/Storage 원본 소유권 유지

## CHAT-000 선행조건

- REL-001·REL-002 완료 링크와 승인자
- Android/iOS `REUSE_DEVGYM_RECORD` 대상의 공개 가능한 식별자
- 기존 웹/PWA 병렬 운영, additive-first backend, v1 계약 병행과 독립 배포 원칙
- Flutter PWA, AI/LLM, FastAPI/EC2 비범위 확인

## 오늘 종료 기준

- source evidence와 미확인 항목이 구분돼 있다.
- 콘솔·운영 binary 확인에 필요한 최소 질문이 준비돼 있다.
- 역할별 다음 행동과 금지 작업이 분리돼 있다.
- REL-001이 증거 없이 Done으로 이동하지 않는다.
- 파일 작성 이외의 commit, push, PR, Trello 상태 변경과 구현·배포를 수행하지 않는다.
