import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Companion thread learner-profile toggle (LM03-S2b-1)")
struct CompanionThreadProfileToggleTests {
    @Test("defaultsToTrue — a thread constructed without the toggle follows global")
    func defaultsToTrue() {
        let thread = CompanionThread(id: "t1", languageSpaceID: "s1", createdAt: Date(timeIntervalSince1970: 0))
        #expect(thread.usesLearnerProfile == true)
    }

    @Test("decodingWithoutKey — a payload predating the field decodes as true")
    func decodingWithoutKey() throws {
        // JSON encoded before usesLearnerProfile existed (key absent).
        let legacy = Data("""
        {"id":"t1","languageSpaceID":"s1","createdAt":0}
        """.utf8)
        let thread = try JSONDecoder().decode(CompanionThread.self, from: legacy)
        #expect(thread.usesLearnerProfile == true)
    }

    @Test("roundTrip — explicit false survives encode/decode")
    func roundTrip() throws {
        let original = CompanionThread(
            id: "t1", languageSpaceID: "s1", createdAt: Date(timeIntervalSince1970: 0), usesLearnerProfile: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CompanionThread.self, from: data)
        #expect(decoded.usesLearnerProfile == false)
    }
}
