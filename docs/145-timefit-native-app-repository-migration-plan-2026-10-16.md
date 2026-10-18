# TimeFit Flutter 네이티브 앱 별도 저장소·병렬 개발 및 출시 계획

- 문서 번호: `145`
- 작성일: 2026-10-16
- 상태: 실행 기준선(Baseline)
- 기준선 개정: 2026-10-18 — REL-001 비식별 관측과 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로, public visibility, production signing 출시 전 유예 결정 반영(검토 중)
- 대상: 제품, Flutter, 백엔드, QA, Release Engineering, 보안, 고객지원
- 결정 범위: Flutter iOS/Android 앱의 별도 저장소·모바일 웹과의 병렬 운영·공유 백엔드 계약·기존 DevGym 스토어 레코드 업데이트 출시

> **최종 결정**
> Flutter iOS/Android 앱은 기존 웹·백엔드와 분리된 public **`sh414lim/timefit-ax_agent`** 저장소(계획 문서 별칭 `timefit-mobile`)에서 개발한다. 사용자는 추적된 내부 문서와 기존 Git 이력이 인터넷에 공개될 수 있음을 확인하고 public 전환을 승인했으며, Release 세션은 2026-10-18T04:27:38Z에 실제 visibility와 익명 read를 확인했다. 현재 **`time_fit`** 저장소는 계속 개발·배포되는 모바일 웹앱과 Supabase 데이터베이스, RLS, RPC, Edge Functions, Realtime, Storage, 알림 발송을 포함한 **공유 백엔드의 유일한 원본(canonical source)** 으로 유지한다. 모바일 웹과 Flutter 앱은 서로를 대체하지 않고 같은 제품·계정·데이터를 사용하는 독립 클라이언트로 병렬 운영한다. Flutter 앱의 PWA 구현은 본 계획 범위 밖이지만 기존 모바일 웹/PWA 트랙의 개발·배포를 중단하거나 종료하지 않는다. 네이티브 출시는 Android **`데브짐-매니저`**, iOS **`데브짐`** 의 **기존 배포 레코드를 업데이트하는 경로로 확정**한다. 별도 Git 저장소 사용 여부와 스토어 업데이트 가능 여부는 독립적이며, 기존 application ID/Bundle ID·서명 계보·스토어 레코드·상향 version/build를 보존하면 `timefit-ax_agent`에서 만든 바이너리도 같은 레코드에 제출할 수 있다. REL-001에서 Android 설치 사용자 `5`, 최근 28일 활성 기기 `1`, iOS TestFlight 비영(非零) 지표, backend `public.users` `337`행과 `auth.users` `40`계정을 서로 다른 기준 시각으로 관측했으므로 사용자 0명으로 간주하지 않는다. `legacyUserMigrationDecision=REQUIRED`를 유지하되, 사용자가 기존 사용자 전원 동의와 기존 사용자 데이터 미이전을 확정한 결정은 `legacyUserDataTransferDecision=USER_ATTESTED_DO_NOT_MIGRATE`로 별도 기록한다. 이는 consent 원본 검증, 데이터 삭제, 서비스 종료, 구독 해지 또는 출시 승인이 아니다. AI/AX 기능은 본 계획에서 제외한다.

> **Production signing 유예 결정 — 2026-10-18**
> 사용자는 앱 서명 확인·설정·서명 연속성 및 실제 signed update 검증을 앱 출시 준비 시점으로 유예하고, 그 밖의 작업을 진행하기로 결정했다. 이 상태는 `SIGNING_DEFERRED_TO_RELEASE_GATE`이며 완료·면제·기술 `GO`·배포 승인이 아니다. production identity/signing 주입, signed artifact promotion, TestFlight·스토어 업로드와 기존 설치본 위 signed update smoke는 REL-003·REL-011·REL-013·REL-017의 출시 전 필수 Gate로 남긴다. secret 없는 dev/staging·no-codesign 빌드, 앱 구조·테스트·계약 구현은 별도 개발 착수 Gate로 분리할 수 있지만, IAP/결제, 사용자·데이터 처리, 실제 콘솔 권한, 제품·정책 승인과 저장소 거버넌스 조건은 이 결정으로 제거하지 않는다.

---

## 1. 목적과 성공 상태

이 계획의 목적은 현재 모바일 웹앱의 개발·배포를 유지하면서 Flutter 네이티브 앱을 별도 저장소에서 독립적으로 개발·출시하고, 두 클라이언트가 공유 백엔드와 사용자 데이터를 안전하게 병렬 사용하도록 만드는 것이다.

성공 상태는 다음과 같다.

1. `timefit-mobile`에서 재현 가능한 iOS Archive/IPA와 Android AAB/APK를 만든다.
2. 현재 모바일 웹앱은 기존 트랙에서 중단 없이 계속 개발·배포된다.
3. 모바일 웹과 Flutter가 동일 사용자·조직·권한·업무 데이터의 공유 백엔드를 데이터 손상 없이 병렬 사용한다.
4. Android는 `데브짐-매니저`, iOS는 `데브짐`의 정확한 기존 레코드를 사용하며 release mode를 `REUSE_DEVGYM_RECORD`로 고정한다. 기술·제품·스토어 정책 Gate가 통과하지 않으면 새 레코드로 자동 전환하지 않고 출시를 중단한다.
5. 기존 application ID/Bundle ID·서명 계보·스토어 레코드·entitlement·상향 version/build 연속성을 보존하고, TimeFit으로 바뀐 기능·브랜드·개인정보 metadata를 투명하게 심사한다.
6. 웹과 네이티브의 인증 세션·로컬 저장소·배포 일정은 독립시키되 사용자 UUID와 서버 권한 의미는 일치시킨다.
7. 한 클라이언트의 장애·출시 중단·Kill Switch가 다른 클라이언트의 정상 기능을 불필요하게 중단하지 않는다.

### 1.1 명시적 비범위

다음 항목은 이번 Flutter 네이티브 앱 계획에 포함하지 않는다.

- Flutter 저장소에서의 PWA 설치, Service Worker, Web App Manifest, 브라우저 캐시, Web Push, PWA 오프라인 셸 구현
- 기존 모바일 웹/PWA의 기능 개발·배포·유지보수·종료 결정(기존 웹 트랙에서 별도로 계속 관리)
- 기존 PWA 화면을 Flutter WebView로 감싸는 방식이나 Capacitor 전환
- AI 추천, 생성형 AI, LLM 분석, AI 요약, AI 챗봇
- AX 서비스, 접근성 자동화/에이전트 실험, `services/timefit-ax` 연동
- 태블릿 출퇴근 앱을 새 모바일 앱의 코드베이스로 병합하는 작업
- 기존 운영 데이터의 별도 백엔드 복제 또는 신규 Supabase 프로젝트 이전
- 기존 DevGym 레코드와 별개인 신규 스토어 상품·Bundle ID·Android package/application ID를 생성하는 작업
- 기존 저장소 안의 모바일 웹/PWA·AI·AX 코드를 Flutter 작업 명목으로 삭제하거나 재설계하는 작업

접근성 자체는 앱 품질의 기본 요건으로 유지한다. 여기서 제외하는 “AX”는 별도 AX 서비스·에이전트 기능 범위를 뜻하며, 스크린리더 라벨, 동적 글자 크기, 색 대비, 키보드 탐색 같은 기본 접근성 품질을 제외한다는 뜻이 아니다.

---

## 2. 현재 저장소와 제품 정보에서 확인한 근거

### 2.1 확인된 사실

| 근거 | 확인 내용 | 이 계획에 미치는 영향 |
| --- | --- | --- |
| `tablet_app/android/app/build.gradle.kts:9` | Android namespace가 `com.example.timefit_tablet` | 운영 모바일 앱 식별자로 사용할 수 없는 예시/태블릿 식별자다. |
| `tablet_app/android/app/build.gradle.kts:24` | Android `applicationId`가 `com.example.timefit_tablet` | 실제 운영 Android package name의 근거가 아니다. |
| `tablet_app/android/app/build.gradle.kts:35-37` | `release` 빌드가 `signingConfigs.getByName("debug")` 사용 | 해당 설정으로 운영 업데이트를 만들거나 스토어에 제출하면 안 된다. |
| `tablet_app/ios/Runner.xcodeproj/project.pbxproj:371,550,572` | iOS Runner Bundle ID가 `com.example.timefitTablet` | 실제 운영 iOS Bundle ID의 근거가 아니다. |
| `docs/12-appstore-onestore-release-plan.md:49,70` | `com.timefit.app`을 iOS/Android 계획값으로 기재하면서 “최종 확정 전”이라고 명시 | 문서상 후보일 뿐 실제 스토어 정체성으로 확정할 수 없다. |
| `README.md:37-39` | Supabase 스키마·RLS·Edge Function·운영 백엔드 문서를 현재 저장소가 안내 | `time_fit`을 모바일 웹과 공유 백엔드의 원본으로 유지하는 근거다. |
| `supabase/config.toml` 및 `supabase/migrations/` | Auth, DB, Realtime, Storage, migration 구성이 현재 저장소에 존재 | 모바일 저장소로 서버 스키마와 migration을 복제하지 않는다. |
| `docs/144-admin-mobile-app-replan-2026-10-15.md:10,253` | 기존 문서가 모바일 웹/PWA 트랙의 계획과 검증을 정의 | 그 웹 트랙은 계속 유효하다. 본 문서는 별도 Flutter 네이티브 트랙만 추가하며 기존 웹 계획을 대체하지 않는다. |
| `services/timefit-ax/`, AI 관련 migration | 저장소에 AX/AI 관련 자산이 존재 | 존재 여부와 무관하게 본 릴리스 범위에서는 참조·연동·확장하지 않는다. |
| 제품 책임자 제공 정보 | Android 운영 네이티브 앱은 `데브짐-매니저`, iOS 운영 네이티브 앱은 `데브짐`이며 TimeFit과 기능이 완전히 다름 | 두 기존 record의 재사용은 확정했으며, 기술 연속성과 제품·정책·심사 준비가 모두 충족돼야 제출한다. |
| REL-001 비식별 관측 | Android 설치 사용자 `5`, 최근 28일 활성 기기 `1`; iOS TestFlight 비영 지표; backend `public.users` `337`행, `auth.users` `40`계정 | 서로 다른 기준 시각·범위의 관측이며 동일 사람 수나 삭제 대상을 뜻하지 않는다. zero-user는 증명되지 않았고 `legacyUserMigrationDecision=REQUIRED`다. |
| 사용자 확정 제품 결정 | 기존 사용자 전원 동의, 기존 사용자 데이터 미이전 | `USER_ATTESTED` 결정으로 기록한다. consent 원본·대상·고지 내용은 독립 검증되지 않았고, 원본 데이터는 별도 승인 없이 삭제·변경하지 않는다. |

### 2.2 아직 확인되지 않은 사실

저장소만으로는 다음 값을 확정할 수 없다.

- DevGym iOS/Android 레코드의 정확한 Apple ID/PID/AID, Bundle ID/application ID, 소유 Team/계정, 현재 version/build
- DevGym 레코드의 app-signing/upload 권한과 실제 업데이트 기술 연속성
- DevGym 활성 설치·기기, 백엔드 installation/push token, 활성 구독/IAP가 실제로 모두 0인지와 조회 기준 시점·범위
- DevGym 리뷰·개인정보 고지·브랜드 계약 및 TimeFit 전환이 스토어 심사·정책상 허용되는지
- 실제 설치 바이너리의 앱 서명 인증서 SHA-256 및 서명 계보
- 운영 APNs/FCM 앱 등록, Associated Domains, App Links, OAuth callback
- 기존 앱이 사용하는 Keychain/Keystore/local database 키와 세션 형식
- DevGym 마지막 운영 바이너리와 연결되는 정확한 source commit

따라서 `com.timefit.app`, `com.example.timefit_tablet`, `com.example.timefitTablet` 중 어느 것도 추측으로 production 값에 복사하지 않는다. DevGym 재사용의 기술 값은 **스토어 콘솔과 마지막 운영 바이너리의 교차 검증 결과만** 원본으로 인정하지만, 값이 일치한다는 사실만으로 TimeFit 전환 제출을 승인하지 않는다. REL-003에서 승인된 `REUSE_DEVGYM_RECORD` identity manifest만 production 원본으로 인정한다. 현재 배포 중인 모바일 웹앱의 도메인, PWA manifest ID, 웹 배포 이력은 네이티브 스토어 정체성의 증거가 아니다.

### 2.3 현재 `tablet_app`에 대한 판정

현재 `tablet_app`은 이 계획의 Flutter 모바일 앱 시작점이나 운영 서명 기준이 아니다. 참고 가능한 업무 흐름이나 공통 Dart 코드가 발견되더라도 다음 절차 없이 가져오지 않는다.

1. 라이선스·소유권 확인
2. 태블릿 전용 가정 제거 여부 검토
3. 모바일 도메인 계약과 보안 검토
4. 테스트를 포함한 선택적 코드 이식

`tablet_app`의 package/Bundle ID와 debug signing 설정은 복사 금지 항목이다.

---

## 3. 핵심 아키텍처·배포 결정

### 3.1 ADR 요약

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| Flutter 소스 저장소 | public 독립 `sh414lim/timefit-ax_agent`; 익명 read 확인 | visibility와 무관하게 네이티브 수명주기, 서명, Flutter CI/CD를 웹·서버 배포와 분리한다. |
| 모바일 웹·백엔드 저장소 | 기존 `time_fit` 유지 | 모바일 웹을 계속 개발·배포하고 DB/RLS/RPC/Edge Function 이력과 배포 체인을 단일 원본으로 유지한다. |
| 클라이언트 관계 | 모바일 웹과 Flutter 병렬 운영 | 어느 한쪽도 다른 쪽의 대체·종료 조건이 아니다. 같은 계정·데이터를 독립 UI와 릴리스 주기로 사용한다. |
| 스토어 배포 | Android `데브짐-매니저`, iOS `데브짐` 기존 record 재사용 확정 | 새 저장소에서 빌드하되 기존 ID·서명·version 연속성을 지키고 제품·정책·metadata Gate를 통과한다. |
| 앱 기술 | Flutter iOS/Android | PWA/WebView 재사용이 아닌 네이티브 앱 클라이언트로 구현한다. |
| 데이터 원본 | 기존 Supabase/서버 | 별도 모바일 DB나 신규 Auth 프로젝트를 만들지 않는다. |
| 모바일 웹/PWA | 기존 트랙에서 지속 | Flutter 티켓의 구현 산출물에는 포함하지 않지만 공유 계약 회귀 테스트 대상에는 포함한다. |
| AI/AX | 제외 | 릴리스 범위와 데이터 처리 범위를 제한한다. |
| 태블릿 앱 | 독립 유지 | 현재 placeholder ID/debug signing 구성과 새 운영 모바일 앱을 혼동하지 않는다. |

### 3.2 저장소 선택 의사결정 매트릭스

점수는 1(불리)~5(유리)이며, 가중치는 병렬 개발의 우선순위다.

