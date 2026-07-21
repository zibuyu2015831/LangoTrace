import Foundation
@testable import LangoTraceCore
import Testing

/// LM03-S3b-2: building a deposit input from a companion conversation candidate
/// (the chat → memory loop), plus the shared kind mapping.
@Suite("Memory deposit input")
struct MemoryDepositTests {
    private func candidate(_ kind: LearningMemoryCandidate.Kind, id: String = "c1") -> CompanionMemoryCandidate {
        CompanionMemoryCandidate(
            id: id, kind: kind, text: "text", explanationNative: "gloss",
            exampleTarget: "et", exampleNative: "en", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    @Test("Companion candidate deposit has no entry, neutral difficulty, mapped fields")
    func companionCandidateInput() {
        let input = MemoryDepositInput(companionCandidate: candidate(.word), spaceID: "s1")
        #expect(input.spaceID == "s1")
        #expect(input.entryID == nil) // conversation candidate has no owning entry
        #expect(input.sourceCandidateID == "c1")
        #expect(input.kind == .wordPhrase)
        #expect(input.text == "text")
        #expect(input.note == "gloss") // explanationNative → note
        #expect(input.exampleTarget == "et")
        #expect(input.exampleNative == "en")
        #expect(input.difficulty == .medium) // neutral seed, never reads band/difficulty
    }

    @Test("Kind mapping: word/phrase → wordPhrase; pattern/grammar/error → sentence")
    func kindMapping() {
        #expect(MemoryDepositInput(companionCandidate: candidate(.word), spaceID: "s").kind == .wordPhrase)
        #expect(MemoryDepositInput(companionCandidate: candidate(.phrase), spaceID: "s").kind == .wordPhrase)
        #expect(MemoryDepositInput(companionCandidate: candidate(.sentencePattern), spaceID: "s").kind == .sentence)
        #expect(MemoryDepositInput(companionCandidate: candidate(.grammarPoint), spaceID: "s").kind == .sentence)
        #expect(MemoryDepositInput(companionCandidate: candidate(.errorPattern), spaceID: "s").kind == .sentence)
    }

    @Test("Analysis-candidate init still carries its owning entry (regression)")
    func analysisCandidateInputUnchanged() {
        let analysis = LearningMemoryCandidate(
            id: "a1", sentenceID: nil, kind: .word, text: "w", explanationNative: "n",
            exampleTarget: "t", exampleNative: "v", difficulty: .hard
        )
        let input = MemoryDepositInput(candidate: analysis, spaceID: "s1", entryID: "e1")
        #expect(input.entryID == "e1") // entry preserved — widening to optional did not change this path
        #expect(input.difficulty == .hard)
    }
}
