# REL-002 역할 등록·ADR 승인·수동 검토 절차

- 상태: `PROPOSED_NOT_CONFIGURED`
- 적용 저장소: `sh414lim/timefit-ax_agent`
- 기준 commit: `c0c74de0ef51a6e568785234a3701ab55db97973`
- 연관 티켓: [REL-002](https://trello.com/c/jl0z2Tvd)
- 연관 ADR: [ADR-REL-002](../adr/ADR-REL-002-repository-boundaries.md)

이 문서는 `main@c0c74de` 감사 당시 private repository의 branch protection/ruleset API가 GitHub plan 제한으로 HTTP `403`을 반환한 상태에서 사용할 수 있는 **제안된 수동 검토 절차**다. 이후 사용자가 public visibility 전환을 승인했지만 실제 전환과 기능 지원 여부는 별도 확인 대상이다. 설정이 적용됐거나 REL-002가 완료됐다는 증거가 아니다. 절차를 채택하려면 Repository Owner의 명시적 승인, 실제 역할 지정과 각 PR의 독립 검토 evidence가 필요하다.

## 1. 역할과 신원 등록

| 역할 | 사람/팀 | GitHub handle/team | 권한 evidence | 결정 범위 | 상태 |
| --- | --- | --- | --- | --- | --- |
| Repository Owner | 미지정 | 확인된 repository owner account와 역할 연결 필요 | repository permission 조회 | 저장소 설정·merge 정책 | `PENDING_VERIFICATION` |
| Mobile Code Owner | 미지정 | 미지정 | Flutter 경로 소유 확인 | Flutter 코드·테스트·native project | `PENDING_ASSIGNMENT` |
| Backend Code Owner | 미지정 | 미지정 | `time_fit` 권한과 책임 확인 | API/event 계약·backend 배포 | `PENDING_ASSIGNMENT` |
| Release Manager | 미지정 | 미지정 | store/CI release 권한 확인 | build promotion·store 제출 | `PENDING_ASSIGNMENT` |
| Security Approver | 미지정 | 미지정 | signing/provider 검토 권한 확인 | identity·signing·secret·provider | `PENDING_ASSIGNMENT` |
| Architecture Owner | 미지정 | 미지정 | ADR 검토 책임 확인 | 저장소·계약 경계 ADR | `PENDING_ASSIGNMENT` |
| Backup Approver | 미지정 | 미지정 | 복구·대체 승인 역할 확인 | owner 부재 시 독립 검토 | `PENDING_ASSIGNMENT` |
| Product Decision Authority | 사용자 | GitHub handle과 기술 권한 연결 안 됨 | 대화에서 제품 결정 확인 | legacy 데이터 미이전 제품 결정 | `USER_ATTESTED_PRODUCT_SCOPE_ONLY` |

현재 `CODEOWNERS`의 `@sh414lim`은 확인된 GitHub account이므로 review 요청 대상이 될 수 있다. 그러나 별도 evidence 없이 위 기술·출시·보안 역할 중 하나로 자동 지정하지 않는다.

Codex 역할 세션과 자동화 실행자는 문서 작성, 정적 검사와 evidence 수집을 수행할 수 있지만 인간 책임자·독립 reviewer·승인자로 기록하지 않는다. 역할 세션 이름을 실제 사람이나 GitHub account로 변환하지 않는다.

## 2. ADR 승인 기록 형식

ADR 상태를 `APPROVED`로 변경하려면 아래 기록을 PR 본문 또는 제한 접근 승인 register에 남긴다.

```yaml
adr: ADR-REL-002
revision: <reviewed-commit-sha>
decision: APPROVED | CHANGES_REQUESTED | REJECTED
architectureOwner:
  displayName: <verified-human-or-team>
  githubHandleOrTeam: <verified-handle-or-team>
  permissionEvidence: <url-or-restricted-evidence-id>
releaseReviewer:
  displayName: <verified-human-or-team>
  githubHandleOrTeam: <verified-handle-or-team>
reviewedAt: <UTC timestamp>
reviewUrl: <pull-request-or-review-url>
remainingExceptions:
  - <explicit exception and owner>
```

작성자 자신의 승인, Codex 세션의 검토 문구, CI 성공 또는 PR merge만으로 ADR 승인을 만들지 않는다.

## 3. 제안된 수동 merge 검토 절차

branch protection이 자동으로 강제되지 않는 동안 다음 절차를 **모두** 수행한 PR만 merge 후보로 삼는다.

1. PR은 draft로 시작하고 ticket, repository, affected clients, contract version, backend prerequisite, identity impact를 채운다.
2. 변경 파일을 Mobile, Backend, Release, Security, Architecture 경로로 분류하고 각 경로의 실제 역할 owner를 확인한다.
3. 작성자와 다른 검증된 인간 reviewer가 diff, 테스트 결과, 비밀값·identity 영향과 복구 계획을 검토한다.
4. 경계·ADR·release 또는 production 영향이 있으면 해당 영역의 별도 역할 reviewer를 한 명 더 요구한다. 동일한 사람이 두 독립 역할을 겸했다면 겸임 사실과 권한 evidence를 기록한다.
5. 작성자는 review 요청 이후의 commit SHA를 고정하고 필수 검사 결과 URL 또는 로그를 연결한다.
6. 변경 요청 이후 새 commit이 추가되면 이전 승인을 재사용하지 않고 최신 SHA에서 다시 검토한다.
7. merge 직전 Repository Owner 또는 위임된 Backup Approver가 최신 SHA, 승인자, 미해결 conversation, 검사 상태와 scope를 대조해 수동 확인 기록을 남긴다.
8. evidence가 누락되거나 실제 역할이 미지정이면 merge하지 않고 draft 또는 blocked 상태를 유지한다.

### 최소 독립 검토 제안

- 문서·repository governance 전용: 작성자 외 검증된 인간 reviewer 1명 + Architecture/Repository 역할 확인
- Flutter 코드 또는 native project: 작성자 외 Mobile reviewer 1명
- workflow·release·identity·signing·provider: 작성자 외 Release reviewer와 Security reviewer 각각 1명
- backend 계약: 이 저장소 PR과 별개로 `time_fit` Backend reviewer evidence 연결
- production promotion 또는 store 제출: 이 절차 밖이며 REL-001/003과 별도 release 승인이 필요

이 인원수와 역할 구성은 `PROPOSED`다. Repository Owner가 채택하기 전에는 저장소 정책으로 표현하지 않는다.

## 4. PR별 수동 검토 evidence

```yaml
reviewedCommit: <full-sha>
changeAuthor: <github-handle>
affectedRoleDomains:
  - <mobile|backend|release|security|architecture|docs>
verifiedReviewers:
  - handleOrTeam: <verified-handle-or-team>
    role: <verified-role>
    reviewUrl: <url>
    decision: APPROVED | CHANGES_REQUESTED
    reviewedAt: <UTC timestamp>
checks:
  diffCheck: <result-or-url>
  boundaryScan: <result-or-url>
  formatAnalyzeTestBuild: <result-or-not-applicable-reason>
unresolvedExceptions:
  - <exception, owner, due condition>
mergeConfirmation:
  actor: <repository-owner-or-backup-approver>
  confirmedAt: <UTC timestamp>
```

자동 CI 실행이 0건이면 `PASSED`가 아니라 `NOT_RUN`으로 기록한다. 수동 검증은 자동 required check가 적용됐다는 증거가 아니다.

## 5. CODEOWNERS와 역할 변경

- 확인된 GitHub user/team만 `.github/CODEOWNERS`에 추가한다.
- role 표의 사람/팀, GitHub handle/team, permission evidence 세 값이 일치하기 전에는 placeholder를 CODEOWNERS에 넣지 않는다.
- Mobile, Backend, Release 책임을 한 계정으로 임의 통합하지 않는다.
- 역할 변경은 별도 PR로 수행하고 이전 owner, 새 owner, 적용 시각과 복구 연락처를 기록한다.
- `time_fit` Backend Code Owner는 이 저장소 CODEOWNERS만으로 지정할 수 없으며 해당 저장소의 확인이 필요하다.

## 6. plan 제한과 남은 자동화 Gap

| 항목 | 현재 상태 | 수동 대안 | 완료로 인정하려면 필요한 evidence |
| --- | --- | --- | --- |
| branch protection/ruleset | `main@c0c74de` private 감사에서 `BLOCKED_BY_HOSTING_PLAN`, API `403`; public 전환 후 상태 미확인 | 최신 SHA 기반 독립 review와 merge 확인 기록 | 전환 후 설정 지원 여부 재조회와 실제 설정, 또는 승인된 수동 절차를 실제 PR에서 수행한 기록 |
| required review | 자동 강제 없음 | 역할별 reviewer evidence | Repository Owner 채택 + 실제 review URL·시각·SHA |
| required checks | 자동 강제 확인 안 됨 | 검사 결과를 PR에 연결하고 merge 확인자가 대조 | 설정 캡처 또는 각 PR의 완전한 수동 evidence |
| secret scanning | hosted 기능 `DISABLED`; `main@c0c74de` official gitleaks 일회성 audit finding `0` | audit evidence를 PR에 연결하고 이후 head는 다시 검사 | hosted 설정 evidence 또는 Repository Owner가 채택한 반복 scan·실패 차단 정책과 실제 실행 기록 |
| environment approver | environments `0` | production job 미구성·fail-closed 유지 | release 전 environment와 실제 approver 설정 evidence |

수동 절차는 GitHub 설정의 부재를 숨기지 않으며 plan 변경을 수행하지 않는다. public visibility 전환 승인이나 실행도 branch protection, required review 또는 hosted secret scanning의 활성화를 자동 증명하지 않는다. 일회성 finding `0`도 hosted 기능 활성이나 필수 강제를 대신하지 않는다. 자동 강제가 필요한 수용 기준은 전환 후 재조회와 실제 설정 또는 채택된 반복 정책의 evidence가 확보될 때까지 `BLOCKED_BY_HOSTING_PLAN_AT_AUDIT`, `HOSTED_DISABLED` 또는 `NOT_VERIFIED`로 유지한다.

## 7. 이 draft에서 하지 않는 작업

- GitHub plan 변경, branch protection/ruleset 또는 environment 생성
- 미확인 사용자를 CODEOWNERS에 추가
- 실제 사람의 기술·출시·보안 승인 생성
- production secret, signing credential, store/Firebase/OAuth 연결
- REL-001/003 이전의 production identity 적용 또는 배포

## 8. 채택 조건

- Repository Owner와 Backup Approver의 실제 계정·권한 확인
- Mobile, Backend, Release, Security와 Architecture 역할의 사람/팀 지정
- ADR-REL-002 최신 commit에 대한 독립 검토와 결정 기록
- 수동 절차를 적용한 한 개 이상의 PR에서 최신 SHA·review URL·검사 결과·merge 확인 evidence 확보
- 자동화 Gap을 REL-002 evidence mapping에 `SATISFIED`, `PARTIAL`, `BLOCKED`로 구분해 기록

채택 전 상태는 `PROPOSED_NOT_CONFIGURED`다. 이 문서를 merge해도 branch protection, required review, secret scanning 또는 environment 권한이 설정된 것으로 간주하지 않는다.
