import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// LM03-S3b-2: the session-summary batch deposit — candidates flow into the memory
/// review system and surface a per-candidate "已加入" state.
@MainActor
@Suite("Companion deposit store")
struct CompanionDepositStoreTests {
    /// Mutable deposited set shared between the deposit + read closures, so the stub
    /// models real idempotent deposit (deposit marks ids; read returns them).
    private final class Box: @unchecked Sendable {
        var deposited: Set<String> = []
        var depositCalls = 0
    }

    private func candidate(_ id: String) -> CompanionMemoryCandidate {
        CompanionMemoryCandidate(
            id: id, kind: .word, text: id, explanationNative: "n",
            exampleTarget: "t", exampleNative: "v", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    private func makeStore(_ box: Box, preDeposited: Set<String> = []) -> CompanionChatStore {
        box.deposited = preDeposited
        let extracted = [candidate("c1"), candidate("c2")]
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, _ in .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted(extracted) },
            depositAllCandidates: { _ in
                box.depositCalls += 1
                box.deposited.formUnion(["c1", "c2"])
                return 2
            },
            depositedCandidateIDs: { _ in box.deposited }
        )
        return CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
    }

    @Test("depositAllCandidates marks every candidate deposited; isCandidateDeposited reflects it")
    func depositAllMarksDeposited() async {
        let box = Box()
        let store = makeStore(box)
        await store.load()
        await store.extractCandidates()
        #expect(store.isCandidateDeposited("c1") == false) // none deposited yet
        #expect(store.canDeposit)

        await store.depositAllCandidates()
        #expect(store.depositedCandidateIDs == ["c1", "c2"])
        #expect(store.isCandidateDeposited("c1"))
        #expect(store.isCandidateDeposited("c2"))
    }

    @Test("depositAllCandidates is idempotent — re-running does not error and the set is stable")
    func depositIdempotent() async {
        let box = Box()
        let store = makeStore(box)
        await store.load()
        await store.extractCandidates()
        await store.depositAllCandidates()
        await store.depositAllCandidates()
        #expect(box.depositCalls == 2) // both invoked
        #expect(store.depositedCandidateIDs == ["c1", "c2"]) // stable, no duplicates
    }

    @Test("load brings out the already-deposited set so candidates show 已加入 immediately")
    func loadHydratesDepositedSet() async {
        let box = Box()
        let store = makeStore(box, preDeposited: ["c1"])
        await store.load()
        #expect(store.depositedCandidateIDs == ["c1"])
        #expect(store.isCandidateDeposited("c1"))
        #expect(store.isCandidateDeposited("c2") == false)
    }
}