| 평가 항목 | 가중치 | `time_fit` 안에 Flutter 추가 | 새 `timefit-mobile` | 판정 |
| --- | ---: | ---: | ---: | --- |
| 서명·스토어 권한 격리 | 5 | 2 | 5 | 새 저장소 |
| 모바일 CI/CD 독립성 | 5 | 2 | 5 | 새 저장소 |
| 백엔드 migration 단일 원본 | 5 | 5 | 5 | 어느 쪽도 가능하나 서버는 `time_fit` 유지 |
| 릴리스 cadence 독립성 | 4 | 2 | 5 | 새 저장소 |
| 코드 소유권·리뷰 경계 | 4 | 2 | 5 | 새 저장소 |
| 초기 설정 비용 | 2 | 4 | 2 | 단일 저장소가 유리하지만 영향이 작음 |
| 계약 변경 동기화 | 4 | 4 | 3 | 계약 자동 검증으로 보완 |
| 가중 합계 |  | 77 | **119** | **`timefit-mobile` 채택** |

### 3.3 플랫폼별 확정 스토어 경로와 차단 조건

REL-001은 iOS와 Android를 각각 감사하되 릴리스 경로를 다시 선택하지 않는다. 경로는 다음과 같이 확정돼 있다.

| 플랫폼 | 확정 릴리스 경로 | 제출 전 필수 Gate | 실패 시 처리 |
| --- | --- | --- | --- |
| Android | 기존 `데브짐-매니저` record의 `REUSE_DEVGYM_RECORD` | 정확한 application ID·app-signing lineage·upload 권한·최대 versionCode·record 소유권·metadata 전환 승인 | `BLOCKED_PENDING_RECOVERY`; 신규 record로 자동 우회하지 않음 |
| iOS | 기존 `데브짐` App Store Connect record의 `REUSE_DEVGYM_RECORD` | 정확한 Bundle ID·Apple ID·Team·entitlement·상향 version/build·metadata 전환 승인 | `BLOCKED_PENDING_RECOVERY`; 신규 record로 자동 우회하지 않음 |

새 Git 저장소와 스토어 경로는 별개다. `timefit-mobile`은 새 저장소를 사용하지만, production build에는 위 기존 record의 정확한 identity와 서명만 주입한다. 같은 ID·서명 계보·더 높은 version/build를 지키면 새 저장소에서 만든 바이너리도 기존 record의 업데이트가 된다. 모바일 웹의 배포 상태는 이 결정을 바꾸지 않는다.

### 3.4 기존 record 재사용 원칙

- 기존 ID·서명·entitlement·version 연속성을 훼손하면 release blocker다.
- 제품·법무·개인정보·스토어 정책과 metadata 전환 승인도 반드시 필요하다. 제품이 다르다는 사실을 숨기거나 단순 UI 개편으로 축소 설명하지 않는다.
- legacy 처리 경로는 둘뿐이다. 동일 `as_of` 증거가 모두 0이면 `NOT_APPLICABLE_ZERO_VERIFIED`; 하나라도 비영이거나 조회 불능이면 `REQUIRED`다. `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`가 승인되면 legacy 데이터·session·local DB·push token·IAP를 TimeFit으로 가져오지 않고 원본을 보존하며 fresh login, 새 local namespace, 신규 push 동의·등록을 사용한다. 두 경로 모두 출시 전 스토어 업데이트 설치·서명·version 검증을 생략하지 않지만, 이 출시 Gate는 production identity를 사용하지 않는 비서명 개발 작업의 착수를 막지 않는다.
- 허용된 store target/ID를 manifest와 CI allowlist에 기록하고 신규 record·새 production ID 생성을 차단한다.
- 모바일 웹은 계속 운영되며 Flutter 출시의 롤백·종료 대상이 아니다.

---

## 4. 기존 DevGym 스토어 정체성 재사용 요구사항

### 4.1 감사 및 원본 우선순위

각 플랫폼의 확정된 DevGym 레코드 정체성을 다음 우선순위로 확인한다.

1. 현재 판매 중인 스토어 콘솔의 앱/상품 레코드
2. 해당 스토어에서 내려받은 마지막 운영 바이너리의 서명·manifest
3. 스토어 배포 이력 및 CI의 검증 가능한 release artifact
4. 마지막 운영 release tag의 설정
5. 기획 문서와 현재 작업공간의 예시 설정

1~3이 일치하지 않으면 해당 플랫폼을 `BLOCKED_PENDING_RECOVERY`로 두고 콘솔 소유자와 Release Engineering이 원인을 해소한다. 이 문서의 승인 범위에서 신규 record를 만들거나 새 production ID로 우회하지 않는다. 경로를 바꾸려면 제품 책임자의 별도 decision record와 본 기준선 개정이 필요하다.

### 4.2 iOS 경로별 요구사항

확정된 `REUSE_DEVGYM_RECORD` 경로에서 다음 기술 연속성 요구사항을 모두 지킨다.

| 분류 | 업데이트 경로 요구사항 | 검증 방법 |
| --- | --- | --- |
| 스토어 레코드 | 같은 App Store Connect 앱 레코드와 Apple ID를 사용 | 콘솔 URL/Apple ID와 기존 버전 이력 캡처 |
| Bundle ID | 마지막 운영 앱과 문자 단위로 같은 Bundle ID | 콘솔, archive의 `Info.plist`, 서명 entitlement 3자 대조 |
| 소유 계정 | 현재 앱 레코드를 소유한 Apple Developer Team에서 제출 | Team ID, App Store Connect 역할, provisioning 결과 확인 |
| 서명 | 현재 소유 Team의 유효한 배포 자격 증명과 profile 사용 | archive validation 및 TestFlight 처리 성공 |
| 버전 | 새 marketing version을 만들고 build number를 기존 업로드보다 증가 | App Store Connect build history와 CI 비교 |
| App ID capability | Push, Associated Domains, Keychain Sharing, App Groups, Sign in with Apple 등 기존 사용 capability 보존 | 기존 binary entitlement와 신규 archive 비교 |
| Keychain | 기존 세션을 읽어야 한다면 application identifier prefix와 keychain access group 호환성 확인 | 실제 스토어 설치→업데이트 테스트 |
| APNs | 기존 push topic(Bundle ID)과 운영 APNs 환경 유지 | device token 등록 및 운영 샌드박스 분리 테스트 |
| Universal Links | 기존 도메인과 `apple-app-site-association`의 appID 매핑 유지 | 설치/미설치·로그인/로그아웃 링크 테스트 |
| OAuth | 등록된 URL scheme·redirect URI·Sign in with Apple 설정 유지 | 공급자 콘솔과 callback E2E |
| App Groups/iCloud | 기존 앱이 사용했다면 container ID와 entitlement 보존 | capability inventory와 데이터 접근 회귀 테스트 |

iOS에서 “같은 인증서 파일” 자체가 영구 식별자인 것은 아니다. 배포 인증서는 갱신할 수 있다. 핵심은 **같은 App Store Connect 레코드와 Bundle ID**, 현재 소유 Team의 유효한 서명, 그리고 데이터·기능 연속성에 필요한 entitlement다. 앱 이전(App Transfer)이 실제로 있었던 경우 Team prefix, Keychain, APNs, Sign in with Apple 영향은 별도 점검 없이는 안전하다고 보지 않는다.

신규 Bundle ID 또는 App Store Connect record는 만들지 않는다. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로에서는 기존 Keychain/session 데이터를 읽거나 옮기지 않고 최초 TimeFit 로그인을 제공한다. 어느 경로든 기존 앱→신규 Flutter archive의 앱 삭제 없는 업데이트 설치와 entitlement 연속성은 반드시 검증한다.

### 4.3 Android 경로별 요구사항

확정된 `REUSE_DEVGYM_RECORD` 경로에서 다음 기술 연속성 요구사항을 모두 지킨다.

| 분류 | 업데이트 경로 요구사항 | 검증 방법 |
| --- | --- | --- |
| 스토어 상품 | 기존 Android 스토어의 같은 상품/PID/AID 또는 Play app record 사용 | 콘솔 상품 이력과 현재 판매 URL 확인 |
| package/application ID | 마지막 운영 앱과 정확히 같은 `applicationId`/package name | 콘솔, AAB/APK manifest, 설치 앱 3자 대조 |
| app signing | 설치된 앱이 수락하는 같은 app-signing certificate 또는 공식적으로 지원되는 signing lineage | 기존 배포 APK와 신규 최종 배포 APK의 SHA-256/lineage 검증 |
| upload key | 해당 스토어가 등록한 upload key로 업로드 | 콘솔 certificate와 업로드 사전 검증 |
| versionCode | 스토어의 현재 최대값보다 큰 정수 | 모든 active/retained track 및 ONE store binary 이력 조회 |
| versionName | 제품 릴리스 버전 정책과 일치 | release manifest와 스토어 metadata 비교 |
| binary 형식 | 기존 스토어의 APK/AAB 전환 상태와 정책 준수 | 콘솔 상품 설정 확인; AAB 전환의 비가역성 검토 |
| Firebase | 실제 운영 package와 signing fingerprint가 등록된 기존 Firebase app 사용 | Firebase 앱 등록과 FCM 실기기 테스트 |
| App Links | 기존 host/path와 `assetlinks.json`에 실제 배포 app-signing SHA-256 유지 | 스토어 설치본으로 verified link 확인 |
| OAuth | 기존 scheme/redirect와 SHA fingerprint 의존 설정 유지 | 공급자 콘솔과 callback E2E |
| IAP/라이선스 | 기존 상품 ID, license/billing 연결 유지 | 테스트 구매·복원 및 서버 영수증 검증 |

Android의 upload key와 사용자의 기기에 설치되는 app-signing key를 혼동하면 안 된다. 관리형 앱 서명을 쓰는 스토어에서는 둘이 다를 수 있다. 여러 Android 스토어에서 같은 앱을 배포한다면 설치 출처별 최종 signing certificate와 교차 업데이트 정책을 REL-001에서 확정한다.

신규 application ID 또는 스토어 record는 만들지 않는다. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로에서는 기존 Keystore/session/push 데이터를 읽거나 옮기지 않는다. 어느 경로든 기존 배포 APK/AAB→신규 Flutter artifact의 앱 삭제 없는 업데이트 설치, signing lineage와 versionCode 증가는 반드시 검증한다. 모바일 웹/PWA의 manifest ID나 브라우저 설치 이력은 Android package 연속성으로 취급하지 않는다.

### 4.4 DevGym 레코드 재사용의 제품·정책 연속성 요구사항

재사용 경로는 확정됐지만, 실제 candidate 제출 전에는 아래 항목이 모두 승인돼야 한다.

| 검토 항목 | 필수 판단 | 승인/증거 |
| --- | --- | --- |
| 제품 정체성 | DevGym과 TimeFit의 핵심 기능·대상 사용자가 완전히 다르다는 사실을 전제로 record 전환이 허용되는가 | 제품 책임자 decision record |
| 기존 사용자 | 실제 활성 사용자·설치가 0인지, 0이 아니라면 자동 업데이트 후 기능 소멸·계정 차이·데이터 접근·재로그인·지원 경로를 어떻게 처리할지 | 같은 기준 시점의 스토어 활성 설치/기기 export + 백엔드 installation/token 조회; 0이면 `NOT_APPLICABLE_ZERO_VERIFIED`, 비영이면 승인된 `REQUIRED` 계획. 현재 제품 결정은 `USER_ATTESTED_DO_NOT_MIGRATE`이며 원본 보존·fresh login·지원 계획 검토가 필요 |
| 스토어 심사 | 이름·아이콘·카테고리·기능·개인정보 목적의 대폭 변경을 해당 record에서 제출해도 되는가 | 최신 공식 정책 검토 및 필요 시 스토어 사전 문의 evidence |
| 개인정보·약관 | DevGym 동의·고지와 TimeFit 수집·처리 목적의 차이가 해소되는가 | 법무/개인정보 책임자 승인 |
| 구독·결제 | 활성 IAP/구독·미정산 거래·entitlement가 실제 0인지, 0이 아니라면 어떻게 보호·종료·이관하는가 | App Store Connect/Android 판매자 콘솔과 서버 영수증 DB export; 모두 0이면 `NOT_APPLICABLE_ZERO_VERIFIED`, 비영·조회 불능이면 `REQUIRED` 계획에서 보호·지원·복구 책임을 승인. `USER_ATTESTED_DO_NOT_MIGRATE`만으로 결제 상태를 0 또는 종료로 간주하지 않음 |
| 브랜드·지원 | 기존 리뷰·평점·지원 채널을 TimeFit이 승계하는 것이 사용자 오인을 만들지 않는가 | 브랜드·고객지원 승인 |
| 데이터 | DevGym 로컬/서버 데이터를 TimeFit 사용자 데이터로 오인·자동 연결하지 않는가 | 데이터 매핑 `NONE` 기본, 명시적 migration 근거 |

한 항목이라도 `NO_GO`, 미확인, 승인 만료이면 DevGym record에 Flutter candidate를 제출하지 않는다. 신규 record로 자동 fallback하지 않으며 `BLOCKED_PENDING_RECOVERY` 상태로 원인을 해소하거나 제품 책임자가 별도 의사결정으로 기준선을 변경해야 한다.

### 4.5 플랫폼 공통 병렬 운영 원칙

- 같은 운영 Supabase/Auth 프로젝트와 사용자 UUID를 사용한다.
- 기존 조직, 역할, RLS, RPC 의미를 클라이언트 편의 때문에 바꾸지 않는다.
- 웹과 Flutter의 installation ID, push token, 세션, 로컬 DB namespace를 분리하고 서버에서는 사용자 ID·조직·`client_type`을 함께 검증한다.
- 지원 중인 모바일 웹 또는 네이티브 클라이언트가 사용하는 API/RPC를 사용량·소유자·deprecation 승인 없이 제거하지 않는다.
- 웹 URL, Universal/App Links, custom scheme, OAuth callback의 namespace와 소유권을 명시해 서로 가로채지 않게 한다.
- 고객지원 URL, 개인정보처리방침, 계정 삭제 경로는 두 클라이언트 모두에서 일관되게 접근 가능해야 한다.
- 기존 record 업데이트이므로 모든 제출에서 현재 최대값보다 높은 version/build를 확인한다.
- 웹 배포와 네이티브 배포는 서로 독립적으로 실행·중단할 수 있어야 한다.

### 4.6 Production Identity Manifest

REL-001은 다음 필드를 갖는 identity manifest를 초기화하고 REL-003이 고정된 reuse 경로의 승인 상태를 최종 확정한다. 이 문서에는 실제 값이나 비밀을 쓰지 않는다.

