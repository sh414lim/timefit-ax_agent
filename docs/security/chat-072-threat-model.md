# CHAT-072 mobile local security slice

Status: local evidence only. CHAT-072 remains blocked by REL-001, REL-002,
CHAT-020, and the unimplemented server authorization matrix.

## Assets and trust boundaries

| Asset | Boundary | Local mitigation | Deferred evidence |
| --- | --- | --- | --- |
| Message body and attachment metadata | Picker/UI to local application | Raw values are excluded from CHAT-071 typed exports | Server logs, retention, consent policy |
| Private attachment bytes | External picker stream to app-private copy | Count and 20 MiB limits, signature/MIME/extension agreement, UUID destination, rollback | Storage authorization and remote object policy |
| Local file URI | Drift row to upload executor | File scheme, resolved private-root containment, regular-file and byte-count checks | Remote upload authorization |
| Preview URL | Provider to in-memory preview state | Memory-only URL, expiry refresh, revoked-session fail closed, no URL export | Signed URL and permission revalidation RPC |
| Correlation identifiers | Product flow to observability sink | Typed allowlist and format validation; raw strings fail closed | User identity hashing policy remains unspecified |
| Repository credentials | Working tree/history to CI | Pinned/checksummed local scanner, complete-history requirement, redacted summaries | Hosted governance and required-check settings |

The OS picker, files it returns, Drift content, injected URL/upload providers,
and Git history are untrusted inputs. Local app code and reviewed pinned CI
scripts are the trusted enforcement boundary. Fake providers establish only
local behavior, never server authorization.

## Attack paths and mitigations

- Filename traversal or control characters: reject empty, dot-segment,
  separator-like, C0, and DEL names; store bytes under an app-generated UUID.
- Disguised payload: accept only the already specified JPEG, PNG, WebP, and PDF
  signatures when extension and optional declared MIME agree. The confirmed
  five-file and 20 MiB limits remain unchanged.
- Symlink/path substitution: resolve the private root and candidate file,
  reject non-files and paths outside the root, and verify persisted byte count.
- Revoked preview access or URL reuse: keep signed URLs in memory, invalidate on
  forbidden/session close, and do not infer restored permission locally.
- Log/crash exfiltration: CHAT-071 exports only stable typed fields; security
  regression tests cover nested raw strings, exception text, URLs, filenames,
  and invalid event codes.
- Secret committed then deleted: CI scans both the current tree and all refs.
  Inline allow comments, repository ignore files, and config environment
  variables cannot override the reviewed scanner policy.

## Explicitly deferred

There is no product deep-link parser or accepted deep-link contract in this
checkout: the router currently defines only `/`. No scheme, host, route, or
identifier rule is invented here. Deep-link validation starts only after that
contract is approved.

DB/Storage/Realtime roles, UUID authorization, revoked membership behavior,
web sharing contracts, real signed URLs, staging/device penetration evidence,
production rollout, paid services, and hosted governance settings are outside
this slice. The local tests must not be presented as evidence for those items.
