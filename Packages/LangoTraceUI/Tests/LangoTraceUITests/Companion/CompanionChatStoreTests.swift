import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Companion chat store")
struct CompanionChatStoreTests {
    private final class Box: @unchecked Sendable {
        var sendCalled = false
    }

    private func message(_ id: String, _ role: CompanionMessageRole, _ text: String) -> CompanionMessage {
        CompanionMessage(
            id: id, threadID: "t1", sequence: 0, role: role, content: text,
            targetLanguageCode: "en", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    @Test("coldStartGreetingIsLocalNoOutbound — empty thread shows greeting without sending")
    func coldStartGreetingIsLocalNoOutbound() async {
        let box = Box()
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, _ in box.sendCalled = true; return .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        #expect(store.phase == .ready)
        #expect(store.showsColdStartGreeting)
        #expect(store.messages.isEmpty)
        #expect(box.sendCalled == false) // loading never triggers an outbound request
    }

    @Test("Sending appends the user then assistant turn and clears the draft")
    func sendAppendsUserAndAssistant() async {
        let user = message("u1", .user, "hi")
        let assistant = message("a1", .assistant, "hello")
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, _ in .appended(user: user, assistant: assistant) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        store.draftText = "hi"
        await store.send()
        #expect(store.messages.map(\.id) == ["u1", "a1"])
        #expect(store.messages.map(\.isUser) == [true, false])
        #expect(store.draftText.isEmpty)
        #expect(store.showsColdStartGreeting == false)
        #expect(store.failure == nil)
    }

    @Test("failureStatePreservesUserInputAndDoesNotFake — draft kept, no assistant appended")
    func failureStatePreservesUserInputAndDoesNotFake() async {
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: []) },
            send: { _, _, _ in .failed(.providerUnavailable) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions)
        await store.load()
        store.draftText = "important text"
        await store.send()
        #expect(store.failure == .providerUnavailable)
        #expect(store.draftText == "important text") // never lost
        #expect(store.messages.isEmpty) // no faked reply, no dangling turn
    }

    @Test("Unavailable when the App has no database")
    func unavailableWithoutDatabase() async {
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: .disabled)
        await store.load()
        #expect(store.phase == .unavailable)
    }

    @Test("canSend requires non-blank draft and not mid-send")
    func canSendGating() {
        let store = CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: .disabled)
        #expect(store.canSend == false)
        store.draftText = "   "
        #expect(store.canSend == false)
        store.draftText = "hi"
        #expect(store.canSend)
    }
}
