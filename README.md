# timefit-ax_agent

TimeFit Flutter 네이티브 iOS/Android 앱의 실제 소스 저장소입니다.

## 참고 대상

- 기존 TimeFit 저장소: <https://github.com/sh414lim/time-fit>
- 기존 저장소는 읽기 전용 참고 대상으로 취급합니다.
- 이 저장소에는 기존 TimeFit 원본 코드를 복사하거나, submodule·빌드 의존성으로 연결하지 않습니다.
- 기존 계획 문서의 `timefit-mobile`은 이 저장소를 가리키며 별도 저장소를 뜻하지 않습니다.

## 분리 원칙

- Git 이력, 코드, 빌드, 테스트, 배포 파이프라인을 기존 TimeFit과 분리합니다.
- 운영 배포나 외부 서비스 연결은 별도 승인과 설계 없이 구성하지 않습니다.
- 토큰, 비밀번호, API 키, 인증서 및 다른 자격증명을 Git에 저장하지 않습니다.
- 기존 TimeFit의 변경이 필요하면 이 저장소에서 직접 수정하지 않고, 별도로 승인된 작업에서 처리합니다.

## 현재 상태

Flutter 3.38.5와 Dart 3.10.4로 생성한 iOS/Android 최소 bootstrap이 있습니다. 앱 기능, 외부 서비스 연결, production identity, signing, store upload는 아직 구성하지 않았습니다.

- `dev`: `lib/main.dart`, 명시적인 dev bundle/application ID 사용
- `staging`: `lib/main_staging.dart`, 명시적인 staging bundle/application ID 사용
- `production`: 승인된 identity와 signing이 없어 실행 및 빌드 대상에서 제외

네이티브 flavor와 Dart entrypoint가 일치하지 않으면 Android Gradle 또는 iOS Xcode build가 실패합니다.

## 로컬 실행과 검증

```bash
flutter pub get
flutter analyze
flutter test

# Android
flutter run --flavor dev -t lib/main.dart
flutter run --flavor staging -t lib/main_staging.dart

# iOS 서명 없는 build smoke
flutter build ios --debug --no-codesign --flavor dev -t lib/main.dart
flutter build ios --debug --no-codesign --flavor staging -t lib/main_staging.dart
```

production identifier나 signing credential을 로컬 파일에 입력하지 않습니다. Apple·Android production 설정은 REL-001/003 승인 후 별도 변경으로 적용합니다.

## CI 도구 체인

- iOS smoke job은 GitHub-hosted `macos-15` runner와 `/Applications/Xcode_16.4.app`의 Xcode 16.4 (`16F6`)를 사용합니다.
- `macos-14`는 2026-11-02 지원 종료 예정이며, 종료 전 brownout 동안 작업이 강제 실패하므로 지원 runner로 이동했습니다.
- `actions/checkout`은 Node 24 기반 `v5.1.0`의 검증된 커밋 `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`로 고정합니다.
- CI는 Flutter 3.38.5를 소스 SHA로 검증한 뒤 Android와 iOS의 `dev`·`staging` debug build를 실행합니다. iOS build는 서명 없이 수행합니다.

참고: [macOS 14 runner image retirement](https://github.blog/changelog/2026-10-01-github-actions-macos-14-runner-image-retirement/), [macOS 15 runner image software](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), [Node 20 retirement](https://github.blog/changelog/2026-09-23-node-20-is-no-longer-available-in-github-actions/)

## 로컬 참고 설정

개발자별 기존 TimeFit 체크아웃 경로는 `.timefit-reference.local`에만 기록합니다. 이 파일은 Git에서 제외되며 공유 문서나 스크립트에 절대 경로를 하드코딩하지 않습니다.

예시 형식:

```text
TIMEFIT_REFERENCE_PATH=/absolute/path/to/time-fit
```

`.timefit-reference.local`은 빌드 입력이나 커밋 대상이 아닙니다.
