# CHAT-079 visual delta resolution

Original tracking baseline: `712e5136aa39b43048abfbaf69190405b0f98c02`

Current correction baseline: `5dc2dafa5bd3157a32709cd2f75fce0a7ee5e39d`

Follow-up correction base: `0c3364cf416f14fa92b7a00848a3b7bb2ad65327`

Sources reviewed directly in the signed-in Library viewer:

- mobile Home, approval, notice, and analytics PNG/JPEG reference pairs;
- landscape Home, approval, analytics, and schedule references;
- the independent `REVIEW-712e5136.md` and the 50-row
  `timefit-ax-head-712e5136-fidelity-delta-v0.1.csv`.

The reconstructed vectors below are controlled traces. They are not original
brand exports and are not accepted as pixel-identical until a same-canvas
overlay can be run. Library materialization still fails technically, so this
revision must not claim an automated edge, overlay, SSIM, or colour-delta pass.

## Post-5dc2daf correction checkpoint

This revision addresses the independently reproduced source-variant and
one-frame composition failures without changing the demo-only data boundary:

- compact mobile workflow presentation keeps notice confirmation, analytics
  insight/chips, schedule actions, and approval automation/confirmation above
  the composer in the supplied `402x874` frame;
- mobile analytics retains a saturated outgoing bubble and plain unequal KPI
  tiles without role glyphs, while expanded analytics uses a pale outgoing bubble, desktop KPI
  comparisons, paperclip composer, and four source question chips;
- expanded approval uses the paperclip/filled-send composer. The mobile
  approval plus remains outside its pale input field while the plane is now
  inside that field;
- the expanded chart announces raw won, not thousands of won, and its two
  labelled peaks use anchors consistent with `620,000/800,000` and
  `780,000/800,000`;
- the Home demo disclosure is an overlay instead of a header-flow item, the
  hero falloff is visible, and the card/composer rhythm is based on available
  height rather than one fixed cutoff.

These are local structural corrections, not a visual-acceptance claim. The
follow-up branch uses the measurement catalogue's explicitly labelled
estimated viewer transcription for the expanded analysis explanation and four
questions. It is regression-tested as a presentation candidate, but remains
subject to direct source-byte confirmation. Original logo, robot, glyph and
font exports remain unavailable; reconstructed assets remain comparison
targets rather than exemptions.

## Post-4faa0bc independent-QA correction

The independent `REVIEW-4faa0bc.md` reproduced three remaining composition
problems. This checkpoint closes their local bounds without changing the
memory-only demo contract:

- the first approval deadline is now a separate, title-aligned row inside the
  request card. It no longer inherits the narrow text column left between the
  role field and action buttons, and 320x760 plus 1024x768 regressions assert
  that the clock and label remain inside the pill without overflow;
- the expanded store explanation is shortened from the estimated viewer
  transcription to the four painted lines visible at the proposed 1024x576
  comparison fixture. This remains a presentation candidate, not proof of the
  unavailable source text bytes;
- the Home body retains its measured 9.5dp height but uses compact Korean
  tracking to approximate the unavailable source font width. All four cards
  now retain the supplied two-line composition at both 402dp and 432dp without
  clipping.

These fixes remove deterministic layout differences only. They do not resolve
the original brand vectors, runtime font identity, same-canvas overlay, or
Simulator capture requirements, so visual acceptance remains pending.

### Evidence correction

The four previously named `*-ipadpro13-landscape-native-buffer.png` files are
`2064x2752` upright portrait-shaped tablet renders. They are preserved as
historical evidence, but **must not be cited as landscape evidence**. Rotating
the PNG or changing its filename does not establish a landscape viewport. A
replacement capture is accepted only when the running app exposes the
expanded shell in a landscape viewport and the native screenshot dimensions
are wider than tall. Device, OS, exact HEAD, build entrypoint, logical
viewport and raw pixel size must be recorded together. This is separate from
the still-open 16:9 source versus 4:3 iPad responsive comparison.

## Fifty-row delta tracking

