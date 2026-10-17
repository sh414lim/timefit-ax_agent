# REL-001 기존 배포 앱 정체성 감사 초안

## 1. 문서 상태와 범위

이 문서는 기존 배포 앱 소스로 지정된 [`tpghks521/dev_manager`](https://github.com/tpghks521/dev_manager)를 읽기 전용으로 조사한 source baseline이다. 저장소 이름, 앱 표시명 또는 코드상의 식별자가 Android `데브짐-매니저`나 iOS `데브짐` 스토어 레코드와 같다는 결론을 의미하지 않는다.

```yaml
auditGeneratedAt: 2026-10-17
sourceRepository: https://github.com/tpghks521/dev_manager
sourceBranch: main
sourceCommit: 06b15237efd37168ef9305c5e12a7872ba5a489b
evidenceStatus: SOURCE_REPOSITORY_REVIEWED_CONSOLE_PENDING
storeRecordMatch: PENDING
legacyUserMigrationDecision: PENDING
as_of: null
```

`as_of`는 App Store Connect, Android 배포 콘솔, 백엔드와 구독/IAP 증거를 동일 시각 기준으로 확보할 때만 채운다. 현재 저장소 조사만으로 사용자·설치·구독이 0명이라고 판정하지 않는다.

## 2. 플랫폼 식별 후보

| 항목 | 저장소 후보 값 | 근거 | 현재 판정 |
| --- | --- | --- | --- |
| Android namespace | `com.leofitTech.devmanager.admin.dev_manager` | [`android/app/build.gradle.kts`](https://github.com/tpghks521/dev_manager/blob/main/android/app/build.gradle.kts) | 콘솔·운영 AAB/APK 대조 필요 |
| Android applicationId | `com.leofitTech.devmanager.admin.dev_manager` | [`android/app/build.gradle.kts`](https://github.com/tpghks521/dev_manager/blob/main/android/app/build.gradle.kts) | 콘솔·운영 AAB/APK 대조 필요 |
| Android 표시명 | `BroGym` | [`android/app/src/main/AndroidManifest.xml`](https://github.com/tpghks521/dev_manager/blob/main/android/app/src/main/AndroidManifest.xml) | 스토어명과 동일성 미확인 |
| iOS Xcode Bundle ID 후보 | `com.leofitTech.devmanager.admin.devManager.v1` | [`ios/Runner.xcodeproj/project.pbxproj`](https://github.com/tpghks521/dev_manager/blob/main/ios/Runner.xcodeproj/project.pbxproj) | App Store Connect·운영 IPA 대조 필요 |
| iOS Team ID 후보 | `729TVX5977` | [`ios/ExportOptions.plist`](https://github.com/tpghks521/dev_manager/blob/main/ios/ExportOptions.plist) | Apple Developer Team 확인 필요 |
| iOS 표시명 | `BroGym` | [`ios/Runner/Info.plist`](https://github.com/tpghks521/dev_manager/blob/main/ios/Runner/Info.plist) | 스토어명과 동일성 미확인 |
| Flutter 버전 | `1.0.1+11` | [`pubspec.yaml`](https://github.com/tpghks521/dev_manager/blob/main/pubspec.yaml) | 스토어 최대 version/build 아님 |

Android에는 `productFlavors`가 없고 iOS에는 단일 `Runner` scheme과 Debug/Profile/Release 구성만 확인됐다. dev/staging/production flavor가 이미 존재한다고 간주하지 않는다.

### iOS 식별자 불일치

- Xcode project: `com.leofitTech.devmanager.admin.devManager.v1`
- `GoogleService-Info.plist`: `com.leofitTech.devmanager.admin.devManager`
- generated Firebase options: `com.leofittech.devmanager.admin.v3`

세 값 중 어느 것도 승인된 production Bundle ID로 바로 복사하지 않는다. App Store Connect record, 마지막 운영 IPA, Apple Developer identifier, Firebase iOS app 등록을 교차 검증해야 한다.

## 3. 서명과 배포 구조

### Android

- [`android/app/build.gradle.kts`](https://github.com/tpghks521/dev_manager/blob/main/android/app/build.gradle.kts)는 `android/key.properties`와 `android/app/upload-keystore.jks` 위치를 전제로 한다.
- 실제 key, alias, 비밀번호, 인증서와 서비스 계정 값은 이 문서에 기록하거나 새 저장소로 복사하지 않는다.
- [`android-play.yml`](https://github.com/tpghks521/dev_manager/blob/main/.github/workflows/android-play.yml)은 GitHub secrets에서 keystore와 Play 서비스 계정을 복원해 internal track으로 올린다.
- `key.properties`가 없을 때 release가 debug signing으로 fallback하는 기존 동작은 production 설계에 재사용하지 않는다.
- app-signing certificate와 upload credential의 관계, Play App Signing 사용 여부 및 최대 versionCode는 콘솔과 마지막 운영 artifact로 확인한다.

### iOS

- [`ios/ExportOptions.plist`](https://github.com/tpghks521/dev_manager/blob/main/ios/ExportOptions.plist)은 `app-store`, automatic signing과 Team ID 후보를 사용한다.
- [`ios-testflight.yml`](https://github.com/tpghks521/dev_manager/blob/main/.github/workflows/ios-testflight.yml)과 [`ios/testflight.sh`](https://github.com/tpghks521/dev_manager/blob/main/ios/testflight.sh)는 App Store Connect API key를 런타임에 주입한다.
- API key ID, issuer ID, `.p8`, provisioning profile과 인증서는 복사하거나 문서화하지 않는다.
- entitlements 파일과 `CODE_SIGN_ENTITLEMENTS` 설정은 저장소에서 확인되지 않았다. Keychain/App Group, Associated Domains와 APNs entitlement는 운영 IPA와 Apple 콘솔에서 확인한다.

GitHub Actions는 `main` 자동 배포가 아니라 수동 실행 또는 `android-int-*`, `ios-tf-*` 태그를 사용한다. 기존 pipeline은 참고 대상으로만 보며 `timefit-ax_agent`에 연결하거나 그대로 복제하지 않는다.

## 4. Firebase, push, deep link와 권한

- Firebase project 후보는 `dev-manager-bd0b4`다. Android Firebase app은 applicationId 후보와 일치하지만 iOS Firebase 설정은 Bundle ID 후보들과 불일치한다.
- `google-services.json`, `GoogleService-Info.plist`, generated Firebase options에는 client key가 포함된다. 파일이나 key 값을 새 앱에 복사하지 않고 REL-001/003에서 승인된 Firebase app 설정만 별도로 주입한다.
- `firebase_messaging`, FCM device-token 등록 및 APNs 연결 구현은 확인되지 않았다. 기존 코드의 `NotificationSender`는 Supabase `notifications` 테이블 INSERT이며 push delivery 증거가 아니다.
- Android manifest에는 `INTERNET`만 확인되며 VIEW/BROWSABLE deep-link intent-filter가 없다. `usesCleartextTraffic=true`는 재사용하지 않는다.
- iOS Info.plist에는 URL scheme이 없고 Associated Domains/APNs entitlement도 확인되지 않았다. `NSAllowsArbitraryLoads=true`는 재사용하지 않는다.
- GoRouter의 pending URI 메모리 처리는 OS deep-link 등록 증거가 아니다.

## 5. 인증, API와 백엔드 연결

- 앱은 Supabase 이메일/비밀번호 인증과 직접 DB 접근을 사용한다.
- source에는 특정 Supabase project endpoint와 client anon key가 하드코딩돼 있다. endpoint는 inventory 대상으로만 취급하고 key 값은 이 문서에 기록하지 않는다.
- Kakao REST client key도 source에 하드코딩돼 있다. 값과 기존 OAuth 설정을 복사하지 않는다.
- 로컬 datasource는 사용자 객체와 access token을 `SharedPreferences`에 저장한다. 평문 token 캐시는 새 앱에 재사용하지 않는다.
- `flutter_secure_storage`는 dependency에는 있지만 실제 사용 근거가 확인되지 않았다.
- 기존 계정 삭제 구현은 실제 삭제가 아니라 로그아웃만 수행한다.
- `dev_manager`의 `lib/docs/migrations` 및 SQL 문서는 legacy 참고 자료다. 공유 DB/RLS/RPC/migration의 canonical source는 계속 기존 `time_fit`이며 이 저장소로 복사하지 않는다.

## 6. 재사용 경계

### 검증 후 identity manifest에 기록할 수 있는 후보

- Android applicationId·namespace와 iOS Bundle ID·Team ID 후보
- Firebase project/app 식별 후보와 플랫폼별 등록 관계
- Flutter toolchain `3.38.5` 및 기존 version/build 산정 방식
- signing 설정 위치, 배포 trigger 및 필요한 역할의 종류
- source provenance: `tpghks521/dev_manager@06b15237efd37168ef9305c5e12a7872ba5a489b`

위 항목도 스토어 콘솔과 마지막 운영 binary로 일치가 확인되기 전에는 production 값이 아니다.

### 재사용하지 않을 항목

- keystore, `.p8`, 서비스 계정, API/OAuth key, token, 비밀번호, 인증서와 GitHub secret 값
- Firebase 설정 파일과 hardcoded Supabase/Kakao client 설정
- debug-signing fallback, 평문 access-token cache
- unrestricted cleartext/ATS 설정
- WebView와 기존 관리자 앱 기능 코드
- legacy schema, SQL, 인증·사용자 자동생성 및 알림 구현
- 기존 CI/CD와 배포 권한의 직접 연결

## 7. 콘솔·운영 artifact 확인 목록

모든 export는 가능한 한 같은 `as_of`와 timezone, 조회 범위, 수행 계정을 기록한다.

- [ ] Android `데브짐-매니저` record URL, 내부 ID, 소유 계정과 package name
- [ ] Play App Signing certificate fingerprint, upload certificate, 최대 versionCode와 마지막 운영 AAB/APK checksum
- [ ] iOS `데브짐` App Store Connect URL, Apple ID, Bundle ID, Team, 최대 version/build
- [ ] 마지막 운영 IPA의 Bundle ID, Team, entitlements, provisioning 및 checksum
- [ ] Firebase Android/iOS app package·Bundle ID, project owner, APNs topic과 FCM 설정
- [ ] OAuth callback, URL scheme, Universal/App Links 및 웹 도메인 소유권
- [ ] App Store/Play 현재 설치·활성 기기와 최근 30/90일 활성 지표
- [ ] backend installation, 최근 접속, session, push token과 사용자 연결 수
- [ ] 활성 구독, IAP, 미정산 거래와 복원 가능한 entitlement
- [ ] DevGym 평점·리뷰·개인정보·브랜드·지원 채널과 TimeFit 전환 영향
- [ ] Owner, Release Manager, Backup Approver 및 실제 제출/복구 역할

## 8. Evidence 상태와 REL-001 완료 조건

현재 상태는 다음과 같다.

| Evidence 묶음 | 상태 | 완료 기준 |
| --- | --- | --- |
| source provenance | `SOURCE_REVIEWED` | commit·repository·platform 파일 링크 유지 |
| Android technical continuity | `PENDING_CONSOLE_AND_BINARY` | record/package/signing/version/artifact 일치 |
| iOS technical continuity | `PENDING_CONSOLE_AND_BINARY` | record/Bundle ID/Team/entitlement/version/artifact 일치 |
| product/policy continuity | `PENDING_OWNER_REVIEW` | 브랜드·metadata·개인정보·지원 영향 승인 |
| zero-user evidence | `PENDING` | 동일 `as_of`의 store/backend/subscription 증거 모두 0 |
| access continuity | `PENDING` | 최소 두 명의 제출·복구 경로 확인 |

REL-001은 다음을 모두 충족할 때만 완료한다.

1. Android와 iOS record의 실제 운영 식별자와 소유권을 콘솔에서 확인한다.
2. 마지막 운영 binary에서 identifier, signing lineage, entitlement와 version/build를 추출해 콘솔과 대조한다.
3. 기술적으로 update 가능하다는 판정과 제품·정책상 전환 가능하다는 판정을 분리한다.
4. 동일 `as_of`의 설치·활성 기기, backend installation·push token, 구독/IAP 증거로 `legacyUserMigrationDecision`을 `PENDING`, `REQUIRED`, `NOT_APPLICABLE_ZERO_VERIFIED` 중 하나로 승인한다.
5. 미확인 또는 불일치가 있으면 `BLOCKED_PENDING_RECOVERY`로 유지하고 신규 store record나 추측한 production ID로 우회하지 않는다.

## 9. 사용자에게 필요한 최소 콘솔 입력

다음 두 묶음이면 다음 감사 단계를 진행할 수 있다.

1. Android: 해당 Play/배포 콘솔의 앱 개요·App Signing·최근 설치 지표 화면과 마지막 운영 AAB/APK 정보에 대한 읽기 접근 또는 redacted export.
2. iOS: 해당 App Store Connect 앱 정보·빌드·사용 지표와 Apple Developer identifier/entitlement 화면에 대한 읽기 접근 또는 redacted export.

두 묶음 모두 record URL, 조회 시각/timezone과 조회 계정을 함께 제공하고 비밀번호·private key·인증서 원문은 공유하지 않는다.
