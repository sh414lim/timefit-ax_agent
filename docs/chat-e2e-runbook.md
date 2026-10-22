# CHAT-074 local fault E2E runbook

Status: local scripted-fault preparation only. CHAT-074 remains blocked by
REL-001, REL-002, staging backend work, and physical-device evidence.

## Covered local vertical paths

`integration_test/chat_e2e_test.dart` and its host-test mirror exercise the
production `ChatScreen`, composer, `SendMessage`, file-backed Drift database,
and `OutboxWorker`. The injected executor is deterministic test code, not an
RPC adapter or server fixture.

- Three messages are entered through the UI while no worker is running. After
  closing and reopening SQLite, a reconstructed worker preserves command and
  client IDs and insertion order, including identical timestamps and IDs whose
  lexical order is the reverse of creation order.
- One scripted response records a remote-like commit but returns
  `unknown_commit_timeout`. The retry uses the same ID and the fake ledger
  converges without a duplicate; a wake immediately before the persisted retry
  deadline remains ineligible and the exact deadline is eligible.
- An upload command is interrupted at persisted 60/100 progress. Closing and
  reopening SQLite preserves the attachment and lease; a reconstructed worker
  reclaims the expired lease and completes the local fixture.
- With two files, one ready and one failed, the production composer disables
  send and creates neither a local message nor a message outbox command.

The host test is executable without claiming device behavior:

```text
fvm flutter test test/integration/chat_local_fault_e2e_test.dart
```

Use a physical Android or iOS device for the integration target:

```text
fvm flutter test integration_test/chat_e2e_test.dart \
  --flavor dev -d <physical-device-id>
```

## Not covered by this slice

- Actual airplane mode, Wi-Fi/cellular transitions, process kill, or OS resume.
- Actual upload, RPC, server canonical rows, Realtime blocking, polling
  gap-fill, membership revoke, or shared-backend role policy.
- Existing web smoke, staging fixture functions, nightly ten-run evidence,
  physical-device video, release gates, production, or deployment.

The scripted ledger must never be reported as server, staging, network, or
physical-device evidence. No performance or reliability threshold is inferred
from host-test execution.
