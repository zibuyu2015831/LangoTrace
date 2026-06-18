import Foundation
@testable import LangoTraceLearnerModel
import Testing

/// Value-type semantics for the Ability coverage model. These run independently of
/// the data layer (no GRDB), guarding the structural contract: two kinds only, no
/// proficiency fields, evidence provenance carried per entry.
@Suite("Ability coverage model")
struct AbilityCoverageModelTests {
    @Test("structural kind has exactly the two v1 values")
    func kindHasTwoValues() {
        #expect(AbilityCoverageKind.allCases == [.wordPhrase, .sentence])
    }

    @Test("an entry carries occurrence count and evidence provenance")
    func entryCarriesProvenance() {
        let entry = AbilityCoverageEntry(
            text: "croissant",
            kind: .wordPhrase,
            occurrenceCount: 2,
            evidence: [
                LearnerEvidenceRef(sourceType: .memoryItem, sourceID: "m1"),
                LearnerEvidenceRef(sourceType: .memoryItem, sourceID: "m2"),
            ]
        )
        #expect(entry.occurrenceCount == 2)
        #expect(entry.evidence.map(\.sourceID) == ["m1", "m2"])
        #expect(entry.evidence.allSatisfy { $0.sourceType == .memoryItem })
    }

    @Test("coverage groups entries and is equatable by content")
    func coverageEquatable() {
        let date = Date(timeIntervalSince1970: 0)
        let a = AbilityCoverage(languageCode: "en", entries: [], generatedAt: date)
        let b = AbilityCoverage(languageCode: "en", entries: [], generatedAt: date)
        #expect(a == b)
    }
}
