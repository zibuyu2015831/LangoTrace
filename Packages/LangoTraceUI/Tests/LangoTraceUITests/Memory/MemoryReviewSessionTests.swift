import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// Covers the E8 review session state machine: empty/non-empty load, reveal,
/// two-option feedback advancing through the batch, and the finished summary.
@Suite("Memory review session view model")
@MainActor
struct MemoryReviewSessionTests {
    private func item(_ id: String) -> DepositedMemoryItem {
        DepositedMemoryItem(
            id: id, spaceID: "s", entryID: "e", sourceKind: .candidate, sourceCandidateID: "c-\(id)",
            kind: .wordPhrase, text: id, note: "note", exampleTarget: "t", exampleNative: "n",
            difficulty: .medium, createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeViewModel(batch: [DepositedMemoryItem], recorder: Recorder = Recorder()) -> MemoryReviewSessionViewModel {
        MemoryReviewSessionViewModel(
            spaceID: "s",
            actions: MemoryReviewActions(
                loadDueBatch: { _, _ in batch },
                recordOutcome: { id, outcome in await recorder.record(id, outcome) },
                markMastered: { id in await recorder.master(id) },
                statistics: { _ in .zero }
            )
        )
    }

    @Test("an empty due batch lands in the empty state")
    func emptyBatch() async {
        let vm = makeViewModel(batch: [])
        await vm.load()
        #expect(vm.phase == .empty)
    }

    @Test("a non-empty batch starts reviewing the first item, hidden until revealed")
    func nonEmptyStarts() async {
        let vm = makeViewModel(batch: [item("a"), item("b")])
        await vm.load()
        #expect(vm.phase == .reviewing)
        #expect(vm.currentItem?.id == "a")
        #expect(!vm.isRevealed)
        vm.reveal()
        #expect(vm.isRevealed)
    }

    @Test("feedback advances through the batch and finishes after the last item")
    func feedbackAdvancesAndFinishes() async {
        let recorder = Recorder()
        let vm = makeViewModel(batch: [item("a"), item("b")], recorder: recorder)
        await vm.load()
        await vm.submit(.remembered)
        #expect(vm.currentItem?.id == "b")
        #expect(!vm.isRevealed)
        await vm.submit(.needsAnotherLook)
        #expect(vm.phase == .finished)
        #expect(vm.reviewedCount == 2)
        #expect(await recorder.outcomes == ["a:remembered", "b:needsAnotherLook"])
    }

    @Test("mastering the current item advances and records mastery")
    func masterAdvances() async {
        let recorder = Recorder()
        let vm = makeViewModel(batch: [item("a")], recorder: recorder)
        await vm.load()
        await vm.masterCurrent()
        #expect(vm.phase == .finished)
        #expect(await recorder.mastered == ["a"])
    }
}

private actor Recorder {
    private(set) var outcomes: [String] = []
    private(set) var mastered: [String] = []
    func record(_ id: String, _ outcome: MemoryReviewOutcome) {
        outcomes.append("\(id):\(outcome.rawValue)")
    }

    func master(_ id: String) {
        mastered.append(id)
    }
}
