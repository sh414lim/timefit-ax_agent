# REL-001 production evidence access matrix

- 티켓: [REL-001 — 기존 DevGym 레코드 정체성·사용자 0명 증거 감사](https://trello.com/c/xFoln3Kq)
- 설계 원문: [145 — 네이티브 앱 저장소·출시 계획](../145-timefit-native-app-repository-migration-plan-2026-10-16.md)의 REL-001 작업 1~13, 산출물과 수용 기준
- 후속 Gate: [146 — 네이티브 채팅 아키텍처](../146-timefit-native-chat-architecture-2026-10-16.md)의 2.4~2.5와 [147 — 실행 티켓 카탈로그](../147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md)의 REL 완료 Gate
- 목적: 확인된 콘솔·빌드 evidence와 아직 필요한 접근을 분리해 기록
- 운영 변경: 없음

```yaml
evidenceStatus: PARTIAL_MULTI_SOURCE_OBSERVED
integratedAsOf: null
githubReviewAccess: PENDING_INVITATION_NOT_EFFECTIVE
storeTargetSelectionApproval: PENDING
technicalContinuityApproval: PENDING
productPolicyApproval: PENDING
legacyUserMigrationApproval: PENDING
releaseApproval: PENDING
```

`integratedAsOf`는 Android, iOS, backend, push와 구독/IAP를 같은 기준 시각과 조회 범위로 다시 확인하기 전에는 채우지 않는다. 이 문서는 record 선택, production identity 적용, 데이터 삭제 또는 출시를 승인하지 않는다.

## Evidence source와 기준 시각

| Evidence ref | Source | 관찰 시각(UTC) | 데이터 기준 시각 | 확인 범위 |
| --- | --- | --- | --- | --- |
| `REL001-ANDROID-CONSOLE-QA-20261017T031417Z` | Google Play Console read-only QA 관찰 | `2026-10-17T03:14:17Z` | 최신 완전 통계 `2026-10-13` | package, release/version, 설치·활성 지표, Play App Signing 상태 |
| `REL001-IOS-ASC-QA-01a147a4-9770` | App Store Connect read-only QA 역할 결과 `cloud 01a147a4-9770` | `2026-10-17T03:23:36Z` | 90일 analytics 최신 `2026-10-15`; TestFlight는 관찰 시점 현재값 | 두 앱 record, version/build, TestFlight 설치·session, actual build Team, 계약·IAP 화면 |
| `REL001-GITHUB-COLLAB-20261017T083211Z` | GitHub API read-only 재조회 | `2026-10-17T08:32:11Z` | 초대 생성 `2026-10-17T08:19:32Z` | `tpghks521` write 초대 `338202054`는 pending·미만료이고 실제 permission은 `none` |

Android와 iOS store evidence의 관찰 시각과 데이터 기준일이 다르므로 하나의 `as_of`로 합치지 않는다. 원본 콘솔 화면·export의 제한 접근 보관 위치와 checksum은 아직 이 문서에 연결되지 않았다.

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
| Existing backend | 아직 이 문서에 연결된 집계 없음 | installation, 최근 접속, 사용자 연결, session, push token을 platform·record별로 집계 | Backend Evidence Owner | `PENDING` |
| Firebase·push | source 후보 외 운영 등록 관계 미확정; 제품 의사는 사용자 권한 확보 후 새 알림을 등록·발송하는 방향 | Android/iOS app 등록, APNs topic, FCM project owner와 활성 token 관계; 기존 token 미승계와 신규 동의 흐름 승인 | Backend Evidence Owner + Security Approver | `PENDING` |
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
| Product/Policy Approver | 테스트 사용자 미이전, 브랜드·metadata·개인정보·지원·계약 영향 승인 | `PENDING` |
| Security Approver | signing lineage, entitlement, provider mapping 검토 | `PENDING` |

QA source identifier는 evidence 출처이지 위 승인 역할을 자동으로 맡았다는 뜻이 아니다. 최소 두 명의 승인된 담당자가 제출 또는 복구 경로를 가져야 한다.

GitHub 협업 초대 역시 문서 검토 경로일 뿐 Owner, Release Manager, Backup Approver 또는 스토어·백엔드 접근 권한의 증거가 아니다. 이번 감사 준비에서는 초대를 수락하거나 저장소 권한을 변경하지 않았다.

병합된 설계 원문의 `REUSE_DEVGYM_RECORD`는 출시 모드 요구사항이다. 관찰된 두 iOS record 중 정확한 target 선택, 사용자 0명, 서명·제품·정책 연속성이 확인됐다는 증거로 재해석하지 않는다. 현재 nonzero 관찰값과 서로 다른 기준 시각 때문에 146/147의 zero-user release Gate는 충족되지 않았다.

## 접근·행위 제한

- 비밀번호, OTP, API key, private key, 인증서 원문, provisioning profile과 서비스 계정 파일을 Git에 기록하지 않는다.
- 올바른 Apple Team 권한이 확인되기 전에는 현재 접근 가능한 다른 Team을 대신 사용하지 않는다.
- 유료 앱 계약 warning은 관찰만 기록하며 동의·갱신하지 않는다.
- IAP 목록 empty를 active subscription, 복원 가능 entitlement 또는 미정산 거래 `0`의 증거로 사용하지 않는다.
- store record, production identity, signing, upload와 사용자 데이터는 이 감사 문서에서 변경하지 않는다.

## REL-001 access 완료 조건

- Android와 iOS 각각 정확한 store target과 소유 계정이 승인되고, 미선택 iOS record가 명시된다.
- Android app-signing/upload lineage와 iOS Team·identifier·entitlement·provisioning이 마지막 운영 artifact와 일치한다.
- Owner, Release Manager, Backup Approver, Backend Evidence Owner와 Product/Policy·Security Approver가 실제 담당자로 확인된다.
- store, backend, push와 구독/IAP evidence를 하나의 통합 `as_of`로 다시 수집·대조한다.
- 접근 불가·증거 누락 항목에는 blocker owner와 recovery action이 연결된다.

완료 전에는 store 선택, production identity, migration 또는 release를 승인하지 않는다.
