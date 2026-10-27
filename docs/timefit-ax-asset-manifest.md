# TimeFit AX reconstructed asset manifest

Status: `TRACE_READY` candidate; no original-pixel overlay verdict yet.

| Role ID | Runtime implementation | Status | Coordinate space | Source |
| --- | --- | --- | --- | --- |
| `brand.logo.square` | `_ReconstructedMarkPainter(square: true)` | reconstructed | normalized widget bounds | Mobile Home `libfile_83347d...` |
| `brand.mark.free` | `_ReconstructedMarkPainter(square: false)` | reconstructed | normalized widget bounds | Landscape Home `libfile_e99381...` |
| `character.robot.home` | `_ReconstructedRobotPainter` | reconstructed | normalized hero-field bounds | Mobile Home `libfile_83347d...` |
| `brand.avatar.assistant` | `_ReconstructedAssistantPainter` | reconstructed | normalized widget bounds | Mobile notice/analysis assistant mark |
| `action.store` | `ReconstructedHomeActionGlyph.storeOverview` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.schedule` | `ReconstructedHomeActionGlyph.weeklySchedule` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.cost` | `ReconstructedHomeActionGlyph.costAnalysis` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `action.notice` | `ReconstructedHomeActionGlyph.employeeAnnouncement` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `composer.paperclip` | `_ReconstructedPaperclipPainter` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `composer.plus` | `_ReconstructedPlusPainter` | reconstructed | normalized 1×1 | Mobile approval/analysis |
| `composer.send` | `_ReconstructedSendPainter` | reconstructed | normalized 1×1 | Mobile/landscape Home |
| `workflow.approval.leave` | `_WorkflowRoleGlyphPainter.leave` | reconstructed | normalized 1×1 | Mobile approval |
| `workflow.approval.shift` | `_WorkflowRoleGlyphPainter.shift` | reconstructed | normalized 1×1 | Mobile approval |
| `workflow.approval.receipt` | `_WorkflowRoleGlyphPainter.receipt` | reconstructed | normalized 1×1 | Mobile approval |
| `workflow.approval.automation.mobile` | `_ApprovalGearPainter` | reconstructed | normalized 1×1 | Mobile approval |
| `workflow.approval.automation.landscape` | `_InsightSparklePainter` | reconstructed | normalized 1×1 | Landscape approval |
| `workflow.notice.megaphone` | `_NoticeMegaphonePainter` | reconstructed | normalized 1×1 | Mobile notice |
| `workflow.analytics.insight` | `_InsightSparklePainter` | reconstructed | normalized 1×1 | Mobile/landscape analysis |

The original vectors, exact font and exact robot gradient/alpha were not
available. The assistant trace follows the observed blue mark avatar rather
than the Home robot face. These paths must not be labeled original or visually
accepted.
Their source/bbox overlay, edge heatmap and color sample comparison remain
required. Git commit and evidence-image SHA-256 values are recorded only after a
clean final commit and captures exist.
