import LangoTraceCore
import Testing

@Test("Learning material enum raw values match prompt and database contract")
func learningMaterialEnumRawValuesMatchContract() {
    #expect(LearningMaterialInputKind.nativeRecord.rawValue == "nativeRecord")
    #expect(LearningMaterialInputKind.targetWriting.rawValue == "targetWriting")
    #expect(LearningMaterialInputKind.mixed.rawValue == "mixed")
    #expect(LearningMaterialInputKind.uncertain.rawValue == "uncertain")

    #expect(LearningMaterialPromptMode.automaticLearningMaterial.rawValue == "automaticLearningMaterial")
    #expect(LearningMaterialPromptMode.analyzeCurrentLearningText.rawValue == "analyzeCurrentLearningText")

    #expect(LearningMaterialAnalysisStatus.fresh.rawValue == "fresh")
    #expect(LearningMaterialAnalysisStatus.stale.rawValue == "stale")
    #expect(LearningMaterialAnalysisStatus.missing.rawValue == "missing")
    #expect(LearningMaterialAnalysisStatus.failed.rawValue == "failed")
}

@Test("Learning material failure categories cover recoverable provider and persistence outcomes")
func learningMaterialFailureCategoriesCoverContract() {
    let categories = Set(LearningMaterialGenerationFailureCategory.allCases.map(\.rawValue))

    #expect(categories == [
        "providerNotConfigured",
        "credentialMissing",
        "networkUnavailable",
        "timeout",
        "providerRejected",
        "unsupportedProvider",
        "unsupportedModel",
        "contentTooLong",
        "invalidStructuredResponse",
        "cancelled",
        "persistenceFailed",
        "unknown",
    ])
}

@Test("Learning material length estimator buckets CJK latin and mixed input")
func learningMaterialLengthEstimatorBucketsInput() {
    #expect(LearningMaterialLengthEstimator.bucket(for: "今天下班后去买咖啡。") == .short)
    #expect(LearningMaterialLengthEstimator.bucket(for: String(repeating: "hello ", count: 700)) == .medium)
    #expect(LearningMaterialLengthEstimator.bucket(for: String(repeating: "语", count: 3001)) == .tooLong)
    #expect(LearningMaterialLengthEstimator.estimateTokens(for: "hello 语迹!") == 4)
}

@Test("Learning material generation state prevents duplicate operations for same entry")
func learningMaterialGenerationStatePreventsDuplicateOperations() {
    let operationID = DiagnosticOperationID(rawValue: "op-generate")
    let state = LearningMaterialGenerationState.generating(operationID: operationID)

    #expect(state.isRunning)
    #expect(!state.canStartGeneration)
    #expect(state.operationID == operationID)
}

@Test("Learning material generation state represents stale editing and analysis")
func learningMaterialGenerationStateRepresentsEditingAndAnalysis() {
    let editing = LearningMaterialGenerationState.editing(materialID: "material-1", analysisIsStale: true)
    let analyzing = LearningMaterialGenerationState.analyzing(
        materialID: "material-1",
        operationID: DiagnosticOperationID(rawValue: "op-analyze")
    )

    #expect(editing.analysisIsStale)
    #expect(!editing.isRunning)
    #expect(analyzing.isRunning)
    #expect(analyzing.materialID == "material-1")
}

@Test("Learning material failure state can preserve editable material retry context")
func learningMaterialFailureStatePreservesMaterialRetryContext() {
    let failed = LearningMaterialGenerationState.failed(
        LearningMaterialGenerationFailureDisplay(
            category: .networkUnavailable,
            operationID: DiagnosticOperationID(rawValue: "op-analyze"),
            materialID: "material-1",
            analysisIsStale: true
        )
    )

    #expect(!failed.isRunning)
    #expect(failed.canStartGeneration)
    #expect(failed.operationID?.rawValue == "op-analyze")
    #expect(failed.materialID == "material-1")
    #expect(failed.analysisIsStale)
}

@Test("Entry source describes capture modality and not AI routing result")
func entrySourceDoesNotImplyLearningMaterialInputKind() {
    #expect(EntrySource.typedText.rawValue == "typedText")
    #expect(EntrySource.photoWriting.rawValue == "photoWriting")
    #expect(EntrySource.targetLanguageWriting.rawValue == "targetLanguageWriting")

    #expect(LearningMaterialInputKind.kind(inferredFrom: .typedText) == nil)
    #expect(LearningMaterialInputKind.kind(inferredFrom: .targetLanguageWriting) == nil)
}