```yaml
schemaVersion: 1
ios:
  nativeRecordStatus: existing
  releaseMode: REUSE_DEVGYM_RECORD
  submissionStatus: PENDING|GO|BLOCKED_PENDING_RECOVERY
  technicalContinuityDecision: PENDING|GO|NO_GO
  productPolicyContinuityDecision: PENDING|GO|NO_GO
  selectedStoreRecordApproved: true|false
  appleIdRecorded: true|false
  bundleIdVerified: true|false
  owningTeamVerified: true|false
  latestStoreVersionRecorded: true|false
  latestBuildRecorded: true|false
  entitlementsCompared: true|false
android:
  nativeRecordStatus: existing
  releaseMode: REUSE_DEVGYM_RECORD
  submissionStatus: PENDING|GO|BLOCKED_PENDING_RECOVERY
  technicalContinuityDecision: PENDING|GO|NO_GO
  productPolicyContinuityDecision: PENDING|GO|NO_GO
  selectedStoreRecordsApproved: true|false
  packageNameVerified: true|false
  maxVersionCodeRecorded: true|false
  appSigningCertificateCompared: true|false
  uploadCredentialAccessVerified: true|false
  binaryFormatVerified: true|false
shared:
  observedLegacyPopulationStatus: NONZERO_PARTIAL_MULTI_SOURCE
  activeStoreInstallEvidenceAsOfRecorded: true|false
  backendActiveInstallationCountVerifiedZero: true|false
  activeSubscriptionAndIapVerifiedZero: true|false
  legacyUserMigrationDecision: PENDING|NOT_APPLICABLE_ZERO_VERIFIED|REQUIRED
  legacyUserDataTransferDecision: PENDING|USER_ATTESTED_DO_NOT_MIGRATE|APPROVED_MIGRATION
  existingUserConsentStatus: UNKNOWN|USER_ATTESTED_ALL_EXISTING_USERS|INDEPENDENTLY_VERIFIED
  consentArtifactVerification: NOT_ACQUIRED|NOT_INDEPENDENTLY_VERIFIED|VERIFIED
  authProjectVerified: true|false
  mobileWebContinuesIndependently: true|false
  sharedContractOwnerRecorded: true|false
  namespaceCollisionReviewComplete: true|false
  deepLinksInventoried: true|false
  pushProvidersVerified: true|false
  priorNativeArtifactArchivedIfApplicable: true|false
```

실제 키, 인증서 private material, provisioning profile 원문, keystore, 비밀번호, API key, APNs key, Firebase service account, refresh/access token은 Git·티켓·문서·로그에 넣지 않는다. 공개 인증서의 SHA-256도 접근 제한된 release evidence에만 기록하고, 이 계획서에는 값 자체를 남기지 않는다.

### 4.7 개발 착수 Gate와 production signing 출시 Gate 분리

`SIGNING_DEFERRED_TO_RELEASE_GATE`는 signing 관련 작업의 시점만 바꾼다.

- **개발 착수 가능 범위:** production identity·signing credential·provider production 설정을 사용하지 않는 dev/staging 코드, no-codesign 빌드, 정적 분석·unit/widget/architecture test, 공개 fixture와 계약 검증.
- **signing 유예 범위:** certificate/profile/upload key 생성·연결·교체, signing lineage 판정, signed artifact promotion, TestFlight·스토어 업로드, 기존 store build 위 signed update smoke.
- **계속 진행할 비서명 정체성 작업:** store record·application ID·Bundle ID·version/build·소유권의 read-only inventory와 비밀이 아닌 manifest 필드 검토. 이를 production project에 주입하거나 승인된 최종 manifest로 표시하지 않는다.
- **별도 미완료 조건:** IAP/결제·entitlement evidence, legacy population과 실제 데이터 처리 승인, 실제 콘솔·provider 권한, 제품·법무·스토어 정책, branch protection·독립 review와 owner 지정은 signing 유예로 충족되거나 면제되지 않는다.
- 비서명 구현 PR의 준비·검토는 진행할 수 있지만, 관련 REL 티켓을 완료로 이동하거나 release status를 `GO`로 바꾸는 근거로 사용하지 않는다.

---

## 5. 저장소 경계와 소유권

### 5.1 목표 구조

```text
timefit-ax_agent/                # public 독립 Flutter repository
  lib/                           # Flutter UI, domain, data adapters
  ios/                           # iOS project, non-secret capabilities/config
  android/                       # Android project, flavors, non-secret config
  test/ integration_test/        # unit/widget/integration/upgrade tests
  contracts/                     # 소비하는 계약 snapshot/generated client
  release/                       # metadata source, checklists, runbooks
  .github/ or ci/                # build/test/release pipeline

time_fit/                        # 기존 모바일 웹 + canonical shared backend repository
  app/ pages/ web/               # 실제 구조에 맞춘 모바일 웹 UI와 웹 배포 자산
  supabase/migrations/           # DB schema, RLS, functions, triggers
  supabase/functions/            # Edge Functions
  server/ pages/api/ backend/    # 기존 서버/API 계층
  contracts/                     # API/event schema의 원본
  docs/                          # 웹·서버·제품·운영 의사결정

tablet_app/                      # 기존 저장소 안의 독립 태블릿 클라이언트
  ...                            # 이번 모바일 앱의 ID/signing 원본 아님
```

### 5.2 경계 표

| 자산/책임 | 원본 저장소 | 규칙 |
| --- | --- | --- |
| Flutter 화면, 상태 관리, 라우팅 | `timefit-mobile` | 웹/PWA 코드를 런타임 의존성으로 두지 않는다. |
| iOS/Android 프로젝트와 flavor | `timefit-mobile` | production ID는 REL-001 산출물에서 주입·검증한다. |
| 모바일 unit/widget/integration test | `timefit-mobile` | PR과 release gate에서 실행한다. |
| 모바일 CI/CD와 스토어 metadata source | `timefit-mobile` | 비밀은 CI secret manager에서만 주입한다. |
| DB schema, RLS, trigger, RPC | `time_fit` | 모바일 저장소에 SQL 원본을 복제하지 않는다. |
| Edge Functions, push dispatcher | `time_fit` | 서버 권한과 idempotency를 강제한다. |
| 모바일 웹 UI·PWA·웹 배포 | `time_fit`의 기존 웹 트랙 | Flutter 일정과 독립적으로 계속 개발·배포한다. |
| API/event schema 원본 | `time_fit` | versioned artifact를 생성해 모바일이 소비한다. |
| 생성된 API client/model | `timefit-mobile` | 원본 schema 버전과 checksum을 기록한다. |
| 운영 dashboard/alert 정의 | 기본 `time_fit`, 앱 심볼 업로드는 `timefit-mobile` | 양쪽 release ID로 연결한다. |
| PWA | `time_fit`의 기존 웹 트랙 | Flutter 구현 범위에서는 제외하되 운영 중인 계약 consumer로 회귀 검증한다. |
| AI/AX | 기존 위치 유지 | 이번 계획의 변경·의존·출시 범위에서 제외한다. |

### 5.3 교차 저장소 변경 규칙

1. 계약 변경은 `time_fit`에서 먼저 additive하게 정의하고 모바일 웹 회귀 검증 후 staging에 배포한다.
2. 계약 artifact에는 semantic version, commit SHA, 생성 시각, 호환 범위를 기록한다.
3. `timefit-mobile` PR은 소비하는 계약 버전을 명시하고 contract test를 통과한다.
4. 서버의 destructive change는 모바일 웹을 포함한 지원 중인 모든 contract consumer의 사용량이 0이고 각 소유자가 승인한 후 별도 릴리스로 수행한다.
5. 하나의 티켓에 양쪽 저장소의 구현을 숨기지 않는다. 필요하면 서버 하위 작업과 모바일 하위 작업을 분리하고 동일 REL ID로 연결한다.
6. 모바일 저장소는 service role key, DB migration 권한, 운영 DB 직접 접속 권한을 갖지 않는다.
7. 백엔드는 `applicationId`, 앱 버전 같은 클라이언트 주장만으로 인증·권한을 부여하지 않는다.
8. 모바일 웹과 Flutter는 독립 release train을 사용한다. 한쪽 배포 성공을 다른 쪽 배포의 전제나 완료 증거로 간주하지 않는다.
9. 공유 계약 PR에는 `affected_clients`, `minimum_supported_contract`, `web_regression_evidence`, `native_contract_evidence`, rollout owner를 기록한다.

### 5.4 브랜치·태그·릴리스 규칙

- 모바일 기본 브랜치는 보호하고 PR 승인과 필수 검사를 강제한다.
- production 릴리스 태그 예시는 `mobile-vX.Y.Z+BUILD`로 하되 실제 규칙은 REL-002 ADR에서 확정한다.
- 백엔드 호환 릴리스는 연결된 migration/function 배포 ID를 모바일 release manifest에 기록한다.
- 기존 iOS `데브짐`·Android `데브짐-매니저`의 마지막 운영 artifact와 확보 가능한 source tag/checksum을 보존하고, 최초 TimeFit Flutter release artifact부터 같은 보존 정책을 이어간다.
- 태그에 서명 비밀, 토큰, provisioning profile, keystore를 포함하지 않는다.

---

## 6. 보안·비밀·개인정보 원칙

- 저장소에는 `.env` 운영값, keystore, `.p12`, private key, provisioning profile, APNs key, 서비스 계정 JSON, 토큰, 비밀번호를 커밋하지 않는다.
- secret manager에는 최소 권한과 승인자 분리를 적용하고, CI가 필요한 시점에만 단기적으로 주입한다.
- 로그에는 메시지 본문, 급여·근태 원문, access/refresh token, signed URL, push token 전체값을 남기지 않는다.
- 사용자·조직 식별자는 진단 목적에 필요한 경우 pseudonymous ID로 처리하고 보존 기간을 둔다.
- 앱의 production flavor는 debug endpoint, debug signing, test account 자동 로그인, 우회 feature flag를 포함하면 실패한다.
- AI/AX SDK, 데이터 전송, 모델 endpoint, 관련 권한은 dependency allowlist와 binary scan으로 차단한다.

---

## 7. R0~R3 실행 로드맵

| 단계 | 목표 | 티켓 | 종료 게이트 |
| --- | --- | --- | --- |
| R0 — 정체성·경계 확정 | 기존 DevGym record의 identity·사용자 0명 증거를 감사하고 별도 저장소·웹 병렬 운영 기준선을 고정 | REL-001~REL-004 | `REUSE_DEVGYM_RECORD` 기술/정책 Gate 승인, 저장소/namespace/환경 소유권 확정, 웹 회귀·update 설치 기준선 재현 |
| R1 — 공유 계약·클라이언트 격리 | 모바일 웹과 Flutter가 같은 서버를 안전하게 사용하도록 계약·세션·로컬 상태·푸시·링크를 분리 | REL-005~REL-010 | staging 다중 클라이언트 통과, client-scoped Kill Switch 훈련, idempotency·namespace 격리 증명 |
| R2 — 기존 record 배포 기반·검증 | 기존 record 전용 서명 CI, 스토어 자료, clean-install과 upgrade E2E, 관측성을 완성 | REL-011~REL-014 | 기존 record 테스트 트랙 업로드 성공, 모바일 웹 회귀 0건, release blocker 0건 |
| R3 — 네이티브 단계 출시·안정화 | 네이티브 코호트를 확대하고 웹과 독립적으로 장애 대응한 뒤 임시 호환 계층만 정리 | REL-015~REL-018 | 네이티브 100% 배포·관찰 완료, 웹 정상 운영, 임시 경로 정리 승인·감사 자료 보존 |

R0의 **비서명 개발 착수 판정**과 R0 티켓의 **완료·릴리스 판정**은 동일하지 않다. 4.7의 개발 착수 Gate를 만족하면 dev/staging 범위의 PR을 준비할 수 있지만, R0 종료 게이트와 REL-001/003/004 완료에는 유예된 signing·signed update evidence를 포함한 원래 수용 기준이 그대로 적용된다.

### 7.1 단계 의존 관계

```text
REL-001 → REL-002 → REL-003 → REL-004
              │          │          │
              └──────────┴──────────┼→ REL-005 → REL-006
                                    ├→ REL-007 → REL-008
                                    ├→ REL-009
                                    └→ REL-010

REL-001 + REL-005~010 → REL-011 → REL-012 → REL-013 → REL-014
REL-014 → REL-015 → REL-016 → REL-017 → REL-018
```

REL-016은 순서상 R3에 있지만 runbook과 client-scoped Kill Switch는 REL-015 시작 전에 완성·훈련해야 한다. REL-017은 REL-003에서 승인된 기존 `REUSE_DEVGYM_RECORD` target을 다시 잠그고 신규 record 제출을 차단하는 최종 change-control 게이트다.

---

## 8. 티켓 공통 정의

- **완료**는 코드 merge가 아니라 산출물, 자동 검사, 실기기 또는 콘솔 증거, 승인까지 갖춘 상태다.
- **증거**는 민감값을 가린 로그, checksum, 테스트 결과, 콘솔 상태 캡처, 승인 기록으로 구성한다.
- 모든 증거에는 실행 일시, 환경, 앱 version/build, mobile commit, backend commit을 기록한다.
- “금지 작업”을 해야만 진행할 수 있다면 티켓을 완료 처리하지 않고 release blocker로 에스컬레이션한다.
- 실제 운영 계정이나 고객 데이터로 파괴적 테스트를 하지 않는다.

---

## 9. 상세 실행 티켓

## REL-001 — 기존 DevGym 레코드 정체성·사용자 0명 증거 감사

**목표**

현재 모바일 웹 배포와 분리해 Android `데브짐-매니저`, iOS `데브짐` 레코드의 제품 귀속·서명 연속성을 확인하고, 기존 사용자·설치·구독/IAP가 0이라는 주장을 콘솔과 백엔드 증거로 검증한다. release mode는 두 플랫폼 모두 `REUSE_DEVGYM_RECORD`로 고정하고 REL-003에서 제출 가능 여부만 승인한다.

서명 연속성 확인은 `SIGNING_DEFERRED_TO_RELEASE_GATE`로 남아 REL-001 완료와 출시 전 판단에는 필요하지만, production identity를 사용하지 않는 비서명 dev/staging 구현 착수의 선행조건으로 사용하지 않는다.

**적용 저장소/시스템**

- 문서·감사 산출물: `time_fit`
- 조회 대상: App Store Connect, Apple Developer, 실제 Android 스토어 콘솔, Firebase/푸시 공급자, OAuth 공급자, 기존 CI artifact 저장소
- 코드 변경: 없음

**선행 조건**

- 스토어 콘솔 read access
- 기존 네이티브 record가 있는 경우 마지막 운영 IPA/App Store 설치본, Android AAB/APK/스토어 설치본
- 기존 릴리스 담당자와 계정 소유자 지정

**작업**

