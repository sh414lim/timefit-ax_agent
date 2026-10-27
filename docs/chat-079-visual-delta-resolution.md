# CHAT-079 visual delta resolution

Baseline: `712e5136aa39b43048abfbaf69190405b0f98c02`

Sources reviewed directly in the signed-in Library viewer:

- mobile Home, approval, notice, and analytics PNG/JPEG reference pairs;
- landscape Home, approval, analytics, and schedule references;
- the independent `REVIEW-712e5136.md` and the 50-row
  `timefit-ax-head-712e5136-fidelity-delta-v0.1.csv`.

The reconstructed vectors below are controlled traces. They are not original
brand exports and are not accepted as pixel-identical until a same-canvas
overlay can be run. Library materialization still fails technically, so this
revision must not claim an automated edge, overlay, SSIM, or colour-delta pass.

## Fifty-row delta tracking

`implemented` means the identified structure is present and has a local
regression. It does not mean visual acceptance. `pending visual QA` means a new
same-condition capture is needed. `blocked` and `out of reference` retain the
meaning from the source review.

| Source row/item | Status in this revision | Resolution or remaining limit |
| --- | --- | --- |
| GLOBAL new PNG role | reference only | Kept as source evidence; never counted as current output. |
| GLOBAL approval capture | pending visual QA | Approval stays component-only; mobile and landscape capture targets are included in the evidence plan. |
| GLOBAL tablet canvas | pending visual QA | 4:3 Simulator evidence remains responsive evidence, never stretched to the 16:9 source. |
| GLOBAL primary aliases | partial | Screen-specific Home aliases remain; workflow role colours are separated where the source proves a difference. Exact colour delta is blocked by source-byte transfer. |
| GLOBAL runtime font | blocked | The source family/renderer is unknown. Platform font remains explicitly unverified. |
| M_HOME square logo | implemented, pending visual QA | Replaced generic T-plus with a filled cap, hooked/check stem, negative-space-aware silhouette and sparkle family. |
| M_HOME hero field | implemented, pending visual QA | Uses a radial falloff instead of a flat ellipse. |
| M_HOME robot silhouette | implemented, pending visual QA | Head/bezel/face, eyes, ears, antenna, rays, speech-tail torso and independently sized chest mark are reconstructed. |
| M_HOME action grid | implemented, pending visual QA | Source-density two-column cards retained; responsive one-column adaptation remains separate. |
| M_HOME card copy | implemented | Width 402 and 432 regressions assert all four `RenderParagraph`s do not exceed two lines. |
| M_HOME mobile tile colour | implemented | All four mobile fields are pale blue with blue glyphs. |
| M_HOME quick-action paths | partial, pending visual QA | Controlled bar/calendar/database/document-pen painters remain; exact path overlay is blocked. |
| M_HOME composer gap | pending visual QA | Layout no longer changes solely to satisfy a fixed height; final same-aspect vertical anchor must be measured from the new capture. |
| M_HOME demo badge | unresolved product constraint | Visible local-only disclosure is required. It is not masked from comparison and remains a known source delta. |
| M_NOTICE header variant | implemented, pending visual QA | Mobile workflow header is centered and no longer displaced by the demo badge; Back remains as a required local navigation control. |
| M_NOTICE assistant avatar | implemented, pending visual QA | Uses the reconstructed TimeFit mark avatar, not a robot face. |
| M_NOTICE result icon | implemented | Dedicated megaphone painter and semantic role. |
| M_NOTICE result card density | partial | Content anatomy is preserved; final source bbox density needs new capture review. |
| M_NOTICE final assistant bubble | implemented | Confirmation bubble and timestamp are restored before the composer. |
| M_NOTICE composer variant | implemented | Paperclip with pale-blue send treatment. |
| M_APPROVAL current screen | pending visual QA | Component exists; no general Home route is invented. |
| M_APPROVAL composer variant | implemented | Plus leading control and unfilled grey plane treatment. |
| M_ANALYSIS outgoing bubble | implemented | Saturated blue surface and white text. |
| M_ANALYSIS assistant avatar | implemented | TimeFit mark and timestamp. |
| M_ANALYSIS result density | partial | Full chart anatomy and chips are present; exact one-screen density needs new capture review. |
| M_ANALYSIS KPI widths | implemented | Existing unequal 27/22/23 layout is preserved; landscape keeps 221/210/212 proportions. |
| M_ANALYSIS chart anatomy | implemented | Unit, axes, labels, smooth curve, area fill, dots and two peak callouts. |
| M_ANALYSIS insight/chips | implemented | Sparkle, divider, supporting copy, timestamp and both suggestion chips. |
| M_ANALYSIS composer variant | implemented | Plus leading control with filled blue send. |
| M_SCHEDULE header/chat | partial, pending visual QA | Centered header, mark avatar and timestamps are present; exact source spacing awaits capture. |
| M_SCHEDULE result density | partial | Full week/table/info/actions anatomy remains responsive; exact bbox awaits capture. |
| M_SCHEDULE employee/weekend | implemented | Initial avatars, name/role cells, Sunday red and Saturday blue. |
| M_SCHEDULE safety notice | implemented | The source result is no longer followed by a long layout-displacing safety sentence; the compact demo chip remains explicit. |
| M_SCHEDULE composer variant | implemented | Paperclip with pale-blue send treatment. |
| L_HOME sidebar | partial | Existing recent conversation data/navigation remains; source-only sample rows are not written to Drift. |
| L_HOME free mark | implemented, pending visual QA | Uses the same reconstructed mark family without a square. |
| L_HOME tile variants | implemented | Blue/green/purple/orange fields and role-specific glyph colours are separated from mobile. |
| L_ANALYSIS shell details | partial | Selected/recent rows, timestamps and question chips are present; exact sidebar copy density awaits capture. |
| L_ANALYSIS result anatomy | implemented, pending visual QA | Live state, unequal KPI blocks, role glyphs, comparison pills, source labels, chart and insight are present. |
| L_ANALYSIS sidebar brand | implemented | Free blue mark and all-blue wordmark. |
| L_SCHEDULE shell details | implemented, pending visual QA | Selected recent row, chat timestamps and bottom suggestion chips. |
| L_SCHEDULE result anatomy | implemented, pending visual QA | Export/share, range/subtitle/success/more, eight avatars, weekend colours, totals, confirm then edit. |
| L_APPROVAL current screen | pending visual QA | Capture is required; reference imagery is not implementation proof. |
| L_NOTICE mapping | out of reference | Kept as a responsive proposal, never counted among the nine supplied screens. |
| COST mapping | out of reference | Continues to reuse the analytics presentation and is labelled as a proposal, not a supplied cost design. |
| RESPONSIVE small widths | implemented | Existing 320/390/430 checks plus 402/432 copy checks remain. |
| RESPONSIVE text 100/200% | implemented as functional gate | No-overflow/scroll checks remain separate from source fidelity. |
| RESPONSIVE keyboard | implemented as functional gate | Draft/focus/reachability tests remain; the source does not establish keyboard visuals. |
| RESPONSIVE rotation | pending Simulator evidence | State preservation remains tested; final raw capture orientation and viewport must be recorded. |
| UX behaviour contract | preserved | Preview actions remain memory-only; Drift/message/attachment/Outbox mutation remains zero. |

## Explicit unresolved items

- No original logo/robot vector or exact font asset is available. The new paths
  require visual review and must continue to be labelled reconstructed.
- Original Library bytes cannot currently be materialized. Automated
  overlay/edge/colour comparison is blocked by a technical transfer failure,
  not by a permission denial.
- Approval remains a presentation component because adding a general-app route
  is a product decision not established by the four Home action cards.
- There is no supplied cost-specific or landscape-notice reference. Those
  screens remain proposals and cannot contribute to nine-screen fidelity.
- The visible demo disclosure intentionally differs from the source and must
  not be masked from a future comparison.
