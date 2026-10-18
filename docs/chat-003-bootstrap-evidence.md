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

## dependency 해석 차단

`docs/147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md` 2.1의 버전을 그대로 적용하고 다음 명령을 실행했다.

```bash
flutter pub get
```

결과는 exit code `1`이다.

```text
supabase_flutter 2.18.0
  -> supabase_common 0.1.2
  -> crypto ^3.0.7

catalog exact pin: crypto 3.0.6
```

두 제약은 동시에 만족할 수 없어 새 `pubspec.lock`을 만들 수 없다. `crypto` 상향, `supabase_flutter` 하향 또는 `dependency_overrides`는 명세 변경이므로 이 변경에서 임의 적용하지 않았다.

## 검증 상태

- 실행 가능: Dart format, repository boundary 검사
- 차단: `pub get --enforce-lockfile`, analyze, unit/widget, Android debug build, iOS no-codesign build
- 차단 해제 조건: 설계 원본의 충돌 dependency version 결정 및 문서 개정

민감정보, 운영 식별자, signing 설정, provider 설정은 추가하지 않았다.