1. 제품명 검색만으로 판단하지 않고 법인/팀 소유 App Store Connect 계정에서 iOS `데브짐`, 실제 Android 배포 콘솔에서 `데브짐-매니저`의 정확한 record URL·내부 ID·소유 계정을 확정한다.
2. 모바일 웹 URL, PWA manifest ID, 홈 화면 설치 아이콘과 네이티브 store record를 명시적으로 구분한다.
3. iOS record가 있으면 Apple ID, Bundle ID, version/build, 소유 Team, 제출 역할을 대조하고 마지막 archive/설치본의 identifier, Keychain/App Group, Associated Domains, APNs entitlement와 비교한다.
4. Android record가 있으면 상품/PID/AID, package name, 최대 versionCode, APK/AAB 상태를 조사하고 최종 배포 artifact의 app-signing certificate 및 upload credential 관계를 확인한다.
5. 동일한 `as_of` 시각과 조회 범위를 사용해 각 스토어의 현재 설치/활성 기기/최근 30·90일 활성 지표를 export하고, 지표 정의와 timezone을 함께 기록한다.
6. 기존 백엔드에서 DevGym installation, 최근 접속, push token, 사용자 연결을 조회하고 스토어 지표와 reconciliation한다. 접근할 기존 백엔드가 없다면 그 사실과 소유자 확인을 증거화한다.
7. App Store Connect·Android 판매자 콘솔·영수증 서버에서 활성 구독, 미정산 거래, 복원 가능한 entitlement, 판매 중 IAP가 0인지 확인한다.
8. 사용자/설치/구독 중 하나라도 0이 아니거나 조회 불능이면 `legacyUserMigrationDecision: REQUIRED` 또는 `PENDING`으로 두고 세션·로컬 데이터·푸시·결제 영향 분석을 생략하지 않는다. 모두 0일 때만 `NOT_APPLICABLE_ZERO_VERIFIED`로 승인한다. `REQUIRED`에서 데이터 미이전을 결정한 경우에는 `legacyUserDataTransferDecision: USER_ATTESTED_DO_NOT_MIGRATE`를 별도 기록하고 원본 보존·no-transfer inventory·fresh login·신규 push 동의·지원·복구 계획을 승인 대상으로 둔다.
9. DevGym record의 평점·리뷰, 개인정보 신고, 브랜드/계약, 지원 채널, 기능 설명과 TimeFit 전환 시 영향 목록을 만든다.
10. App Store/Android 스토어의 사전 문의 또는 공식 검토가 필요한 항목과 담당자를 기록한다. 추측 답변을 승인 증거로 쓰지 않는다.
11. Firebase 앱 등록, APNs, FCM project, OAuth callback, Universal/App Links, 웹 도메인 소유권을 inventory로 만들고 웹 전용/DevGym 전용/TimeFit용으로 전환할 항목/공유를 표시한다.
12. DevGym source commit, provenance, checksum을 연결하고 확보 불가 항목은 blocker와 소유자를 기록한다.
13. 기술 연속성, 사용자 0명, 제품·정책 연속성 증거를 별도 묶음으로 만들고 접근 권한을 Owner, Release Manager, Backup Approver로 나눈다.

**산출물**

- `production-app-identity.yaml` 또는 동등한 제한 접근 artifact
- `production-access-matrix.md`
- `native-record-audit.md`
- 기존 native artifact가 있는 경우 checksum 목록과 서명 비교 보고서
- 기술 연속성 audit evidence와 제품·정책 영향 assessment
- `legacy-user-zero-evidence.md`와 redacted 콘솔/backend export

**수용 기준**

- iOS/Android 각각 DevGym record의 실제 운영 식별자, 최대 version/build, app-signing 연속성과 upload 가능 여부가 증명된다.
- 기술적으로 update가 가능하다는 결론과 제품·정책상 재사용 가능하다는 결론이 혼합되지 않는다.
- DevGym 활성 사용자/설치·backend installation/push token·활성 구독/IAP가 같은 기준 시점으로 검증되고 migration decision이 `PENDING`, `REQUIRED`, `NOT_APPLICABLE_ZERO_VERIFIED` 중 하나로 기록된다.
- 사용자 0명이 증명된 경우에만 세션·로컬 데이터·푸시·결제 migration 구현을 `NOT_APPLICABLE_ZERO_VERIFIED`로 처리한다. 비영 관측에서는 `REQUIRED`를 유지하며, 승인된 `USER_ATTESTED_DO_NOT_MIGRATE` 계획이 있으면 legacy 데이터를 읽거나 이전하지 않는 fresh-login 경로를 구현한다. 어느 경로든 스토어 update 설치 시험은 그대로 유지한다.
- DevGym 스토어 metadata·개인정보·브랜드 영향이 문서화된다.
- 모바일 웹 배포가 어느 플랫폼의 기존 네이티브 record로 오분류되지 않는다.
- 현재 저장소의 `com.example.*` 및 계획값 `com.timefit.app`을 운영값으로 오인하지 않는다.
- 최소 2명의 승인된 담당자가 릴리스 수행 또는 복구 경로를 가진다.

**검증/증거**

- 검색한 스토어 계정/record와 제품 귀속의 redacted 조사표
- 업데이트 경로는 콘솔 값과 바이너리 추출값의 redacted 비교표 및 서명 검증 로그
- DevGym 제품·정책 영향표와 스토어 사전 검토 요청/응답(있는 경우)
- 기준 시각·조회 범위·지표 정의가 포함된 스토어 설치/활성 기기 export, backend installation/token count, 구독/IAP export와 reconciliation 결과
- 권한 확인 일시·담당자·콘솔 역할 기록

**금지 작업**

- 추측한 ID를 production Flutter 프로젝트에 먼저 입력
- private key, 비밀번호, token, service account를 문서나 Git에 저장
- 감사 중 사실 확인을 위해 임시 앱 레코드 생성
- 제품 책임자의 구두 진술만으로 legacy migration을 `NOT_APPLICABLE` 처리
- 모바일 웹/PWA 배포를 네이티브 앱 배포로 간주
- 현재 `tablet_app` debug key를 운영키로 사용

**롤아웃/롤백**

- 배포 작업이 아닌 감사 티켓이다.
- 기술 또는 제품·정책 증거가 불충분하면 해당 플랫폼을 `BLOCKED_PENDING_RECOVERY`로 만들고 현재 모바일 웹과 백엔드에는 변경을 가하지 않는다. 사용자 0명만 미증명인 경우에는 migration을 `REQUIRED`로 보수적으로 취급한다.

---

## REL-002 — 저장소 분리 ADR과 `timefit-mobile` 부트스트랩

**목표**

독립 Flutter 저장소와 계속 운영되는 모바일 웹·canonical backend의 책임 경계를 실행 가능한 규칙으로 확정한다.

**적용 저장소/시스템**

- public 독립 `sh414lim/timefit-ax_agent`(계획 별칭 `timefit-mobile`)
- 기존 `time_fit`의 ADR/계약 문서
- Git hosting, CI, code ownership

**선행 조건**

- REL-001의 identity 필드 구조 승인
- 저장소 생성 권한과 모바일/백엔드 코드 소유자 지정

**작업**

1. `timefit-ax_agent`의 승인된 public visibility 전환을 확인하고 기본 브랜치 보호, required review, secret scanning의 실제 지원·설정 상태를 각각 검증한다. 공개 전환 자체를 보호 기능 활성화로 간주하지 않는다.
2. Flutter iOS/Android 최소 프로젝트, dev/staging/production flavor 구조, test 디렉터리를 만든다.
3. production ID는 하드코딩하지 않고 REL-001에서 검증한 기존 DevGym identity manifest를 CI에서 적용·검증한다.
4. `time_fit`이 모바일 웹 UI와 DB/RLS/RPC/Edge Functions/Realtime/Storage/push dispatcher의 원본임을 ADR에 기록한다.
5. 모바일 웹 배포 pipeline과 Flutter pipeline이 서로 독립적으로 실행·중지·롤백되도록 owner와 environment 권한을 분리한다.
6. API/event contract의 publish-consume 방식을 정하고 웹 producer/consumer test와 Flutter consumer test를 양쪽 CI에 연결한다.
7. PWA, Capacitor, WebView, AI/AX dependency를 Flutter allowlist 밖으로 두되 웹 트랙 자체는 수정·중단하지 않는다.
8. 기존 네이티브 소스가 별도라면 감사용 immutable tag/archive와 update fixture에 필요한 최소 자산을 보존한다. 모바일 웹 저장소나 웹 신규 기능 개발을 동결하지 않는다.
9. 티켓 템플릿에 `Repository`, `Affected clients`, `Contract version`, `Backend deploy prerequisite`, `Evidence`를 필수 필드로 추가한다.

**산출물**

- 저장소 경계 ADR
- `timefit-mobile` 기본 구조와 CODEOWNERS
- CI skeleton 및 dependency allowlist
- versioned contract 소비 규칙
- 기존 네이티브 source가 있을 때의 보존 태그/목록
- 웹·Flutter·backend CODEOWNERS 및 release train 표

**수용 기준**

- 카드만 보고 어느 저장소에 변경해야 하는지 판단할 수 있다.
- 모바일 빌드는 PWA artifact나 웹 배포에 의존하지 않는다.
- 웹 빌드·배포 역시 Flutter artifact나 앱 심사 상태에 의존하지 않는다.
- 모바일 CI는 production secret 없이 PR 검사를 실행할 수 있다.
- 서버 migration 원본이 `timefit-mobile`에 중복되지 않는다.

**검증/증거**

- 저장소 visibility와 branch protection 설정 캡처
- clean checkout에서 Flutter analyze/test/build smoke 결과
- forbidden dependency scan 결과
- ADR 승인 기록

**금지 작업**

- `time_fit`에서 Supabase migration을 잘라내 이동
- 현재 untracked 작업이나 태블릿 코드를 일괄 복사·삭제
- Flutter 분리를 이유로 모바일 웹 기능 개발·배포를 동결하거나 종료
- 승인 범위를 넘어 Git history를 rewrite하거나 추적 내용을 무차별 삭제
- production secret을 초기 commit에 포함

**롤아웃/롤백**

- skeleton은 dev 환경에서만 시작하고 production 연결은 REL-011까지 차단한다.
- 부트스트랩 실패 시 신규 저장소를 폐기하기보다 접근을 잠그고 ADR/commit을 보존해 재구성한다. 백엔드에는 영향이 없어야 한다.

---

## REL-003 — 기존 DevGym 레코드 제출 이중 Go/No-Go 게이트

**목표**

두 플랫폼의 확정된 DevGym record 재사용에 대해 **기술 연속성**과 **제품·스토어 정책 연속성**을 독립 심사하고 실제 제출 가능 여부를 확정한다. 실패 시 신규 listing으로 자동 전환하지 않는다.

**적용 저장소/시스템**

- `time_fit`의 release ADR과 REL-001 evidence
- App Store Connect, Apple Developer, Android 스토어 콘솔
- `timefit-mobile` CI 정책

**선행 조건**

- REL-001 완료
- REL-002 ADR 초안 승인

**작업**

1. `Technical Continuity Gate`에서 iOS DevGym record 접근, Bundle ID, Team, entitlement와 Android DevGym 상품, package, app-signing lineage, upload credential, version 증가 가능성을 플랫폼별 `GO/NO_GO`로 판정한다.
2. `Product/Policy Continuity Gate`에서 DevGym과 TimeFit의 기능·대상 사용자·브랜드·스토어 설명·카테고리·리뷰·구독/IAP·개인정보 수집·지원 의무 차이를 기록한다.
3. REL-001의 `legacyUserMigrationDecision`과 `legacyUserDataTransferDecision`을 함께 검토한다. `NOT_APPLICABLE_ZERO_VERIFIED`이면 기존 사용자 공지·세션·로컬 데이터·push·결제 migration 구현만 N/A로 승인한다. `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`이면 기존 데이터를 TimeFit으로 이전하거나 읽지 않고 원본을 보존하며 fresh login, 새 local namespace, 신규 push 동의·등록을 사용하는 실행 계획을 요구한다. consent 원본 미검증, no-transfer inventory, opt-out·고객지원·개인정보·법무·보존·복구 책임은 별도 승인한다.
4. 기능이 완전히 다른 앱으로의 전환에 대해 필요한 경우 App Store/Android 스토어에 사전 검토를 요청하고 답변을 evidence로 보존한다.
5. 제품 책임자·법무/정책 책임자·보안·Release Engineering이 Product/Policy Gate를 각각 승인한다. 기술 담당자의 단독 승인은 허용하지 않는다.
6. Android `데브짐-매니저`, iOS `데브짐`의 store target, ID와 `REUSE_DEVGYM_RECORD` mode를 CI allowlist에 고정하고 그 외 target/ID를 denylist로 차단한다.
7. 두 Gate가 모두 `GO`이고 사용자 migration decision이 `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED` 계획일 때만 제출 상태를 `GO`로 바꾼다.
8. 어느 Gate든 `NO_GO` 또는 미확인이면 `BLOCKED_PENDING_RECOVERY`로 유지하고 production build promotion과 store upload를 차단한다.

**산출물**

- Native Store Path Decision Record
- Technical Continuity Gate 및 Product/Policy Continuity Gate 서명본
- DevGym 사용자 영향·스토어 사전 검토 evidence
- zero-user 증거 또는 비영 관측 증거, `legacyUserMigrationDecision`과 `legacyUserDataTransferDecision` 승인본
- identity drift CI policy
- blocker recovery plan(필요 시)

**수용 기준**

- iOS와 Android 모두 `REUSE_DEVGYM_RECORD`이며 각각 정확히 하나의 기존 store target이 승인된다.
- 기술 Gate와 제품·정책 Gate가 모두 `GO`이고 사용자 0명 증거 또는 기존 사용자 대응 계획이 승인된다.
- “새 Git 저장소 ≠ 새 스토어 앱” 및 “기술적으로 update 가능 ≠ 제품 전환 승인”이 ADR과 체크리스트에 명시된다.
- 미선택 store target으로의 업로드가 CI negative test에서 차단된다.

**검증/증거**

- DevGym 후보의 기술 연속성 검사와 별도 제품·정책 승인 기록
- store/backend/IAP 관측 증거와 migration/data-transfer decision 검토 기록
- CI identity mismatch 실패 테스트
- 승인자와 승인 시각이 있는 decision record

**금지 작업**

- 같은 ID·서명으로 업로드 가능하다는 이유만으로 DevGym→TimeFit 전환 승인
- 제품·법무·스토어 검토 없이 기존 사용자에게 완전히 다른 앱을 업데이트로 배포
- “임시” 신규 상품 생성 또는 새 production ID 적용
- 한 플랫폼의 identity·서명 증거를 다른 플랫폼에 재사용

**롤아웃/롤백**

- Go 전에는 production flavor와 제출 파이프라인을 비활성화한다.
- Gate가 하나라도 No-Go면 제출을 중단하고 `BLOCKED_PENDING_RECOVERY`로 전환한다.
- 경로 변경은 이 티켓 범위 밖이다. 변경이 필요하면 제품 책임자의 별도 decision record와 본 기준선 개정 전까지 어떤 artifact도 promotion하지 않는다.

---

## REL-004 — 모바일 웹·공유 백엔드·기존 네이티브 업데이트 기준선

**목표**

계속 운영될 모바일 웹의 핵심 계약과 품질을 기준선으로 만들고, iOS/Android 기존 DevGym 설치본의 앱 삭제 없는 update 기준선을 추가한다. 사용자 migration fixture는 REL-001 증거에 따라 조건부로 만든다.

**적용 저장소/시스템**

- 테스트/문서: `time_fit`
- fixture 소비: `timefit-mobile`
- 모바일 웹 staging/production-safe test 환경, shared backend staging
- iOS `데브짐`, Android `데브짐-매니저` 실제 스토어 설치본

**선행 조건**

- REL-001 artifact와 REL-003 reuse Gate 결과 확보
- 비파괴 테스트용 사용자·조직 준비

**작업**

