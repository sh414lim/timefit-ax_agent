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
generated source without committed generated output: EXPECTED FAILURE (`Generated files are stale or missing`)
fixture harness result: PASS
```

## CI evidence

- Draft PR: pending
- Successful non-required workflow URL: pending
- Intentional failure workflow URL: the safe fixture job is part of the PR workflow; pending
- Required-check setting: out of scope for this change and not claimed

## Scope and limitations

- No `pubspec.yaml` or `pubspec.lock` change.
- No production identity, signing credential, secret, service, deployment, store upload, branch protection, or required-check setting change.
- Build runner reports that the pinned analyzer language version trails Dart 3.10. The exact package set is owned by CHAT-003 and was not changed in CHAT-005; generation and fatal analysis still pass.
- CI uses the pinned official Flutter source in GitHub-hosted runners. The separate FVM wrapper execution evidence remains a CHAT-003 follow-up and is not claimed here.
