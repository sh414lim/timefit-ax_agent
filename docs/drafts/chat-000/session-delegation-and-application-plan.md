# CHAT-000 session delegation and application plan

- Status: `REVIEW_DRAFT_NOT_APPLIED_NOT_FROZEN`
- Baseline: `sh414lim/timefit-ax_agent@10471939422cf27041a2366eb96aad398572e69e`
- Ticket: [CHAT-000](https://trello.com/c/aTapyA3V)
- Scope: unsigned architecture and contract-v1 planning only

## 1. Delegated session roles

| Work role | Primary session | Effort | Backup and activation rule |
| --- | --- | --- | --- |
| Planning, Architecture, Product-policy draft | `01a1344a-1ed1-7067-8efd-c164af0fc0ee` | high | `01a147b6-c633-75cf-95c7-8bb3b9124026` may preserve scope/evidence continuity; it does not approve its own merge decision |
| Mobile implementation | `01a147a5-2737-75a0-86ef-04bc99535025` | low | `01a147a4-27ff-7717-b4e2-55d549cbb014` may handle shared fixture or build wiring only; architecture changes return to the design session |
| Backend and CI implementation | `01a147a4-27ff-7717-b4e2-55d549cbb014` | low | `01a147a5-2737-75a0-86ef-04bc99535025` may validate consumer fixtures only; it does not self-approve backend/RLS changes |
| Independent QA and Security review | `01a147a4-9770-72b5-b5a9-788adcabc002` | high | `01a147b6-c633-75cf-95c7-8bb3b9124026` may rerun read-only verification if QA is unavailable, but merge authority then moves to `01a1344a-1ed1-7067-8efd-c164af0fc0ee` so author/reviewer/releaser do not collapse into one role |
| Release, merge and deployment verification | `01a147b6-c633-75cf-95c7-8bb3b9124026` | high | `01a1344a-1ed1-7067-8efd-c164af0fc0ee` may coordinate evidence and status if Release is unavailable; it performs no push, merge or deployment without explicit authorization and completed independent QA |

These identifiers are Codex sessions, not people, GitHub accounts, Trello members or human approval identities. No Trello member assignment or external permission is implied.

## 2. Separation rules

1. Implementation sessions do not issue the final independent QA verdict for their own changes.
2. QA/Security receives the exact immutable head and returns findings before Release decides readiness.
3. Release verifies the reviewed head, required checks, branch rules and scope before any authorized merge.
4. If the QA backup is activated, Release cannot also make the merge decision for that change; the design session performs the non-mutating readiness cross-check and the user retains external-action authority.
5. A later commit invalidates earlier exact-head QA and requires re-review.
6. Session evidence is labelled `SESSION_TECHNICAL_REVIEW`; it is never labelled verified-human, CODEOWNER, legal, store-owner or independent-human approval.

## 3. What user delegation resolves

The user delegation is sufficient for these internal workflow decisions:

- who owns the architecture/product-policy draft;
- which session prepares mobile or backend/CI implementation;
- which separate session performs technical QA/Security review;
- which session coordinates release, merge and deployment verification when separately authorized;
- backup routing, evidence handoff and routine Trello work-status updates;
- proceeding without repeatedly asking who should own those session tasks.

The delegation does not itself authorize external mutation beyond the task's stated scope.

## 4. Conditions delegation cannot satisfy

The following remain evidence-based or human/platform conditions:

- verified App Store Connect, Apple Developer, Play Console, Firebase/APNs/OAuth ownership and roles;
- correct production record selection, signing lineage, certificates/profiles, upload credentials and entitlement continuity;
- hosted security settings or repository permissions that have not actually been configured;
- actual store installation/update, supported-OS, IAP, subscription, provider and existing-user evidence;
- legal, privacy, product-policy, support, retention and store-review decisions requiring accountable people;
- a ticket or governance rule that explicitly requires a verified human/team, second human approver or GitHub CODEOWNER approval.

A session may draft the checklist and review the evidence shape, but it cannot manufacture these facts or be recorded as the accountable human.

## 5. Exact proposed `time_fit` changes

No path below is changed by this review draft. After explicit `time_fit` document-change approval, the proposed documentation PR is limited to:

| Proposed path | Change | Impact |
| --- | --- | --- |
| `docs/adr/ADR-CHAT-001-native-supabase-durable-realtime.md` | Apply the reviewed ADR draft | Freezes repository boundary, durable-write, Realtime-hint, gap-fill, Outbox and service exclusions |
| `docs/contracts/chat-v1.md` | Record exact RPC parameters/responses, required/null fields, limits, error envelope, Broadcast envelope and Storage object rules | Canonical shared contract for web, Flutter iOS and Flutter Android |
| `docs/contracts/fixtures/chat-v1/*.json` | Add success, unknown-field, missing-field, auth, authorization, validation and idempotent-retry fixtures | Shared parser/provider tests without cross-repository source coupling |
| `.github/pull_request_template.md` | Add ADR, contract version, affected clients, backend prerequisite and evidence links if absent | Makes contract impact explicit on backend/web PRs |

The corresponding later `timefit-ax_agent/.github/pull_request_template.md` change is link-only if the current template does not already expose the merged ADR and `schemaVersion: 1`. Flutter implementation, dependency, native project and production configuration changes are outside this draft.

## 6. Planned handoff order

1. Design session revises this review draft and records unresolved facts; revision alone is not freeze or approval.
2. Independent QA/Security session re-reviews the revised draft against 145/146/147, ADR-REL-002 and current Trello boundaries. A passing result is required before contract application or implementation start.
3. After explicit `time_fit` document-change authorization, Backend/CI session applies only the approved ADR/contract/fixture documentation paths on a separate branch.
4. Mobile session validates the same fixtures from the consumer side without backend source copying.
5. Independent QA/Security reviews the exact implementation head.
6. Release session verifies required checks and scope; merge or deployment still requires the authorization applicable at that time.

## 7. CHAT-000 completion boundary

This review draft supports the card's unsigned contract-freeze preparation. It does not complete CHAT-000. Completion still requires:

- review of the contract-application decisions in ADR section 7.1 and passing executable validation for the fixture-complete subset explicitly declared by `chat-v1.md`; full RPC, idempotency, pagination, attachment schema and fixture coverage remains a CHAT-001 completion condition;
- an applied `time_fit` ADR/contract documentation PR and link validation;
- review evidence for the exact applied head;
- resolution or explicit release-gated treatment of REL-001/REL-002 facts referenced by the final ADR;
- no false claim that a Codex session supplied a human-only approval.
