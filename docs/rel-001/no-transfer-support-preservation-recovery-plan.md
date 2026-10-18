# REL-001 no-transfer 지원·보존·복구 실행 계획

- 상태: `DRAFT_REVIEW_PENDING`
- 적용 경로: `legacyUserMigrationDecision=REQUIRED`
- 데이터 처리 결정: `legacyUserDataTransferDecision=USER_ATTESTED_DO_NOT_MIGRATE`
- 제품 결정 근거: 사용자가 기존 사용자 데이터 미이전과 기존 사용자 전원 동의를 직접 보고함
- 기술·출시 승인: `NOT_GRANTED`
- 연관 티켓: [REL-001](https://trello.com/c/xFoln3Kq), [REL-003](https://trello.com/c/5hCM0Z9l)
- 근거 문서: [legacy population evidence](legacy-user-zero-evidence.md), [production access matrix](production-access-matrix.md)

이 문서는 제품 결정을 다시 묻지 않고 안전한 no-transfer 구현과 검토 범위를 고정한다. 사용자 보고는 제품 의사와 consent 상태를 `USER_ATTESTED`로 기록할 근거지만, consent 원본의 독립 검증, 기술 소유자 지정, store target 선택, 기술 연속성 `GO`, 데이터 삭제, 서비스 종료, 결제 처리 또는 출시 승인은 아니다.

## 1. 실행 불변조건

1. legacy backend row, object, local DB, Keychain/Keystore 값, session, push token과 결제 상태를 TimeFit으로 복사하거나 읽지 않는다.
2. legacy 원본은 승인된 보존·폐기 결정 전까지 변경·삭제·대량 비활성화하지 않는다.
3. TimeFit은 fresh login에서 시작하고 legacy session을 인증 근거로 사용하지 않는다.
4. TimeFit local storage는 legacy 앱과 구분되는 새 namespace/schema로 초기화한다.
5. push는 TimeFit 화면에서 새 동의를 받은 뒤 현재 설치가 발급받은 token만 등록한다.
6. store/IAP evidence가 완료되기 전에는 legacy entitlement를 0, 종료 또는 이전 완료로 간주하지 않는다.
7. clean install과 기존 store build 위 uninstall 없는 update smoke를 모두 수행한다. no-transfer는 update 검증의 대체 사유가 아니다.
8. 장애 시 원본을 되돌려 쓰거나 legacy reader를 긴급 추가하지 않는다. rollout을 멈추고 compatible backend를 유지한 채 forward-fix한다.

## 2. no-transfer inventory

| 영역 | 허용 동작 | 금지 동작 | 검토 evidence | 책임 역할 | 상태 |
| --- | --- | --- | --- | --- | --- |
| 인증/session | fresh TimeFit login, 새 session 발급 | legacy session·cookie·Keychain/Keystore token 읽기 또는 승계 | update/clean-install 로그인 영상, source scan | Mobile Code Owner + Security Approver | `PENDING_OWNER_AND_TEST` |
| 로컬 데이터 | 새 namespace/schema 초기화 | legacy DB·cache·draft·pending operation import | namespace manifest, fixture, source scan | Mobile Code Owner | `PENDING_OWNER_AND_TEST` |
| backend 데이터 | 기존 row 보존, TimeFit 계약으로 새 요청 처리 | legacy row 복사·재분류·삭제·대량 비활성화 | 비식별 schema·store/platform mapping, 보존 결정 | Backend Evidence Owner + Product/Policy Approver | `PENDING_MAPPING_AND_APPROVAL` |
| push | 새 권한 요청 후 현재 token 등록 | legacy token·topic import 또는 자동 구독 | provider mapping, 권한·등록 테스트 | Mobile Code Owner + Backend Evidence Owner + Security Approver | `PENDING_PROVIDER_MAPPING` |
| 결제/IAP | evidence 확보 전 fail-closed, 지원 escalation | legacy entitlement를 0으로 추정하거나 자동 소멸·승계 | store/receipt export, 미정산 거래 확인 | Release Manager + Product/Policy Approver | `BLOCKED_PENDING_EVIDENCE` |
| 파일/storage | 기존 object 보존, TimeFit 신규 업로드만 새 계약 사용 | legacy object 이동·삭제·소유자 재연결 | 비식별 inventory와 retention owner | Backend Evidence Owner + Product/Policy Approver | `PENDING_INVENTORY` |
| 분석·로그 | 신규 client identifier로 최소 진단 수집 | legacy identity를 사용자 매핑 키로 재사용 | telemetry schema 검토 | Mobile Code Owner + Security Approver | `PENDING_OWNER_REVIEW` |

실제 계정, 이메일, token, 영수증, row 또는 object 목록은 이 저장소에 기록하지 않는다. 검토 evidence는 집계값, redacted export, checksum과 제한 접근 위치의 소유자만 기록한다.

## 3. 사용자 지원 계획

### 출시 전 준비

- 제품 책임자의 no-transfer 결정을 바탕으로 “기존 데이터가 TimeFit으로 이전되지 않으며 새 로그인이 필요하다”는 안내 초안을 만든다.
- 공지 대상·채널·시점·언어와 opt-out 또는 문의 경로는 Product/Policy Approver가 검토한다.
- 실제 legacy 사용자·테스터 대상 목록은 승인된 제한 접근 시스템에서 관리하며 Git에 넣지 않는다.
- Support Owner와 Backup Support Owner를 실제 사람으로 지정하고 근무 시간·응답 목표·escalation 채널을 기록한다.
- consent 원본이 확보되지 않으면 `NOT_INDEPENDENTLY_VERIFIED` 표기를 유지하고, 이를 검증 완료로 표현하지 않는다.

### 문의 처리 분류

| 문의 유형 | 1차 대응 | escalation | 금지 |
| --- | --- | --- | --- |
| 로그인 불가 | TimeFit 계정·인증 절차 안내 | Mobile Code Owner + Backend Evidence Owner | legacy session 복원 또는 token 전달 요구 |
| 기존 데이터 문의 | 미이전 정책과 원본 보존 상태 안내 | Product/Policy Approver | 즉석 삭제·수동 복사 약속 |
| push 미수신 | 새 동의·현재 token 등록 상태 확인 | Mobile Code Owner + Security Approver | legacy token 재활성화 |
| 결제·구독 | 거래 보존, 영수증·store support 경로 안내 | Release Manager + Product/Policy Approver | evidence 없이 환불·해지·entitlement 소멸 확정 |
| 데이터 권리 요청 | 승인된 개인정보 절차로 접수 | Product/Policy Approver | 지원 담당자의 직접 DB 수정 |

지원 안내를 실제 사용자에게 게시하거나 발송하는 행위는 별도 승인과 담당자 지정 후 수행한다.

## 4. 원본 보존 계획

1. legacy source commit, store artifact, signing/entitlement 비교 결과, backend 비식별 inventory와 provider export를 evidence ID와 checksum으로 묶는다.
2. 원본 위치, 접근 역할, retention 기간과 폐기 승인자를 제한 접근 register에 기록한다. 이 Git 문서에는 secret이나 로컬 절대경로를 적지 않는다.
3. 보존 중인 backend row·storage object·provider project·store record를 no-transfer 구현이 변경하지 않는지 release 전 read-only 대조한다.
4. 삭제·서비스 종료·provider project 해지·유료 계약 변경은 별도 티켓과 영향 분석, 복구 가능성, 명시적 승인을 요구한다.
5. checksum 불일치 또는 원본 접근 불가가 발견되면 release를 중단하고 evidence owner에게 escalation한다.

## 5. 복구와 중단 계획

### 중단 조건

- legacy reader/import, session 승계 또는 token import 코드가 발견됨
- 새 namespace 대신 legacy 저장소를 열거나 덮어씀
- store/IAP 상태를 증거 없이 0 또는 종료로 처리함
- 원본 row·object·provider 설정에 쓰기 동작이 발생함
- 실제 store target, signing lineage 또는 entitlement가 승인 범위를 벗어남
- update 또는 clean-install smoke가 실패함
- 지원·보존 책임자가 미지정이거나 연락 경로가 검증되지 않음

### 대응 순서

1. RC promotion 또는 rollout을 중단하고 incident evidence를 보존한다.
2. 모바일 웹과 compatible backend를 계속 유지하며 legacy 원본에는 쓰지 않는다.
3. client-scoped flag로 영향을 받은 신규 기능을 끄고, 강제 downgrade 대신 forward-fix를 준비한다.
4. 영향 범위, 최초 관찰 시각, build/commit, store cohort와 지원 문의를 기록한다.
5. Mobile, Backend Evidence, Release, Security, Product/Policy 역할이 수정안과 사용자 안내 필요성을 각각 검토한다.
6. 실제 기존 build→수정 RC update와 clean install을 다시 검증한 뒤 별도 재승인을 받는다.

## 6. 역할과 승인 경계

| 결정/검토 | 현재 근거 | 승인으로 인정되는 주체 | 현재 상태 |
| --- | --- | --- | --- |
| 기존 사용자 데이터 미이전 제품 결정 | 사용자 직접 보고 | Product Decision Authority | `USER_ATTESTED_CONFIRMED` |
| consent 원본·대상·고지 검증 | 원본 미확보 | Product/Policy Approver | `PENDING` |
| no-transfer 기술 설계 | 이 draft | Mobile Code Owner + Backend Evidence Owner + Security Approver | `PENDING_REVIEW` |
| 보존·retention·데이터 권리 절차 | 미지정 | Product/Policy Approver + Backend Evidence Owner | `PENDING_REVIEW` |
| 지원 운영과 복구 연락망 | 미지정 | Support Owner + Backup Support Owner | `PENDING_ASSIGNMENT` |
| store/IAP 처리 | evidence 미완료 | Release Manager + Product/Policy Approver | `BLOCKED_PENDING_EVIDENCE` |
| 기술 연속성·release | REL-001/003 미완료 | Release Manager + Security Approver + REL-003 승인자 | `NOT_APPROVED` |

Codex 역할 세션, 자동화 실행자, QA 관찰 source와 PR 작성자는 문서 작성·검증 evidence를 제공할 수 있지만 실제 인간 책임자 또는 승인자를 대신하지 않는다. GitHub handle과 역할은 신원·권한이 확인된 뒤에만 연결한다.

## 7. 검토 완료 조건

- no-transfer inventory의 모든 `PENDING_*` 항목에 실제 책임자, evidence 위치와 승인 시각이 기록됨
- consent 미검증 상태, 지원 공지, retention·복구 경계를 Product/Policy Approver가 검토함
- source scan에서 legacy reader/import가 없고 새 login·namespace·push 동의 fixture가 준비됨
- 동일 `as_of` store/backend/push/IAP evidence와 record/platform mapping이 REL-001에 연결됨
- update와 clean-install smoke 계획, 중단 조건, support escalation을 tabletop으로 검토함
- REL-003의 Technical 및 Product/Policy Gate가 각각 별도 결정을 기록함

이 조건이 충족돼도 본 문서만으로 production identity 설정, credential 연결, store upload 또는 release를 실행하지 않는다.
