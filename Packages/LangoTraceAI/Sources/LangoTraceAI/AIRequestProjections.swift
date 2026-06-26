import Foundation
import LangoTraceCore

// Pure "will-send" preview + non-sensitive log-row builders for the two live AI
// text capabilities (系列 E6).
//
// These are constructed from the *same* request structs that build the real
// outbound request, so the preview can never drift from what is sent. They
// perform no network IO and render no prompt body — only non-sensitive
// descriptors (provider preset, model, prompt id/version, a size bucket, and
// the included/excluded content *categories*).
//
// Per the E6 self-review the request log is written by an App-Shell recorder
// (mirroring `ReadingExplanationOperationRecorder`), not by the AI services
// themselves; these builders give that recorder the same-source values.

/// The content categories every outbound learning/reading request always
/// excludes — the privacy guarantees the preview asserts.
private let alwaysExcludedContent: [AIRequestContentDescriptor] = [
    .historicalEntries,
    .photoAttachments,
    .audioRecordings,
    .longTermMemory,
    .apiCredential,
    .otherLanguageSpaces,
]

public extension AIRequestPreviewProjection {
    /// Single-source factory for the learning-material generation projection,
    /// shared by the request-based `previewProjection()` and the App-Shell
    /// preview seam (which builds it from a cached endpoint before any request
    /// exists). Content categories live here so both paths stay in sync.
    static func learningMaterialGeneration(
        endpoint: AIProviderEndpointInput,
        lengthBucket: AIRequestLengthBucket
    ) -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .learningMaterialGeneration,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: LearningMaterialPromptRegistry.generationPromptID,
            promptVersion: LearningMaterialPromptRegistry.promptVersion,
            lengthBucket: lengthBucket,
            includedContent: [.currentEntryBody],
            excludedContent: alwaysExcludedContent
        )
    }

    /// Single-source factory for the photo-writing assist projection. This is the
    /// *only* projection whose `includedContent` carries `.photoAttachments`: a
    /// photo enters an outbound AI request solely through this explicit,
    /// user-triggered capability. Every other always-excluded category stays
    /// excluded — the exclusion set is derived from `alwaysExcludedContent` with
    /// photos removed, so it cannot silently drift from the shared list.
    ///
    /// The projection is mode-independent on purpose: both writing-suggestions
    /// and native-draft modes send the same content categories (the photo, the
    /// optional user note, and the language-space profile), so the preview the
    /// user confirms is honest regardless of mode.
    static func photoWritingAssist(
        endpoint: AIProviderEndpointInput,
        lengthBucket: AIRequestLengthBucket
    ) -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .photoWritingAssist,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: PhotoWritingAssistPromptRegistry.promptID,
            promptVersion: PhotoWritingAssistPromptRegistry.promptVersion,
            lengthBucket: lengthBucket,
            includedContent: [
                .photoAttachments,
                .currentEntryBody,
                .nativeLanguageProfile,
                .targetLanguageProfile,
                .proficiencyLevel,
            ],
            excludedContent: alwaysExcludedContent.filter { $0 != .photoAttachments }
        )
    }

    /// Single-source factory for the companion chat extraction projection
    /// (LM03-S2a). Its only included category is `companionConversation` — the
    /// conversation the user already shared turn-by-turn, re-sent on an explicit
    /// "extract" action. It admits **no new outbound category** (no photo, no
    /// long-term memory, no historical entries): every always-excluded guarantee
    /// stays excluded, so the preview the user confirms honestly discloses that
    /// only this conversation is sent.
    static func companionExtraction(
        endpoint: AIProviderEndpointInput,
        lengthBucket: AIRequestLengthBucket
    ) -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .companionExtraction,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: CompanionExtractionPromptRegistry.promptID,
            promptVersion: CompanionExtractionPromptRegistry.promptVersion,
            lengthBucket: lengthBucket,
            includedContent: [.companionConversation],
            excludedContent: alwaysExcludedContent
        )
    }

    /// Single-source factory for the companion *conversation send* projection
    /// (LM03-S1 + S2b-1). The first capability that models the outbound
    /// conversation itself. When `hasMemoryInjection` is true (the user consented
    /// to Memory injection and the per-conversation toggle is on), it additionally
    /// discloses `.curatedLearnerMemory` — the consented, scrubbed top-5 subset of
    /// long-term memory. Crucially, `.longTermMemory` **stays in the excluded set**
    /// always: the raw long-term memory store is never bulk-sent, so the preview
    /// can honestly show both "sends: curated subset" and "does not send: full
    /// memory store". Preview-only — no `makeLogEntry` (conversation-level logging
    /// is deferred).
    static func companionConversation(
        endpoint: AIProviderEndpointInput,
        lengthBucket: AIRequestLengthBucket,
        hasMemoryInjection: Bool,
        hasBroughtInRecords: Bool = false
    ) -> AIRequestPreviewProjection {
        var included: [AIRequestContentDescriptor] = [
            .companionConversation,
            .nativeLanguageProfile,
            .targetLanguageProfile,
            .proficiencyLevel,
        ]
        if hasMemoryInjection {
            included.append(.curatedLearnerMemory)
        }
        // 方案A (user brought in a record) or 方案B (companion auto-sourced one).
        // Either way the record body egresses, so the preview discloses it.
        if hasBroughtInRecords {
            included.append(.broughtInRecords)
        }
        return AIRequestPreviewProjection(
            capability: .companionConversation,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: CompanionPromptRegistry.systemPromptID,
            promptVersion: CompanionPromptRegistry.promptVersion,
            lengthBucket: lengthBucket,
            includedContent: included,
            excludedContent: alwaysExcludedContent
        )
    }

    /// Single-source factory for the companion *summarization* projection
    /// (LM03-S3b-1 "对话记忆"). Its only included category is `companionConversation`
    /// — the summarization re-sends turns of *this same conversation* the provider
    /// already received earlier (when fresh, in-window). It admits **no new outbound
    /// category and no external data**: long-term memory, brought-in records,
    /// photos, audio, historical entries all stay excluded, so the preview honestly
    /// discloses that only this conversation is sent to build its memory.
    /// Preview-only — no `makeLogEntry`.
    static func companionSummarization(
        endpoint: AIProviderEndpointInput,
        lengthBucket: AIRequestLengthBucket
    ) -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .companionSummarization,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: CompanionSummarizationPromptRegistry.summarizationPromptID,
            promptVersion: CompanionSummarizationPromptRegistry.promptVersion,
            lengthBucket: lengthBucket,
            includedContent: [.companionConversation],
            excludedContent: alwaysExcludedContent
        )
    }
}