1. 현재 모바일 웹의 지원 브라우저, 배포 버전, 주요 route, API/RPC, DB 필드 가정, 인증·조직 context, Realtime, 파일 업로드 계약을 inventory로 만든다.
2. 로그인, 조직 선택, 핵심 데이터 조회·쓰기, 로그아웃의 웹 golden scenario와 contract fixture를 기록한다.
3. 정상·만료 세션, 네트워크 손실, 중복 submit, 권한 거부, Realtime reconnect fixture를 만든다.
4. 웹의 성공률·오류율·p95 latency와 공유 backend 지표를 기준선으로 저장한다.
5. Flutter가 추가할 bootstrap/API/event 호출과 기존 웹 호출의 충돌 가능성을 비교한다.
6. 두 플랫폼의 마지막 DevGym 스토어 설치본과 앱 삭제 없는 update fixture 설계를 준비한다. 실제 signed candidate를 사용한 서명·version·설치 성공 검증은 사용자 0명 여부와 무관한 출시 전 필수 Gate이며 `SIGNING_DEFERRED_TO_RELEASE_GATE` 상태에서 실행 완료로 표시하지 않는다.
7. `legacyUserMigrationDecision: NOT_APPLICABLE_ZERO_VERIFIED`이면 local/session/push/IAP 데이터 fixture만 N/A로 표시하고 근거 링크를 남긴다. `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`이면 원본 보존, legacy reader/import 부재, fresh login, 새 local namespace, 신규 push 동의·등록, 결제 상태 미승계 기대값을 fixture로 만든다. `PENDING` 또는 다른 `REQUIRED` 상태는 승인된 처리 계획 없이는 통과시키지 않는다.
8. Flutter clean-install 기준선도 별도로 정의해 신규 설치와 기존 record update 설치를 모두 검증한다.

**산출물**

- web/native/backend compatibility matrix
- 모바일 웹 golden E2E scenario/fixture
- DevGym update-install fixture와 REL-001 결정별 legacy-state fixture 또는 `NOT_APPLICABLE_ZERO_VERIFIED` 증거
- API/RPC 제거 금지 목록
- 웹·공유 backend 품질·성능 baseline

**수용 기준**

- 지원 중인 모바일 웹 contract와 소유자가 명시된다.
- 모바일 웹 golden scenario가 staging에서 반복 실행된다.
- Flutter 계약 변경 전후 웹 회귀를 자동 비교할 수 있다.
- 두 플랫폼 모두 실제 설치본에서 앱 삭제 없는 update test를 시작할 수 있고, legacy-state fixture의 포함/N/A가 REL-001 결정과 일치한다.

**검증/증거**

- 브라우저·웹 deploy ID·backend deploy ID가 표시된 golden run 결과
- backend request/RPC 목록과 usage snapshot
- fixture checksum 및 개인정보 비식별 확인
- 조건부 native 기기·OS·build 결과

**금지 작업**

- 운영 고객 데이터를 fixture로 복사
- `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 계획 없이 DevGym local/session/push/IAP 처리를 생략
- 모바일 웹 회귀를 Flutter widget test로 대체
- 아직 호출되는 RPC를 정리 대상으로 표시

**롤아웃/롤백**

- 테스트 전용 변경만 허용한다.
- 모바일 웹 기준선이 재현되지 않으면 공유 계약 변경을 중단하고 웹 artifact·테스트 계정부터 복구한다. 현재 웹 배포는 유지한다.

---

## REL-005 — 모바일 웹·Flutter 공유 백엔드 호환 계약

**목표**

계속 운영되는 `mobile-web`과 신규 `flutter-native`가 같은 backend를 독립 릴리스하면서 데이터 손상 없이 사용하게 한다. DevGym client는 재사용 경로일 때만 별도 generation으로 포함한다.

**적용 저장소/시스템**

- 계약·구현 원본: `time_fit`
- 생성 client/contract test: `timefit-mobile`

**선행 조건**

- REL-004 웹 제거 금지 목록과 golden fixture
- 백엔드 staging 및 migration rehearsal 환경

**작업**

1. bootstrap 요청에 `client_type`(`mobile_web|flutter_native|devgym_native_if_applicable`), platform, application ID/origin, client generation, version/build/deploy ID, installation ID, locale, timezone을 정의한다.
2. 응답에 schema version, server time, mode, minimum/recommended version, store URL, config TTL, feature flags, compatibility code를 정의한다.
3. `CLIENT_VERSION_UNSUPPORTED`, `CLIENT_GENERATION_UNSUPPORTED`, `FEATURE_DISABLED`, `MAINTENANCE`, `READ_ONLY_MODE` 등 안정된 오류 코드를 정의한다.
4. DB 변경은 `expand → backfill/migrate → contract` 순서로 분리한다.
5. 신규 필드에 구버전 안전 기본값을 두고 기존 RPC의 입력·출력 의미를 변경하지 않는다.
6. write API에 idempotency와 서버 권한 검사를 적용하고 `client_type`/generation별 telemetry를 추가한다.
7. 계약 schema를 versioned artifact로 발행하고 웹 consumer test와 Flutter generated client/consumer test를 연결한다.
8. 웹과 Flutter의 deployment가 서로 다른 계약 버전을 소비하는 기간을 지원하는 N/N-1 호환 정책과 owner를 정의한다.

**산출물**

- bootstrap/API/event schema
- compatibility policy와 오류 코드 문서
- additive migration 및 contract tests
- client_type/generation별 dashboard dimension

**수용 기준**

- 동일 staging backend에서 모바일 웹과 Flutter golden test가 동시에 통과한다.
- 새 migration 후 모바일 웹의 핵심 쓰기·읽기와 현재 SLO가 유지된다.
- destructive contract는 모든 지원 consumer의 호출 0, owner 승인, deprecation window 종료 전에는 실행하지 않는다. Flutter 100% 배포는 웹 contract 제거 조건이 아니다.
- 앱 버전 값은 인증·인가 근거로 사용되지 않는다.

**검증/증거**

- producer/consumer contract test 결과
- migration 전후 모바일 웹 golden diff와 Flutter contract test
- 중복 요청·재시도 idempotency 테스트
- RLS/권한 회귀 결과

**금지 작업**

- 기존 컬럼/RPC 즉시 삭제 또는 의미 변경
- client generation 헤더만 믿고 권한 허용
- 모바일 저장소에서 DB schema를 직접 배포
- AI/AX endpoint를 호환 계약에 포함

**롤아웃/롤백**

- additive server change를 먼저 staging→production 순으로 배포하되 신규 경로는 flag off로 둔다.
- 문제 시 Flutter 전용 경로/flag만 끄고 모바일 웹 경로를 유지한다. destructive migration은 이 단계에서 금지하므로 schema rollback 의존을 줄인다.

---

## REL-006 — Remote Config·최소 버전·Kill Switch

**목표**

스토어 재심사 없이 위험 기능을 제한하고 버전 호환 상태를 제어한다.

**적용 저장소/시스템**

- config endpoint와 enforcement: `time_fit`
- config client와 안전 UI: `timefit-mobile`

**선행 조건**

- REL-005 bootstrap contract
- 운영자 역할과 감사 로그 정책

**작업**

1. `normal`, `read_only`, `maintenance` mode와 chat/write, realtime, attachment, push 등 독립 flag를 정의한다.
2. iOS/Android 최소·권장 버전과 REL-003에서 선택된 플랫폼별 스토어 URL을 config에 둔다. 웹 최소 버전 정책과 혼합하지 않는다.
3. TTL, last-known-good cache, schema validation, 잘못된 값의 안전 기본값을 구현한다.
4. 캐시 없는 첫 실행에서 config 실패 시 로그인/읽기만 허용하고 비가역 쓰기·업로드를 차단한다.
5. 서버가 보안·무결성 관련 flag를 실제 API에서 강제하되 `client_type` scope를 지원해 Flutter 장애 시 모바일 웹을 불필요하게 차단하지 않는다.
6. 변경 권한, 2인 승인, 변경 사유, 이전/새 값, 자동 만료를 audit log에 남긴다.
7. staging에서 쓰기·Realtime·첨부·푸시별 game day를 수행한다.

**산출물**

- versioned config schema와 client
- 운영자 console/runbook
- Kill Switch audit log
- game-day report

**수용 기준**

- 승인된 운영자가 5분 이내에 각 위험 기능을 독립 중단할 수 있다.
- 앱 재시작 없이 TTL 후 새 설정이 반영된다.
- invalid/missing config에서 crash나 무단 쓰기가 없다.
- minimum version 미만은 REL-003 manifest에 승인된 해당 플랫폼 store URL로만 안내한다.
- Flutter 전용 flag 중단이 모바일 웹 기능 flag를 변경하지 않는다.

**검증/증거**

- flag별 server/client 통합 테스트
- config outage·stale cache·clock skew 테스트
- 변경 감사 로그와 복구 소요 시간

**금지 작업**

- 앱 UI만 숨기고 서버 write는 허용
- 임의 URL로 업데이트 유도
- config를 사용자 권한의 대체 수단으로 사용
- secret을 remote config에 저장

**롤아웃/롤백**

- 읽기 전용으로 관찰한 뒤 일부 내부 계정에서 활성화한다.
- config 이상 시 last-known-good로 복귀하고 server는 보수적인 write 차단값을 적용한다.

---

## REL-007 — 웹·네이티브 인증 세션 격리와 계정 연속성

**목표**

모바일 웹과 Flutter가 같은 사용자 UUID·조직 권한을 사용하되 세션 저장소와 lifecycle은 분리한다. 기존 native session 처리는 REL-001 결정에 따른다. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`에서는 legacy session을 읽거나 이전하지 않고 최초 TimeFit 로그인을 사용한다.

**적용 저장소/시스템**

- 모바일 secure storage/auth client: `timefit-mobile`
- refresh·session validation·audit: `time_fit`

**선행 조건**

- REL-001의 고정 reuse mode, `legacyUserMigrationDecision`, Keychain/Keystore/access group 조사
- REL-004 웹 auth 계약 및 DevGym update/session fixture 결정
- REL-005 bootstrap

**작업**

1. 모바일 웹의 cookie/local storage/session lifecycle과 Flutter secure storage를 별도 namespace로 정의한다. 브라우저 저장소를 앱이 읽거나 복사하지 않는다.
2. Flutter는 같은 운영 Auth project를 사용하고 로그인 후 서버에서 사용자 UUID·조직 membership·role을 다시 조회한다.
3. refresh token rotation, revoke, 다중 기기, 비밀번호 변경, 계정 비활성화가 웹과 Flutter에서 일관되게 강제되는지 검증한다.
4. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`이면 DevGym session reader를 구현하지 않고 최초 TimeFit 로그인을 기본으로 한다. 웹 로그인 상태 자동 이전도 약속하지 않는다. `REQUIRED` no-transfer 경로에서는 원본 세션을 변경·삭제하지 않는다.
5. `REQUIRED`이고 동일 app sandbox와 issuer/project가 증명된 경우에만 DevGym session reader를 별도 flag로 구현한다. DevGym 계정 체계가 다르면 반드시 재로그인한다.
6. 구조·issuer·project를 검증하고 서버 refresh 성공 후 현재 사용자와 조직 context를 다시 조회한 뒤에만 Flutter secure storage에 기록한다.
7. 재로그인 중 pending deep link를 비민감 형태로 보존하고 성공 후 권한 재검증 뒤 이동한다.
8. 웹 또는 앱에서 로그아웃·계정 전환할 때의 정책을 명시하고 해당 클라이언트의 cache, push association, memory state를 완전히 비운다. 다른 클라이언트 세션을 임의 revoke하지 않는다.

**산출물**

- auth/session state machine과 client namespace 문서
- secure storage adapter
- reauthentication UX/copy
- DevGym session migration adapter, 또는 REL-001 증거에 연결된 `NOT_APPLICABLE_ZERO_VERIFIED`/승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 기록
- threat model과 test matrix

**수용 기준**

- migration 실패가 startup crash loop로 이어지지 않는다.
- 다른 사용자/조직의 로컬 데이터 노출이 0건이다.
- 비밀번호는 읽기·이전·저장하지 않는다.
- 웹 로그인 상태와 무관하게 Flutter 최초 로그인이 정상 동작한다.
- DevGym session 투명 이전이 불가능하거나 미승인일 때 재로그인 사유와 복구 경로가 명확하다.

**검증/증거**

- 유효/만료/폐기/rotation/다른 프로젝트/로그아웃/다중 계정 테스트
- 웹·Flutter 동시 로그인/로그아웃/토큰 폐기 교차 테스트
- 두 플랫폼의 실제 스토어 설치→업데이트 Keychain/Keystore 접근·crash 없음 검증; session migration은 decision별 기대값 검증
- 로그 redaction scan

**금지 작업**

- 웹 cookie/localStorage나 알 수 없는 blob을 Flutter로 복사·임의 파싱
- access/refresh token 출력 또는 analytics 전송
- 검증되지 않은 DevGym 또는 브라우저 storage 접근 우회 시도
- 세션 실패 시 익명 사용자로 기존 데이터를 표시

**롤아웃/롤백**

- 내부 파일럿에서 Flutter 인증 성공률을 먼저 측정한다. 실제 데이터 이전이 승인된 `REQUIRED` migration만 별도 cohort에서 측정하며, `USER_ATTESTED_DO_NOT_MIGRATE` 경로는 fresh-login cohort로 검증한다.
- 오류율이 기준을 넘으면 native migration flag만 끄고 안전한 재로그인 경로로 전환한다. 모바일 웹 세션과 서버 사용자 데이터는 변경하지 않는다.

---

## REL-008 — Flutter 로컬 데이터·캐시·Outbox 초기 설계

**목표**

Flutter 전용 로컬 DB·캐시·Outbox를 새로 설계해 중복 전송·계정 간 데이터 혼합을 방지한다. 기존 native state migration은 REL-001 결정이 `REQUIRED`이고 실제 이전 대상이 확인된 경우에만 별도 adapter로 다룬다.

**적용 저장소/시스템**

- local data/outbox 및 조건부 migration adapter: `timefit-mobile`
- idempotency/reconciliation API: `time_fit`

**선행 조건**

- REL-004 웹 계약과 DevGym local fixture/N/A 결정
- REL-007 사용자 identity 확정
- REL-005 idempotency 계약

**작업**

1. Flutter 로컬 schema에 user ID, organization ID, environment, schema version을 복합 namespace로 적용한다.
2. server-authoritative cache와 local-only draft, outbox item을 분리하고 각 보존·암호화·삭제 정책을 정의한다.
3. outbox는 idempotency key, aggregate, payload version, dependency, state, attempt count, retry time, terminal error를 저장한다.
4. process kill, 저장 공간 부족, DB corruption, 계정 전환에서 cache 재초기화와 서버 resync가 가능하게 한다.
5. pending write는 서버에 idempotency key로 저장 여부를 확인한 뒤에만 재개한다.
6. 모바일 웹의 IndexedDB/localStorage를 Flutter local DB로 읽거나 공유하지 않는다.
7. `legacyUserMigrationDecision: REQUIRED`이고 `legacyUserDataTransferDecision`이 승인된 migration이며 옮길 값이 실제로 확인된 경우에만 언어·테마, 검증 가능한 draft, idempotency key가 있는 pending operation을 후보로 분류한다. `USER_ATTESTED_DO_NOT_MIGRATE`에서는 후보를 만들지 않는다.
8. 승인된 migration은 `migrationKey`, source schema, status, attempt, timestamp, error를 journal에 기록하고 copy→validate→commit으로 처리한다. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`이면 migration code를 포함하지 않고 증거 링크, 원본 보존과 새 namespace 검증만 남긴다.

