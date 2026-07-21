import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Companion chat presentation")
struct CompanionChatPresentationTests {
    @Test("companionEntryHiddenWhenDisabledOnAllPlatforms — the one gate every platform honors")
    func companionEntryHiddenWhenDisabledOnAllPlatforms() {
        #expect(CompanionEntryAvailability.isVisible(featureEnabled: false) == false)
        #expect(CompanionEntryAvailability.isVisible(featureEnabled: true))
    }

    @Test("Failure copy is honest — non-rejection failures collapse to unavailable")
    func failureCopyMapping() {
        #expect(CompanionChatCopy.failureKey(.providerUnavailable) == "companion.failure.unavailable")
        #expect(CompanionChatCopy.failureKey(.empty) == "companion.failure.unavailable")
        #expect(CompanionChatCopy.failureKey(.other) == "companion.failure.unavailable")
        #expect(CompanionChatCopy.failureKey(.rejected) == "companion.failure.rejected")
        #expect(CompanionChatCopy.failureKey(.cancelled) == "companion.failure.cancelled")
    }

    @Test("Stable localization keys")
    func localizationKeys() {
        #expect(CompanionChatCopy.entryTitleKey == "companion.entry.title")
        #expect(CompanionChatCopy.settingsToggleKey == "companion.settings.toggle")
        #expect(CompanionChatCopy.coldStartGreetingKey == "companion.greeting.coldStart")
        #expect(CompanionChatCopy.entryDetailActionKey == "companion.entry.talkAboutRecord")
        #expect(CompanionChatCopy.gentleRecastToggleKey == "companion.recast.toggle")
        #expect(CompanionChatCopy.depositAllKey == "companion.deposit.all")
        #expect(CompanionChatCopy.depositedBadgeKey == "companion.deposit.added")
    }

    @Test("Message presentation maps role to isUser")
    func messagePresentationMapsRole() {
        let user = CompanionMessage(
            id: "u", threadID: "t", sequence: 0, role: .user, content: "hi",
            targetLanguageCode: "en", createdAt: .init(timeIntervalSince1970: 0)
        )
        let assistant = CompanionMessage(
            id: "a", threadID: "t", sequence: 1, role: .assistant, content: "hello",
            targetLanguageCode: "en", createdAt: .init(timeIntervalSince1970: 1)
        )
        #expect(CompanionMessagePresentation(user).isUser)
        #expect(CompanionMessagePresentation(assistant).isUser == false)
    }
}