public extension LearningMaterialServiceGenerationRequest {
    /// Projection for a generation request (builds learning material from the
    /// current entry body).
    func previewProjection() -> AIRequestPreviewProjection {
        .learningMaterialGeneration(endpoint: endpoint, lengthBucket: AIRequestLengthBucket(lengthBucket))
    }

    /// Non-sensitive log row for this request's outcome.
    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        LearningMaterialLogContext(
            operationID: operationID,
            endpoint: endpoint,
            lengthBucket: lengthBucket,
            promptID: LearningMaterialPromptRegistry.generationPromptID
        ).makeLogEntry(id: id, outcome: outcome, createdAt: createdAt)
    }
}

public extension LearningMaterialServiceAnalysisRequest {
    /// Projection for an analysis request (re-analyses the existing learning
    /// text rather than the raw entry body).
    func previewProjection() -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .learningMaterialGeneration,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: LearningMaterialPromptRegistry.analysisPromptID,
            promptVersion: LearningMaterialPromptRegistry.promptVersion,
            lengthBucket: AIRequestLengthBucket(lengthBucket),
            includedContent: [.currentLearningText],
            excludedContent: alwaysExcludedContent
        )
    }

    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        LearningMaterialLogContext(
            operationID: operationID,
            endpoint: endpoint,
            lengthBucket: lengthBucket,
            promptID: LearningMaterialPromptRegistry.analysisPromptID
        ).makeLogEntry(id: id, outcome: outcome, createdAt: createdAt)
    }
}

public extension ReadingSelectionExplanationServiceRequest {
    /// Projection for a reading selection explanation request.
    func previewProjection() -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .readingSelectionExplanation,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: ReadingSelectionExplanationPromptRegistry.promptID,
            promptVersion: ReadingSelectionExplanationPromptRegistry.promptVersion,
            lengthBucket: AIRequestLengthBucket(characterCount: input.selectedText.count + input.contextText.count),
            includedContent: [
                .selectedReadingPassage,
                .readingContextWindow,
                .nativeLanguageProfile,
                .targetLanguageProfile,
                .proficiencyLevel,
            ],
            excludedContent: alwaysExcludedContent
        )
    }

    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        let lengthBucket = AIRequestLengthBucket(characterCount: input.selectedText.count + input.contextText.count)
        return AIRequestLogEntry(
            id: id,
            operationID: DiagnosticOperationID(rawValue: id),
            capability: .readingSelectionExplanation,
            providerPresetID: endpoint.providerPresetID,
            endpointPurpose: endpoint.purpose,
            adapterKind: endpoint.adapterKind,
            modelName: endpoint.modelName,
            promptID: ReadingSelectionExplanationPromptRegistry.promptID,
            promptVersion: ReadingSelectionExplanationPromptRegistry.promptVersion,
            inputLengthBucket: lengthBucket,
            status: outcome.status,
            failureBucket: outcome.failureBucket,
            createdAt: createdAt
        )
    }
}