**산출물**

- versioned Flutter local schema, namespace, retention policy
- outbox state machine과 recovery policy
- DevGym migration journal/reader, 또는 `NOT_APPLICABLE_ZERO_VERIFIED`/승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 기록
- server reconciliation endpoint/test
- cleanup policy

**수용 기준**

- clean install에서 웹 또는 다른 환경의 로컬 데이터가 섞이지 않는다.
- 메시지/업무 작업의 중복 서버 저장과 확인된 유실이 0건이다.
- outbox 처리 중 강제 종료 후 재실행해도 같은 결과가 나온다.
- 실제 데이터 이전이 승인된 `REQUIRED` migration만 앱 삭제 없는 업데이트에서 allowlist 값을 복사한다. `NOT_APPLICABLE_ZERO_VERIFIED`와 `USER_ATTESTED_DO_NOT_MIGRATE`에서는 legacy 값에 의존하거나 복사하지 않는다.
- 계정 전환 후 이전 계정 cache가 보이지 않는다.

**검증/증거**

- Flutter schema 버전·계정·조직·환경 격리 테스트
- process kill/property-based outbox idempotency 테스트
- REL-001 decision별 DevGym fixture migration 또는 N/A 결과
- 중복·유실 reconciliation report
- 개인정보 잔존 파일 검사

**금지 작업**

- 모바일 웹 브라우저 저장소를 공유 DB처럼 사용
- 조건부 migration 검증 전에 DevGym 원본 삭제
- idempotency key 없는 outbox 자동 전송
- cache를 서버 원본보다 우선
- 사용자 ID 불일치 데이터를 현재 계정에 연결

**롤아웃/롤백**

- Flutter cache/outbox는 내부 cohort부터 활성화하고 실제 데이터 이전이 승인된 DevGym migration reader만 별도 flag로 제한한다. `USER_ATTESTED_DO_NOT_MIGRATE` 빌드에는 reader를 포함하지 않는다.
- 이상 시 Flutter cache를 폐기하고 서버에서 재동기화하며 DevGym 원본이 있으면 보존한다. 모바일 웹 로컬 상태는 건드리지 않는다.

---

## REL-009 — 네이티브 푸시 설치·토큰·payload 분리

**목표**

Flutter 네이티브 push를 모바일 웹/Web Push와 독립 등록하고 알림 누락·중복·로그아웃 후 오발송을 방지한다. DevGym token은 재사용 경로일 때도 TimeFit 사용자 동의와 재등록 없이 승계하지 않는다.

**적용 저장소/시스템**

- token client·route: `timefit-mobile`
- installation registry·dispatcher: `time_fit`
- APNs/FCM, REL-003에서 승인된 네이티브 app 등록, 기존 웹 push 설정

**선행 조건**

- REL-001의 웹/DevGym/TimeFit push provider inventory
- REL-005 generation 계약
- REL-007 로그인·로그아웃 lifecycle

**작업**

1. 설치 모델에 user, installation, `client_type`, platform, application ID, generation, app version/build, provider project, token, permission state, status, lastSeen/revoked를 정의한다.
2. 앱 시작·로그인·token refresh 때 upsert하고 로그아웃·계정 전환 때 사용자 연결을 해제한다.
3. invalid/unregistered 응답을 서버가 처리해 token을 비활성화한다.
4. payload는 schema version, event ID, type, resource ID만 포함하고 민감 본문은 서버 재조회한다.
5. 같은 event ID는 한 번만 표시·route한다.
6. 모바일 웹과 Flutter가 이해하는 payload 범위가 다르면 client_type/generation별 payload를 생성한다. legacy push payload는 REL-001에서 실제 활성 installation이 확인된 경우에만 호환한다.
7. 기존 알림 권한을 무조건 다시 요청하지 않고 OS 상태를 먼저 읽는다. DevGym record 재사용이어도 기능·목적이 달라진 TimeFit 알림의 사용자 안내와 동의 요구사항을 제품·법무 검토에 따른다.
8. 웹 push subscription과 native device token은 서로 다른 installation record로 저장하고 한쪽 revoke가 다른 쪽을 삭제하지 않게 한다.
9. `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`이면 legacy token import/발송 코드를 만들지 않고 TimeFit 로그인·권한 안내 후 현재 설치에서 받은 token만 새 installation으로 등록한다. 그 밖의 `REQUIRED` 상태에서도 기존 token을 자동 승계하지 않고 승인된 재동의·재등록 절차를 따른다.

**산출물**

- installation registry schema/API
- push payload v1 schema와 fixtures
- token lifecycle client
- dispatcher generation routing과 runbook

**수용 기준**

- foreground/background/terminated에서 알림 route가 성공한다.
- token rotation 뒤 이전 token이 비활성화된다.
- 로그아웃 사용자에게 보호 데이터 알림이 발송되지 않는다.
- 동일 event의 중복 표시가 없다.
- legacy token은 migration decision과 무관하게 TimeFit 대상으로 일괄 승계되지 않으며, N/A 경로에는 legacy token import code가 없다.

**검증/증거**

- APNs/FCM 실기기 delivery matrix
- token rotation·invalid token·logout test
- payload privacy scan 및 event dedupe 결과
- 모바일 웹/Flutter 동시 기기 테스트와 실제 스토어 설치→Flutter update push 상태 테스트

**금지 작업**

- push payload에 메시지·급여·근태 원문 포함
- token 전체값을 로그/analytics에 기록
- REL-003 release mode와 다른 Firebase/APNs app을 연결
- DevGym token을 TimeFit 마케팅·업무 알림 대상으로 일괄 재사용
- 사용자 ID 없이 token을 영구 연결

**롤아웃/롤백**

- 내부 코호트의 Flutter installation에만 신규 generation routing을 활성화한다.
- 장애 시 Flutter push만 flag off하고 앱은 polling/수동 refresh를 제공한다. 모바일 웹/Web Push dispatcher는 유지한다.

---

## REL-010 — 웹·네이티브 링크 namespace와 OAuth callback 공존

**목표**

모바일 웹 URL을 유지하면서 Flutter Universal/App Links·custom scheme·OAuth callback의 소유권과 route를 분리하고, inventory에서 실제 사용이 확인된 DevGym 과거 링크만 기간 제한 alias로 처리한다.

**적용 저장소/시스템**

- route/parser: `timefit-mobile`
- redirect/link metadata와 권한 조회: `time_fit`
- Apple/Android/OAuth 공급자 설정

**선행 조건**

- REL-001 link/callback inventory
- REL-004 웹 route/payload fixture와 DevGym link inventory/fixture
- REL-007 인증 후 목적지 복구

**작업**

1. 모바일 웹 URL과 DevGym scheme/host/path/query를 inventory하고 TimeFit native용 namespace/route mapping을 만든다.
2. 인증 필요 링크는 안전한 pending route로 저장하고 로그인 후 서버 권한 검증 뒤 연다.
3. 삭제·승인·결제·개인정보 변경은 링크 수신만으로 실행하지 않는다.
4. iOS Associated Domains와 AASA에 REL-003 release mode의 실제 Team ID+Bundle ID 조합을 검증하고 기존 웹 route를 깨지 않게 한다.
5. Android `autoVerify`와 `assetlinks.json`에 선택된 실제 app-signing SHA-256을 사용하고 웹 fallback을 검증한다.
6. malformed/unknown/expired link에 설명 가능한 fallback 화면을 제공한다.
7. DevGym route alias는 `REUSE_DEVGYM_RECORD`일 때만 사용량 기반 기간 동안 유지한다. 모바일 웹 URL은 Flutter 100% 배포 후에도 종료하지 않는다.

**산출물**

- web↔Flutter route ownership map 및 필요한 경우 DevGym→Flutter alias map/N/A 근거
- signed/validated route parser
- AASA/assetlinks 배포·검증 절차
- OAuth callback matrix와 fixtures

**수용 기준**

- 설치/미설치, 로그인/로그아웃, web/Flutter 조합과 승인된 DevGym alias 조합을 모두 통과한다.
- 권한 없는 resource가 링크로 열리지 않는다.
- 과거 push/email fixtures가 crash 없이 의도한 route 또는 명시적 fallback으로 간다.

**검증/증거**

- 실제 도메인의 AASA/assetlinks 응답과 OS verification 결과
- route fuzz/malformed 테스트
- OAuth provider별 실기기 callback E2E

**금지 작업**

- debug certificate를 production `assetlinks.json`에 사용
- 미확인 resource ID를 그대로 화면에 전달
- unknown link를 조용히 홈으로 보내 성공 처리
- Flutter 링크 설정으로 기존 모바일 웹 URL 또는 OAuth callback을 가로채기

**롤아웃/롤백**

- 웹 route와 native route를 병행하고 client_type별 성공률을 관찰한다.
- 문제 시 native link 생성/association만 끄고 모바일 웹 URL을 fallback으로 유지한다. 승인된 DevGym alias는 정해진 기간 동안 parser가 계속 지원한다.

---

## REL-011 — Production 식별자·서명·재현 가능한 CI/CD

**목표**

`timefit-mobile`에서 REL-003의 기존 iOS `데브짐`·Android `데브짐-매니저` target에만 수락되는, 비밀 노출 없는 재현 가능한 production artifact를 만든다.

**적용 저장소/시스템**

- `timefit-mobile`
- CI secret manager, App Store Connect, Android 스토어 테스트 트랙

**선행 조건**

- REL-001~REL-003 승인
- REL-005~REL-010의 release 대상 계약 확정

**작업**

1. production flavor에 REL-003에서 승인된 Bundle ID/application ID를 적용하고 dev/staging은 별도 suffix를 쓴다.
2. iOS Team, provisioning, capabilities와 Android signing/upload 설정을 secret manager 연동으로 구성한다.
3. debug signing, placeholder ID, 잘못된 Team/target과 현재 최대값 이하의 version/build를 차단한다.
4. dependency lock, Flutter SDK pin, deterministic build inputs와 provenance를 기록한다.
5. IPA/Archive, AAB/APK, dSYM, mapping, SBOM, checksum, build metadata를 보존한다.
6. artifact에서 최종 ID, version, entitlement, signing certificate를 추출해 REL-003 최종 manifest와 자동 비교한다.
7. 승인된 기존 iOS TestFlight/App Store Connect record와 Android 내부/비공개 테스트 track에만 업로드한다.
8. release pipeline과 web deployment pipeline 사이에 secret·trigger·rollback 권한을 공유하지 않고 상호 독립성을 시험한다.

**산출물**

- protected release pipeline
- signed test artifacts와 provenance
- identity/signing verification job
- artifact retention/restore policy

**수용 기준**

- 신규 저장소 빌드가 플랫폼별로 승인된 테스트 채널에 수락된다.
- 잘못된 ID, debug signing, 낮은 versionCode/build number에서 pipeline이 실패한다.
- 승인된 두 DevGym target 외 임의 신규/다른 target 업로드가 실패한다.
- 개발자 로컬 장비에 production private key를 배포하지 않는다.
- release artifact와 symbols를 감사 기간 동안 복구할 수 있다.

**검증/증거**

- clean runner build log와 checksum
- archive/AAB identity extraction report
- 승인된 TestFlight/Android 테스트 트랙 처리 성공 캡처와 target ID
- secret scan 및 SBOM 결과

**금지 작업**

- keystore, certificate private material, provisioning profile을 Git에 commit
- `tablet_app` debug signing 설정 복사
- REL-003 승인 없이 테스트 편의를 위한 store record 생성
- CI target을 바꿔 DevGym↔TimeFit 경로를 우회
- 서명 검증을 사람이 눈으로만 수행

**롤아웃/롤백**

- 내부 테스트 트랙까지만 자동화하고 production 제출은 수동 승인 gate를 둔다.
- pipeline 이상 시 artifact promotion을 중단하고 마지막 검증된 runner/image와 lockfile로 재빌드한다.

---

## REL-012 — 기존 스토어 listing 전환·개인정보·심사 자료 준비

**목표**

기존 Android `데브짐-매니저`와 iOS `데브짐` listing을 TimeFit으로 전환하고, metadata·개인정보·심사 자료를 Flutter 실제 동작과 REL-001의 실제 population evidence 및 승인된 사용자 처리 계획에 맞춘다.

**적용 저장소/시스템**

- metadata source: `timefit-mobile/release` 또는 합의된 경로
- REL-003에서 승인된 기존 iOS `데브짐`·Android `데브짐-매니저` target
- 지원·약관·개인정보 URL

**선행 조건**

- REL-011 테스트 artifact
- 실제 구현 기능과 수집 데이터 inventory
- 심사 계정과 안정된 staging/production backend

**작업**

1. 기존 두 record에서 이름, 설명, 카테고리, 아이콘, 스크린샷, 지원 URL, version metadata를 TimeFit 실제 기능에 맞춰 작성한다. 신규 record는 만들지 않는다.
2. DevGym→TimeFit의 기능·브랜드·대상 사용자 변경, 실제 population evidence의 기준 시각·범위, 데이터/계정 migration 및 data-transfer decision과 사전 검토 결과를 심사 노트에 명시한다. 단순 “Flutter 재구현”으로 축소 설명하지 않는다.
3. 개인정보처리방침, 이용약관, 고객지원, 계정 삭제 경로를 실기기에서 검증한다.
4. App Privacy/Data Safety 신고를 실제 SDK, 로그, push, 파일/카메라 사용과 맞춘다.
5. iOS Privacy Manifest와 third-party SDK manifest를 검토한다.
6. 권한은 실제 기능 사용 시점에만 요청하고 purpose string을 정확히 쓴다.
7. REL-001이 `REQUIRED`이면 승인된 계획에 따라 재로그인, no-transfer, 원본 보존과 지원 경로를 릴리스 노트·사전 공지·앱 내 안내에 명시한다. `NOT_APPLICABLE_ZERO_VERIFIED`이면 공지 N/A 근거를 review packet에 포함한다.
8. PWA 및 구현되지 않은 AI/AX 기능을 설명·스크린샷·키워드에 넣지 않는다.

**산출물**

- versioned store metadata와 screenshot set
- review notes/test account instructions
- privacy/data inventory와 SDK manifest report
- support readiness checklist

**수용 기준**

- metadata가 REL-003에서 선택한 정확한 record에만 적용된다.
- 사용자 0명 evidence 또는 필요한 기존 사용자 영향 고지와 제품·법무·스토어 검토가 승인된다.
- 기존 review/rating 기록이 있더라도 TimeFit의 신규 성과인 것처럼 홍보하지 않는다.
- 설명과 screenshot이 제출 artifact의 실제 기능과 일치한다.
- 개인정보 신고와 권한 호출이 실제 코드와 일치한다.
- 심사 기간 동안 계정과 backend가 안정적으로 동작한다.

**검증/증거**

- metadata diff와 선택된 record ID/release mode 확인
- URL/계정/권한 prompt 실기기 테스트
- dependency/data collection review 승인

