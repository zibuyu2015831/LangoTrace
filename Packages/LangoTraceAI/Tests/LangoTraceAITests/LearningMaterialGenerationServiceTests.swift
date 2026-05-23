import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Test("Learning material prompt registry renders stable generation prompt contract")
func learningMaterialPromptRegistryRendersGenerationPromptContract() {
    let prompt = LearningMaterialPromptRegistry.generatePrompt(
        input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
        lengthBucket: .short
    )

    #expect(prompt.id == "builtin.learning_material.generate.v1")
    #expect(prompt.version == "1")
    #expect(prompt.system.contains("Return exactly one JSON object"))
    #expect(prompt.user.contains("schema_version"))
    #expect(prompt.user.contains("native_language_code: zh-Hans"))
    #expect(prompt.user.contains("target_language_code: en"))
    #expect(prompt.user.contains("今天我去咖啡馆。"))
}

@Test("Learning material prompt registry renders stable analysis prompt contract")
func learningMaterialPromptRegistryRendersAnalysisPromptContract() {
    let prompt = LearningMaterialPromptRegistry.analyzePrompt(
        input: LearningMaterialAnalysisInput(
            materialID: "material-1",
            learningText: "I went to a cafe today.",
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "en",
            proficiencyLevelCode: "b1"
        ),
        lengthBucket: .short
    )

    #expect(prompt.id == "builtin.learning_material.analyze_current_text.v1")
    #expect(prompt.version == "1")
    #expect(prompt.system.contains("Do not rewrite the learning text"))
    #expect(prompt.user.contains("learning_text"))
}

@Test("Learning material generation service builds chat request and parses native record response")
func learningMaterialGenerationServiceBuildsChatRequestAndParsesResponse() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: 200, body: chatResponse(generationJSON(inputKind: "nativeRecord")))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.generate(
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "sk-test-secret",
            input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
            operationID: DiagnosticOperationID(rawValue: "op-1"),
            lengthBucket: .short
        )
    )

    let requests = await httpClient.requests
    #expect(requests.count == 1)
    #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
    #expect(requests[0].jsonBodyValue("response_format.type") == "json_schema")
    #expect(requests[0].jsonBodyValue("response_format.json_schema.name") == "learning_material_generation")
    let revisionCategoryEnum = "response_format.json_schema.schema.properties.revision_notes.items"
        + ".properties.category.enum"
    let memoryKindEnum = "response_format.json_schema.schema.properties.analysis"
        + ".properties.memory_candidates.items.properties.kind.enum"
    let practiceKindEnum = "response_format.json_schema.schema.properties.analysis"
        + ".properties.practice_candidates.items.properties.kind.enum"
    #expect(requests[0].jsonBodyStringArray(revisionCategoryEnum) == [
        "grammar",
        "wordChoice",
        "naturalness",
        "clarity",
        "tone",
        "structure",
    ])
    #expect(requests[0].jsonBodyStringArray(memoryKindEnum) == [
        "word",
        "phrase",
        "sentencePattern",
        "grammarPoint",
        "errorPattern",
    ])
    #expect(requests[0].jsonBodyStringArray(practiceKindEnum) == [
        "listening",
        "shadowing",
        "dictation",
        "backTranslation",
    ])
    #expect(result.inputKind == .nativeRecord)
    #expect(result.learningText == "I went to a cafe today.")
    #expect(result.analysis.sentences.first?.targetSentence == "I went to a cafe today.")
    #expect(result.analysis.memoryCandidates.first?.sentenceID == "sentence-0")
    #expect(result.analysis.practiceCandidates.first?.sentenceID == "sentence-0")
}