public extension PracticeBacktranslationReviewServiceRequest {
    /// Projection for a back-translation critique request — fills the reserved
    /// `practiceBacktranslationReview` capability (系列 E5 Slice 2 / E6 seam).
    func previewProjection() -> AIRequestPreviewProjection {
        AIRequestPreviewProjection(
            capability: .practiceBacktranslationReview,
            providerPresetID: endpoint.providerPresetID,
            modelName: endpoint.modelName,
            promptID: PracticeBacktranslationReviewPromptRegistry.promptID,
            promptVersion: PracticeBacktranslationReviewPromptRegistry.promptVersion,
            lengthBucket: AIRequestLengthBucket(characterCount: reviewCharacterCount),
            includedContent: [
                .practiceAttempt,
                .backtranslationReferenceSentence,
                .nativeLanguageProfile,
                .targetLanguageProfile,
                .proficiencyLevel,
            ],
            excludedContent: alwaysExcludedContent
        )
    }

    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        AIRequestLogEntry(
            id: id,
            operationID: DiagnosticOperationID(rawValue: id),
            capability: .practiceBacktranslationReview,
            providerPresetID: endpoint.providerPresetID,
            endpointPurpose: endpoint.purpose,
            adapterKind: endpoint.adapterKind,
            modelName: endpoint.modelName,
            promptID: PracticeBacktranslationReviewPromptRegistry.promptID,
            promptVersion: PracticeBacktranslationReviewPromptRegistry.promptVersion,
            inputLengthBucket: AIRequestLengthBucket(characterCount: reviewCharacterCount),
            status: outcome.status,
            failureBucket: outcome.failureBucket,
            createdAt: createdAt
        )
    }

    private var reviewCharacterCount: Int {
        input.nativeSentence.count + input.userAttempt.count + input.referenceSentence.count
    }
}

public extension PhotoWritingAssistServiceRequest {
    /// Projection for a photo-writing assist request — the only capability whose
    /// preview admits the photo (see `AIRequestPreviewProjection.photoWritingAssist`).
    func previewProjection() -> AIRequestPreviewProjection {
        .photoWritingAssist(
            endpoint: endpoint,
            lengthBucket: AIRequestLengthBucket(characterCount: input.userNote.count)
        )
    }

    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        AIRequestLogEntry(
            id: id,
            operationID: DiagnosticOperationID(rawValue: id),
            capability: .photoWritingAssist,
            providerPresetID: endpoint.providerPresetID,
            endpointPurpose: endpoint.purpose,
            adapterKind: endpoint.adapterKind,
            modelName: endpoint.modelName,
            promptID: PhotoWritingAssistPromptRegistry.promptID,
            promptVersion: PhotoWritingAssistPromptRegistry.promptVersion,
            inputLengthBucket: AIRequestLengthBucket(characterCount: input.userNote.count),
            status: outcome.status,
            failureBucket: outcome.failureBucket,
            createdAt: createdAt
        )
    }
}

/// Shared learning-material metadata for building a log row from either the
/// generation or analysis request without a long parameter list.
private struct LearningMaterialLogContext {
    var operationID: DiagnosticOperationID
    var endpoint: AIProviderEndpointInput
    var lengthBucket: LearningMaterialEstimatedTokenBucket
    var promptID: String

    func makeLogEntry(id: String, outcome: AIRequestLogOutcome, createdAt: Date) -> AIRequestLogEntry {
        AIRequestLogEntry(
            id: id,
            operationID: operationID,
            capability: .learningMaterialGeneration,
            providerPresetID: endpoint.providerPresetID,
            endpointPurpose: endpoint.purpose,
            adapterKind: endpoint.adapterKind,
            modelName: endpoint.modelName,
            promptID: promptID,
            promptVersion: LearningMaterialPromptRegistry.promptVersion,
            inputLengthBucket: AIRequestLengthBucket(lengthBucket),
            status: outcome.status,
            failureBucket: outcome.failureBucket,
            createdAt: createdAt
        )
    }
}