**금지 작업**

- 승인되지 않은 중복 listing 생성
- DevGym 재사용 시 제품 변경과 기존 사용자 영향을 심사자에게 누락
- 구현되지 않은 PWA·AI·AX 기능 홍보
- production credential을 심사 노트에 평문 기재
- 실제 수집 데이터를 축소 신고

**롤아웃/롤백**

- metadata 초안→법무/보안/제품 검토→승인된 record에 저장 순으로 진행한다.
- 오류 발견 시 제출 전 metadata를 되돌리고, 제출 후에는 심사 철회 또는 수정 가능한 필드 정정 절차를 따른다.

---

## REL-013 — 네이티브 clean-install·기존 record upgrade·웹 병렬 E2E

**목표**

TimeFit Flutter 앱의 clean-install 전체 경로와 모바일 웹 병렬 사용을 증명하고, 두 기존 DevGym record에서 앱 삭제 없는 upgrade 경로를 검증한다.

**적용 저장소/시스템**

- E2E 및 test harness: `timefit-mobile`
- backend assertions/fixtures: `time_fit`
- TestFlight/Android 테스트 트랙과 실기기 lab

**선행 조건**

- REL-004 golden baseline
- REL-005~REL-012 staging-ready
- release candidate 서명 artifact

**작업**

1. 승인된 테스트 track에서 Flutter candidate를 clean install하고 최초 로그인, 조직, cache/outbox, 알림, 링크 전체 경로를 확인한다.
2. 동일 사용자로 모바일 웹과 Flutter에 동시에 로그인해 읽기·쓰기·Realtime·권한 변경·로그아웃 교차 시나리오를 실행한다.
3. 한 클라이언트의 배포·네트워크·세션 장애가 다른 클라이언트의 데이터 정합성과 사용 가능성을 깨지 않는지 확인한다.
4. 최소/최신 iOS, 최소/최신 Android, 저사양 Android에서 반복한다.
5. 유효/만료 세션, 알림 허용/거부, Wi-Fi↔LTE, network loss, 저장 공간 부족, process kill을 시험한다.
6. 두 플랫폼의 DevGym 스토어 설치본을 삭제하지 않고 Flutter candidate로 업데이트해 package/Bundle ID, 서명, version, startup, 최초 TimeFit 로그인, 알림, 링크를 확인한다.
7. `legacyUserMigrationDecision: REQUIRED`이면 승인된 처리 계획의 fixture를 검증한다. `USER_ATTESTED_DO_NOT_MIGRATE`이면 legacy 로그인·설정·push token·pending state를 읽거나 옮기지 않고 원본을 보존하며 최초 로그인과 새 namespace가 표시되는지 확인한다. `NOT_APPLICABLE_ZERO_VERIFIED`이면 빈 legacy sandbox와 최소 설정값에서 같은 무이전 동작을 검증한다.
8. client-scoped read-only/maintenance/Kill Switch에서 웹과 Flutter의 독립 안전 동작을 검증한다.

**산출물**

- signed clean-install/cross-client report 및 두 플랫폼 upgrade report
- device/OS/session matrix
- outbox/reconciliation 및 조건부 migration 결과
- known issue와 release blocker 목록

**수용 기준**

- Critical 시나리오 100% 통과
- 사용자·조직 간 데이터 혼합, 확인된 데이터 유실·중복 저장, startup crash loop가 모두 0건
- 모바일 웹과 Flutter가 같은 backend에서 동시에 핵심 기능을 수행한다.
- 두 플랫폼의 upgrade test가 uninstall/reinstall에 의존하지 않는다.
- 두 플랫폼의 clean-install과 웹 병렬 test가 모두 통과한다.

**검증/증거**

- 고정된 `REUSE_DEVGYM_RECORD`의 package/Bundle ID와 signing 검증
- 화면 녹화 또는 자동화 로그, server reconciliation query 결과
- 네트워크·process failure injection 결과

**금지 작업**

