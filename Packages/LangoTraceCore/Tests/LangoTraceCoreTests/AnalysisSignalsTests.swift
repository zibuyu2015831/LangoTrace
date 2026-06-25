import Foundation
@testable import LangoTraceCore
import Testing

/// Covers the LM02-S4a signal value types: the source-content-origin forward seam
/// (v1 default user-authored) and the lookup behaviour event.
@Suite("Analysis signal value types")
struct AnalysisSignalsTests {
    @Test("source content origin raw values are stable; default is user-authored")
    func sourceContentOriginDefaults() {
        #expect(SourceContentOrigin.userAuthored.rawValue == "userAuthored")
        #expect(SourceContentOrigin.aiGenerated.rawValue == "aiGenerated")
        let event = DictionaryLookupEvent(
            id: "e1", languageSpaceID: "s1", lookedUpTerm: "ephemeral",
            sourceContentID: "doc-1", occurredAt: Date(timeIntervalSince1970: 0)
        )
        #expect(event.sourceContentOrigin == .userAuthored)
    }

    @Test("lookup event carries behaviour fields, never AI content")
    func lookupEventCarriesBehaviourFields() {
        let event = DictionaryLookupEvent(
            id: "e1", languageSpaceID: "s1", lookedUpTerm: "ephemeral",
            sourceContentID: "doc-1", occurredAt: Date(timeIntervalSince1970: 100)
        )
        #expect(event.lookedUpTerm == "ephemeral")
        #expect(event.sourceContentID == "doc-1")
        #expect(event.occurredAt == Date(timeIntervalSince1970: 100))
    }
}
