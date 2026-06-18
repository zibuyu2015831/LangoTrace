import LangoTraceCore

/// Pure presentation model deciding how the source-text card collapses on the entry
/// detail page. Lives in the UI package so it can read `LearningMaterialGenerationState`
/// (LangoTraceCore) and `RenderingSentence`/`LearningRendering` (LangoTraceData), but it
/// holds no SwiftUI state and is fully unit-testable without a running UI.
///
/// Collapsing uses a line-count heuristic (`lineLimit`) rather than a fixed pixel height
/// so the layout respects Dynamic Type. The thresholds are intentionally independent from
/// `EntryTextEditorSheetSizing.preference` (which sizes an editor sheet, a different
/// concern) even though the length/newline idea is borrowed.
struct EntrySourceCollapsePresentation: Equatable {
    /// Number of lines shown before the text is collapsed.
    static let collapsedLineLimit = 6
    /// Trimmed character count beyond which a single long block is treated as expandable.
    static let expandableCharacterThreshold = 180

    let collapsedLineLimit: Int
    let isExpandable: Bool

    static func make(for text: String) -> EntrySourceCollapsePresentation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return EntrySourceCollapsePresentation(collapsedLineLimit: collapsedLineLimit, isExpandable: false)
        }

        let lineCount = trimmed.components(separatedBy: .newlines).count
        let isExpandable = lineCount > collapsedLineLimit || trimmed.count > expandableCharacterThreshold

        return EntrySourceCollapsePresentation(collapsedLineLimit: collapsedLineLimit, isExpandable: isExpandable)
    }
}

/// Pure presentation model deciding which learning-material actions (regenerate,
/// reanalyze, edit) are available, given the current generation state and whether the
/// source entry has drifted from the rendered material.
///
/// Regenerate (re-translate) and reanalyze (re-explain) are user-initiated AI calls and
/// are kept always available (no longer gated on staleness), aligning with the core
/// decision that AI capabilities run only on explicit user triggers. They are disabled only when a
/// call is already running or when the generation state is blocked (which would make the
/// request doomed to fail). Editing is disabled only while a call is running.
struct LearningMaterialActionAvailability: Equatable {
    let canRegenerate: Bool
    let canReanalyze: Bool
    let canEdit: Bool

    static func make(
        generationState: LearningMaterialGenerationState,
        sourceEntryIsStale _: Bool
    ) -> LearningMaterialActionAvailability {
        let isRunning = generationState.isRunning
        let isBlocked = switch generationState {
        case .blocked:
            true
        case .idle, .generating, .generated, .editing, .analyzing, .failed, .cancelled:
            false
        }

        let canRunAICall = !isRunning && !isBlocked
        return LearningMaterialActionAvailability(
            canRegenerate: canRunAICall,
            canReanalyze: canRunAICall,
            canEdit: !isRunning
        )
    }
}
