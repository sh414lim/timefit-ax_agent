# REL-001 production evidence access matrix

- 티켓: [REL-001 — 기존 DevGym 레코드 정체성·사용자 0명 증거 감사](https://trello.com/c/xFoln3Kq)
- 설계 원문: [145 — 네이티브 앱 저장소·출시 계획](../145-timefit-native-app-repository-migration-plan-2026-10-16.md)의 REL-001 작업 1~13, 산출물과 수용 기준
- 후속 Gate: [146 — 네이티브 채팅 아키텍처](../146-timefit-native-chat-architecture-2026-10-16.md)의 2.4~2.5와 [147 — 실행 티켓 카탈로그](../147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md)의 REL 완료 Gate
- 목적: 확인된 콘솔·빌드 evidence와 아직 필요한 접근을 분리해 기록
- 운영 변경: 없음

```yaml
evidenceStatus: PARTIAL_MULTI_SOURCE_OBSERVED
integratedAsOf: null
backendObservedAt: 2026-10-17T08:38:09.492Z
backendEvidenceStatus: PARTIAL_AGGREGATES_OBSERVED_SCOPE_UNMAPPED
backendEvidencePackageStatus: LOCAL_TRANSCRIPTION_CHECKSUM_VERIFIED_PROVIDER_EXPORT_NOT_ACQUIRED
broGymCurrentUsageReport: USER_ATTESTED_NOT_IN_USE
broGymUsageReportObservedAt: 2026-10-17T09:45:49Z
existingUserConsentStatus: USER_ATTESTED_ALL_EXISTING_USERS
legacyUserDataTransferDecision: USER_ATTESTED_DO_NOT_MIGRATE
consentArtifactVerification: NOT_INDEPENDENTLY_VERIFIED
broGymServiceRetirementApproval: NOT_GRANTED
githubReviewAccess: PENDING_INVITATION_NOT_EFFECTIVE
storeTargetSelectionApproval: PENDING
technicalContinuityApproval: PENDING
productPolicyApproval: USER_ATTESTED_NO_DATA_MIGRATION_OTHER_POLICY_REVIEW_PENDING
legacyUserMigrationApproval: USER_ATTESTED_PRODUCT_DECISION_EXECUTION_PLAN_REVIEW_PENDING
releaseApproval: PENDING
```

`integratedAsOf`는 Android, iOS, backend, push와 구독/IAP를 같은 기준 시각과 조회 범위로 다시 확인하기 전에는 채우지 않는다. 이 문서는 record 선택, production identity 적용, 데이터 삭제 또는 출시를 승인하지 않는다.

## Evidence source와 기준 시각

| Evidence ref | Source | 관찰 시각(UTC) | 데이터 기준 시각 | 확인 범위 |
| --- | --- | --- | --- | --- |
| `REL001-ANDROID-CONSOLE-QA-20261017T031417Z` | Google Play Console read-only QA 관찰 | `2026-10-17T03:14:17Z` | 최신 완전 통계 `2026-10-13` | package, release/version, 설치·활성 지표, Play App Signing 상태 |
| `REL001-IOS-ASC-QA-01a147a4-9770` | App Store Connect read-only QA 역할 결과 `cloud 01a147a4-9770` | `2026-10-17T03:23:36Z` | 90일 analytics 최신 `2026-10-15`; TestFlight는 관찰 시점 현재값 | 두 앱 record, version/build, TestFlight 설치·session, actual build Team, 계약·IAP 화면 |
| `REL001-BACKEND-AGGREGATES-20261017T083809492Z` | Supabase `bro-gym` project ref `nzxgcfwranspxynzyglb` aggregate-only SQL | `2026-10-17T08:38:09.492Z` | 쿼리 실행 시점 현재값 | 10초 timeout, read-only transaction, `ROLLBACK`; `public.users`·`auth.users`·auth linkage·최근 sign-in·admin login·FCM/device token·push queue·일반 membership subscription 집계와 store 전용 IAP 명명 object 탐색; raw 개인 행·token 미조회 |
| `REL001-PRODUCT-MIGRATION-DECISION-20261017T094549Z` | 사용자 직접 보고 | `2026-10-17T09:45:49Z` | 현재 제품 방침 진술 | bro-gym 미사용, 기존 사용자 전원 동의, 기존 사용자 데이터 미이전으로 진행; `USER_ATTESTED`이며 제3자 consent 원본의 독립 검증, 데이터 삭제, 서비스 종료 또는 구독 해지 승인이 아님 |
| `REL001-GITHUB-COLLAB-20261017T083211Z` | GitHub API read-only 재조회 | `2026-10-17T08:32:11Z` | 초대 생성 `2026-10-17T08:19:32Z` | `tpghks521` write 초대 `338202054`는 pending·미만료이고 실제 permission은 `none` |

Android, iOS store와 backend evidence의 관찰 시각·데이터 기준일·조회 범위가 다르므로 하나의 `as_of`로 합치지 않는다. backend 조회 시 service에 `restricted/unhealthy` banner가 있었지만 제한된 읽기 집계 쿼리는 성공했다. 이 성공은 서비스 건전성, 전체 schema 포괄 또는 store record와의 사용자 매핑을 증명하지 않는다. backend SQL·비식별 전사본·실행 기록은 아래 checksum으로 확인했지만 provider 원본 export와 서버 audit evidence는 확보되지 않았다. 스토어 콘솔 원본 export도 아직 이 문서에 연결되지 않았다.

### Backend evidence package 검증

제한 접근 local transcription package는 읽기 전용으로 확인했으며 저장소에 복사하지 않았다. 로컬 절대경로는 기록하지 않는다.

- evidence ID: `REL-001-legacy-backend-aggregate-20261017T083809492Z`
- aggregate transcription SHA-256: `332b40a1c5c75f4542918dc7eda184a415f5095a139648cd136bf23d461e1f57`
- execution log transcription SHA-256: `95230cd44e49b26f6f5f3123d2aefbe365f022c4bbc9e09f4e49c121aec786ea`
- account/token/push/billing/IAP schema query SHA-256: `f5d7ba9e6fb56e406ffc6f3d73d0f050cbef210e8381268456087a47e16bbcf2`, `79a3a5ec9548d1b8b475f7a2e46113469b9f2bbf0e862d7a1e98a8bd30213ace`, `4034cf8a4d7a46cec1eeec3854b7c1b3ebfb9fe331778bbc0f7e69c5901191c5`, `e08273ea7c690abe3c2b2c6cd3e0e1ceab9e480a6c41a6ca4fa2d6ac79b2ec3b`, `ef9083c4a15f0cb26a1b054f689cc880b0a788e3ea8fbd7f50861256ee7351d4`
- 한계: Supabase dashboard 원본 CSV/JSON export, 서버 query history/audit log, 공급자 서명·timestamp 실행 영수증과 결과 screenshot은 확보되지 않았다. package는 관측 직후 만든 비식별 전사본이며 provider 원본 export가 아니다.

## 플랫폼·시스템 접근 및 확인 상태

| 시스템 | 확인된 사실 | 아직 필요한 확인 | 최소 담당 역할 | 상태 |
| --- | --- | --- | --- | --- |
| Android store record | package `com.leofitTech.devmanager.admin.dev_manager`; 운영 `1.0.1 (11)`; 내부 테스트 최대 확인 versionCode `1784618057`; 공개 listing은 [데브-매니저](https://play.google.com/store/apps/details?id=com.leofitTech.devmanager.admin.dev_manager) | record 내부 ID·소유 계정의 redacted 기록, 다음 versionCode 정책 | Release Manager | `PARTIAL_VERIFIED` |
| Play App Signing | 사용 중이며 package 연속성 후보 확인 | app-signing certificate fingerprint, upload certificate·credential 소유자와 lineage, 마지막 운영 AAB/APK checksum | Release Manager + Security Approver | `PENDING_SIGNING_LINEAGE` |
| Android population | 설치한 사용자 `5`, 최근 28일 MAU 활성 기기 `1` | backend 계정·installation·push token과 동일 기준 시각 reconciliation | Backend Evidence Owner + Release Manager | `NONZERO_VERIFIED_RECONCILIATION_PENDING` |
| Android 결제 | Payments 계정 미설정으로 조회 불가 | 활성 구독, 판매 중 IAP, 복원 가능 entitlement, 미정산 거래의 권한 있는 조회 | Owner + Product/Policy Approver | `UNKNOWN_UNQUERYABLE` |
| iOS App Store Connect record A | `데브짐`, Apple ID `6747574865`, SKU `GYM-IOS-001`, Bundle ID `com.day.bro.gym` | source·actual build·Team 관계, 사용자·IAP·제품 정책 연속성 | Release Manager + Product/Policy Approver | `RECORD_OBSERVED_NOT_SELECTED` |
| iOS App Store Connect record B | `TimeFit (public BroGym)`, Apple ID `6757376637`, SKU `GYM-IOS-002`, Bundle ID `com.leofitTech.devmanager.admin.devManager.v1`; [공개 listing](https://apps.apple.com/us/app/brogym/id6757376637); [ASC distribution](https://appstoreconnect.apple.com/apps/6757376637/distribution) | 두 record 중 최종 대상 선택과 제품·정책 승인 | Owner + Release Manager + Product/Policy Approver | `SOURCE_BUILD_MATCH_OBSERVED_SELECTION_PENDING` |
| iOS version/build | record B 운영 `1.0 (8)` ready for distribution; `1.0.1`은 selected build 없이 preparing; TestFlight `1.0.1 (1784614115)` | 최대 제출 가능 build, 운영 archive checksum·entitlement·provisioning 비교 | Release Manager + Security Approver | `PARTIAL_VERIFIED` |
| Apple Developer Team | actual build Team `729TVX5977`; 접근한 잘못된 Team `JKGX55GPTN`은 권한 없음 | 올바른 Team의 Apple Developer 접근, identifier·entitlement·certificate/profile metadata와 제출 역할 | Owner + Release Manager + Backup Approver | `CORRECT_TEAM_OBSERVED_ACCESS_PENDING` |
| iOS population | TestFlight internal invited `3`, installs `3`, recent sessions `1`; 90일 analytics에 impressions `37`, product page views `3` 등 표시 | App Store 설치·활성 기기·다운로드 정의와 완전한 export, TestFlight 계정과 backend 연결 | Backend Evidence Owner + Release Manager | `NONZERO_TEST_POPULATION_OBSERVED_RECONCILIATION_PENDING` |
| iOS IAP·계약 | IAP 목록 empty 관찰; 유료 앱 계약 만료 warning 확인, 동의하지 않음 | empty 목록이 active/restorable entitlement `0`인지 영수증·계약 권한으로 확인; 계약 영향 검토 | Owner + Product/Policy Approver | `ZERO_NOT_PROVEN_CONTRACT_ACTION_NOT_TAKEN` |
| Existing backend | `public.users` `337`행, `ACTIVE` `315`; auth link 값 `332` 중 쿼리 분류상 정상 `14`, 끊어진 연결 `318`; `auth.users` `40`; 최근 sign-in 30일 `0`, 90일 `10`; admin `0`; 사용자는 bro-gym 미사용, 전원 동의와 기존 사용자 데이터 미이전을 보고 | product decision을 다시 묻지 않고 store record/platform별 installation·사용자·session 기술 매핑, consent evidence 보관 상태, no-transfer·preservation 경계와 provider 원본 export 확인 | Backend Evidence Owner + Product/Policy Approver | `NONZERO_OBSERVED_USER_ATTESTED_NO_TRANSFER_TECHNICAL_MAPPING_PENDING` |
| Firebase·push | backend 조사 범위에서 FCM/device token `0`, push queue `0` 관찰; 제품 의사는 사용자 권한 확보 후 새 알림을 등록·발송하는 방향 | Android/iOS Firebase 앱 등록, APNs topic, FCM project owner, 다른 token 저장소 존재 여부와 store record 관계; 기존 token 미승계와 신규 동의 흐름 승인 | Backend Evidence Owner + Security Approver | `ZERO_AGGREGATES_OBSERVED_PROVIDER_MAPPING_PENDING` |
| Backend subscription·IAP namespace | 일반 membership subscription 집계 `0`; store 전용 IAP 명명 table/column 탐색 결과 `0` | schema 명명 탐색이 아닌 Android/iOS 판매자·영수증 source의 active/restorable entitlement와 미정산 거래 대조 | Backend Evidence Owner + Product/Policy Approver | `ZERO_NAMESPACE_MATCHES_OBSERVED_IAP_NOT_PROVEN` |
| OAuth·Universal/App Links | 운영 mapping 미확정 | callback, URL scheme, Associated Domains, AASA와 도메인 소유권 | Security Approver | `PENDING` |
| Artifact repository | iOS actual build Team 관찰, source/build Bundle ID 일치 후보 | 마지막 Android·iOS 운영 artifact provenance, checksum과 서명·entitlement 전체 비교 | Release Manager + Security Approver | `PARTIAL_VERIFIED` |
| Private audit repository review | `tpghks521`에 write 초대 `338202054`가 생성됐으나 아직 pending이며 실제 permission은 `none` | 초대 대상자의 수락 후 effective permission 재확인; 필요 없으면 Owner가 초대 정책 결정 | Repository Owner + Invited Reviewer | `PENDING_INVITATION_ACCEPTANCE_EFFECTIVE_NONE` |

## 역할과 승인 경계

| 역할 | 책임 | 지정 상태 |
| --- | --- | --- |
| Owner | 두 iOS record 중 대상, 계정·제품 귀속과 migration disposition 승인 | `PENDING_VERIFIED_IDENTITY` |
| Release Manager | store record, version/build, artifact·signing 연속성 검증 | `PENDING_VERIFIED_IDENTITY` |
| Backup Approver | 올바른 Apple Team과 Android 제출·복구 경로의 독립 확인 | `PENDING` |
| Backend Evidence Owner | 동일 기준 시각의 installation·session·push·사용자 연결 집계 | `PENDING` |
| Product/Policy Approver | 기존 사용자 데이터 미이전 제품 결정, 브랜드·metadata·개인정보·지원·계약 영향 승인 | `USER_ATTESTED_NO_DATA_MIGRATION_OTHER_POLICY_REVIEW_PENDING` |
| Security Approver | signing lineage, entitlement, provider mapping 검토 | `PENDING` |

QA source identifier는 evidence 출처이지 위 승인 역할을 자동으로 맡았다는 뜻이 아니다. 최소 두 명의 승인된 담당자가 제출 또는 복구 경로를 가져야 한다.

GitHub 협업 초대 역시 문서 검토 경로일 뿐 Owner, Release Manager, Backup Approver 또는 스토어·백엔드 접근 권한의 증거가 아니다. 이번 감사 준비에서는 초대를 수락하거나 저장소 권한을 변경하지 않았다.

병합된 설계 원문의 `REUSE_DEVGYM_RECORD`는 출시 모드 요구사항이다. 관찰된 두 iOS record 중 정확한 target 선택, 사용자 0명, 서명·제품·정책 연속성이 확인됐다는 증거로 재해석하지 않는다. 현재 nonzero 관찰값과 서로 다른 기준 시각 때문에 `NOT_APPLICABLE_ZERO_VERIFIED` 경로는 충족되지 않았다. 2026-10-18 draft 기준선의 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로도 no-transfer 실행 계획, consent 미검증 표기, IAP·기술·정책 독립 Gate와 승인자가 완료되기 전에는 release Gate를 통과하지 않는다.

## 접근·행위 제한

- 비밀번호, OTP, API key, private key, 인증서 원문, provisioning profile과 서비스 계정 파일을 Git에 기록하지 않는다.
- 올바른 Apple Team 권한이 확인되기 전에는 현재 접근 가능한 다른 Team을 대신 사용하지 않는다.
- 유료 앱 계약 warning은 관찰만 기록하며 동의·갱신하지 않는다.
- IAP 목록 empty를 active subscription, 복원 가능 entitlement 또는 미정산 거래 `0`의 증거로 사용하지 않는다.
- backend의 token·queue·subscription 집계 `0`과 IAP 명명 object 탐색 `0`을 다른 schema, 외부 공급자 또는 store 영수증의 값이 `0`이라는 증거로 확대하지 않는다.
- 사용자 보고 `bro-gym` 미사용을 `337`행 전체의 테스트 사용자 분류, 계정·row·storage 삭제, 서비스 종료, 공급자 project 삭제 또는 유료 구독 해지 승인으로 확대하지 않는다.
- 사용자 전원 동의와 데이터 미이전 보고는 제품 결정으로 사용하되, consent 원본·대상 목록·고지 내용·시각을 제3자 자료로 독립 검증했다는 뜻으로 표현하지 않는다.
- store record, production identity, signing, upload와 사용자 데이터는 이 감사 문서에서 변경하지 않는다.

## REL-001 access 완료 조건

- Android와 iOS 각각 정확한 store target과 소유 계정이 승인되고, 미선택 iOS record가 명시된다.
- Android app-signing/upload lineage와 iOS Team·identifier·entitlement·provisioning이 마지막 운영 artifact와 일치한다.
- Owner, Release Manager, Backup Approver, Backend Evidence Owner와 Product/Policy·Security Approver가 실제 담당자로 확인된다.
- store, backend, push와 구독/IAP evidence를 하나의 통합 `as_of`로 다시 수집·대조한다.
- 접근 불가·증거 누락 항목에는 blocker owner와 recovery action이 연결된다.

완료 전에는 store 선택, production identity, migration 또는 release를 승인하지 않는다.
