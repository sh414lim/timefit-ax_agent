# TimeFit AX pixel-fidelity implementation

Status: local implementation slice, not visual acceptance  
Source baseline: `timefit-ax-pixel-fidelity-spec-v0.3.md` and
`timefit-ax-source-measurements-v0.3.csv` (356 rows: 196 measured,
158 estimated, 2 proposed)

## Evidence and provenance

All nine Library originals were opened in the signed-in read-only Library viewer
before this implementation. The rejected CHAT-079 feedback render is not used as
a design source. Source status bars and personal sample values are not copied into
fixtures.

The measurements are consumed with their original confidence:

- `measured`: primary geometry evidence for source-relative layout.
- `estimated`: useful for hierarchy and approximate placement, never described as
  an exact token.
- `proposed`: product safety additions excluded from reference overlays.

## Architecture

```text
DevChatShell (database/session/lifecycle owner)
  └─ DemoHomeScreen (memory-only selection and draft)
       ├─ MobileHomePresentation (9:16 source hierarchy)
       ├─ TabletHomePresentation (16:9 source hierarchy)
       └─ DemoBusinessPreviewScreen (memory-only result selection)
            ├─ Mobile result card presentation
            └─ Expanded sidebar/chat/result presentation
```

The shell keeps all Drift and navigation callbacks. Home and preview widgets do
not create conversations, write messages, start workers, or invoke remote
adapters. A quick action changes only an in-memory enum. Returning from a preview
restores the same `TextEditingController`, focus node, selection, and draft.

## Source variants

Mobile Home preserves this order: brand header, robot asset slot, black title,
two-line subtitle, 2×2 horizontal cards, paperclip composer. It does not add a
central recent list, new-chat CTA, development banner, or long safety paragraph.

Expanded Home preserves the 17.8% sidebar, TimeFit symbol asset slot, two-tone
title, four-card row, and bottom composer. Recent conversations remain a read-only
projection of the existing controller. Mobile and expanded presentations share
content models, not a stretched layout tree.

Business previews preserve their distinct anatomy:

| Preview | Mobile | Expanded |
| --- | --- | --- |
| store analysis | chat result with KPI/chart/insight | sidebar + chat + wide result |
| weekly schedule | chat result with compact week grid | sidebar + chat + wide matrix |
| approvals | stacked request cards | sidebar + chat + approval result pane |
| announcement | chat result with audience/date/channel review | common expanded shell with review card |

Every action remains a review or sample interaction. No button represents a real
approval, announcement send, schedule confirmation, or automation success.

## Tokens

`TimeFitAxVisualTokens` is an additive `AppTheme` extension consumed only by the
copied presentation; it does not replace any existing global color or typography
token. Light values are JPEG sample estimates recorded by v0.3, not approved
production brand tokens. Dark values are accessibility-preserving product
proposals because no dark original exists.

Source-pixel measurements are mapped through the reference viewport rather than
copied as Flutter dp. Exact overlays use 432×768 logical at DPR 2 for mobile and
1024×576 logical at DPR 1.5 for expanded 16:9. Other viewports preserve hierarchy
and scroll reachability, but are responsive evidence rather than exact overlays.

## Asset policy

The repository contains no approved TimeFit logo, tablet symbol, smiling robot,
assistant mark, source icon set, or exact font files. The square mark, free mark,
Home robot, assistant avatar, four Home action glyphs, workflow role glyphs,
paperclip, and send plane are therefore human-controlled `CustomPainter`
reconstructions of observed JPEG anatomy. They are marked `reconstructed`, never
`original`, and contain no stock, Material, or generated mascot. The assistant
avatar is explicitly inferred from the business-screen avatar and Home robot
anatomy; it remains an overlay-review target rather than an accepted original.

The approval presentation is implemented as the reusable
`DemoBusinessPreviewScreen.approvals` component. The supplied Home has no
approval shortcut, so this screen is intentionally component-only until an
approved navigation route exists. Home's four actions remain executable in the
dev-local app.

Required before visual acceptance:

1. original square logo, tablet symbol and robot SVG/transparent PNG, or an
   accepted overlay review of the reconstructed paths;
2. assistant avatar asset with clear-space guidance;
3. exact font family/weights and redistribution approval;
4. source icon set or approved mappings.

Until those arrive, asset regions are overlay masks/exemptions and the result may
pass functional/layout tests but cannot pass pixel fidelity.

## Verification contract

- functional: memory-only actions, zero Drift/remote mutations, draft/focus
  preservation, existing local chat/attachment/restart flows;
- responsive: 320/390/430 and 1024/1366 widths, text scale 1/2, keyboard and
  scroll reachability, light/dark;
- visual: actual app theme/font/renderer captures at the two source viewports,
  then source-aligned overlay and diff;
- acceptance: functional PASS and visual PASS are reported separately. Missing
  assets, font uncertainty, simulator mismatch, and masked regions remain open.

