import Foundation
import LangoTraceCore

public enum LearningMaterialGenerationActionResult: Equatable, Sendable {
    case generated(LearningMaterial)
    case failed(LearningMaterialGenerationFailureCategory)
}

public struct LearningMaterialGenerationActions: Sendable {
    public var generateMaterial: @Sendable (
        LearningMaterialGenerationInput,
        DiagnosticOperationID,
        LearningMaterialEstimatedTokenBucket
    ) async -> LearningMaterialGenerationActionResult
    public var updateLearningText: @Sendable (
        String,
        String
    ) async -> LearningMaterialGenerationActionResult
    public var analyzeCurrentText: @Sendable (
        LearningMaterialAnalysisInput,
        DiagnosticOperationID,
        LearningMaterialEstimatedTokenBucket
    ) async -> LearningMaterialGenerationActionResult
    public var recordBlockedOperation: @Sendable (
        DiagnosticOperationID,
        String,
        LearningMaterialOperationKind,
        LearningMaterialGenerationFailureCategory,
        LearningMaterialEstimatedTokenBucket
    ) async -> Void
    public var cancelOperation: @Sendable (
        DiagnosticOperationID,
        String,
        String?,
        LearningMaterialOperationKind,
        LearningMaterialEstimatedTokenBucket
    ) async -> Void
    public var operationIDGenerator: @Sendable () -> DiagnosticOperationID

    public init(
        generateMaterial: @escaping @Sendable (
            LearningMaterialGenerationInput,
            DiagnosticOperationID,
            LearningMaterialEstimatedTokenBucket
        ) async -> LearningMaterialGenerationActionResult = { _, _, _ in .failed(.providerNotConfigured) },
        updateLearningText: @escaping @Sendable (
            String,
            String
        ) async -> LearningMaterialGenerationActionResult = { _, _ in .failed(.providerNotConfigured) },
        analyzeCurrentText: @escaping @Sendable (
            LearningMaterialAnalysisInput,
            DiagnosticOperationID,
            LearningMaterialEstimatedTokenBucket
        ) async -> LearningMaterialGenerationActionResult = { _, _, _ in .failed(.providerNotConfigured) },
        recordBlockedOperation: @escaping @Sendable (
            DiagnosticOperationID,
            String,
            LearningMaterialOperationKind,
            LearningMaterialGenerationFailureCategory,
            LearningMaterialEstimatedTokenBucket
        ) async -> Void = { _, _, _, _, _ in },
        cancelOperation: @escaping @Sendable (
            DiagnosticOperationID,
            String,
            String?,
            LearningMaterialOperationKind,
            LearningMaterialEstimatedTokenBucket
        ) async -> Void = { _, _, _, _, _ in },
        operationIDGenerator: @escaping @Sendable () -> DiagnosticOperationID = {
            DiagnosticOperationID(rawValue: UUID().uuidString)
        }
    ) {
        self.generateMaterial = generateMaterial
        self.updateLearningText = updateLearningText
        self.analyzeCurrentText = analyzeCurrentText
        self.recordBlockedOperation = recordBlockedOperation
        self.cancelOperation = cancelOperation
        self.operationIDGenerator = operationIDGenerator
    }

    public static let disabled = LearningMaterialGenerationActions()
}
