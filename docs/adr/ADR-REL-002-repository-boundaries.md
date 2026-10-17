# ADR-REL-002: TimeFit 네이티브 저장소 분리와 부트스트랩 경계

- 상태: `PROPOSED`
- 작성일: 2026-10-17
- 대상 티켓: [REL-002 — 저장소 분리 ADR과 timefit-mobile 부트스트랩](https://trello.com/c/jl0z2Tvd)
- 선행 Gate: [REL-001](https://trello.com/c/xFoln3Kq) 미완료
- 후속 Gate: [CHAT-000](https://trello.com/c/aTapyA3V) 착수 금지 상태 유지

## 1. 결정 요약

`sh414lim/timefit-ax_agent`를 계획 문서에서 `timefit-mobile`로 부른 TimeFit Flutter 네이티브 iOS/Android 앱의 실제 저장소로 사용한다. 기존 `sh414lim/time-fit`과 `tpghks521/dev_manager`의 코드나 배포 수명주기를 이 저장소에 결합하지 않는다.

이 ADR은 저장소·소유권·배포 경계를 제안한다. REL-001, REL-002 또는 CHAT-000의 전체 완료를 선언하지 않으며 production 앱 식별자, Apple App Store record, 서명 주체 또는 배포 승인을 확정하지 않는다.

## 2. 현재 확인된 사실과 미결정 사항

### 확인된 사실

- `timefit-ax_agent`는 private 독립 저장소로 생성되어 있다.
- `time-fit`은 계속 운영되는 모바일 웹/PWA와 공유 backend의 canonical source다.
- `tpghks521/dev_manager`는 기존 네이티브 source·artifact 정체성 조사와 update fixture의 읽기 전용 근거다.
- Android package 후보 `com.leofitTech.devmanager.admin.dev_manager`는 source와 Play Console record가 일치한다.
- Android store 지표는 0이 아니며 backend 계정 수와 동일시할 수 없다.
- 제품 책임자는 기존 사용자 집단을 테스트 사용자로 분류하고 legacy 데이터 미이전을 원한다. 실제 삭제 대상과 실행은 승인되지 않았다.

### 미결정 사항

- Apple Developer 팀 권한은 사용자가 확보 후 알릴 예정이므로 iOS signing·upload·배포는 대기한다.
- Apple ID `6757376637`은 source와 일치하는 후보일 뿐 사용자가 대상 record로 선택하지 않았다.
- production Bundle ID, Team, entitlement, 최대 build와 upload 권한은 확정되지 않았다.
- Android upload key 소유·접근과 app-signing lineage는 확정되지 않았다.
- REL-001의 최종 `legacyUserMigrationDecision`과 REL-003의 이중 Go/No-Go는 승인되지 않았다.
- 모바일, backend와 release owner의 실제 사용자·팀 handle은 지정되지 않았다.

미결정 값을 placeholder라도 production 설정으로 입력하지 않는다.

## 3. 저장소별 책임

| 저장소/시스템 | 원본 책임 | 허용되는 연결 | 금지되는 연결 |
| --- | --- | --- | --- |
| `sh414lim/timefit-ax_agent` | Flutter 네이티브 앱, 앱 전용 테스트·문서·CI | 공개 계약 소비, 승인된 환경별 설정 주입 | `time-fit` source vendoring, submodule, production secret 복사 |
| `sh414lim/time-fit` | 모바일 웹/PWA, DB schema, RLS, RPC, Edge Functions, Realtime, Storage, push dispatcher | 버전된 API/event 계약 publish | Flutter artifact 의존, 앱 심사 때문에 웹 배포 중단 |
| `tpghks521/dev_manager` | legacy source provenance와 update fixture 근거 | 읽기 전용 commit·checksum·fixture 참조 | source·CI·credential 복사, 새 기능 개발 대상화 |
| Store/Firebase/OAuth console | record·identity·signing·provider 설정 | 승인된 manifest와 CI 검증 결과 | 추측한 ID 등록, 임시 production record 생성 |

backend 변경이 필요하면 `time_fit`에서 additive-first로 수행하고 계약 버전을 publish한다. Flutter 저장소는 해당 계약을 소비하고 consumer test를 실행한다. 두 저장소의 Git 이력과 release train을 합치지 않는다.

## 4. 디렉터리와 파일 소유 경계

| 경로 | 책임 역할 | 현재 허용 범위 |
| --- | --- | --- |
| `pubspec.yaml`, `analysis_options.yaml`, `.metadata` | Mobile Code Owner | Flutter SDK·dependency·분석 기준; release 역할이 병행 수정하지 않음 |
| `lib/`, `test/`, `integration_test/` | Mobile Code Owner | REL·CHAT Gate가 허용한 Flutter 구현과 테스트 |
| `android/`, `ios/` | Mobile Code Owner + Release Owner | dev/staging bootstrap; production identity·signing 변경은 별도 승인 |
| `config/`, `tool/`, `scripts/` | Mobile Code Owner | secret 없는 schema·검증·로컬 도구 |
| `.github/workflows/` | Mobile Code Owner + Release Owner | PR analyze/test와 비업로드 build smoke; store upload 비활성 |
| `docs/adr/`, `docs/runbooks/`, `docs/release/` | Architecture/Release Owner | ADR, evidence schema, 비밀값 없는 runbook |
| `time_fit`의 schema·RLS·RPC·Edge Functions | Backend Code Owner | 이 저장소에서 직접 수정하지 않음 |

실제 GitHub CODEOWNERS handle은 담당자가 확정된 뒤 별도 변경으로 추가한다. 임의의 사용자명을 추측하지 않는다.

## 5. 환경과 identity 정책

### dev/staging

- Apple 팀 권한과 production record 확정 전에 준비할 수 있다.
- 실제 production identifier와 혼동되지 않는 명시적 non-production identity만 사용한다.
- production secret 없이 analyze, unit test, contract consumer test와 비업로드 build smoke를 실행할 수 있어야 한다.
- 외부 콘솔 연결이 필요한 테스트는 opt-in으로 분리하고 기본 PR 검사에 포함하지 않는다.

### production

- source에 Bundle ID, application ID, Team ID, signing credential과 provider secret을 하드코딩하지 않는다.
- REL-001/003에서 승인된 제한 접근 identity manifest를 CI가 주입하고 artifact에서 다시 추출해 비교한다.
- manifest 누락, 미승인 Apple ID, identity mismatch 또는 signing lineage 미확인은 fail-closed로 처리한다.
- Apple ID `6757376637`을 승인된 target으로 간주하거나 CI allowlist에 넣지 않는다.
- REL-003 이중 `GO`, 승인된 사용자 영향 처리와 release owner 승인이 없으면 build promotion과 store upload를 실행하지 않는다.

## 6. 독립 빌드·배포 원칙

| 단위 | 독립 실행 | 독립 중단 | rollback/복구 원칙 |
| --- | --- | --- | --- |
| 모바일 웹/PWA | Flutter artifact 없이 build·deploy | 앱 심사·배포와 무관하게 중단 가능 | 기존 웹 pipeline 유지 |
| 공유 backend | 버전된 additive contract로 배포 | 기능별 flag·권한·scheduler 단위 중단 | destructive rollback 대신 forward-fix |
| Flutter iOS | 웹 재배포 없이 build | TestFlight·rollout 별도 중단 | compatible backend 유지, forward-fix |
| Flutter Android | 웹 재배포 없이 build | Internal·rollout 별도 중단 | compatible backend 유지, forward-fix |

Flutter pipeline은 PWA artifact, WebView wrapper 또는 웹 배포 결과를 앱 binary 입력으로 사용하지 않는다. 웹 pipeline도 Flutter build와 스토어 심사 상태를 입력으로 사용하지 않는다.

## 7. Flutter 부트스트랩 후속 작업 계약

이 ADR 승인 후 Flutter bootstrap은 별도 변경 범위로 실행한다.

### 역할별 변경 소유

- Flutter 역할은 `pubspec.yaml`, `analysis_options.yaml`, `.metadata`, `lib/`, `test/`, `integration_test/`, `android/`, `ios/`를 소유한다.
- Release 역할은 `.github/workflows/`, `config/`, `scripts/`, `docs/release/`를 소유하며 Flutter scaffold와 동시에 같은 파일을 수정하지 않는다.
- Architecture 역할은 이 ADR을 소유하고 Flutter·Release 경로를 수정하지 않는다.
- 공통 파일 변경이 필요하면 먼저 파일 단위 소유자를 지정하고 하나의 역할만 수정한다.

확인된 로컬 toolchain은 Flutter `3.38.5`, Dart `3.10.4`, Xcode `16.1`, Java `17`이다. 이 버전 표시는 실행 성공 증거가 아니다. Flutter SDK cache 쓰기 제한이 관찰됐으므로 analyze/test/build가 cache write를 요구하면 허용된 승인 절차로 실행하고 SDK 복사, cache 경로 변조 또는 비공식 우회를 사용하지 않는다.

CHAT-006은 REL-001, REL-002와 CHAT-003 선행 조건이 있으므로 이 부트스트랩 준비로 착수됐다고 간주하지 않는다.

### 후속 작업 순서

1. 저장소 root에 Flutter iOS/Android 최소 프로젝트와 `test/`를 만든다.
2. dev/staging/production configuration schema를 분리하되 production 값은 빈 상태로 유지한다.
3. dev/staging은 production record와 혼동되지 않는 identity를 사용한다.
4. PR 기본 검사로 format, analyze, unit test와 secret 없는 build smoke를 구성한다.
5. PWA, Capacitor, WebView, AI/LLM, FastAPI/EC2 dependency가 들어오지 않도록 allowlist/scan을 둔다.
6. 기존 `dev_manager` session, local DB, push token과 결제 상태를 import하지 않는다.
7. update fixture에서는 stale legacy cache가 있어도 새 로그인과 새 로컬 namespace가 안전하게 초기화되는지 검증한다.
8. store upload, signing credential 연결과 production promotion job은 비활성 상태로 둔다.

Flutter toolchain과 package version은 bootstrap 변경에서 명시적으로 고정하고 clean checkout 결과를 evidence로 남긴다.

## 8. 티켓 라우팅 필드

이 저장소와 `time_fit`에 걸치는 후속 티켓에는 다음 필드를 요구한다.

```yaml
Repository: timefit-ax_agent | time_fit | both-with-separate-PRs
AffectedClients: flutter-ios | flutter-android | mobile-web | backend
ContractVersion: none | v1 | explicit-version
BackendDeployPrerequisite: none | ticket-or-release-id
IdentityImpact: none | dev | staging | production-gated
Evidence: test-command-or-link
```

`both-with-separate-PRs`는 한 PR에 두 저장소 변경을 혼합한다는 뜻이 아니다. 서로 독립된 PR과 배포 순서를 연결한다는 뜻이다.

## 9. 현재 허용되는 작업과 Gate

### 권한과 무관하게 진행 가능

- 이 ADR 검토와 owner 역할 확정
- secret 없는 Flutter bootstrap 설계와 dependency allowlist
- 새 로그인, 새 로컬 namespace와 legacy data 미사용 fixture 설계
- API/event contract consumer test harness 설계
- production identity가 없는 PR 검사와 fail-closed CI 검증 설계

### 권한 또는 별도 승인 전 금지

- Apple record 선택, Team 연결, certificate/profile/API key 생성·변경
- Android upload key 생성·교체 또는 signing 설정 변경
- production identity manifest 값 확정과 allowlist 등록
- 실제 사용자·테스트 데이터 삭제 또는 backend row 변경
- Store/Firebase/OAuth production 설정 변경
- TestFlight, Play Internal 또는 production 배포

## 10. 수용 기준과 남은 증거

이 ADR 하위 작업은 다음 조건을 만족하면 검토 가능하다.

- 카드만 보고 변경 대상 저장소와 owner 역할을 판별할 수 있다.
- 웹, backend, Flutter iOS와 Flutter Android의 build·중단·복구 단위가 분리돼 있다.
- production identity와 signing이 승인 전 fail-closed임이 명시돼 있다.
- Apple ID 후보가 target 확정으로 오인되지 않는다.
- 데이터 삭제가 bootstrap 또는 개발 준비의 선행조건이 아니다.
- 권한과 무관한 준비와 release 전 필수 Gate가 구분돼 있다.

REL-002 전체 완료에는 이 ADR 외에 다음 증거가 추가로 필요하다.

- Mobile Code Owner, Backend Code Owner와 Release Owner의 실제 지정
- repository visibility와 branch protection 설정 캡처
- CODEOWNERS와 PR template 적용
- Flutter clean checkout의 format/analyze/test/build smoke
- production secret 없이 PR 검사가 실행된 결과
- 기술 책임자의 ADR 승인 기록

위 증거가 없으므로 이 문서만으로 REL-002를 완료 처리하지 않는다. REL-001과 REL-002가 모두 완료되기 전에는 CHAT-000을 시작하지 않는다.

## 11. 검증 명령

```bash
rg -n "timefit-ax_agent|time_fit|dev_manager|production|Apple ID|6757376637|CHAT-000" \
  docs/adr/ADR-REL-002-repository-boundaries.md
git diff --check
```

## 12. 결과와 후속 결정

이 ADR을 승인하면 저장소 분리 원칙을 유지한 채 Flutter bootstrap PR을 준비할 수 있다. Apple Developer 권한 확보는 iOS production identity·signing·upload Gate에만 필요하며 secret 없는 dev/staging bootstrap과 로컬 테스트 설계를 막지 않는다.

production target과 release mode의 최종 승인은 REL-001/003 evidence와 별도 Product/Policy Gate에서 수행한다.
