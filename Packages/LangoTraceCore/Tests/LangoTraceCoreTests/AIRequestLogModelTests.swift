import Foundation
import LangoTraceCore
import Testing

/// Pins the non-sensitive request-log + preview-projection contract (系列 E6).
/// Guards: the capability vocabulary, the standing per-domain failure → bucket
/// mapping (E0a did not unify the taxonomy, so the mapping is permanent), the
/// coarse length buckets, and — structurally — that the log entry has no
/// free-text content field.
@Suite("AI request log + preview projection models")
struct AIRequestLogModelTests {
    @Test("capability vocabulary includes every live path including photo-writing assist")
    func capabilityVocabulary() {
        let all = Set(AIRequestCapability.allCases)
        #expect(all.contains(.learningMaterialGeneration))
        #expect(all.contains(.readingSelectionExplanation))
        #expect(all.contains(.practiceBacktranslationReview))
        #expect(all.contains(.photoWritingAssist))
    }

    @Test("learning-material failure categories map onto the standing log buckets")
    func learningMaterialFailureMapping() {
        typealias Category = LearningMaterialGenerationFailureCategory
        #expect(AIRequestLogFailureBucket(Category.providerNotConfigured) == .providerNotConfigured)
        #expect(AIRequestLogFailureBucket(Category.credentialMissing) == .credentialMissing)
        #expect(AIRequestLogFailureBucket(Category.authenticationFailed) == .credentialMissing)
        #expect(AIRequestLogFailureBucket(Category.networkUnavailable) == .network)
        #expect(AIRequestLogFailureBucket(Category.timeout) == .timeout)
        #expect(AIRequestLogFailureBucket(Category.rateLimited) == .providerRejected)
        #expect(AIRequestLogFailureBucket(Category.providerRejected) == .providerRejected)
        #expect(AIRequestLogFailureBucket(Category.unsupportedProvider) == .unsupported)
        #expect(AIRequestLogFailureBucket(Category.unsupportedModel) == .unsupported)
        #expect(AIRequestLogFailureBucket(Category.invalidStructuredResponse) == .invalidResponse)
        #expect(AIRequestLogFailureBucket(Category.persistenceFailed) == .persistence)
    }

    @Test("reading-explanation failure categories map onto the standing log buckets")
    func readingExplanationFailureMapping() {
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.providerNotConfigured) == .providerNotConfigured)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.authenticationFailed) == .credentialMissing)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.networkUnavailable) == .network)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.timeout) == .timeout)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.rateLimited) == .providerRejected)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.unsupportedModel) == .unsupported)
        #expect(AIRequestLogFailureBucket(ReadingSelectionExplanationFailureCategory.invalidStructuredResponse) == .invalidResponse)
    }

    @Test("length bucket maps from the learning-material token bucket")
    func lengthBucketFromTokenBucket() {
        #expect(AIRequestLengthBucket(LearningMaterialEstimatedTokenBucket.short) == .short)
        #expect(AIRequestLengthBucket(LearningMaterialEstimatedTokenBucket.medium) == .medium)
        #expect(AIRequestLengthBucket(LearningMaterialEstimatedTokenBucket.tooLong) == .long)
    }

    @Test("length bucket maps from a character count")
    func lengthBucketFromCharacterCount() {
        #expect(AIRequestLengthBucket(characterCount: 0) == .short)
        #expect(AIRequestLengthBucket(characterCount: 399) == .short)
        #expect(AIRequestLengthBucket(characterCount: 400) == .medium)
        #expect(AIRequestLengthBucket(characterCount: 1599) == .medium)
        #expect(AIRequestLengthBucket(characterCount: 1600) == .long)
    }

    @Test("a cancelled entry carries no failure bucket")
    func cancelledEntryHasNoFailureBucket() {
        let entry = AIRequestLogEntry(
            id: "log-1",
            operationID: DiagnosticOperationID(rawValue: "op-1"),
            capability: .learningMaterialGeneration,
            providerPresetID: "preset",
            endpointPurpose: .textGeneration,
            adapterKind: .openAICompatibleChat,
            modelName: "model",
            promptID: "prompt",
            promptVersion: "1",
            inputLengthBucket: .short,
            status: .cancelled,
            failureBucket: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        #expect(entry.status == .cancelled)
        #expect(entry.failureBucket == nil)
    }

    @Test("content descriptors separate always-excluded privacy categories from included ones")
    func excludedDescriptorsExist() {
        let descriptors = Set(AIRequestContentDescriptor.allCases)
        // The preview's privacy guarantees are part of the closed vocabulary.
        #expect(descriptors.contains(.apiCredential))
        #expect(descriptors.contains(.photoAttachments))
        #expect(descriptors.contains(.historicalEntries))
        #expect(descriptors.contains(.longTermMemory))
    }

    @Test("the preview projection carries only non-sensitive descriptors, never content")
    func projectionIsContentFree() {
        let projection = AIRequestPreviewProjection(
            capability: .learningMaterialGeneration,
            providerPresetID: "openai",
            modelName: "gpt-x",
            promptID: "builtin.learning_material",
            promptVersion: "1",
            lengthBucket: .medium,
            includedContent: [.currentEntryBody],
            excludedContent: [.historicalEntries, .photoAttachments, .apiCredential]
        )
        #expect(projection.includedContent.contains(.currentEntryBody))
        #expect(projection.excludedContent.contains(.apiCredential))
    }
}
