# CHAT-032 candidate fixtures

These JSON files are an **unapproved, candidate-only namespace** used to test a
fail-closed Flutter parser while the shared backend v1 contract remains blocked.
They are not copied backend fixtures, are not evidence of server compatibility,
and must not be imported by product code.

The field names are recommendations derived from architecture section 10.6.
CHAT-001 and the backend contract remain the authority once approved. Non-empty
attachments intentionally fail because no attachment response schema is approved.

## Unapproved alternatives

The fixtures intentionally choose one narrow shape so the local decoder can be
tested, but none of these choices settles the wire contract:

| Concern | Candidate fixture choice | Still-unapproved alternative |
| --- | --- | --- |
| contract version | `schemaVersion: 1` | a `revision` field or capability-negotiated version |
| message timestamp | `createdAt` | `serverCreatedAt` |
| page shape | flat page fields | an envelope such as `data`/`error` |
| older-page token | `hasMoreBefore` plus `nextCursor` | `beforeSequence` without a cursor |
| retry delay | integer seconds | milliseconds or a typed duration field |

The candidate cursor policy fails closed unless `hasMoreBefore` and a non-empty
`nextCursor` agree. This is a defensive fixture rule, not evidence that the
server will use cursors.

## Local parser budgets

Both candidate decoders default to 1,000,000 UTF-8 bytes, depth 32, 256 entries
per container, and 4,096 total nodes. Parsed objects use a conservative detached
JSON-tree byte estimate. These values are local denial-of-service defenses only;
they are injectable in tests and are **not** approved server payload limits.

Depth is defined identically for JSON text and parsed objects: a scalar root is
depth 0, a root list/map is depth 1, and each nested list/map adds 1. Aliased
containers are allowed and counted on each appearance; an active cycle is
rejected. This definition is also candidate-only and does not set a server limit.

`maxUtf8Bytes` applies to the detached logical JSON tree on both paths. Before
parsing text, an additional derived ceiling of eight times that value bounds raw
JSON escapes and formatting; it is a local parser-allocation guard, not a wire
payload allowance or approved server limit.
