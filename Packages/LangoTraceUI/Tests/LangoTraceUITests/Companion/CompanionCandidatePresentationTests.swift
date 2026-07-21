import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

/// LM03-S2a Phase 4: the extracted-candidate presentation, the request-preview
/// disclosure of the conversation, and the extraction localization keys.
@Suite("Companion candidate presentation")
struct CompanionCandidatePresentationTests {
    private func candidate(messageID: String?) -> CompanionMemoryCandidate {
        CompanionMemoryCandidate(
            id: "c1", messageID: messageID, kind: .phrase, text: "break the ice",
            explanationNative: "打破沉默", exampleTarget: "Let's break the ice.",
            exampleNative: "我们来打破沉默。", createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    @Test("mapsCandidateFieldsAndLiveSource")
    func mapsLiveCandidate() {
        let presentation = CompanionCandidatePresentation(candidate(messageID: "m1"))
        #expect(presentation.id == "c1")
        #expect(presentation.kind == .phrase)
        #expect(presentation.text == "break the ice")
        #expect(presentation.isSourceMessageDeleted == false)
    }

    @Test("nilSourceMessageShowsDeletedState — round-1 P2-2")
    func nilSourceShowsDeleted() {
        let presentation = CompanionCandidatePresentation(candidate(messageID: nil))
        #expect(presentation.isSourceMessageDeleted)
    }

    @Test("extractionFailureCopyIsHonestForEveryCategory")
    func extractionFailureCopy() {
        for error in [CompanionExtractionError.invalidStructuredOutput, .providerUnavailable,
                      .rejected, .cancelled, .other]
        {
            #expect(CompanionChatCopy.extractionFailureKey(error) == "companion.extraction.failure")
        }
    }

    @Test("stableExtractionLocalizationKeys")
    func stableKeys() {
        #expect(CompanionChatCopy.extractActionKey == "companion.extraction.action")
        #expect(CompanionChatCopy.extractLoadingKey == "companion.extraction.loading")
        #expect(CompanionChatCopy.extractSuccessCountKey == "companion.extraction.successCount")
        #expect(CompanionChatCopy.extractEmptyKey == "companion.extraction.empty")
        #expect(CompanionChatCopy.extractFailureKey == "companion.extraction.failure")
        #expect(CompanionChatCopy.extractSourceDeletedKey == "companion.extraction.sourceDeleted")
    }

    @Test("extractionLocalizationKeysResolveInBundle — keys exist in the catalog")
    func keysResolve() {
        let keys = [
            CompanionChatCopy.extractActionKey,
            CompanionChatCopy.extractLoadingKey,
            CompanionChatCopy.extractSuccessCountKey,
            CompanionChatCopy.extractEmptyKey,
            CompanionChatCopy.extractFailureKey,
            CompanionChatCopy.extractSourceDeletedKey,
        ]
        for key in keys {
            #expect(localizedString(key) != key)
        }
    }

    @Test("requestPreviewDisclosesConversationCategory — D2 explicit disclosure")
    func requestPreviewDisclosesConversation() {
        // The companion conversation descriptor must render a real disclosure label,
        // not an empty string — the preview honestly states this conversation is sent.
        let label = RequestPreviewCardModel.label(for: .companionConversation)
        #expect(!label.isEmpty)
        #expect(localizedString("requestPreview.content.companionConversation") != "requestPreview.content.companionConversation")
    }
}
