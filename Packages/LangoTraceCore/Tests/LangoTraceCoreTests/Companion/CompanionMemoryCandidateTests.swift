@testable import LangoTraceCore
import XCTest

/// LM03-S2a Phase 1: the chat-reflux memory candidate value type. It reuses the
/// learning-material `LearningMemoryCandidate.Kind` vocabulary (word / phrase /
/// sentencePattern / grammarPoint / errorPattern) so chat-sourced candidates ride
/// the same review surface (plan §交付物 A / D1).
final class CompanionMemoryCandidateTests: XCTestCase {
    func testConstructsWithSemanticFieldsAndOptionalSourceMessage() {
        let candidate = CompanionMemoryCandidate(
            id: "c1",
            messageID: "m1",
            kind: .phrase,
            text: "break the ice",
            explanationNative: "打破沉默、缓和气氛",
            exampleTarget: "Let's break the ice with a quick game.",
            exampleNative: "我们用一个小游戏来打破沉默。",
            createdAt: Date(timeIntervalSince1970: 1000)
        )

        XCTAssertEqual(candidate.id, "c1")
        XCTAssertEqual(candidate.messageID, "m1")
        XCTAssertEqual(candidate.kind, .phrase)
        XCTAssertEqual(candidate.text, "break the ice")
    }

    func testSourceMessageIDDefaultsToNilForOrphanedCandidate() {
        // After the source message is deleted (message_id SET NULL), the candidate
        // survives with a nil weak reference (ADR-008 §4 / plan round-1 P2-2).
        let candidate = CompanionMemoryCandidate(
            id: "c2",
            kind: .word,
            text: "ephemeral",
            explanationNative: "短暂的",
            exampleTarget: "an ephemeral moment",
            exampleNative: "一个短暂的瞬间",
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        XCTAssertNil(candidate.messageID)
    }

    func testReusesEveryLearningMemoryCandidateKind() {
        // The chat-reflux candidate must accept the full learning-material Kind set
        // so the two candidate sources can later merge onto one review surface (D1).
        for kind in LearningMemoryCandidate.Kind.allCases {
            let candidate = CompanionMemoryCandidate(
                id: "k-\(kind.rawValue)",
                kind: kind,
                text: kind.rawValue,
                explanationNative: "n",
                exampleTarget: "t",
                exampleNative: "v",
                createdAt: Date(timeIntervalSince1970: 0)
            )
            XCTAssertEqual(candidate.kind, kind)
        }
    }

    func testEquatableDistinguishesByEveryField() {
        let base = CompanionMemoryCandidate(
            id: "c3",
            messageID: "m3",
            kind: .word,
            text: "serene",
            explanationNative: "宁静的",
            exampleTarget: "a serene lake",
            exampleNative: "一片宁静的湖",
            createdAt: Date(timeIntervalSince1970: 3000)
        )
        var differentKind = base
        differentKind.kind = .grammarPoint
        var orphaned = base
        orphaned.messageID = nil

        XCTAssertEqual(base, base)
        XCTAssertNotEqual(base, differentKind)
        XCTAssertNotEqual(base, orphaned)
    }
}
