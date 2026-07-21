import Combine
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// LM03-S3a: the streaming in-flight reply (`inFlightReply`) and the gentle-recast
/// correction toggle, driven through the `CompanionChatActions` seam.
@MainActor
@Suite("Companion streaming + gentle recast store")
struct CompanionStreamingStoreTests {
    private final class Box: @unchecked Sendable {
        var recastSpaceID: String?
        var recastEnabled: Bool?
    }

    private func message(_ id: String, _ role: CompanionMessageRole, _ text: String) -> CompanionMessage {
        CompanionMessage(
            id: id, threadID: "t1", sequence: 0, role: role, content: text,
            targetLanguageCode: "en", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    // MARK: - Streaming

    @Test("inFlightReply tracks the cumulative partials, then clears once the full reply is persisted")
    func inFlightReplyTracksPartialsThenClearsOnSuccess() async {
        let user = message("u1", .user, "hi")
        let assistant = message("a1", .assistant, "Hello")
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, onPartial in
                // The transport streams cumulative deltas before the turn resolves.
                onPartial("He")
                onPartial("Hello")
                return .appended(user: user, assistant: assistant)
            },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()

        // Record every published inFlightReply value to prove the bubble grew.
        var observed: [String] = []
        let cancellable = store.$inFlightReply.sink { observed.append($0) }
        defer { cancellable.cancel() }

        store.draftText = "hi"
        await store.send()

        // The in-flight bubble surfaced the cumulative reply up to the full text...
        #expect(observed.contains("He"))
        #expect(observed.contains("Hello"))
        // ...and the persisted message is the COMPLETE text, not a mid-stream partial.
        #expect(store.messages.map(\.text) == ["hi", "Hello"])
        // The transient is cleared once the real message lands.
        #expect(store.inFlightReply.isEmpty)
        #expect(store.draftText.isEmpty)
        #expect(store.failure == nil)
    }

    @Test("A failure after partial deltas clears the in-flight reply, keeps the draft, appends no assistant")
    func failureAfterPartialClearsInFlightAndKeepsDraft() async {
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, onPartial in
                onPartial("He") // streamed something...
                return .failed(.providerUnavailable) // ...then failed honestly
            },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        store.draftText = "important text"
        await store.send()

        #expect(store.failure == .providerUnavailable)
        #expect(store.inFlightReply.isEmpty) // partial discarded, never persisted
        #expect(store.draftText == "important text") // input never lost
        #expect(store.messages.isEmpty) // no faked / dangling assistant turn
    }

    // MARK: - Gentle recast (warm restate) toggle

    @Test("gentleRecastEnabled reflects the loaded persona correction posture")
    func gentleRecastEnabledReflectsLoadedPersona() async {
        let recastActions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: [], correction: .warmRecast) },
            send: { _, _, _ in .failed(.other) },
            deleteFrom: { _ in }, clear: { _ in }, extract: { _ in .extracted([]) }
        )
        let recastStore = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: recastActions)
        await recastStore.load()
        #expect(recastStore.gentleRecastEnabled)

        for posture in [CompanionCorrection.ifNeeded, .none] {
            let actions = CompanionChatActions(
                loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: [], correction: posture) },
                send: { _, _, _ in .failed(.other) },
                deleteFrom: { _ in }, clear: { _ in }, extract: { _ in .extracted([]) }
            )
            let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
            await store.load()
            #expect(store.gentleRecastEnabled == false)
        }
    }

    @Test("setGentleRecast routes the spaceID + flag through the action and updates state")
    func setGentleRecastRoutesThroughAction() async {
        let box = Box()
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: [], correction: .ifNeeded) },
            send: { _, _, _ in .failed(.other) },
            deleteFrom: { _ in }, clear: { _ in }, extract: { _ in .extracted([]) },
            setGentleRecast: { spaceID, enabled in box.recastSpaceID = spaceID; box.recastEnabled = enabled }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        #expect(store.gentleRecastEnabled == false)

        await store.setGentleRecast(true)
        #expect(box.recastSpaceID == "s1") // persona is per-space, not per-thread
        #expect(box.recastEnabled == true)
        #expect(store.gentleRecastEnabled)
    }
}
