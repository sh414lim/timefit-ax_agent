# CHAT-003 비서명 bootstrap gap 증거

- 기준 revision: `4e60a60f6d33f79c8b2bb3bd663c24a6ea3d01ea`
- 범위: `.fvmrc`, exact dependency, lockfile, clean-checkout 명령, dev/staging 비서명 smoke
- production identity·signing·provider 연결: 미설정 유지

## 확인한 도구 체인

```text
Flutter 3.38.5 (framework revision f6ff1529fd)
Dart 3.10.4
```

현재 실행 환경에는 `fvm` executable이 없어 설치된 공식 Flutter SDK의 동일 버전으로 version 확인과 dependency solver를 실행했다. `.fvmrc` 기반 clean-checkout 명령은 dependency 충돌이 해소된 뒤 FVM 환경에서도 재검증해야 한다.

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
- Android dev/staging debug: 실패

Android 실패 원인은 명세 고정 `file_picker 8.0.0+1`이 Flutter 3.38.5에서 제거된 v1 embedding API `PluginRegistry.Registrar`를 참조하기 때문이다. dev와 staging 모두 `:file_picker:compileDebugJavaWithJavac`에서 동일하게 실패했다. package의 Linux/macOS/Windows default implementation metadata 경고는 analyze·test와 iOS build에서 비치명적이었지만, Android source 호환성은 실제 build blocker다.

`flutter_local_notifications 17.2.4`가 요구하는 core library desugaring은 해당 package의 동봉 README/build 설정에 명시된 `desugar_jdk_libs 1.2.2`로 활성화했다. 이 보완 뒤 Android build는 다음 단계인 `file_picker` compile까지 진행했다.

차단 해제에는 Flutter 3.38.5와 호환되는 `file_picker` exact version을 설계 원본에서 승인해야 한다. 버전 변경이나 pub-cache source patch는 임의 적용하지 않았다.

민감정보, 운영 식별자, signing 설정, provider 설정은 추가하지 않았다.
