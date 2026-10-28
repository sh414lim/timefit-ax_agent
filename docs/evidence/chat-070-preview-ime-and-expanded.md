# CHAT-070: Home/preview IME and expanded follow-up

Date: 2026-10-28. Base: `f2fd8ad58d1411258dd9419dc0a816ec554a4d72`.
Branch: `fix/chat-070-preview-ime`. The previous worktree/head was preserved.
IME-only checkpoint: `6ac971a1b001848a5ded27637be78350d346d8fd`.

## IME red/green

Independent review found that the previous controller/FocusNode checks were
insufficient. Before this edit, the permanent test
`focused Home to preview keeps the live IME connection` failed with
`hasAnyClients == false` after tapping Home's analysis shortcut. The editing
value, composing range and focus still matched; that did not prove a working
input connection. The previous 45 tests covered preview resizing but missed this
focused Home-to-preview boundary. The issue also existed before the mobile
overflow change.

Home now owns one GlobalKey for the shared composer. That identity is explicitly
passed through mobile/expanded Home and preview layouts so the actual
EditableText subtree is reparented instead of disposed. No unfocus/refocus,
post-frame keyboard reopening or platform-client replacement is used as a
substitute. Controllers and FocusNodes keep their existing ownership rules.

`demo_home_preview_ime_test.dart` has **25 passing tests**:

- the original failing transition;
- four shortcuts × five initial views: 393×852/1x/keyboard280,
  320×640/2x/keyboard280, 852×393/2x/keyboard216, 900×600/2x,
  and 1024×900/1x/keyboard280;
- two forward/back cycles per case, including intermediate mobile rotations and
  restoration to the original form factor while selection/composing are active;
- the same EditableText State, focused node, complete editing value, visible
  keyboard stub and active client after every step;
- no new TextInput.clearClient, setClient or hide calls during those transitions;
- later multiline editing still received by the existing client;
- unmount closes the client; four initially unfocused cases do not open one.

These are Flutter platform-channel stub assertions, not a new native Simulator
IME test or a device-keyboard/video claim.

## Expanded layout red/green

After the IME checkpoint was fixed, a separate permanent regression reproduced
the 900×600 expanded schedule failures with no keyboard, at 1x and 2x. Both the
default widget-test font and bundled Nanum Gothic control were checked.

For a twelve-line synthetic draft, the Korean control reported right overflow
2.9px at 1x and bottom/right 105px/56px at 2x. The default test font reported
6.2px and 198px/62px. Independent QA's 17px bottom report uses a different
fixture/rendering configuration; no claim is made that these numeric cases are
identical. The same failing expanded Column/action paths are covered and all
four explicit font/scale cases now pass.

Changes:

- The expanded chat has a bounded, vertically scrollable shell with its original
  minimum available height. A 44dp intrinsic bound around the lazy conversation
  viewport avoids requesting intrinsic sizes from a ListView. At normal heights,
  Expanded still receives the original remaining space.
- The editor viewport is bounded by actual available height and at least one
  scaled input line; text, Return and input identity remain unchanged.
- Result action labels can wrap, and their containers retain a minimum 48dp
  height instead of clipping large text to a fixed 48dp height. They remain
  disabled, display-only semantics inside the unchanged IgnorePointer pane.
- Wider focused-Home regression exposed its navigation sidebar overflowing at
  900dp/2x. The sidebar uses the same bounded intrinsic/scroll pattern, preserving
  its lazy recent-conversation list and existing callbacks.
- Other-screen regression exposed narrow expanded notice heading/meta rows;
  their text is now flexible/wrapping instead of overflowing horizontally. The
  same text-row bound applies to checklist rows. No text, font size, colors,
  assets, fixture data or business operation was changed.

`demo_expanded_preview_test.dart` has **32 passing tests**: the four original
font/scale regressions plus four actions × seven Korean-control cases:
900×600 at 1x/2x and 2x/keyboard280, 1024×768 at 1x/2x, and 1366×768 at 1x/2x.
Both themes are represented. Tests check no layout exceptions, full visible
44dp send/add/back targets with real widget taps, unchanged draft/scaler,
editable line height/scroll extent, and fully visible unclipped schedule labels.
Disabled result labels are checked visually/semantically, not falsely treated
as clickable business operations.

## Final integrated checks

| Check | Result |
| --- | --- |
| IME failure before edit | Expected FAIL: active client false, exit 1 |
| Expanded failure before edit | 4 expected failures, exit 1 |
| Mobile + IME + expanded focused suite | 102 PASS, exit 0 |
| Full existing/new tests | 552 PASS, exit 0; no skips or golden baseline rewrites |
| Analyze, fatal infos/warnings | No issues, exit 0 |
| Format lib/test/integration_test | 166 files, 0 changed, exit 0 |
| Fresh generator build | exit 0; all 107 tracked lib files, including 5 regenerated files, byte-identical |
| Normal expanded geometry A/B | base 18 PASS / fixed 18 PASS; measured rects identical |
| Diff check | PASS |

Normal geometry used 1024×768 and 1536×864 at 1x with the same control renderer:
four previews with short/long drafts, plus Home at both sizes. Conversation
viewport, composer/input/send/logo positions and Home sidebar/logo/settings
positions were identical. This is geometry evidence, not raster/font/color
identity with the supplied reference images.

Generation used fresh copied inputs without existing `.g.dart` files, the locked
offline cache and build_runner **without** a conflicting-output deletion flag.
Generated files and the prior worktrees were not deleted. Temporary QA inputs
and failures were retained. No schema, lockfile, backend or remote-worker change
was made.

Retained local logs: `chat070-ime-red.log`, `chat070-ime-matrix.log`,
`chat070-expanded-red.log`, `chat070-ime-expanded-matrix-v2.log`,
`chat070-ime-expanded-full.log`, `chat070-ime-expanded-analyze.log`,
`chat070-ime-expanded-format.log`, `chat070-ime-expanded-generated.log`, and
`chat070-expanded-geometry-{base,fixed}.log`. Initial exploratory failures remain
recorded; they are not silently reclassified as PASS.

## Boundaries and handoff

These are implementer-local checks awaiting independent review of the final
head. No existing Simulator/app/user draft or persisted user data was operated
on. No new screenshot, install, signing, physical device, Android, staging,
server, authentication, network/security setting, paid feature, deployment,
remote Git or Trello operation occurred. No file deletion or build cleanup was
performed. Native IME, VoiceOver/TalkBack and original visual fidelity remain
unverified, so the entire CHAT-070 ticket is not declared complete.
