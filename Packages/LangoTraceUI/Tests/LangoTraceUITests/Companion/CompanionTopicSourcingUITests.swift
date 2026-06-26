import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Companion topic sourcing UI (LM03-S2b-2)")
struct CompanionTopicSourcingUITests {
    private final class FakeTopicConsent: CompanionTopicSourcingConsentStore, @unchecked Sendable {
        var consent: CompanionTopicSourcingConsent = .notDecided
        func reset() {
            consent = .notDecided
        }
    }

    private final class Box: @unchecked Sendable {
        var sendCalled = false
    }

    private func store(box: Box = Box(), topic: FakeTopicConsent = FakeTopicConsent(), usesProfile: Bool = true) -> CompanionChatStore {
        let actions = CompanionChatActions(
            loadThread: { _, _ in CompanionLoadedThread(threadID: "t1", messages: [], usesLearnerProfile: usesProfile) },
            send: { _, _ in box.sendCalled = true; return .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) }
        )
        return CompanionChatStore(spaceID: "s1", sourceEntryID: nil, actions: actions, topicConsentStore: topic)
    }

    @Test("notDecidedNeedsPreviewBlocksSourcing — one-time preview required, sourcing off")
    func notDecidedNeedsPreviewBlocksSourcing() async {
        let s = store()
        await s.load()
        #expect(s.needsTopicSourcingPreview)
        #expect(s.canSourceTopic == false)
    }

    @Test("enabledWithToggleSources — sticky decision, sources when enabled + toggle on")
    func enabledWithToggleSources() async {
        let topic = FakeTopicConsent()
        let s = store(topic: topic)
        await s.load()
        s.setTopicConsent(.enabled)
        #expect(s.needsTopicSourcingPreview == false)
        #expect(s.canSourceTopic)
        #expect(topic.consent == .enabled)
    }

    @Test("toggleOffBlocksSourcing — per-conversation toggle off blocks even when consented")
    func toggleOffBlocksSourcing() async {
        let s = store(usesProfile: false)
        await s.load()
        s.setTopicConsent(.enabled)
        #expect(s.canSourceTopic == false)
    }

    @Test("loadNeverSendsEvenWhenTopicAuthorized — cold-start zero-outbound preserved")
    func loadNeverSendsEvenWhenTopicAuthorized() async {
        let box = Box()
        let topic = FakeTopicConsent()
        topic.consent = .enabled
        let s = store(box: box, topic: topic)
        await s.load()
        // Topic finding is a send-turn decision (App side); load must NEVER egress.
        #expect(box.sendCalled == false)
        #expect(s.showsColdStartGreeting)
    }

    @Test("broughtInRecordsLabelIsNonEmpty — descriptor renders an included label")
    func broughtInRecordsLabelIsNonEmpty() {
        #expect(!RequestPreviewCardModel.label(for: .broughtInRecords).isEmpty)
    }
}
