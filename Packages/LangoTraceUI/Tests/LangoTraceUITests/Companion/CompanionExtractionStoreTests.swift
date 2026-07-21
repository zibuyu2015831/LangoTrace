import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// LM03-S2a Phase 4: the chat-reflux extraction flow on the store — trigger →
/// loading → one of three outcomes (count > 0 / empty / honest failure). The
/// conversation is never lost on failure and no candidates are faked.
@MainActor
@Suite("Companion extraction store")
struct CompanionExtractionStoreTests {
    private nonisolated func message(_ id: String) -> CompanionMessage {
        CompanionMessage(
            id: id, threadID: "t1", sequence: 0, role: .user, content: "hi",
            targetLanguageCode: "en", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    private nonisolated func candidate(_ id: String, messageID: String? = "m1") -> CompanionMemoryCandidate {
        CompanionMemoryCandidate(
            id: id, messageID: messageID, kind: .word, text: "word-\(id)",
            explanationNative: "n", exampleTarget: "t", exampleNative: "v",
            createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    private func makeStore(
        extract: @escaping @Sendable (String) async -> CompanionExtractionOutcome
    ) -> CompanionChatStore {
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: [message("u1")]) },
            send: { _, _, _ in .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: extract
        )
        return CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
    }

    @Test("extractionSuccessSurfacesCountAndCandidates")
    func extractionSuccess() async {
        let store = makeStore { _ in .extracted([candidate("c1"), candidate("c2")]) }
        await store.load()
        #expect(store.canExtract)
        await store.extractCandidates()
        #expect(store.isExtracting == false)
        #expect(store.lastExtractionCount == 2)
        #expect(store.candidates.map(\.id) == ["c1", "c2"])
        #expect(store.extractionFailure == nil)
    }

    @Test("extractionEmptyIsSuccessCountZeroNotFailure")
    func extractionEmpty() async {
        let store = makeStore { _ in .extracted([]) }
        await store.load()
        await store.extractCandidates()
        #expect(store.lastExtractionCount == 0)
        #expect(store.candidates.isEmpty)
        #expect(store.extractionFailure == nil)
    }

    @Test("extractionFailureKeepsConversationAndReportsHonestly")
    func extractionFailure() async {
        let store = makeStore { _ in .failed(.invalidStructuredOutput) }
        await store.load()
        await store.extractCandidates()
        #expect(store.extractionFailure == .invalidStructuredOutput)
        #expect(store.lastExtractionCount == nil)
        #expect(store.candidates.isEmpty)
        // The conversation is untouched.
        #expect(store.messages.map(\.id) == ["u1"])
    }

    @Test("cannotExtractWithoutMessages")
    func cannotExtractEmptyThread() async {
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, _ in .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        #expect(store.canExtract == false)
    }

    @Test("retryAfterFailureClearsPriorError")
    func retryClearsError() async {
        let box = FlipBox()
        let store = makeStore { _ in
            if box.firstCall {
                box.firstCall = false
                return .failed(.providerUnavailable)
            }
            return .extracted([candidate("c1")])
        }
        await store.load()
        await store.extractCandidates()
        #expect(store.extractionFailure == .providerUnavailable)
        await store.extractCandidates()
        #expect(store.extractionFailure == nil)
        #expect(store.lastExtractionCount == 1)
    }

    private final class FlipBox: @unchecked Sendable {
        var firstCall = true
    }
}
