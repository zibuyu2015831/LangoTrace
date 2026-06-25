import Foundation
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Memory layer domain model: the净新增 system-level "life fact /
/// goal" value type the user explicitly remembers (ADR-006 §2 显式记住先行). Pure
/// value type, no persistence — storage/visibility defaults verified here.
@Suite("Memory fact model")
struct MemoryFactModelTests {
    @Test("default visibility is global for explicitly-saved facts")
    func defaultVisibilityIsGlobal() {
        // §12.2: a user who explicitly tells the App something defaults to global
        // (overview-visible + future companion-usable); companionOnly is reserved
        // for v2 auto-extraction.
        let fact = MemoryFact(id: "f1", kind: .lifeFact, text: "我住在上海")
        #expect(fact.visibility == .global)
        #expect(fact.source == .manualMemory)
        #expect(fact.salience == 0)
        #expect(fact.sourceEntryID == nil)
    }

    @Test("kind raw values are stable wire identifiers")
    func kindRawValuesAreStable() {
        #expect(MemoryFactKind.lifeFact.rawValue == "lifeFact")
        #expect(MemoryFactKind.preference.rawValue == "preference")
        #expect(MemoryFactKind.goal.rawValue == "goal")
        #expect(MemoryFactKind.relationship.rawValue == "relationship")
        #expect(MemoryFactKind.allCases.count == 4)
    }

    @Test("visibility raw values are stable")
    func visibilityRawValuesAreStable() {
        #expect(MemoryFactVisibility.global.rawValue == "global")
        #expect(MemoryFactVisibility.companionOnly.rawValue == "companionOnly")
    }

    @Test("evidence is derived from a weak source-entry link when present")
    func evidenceDerivesFromSourceEntry() {
        let withSource = MemoryFact(
            id: "f2",
            kind: .goal,
            text: "考过 N2",
            sourceEntryID: "entry-7"
        )
        let ref = withSource.evidence
        #expect(ref?.sourceType == .manualMemory)
        #expect(ref?.sourceID == "entry-7")

        let withoutSource = MemoryFact(id: "f3", kind: .preference, text: "喜欢爵士乐")
        #expect(withoutSource.evidence == nil)
    }
}
