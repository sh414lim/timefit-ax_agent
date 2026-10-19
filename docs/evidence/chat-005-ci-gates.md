# CHAT-005 mobile CI gate evidence

- Observed: 2026-10-18 UTC
- Ticket: <https://trello.com/c/WAznTon1>
- Architecture: [`docs/146-timefit-native-chat-architecture-2026-10-16.md`](../146-timefit-native-chat-architecture-2026-10-16.md)
- Design catalog: [`docs/147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md`](../147-timefit-native-chat-execution-ticket-catalog-2026-10-16.md), CHAT-005
- Baseline: `main@f67abc45c767a6d2131443f0bf09fe86fdd94b4d`

## Local success path

The existing Flutter 3.38.5 / Dart 3.10.4 SDK was used with no signing or deployment action.

```text
CI_MOBILE_USE_SYSTEM_FLUTTER=1 bash scripts/ci_mobile.sh
  locked dependency resolution: PASS
  pubspec.lock SHA-256: 567aa7f5bdc661318185366e2e595245b2af2428eb39d66136785a7cb68197ec
  generated-file diff: PASS
  dart format: PASS (7 files, 0 changed)
  flutter analyze --fatal-infos --fatal-warnings: PASS
  flutter test --coverage: PASS (6 tests)
  Android dev debug build: PASS
  Android staging debug build: PASS

CI_MOBILE_USE_SYSTEM_FLUTTER=1 bash scripts/ci_mobile.sh ios
  locked dependency resolution: PASS
  iOS dev debug --no-codesign build: PASS
  iOS staging debug --no-codesign build: PASS

bash scripts/ci/verify_bootstrap_boundaries.sh
  non-production boundary validation: PASS
```

## Intentional failure fixtures

`scripts/ci_mobile_gate_fixtures.sh` creates disposable copies under `mktemp -d`, verifies the expected diagnostic, and removes the copies. The source checkout is not modified.

```text
intentional undefined identifier: EXPECTED FAILURE (`undefined_identifier`)
dependency version changed without lockfile: EXPECTED FAILURE (`Unable to satisfy pubspec.yaml using pubspec.lock`)
generated output ignored by `*.g.dart`: EXPECTED FAILURE (`Generated files are stale or missing`)
inline `pull_request.paths` filter: EXPECTED FAILURE (`must not contain paths`)
inline `pull_request.paths-ignore` filter: EXPECTED FAILURE (`must not contain paths`)
additional `push` trigger bypass: EXPECTED FAILURE (`exactly one pull_request trigger`)
quoted and plain top-level `on` keys together: EXPECTED FAILURE (`one unambiguous top-level on key`)
duplicate plain top-level `on` keys: EXPECTED FAILURE (`one unambiguous top-level on key`)
fixture harness result: PASS
```

## CI evidence

- Draft PR: <https://github.com/sh414lim/timefit-ax_agent/pull/16>
- Successful blocker-fix workflow: <https://github.com/sh414lim/timefit-ax_agent/actions/runs/39176969298>
- Bootstrap boundaries: PASS (5s)
- Format, analyze, coverage, Android smoke: PASS (6m19s)
- Intentional gate failure fixtures: PASS (2m10s)
- iOS no-codesign smoke: PASS (9m9s)
- Required-check setting: out of scope for this change and not claimed

## Scope and limitations

- No `pubspec.yaml` or `pubspec.lock` change.
- Generated-output verification snapshots and hashes the actual files under `lib`, `test`, and `integration_test`, independently of Git ignore rules.
- Pull request trigger validation inspects the YAML AST before semantic loading, rejecting duplicate or mixed top-level `on` keys as well as filters and additional triggers.
- Disposable fixture copies exclude regenerated build caches, dependency state, coverage, and CocoaPods outputs.
- No production identity, signing credential, secret, service, deployment, store upload, branch protection, or required-check setting change.
- Build runner reports that the pinned analyzer language version trails Dart 3.10. The exact package set is owned by CHAT-003 and was not changed in CHAT-005; generation and fatal analysis still pass.
- CI uses the pinned official Flutter source in GitHub-hosted runners. The separate FVM wrapper execution evidence remains a CHAT-003 follow-up and is not claimed here.
