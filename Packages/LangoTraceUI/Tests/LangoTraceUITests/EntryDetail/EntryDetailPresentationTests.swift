import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Entry source collapse presentation")
struct EntrySourceCollapsePresentationTests {
    @Test("Short single-line text is not expandable")
    func shortTextNotExpandable() {
        let presentation = EntrySourceCollapsePresentation.make(for: "今天去了海边。")

        #expect(presentation.isExpandable == false)
        #expect(presentation.collapsedLineLimit == EntrySourceCollapsePresentation.collapsedLineLimit)
    }

    @Test("Empty / whitespace text is not expandable")
    func emptyTextNotExpandable() {
        #expect(EntrySourceCollapsePresentation.make(for: "   \n  ").isExpandable == false)
        #expect(EntrySourceCollapsePresentation.make(for: "").isExpandable == false)
    }

    @Test("Text with more newlines than the collapsed line limit is expandable")
    func manyLinesAreExpandable() {
        let lines = (0 ..< (EntrySourceCollapsePresentation.collapsedLineLimit + 2))
            .map { "第\($0)行" }
            .joined(separator: "\n")

        #expect(EntrySourceCollapsePresentation.make(for: lines).isExpandable == true)
    }

    @Test("Long continuous text beyond the character threshold is expandable")
    func longContinuousTextIsExpandable() {
        let long = String(repeating: "あ", count: EntrySourceCollapsePresentation.expandableCharacterThreshold + 1)

        #expect(EntrySourceCollapsePresentation.make(for: long).isExpandable == true)
    }
}

@Suite("Learning material action availability")
struct LearningMaterialActionAvailabilityTests {
    private func make(_ state: LearningMaterialGenerationState, stale: Bool = false) -> LearningMaterialActionAvailability {
        LearningMaterialActionAvailability.make(generationState: state, sourceEntryIsStale: stale)
    }

    @Test("Regenerate and reanalyze are always available in idle/generated/editing/cancelled/failed")
    func availableInRestingStates() {
        let restingStates: [LearningMaterialGenerationState] = [
            .idle,
            .generated(materialID: "m1"),
            .editing(materialID: "m1", analysisIsStale: false),
            .cancelled(materialID: "m1"),
            .failed(LearningMaterialGenerationFailureDisplay(category: .networkUnavailable)),
        ]

        for state in restingStates {
            let availability = make(state)
            #expect(availability.canRegenerate == true)
            #expect(availability.canReanalyze == true)
            #expect(availability.canEdit == true)
        }
    }

    @Test("Regenerate availability no longer depends on source staleness")
    func independentOfStaleness() {
        let fresh = make(.generated(materialID: "m1"), stale: false)
        let stale = make(.generated(materialID: "m1"), stale: true)

        #expect(fresh.canRegenerate == true)
        #expect(stale.canRegenerate == true)
    }

    @Test("All actions are disabled while a generation or analysis is running")
    func disabledWhileRunning() {
        let runningStates: [LearningMaterialGenerationState] = [
            .generating(operationID: DiagnosticOperationID(rawValue: "op-1")),
            .analyzing(materialID: "m1", operationID: DiagnosticOperationID(rawValue: "op-2")),
        ]

        for state in runningStates {
            let availability = make(state)
            #expect(availability.canRegenerate == false)
            #expect(availability.canReanalyze == false)
            #expect(availability.canEdit == false)
        }
    }

    @Test("AI actions are disabled in every blocked reason to avoid doomed requests")
    func disabledWhenBlocked() {
        for reason in LearningMaterialGenerationBlockReason.allCases {
            let availability = make(.blocked(reason))
            #expect(availability.canRegenerate == false, "regenerate must be disabled for \(reason)")
            #expect(availability.canReanalyze == false, "reanalyze must be disabled for \(reason)")
        }
    }
}
