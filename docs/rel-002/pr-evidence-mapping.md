# REL-002 PR #1~#8 evidence mapping

- 티켓: [REL-002 — 저장소 분리 ADR과 timefit-mobile 부트스트랩](https://trello.com/c/jl0z2Tvd)
- 기준 원문: [145 — REL-002](../145-timefit-native-app-repository-migration-plan-2026-10-16.md), [ADR-REL-002](../adr/ADR-REL-002-repository-boundaries.md)
- 확인 기준: remote `main` `0ca9428323ff77d4c06ad1bc32fa8fdb48d7a0a4`, 2026-10-18 재확인
- 판정 원칙: PR merge는 산출물 evidence일 뿐 티켓 완료·승인·배포를 뜻하지 않는다.

## 1. PR 산출물 매핑

| PR | 병합 산출물 | REL-002 기여 | 한계 |
| --- | --- | --- | --- |
| [#1](https://github.com/sh414lim/timefit-ax_agent/pull/1) | REL-001 identity audit baseline | production identity를 추측하지 않는 fail-closed 입력 구조 | REL-002 승인·owner·repository protection evidence 아님 |
| [#2](https://github.com/sh414lim/timefit-ax_agent/pull/2) | 저장소 경계 ADR | 저장소·소유 경로·독립 배포·금지 연결 정의 | ADR 상태 `PROPOSED`; 기술 책임자 승인 없음 |
| [#3](https://github.com/sh414lim/timefit-ax_agent/pull/3) | isolated Flutter bootstrap | iOS/Android 최소 구조, dev/staging, test, production fail-closed | production identity·signing·외부 서비스 연결 없음; 이는 의도된 Gate |
| [#4](https://github.com/sh414lim/timefit-ax_agent/pull/4) | CODEOWNERS, PR template, bootstrap boundary 검사 | governance skeleton과 필수 routing/evidence 필드 | CODEOWNERS는 확인된 `@sh414lim`만 포함; Mobile/Backend/Release 실제 owner 미지정 |
| [#5](https://github.com/sh414lim/timefit-ax_agent/pull/5) | 지원 runner로 CI 이전 | PR format/analyze/test/Android·iOS no-codesign smoke 유지 | protected branch/required check 설정 evidence 아님 |
| [#6](https://github.com/sh414lim/timefit-ax_agent/pull/6) | 145/146/147 baseline과 import provenance | 티켓·계약 기준선 확보 | 가져온 기준선 자체가 REL-002 완료나 승인 기록은 아님 |
| [#7](https://github.com/sh414lim/timefit-ax_agent/pull/7) | REL-001 production evidence | identity·population blocker의 부분 evidence | REL-002 수용 기준 직접 완료 아님 |
| [#8](https://github.com/sh414lim/timefit-ax_agent/pull/8) | REL-001 migration evidence 갱신 | nonzero 관측과 사용자 no-transfer 결정 구분 | `PROPOSED_NOT_APPLIED` 설계 변경이었고 REL-001/002 승인 아님 |

## 2. REL-002 수용 기준 판정

| 수용 기준·증거 | 현재 evidence | 판정 | 남은 조건 |
| --- | --- | --- | --- |
| private 독립 저장소 | GitHub repository 조회에서 `private: true`, 기본 branch `main` | `SATISFIED` | visibility를 public으로 바꾸지 않음 |
| 저장소 경계 ADR | PR #2, `ADR-REL-002` | `PARTIAL` | ADR `APPROVED` 전환과 기술 책임자 승인 기록 |
| Flutter iOS/Android 최소 구조·test | PR #3 | `SATISFIED_FOR_BOOTSTRAP` | 제품 기능 완료나 production 준비로 확대 해석 금지 |
| dev/staging/production 구조 | PR #3; production entrypoint 없음, fail-closed | `SATISFIED_FOR_BOOTSTRAP` | production identity는 REL-001/003 승인 후 별도 적용 |
| CODEOWNERS·PR template | PR #4 | `PARTIAL` | Mobile/Backend/Release 실제 GitHub owner 또는 팀 지정 |
| clean checkout format/analyze/test/build smoke | CI [#39002757916](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39002757916), [#39003684751](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39003684751), [#39007358409](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39007358409) 모두 성공 | `SATISFIED_FOR_CURRENT_BOOTSTRAP` | 후속 dependency/플랫폼 변경 때 같은 검증 유지 |
| production secret 없는 PR 검사 | workflow `permissions: contents: read`, secret/write permission 및 release/upload trigger 검사 | `SATISFIED_FOR_WORKFLOW_CONTENT` | GitHub secret scanning 설정 자체의 활성화 evidence와 구분 |
| dependency/boundary allowlist | `scripts/ci/verify_bootstrap_boundaries.sh`가 production identity, signing, provider file, PWA/deploy 경로를 차단 | `PARTIAL` | 향후 실제 dependency allowlist·contract consumer test 확장 |
| branch protection·required review | private repository의 branch protection/ruleset API가 GitHub plan 제한으로 HTTP `403` | `BLOCKED_BY_HOSTING_PLAN` | plan 변경 또는 승인된 수동 governance 대안과 독립 증거 |
| secret scanning 설정 | repository API `security_and_analysis: null`; 별도 활성화 증거 없음 | `NOT_VERIFIED` | GitHub 설정 증거 또는 승인된 대체 scan evidence |
| environment 권한 분리 | GitHub environments `0` | `NOT_CONFIGURED` | release 단계 전 environment/approver 분리; bootstrap production은 계속 차단 |
| versioned contract publish/consume와 양쪽 CI | schema·consumer test 연결 없음 | `NOT_STARTED` | REL-004/005와 별도 `time_fit` 승인 변경 필요 |
| 기존 native source 보존 tag/archive | source/build 일부 관측만 있고 immutable archive/tag evidence 없음 | `PARTIAL` | 소유권·checksum·보존 위치 승인 |
| ADR 기술 승인 | 승인 댓글·서명 없음 | `NOT_APPROVED` | 기술 책임자 승인과 시각 |

## 3. 현재 수행 가능한 보완과 보류 경계

현재 저장소 안에서 안전하게 수행 가능한 보완은 이 evidence mapping 유지, ADR 검토, PR template·boundary 검사 회귀 확인과 owner 후보를 추측하지 않는 빈 역할표 유지다. 다음 작업은 권한·별도 결정 없이 수행하지 않는다.

- GitHub 요금제 변경, branch protection/ruleset 생성 또는 required reviewer 강제
- 확인되지 않은 GitHub 사용자·팀을 CODEOWNERS에 추가
- production environment, signing, store upload, provider secret 연결
- `time_fit`의 backend 계약·CI 수정
- REL-001/003 미완료 상태에서 production identity 적용

따라서 REL-002는 `PARTIAL`이다. 현재 보완 문서는 완료 증거를 정리하지만 빠진 설정·역할·승인을 완료 처리하지 않는다.
