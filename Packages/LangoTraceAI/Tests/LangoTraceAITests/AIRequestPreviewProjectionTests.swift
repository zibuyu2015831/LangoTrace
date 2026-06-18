import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

/// Covers the pure "will-send" projection + non-sensitive log-row builders for
/// the two live AI text capabilities (系列 E6). These are constructed from the
/// same request structs that build the real request, so the preview cannot
/// drift from what is sent.
@Suite("AI request preview projection")
struct AIRequestPreviewProjectionTests {
    private func generationRequest(sourceText: String = "hello") -> LearningMaterialServiceGenerationRequest {
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "secret",
            input: sampleGenerationInput(sourceText: sourceText),
            operationID: DiagnosticOperationID(rawValue: "op-1"),
            lengthBucket: .medium
        )
    }

    private func readingRequest() -> ReadingSelectionExplanationServiceRequest {
        ReadingSelectionExplanationServiceRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "secret",
            input: ReadingSelectionExplanationInput(
                documentID: "doc-1",
                sourceAnchorID: "anchor-1",
                selectedText: "ephemeral",
                selectionScope: .sentence,
                containingSentence: "An ephemeral thing.",
                previousSentence: nil,
                nextSentence: nil,
                containingParagraph: "An ephemeral thing.",
                contextMode: .currentParagraph,
                contextText: "An ephemeral thing.",
                nativeLanguageCode: "zh-Hans",
                targetLanguageCode: "en",
                proficiencyLevelCode: "b1"
            )
        )
    }

    @Test("learning-material generation projection describes provider, model and content kinds")
    func generationProjectionDescribesProviderModelAndContentKinds() {
        let projection = generationRequest().previewProjection()
        #expect(projection.capability == .learningMaterialGeneration)
        #expect(projection.providerPresetID == "openai")
        #expect(projection.modelName == "gpt-4.1-mini")
        #expect(projection.promptID == LearningMaterialPromptRegistry.generationPromptID)
        #expect(projection.includedContent == [.currentEntryBody])
        // The privacy guarantees are part of the projection.
        #expect(projection.excludedContent.contains(.apiCredential))
        #expect(projection.excludedContent.contains(.photoAttachments))
        #expect(projection.excludedContent.contains(.historicalEntries))
    }

    @Test("analysis projection re-analyses the existing learning text, not the raw entry")
    func analysisProjectionDescribesLearningText() {
        let request = LearningMaterialServiceAnalysisRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "secret",
            input: LearningMaterialAnalysisInput(
                materialID: "material-1",
                learningText: "Some learning text.",
                nativeLanguageCode: "zh-Hans",
                targetLanguageCode: "en",
                proficiencyLevelCode: "b1"
            ),
            operationID: DiagnosticOperationID(rawValue: "op-2"),
            lengthBucket: .short
        )
        let projection = request.previewProjection()
        #expect(projection.includedContent == [.currentLearningText])
        #expect(projection.promptID == LearningMaterialPromptRegistry.analysisPromptID)
    }

    @Test("reading-selection projection describes the selection, context window and language profile")
    func readingProjectionDescribesSelectionContext() {
        let projection = readingRequest().previewProjection()
        #expect(projection.capability == .readingSelectionExplanation)
        #expect(projection.includedContent.contains(.selectedReadingPassage))
        #expect(projection.includedContent.contains(.readingContextWindow))
        #expect(projection.includedContent.contains(.proficiencyLevel))
        #expect(projection.excludedContent.contains(.apiCredential))
        #expect(projection.promptVersion == ReadingSelectionExplanationPromptRegistry.promptVersion)
    }

    @Test("a successful outcome yields a success log row with no failure bucket")
    func successOutcomeYieldsSuccessRow() {
        let entry = generationRequest().makeLogEntry(id: "log-1", outcome: .success, createdAt: Date(timeIntervalSince1970: 0))
        #expect(entry.status == .success)
        #expect(entry.failureBucket == nil)
        #expect(entry.capability == .learningMaterialGeneration)
        #expect(entry.adapterKind == .openAICompatibleChat)
        #expect(entry.operationID == DiagnosticOperationID(rawValue: "op-1"))
    }

    @Test("a failed outcome carries the mapped failure bucket")
    func failedOutcomeCarriesBucket() {
        let entry = generationRequest().makeLogEntry(
            id: "log-2",
            outcome: .failed(.network),
            createdAt: Date(timeIntervalSince1970: 0)
        )
        #expect(entry.status == .failed)
        #expect(entry.failureBucket == .network)
    }

    @Test("a cancelled outcome records cancelled status with no failure bucket")
    func cancelledOutcomeRecordsCancelled() {
        let entry = readingRequest().makeLogEntry(id: "log-3", outcome: .cancelled, createdAt: Date(timeIntervalSince1970: 0))
        #expect(entry.status == .cancelled)
        #expect(entry.failureBucket == nil)
        #expect(entry.capability == .readingSelectionExplanation)
    }
}
