## Ticket

- Trello or approved work item: <!-- required: URL or identifier -->

## Change routing

- Repository: `timefit-ax_agent` <!-- required -->
- Affected clients: <!-- required: select every affected client -->
  - [ ] Flutter iOS
  - [ ] Flutter Android
  - [ ] Mobile web/PWA
  - [ ] Shared backend
  - [ ] Documentation or repository governance only
- Contract version: <!-- required: none, v1, or explicit version -->
- Backend deploy prerequisite: <!-- required: none or ticket/release identifier -->
- Identity impact: <!-- required: none, dev, staging, or production-gated -->

## Summary

<!-- Describe the change and why it belongs in this repository. -->

## Evidence

<!-- Required: list exact commands and attach or link their results. -->

- Commands:
- CI or review URL:
- Additional evidence:

## Repository and release boundaries

- [ ] This change does not copy or modify `time_fit` source, schema, RLS, RPC, Edge Functions, Realtime, Storage, or deployment configuration in this repository.
- [ ] Flutter and mobile-web build or deployment lifecycles remain independent.
- [ ] No token, password, API key, certificate, signing material, provider configuration, or production secret is included.
- [ ] No unapproved production application ID, Bundle ID, Apple ID, Team ID, signing configuration, store target, or release upload is introduced.
- [ ] If production identity or release behavior is affected, the applicable REL evidence and explicit approval are linked above; otherwise the change remains fail-closed.
- [ ] Existing web/PWA operation is not frozen, replaced, or made dependent on Flutter delivery.

## Verification

- [ ] Formatting check passed.
- [ ] Static analysis passed or is not applicable with a reason below.
- [ ] Relevant tests and non-deployment build smoke passed or are not applicable with a reason below.
- [ ] `scripts/ci/verify_bootstrap_boundaries.sh` passed when bootstrap, native platform, workflow, or dependency files changed.

Not-applicable reasons:

## Risk and recovery

- User/data impact: <!-- required -->
- Rollback or forward-fix plan: <!-- required -->
- Remaining blockers or follow-up tickets: <!-- required -->

## Review ownership

- [ ] Review is requested only from confirmed GitHub users or teams in `CODEOWNERS`.
- [ ] Branch protection, required review, secret scanning, environment permissions, and other repository settings are requested separately; this PR does not claim those settings were applied.
- [ ] Codex role sessions, automation actors, CI results, and the change author are not recorded as human or independent approvers.
- [ ] If automatic branch protection or required review is unavailable, the proposed procedure in `docs/rel-002/governance-review-procedure.md` is linked below and its latest-SHA review evidence is complete; otherwise this PR remains draft or blocked.

- Reviewed commit SHA:
- Verified reviewer handle/team and role:
- Review URL and UTC timestamp:
- Manual merge confirmation evidence or not-applicable reason:
