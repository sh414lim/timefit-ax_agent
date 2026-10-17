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

## 로컬 참고 설정

개발자별 기존 TimeFit 체크아웃 경로는 `.timefit-reference.local`에만 기록합니다. 이 파일은 Git에서 제외되며 공유 문서나 스크립트에 절대 경로를 하드코딩하지 않습니다.

예시 형식:

```text
TIMEFIT_REFERENCE_PATH=/absolute/path/to/time-fit
```

초기 커밋은 프로젝트 경계와 작업 규칙만 정의하며 애플리케이션 구현이나 배포 설정을 포함하지 않습니다.
