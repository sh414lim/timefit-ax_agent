# REL-002 PR evidence와 security audit mapping

- 티켓: [REL-002 — 저장소 분리 ADR과 timefit-mobile 부트스트랩](https://trello.com/c/jl0z2Tvd)
- 기준 원문: [145 — REL-002](../145-timefit-native-app-repository-migration-plan-2026-10-16.md), [ADR-REL-002](../adr/ADR-REL-002-repository-boundaries.md)
- 역사적 evidence 기준: PR #1~#8, 당시 remote `main` `0ca9428323ff77d4c06ad1bc32fa8fdb48d7a0a4`
- 현재 기준: PR #9 병합 후 remote `main` `c0c74de0ef51a6e568785234a3701ab55db97973`, 2026-10-18 재확인
- 판정 원칙: PR merge는 산출물 evidence일 뿐 티켓 완료·승인·배포를 뜻하지 않는다.

## 1. PR 산출물 매핑

PR #1~#8 행은 당시 상태를 보존한 historical mapping이다. 현재 상태와 security audit 판정은 PR #9 및 아래 3절을 함께 읽는다.

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
| [#9](https://github.com/sh414lim/timefit-ax_agent/pull/9) | 두 migration 경로 기준선, provenance와 REL-002 evidence mapping 개정 | `main@c0c74de`를 현재 설계·감사 기준으로 고정 | REL-002 owner·ADR 승인·hosted 보호·secret scanning 완료 증거 아님 |

## 2. REL-002 수용 기준 판정

| 수용 기준·증거 | 현재 evidence | 판정 | 남은 조건 |
| --- | --- | --- | --- |
| 독립 저장소와 visibility 결정 | `main@c0c74de` 감사 당시 `private: true`; 이후 사용자가 추적 문서·기존 Git 이력의 인터넷 공개 범위를 확인하고 전체 저장소 public 전환을 명시 승인 | `INDEPENDENT_SATISFIED_PUBLIC_CHANGE_APPROVED_PENDING_VERIFICATION` | Release 세션이 실제 visibility와 익명 접근을 확인하기 전까지 public 전환 완료로 기록하지 않음 |
| 저장소 경계 ADR | PR #2, `ADR-REL-002` | `PARTIAL` | ADR `APPROVED` 전환과 기술 책임자 승인 기록 |
| Flutter iOS/Android 최소 구조·test | PR #3 | `SATISFIED_FOR_BOOTSTRAP` | 제품 기능 완료나 production 준비로 확대 해석 금지 |
| dev/staging/production 구조 | PR #3; production entrypoint 없음, fail-closed | `SATISFIED_FOR_BOOTSTRAP` | production identity는 REL-001/003 승인 후 별도 적용 |
| CODEOWNERS·PR template | PR #4; [역할 등록·수동 검토 절차 draft](governance-review-procedure.md) | `PARTIAL` | Mobile/Backend/Release 실제 GitHub owner 또는 팀 지정과 절차 채택 evidence |
| clean checkout format/analyze/test/build smoke | CI [#39002757916](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39002757916), [#39003684751](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39003684751), [#39007358409](https://github.com/sh414lim/timefit-ax_agent/actions/runs/39007358409) 모두 성공 | `SATISFIED_FOR_CURRENT_BOOTSTRAP` | 후속 dependency/플랫폼 변경 때 같은 검증 유지 |
| production secret 없는 PR 검사 | workflow `permissions: contents: read`, secret/write permission 및 release/upload trigger 검사 | `SATISFIED_FOR_WORKFLOW_CONTENT` | GitHub secret scanning 설정 자체의 활성화 evidence와 구분 |
| dependency/boundary allowlist | `scripts/ci/verify_bootstrap_boundaries.sh`가 production identity, signing, provider file, PWA/deploy 경로를 차단 | `PARTIAL` | 향후 실제 dependency allowlist·contract consumer test 확장 |
| branch protection·required review | `main@c0c74de`의 private 상태에서 branch protection/ruleset API가 GitHub plan 제한으로 HTTP `403`; [수동 검토 절차](governance-review-procedure.md)는 `PROPOSED_NOT_CONFIGURED` | `BLOCKED_BY_HOSTING_PLAN_AT_AUDIT` | visibility 전환 후 지원 여부를 재조회하거나 Repository Owner가 절차를 채택하고 실제 PR의 최신 SHA·독립 review·merge 확인 evidence 확보 |
| secret scanning | GitHub hosted secret scanning은 disabled; `main@c0c74de` history와 tree의 공식 gitleaks 일회성 감사 finding `0` | `LOCAL_AUDIT_PASSED_HOSTED_DISABLED` | hosted 기능 활성 또는 승인된 반복 scan 정책·required evidence; 이후 head 재검사 |
| environment 권한 분리 | GitHub environments `0` | `NOT_CONFIGURED` | release 단계 전 environment/approver 분리; bootstrap production은 계속 차단 |
| Actions 기본 권한 | workflow 기본 `read`, Actions의 PR review 승인 비활성 | `READ_ONLY_DEFAULT_PR_APPROVAL_DISABLED` | required check·review 강제와는 별도; 승인된 정책과 설정 evidence 필요 |
| 협업자 초대 | `tpghks521` 초대 `338202054`는 pending `write`, 실효 권한 `none` | `PENDING_INVITATION_EFFECTIVE_NONE` | 수락 후 실제 권한 재확인 또는 Owner의 초대 처리 결정 |
| versioned contract publish/consume와 양쪽 CI | schema·consumer test 연결 없음 | `NOT_STARTED` | REL-004/005와 별도 `time_fit` 승인 변경 필요 |
| 기존 native source 보존 tag/archive | source/build 일부 관측만 있고 immutable archive/tag evidence 없음 | `PARTIAL` | 소유권·checksum·보존 위치 승인 |
| ADR 기술 승인 | 승인 댓글·서명 없음; 승인 기록 형식만 draft로 정의 | `NOT_APPROVED` | 검증된 Architecture Owner와 Release reviewer의 최신 SHA 승인·시각·review URL |

## 3. 2026-10-18 redacted secret-scan audit

```yaml
evidenceId: REL002-GITLEAKS-V8301-MAIN-C0C74DE-20261018
source: RELEASE_SESSION_READ_ONLY_AUDIT
target:
  repository: sh414lim/timefit-ax_agent
  revision: c0c74de0ef51a6e568785234a3701ab55db97973
  reachableCommitCountAtAudit: 23
scanner:
  name: gitleaks
  version: 8.30.1
  distribution: OFFICIAL_GITHUB_RELEASE
  publishedChecksumVerification: PASSED
  checksumValues: RETAINED_BY_RELEASE_SESSION_NOT_RECORDED_IN_GIT
scans:
  historyAllRefs:
    mode: GIT_ALL_REACHABLE_HISTORY
    redaction: 100_PERCENT
    observedAt: 2026-10-18T12:54:33Z
    exitStatus: 0
    findings: 0
  currentTree:
    mode: DIRECTORY_TREE
    redaction: 100_PERCENT
    observedAt: 2026-10-18T12:54:39Z
    exitStatus: 0
    findings: 0
supplementalChecks:
  highConfidenceSecretFormats: 0
  sensitiveFilenamesInHistory: 0
  credentialAssignments: 0
  entropyCandidatesReviewed: 9
  entropyDisposition: PUBLIC_PATH_OR_IDENTIFIER_OR_EVIDENCE_ID
hostedControls:
  secretScanning: DISABLED
  branchProtection: BLOCKED_BY_HOSTING_PLAN_HTTP_403
  rulesets: BLOCKED_BY_HOSTING_PLAN_HTTP_403
  environments: 0
  actionsDefaultWorkflowPermission: READ
  actionsCanApprovePullRequestReviews: false
collaborator:
  login: tpghks521
  invitationId: 338202054
  invitationState: PENDING_WRITE
  effectivePermission: NONE
auditDecision: LOCAL_ONE_TIME_AUDIT_PASSED_NOT_ENFORCED
```

history 검사는 official gitleaks의 Git history 모드에 모든 reachable ref를 전달했고, tree 검사는 directory 모드로 수행했다. 두 실행 모두 JSON report와 100% redaction을 사용했다. 재현 command 원문, official asset·binary checksum 값과 임시 report 경로는 Release 세션 evidence에만 보존하고 Git에는 복사하지 않는다. report의 finding 배열은 두 범위 모두 비어 있었다.

entropy 후보 9건은 값 자체를 이 문서에 복사하지 않고 공개 경로·공개 식별자·evidence ID 범주임을 검토했다. 이 판정은 `main@c0c74de`에 대한 시점성 감사이며 PR #10 이후 commit이나 미래 branch를 자동 포함하지 않는다.

finding `0`은 hosted secret scanning 활성, branch protection, ruleset, required check, required review 또는 scan 정책 채택을 의미하지 않는다. GitHub hosted secret scanning은 disabled이고 보호 기능은 plan 제한, environment는 0개다. 반복 시점·대상·실패 처리와 merge 차단을 정의한 정책은 [`governance-review-procedure.md`](governance-review-procedure.md)에서 계속 `PROPOSED_NOT_CONFIGURED`로 둔다.

## 4. 현재 수행 가능한 보완과 보류 경계

현재 저장소 안에서 안전하게 수행 가능한 보완은 이 evidence mapping 유지, ADR 검토, PR template·boundary 검사 회귀 확인, [역할 등록·수동 검토 절차](governance-review-procedure.md)의 검토와 owner 후보를 추측하지 않는 빈 역할표 유지다. 수동 절차는 유료 plan 제한을 숨기지 않으며 채택·적용 evidence 전에는 required review가 설정됐다고 표현하지 않는다. 다음 작업은 권한·별도 결정 없이 수행하지 않는다.

- GitHub 요금제 변경, branch protection/ruleset 생성 또는 required reviewer 강제
- 확인되지 않은 GitHub 사용자·팀을 CODEOWNERS에 추가
- production environment, signing, store upload, provider secret 연결
- `time_fit`의 backend 계약·CI 수정
- REL-001/003 미완료 상태에서 production identity 적용

따라서 REL-002는 `PARTIAL`이다. 현재 보완 문서는 완료 증거를 정리하지만 빠진 설정·역할·승인을 완료 처리하지 않는다.

## 5. repository visibility 승인과 실행 경계

- 사용자 승인 evidence: `Sentinel_f6c44705f4108191b830d573f0f5c5bc`
- 승인 범위: `sh414lim/timefit-ax_agent`의 추적 파일·내부 계획 문서와 기존 Git 이력이 인터넷에서 열람될 수 있는 public visibility 전환
- 현재 판정: `PUBLIC_VISIBILITY_APPROVED_PENDING_RELEASE_VERIFICATION`
- 실행 완료 판정에 필요한 evidence: GitHub repository visibility 조회와 인증 없는 read 접근 확인
- 승인에 포함되지 않는 작업: history rewrite, 기존 내용 무차별 삭제, collaborator/credential 변경, GitHub 요금제 변경, branch protection/ruleset·hosted secret scanning 활성화

public 전환은 독립 저장소 경계를 바꾸지 않으며 hosted secret scanning이나 required review를 자동으로 구성했다는 뜻도 아니다. Release 세션의 실행 확인 전에는 이 문서가 저장소를 이미 public이라고 주장하지 않는다.
