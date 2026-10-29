# CHAT-047 hybrid logout: fake-only candidate

This test-support candidate exercises the approved 2026-10-29 direction:
strict local protection, bounded observation of remote release, and separate
truthful results. It does not establish a product API or a server contract.

## Reuse and scope

- The existing `LocalChatSessionCoordinator` still owns repository admission,
  mutation drain, strict local stop, local purge, and retry. It is unchanged.
- `HybridLogoutCandidate` exists under `test/support` only. It supplies a local
  stop callback to that coordinator; no remote Future enters its serial local
  cleanup queue. This is a proposed composition, not current app behavior.
- The existing `ChatRealtimeSource` candidate is exercised with its fake port
  to verify immediate generation fencing and handle quarantine. Local source
  unsubscribe completion is deliberately **not** mapped to a remote ACK.
- Tests run the existing `LogoutChatDataPurger` against in-memory Drift and the
  existing deterministic private filesystem fake. No real file is deleted.
- Previous best-effort composition characterization tests remain unchanged.
  This candidate adds a different result/observation model rather than changing
  their observations or silently assigning stronger semantics to them.

## Three principles and evidence

| Principle | Candidate behavior and tests |
| --- | --- |
| Strict local protection | Synchronous callback fencing and existing repository closure; writes drain/rollback before local stop and file-first/DB-last purge. Stop, fence, purge, DB transaction, and verification failures keep local completion false and recovery required. |
| Bounded remote observation | Each fake remote operation has its own state. A manually reached boundary marks pending operations uncertain and settles observation without cancelling their underlying Futures. Local purge can finish even if those Futures never complete. |
| Separate truthful results | Local completion never infers remote success. ACK confirms only its named fake operation; unsupported, failed and uncertain remain distinct. Remote confirmation cannot bypass a pending or failed local stage. |

The local-completion predicate also requires purge verification. It does not
represent Auth credential removal or implement any actual route transition.
No remote result participates in that predicate.

## Attempts and late results

Repeated logout calls share the same attempt Future until a disposal transition
or an explicit local retry changes the observation. Disposal during an ongoing
run joins that same Future. Disposal after an undisposed logout has settled
returns a new immutable disposed snapshot; repeated dispose/logout calls then
share that disposal Future. Previously returned results remain historical and
unchanged. Each explicit local retry owns its own Future and disposal cache, so
an old completed result cannot replace a newer pending or completed retry.
Explicit local retry creates a new attempt and retries only the stage
retained by the existing local coordinator. It does not reissue remote calls:
no remote retry capability or credential availability is assumed. Any old
pending observation becomes uncertain, its waiters settle, and its late results
cannot overwrite the new attempt. Previous immutable snapshots remain readable.

A late explicit fake ACK after a manual boundary may update the current remote
result only. The local result and previously returned snapshot do not change.
Disposal fences such updates, marks outstanding remote observations uncertain,
and joins the same local cleanup. A local failure still requires explicit retry
even after disposal. Callback tokens are instance-owned, so another namespace's
candidate cannot accept an old token.
An application owner would still have to prevent replacement with a fresh
coordinator before the previous local cleanup completes. This test candidate
does not provide a process-wide admission/namespace registry.

## Limits and remaining decisions

- `confirmed` means an explicit scripted fake acknowledgement only. Tests do
  not prove server detach, device revoke support, or remote Auth sign-out.
- The three independent remote scripts may run together in this fixture. Their
  order is not an Auth/device/Realtime implementation policy.
- There are no duration constants, production timers, cancellation deadlines,
  server adapters, credentials, app wiring, routes or UI changes.
- A local mutation or local cleanup Future that never completes remains pending
  and cannot satisfy local protection. A remote boundary never skips it. There
  is no proposed local timeout/recovery-cancellation policy here.
- The result ledger is in memory. There is no durable marker, schema change,
  startup-before-use recovery, process restart guarantee or persisted namespace
  mapping. Closing and reopening a real app is outside this evidence.
- Ledger exports contain booleans, enums and opaque numeric test identities.
  Raw errors/stack, account/conversation identifiers, bodies, paths, filenames,
  URLs and credentials are not stored or stringified there.
- The reused filesystem fake has no file-incarnation model and queues outcomes
  globally by operation kind. It cannot prove safe reuse of a path while an old
  deletion is still pending. Namespace tests do not imply that stronger property.
- Pending remote work is observed, not physically cancelled. Implementations
  must still decide adapter capability, deadline ownership, late-resource
  reclamation, real Auth/device ordering, persistence, and product presentation.

Focused command:

```sh
flutter test test/features/chat/application/hybrid_logout_candidate_test.dart \
  test/features/chat/application/chat_session_realtime_cleanup_composition_test.dart \
  test/features/chat/application/chat_session_cleanup_boundary_test.dart \
  test/features/chat/application/chat_cleanup_ledger_test.dart \
  test/core/database/fake_private_chat_filesystem_test.dart
```

These results are local candidate evidence; CHAT-047 is not complete and the
normal app still does not instantiate this composition.
