# TimeFit AX reconstructed asset manifest

Status: `TRACE_READY` candidate; no original-pixel overlay verdict yet.

| Role ID | Runtime implementation | Status | Coordinate space | Source |
| --- | --- | --- | --- | --- |
| `brand.logo.square` | `_ReconstructedMarkPainter(square: true)` | reconstructed | normalized widget bounds | Mobile Home `libfile_83347d...` |
| `brand.mark.free` | `_ReconstructedMarkPainter(square: false)` | reconstructed | normalized widget bounds | Landscape Home `libfile_e99381...` |
| `character.robot.home` | `_ReconstructedRobotPainter` | reconstructed | normalized hero-field bounds | Mobile Home `libfile_83347d...` |
| `brand.avatar.assistant` | `_PendingAssetPainter` | pending | normalized widget bounds | business references, exact path unknown |
| `action.store` | `ReconstructedHomeActionGlyph.storeOverview` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.schedule` | `ReconstructedHomeActionGlyph.weeklySchedule` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.cost` | `ReconstructedHomeActionGlyph.costAnalysis` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.notice` | `ReconstructedHomeActionGlyph.employeeAnnouncement` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `composer.paperclip` | `_ReconstructedPaperclipPainter` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `composer.send` | `_ReconstructedSendPainter` | reconstructed | normalized 1×1 | Mobile/landscape Home |

The original vectors, exact font, robot gradient/alpha and assistant avatar were
not available. These paths must not be labeled original or visually accepted.
Their source/bbox overlay, edge heatmap and color sample comparison remain
required. Git commit and evidence-image SHA-256 values are recorded only after a
clean final commit and captures exist.
