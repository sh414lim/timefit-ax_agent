# REL-001 legacy population and migration evidence

- 티켓: [REL-001 — 기존 DevGym 레코드 정체성·사용자 0명 증거 감사](https://trello.com/c/xFoln3Kq)
- 설계 원문: [145 — 네이티브 앱 저장소·출시 계획](../145-timefit-native-app-repository-migration-plan-2026-10-16.md)의 REL-001 작업 5~8과 수용 기준
- 후속 Gate: [146 — 네이티브 채팅 아키텍처](../146-timefit-native-chat-architecture-2026-10-16.md)의 2.5와 [147 — 실행 티켓 카탈로그](../147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md)의 zero-user Gate
- 목적: zero-user 주장을 검증하고 nonzero evidence가 있으면 보수적인 migration 경로를 유지

```yaml
evidenceStatus: PARTIAL_MULTI_SOURCE_OBSERVED
integratedAsOf: null
androidObservedAt: 2026-10-17T03:14:17Z
androidMetricAsOf: 2026-10-13
iosObservedAt: 2026-10-17T03:23:36Z
iosAnalyticsLatestDate: 2026-10-15
backendObservedAt: 2026-10-17T08:38:09.492Z
backendPopulationEvidence: NONZERO_AGGREGATES_OBSERVED_SCOPE_UNMAPPED
backendEvidencePackageStatus: LOCAL_TRANSCRIPTION_CHECKSUM_VERIFIED_PROVIDER_EXPORT_NOT_ACQUIRED
broGymCurrentUsageReport: USER_ATTESTED_NOT_IN_USE
broGymUsageReportObservedAt: 2026-10-17T09:45:49Z
existingUserConsentStatus: USER_ATTESTED_ALL_EXISTING_USERS
consentArtifactVerification: NOT_INDEPENDENTLY_VERIFIED
backend337TechnicalClassification: OBSERVED_SCOPE_UNMAPPED
backend337MigrationDisposition: PRESERVE_NO_TRANSFER_NO_DELETE
storePopulationEvidence: NONZERO_VERIFIED
legacyUserMigrationDecision: REQUIRED
legacyUserDataTransferDecision: USER_ATTESTED_DO_NOT_MIGRATE
productIntent: USER_ATTESTED_NO_LEGACY_DATA_MIGRATION
destructiveResetApproval: NOT_GRANTED
destructiveResetStatus: NOT_PLANNED_NOT_EXECUTED
storeTargetSelectionApproval: PENDING
releaseApproval: PENDING
```

Android, iOS와 backend evidence의 관찰 시각·metric 기준일·조회 범위가 다르므로 통합 `as_of`를 만들지 않는다. 현재 evidence는 zero-user를 증명하지 않으며 `NOT_APPLICABLE_ZERO_VERIFIED`를 사용할 수 없다.

## Evidence source

| Evidence ref | Source | 관찰 시각(UTC) | 데이터 기준 |
| --- | --- | --- | --- |
| `REL001-ANDROID-CONSOLE-QA-20261017T031417Z` | Google Play Console read-only QA 관찰 | `2026-10-17T03:14:17Z` | 최신 완전 통계 `2026-10-13` |
| `REL001-IOS-ASC-QA-01a147a4-9770` | App Store Connect read-only QA 역할 결과 `cloud 01a147a4-9770` | `2026-10-17T03:23:36Z` | analytics 최신 `2026-10-15`; TestFlight는 관찰 시점 현재값 |
| `REL001-BACKEND-AGGREGATES-20261017T083809492Z` | Supabase `bro-gym` project ref `nzxgcfwranspxynzyglb` aggregate-only SQL | `2026-10-17T08:38:09.492Z` | 10초 timeout, read-only transaction, `ROLLBACK`; 쿼리 실행 시점 현재 집계 |
| `REL001-PRODUCT-MIGRATION-DECISION-20261017T094549Z` | 사용자 직접 보고 | `2026-10-17T09:45:49Z` | bro-gym 미사용, 기존 사용자 전원 동의, 기존 사용자 데이터 미이전으로 진행; consent 원본 독립 검증·삭제·서비스 해지 승인은 아님 |

콘솔 화면·provider 원본 export는 아직 연결되지 않았다. 제한 접근 local transcription package의 aggregate SHA-256은 `332b40a1c5c75f4542918dc7eda184a415f5095a139648cd136bf23d461e1f57`, execution log SHA-256은 `95230cd44e49b26f6f5f3123d2aefbe365f022c4bbc9e09f4e49c121aec786ea`로 확인했다. package는 저장소에 복사하지 않았고 로컬 절대경로를 기록하지 않는다. dashboard 원본 CSV/JSON, 서버 audit log, 공급자 서명·timestamp 실행 영수증과 screenshot은 확보되지 않았으므로 전사본을 provider 원본 export로 취급하지 않는다. 아래 숫자는 source별 관찰값이며 사람 수, backend 계정 수 또는 삭제 대상 수로 자동 환산하지 않는다. backend 조회는 raw 개인 행·token을 읽지 않았고 운영 변경 없이 `ROLLBACK`됐으며, service의 `restricted/unhealthy` banner가 표시된 상태에서도 제한된 집계 쿼리는 성공했다.

## 확인된 store population

| 플랫폼·record | 지표 | 확인값 | 해석 | 상태 |
| --- | --- | --- | --- | --- |
| Android `데브짐-매니저` | 설치한 사용자 | `5` | Play Console 집계값; 실제 사람·backend 계정과 동일시하지 않음 | `VERIFIED_NONZERO` |
| Android `데브짐-매니저` | 최근 28일 MAU | 활성 기기 `1` | 기기 기반 지표; 사용자 identity와 연결되지 않음 | `VERIFIED_NONZERO` |
| iOS `TimeFit (public BroGym)` | TestFlight internal invited | `3` | 내부 테스터 초대 수 | `VERIFIED_NONZERO_TEST_POPULATION` |
| iOS `TimeFit (public BroGym)` | TestFlight installs | `3` | TestFlight 설치 수 | `VERIFIED_NONZERO_TEST_POPULATION` |
| iOS `TimeFit (public BroGym)` | TestFlight recent sessions | `1` | 관찰 시점 TestFlight session 지표 | `VERIFIED_NONZERO_TEST_POPULATION` |
| iOS `TimeFit (public BroGym)` | 90일 analytics | impressions `37`, product page views `3`; downloads 등은 완전한 판정에 불충분 | analytics 최신일 `2026-10-15`; 설치·활성 사용자 0의 증거가 아님 | `PARTIAL_NONZERO_ZERO_NOT_PROVEN` |
| iOS `데브짐` | 설치·활성·TestFlight | 확인값 미연결 | 두 record 중 대상 선택 전 별도 조회 필요 | `PENDING` |

두 iOS record는 다음과 같이 관찰됐다.

- `데브짐`: Apple ID `6747574865`, SKU `GYM-IOS-001`, Bundle ID `com.day.bro.gym`
- `TimeFit (public BroGym)`: Apple ID `6757376637`, SKU `GYM-IOS-002`, Bundle ID `com.leofitTech.devmanager.admin.devManager.v1`

후자는 `dev_manager` source 및 actual build와 Bundle ID가 일치하며 actual build Team은 `729TVX5977`이다. 이 일치는 기술 evidence 일부일 뿐 최종 store target 선택이나 제품·정책 승인이 아니다.

## 구독·IAP와 backend evidence

| 영역 | 현재 관찰 | 판정 | 필요한 후속 evidence |
| --- | --- | --- | --- |
| Android Payments | Payments 계정 미설정으로 조회 불가 | `UNKNOWN_UNQUERYABLE` | 활성 구독, IAP, entitlement, 미정산 거래 조회 |
| iOS IAP | IAP 목록 empty | `ZERO_NOT_PROVEN` | 영수증·계약 범위의 active/restorable entitlement와 거래 조회 |
| iOS 계약 | 유료 앱 계약 만료 warning 관찰; 동의·갱신하지 않음 | `CONTRACT_REVIEW_REQUIRED` | 제품·정책·재무 책임자 영향 검토 |
| Backend `public.users` | 총 `337`행, `ACTIVE` `315` | `NONZERO_AGGREGATES_OBSERVED_SCOPE_UNMAPPED` | 제품 결정을 다시 열지 않고 no-transfer·preservation 구현에 필요한 store/platform·record 역할 매핑 확인 |
| Backend auth linkage | auth link 값 `332`; 쿼리 분류상 정상 `14`, 끊어진 연결 `318` | `PARTIAL_LINKAGE_AGGREGATES_OBSERVED` | 분류 SQL·정의·export checksum과 broken link 처리 책임자 확인 |
| Backend `auth.users`·session | `auth.users` `40`; 최근 sign-in 30일 `0`, 90일 `10`; admin `0` | `NONZERO_AUTH_AGGREGATES_OBSERVED_SCOPE_UNMAPPED` | 유효 session, store record·platform 연결과 탈퇴·익명 처리 기준 |
| Push token·queue | FCM/device token `0`, push queue `0` | `ZERO_AGGREGATES_OBSERVED_PROVIDER_MAPPING_PENDING` | Firebase/APNs 공급자와 다른 token 저장소, platform·record별 활성·비활성·중복·만료 token 대조 |
| 일반 membership subscription | 집계 `0` | `ZERO_AGGREGATE_OBSERVED_SCOPE_LIMITED` | store 구독·entitlement와의 의미·연결 확인 |
| Store 전용 IAP schema 탐색 | IAP 명명 table/column 검색 결과 `0` | `ZERO_NAMESPACE_MATCHES_OBSERVED_IAP_NOT_PROVEN` | 판매자 콘솔·영수증 source에서 active/restorable entitlement와 미정산 거래 조회 |

IAP 목록 empty, Payments 조회 불가, 일반 subscription 집계 `0` 또는 IAP 명명 object 탐색 `0`을 store 구독·복원 가능 entitlement·거래 `0`으로 변환하지 않는다.

## 제품 책임자 의사와 실행 경계

사용자의 최신 보고는 bro-gym을 더 이상 사용하지 않고, 기존 사용자 전원이 동의했으며, 기존 사용자 데이터를 새 앱으로 이전하지 않고 진행한다는 것이다. 제품 결정은 `USER_ATTESTED`로 확정하며 같은 범위를 다시 질문하지 않는다. 다만 `337`개 `public.users` record의 기술적 의미, consent 원본·대상 목록·고지 내용의 독립 검증, 데이터 삭제, 서비스 종료 또는 공급자 구독 해지 승인은 별개다. 이를 다음과 같이 기록한다.

```yaml
populationDisposition:
  assertedType: TEST_ONLY
  assertionAuthority: USER_ATTESTED
  existingUserConsent: USER_ATTESTED_ALL_EXISTING_USERS
  consentArtifactVerification: NOT_INDEPENDENTLY_VERIFIED
  technicalRecordClassification: OBSERVED_SCOPE_UNMAPPED
migrationProposal:
  decisionPath: REQUIRED
  mode: USER_ATTESTED_NO_LEGACY_DATA_MIGRATION
  productDecision: CONFIRMED_DO_NOT_MIGRATE_EXISTING_USER_DATA
  freshLoginRequired: true
  legacyLocalDataHandling: DO_NOT_IMPORT_PRESERVE_SOURCE_PENDING_RETENTION_PLAN
  legacyPushTokenHandling: DO_NOT_IMPORT
  legacyPaymentHandling: PENDING_EVIDENCE
testOnlyNoMigrationDraft:
  status: DRAFT_PENDING_TECHNICAL_REVIEW_AND_RELEASE_APPROVAL
  appliesTo: ALL_EXISTING_BRO_GYM_USER_DATA_PER_USER_ATTESTATION
  unclassifiedBackendRows: PRESERVE_NO_TRANSFER_NO_DELETE_PENDING_TECHNICAL_INVENTORY
  authentication: FRESH_TIMEFIT_LOGIN_NO_LEGACY_SESSION_REUSE
  localData: DO_NOT_IMPORT_LEGACY_DB_KEYCHAIN_KEYSTORE_CACHE
  push: DO_NOT_IMPORT_LEGACY_TOKENS_REQUIRE_NEW_PERMISSION_AND_REGISTRATION
  payments: BLOCK_UNTIL_STORE_RECEIPT_AND_ENTITLEMENT_EVIDENCE
  backendData: PRESERVE_NO_DELETE_NO_BULK_DISABLE
  serviceState: NO_PROJECT_SHUTDOWN_OR_SUBSCRIPTION_CANCELLATION
  userSupport: IDENTIFY_AFFECTED_TESTERS_AND_DEFINE_RECOVERY_CONTACT
  releaseGate: REQUIRE_APPROVED_SCOPE_AND_UPDATE_PLUS_CLEAN_INSTALL_SMOKE
```

새 알림은 사용자 권한을 확보한 뒤 현재 설치에서 새 token을 등록하는 방향이며, legacy push token을 자동 승계한다는 결정이 아니다.

이 결정은 `NOT_APPLICABLE_ZERO_VERIFIED`가 아니라 nonzero evidence를 전제로 한 `REQUIRED` 처리 경로다. 실제 계정·row·storage object·token 삭제, Supabase project 종료 또는 유료 구독 해지 승인도 아니다. `337`행 범위에 대해 같은 제품 결정을 다시 묻지 않고, Backend Evidence Owner는 안전한 no-transfer·preservation 구현과 감사 추적에 필요한 schema 의미 및 store/platform 매핑만 비식별 evidence로 좁힌다. 삭제·비활성화·격리·보존 중 어떤 실행 조치가 필요한지는 정확한 대상, 법적·운영 보존 의무, 복구 가능성과 별도 승인을 갖춘 후속 결정으로 다룬다.

## Reconciliation 상태

| 검사 | 기대 조건 | 현재 결과 | 남은 항목 |
| --- | --- | --- | --- |
| 통합 기준 시각 | store/backend/push/IAP가 동일 `as_of`·timezone | `INCOMPLETE` | Android·iOS·backend 시각과 기준일이 다르고 store IAP evidence 미수집 |
| Backend population 범위 | `337`행·`40` auth 계정과 legacy app 사용자·테스터·직원 범위 설명 | `PRODUCT_DECISION_SET_TECHNICAL_MAPPING_INCOMPLETE` | 미사용·전원 동의·데이터 미이전은 `USER_ATTESTED`; no-transfer·preservation 구현과 감사에 필요한 비식별 schema·store/platform mapping은 미완료 |
| Android store↔backend | 사용자 `5`, MAU 기기 `1`과 account/installation 관계 설명 | `INCOMPLETE` | backend aggregate는 있으나 Android record/platform 대상 매핑 없음 |
| iOS record 선택 | 정확히 하나의 기존 store target 승인 | `PENDING` | 두 record의 소유권·정책·사용자 영향 및 승인 |
| iOS store↔backend | TestFlight·analytics와 account/installation 관계 설명 | `INCOMPLETE` | backend aggregate는 있으나 record별 backend·push mapping 없음 |
| 구독·IAP | active/restorable entitlement와 미정산 거래 확인 | `INCOMPLETE` | Android 조회 권한, iOS 영수증·계약 evidence |
| 기존 사용자 disposition | 데이터 미이전 제품 결정과 실행 계획 | `PRODUCT_DECISION_USER_ATTESTED_PLAN_REVIEW_PENDING` | 전원 동의는 `USER_ATTESTED`; consent 원본 미검증 상태, 지원·개인정보·법무·보존·복구 계획 검토 |

## 판정

- `storePopulationEvidence`는 Android와 iOS에서 모두 nonzero 관찰값이 있어 `NONZERO_VERIFIED`다.
- 따라서 `legacyUserMigrationDecision`은 `NOT_APPLICABLE_ZERO_VERIFIED`가 아니라 `REQUIRED`다.
- `REQUIRED` 경로 안에서 기존 사용자 데이터를 이전하지 않는 제품 결정과 기존 사용자 전원 동의는 `USER_ATTESTED`다. consent 원본을 독립 검증했다는 뜻은 아니다.
- 실행 계획 승인 전에는 no-transfer 대상 inventory, 고객지원, 개인정보·법무·보존 영향과 복구 계획을 확인한다. 이 검토는 제품 결정을 다시 묻는 절차가 아니다.
- migration이 승인돼도 store update 연속성, 실제 기존 build 위 update smoke와 clean-install smoke는 생략하지 않는다.

## 설계 기준선 변경 제안

상태: `PROPOSED_NOT_APPLIED`

현재 145/146/147 기준선은 동일 `as_of`에서 store·backend·push·IAP가 모두 0일 때만 데이터 이전 생략을 허용한다. 실제 evidence는 nonzero이고 사용자는 전원 동의와 기존 사용자 데이터 미이전을 확정했으므로, 다음 최소 변경을 별도 설계 변경으로 검토한다.

1. zero-only `NOT_APPLICABLE_ZERO_VERIFIED` 경로는 그대로 유지하되, 별도로 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로를 허용한다.
2. 이 경로는 legacy 데이터를 TimeFit으로 이전하지 않고 원본을 보존·격리하며, fresh login과 신규 push 동의·등록을 사용한다. 삭제·service shutdown·구독 해지는 포함하지 않는다.
3. consent 원본 미검증, no-transfer inventory·보존·지원·복구 계획, store/platform 기술 매핑은 release evidence로 남긴다.
4. 정확한 store target, Android/iOS signing·entitlement·상향 version/build, 실제 기존 build 위 update smoke와 clean-install smoke는 계속 release Gate로 유지한다.
5. REL-001은 위 release evidence가 완료될 때까지 열린 상태로 둔다. 다만 146의 개발·staging 병렬 개발 원칙에 따라 비운영 기능 개발 준비를 production signing·store 제출 증거와 혼합하지 않는다. 147의 전역 Blocked 문구를 바꾸려면 별도 승인된 기준선 개정이 필요하며 이 문서만으로 구현을 자동 착수하지 않는다.

## REL-001 완료 전에 남은 증거

- 두 iOS record 중 정확히 하나의 target 선택과 제품·정책 승인
- 올바른 Apple Team `729TVX5977`의 접근 역할, identifier·entitlement·signing continuity 확인
- Android upload credential 소유와 app-signing lineage, 마지막 운영 artifact checksum
- 동일 `as_of`의 Android/iOS store, backend installation·session·push와 구독/IAP 재조회
- provider 원본 store/backend export 또는 동등한 서명된 evidence; 현재 local transcription package의 checksum과 한계를 유지
- backend `337`행과 auth linkage 집계의 schema 의미·store/platform 매핑을 no-transfer·preservation 감사에 필요한 범위로 비식별 evidence화
- `USER_ATTESTED` consent의 원본 미검증 상태를 명시한 `REQUIRED` no-migration 실행 계획 검토·승인
- Owner, Release Manager, Backup Approver, Backend Evidence Owner, Product/Policy·Security 승인자와 승인 시각

위 항목이 완료되기 전에는 사용자 데이터 삭제, production identity 입력, store upload, release promotion 또는 REL-003 Go 판정을 실행하지 않는다.