- 실패한 upgrade를 clean install 성공으로 대체
- `NOT_APPLICABLE_ZERO_VERIFIED` 또는 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE`인데 근거 없이 legacy migration 코드를 추가
- 실제 운영 고객 계정으로 파괴적 테스트
- blocker를 알려진 제한사항으로만 남기고 출시 승인
- production DB 직접 수정으로 테스트 결과 보정

**롤아웃/롤백**

- 테스트 트랙과 지정 조직에만 candidate를 제공한다.
- 실패 시 네이티브 배포를 중단하고 모바일 웹과 공유 호환 server path를 유지한다. 조건부 migration된 테스트 기기는 REL-016 복구 시나리오로 검증한다.

---

## REL-014 — 관측성·SLO·자동 출시 게이트

**목표**

client_type·release mode·version별 품질과 데이터 무결성을 측정해 네이티브 단계 확대·중단을 객관적으로 결정하고 모바일 웹 회귀를 함께 감시한다.

**적용 저장소/시스템**

- 앱 telemetry/symbol upload: `timefit-mobile`
- server metrics/dashboard/alerts: `time_fit`
- crash/observability platform

**선행 조건**

- REL-004 baseline
- REL-006 Kill Switch
- REL-013 candidate test

**작업**

1. startup, session recovery, login, bootstrap, write, duplicate reconciliation, Realtime reconnect/gap-fill, token registration, notification route, deep-link, crash/ANR 지표를 정의한다. legacy migration 지표는 REL-001이 `REQUIRED`인 경우에만 적용한다.
2. `client_type`, platform, release mode, generation, version/build/deploy ID, release cohort로 분리하되 개인 데이터는 수집하지 않는다.
3. baseline 대비 회귀와 절대 threshold를 release gate로 구현한다.
4. 보안·데이터 무결성 사건은 비율이 아니라 단 1건으로도 중단되게 한다.
5. symbol/mapping 업로드와 release ID를 backend deploy ID에 연결한다.
6. on-call alert, dashboard, incident ticket, REL-016 runbook을 연결한다.

**산출물**

- release dashboard와 alerts
- telemetry data dictionary/redaction policy
- automated gate policy
- on-call handoff

**수용 기준**

- 권장 진행 기준: native crash-free sessions ≥ 99.8%, startup 성공률 ≥ 99.5%, 온라인 write 성공률 ≥ 99.9%. 조건부 migration 대상은 성공률 ≥ 99.5%.
- 로그인 성공률은 baseline 대비 0.5%p 이상 악화되지 않고 p95 startup/API latency는 20% 이상 악화되지 않는다.
- 모바일 웹의 핵심 성공률·p95·서버 오류율은 REL-004 baseline 허용 범위를 벗어나지 않는다.
- 즉시 중단: 타 사용자/조직 노출 1건, 확인된 데이터 유실 또는 중복 서버 저장 1건, 계정 오연결 1건.
- 추가 중단: crash-free < 99.5%, migration 실패 > 0.5%, 로그인 실패 baseline 대비 +1%p, write 실패 > 1%.

**검증/증거**

- synthetic event와 alert firing test
- redaction/PII scan
- mobile-web/flutter-native 및 release-mode 분리 dashboard 캡처
- gate 계산 재현 쿼리

**금지 작업**

- 메시지 본문, token, signed URL을 telemetry에 포함
- 전체 평균으로 특정 version 회귀를 숨김
- 데이터 무결성 사건을 샘플링으로 누락
- 수치 미달인데 수동으로 gate를 우회하고 기록하지 않음

**롤아웃/롤백**

- 내부 build에서 telemetry volume·redaction을 검증한 뒤 공개 cohort에 적용한다.
- telemetry 장애 자체는 안전한 출시 중단 사유다. 잘못된 dashboard는 이전 검증된 query로 복구하고 확대를 보류한다.

---

## REL-015 — 내부 파일럿·단계 배포

**목표**

내부·비공개 테스트 코호트에서 시작해 정량 게이트를 통과할 때만 기존 store target의 production 가용 범위를 확대한다. 모바일 웹 배포는 별도 release train으로 계속된다.

**적용 저장소/시스템**

- release manifest/runbook: `timefit-mobile`
- cohort flag와 dashboard: `time_fit`
- REL-003에서 승인된 기존 iOS/Android record의 staged/phased rollout

**선행 조건**

- REL-011~REL-014 완료
- REL-016 runbook 사전 훈련
- 고객지원·on-call 준비

**작업**

1. 개발/QA 20명 48시간, 내부 2개 조직·최소 50기기 72시간을 운영한다.
2. 공개 1%→5%→10%→25%→50%→100% 순으로 확대한다.
3. 1/5/10%는 각 최소 24시간, 25/50%는 각 최소 48시간 관찰한다.
4. 각 단계에서 REL-014 지표, P0/P1 장애, 고객 문의, 모바일 웹/backend 회귀를 검토한다.
5. 스토어가 원하는 비율 제어를 제공하지 않으면 binary 배포와 server cohort flag를 결합한다.
6. 승인자, 지표 snapshot, 결정 시각, 다음 단계 조건을 release log에 기록한다.
7. 네이티브 100% 뒤 최소 7일 집중 관찰하되 모바일 웹 개발·배포 종료로 해석하지 않는다.
8. production 전환 직전 REL-001과 같은 조회 범위와 단일 `as_of`로 스토어 설치·활성 기기, backend installation·push token, 활성 구독·IAP를 다시 확인한다. `NOT_APPLICABLE_ZERO_VERIFIED` 경로에서 하나라도 0이 아니거나 조회할 수 없으면 즉시 중단하고 REL-001/003을 다시 연다. 승인된 `REQUIRED + USER_ATTESTED_DO_NOT_MIGRATE` 경로에서는 새 관측값을 기존 사용자 영향·지원·보존·복구 계획과 다시 대조하고 승인 범위를 벗어나면 rollout을 중단한다.
9. 신규 설치가 발생하기 시작하면 acquisition, activation, login, crash, 지원 문의를 플랫폼별로 관찰하고 다음 단계 승인에 포함한다.

**산출물**

- cohort별 release log
- stage approval records
- 고객지원 FAQ와 공지 초안
- 100% 후 관찰 보고서

**수용 기준**

- 모든 단계가 최소 시간과 REL-014 gate를 충족한다.
- 자동 비율 증가가 없고 명시적 승인 뒤에만 확대된다.
- 중단 조건 발생 시 5분 안에 확대 중단과 대응이 시작된다.

**검증/증거**

- 스토어 rollout 상태, server cohort 설정, dashboard snapshot
- 단계별 승인자와 timestamp
- 지원 문의 분류·사건 목록

**금지 작업**

- 단계를 건너뛰어 100% 배포
- 스토어 심사 통과를 품질 gate 통과로 간주
- iOS/Android 한쪽 결과를 다른 쪽 승인에 대입
- REL-003에서 승인되지 않은 다른/new listing에 배포
- 네이티브 rollout을 이유로 모바일 웹 배포를 중단

**롤아웃/롤백**

- 위 비율과 관찰 시간을 기본값으로 사용한다.
- gate 위반 시 즉시 스토어 rollout을 pause하고 신규 기능 cohort를 제거하며 REL-016을 실행한다.

---

## REL-016 — 긴급 중단·기능 격리·Forward-fix

**목표**

이미 설치·업데이트된 네이티브 사용자를 이전 바이너리로 강제 복귀시킬 수 없다는 제약 아래 데이터 피해를 멈추고 hotfix를 전달한다. 정상인 모바일 웹은 계속 서비스한다.

**적용 저장소/시스템**

- mobile hotfix: `timefit-mobile`
- server compatibility/Kill Switch/reconciliation: `time_fit`
- App Store/Android 스토어와 incident system

**선행 조건**

- REL-006 Kill Switch
- REL-011 hotfix pipeline
- REL-014 alerts/on-call

**작업**

1. staged/phased rollout을 중지한다.
2. 필요 순서에 따라 Flutter client_type의 write, Realtime, attachment, push를 끈다.
3. backend를 Flutter 전용 호환 경로 또는 client-scoped read-only로 전환한다. 공유 데이터 무결성 사고가 아닌 한 모바일 웹 전체를 중단하지 않는다.
4. 영향 version, 사용자, 조직, 시간 범위를 식별하되 민감 데이터를 incident 채널에 복사하지 않는다.
5. 데이터 reconciliation과 안전한 보정 계획을 만든다.
6. 두 기존 record의 현재 최대값보다 높은 version/build로 hotfix를 생성·검증·제출한다.
7. 사용자 공지, 고객지원, 사후 분석, 재개 승인 절차를 수행한다.
8. staging game day에서 15분 내 차단과 hotfix 테스트 트랙 업로드를 훈련한다.

**산출물**

- incident/rollback runbook
- reconciliation query와 승인 절차
- hotfix pipeline drill report
- 공지·상태 페이지·지원 템플릿

**수용 기준**

- 장애 주입 후 15분 이내 위험 쓰기를 차단한다.
- Flutter가 안전한 read-only/disabled 상태에 진입하고 모바일 웹은 정상 또는 명시적으로 승인된 제한 상태를 유지한다.
- hotfix artifact를 REL-003에서 승인된 테스트 트랙에 만들고 올릴 수 있다.
- 연락망, 권한, 승인자가 실제로 응답 가능하다.

**검증/증거**

- game-day timeline과 목표 시간
- Kill Switch audit log
- hotfix identity/signing 검증
- reconciliation dry-run 결과

**금지 작업**

- 스토어에서 rollout을 멈췄다는 이유로 이미 설치된 앱을 복귀했다고 가정
- 출시 직전/직후 모바일 웹이 사용하는 DB 컬럼·RPC 삭제
- 검증 없는 DB 수동 보정
- 사고 은폐를 위해 telemetry나 audit log 삭제

**롤아웃/롤백**

- 모바일의 실질적 rollback은 기능 격리와 forward-fix다.
- server는 additive 호환 경로로 되돌리고, 조건부 local migration은 copy-on-write 원본에서 복구한다. 재개는 REL-014 gate와 별도 승인 후 네이티브 단계 배포로 시작하며 웹 release train은 독립 유지한다.

---

## REL-017 — 기존 DevGym 스토어 target 제출 잠금·신규 record 방지 게이트

**목표**

최종 제출 직전에 artifact가 REL-003에서 승인한 iOS `데브짐`·Android `데브짐-매니저` target과 정확히 연결되는지 검증하고 identity drift, 신규 record 생성, 무승인 경로 변경을 차단한다.

**적용 저장소/시스템**

- release policy/check: `timefit-mobile`
- identity record: `time_fit`
- App Store Connect/Android 스토어 콘솔의 승인된 target

**선행 조건**

- REL-001~REL-016 완료 또는 승인된 단계 상태
- 최종 release candidate와 metadata

**작업**

1. 제출 화면의 app record/PID/AID와 REL-003 최종 manifest를 2인이 독립 확인한다.
2. 최종 IPA/AAB/APK의 ID, version, entitlement, signing을 다시 추출해 `REUSE_DEVGYM_RECORD` 규칙과 비교한다.
3. store API/CI가 가능하면 허용된 record ID 외 target으로 upload하지 못하게 allowlist한다.
4. 신규 record/production ID가 생성되지 않았고 CI·스토어 API allowlist가 두 승인 target 외 업로드를 차단하는지 확인한다.
5. Technical Gate와 Product/Policy Gate 서명, 사용자 0명 재확인 또는 승인된 migration 계획, 심사 노트가 제출본에 포함됐는지 확인한다.
6. release manager와 security approver, 제품/정책 approver가 final target attestation에 서명한다.
7. ID·서명·제품 승인 blocker가 새로 발생하거나 mode 변경이 필요하면 제출을 중단하고 REL-003을 다시 연다.

**산출물**

- final target/identity attestation
- allowlisted store target policy
- 2인 제출 checklist
- console change log review

**수용 기준**

- 최종 candidate가 플랫폼별 승인된 iOS/Android record에만 연결된다.
- iOS/Android 모두 기존 승인 record만 사용하고 신규 record를 만들지 않는다.
- 두 승인자가 artifact와 record를 직접 검증한다.
- 제품·정책 승인자와 사용자 0명/migration decision 검토자를 포함한 최종 attestation을 갖는다.
- blocker나 경로 변경은 우회하지 않고 출시 중단/REL-003 재승인으로 처리된다.

**검증/증거**

- redacted final binary identity report
- 승인된 target의 version/build history에 candidate가 보이는 캡처
- CI allowlist negative test
- signed attestation

**금지 작업**

- 일정 때문에 승인되지 않은 listing을 “임시” 생성하거나 다른 target으로 전환
- app 이름·아이콘만 비교하고 identity 승인
- 한 명이 build·upload·approve 전부 수행
- 별도 승인 없이 release mode를 변경

**롤아웃/롤백**

- 제출 전에 mandatory gate로 실행한다.
- 불일치 시 upload/promotion을 취소하고 REL-003 또는 REL-011로 돌아간다. 잘못 생성된 빈 record가 있다면 임의 삭제하지 말고 소유자·지원팀과 감사 가능한 정리 절차를 밟는다.

---

## REL-018 — 병렬 운영 안정화·임시 호환 계층 정리·감사 보존

**목표**

네이티브 출시 안정화 후 Flutter 출시용으로 만든 임시 flag·adapter·alias만 사용량과 owner 승인에 따라 정리한다. 모바일 웹과 그 활성 계약은 종료·삭제 대상이 아니다.

**적용 저장소/시스템**

- 임시 API/DB/push compatibility cleanup: `time_fit`
- Flutter temporary alias/승인된 DevGym reader cleanup: `timefit-mobile`
- artifact archive와 스토어 설정

**선행 조건**

- 네이티브 100% 배포 후 최소 90일 또는 제품이 정한 더 긴 관찰 기간
- 제거 대상 임시 경로 호출 14일 연속 0, consumer owner 승인
- 모바일 웹 golden/contract test 통과, 고객지원 예외 0, reconciliation 완료

**작업**

1. 임시 endpoint, RPC version, payload alias, redirect, feature flag, `REQUIRED`로 구현된 DevGym reader의 사용량과 consumer를 최종 확인한다.
2. 각 제거 후보를 `Flutter temporary`, `DevGym compatibility`, `mobile-web active`, `shared permanent`로 분류한다.
3. 모바일 웹 소유자가 사용하는 경로는 호출량과 무관하게 웹 deprecation 절차 없이는 제거하지 않는다.
4. 제거 가능한 임시 경로를 경고/측정 단계로 전환한 뒤 호출 0과 owner 승인을 확인한다.
5. dual-read/write, temporary flag, alias/parser를 작은 변경으로 나눠 제거하고 매 단계 웹·Flutter contract/E2E를 실행한다.
6. destructive DB migration은 모든 consumer 승인, backup·restore rehearsal, 별도 change request를 거쳐 수행한다.
7. 사용하지 않는 네이티브 전용 push credential·redirect와 접근 권한만 폐기/rotation한다. 웹 credential을 함께 폐기하지 않는다.
8. 고정된 `REUSE_DEVGYM_RECORD`의 최초 Flutter/이전 DevGym artifact, symbols, schema, checksum, decision record와 runbook을 보존한다.
9. 웹·Flutter 병렬 아키텍처, data flow, on-call 문서를 갱신한다.

**산출물**

- client_type/owner가 포함된 deprecation usage report
- cleanup PR/migration 세트
- backup/restore rehearsal report
- immutable native release/decision archive와 병렬 운영 문서

**수용 기준**

- 제거한 임시 경로 호출 없이 웹·Flutter 기능과 SLO가 유지된다.
- 삭제된 호환 코드/DB 변경마다 rollback 또는 restore 계획이 있다.
- 감사용 release artifact·release-mode decision·계약 문서가 보존된다.
- 모바일 웹/PWA 활성 코드와 계약이 유지되고 AI/AX 범위를 cleanup 명목으로 변경하지 않는다.

**검증/증거**

- 14일 usage query, client owner 승인, 고객지원 확인
- backup restore checksum 및 rehearsal 결과
- cleanup 전후 contract/E2E/performance diff
- archive 위치·보존 기간·소유자 기록

**금지 작업**

- 관찰 기간·호출 0·consumer owner 승인 전에 임시 API 삭제
- backup/restore 검증 없는 destructive migration
- 모바일 웹에서 사용하는 API/RPC/DB/push/link 경로 삭제
- native release/decision artifact 영구 삭제
- 관련 없는 모바일 웹/PWA·AI·AX 코드 정리로 범위 확대

**롤아웃/롤백**

- 경고→호출 차단 실험→코드 제거→DB contract 순서로 단계화한다.
- 회귀 시 최근 단계만 되돌리고 이전 호환 endpoint/flag를 재활성화한다. 모바일 웹 배포는 독립 유지하고 DB는 rehearsal한 backup/forward restoration 절차를 사용한다.

---

## 10. 릴리스 승인 체크리스트

### Identity

- [ ] REL-003에서 두 플랫폼의 `REUSE_DEVGYM_RECORD`와 정확한 기존 store target이 승인됐다.
- [ ] 기술 연속성과 제품·정책 연속성 Gate가 모두 Go이고 최종 archive/artifact의 ID·서명·entitlement·version이 기존 record와 일치한다.
- [ ] REL-001의 스토어 설치/활성 기기·backend installation/push token·활성 구독/IAP 증거가 같은 기준 시각으로 0을 확인했거나, 발견된 기존 사용자에 대한 migration 계획이 승인됐다.
- [ ] 두 플랫폼 모두 기존 최대 version/build보다 높다.
- [ ] 최종 artifact가 승인된 TestFlight/Android 테스트 트랙에 수락됐다.
- [ ] 승인되지 않은 중복 record·상품·ID가 생성되지 않았다.

### Repository boundary

- [ ] Flutter 앱·테스트·CI는 독립 `timefit-ax_agent`에 있고 승인된 visibility와 실제 설정 evidence가 일치한다.
- [ ] 모바일 웹과 DB/RLS/RPC/Edge Functions의 원본은 `time_fit`에 있고 웹 배포가 계속된다.
- [ ] 계약 버전과 양쪽 commit/deploy ID가 release manifest에 연결됐다.
- [ ] PWA 구현은 Flutter release scope에 없으며 기존 모바일 웹/PWA 트랙을 변경·중단하지 않았다.
- [ ] AI/AX dependency와 산출물이 release scope에 없다.

### Compatibility and data

- [ ] 모바일 웹과 Flutter가 같은 backend에서 동시 동작하고 웹 golden test가 회귀 없이 통과했다.
- [ ] TimeFit clean-install E2E와 두 기존 DevGym 설치본의 앱 삭제 없는 upgrade E2E가 Critical matrix 100% 통과했다.
- [ ] session/local data/outbox/push/link의 namespace 충돌·중복·유실·노출이 0건이다.
- [ ] client-scoped Kill Switch와 read-only mode를 staging에서 훈련했고 웹 비영향을 확인했다.

### Security and operations

- [ ] secret scan에서 운영 비밀이 0건이다.
- [ ] production artifact는 debug signing·placeholder ID를 포함하지 않는다.
- [ ] telemetry가 token·메시지 본문·signed URL을 수집하지 않는다.
- [ ] dashboard, alert, on-call, hotfix pipeline이 준비됐다.
- [ ] 단계별 승인자와 중단 기준이 지정됐다.

---

## 11. 위험 등록부

| 위험 | 영향 | 조기 신호 | 예방/완화 | 중단 조건 |
| --- | --- | --- | --- | --- |
| 선택된 store target/ID를 잘못 적용 | 오배포 또는 업로드 실패 | manifest/console/artifact 불일치 | REL-003 결정, REL-017 2인 대조, CI allowlist | 불일치 1건 |
| DevGym→TimeFit 제품 전환 심사·신뢰 위험 | 심사 거절, 사용자 혼란, 법무/지원 이슈 | 사전 검토 미승인, 문의·리뷰 증가 | 정확한 변경 공개, 기술/제품·정책 이중 Gate, 0명 evidence | Product/Policy Gate No-Go 또는 승인 철회 |
| legacy population·처리 계획 오판 | 숨은 설치·구독자의 데이터/권리 침해 | store/backend/IAP 지표 불일치 또는 승인 범위 밖 사용자 발견 | 동일 기준 시각 export와 reconciliation, `USER_ATTESTED`와 독립 증거 구분, production 직전 재확인 | 처리 계획 미승인, consent/지원 범위 불일치 또는 조회 불능 |
| Android signing key 부재 | DevGym 재사용 불가 | 테스트 트랙 서명 거부 | 공식 키 복구 절차와 소유자 escalation | 기술 연속성 미증명 |
| iOS entitlement drift | update에서 세션·푸시·링크 단절 | Keychain/APNs/Universal Link 실패 | DevGym binary entitlement diff와 update E2E | Critical capability 실패 |
| legacy local migration 오류 | `REQUIRED` cohort의 유실·중복·crash loop | migration 실패율 상승 | 0명 증명 시 N/A; 필요 시 copy-on-write/journal | 실패율 > 0.5% 또는 유실 1건 |
| 모바일 웹 계약 조기 변경 | 운영 웹 사용자 장애 | web golden/SLO 회귀 | additive contract, web owner 승인, consumer tests | 웹 핵심 오류 증가 |
| push 중복/오발송 | 사용자 신뢰·정보 노출 | event/token 중복 증가 | installation registry, event dedupe | 보호 데이터 오발송 1건 |
| 승인되지 않은 listing/record 사용 | 잘못된 사용자·리뷰·브랜드 연결 | 다른 record ID/upload target | REL-017 2인 승인/allowlist | 즉시 제출 중단 |
| client namespace 충돌 | 웹/앱 세션·푸시·링크 오연결 | 다른 client token/route 변경 | client_type, installation, link namespace 격리 | 교차 노출·오발송 1건 |
| scope creep(PWA/AI/AX) | 일정·개인정보 범위 확대 또는 웹 트랙 방해 | Flutter 티켓에서 웹/AI 코드 변경 | dependency allowlist, repo owner review, 별도 backlog | 무승인 관련 변경 탐지 |

---

## 12. 공식 기준 참고

실행 시점에는 스토어 콘솔의 최신 안내를 다시 확인한다.

- Apple App Store Connect — [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/): 빌드 업로드 후 Bundle ID를 변경할 수 없고 Xcode project 값과 일치해야 한다.
- Apple App Store Connect — [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/): Bundle ID와 version 정보로 build를 앱/버전 레코드에 연결한다.
- Apple Developer — [App Review Guidelines 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata): metadata는 실제 핵심 경험과 일치해야 하고, 새 기능·제품 변경은 Review Notes와 What's New에 구체적으로 밝혀야 한다.
- Android Developers — [Configure the app module](https://developer.android.com/build/configure-app-module): 게시 후 application ID를 바꾸지 않으며 기존 업데이트는 같은 application ID와 signing certificate를 사용한다.
- Android Developers — [Sign your app](https://developer.android.com/studio/publish/app-signing): 기기 업데이트는 호환되는 signing certificate를 요구하며 upload key와 app-signing key를 구분한다.
- Google Play Console Help — [Update or unpublish your app](https://support.google.com/googleplay/android-developer/answer/9859350): 업데이트 bundle은 같은 package, 더 높은 versionCode, 같은 signature를 요구한다.
- Google Play Console Help — [Deceptive Behavior](https://support.google.com/googleplay/android-developer/answer/9888077): 버전 간 기능이 크게 바뀌면 사용자에게 알리고 스토어 listing을 갱신해야 하며, 제목·설명·이미지는 실제 기능을 정확히 반영해야 한다.
- ONE store Developer Center — [상품등록과 관리](https://onestore-dev.gitbook.io/dev/docs/apps): 기존 PID 아래 OS별 AID와 Android binary를 관리한다.
- ONE store Developer Center — [상품 FAQ](https://onestore-dev.gitbook.io/dev/help/faq/apps): 기존 상품 업데이트와 더 높은 versionCode 요구사항을 안내한다.
- ONE store Developer Center — [Android App Bundle·키 관리](https://onestore-dev.gitbook.io/dev/help/faq/apps/one-store-android-app-bundle): 다중 스토어 업데이트의 signing key 일치와 AAB 전환 시 주의사항을 안내한다.

---

## 13. 최종 승인 문구

> TimeFit Flutter iOS/Android 앱은 public 독립 `sh414lim/timefit-ax_agent` 저장소에서 개발한다. 사용자는 추적 내부 문서와 기존 Git 이력의 인터넷 공개를 포함한 public visibility 전환을 승인했고 Release 세션이 실제 visibility와 익명 read를 확인했다. 기존 `time_fit` 저장소는 계속 개발·배포되는 모바일 웹앱과 Supabase·서버 계약의 canonical source로 유지하며, 웹과 Flutter는 같은 계정·데이터를 쓰는 병렬 클라이언트다. Flutter는 PWA를 구현하지 않지만 기존 모바일 웹/PWA를 대체·중단·종료하지 않는다. 네이티브 출시는 Android `데브짐-매니저`와 iOS `데브짐`의 기존 배포 record를 업데이트하는 경로로 확정한다. 두 record의 정확한 ID·서명 계보·entitlement·상향 version/build, 제품·법무·스토어 정책·metadata Gate가 모두 Go일 때만 제출한다. REL-001의 현재 비식별 관측은 zero-user를 증명하지 않으므로 `legacyUserMigrationDecision=REQUIRED`를 유지한다. 기존 사용자 전원 동의와 데이터 미이전 결정은 `USER_ATTESTED_DO_NOT_MIGRATE`로 구분하며, 승인된 실행 계획은 legacy 데이터를 TimeFit으로 가져오지 않고 원본을 보존하고 fresh login, 새 local namespace와 신규 push 동의·등록을 사용한다. 이 결정은 consent 원본 검증, 데이터 삭제, 서비스 종료, 결제/IAP 부재 또는 출시 승인이 아니다. 저장소 visibility는 credential 공개나 보호 기능 활성화를 뜻하지 않으며, 별도 Git 저장소 사용은 동일 store record 업데이트를 방해하지 않는다. REL-003에서 제출 가능성을 승인하고 REL-017에서 기존 target만 잠근다. 현재 저장소의 `com.example.*` 값과 문서상 `com.timefit.app` 계획값은 production identity의 증거가 아니다. AI/AX는 이번 Flutter 릴리스 범위에서 제외한다.
