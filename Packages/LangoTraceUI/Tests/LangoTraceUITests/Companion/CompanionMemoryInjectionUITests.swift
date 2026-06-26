import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Companion memory injection UI (LM03-S2b-1)")
struct CompanionMemoryInjectionUITests {
    private final class FakeConsentStore: CompanionMemoryConsentStore, @unchecked Sendable {
        var consent: CompanionMemoryConsent = .notDecided
        func reset() {
            consent = .notDecided
        }
    }

    private final class Box: @unchecked Sendable {
        var toggleWrites: [Bool] = []
    }

    private func actions(box: Box, usesLearnerProfile: Bool) -> CompanionChatActions {
        CompanionChatActions(
            loadThread: { _, _ in
                CompanionLoadedThread(threadID: "t1", messages: [], usesLearnerProfile: usesLearnerProfile)
            },
            send: { _, _ in .failed(.other) },
            deleteFrom: { _ in },
            clear: { _ in },
            extract: { _ in .extracted([]) },
            setUsesLearnerProfile: { _, enabled in box.toggleWrites.append(enabled) }
        )
    }

    @Test("notDecidedNeedsPreviewAndBlocksInjection — the one-time preview is required, injection off")
    func notDecidedNeedsPreviewAndBlocksInjection() async {
        let consent = FakeConsentStore()
        let store = CompanionChatStore(
            spaceID: "s1", sourceEntryID: nil, actions: actions(box: Box(), usesLearnerProfile: true),
            consentStore: consent
        )
        await store.load()
        #expect(store.needsMemoryConsentPreview)
        #expect(store.canInjectMemory == false)
    }

    @Test("consentEnabledWithToggleOnInjects — only this state injects; decision is sticky")
    func consentEnabledWithToggleOnInjects() async {
        let consent = FakeConsentStore()
        let store = CompanionChatStore(
            spaceID: "s1", sourceEntryID: nil, actions: actions(box: Box(), usesLearnerProfile: true),
            consentStore: consent
        )
        await store.load()
        store.setMemoryConsent(.enabled)
        #expect(store.needsMemoryConsentPreview == false)
        #expect(store.canInjectMemory)
        #expect(consent.consent == .enabled) // persisted to the store
    }

    @Test("disabledConsentBlocksInjection — global off never injects")
    func disabledConsentBlocksInjection() async {
        let store = CompanionChatStore(
            spaceID: "s1", sourceEntryID: nil, actions: actions(box: Box(), usesLearnerProfile: true),
            consentStore: FakeConsentStore()
        )
        await store.load()
        store.setMemoryConsent(.disabled)
        #expect(store.canInjectMemory == false)
        #expect(store.needsMemoryConsentPreview == false)
    }

    @Test("perConversationTogglePersistsAndBlocks — toggle off blocks even when consented")
    func perConversationTogglePersistsAndBlocks() async {
        let box = Box()
        let store = CompanionChatStore(
            spaceID: "s1", sourceEntryID: nil, actions: actions(box: box, usesLearnerProfile: true),
            consentStore: FakeConsentStore()
        )
        await store.load()
        store.setMemoryConsent(.enabled)
        #expect(store.canInjectMemory)

        await store.setUsesLearnerProfile(false)
        #expect(box.toggleWrites == [false])
        #expect(store.usesLearnerProfile == false)
        #expect(store.canInjectMemory == false)
    }
}

@Suite("Companion memory preview model (LM03-S2b-1 honest disclosure)")
struct CompanionMemoryPreviewModelTests {
    @Test("discloses curated subset as sent and full memory store as not-sent")
    func disclosesCuratedAndExcluded() {
        let projection = AIRequestPreviewProjection(
            capability: .companionConversation,
            providerPresetID: "openai", modelName: "gpt", promptID: "p", promptVersion: "1",
            lengthBucket: .medium,
            includedContent: [.companionConversation, .curatedLearnerMemory, .proficiencyLevel],
            excludedContent: [.longTermMemory, .photoAttachments, .audioRecordings, .historicalEntries]
        )
        let model = CompanionMemoryPreviewModel(projection: projection)
        // Curated subset disclosed as sent (non-empty included label).
        #expect(model.includedLabels.contains(RequestPreviewCardModel.label(for: .curatedLearnerMemory)))
        #expect(!model.includedLabels.contains(""))
        // Full memory store disclosed as NOT sent.
        #expect(model.excludedLabels.contains(RequestPreviewCardModel.excludedDisclosureLabel(for: .longTermMemory)))
        #expect(model.provider == "openai")
    }
}
