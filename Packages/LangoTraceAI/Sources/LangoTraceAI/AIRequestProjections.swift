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
