import Foundation
import LangoTraceAI
import LangoTraceCore
import LangoTraceData

/// App-Shell writer for the local `ai_request_logs` table (系列 E6).
///
/// Mirrors `ReadingExplanationOperationRecorder`: the AI services stay pure
/// executors; this recorder is driven from `AppEnvironment` around the real
/// generate / analyze / explain calls. Writes are fire-and-forget — a log
/// failure never affects the AI request's main flow (the table is local
/// transparency data, not part of the request contract).
struct AIRequestLogRecorder {
    let repository: (any AIRequestLogRepository)?

    /// Records a learning-material (generation or analysis) outcome. `endpoint`
    /// is nil on pre-flight failures where no provider was resolved yet.
    func recordLearningMaterial(
        operationID: DiagnosticOperationID,
        endpoint: AIProviderEndpointInput?,
        bucket: LearningMaterialEstimatedTokenBucket,
        promptID: String,
        outcome: AIRequestLogOutcome
    ) async {
        guard let repository else { return }
        let entry = AIRequestLogEntry(
            id: UUID().uuidString,
            operationID: operationID,
            capability: .learningMaterialGeneration,
            providerPresetID: endpoint?.providerPresetID,
            endpointPurpose: endpoint?.purpose,
            adapterKind: endpoint?.adapterKind,
            modelName: endpoint?.modelName,
            promptID: promptID,
            promptVersion: LearningMaterialPromptRegistry.promptVersion,
            inputLengthBucket: AIRequestLengthBucket(bucket),
            status: outcome.status,
            failureBucket: outcome.failureBucket,
            createdAt: Date()
        )
        try? await repository.append(entry)
    }

    /// Records a prebuilt entry (reading explanation uses the AI builder).
    func record(_ entry: AIRequestLogEntry) async {
        guard let repository else { return }
        try? await repository.append(entry)
    }

    /// Maps a learning-material failure category to the log bucket, treating
    /// cancellation as a cancelled status rather than a failure.
    static func outcome(for category: LearningMaterialGenerationFailureCategory) -> AIRequestLogOutcome {
        category == .cancelled ? .cancelled : .failed(AIRequestLogFailureBucket(category))
    }
}