`implemented` means the identified structure is present and has a local
regression. It does not mean visual acceptance. `pending visual QA` means a new
same-condition capture is needed. `blocked` and `out of reference` retain the
meaning from the source review.

| Source row/item | Status in this revision | Resolution or remaining limit |
| --- | --- | --- |
| GLOBAL new PNG role | reference only | Kept as source evidence; never counted as current output. |
| GLOBAL approval capture | pending visual QA | Approval stays component-only; mobile and landscape capture targets are included in the evidence plan. |
| GLOBAL tablet canvas | evidence correction required | Prior `2064x2752` upright captures are portrait tablet evidence, not landscape. They stay preserved but cannot support the expanded-landscape claim. A verified width>height native capture is required and still must not be stretched to the 16:9 source. |
| GLOBAL primary aliases | partial | Screen-specific Home aliases remain; workflow role colours are separated where the source proves a difference. Exact colour delta is blocked by source-byte transfer. |
| GLOBAL runtime font | blocked | The source family/renderer is unknown. Platform font remains explicitly unverified. |
| M_HOME square logo | implemented, pending visual QA | Replaced generic T-plus with a filled cap, hooked/check stem, negative-space-aware silhouette and sparkle family. |
| M_HOME hero field | implemented, pending visual QA | Uses a stronger radial falloff instead of a flat ellipse; final falloff and aspect still need new capture comparison. |
| M_HOME robot silhouette | implemented, pending visual QA | Head/bezel/face, eyes, ears, antenna, rays, speech-tail torso and independently sized chest mark are reconstructed. |
| M_HOME action grid | partial, pending visual QA | Source-density two-column cards remain. The block is placed from available height and retains responsive one-column adaptation, but exact source glyph/text scale remains open. |
| M_HOME card copy | functional regression closed, fidelity open | Width 402 and 432 regressions assert all four descriptions retain at most two painted lines without clipping. Mobile fields remain 44/48dp, type remains 12.5/9.5dp, and compact tracking approximates the unavailable source font width while the 2.15:1 source card ratio stays fixed. This is not source-font approval. |
| M_HOME mobile tile colour | implemented | All four mobile fields are pale blue with blue glyphs. |
| M_HOME quick-action paths | partial, pending visual QA | Controlled bar/calendar/database/document-pen painters remain; exact path overlay is blocked. |
| M_HOME composer gap | implemented, pending visual QA | Available-height rhythm brings cards and composer together without a fixed height cutoff. Final same-aspect anchors still require a new capture. |
| M_HOME demo badge | unresolved product constraint | Visible local-only disclosure is required. It is not masked from comparison and remains a known source delta. |
| M_NOTICE header variant | implemented, pending visual QA | Mobile workflow header is centered and no longer displaced by the demo badge; Back remains as a required local navigation control. |
| M_NOTICE assistant avatar | implemented, pending visual QA | Uses the reconstructed TimeFit mark avatar, not a robot face. |
| M_NOTICE result icon | implemented | Dedicated megaphone painter and semantic role. |
| M_NOTICE result card density | implemented, pending visual QA | Compact mobile presentation keeps both actions and the final confirmation above the composer at the source-height fixture. Exact source bbox density still needs capture review. |
| M_NOTICE final assistant bubble | implemented | Confirmation bubble and timestamp are restored before the composer. |
| M_NOTICE composer variant | implemented | Paperclip with pale-blue send treatment. |
| M_APPROVAL current screen | pending visual QA | Component exists; no general Home route is invented. Role fields preserve orange/mint/lavender separation and the clock deadline pill now occupies a bounded title-aligned row at narrow and expanded widths. A component-only Simulator capture is still required and must be labelled as such. |
| M_APPROVAL composer variant | implemented | Plus remains outside the pale field; the unfilled grey plane is now inside the text field as in the mobile source. |
| M_ANALYSIS outgoing bubble | implemented | Saturated blue surface and white text. |
| M_ANALYSIS assistant avatar | implemented | TimeFit mark and timestamp. |
| M_ANALYSIS result density | implemented, pending visual QA | Compact result keeps insight and both mobile chips above the composer at the source-height fixture. Exact source bbox density needs capture review. |
| M_ANALYSIS KPI widths | implemented | Mobile keeps unequal 268/220/225 proportions without desktop role glyphs or comparison pills; landscape keeps role glyphs, comparison pills, and separate 221/210/212 anatomy. |
| M_ANALYSIS chart anatomy | implemented | Unit, axes, labels, smooth curve, area fill, dots and two peak callouts. Expanded semantics use raw won and labelled peak anchors match the 800,000-won axis. |
| M_ANALYSIS insight/chips | implemented, pending visual QA | Sparkle, divider, supporting copy, timestamp and both suggestion chips are in the initial source-height composition. |
| M_ANALYSIS composer variant | implemented | Plus leading control with filled blue send. |
| M_SCHEDULE header/chat | partial, pending visual QA | Centered header, mark avatar and timestamps are present; exact source spacing awaits capture. |
| M_SCHEDULE result density | partial | Full week/table/info/actions anatomy remains responsive; exact bbox awaits capture. |
| M_SCHEDULE employee/weekend | implemented | Initial avatars, name/role cells, Sunday red and Saturday blue. |
| M_SCHEDULE safety notice | implemented | The source result is no longer followed by a long layout-displacing safety sentence; the compact demo chip remains explicit. |
| M_SCHEDULE composer variant | implemented | Paperclip with pale-blue send treatment. |
| L_HOME sidebar | partial | Existing recent conversation data/navigation remains; source-only sample rows are not written to Drift. |
| L_HOME free mark | implemented, pending visual QA | Uses the same reconstructed mark family without a square. |
| L_HOME tile variants | implemented | Blue/green/purple/orange fields and role-specific glyph colours are separated from mobile. |
| L_ANALYSIS shell details | implemented candidate, pending visual QA | The title is `매장 분석`; selected/recent rows, timestamps, pale outgoing bubble, a four-line second assistant explanation, and four vertically stacked full-sentence questions are present. The explanation is adapted from the catalogue's estimated viewer transcription to the observed four-line composition and still needs direct source-byte confirmation. |
| L_ANALYSIS result anatomy | implemented, pending visual QA | Live state, unequal KPI blocks, role glyphs, comparison pills, raw-won semantics, source-consistent peak anchors, chart and insight are present. |
| L_ANALYSIS sidebar brand | implemented | Free blue mark and all-blue wordmark. |
| L_SCHEDULE shell details | implemented, pending visual QA | Selected recent row, chat timestamps and bottom suggestion chips. |
| L_SCHEDULE result anatomy | implemented, pending visual QA | Export/share, range/subtitle/success/more, eight avatars, weekend colours, totals, confirm then edit. |
| L_APPROVAL current screen | pending visual QA | Component-only presentation uses the expanded paperclip/filled-send variant. Capture is required; reference imagery is not implementation proof and no general Home route is invented. |
| L_NOTICE mapping | out of reference | Kept as a responsive proposal, never counted among the nine supplied screens. |
| COST mapping | out of reference | Continues to reuse the analytics presentation and is labelled as a proposal, not a supplied cost design. |
| RESPONSIVE small widths | implemented | Existing 320/390/430 checks plus 402/432 copy checks remain. |
| RESPONSIVE text 100/200% | implemented as functional gate | No-overflow/scroll checks remain separate from source fidelity. |
| RESPONSIVE keyboard | implemented as functional gate | Draft/focus/reachability tests remain; the source does not establish keyboard visuals. |
| RESPONSIVE rotation | pending corrected Simulator evidence | State preservation remains tested. Prior upright `2064x2752` buffers are not landscape evidence; final raw viewport/orientation/native dimensions must be recorded. |
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
- The expanded analysis copy is adapted from the measurement catalogue's
  estimated viewer transcription to the observed four-line composition. Exact
  source bytes remain unavailable, so copy identity remains unverified even
  though the local line-count regression is deterministic.
- The preserved iPad buffers from the `5dc2daf` evidence set are portrait-shaped
  renders despite their filenames. They remain historical artifacts only; a
  corrected, truly landscape capture is still required.