@Test("Learning material generation service builds Responses request with strict JSON schema")
func learningMaterialGenerationServiceBuildsResponsesRequestWithStrictJSONSchema() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: 200, body: responsesResponse(generationJSON(inputKind: "nativeRecord")))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.generate(
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAIResponses),
            plaintextSecret: "sk-test-secret",
            input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
            operationID: DiagnosticOperationID(rawValue: "op-responses"),
            lengthBucket: .short
        )
    )

    let requests = await httpClient.requests
    #expect(requests.count == 1)
    #expect(requests[0].jsonBodyValue("text.format.type") == "json_schema")
    #expect(requests[0].jsonBodyValue("text.format.name") == "learning_material_generation")
    #expect(result.inputKind == .nativeRecord)
}

@Test("Learning material generation service accepts fenced JSON returned by chat providers")
func learningMaterialGenerationServiceAcceptsFencedJSONResponse() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(
            statusCode: 200,
            body: chatResponse("""
            ```json
            \(generationJSON(inputKind: "nativeRecord"))
            ```
            """)
        )),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.generate(
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "sk-test-secret",
            input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
            operationID: DiagnosticOperationID(rawValue: "op-fenced"),
            lengthBucket: .short
        )
    )

    #expect(result.inputKind == .nativeRecord)
    #expect(result.learningText == "I went to a cafe today.")
}

@Test("Learning material generation service parses target writing revision notes")
func learningMaterialGenerationServiceParsesTargetWritingRevisionNotes() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: 200, body: chatResponse(generationJSON(inputKind: "targetWriting")))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.generate(
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "sk-test-secret",
            input: sampleGenerationInput(sourceText: "I go cafe today."),
            operationID: DiagnosticOperationID(rawValue: "op-2"),
            lengthBucket: .short
        )
    )

    #expect(result.inputKind == .targetWriting)
    #expect(result.revisionSummary.first?.category == .grammar)
    #expect(result.revisionSummary.first?.revisedText == "I went to a cafe today.")
}

@Test("Learning material generation service analyzes current learning text without rewriting it")
func learningMaterialGenerationServiceAnalyzesCurrentLearningText() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: 200, body: chatResponse(analysisJSON()))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.analyze(
        LearningMaterialServiceAnalysisRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: "sk-test-secret",
            input: LearningMaterialAnalysisInput(
                materialID: "material-1",
                learningText: "I went to a cafe today.",
                nativeLanguageCode: "zh-Hans",
                targetLanguageCode: "en",
                proficiencyLevelCode: "b1"
            ),
            operationID: DiagnosticOperationID(rawValue: "op-analyze"),
            lengthBucket: .short
        )
    )

    let requests = await httpClient.requests
    #expect(requests.count == 1)
    #expect(requests[0].httpBodyText?.contains("analyze_current_learning_text") == true)
    #expect(result.materialID == "material-1")
    #expect(result.analysis.sentences.first?.targetSentence == "I went to a cafe today.")
}

@Test("Learning material generation service rejects missing analysis fields")
func learningMaterialGenerationServiceRejectsMissingAnalysisFields() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(
            statusCode: 200,
            body: chatResponse("""
            {"schema_version":"learning_material.v1","input_kind":"nativeRecord","learning_text":"I went."}
            """)
        )),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    await #expect(throws: LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)) {
        try await service.generate(
            LearningMaterialServiceGenerationRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleGenerationInput(sourceText: "我去了。"),
                operationID: DiagnosticOperationID(rawValue: "op-invalid"),
                lengthBucket: .short
            )
        )
    }
}

@Test("Learning material generation service rejects unsupported adapters before HTTP")
func learningMaterialGenerationServiceRejectsUnsupportedAdaptersBeforeHTTP() async throws {
    let httpClient = CapturingLearningMaterialHTTPClient(responses: [])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    await #expect(throws: LearningMaterialGenerationServiceError(category: .unsupportedProvider)) {
        try await service.generate(
            LearningMaterialServiceGenerationRequest(
                endpoint: endpoint(adapterKind: .anthropicMessages),
                plaintextSecret: "sk-test-secret",
                input: sampleGenerationInput(sourceText: "我去了。"),
                operationID: DiagnosticOperationID(rawValue: "op-unsupported"),
                lengthBucket: .short
            )
        )
    }
    #expect(await httpClient.requests.isEmpty)
}
