# CHAT-003 비서명 bootstrap gap 증거

- 기준 revision: `4e60a60f6d33f79c8b2bb3bd663c24a6ea3d01ea`
- 범위: `.fvmrc`, exact dependency, lockfile, clean-checkout 명령, dev/staging 비서명 smoke
- production identity·signing·provider 연결: 미설정 유지

## 확인한 도구 체인

```text
Flutter 3.38.5 (framework revision f6ff1529fd)
Dart 3.10.4
```

초기 실행 환경에는 `fvm` executable이 없어 설치된 공식 Flutter SDK의 동일 버전으로 version 확인과 dependency solver를 실행했다. 이후 clean `main`에서 수행한 FVM 재검증 결과는 아래에 별도로 기록한다.

## dependency 해석

`docs/147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md` 2.1의 버전을 그대로 적용하고 다음 명령을 실행했다.

```bash
flutter pub get
```

초기 기준선의 `crypto 3.0.6`은 `supabase_flutter 2.18.0`의 전이 제약 `crypto ^3.0.7`과 충돌했다. 설계 정정 PR #13이 `crypto 3.0.7` exact를 승인하고 main `69d04c75ed65b408dd409723766246371f00c187`에 병합된 뒤 다음 결과를 얻었다.

```text
flutter pub get: exit 0
pubspec.lock: generated
crypto direct lock: 3.0.7
```

명세 밖 package 상향·하향 또는 `dependency_overrides`는 적용하지 않았다.

## 검증 상태

- Flutter `3.38.5`, Dart `3.10.4`: 확인
- Dart format: 통과
- Flutter analyze: 통과
- unit/widget/smoke: 6개 통과
- repository boundary 검사: 통과
- iOS dev/staging `--no-codesign`: 통과
- Android dev/staging debug: 통과

초기 CI의 iOS dev build는 clean runner에서 flavor별 CocoaPods xcconfig가 Runner configuration에 연결되지 않아 `PODS_ROOT`가 비어 실패했다. dev/staging별 Debug/Profile/Release Flutter xcconfig를 명시적으로 연결하고, 기존 `ios/Pods`를 치운 상태에서 `pod install`부터 다시 수행한 뒤 iOS dev/staging 비서명 build가 모두 통과하는 것을 확인했다.

초기 Android 실패 원인은 명세 고정 `file_picker 8.0.0+1`이 Flutter 3.38.5에서 제거된 v1 embedding API `PluginRegistry.Registrar`를 참조했기 때문이다. dev와 staging 모두 `:file_picker:compileDebugJavaWithJavac`에서 동일하게 실패했다. 설계 정정 PR #14가 `file_picker 8.1.0` exact를 승인하고 main `644c72307b47c98142efd7c43fa110c4f4414e63`에 병합되어 이 브랜치에 반영했다.

정정 반영 뒤 `flutter pub get --enforce-lockfile`, Android dev/staging debug, iOS dev/staging 비서명 build를 다시 실행했고 모두 통과했다. lockfile의 `file_picker` 직접 해석 버전은 `8.1.0`이다.

`flutter_local_notifications 17.2.4`가 요구하는 core library desugaring은 해당 package의 동봉 README/build 설정에 명시된 `desugar_jdk_libs 1.2.2`로 활성화했다. 이 보완 뒤 Android build는 다음 단계인 `file_picker` compile까지 진행했다.

명세 밖 버전 변경이나 pub-cache source patch는 적용하지 않았다.

민감정보, 운영 식별자, signing 설정, provider 설정은 추가하지 않았다.

## FVM clean-checkout 재검증 (2026-10-19 UTC)

- 기준 revision: `c5ee59c8d700e02e3a68959d43da5fe19789036f`
- FVM: pub.dev 공식 `fvm 4.3.2`를 임시 `PUB_CACHE`에 설치해 사용
- SDK: `.fvmrc`의 Flutter `3.38.5`, Dart `3.10.4`, framework `f6ff1529fd`
- 전역 PATH, 저장소 FVM 설정, dependency 파일: 변경 없음
- `pubspec.lock` SHA-256 전후 동일: `567aa7f5bdc661318185366e2e595245b2af2428eb39d66136785a7cb68197ec`

다음 README 및 CI 경로를 FVM wrapper로 실행해 통과했다.

```text
fvm flutter pub get: PASS
locked dependency enforcement: PASS
dart format: PASS (35 files)
flutter analyze: PASS (no issues)
unit/widget tests: PASS (19 tests)
repository boundary validation: PASS
bash scripts/ci_mobile.sh: PASS (Android dev/staging debug)
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bash scripts/ci_mobile.sh ios: PASS (iOS dev/staging debug --no-codesign)
```

기존 catalog의 flavor 없는 generic 명령은 현재 프로젝트 구조와 맞지 않았다. Android generic 명령은 flavor APK를 만든 뒤 기본 APK 위치를 찾다가 실패했고, iOS generic 명령은 dev/staging scheme 때문에 Xcode 실행 전에 `--flavor`를 요구하며 실패했다. 따라서 CHAT-003의 수용 명령은 README 및 `scripts/ci_mobile.sh`와 동일한 dev/staging flavor와 entrypoint를 명시해야 한다.

초기 `LC_ALL=C` iOS 시도는 CocoaPods의 UTF-8 요구 때문에 실패했으며 UTF-8 locale에서 성공했다. Build runner가 pinned analyzer 언어 버전에 대한 경고를 출력했지만 generation과 fatal analysis는 통과했고 dependency 또는 lockfile 변경은 없었다.

이 재검증은 비서명 dev/staging 범위만 다룬다. production identity, signing credential, provider 설정, 사용자 데이터에는 접근하거나 변경하지 않았고, release 승인이나 CHAT-003 완료를 의미하지 않는다.
