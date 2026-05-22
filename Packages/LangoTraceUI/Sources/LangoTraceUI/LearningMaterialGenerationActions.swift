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
        operationIDGenerator: @escaping @Sendable () -> DiagnosticOperationID = {
            DiagnosticOperationID(rawValue: UUID().uuidString)
        }
    ) {
        self.generateMaterial = generateMaterial
        self.updateLearningText = updateLearningText
        self.analyzeCurrentText = analyzeCurrentText
        self.operationIDGenerator = operationIDGenerator
    }

    public static let disabled = LearningMaterialGenerationActions()
}
