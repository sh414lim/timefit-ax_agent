# CHAT-070: dev-local preview keyboard slice

Base: `2e130575e738185b6863cefcc0e62614d5367ea1`. Local branch:
`fix/chat-070-preview-keyboard`. Validation date: 2026-10-28.

This fixes the mobile preview shell only. It does not complete CHAT-070, enable
business actions, or establish source-image fidelity or device accessibility.
The existing user Simulator, its in-memory Home draft and persisted data were
not manipulated, terminated, reinstalled or reset during this change.

## Reproduction and cause

The permanent `Home to analysis fits landscape large text and keyboard` test
first failed on the unmodified base with **183px bottom RenderFlex overflow**.
It starts at the real Home action, rather than substituting a different shell.

- Logical viewport: 852×393, DPR 1.
- TextScaler: linear 2.0; dark theme.
- Keyboard inset: 216dp; safe top 24dp; viewPadding bottom 16dp, effective bottom
  padding zero while the keyboard is visible.
- Draft: twelve lines of synthetic Korean text. The bundled Nanum Gothic is a
  layout control, not the original image font or the native iOS renderer.

The effective body was 852×153. `_MobilePreview` laid out a 56dp header and up to
five expanded input lines as inflexible Column children; `Expanded` on the
result list could not recover the height already consumed by those children.

## Change

- Measure one input line using the effective theme input style and TextScaler,
  including the existing input padding. Do not reduce the font or truncate text.
- Bound the input viewport by the actual LayoutBuilder body constraints while
  retaining multiline Return, the existing five-line normal layout and internal
  editing scroll.
- Reserve a 44dp result viewport. When even the header, one complete scaled input
  line, padding and this viewport cannot fit, allow the bounded shell to scroll.
- Keep a stable widget structure across keyboard/height changes; do not replace
  the TextField or its controller/FocusNode. This protects selection and IME.
- Explicitly size the mobile back action to 44×44dp. This is a touch-target change;
  business actions, data, colors, assets and the normal content structure remain
  unchanged.

## Checks

`test/accessibility/demo_preview_keyboard_test.dart` contains **45 passing tests**:

- the original Home-to-analysis red/green regression;
- all four Home shortcuts, three entry/back cycles each, with unchanged draft and
  no conversation/create/archive callbacks;
- nine viewport configurations for each of the four previews: 393×852/1x,
  320×640/2x/keyboard280, 390×844/1.5x/keyboard280, 430×932/2x,
  852×393/2x/keyboard216, 852×393/1x/keyboard216,
  852×320/2x/keyboard216, 899×393/2x/keyboard216, and 1024×768/1x;
- full visible bounds, actual taps and minimum 44dp dimensions for send, leading
  attachment/add and back actions, without invoking real business operations;
- an editable viewport at least one preferred line high, unchanged TextScaler,
  internal text scroll and result-list scrolling where content exceeds its view;
- four editing lifecycle cases: same EditableText State, focus, complete editing
  value, selection and composing range through keyboard/rotation/resize; later
  multiline edits and actual internal drag scroll, including horizontal safe
  areas of 44/34dp.

Light/dark are both represented. This is a widget matrix, not actual OS Dynamic
Type or VoiceOver/TalkBack validation.

| Validation | Result |
| --- | --- |
| Permanent red test before product edit | Expected failure, 183px; exit 1 |
| Focused final regression | 45 PASS, exit 0 |
| Full existing + new suite | 495 PASS, exit 0; existing strict goldens unchanged |
| Analyze with fatal infos/warnings | No issues, exit 0 |
| Format lib/test/integration_test | 164 files, 0 changed, exit 0 |
| Generated comparison | Fresh build_runner build, exit 0; 107 tracked lib files including all 5 generated files byte-identical |
| Default geometry A/B | 16 base and 16 fixed cases PASS; workflow list/composer/input/send/logo rects identical |
| Diff check | PASS |

The geometry comparison used the same control renderer at 393×852 and 430×932,
four actions, short/long drafts, scale 1. It excludes the deliberately enlarged
back touch target. Layout rect equality is not a pixel/color/font fidelity claim.

Generated validation copied inputs into a fresh temporary tree **without copying
existing `.g.dart` files**, used the locked offline package cache, and ran
`dart run build_runner build` without a conflicting-output deletion option.
No original/generated source files or previous build directories were deleted.
All new temporary QA evidence was retained. The standard cleanup/deletion-based
gate script was not used; the independent byte comparison is the reported gate.

Diagnostic log names retained locally: `chat070-preview-red.log`,
`chat070-preview-matrix-final.log`, `chat070-preview-full.log`,
`chat070-preview-analyze-final.log`, `chat070-preview-format-final.log`,
`chat070-preview-generated.log`, and the `chat070-preview-geometry-*-final.log`
pair. Earlier fixture development failures were retained too; they are not
counted as successful runs.

## Unresolved expanded schedule boundary

A separate diagnostic at **900×600**, no keyboard, using the same Korean control
font failed on both the new tree and the untouched base:

- 1x: 2.9px right overflow in the expanded schedule result action row.
- 2x: 105px bottom overflow in `_ExpandedChat`, and 56px right overflow in the
  workflow result action row.

This lies in the expanded chat/result-card path, not the mobile keyboard shell.
It was not fixed or counted as a passing configuration, and no existing test was
skipped or weakened. The exploratory diagnostic and failure logs remain as
`qa_chat070_expanded_baseline_test.dart` and
`chat070-preview-expanded-baseline.log`; the initial broad matrix failures are
also retained. A width-aware action layout and bounded expanded chat need a
separate change coordinated with the other result-card work. Do not interpret
the full in-repository suite PASS as coverage of this known failing boundary.

## Not run / boundaries

No Simulator UI or device installation, native renderer, actual OS 200% setting,
VoiceOver/TalkBack, Android, staging, server, login, sync, upload, deployment,
remote Git or Trello mutation was performed. Existing user inputs/data remain
untouched. No assertion is made that the entire ticket or original visual
matching is complete.
