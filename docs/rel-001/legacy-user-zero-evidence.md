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
storePopulationEvidence: NONZERO_VERIFIED
legacyUserMigrationDecision: PENDING
migrationDecisionCandidate: REQUIRED
productIntent: TEST_USERS_NO_LEGACY_DATA_MIGRATION
destructiveResetApproval: NOT_GRANTED
destructiveResetStatus: NOT_PLANNED_NOT_EXECUTED
storeTargetSelectionApproval: PENDING
releaseApproval: PENDING
```

Android와 iOS evidence의 관찰 시각과 metric 기준일이 다르므로 통합 `as_of`를 만들지 않는다. 현재 evidence는 zero-user를 증명하지 않으며 `NOT_APPLICABLE_ZERO_VERIFIED`를 사용할 수 없다.

## Evidence source

| Evidence ref | Source | 관찰 시각(UTC) | 데이터 기준 |
| --- | --- | --- | --- |
| `REL001-ANDROID-CONSOLE-QA-20261017T031417Z` | Google Play Console read-only QA 관찰 | `2026-10-17T03:14:17Z` | 최신 완전 통계 `2026-10-13` |
| `REL001-IOS-ASC-QA-01a147a4-9770` | App Store Connect read-only QA 역할 결과 `cloud 01a147a4-9770` | `2026-10-17T03:23:36Z` | analytics 최신 `2026-10-15`; TestFlight는 관찰 시점 현재값 |

콘솔 화면·export 원본, checksum과 제한 접근 보관 위치는 아직 연결되지 않았다. 아래 숫자는 source별 관찰값이며 사람 수, backend 계정 수 또는 삭제 대상 수로 자동 환산하지 않는다.

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
| Backend installation | evidence 미연결 | `PENDING` | record/platform별 installation 총수·활성수 |
| Backend user/session | evidence 미연결 | `PENDING` | 사용자 연결, 최근 접속, 유효 session과 탈퇴·익명 처리 기준 |
| Push token | evidence 미연결 | `PENDING` | platform별 활성·비활성·중복·만료 token 집계 |

IAP 목록 empty나 Payments 조회 불가는 `0`으로 변환하지 않는다.

## 제품 책임자 의사와 실행 경계

제품 책임자의 최신 의사는 “기존 사용자는 테스터이고 legacy 사용자·데이터를 새 앱으로 이전하지 않는다”는 것이다. 이를 다음과 같이 기록한다.

```yaml
populationDisposition:
  assertedType: TEST_ONLY
  assertionAuthority: PRODUCT_OWNER
  targetVerification: PENDING
migrationProposal:
  decisionPath: REQUIRED
  mode: NO_LEGACY_DATA_MIGRATION
  freshLoginRequired: true
  legacyLocalDataHandling: IGNORE_AND_ISOLATE_PENDING_SEPARATE_DECISION
  legacyPushTokenHandling: DO_NOT_IMPORT
  legacyPaymentHandling: PENDING_EVIDENCE
```

새 알림은 사용자 권한을 확보한 뒤 현재 설치에서 새 token을 등록하는 방향이며, legacy push token을 자동 승계한다는 결정이 아니다.

이 의사는 `NOT_APPLICABLE_ZERO_VERIFIED`가 아니며 실제 계정·row·storage object·token 삭제 승인도 아니다. 삭제·비활성화·격리·보존 중 어떤 조치가 필요한지는 정확한 대상, 법적·운영 보존 의무, 복구 가능성과 승인자를 갖춘 별도 실행 결정으로 다룬다.

## Reconciliation 상태

| 검사 | 기대 조건 | 현재 결과 | 남은 항목 |
| --- | --- | --- | --- |
| 통합 기준 시각 | store/backend/push/IAP가 동일 `as_of`·timezone | `INCOMPLETE` | Android·iOS 시각과 기준일이 다르고 backend/IAP 미수집 |
| Android store↔backend | 사용자 `5`, MAU 기기 `1`과 account/installation 관계 설명 | `INCOMPLETE` | backend query와 대상 매핑 |
| iOS record 선택 | 정확히 하나의 기존 store target 승인 | `PENDING` | 두 record의 소유권·정책·사용자 영향 및 승인 |
| iOS store↔backend | TestFlight·analytics와 account/installation 관계 설명 | `INCOMPLETE` | record별 backend·push mapping |
| 구독·IAP | active/restorable entitlement와 미정산 거래 확인 | `INCOMPLETE` | Android 조회 권한, iOS 영수증·계약 evidence |
| 테스트 사용자 disposition | 대상과 no-migration 계획 승인 | `PENDING` | 정확한 대상, opt-out·지원·법무·보안 승인 |

## 판정

- `storePopulationEvidence`는 Android와 iOS에서 모두 nonzero 관찰값이 있어 `NONZERO_VERIFIED`다.
- 따라서 `legacyUserMigrationDecision`을 `NOT_APPLICABLE_ZERO_VERIFIED`로 승인할 수 없다.
- 원문 enum의 최종 결정은 아직 `PENDING`이다. 승인 검토 대상 경로는 `REQUIRED`이며, 테스트 사용자에 대한 승인된 no-migration·fresh-login·legacy isolation 계획을 부속 결정으로 둔다.
- 최종 `REQUIRED` 승인 전에는 대상 사용자·데이터, 고객지원, opt-out, 개인정보·법무 영향과 복구 계획을 확인한다.
- migration이 승인돼도 store update 연속성, 실제 기존 build 위 update smoke와 clean-install smoke는 생략하지 않는다.

## REL-001 완료 전에 남은 증거

- 두 iOS record 중 정확히 하나의 target 선택과 제품·정책 승인
- 올바른 Apple Team `729TVX5977`의 접근 역할, identifier·entitlement·signing continuity 확인
- Android upload credential 소유와 app-signing lineage, 마지막 운영 artifact checksum
- 동일 `as_of`의 Android/iOS store, backend installation·session·push와 구독/IAP 재조회
- 테스트 사용자 대상 검증과 승인된 `REQUIRED` no-migration 계획
- Owner, Release Manager, Backup Approver, Backend Evidence Owner, Product/Policy·Security 승인자와 승인 시각

위 항목이 완료되기 전에는 사용자 데이터 삭제, production identity 입력, store upload, release promotion 또는 REL-003 Go 판정을 실행하지 않는다.
