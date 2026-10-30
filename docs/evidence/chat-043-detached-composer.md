# CHAT-043: detached editor admission

## Ticket and local scope

- Ticket: [CHAT-043 — 텍스트 composer와 optimistic 제출 UX](https://trello.com/c/krgD8cqP).
- Main baseline: `dd990d7510efc86baba7b4355660efc0503067ca`.
- The card is still in the backlog, incomplete and Blocked on its original
  dependencies. This local correction does not complete the ticket.
- The selected gap affects the existing dev-local editor: closing/switching a
  conversation disposes its composer while the shared repository/DB session can
  remain open for the next conversation. A retained callback or controller
  reference must not start another mutation for that closed editor.

## Reproduction and correction

Before changing product code, the initial ten-test suite produced nine failures:
disposed submit created a real in-memory Drift message and Outbox command;
disposed retry requeued a failed command; disposed admission still consulted
released dependencies; and a retained production composer button callback wrote
after the editor was unmounted. The shared-session fixture created both the old
and new conversation's messages instead of only the new one.

`ComposerController` now rejects new submit/retry calls and draft edits after
disposal. `canSubmit` returns false before inspecting an expired admission
predicate or released attachment source. A further four-case reentrancy fixture
initially failed in three cases: a predicate could dispose the editor and still
return true for `canSubmit`, retry or failed-attachment removal. All mutation
admission paths now recheck disposal after the injected predicate returns.

Already admitted submit/retry operations retain their existing shared Future
and settle once, including failure. Disposal is not cancellation or purge and
does not close the shared DB session. The existing repository/session boundary
still decides whether an admitted write may commit or must roll back when the
session itself is revoked. No remote cancellation policy is established here.

## Evidence

- New regression suite: `test/features/chat/application/composer_disposal_test.dart`.
- It uses only in-memory Drift, scripted submitters/sources, and the production
  `ChatComposer` widget; no user database, file, account, or Simulator is used.
- The final new suite contains 14 regression tests. Coverage includes real
  message/Outbox non-creation, failed-row and client-ID
  preservation, released dependencies, admitted success/failure drain and
  Future sharing, a new conversation in the shared session, and a retained
  send callback after unmount, and synchronous disposal during admission.
- Focused new/existing composer, attachment barrier and session/Drift suites:
  69 tests passed.
- Full Flutter regression, including existing goldens: 861 tests passed.
- Generated-file consistency passed without source/generated drift (the
  existing analyzer/SDK compatibility warning remains; dependencies unchanged).
- Analyze, format and bootstrap boundary checks passed.

## Unchanged behavior and limits

No visual widget, design token, text, golden baseline, schema, dependency,
network adapter, Auth, app composition, worker or server state was changed.
The new-conversation fixture remains pending/queued, attempt count zero, with
no server identity or canonical sequence.

The retained-callback widget test is deterministic local regression evidence,
not proof of native event ordering or real VoiceOver/TalkBack behavior. No
physical device, Simulator interaction, process-restart validation or live
server test was performed. Draft persistence, real send/reconciliation and
the card's existing external prerequisites remain outside this slice.

This checkpoint is local-only; no Trello mutation, public push, PR or merge is
part of implementation validation.
