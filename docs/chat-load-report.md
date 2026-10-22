# CHAT-073 mobile performance report

Status: harness implemented; physical Android/iOS profile evidence pending.
CHAT-073 remains blocked by REL-001, REL-002, and the shared-backend/staging
work outside this mobile-only slice.

## Fixture and measurement boundary

`integration_test/chat_performance_test.dart` uses the product `ChatScreen`,
`MessageList`, `MessageRepositoryImpl`, `DriftAttachmentComposerSource`, and an
on-disk Drift database. It seeds 500 canonical messages and five uploading
attachments, closes and reopens SQLite before the first render, exercises the
complete scroll range in both directions, and observes ten persisted progress
updates before the ready state for all five attachments. The fixture does not
invoke an upload or remote provider.

The first scenario is named `reopened_sqlite_first_display`: its elapsed clock
starts immediately before `pumpWidget` and stops after the latest message and
five attachment chips are visible. Reopening the connection avoids a warm
repository instance, but it is not an OS cold-cache flush or a full app cold
start and must not be reported as either.

In profile mode each scenario registers its callback, flushes and discards
setup frames, then records raw build, raster, total, and engine-monotonic frame
timestamps plus a VM timeline and UTC scenario window. The driver writes one
reproducible JSON document to `build/performance/chat_performance.json`.
Debug/widget runs validate the harness only and explicitly report
`debug_harness_only`; they are not performance evidence.

## Reproduction

Use the repository-pinned Flutter 3.38.5 and a physical Android or iOS device:

```text
fvm flutter drive --profile \
  --flavor dev \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/chat_performance_test.dart \
  -d <physical-device-id>
```

Preserve the generated JSON with the sanitized device model, OS version,
thermal/power state, run commit, and whether the run was repeated. Do not
compare simulator, emulator, debug, or widget-test elapsed time to physical
device profile results.

## Current evidence

On 2026-10-22 `flutter devices --machine` exposed only macOS and Chrome. No
physical Android/iOS target was connected, so no profile FrameTiming, timeline,
percentile, or pass/fail performance claim is recorded here. No server SLO or
staging workload was executed.

## Deferred scope

- Staging send/history load, duplicate client IDs, Realtime delay and gap-fill.
- Existing web baseline, database pool/lock evidence, query plans, and k6 JSON.
- Physical Android/iOS profile repetitions and an approved mobile frame budget.
- Production traffic, deployment, paid services, and backend contract changes.
