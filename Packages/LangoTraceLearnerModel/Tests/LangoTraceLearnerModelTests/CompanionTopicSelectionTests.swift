import Foundation
import LangoTraceCore
@testable import LangoTraceLearnerModel
import Testing

@Suite("Companion topic selection (LM03-S2b-2 recency top-1)")
struct CompanionTopicSelectionTests {
    private func candidate(_ id: String, at seconds: TimeInterval) -> CompanionTopicCandidate {
        CompanionTopicCandidate(id: id, title: id, body: "body \(id)", createdAt: Date(timeIntervalSince1970: seconds))
    }

    @Test("picksMostRecent — top-1 is the newest candidate regardless of input order")
    func picksMostRecent() {
        let candidates = [candidate("a", at: 1), candidate("c", at: 3), candidate("b", at: 2)]
        let selected = CompanionTopicSelection.select(candidates: candidates)
        #expect(selected.map(\.id) == ["c"])
    }

    @Test("emptyInEmptyOut — no candidates yields nothing")
    func emptyInEmptyOut() {
        #expect(CompanionTopicSelection.select(candidates: []).isEmpty)
    }

    @Test("respectsLimit — limit 0 yields nothing; limit > count returns all recency-sorted")
    func respectsLimit() {
        let candidates = [candidate("a", at: 1), candidate("b", at: 2)]
        #expect(CompanionTopicSelection.select(candidates: candidates, limit: 0).isEmpty)
        #expect(CompanionTopicSelection.select(candidates: candidates, limit: 5).map(\.id) == ["b", "a"])
    }

    @Test("deterministicTieBreak — equal createdAt breaks on id desc")
    func deterministicTieBreak() {
        let candidates = [candidate("a", at: 5), candidate("b", at: 5)]
        #expect(CompanionTopicSelection.select(candidates: candidates).map(\.id) == ["b"])
    }
}
