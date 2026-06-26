import Foundation
import LangoTraceCore
@testable import LangoTraceLearnerModel
import Testing

@Suite("Companion memory selection (LM03-S2b-1 recency + kind quota)")
struct CompanionMemorySelectionTests {
    private func fact(
        _ id: String,
        _ kind: MemoryFactKind,
        at seconds: TimeInterval,
        salience: Int = 0,
        visibility: MemoryFactVisibility = .global,
        softDeletedAt: Date? = nil
    ) -> MemoryFact {
        MemoryFact(
            id: id, kind: kind, text: id, salience: salience, visibility: visibility,
            createdAt: Date(timeIntervalSince1970: seconds), softDeletedAt: softDeletedAt
        )
    }

    @Test("returnsTopFiveRecencyFirst — given oldest-first input, newest is selected first")
    func returnsTopFiveRecencyFirst() {
        // Provider returns oldest-first; selection must re-sort to recency-DESC.
        let facts = (0 ..< 7).map { fact("f\($0)", .lifeFact, at: TimeInterval($0)) }
        let selected = CompanionMemorySelection.select(facts: facts, limit: 5)
        #expect(selected.count == 5)
        #expect(selected.first?.id == "f6") // newest
        #expect(selected.map(\.id) == ["f6", "f5", "f4", "f3", "f2"])
    }

    @Test("kindQuota — a single chatty kind cannot monopolise the budget")
    func kindQuota() {
        // 6 recent lifeFacts + 1 older goal. Pure recency would pick 5 lifeFacts;
        // the quota must surface the older goal.
        var facts = (0 ..< 6).map { fact("life\($0)", .lifeFact, at: TimeInterval(100 + $0)) }
        facts.append(fact("goal0", .goal, at: 1))
        let selected = CompanionMemorySelection.select(facts: facts, limit: 5)
        #expect(selected.count == 5)
        #expect(selected.contains { $0.id == "goal0" })
        #expect(selected.count(where: { $0.kind == .lifeFact }) == 4)
        #expect(selected.first?.id == "life5") // most recent overall still leads
    }

    @Test("emptyAndUnderLimit — empty in empty out; fewer than limit returns all")
    func emptyAndUnderLimit() {
        #expect(CompanionMemorySelection.select(facts: [], limit: 5).isEmpty)
        let three = [fact("a", .lifeFact, at: 3), fact("b", .goal, at: 2), fact("c", .preference, at: 1)]
        #expect(Set(CompanionMemorySelection.select(facts: three, limit: 5).map(\.id)) == ["a", "b", "c"])
    }

    @Test("excludesCompanionOnlyAndDeleted — only global, active facts are selected")
    func excludesCompanionOnlyAndDeleted() {
        let facts = [
            fact("g", .lifeFact, at: 3),
            fact("co", .goal, at: 9, visibility: .companionOnly),
            fact("del", .preference, at: 8, softDeletedAt: Date(timeIntervalSince1970: 10)),
        ]
        let selected = CompanionMemorySelection.select(facts: facts, limit: 5)
        #expect(selected.map(\.id) == ["g"])
    }

    @Test("salienceIndependent — selection is identical regardless of salience values")
    func salienceIndependent() {
        let low = [
            fact("a", .lifeFact, at: 2, salience: 0),
            fact("b", .lifeFact, at: 1, salience: 0),
        ]
        let high = [
            fact("a", .lifeFact, at: 2, salience: 999),
            fact("b", .lifeFact, at: 1, salience: 5),
        ]
        #expect(CompanionMemorySelection.select(facts: low).map(\.id)
            == CompanionMemorySelection.select(facts: high).map(\.id))
    }
}
