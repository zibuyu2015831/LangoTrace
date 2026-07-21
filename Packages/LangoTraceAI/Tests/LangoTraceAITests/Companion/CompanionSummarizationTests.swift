import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

/// LM03-S3b-1: the summarization prompt's privacy directives and the
/// `.companionSummarization` capability's honest disclosure.
@Suite("Companion summarization prompt + projection (LM03-S3b-1)")
struct CompanionSummarizationTests {
    @Test("Summarization prompt declares grounded/no-profiling/no-external-data directives")
    func summarizationPromptDirectives() {
        let rendered = CompanionSummarizationPromptRegistry.summarizationPrompt(
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(rendered.id == "builtin.companion.summary.v1")
        #expect(rendered.directives.contains(.groundedInConversationNoFabrication))
        #expect(rendered.directives.contains(.thirdPersonRecap))
        #expect(rendered.directives.contains(.noProfilingNoExternalData))
        #expect(rendered.directives.contains(.foldPriorSummary))
        // The privacy boundary is named in the text for the model.
        #expect(rendered.text.contains("do not profile"))
        #expect(rendered.text.contains("ONLY what actually appears"))
    }

    @Test("companionSummarization projection discloses only this conversation; external data excluded")
    func summarizationProjectionDisclosure() {
        let p = AIRequestPreviewProjection.companionSummarization(
            endpoint: endpoint(adapterKind: .openAICompatibleChat), lengthBucket: .medium
        )
        #expect(p.capability == .companionSummarization)
        // Only the conversation itself is sent.
        #expect(p.includedContent == [.companionConversation])
        // No external data — every always-excluded guarantee holds.
        #expect(p.excludedContent.contains(.longTermMemory))
        #expect(p.excludedContent.contains(.broughtInRecords) == false) // broughtInRecords isn't in the always-excluded list
        #expect(p.excludedContent.contains(.photoAttachments))
        #expect(p.excludedContent.contains(.audioRecordings))
        #expect(p.excludedContent.contains(.historicalEntries))
        #expect(p.excludedContent.contains(.otherLanguageSpaces))
        #expect(!p.includedContent.contains(.curatedLearnerMemory))
        #expect(!p.includedContent.contains(.longTermMemory))
    }
}
