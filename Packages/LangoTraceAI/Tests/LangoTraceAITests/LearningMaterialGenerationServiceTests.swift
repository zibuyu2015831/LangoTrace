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
    #expect(prompt.system.contains("at least one useful grammar_note"))
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
    #expect(prompt.system.contains("at least one useful grammar_note"))
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
    let grammarNotesMinItems = "response_format.json_schema.schema.properties.analysis"
        + ".properties.sentences.items.properties.grammar_notes.minItems"
    #expect(requests[0].jsonBodyInt(grammarNotesMinItems) == 1)
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

    do {
        _ = try await service.generate(
            LearningMaterialServiceGenerationRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleGenerationInput(sourceText: "我去了。"),
                operationID: DiagnosticOperationID(rawValue: "op-invalid"),
                lengthBucket: .short
            )
        )
        Issue.record("Expected invalid structured response error")
    } catch let error as LearningMaterialGenerationServiceError {
        #expect(error.category == .invalidStructuredResponse)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Learning material generation service rejects invalid revision category instead of coercing")
func learningMaterialGenerationServiceRejectsInvalidRevisionCategory() async {
    await expectGenerationRejects(
        generationJSON(inputKind: "targetWriting", revisionCategory: "vocabulary")
    )
}

@Test("Learning material generation service rejects invalid memory candidate kind instead of coercing")
func learningMaterialGenerationServiceRejectsInvalidMemoryCandidateKind() async {
    await expectGenerationRejects(
        generationJSON(inputKind: "nativeRecord", memoryKind: "vocabulary")
    )
}

@Test("Learning material generation service rejects invalid memory candidate difficulty instead of coercing")
func learningMaterialGenerationServiceRejectsInvalidMemoryCandidateDifficulty() async {
    await expectGenerationRejects(
        generationJSON(inputKind: "nativeRecord", memoryDifficulty: "impossible")
    )
}

@Test("Learning material generation service rejects invalid practice candidate kind instead of coercing")
func learningMaterialGenerationServiceRejectsInvalidPracticeCandidateKind() async {
    await expectGenerationRejects(
        generationJSON(inputKind: "nativeRecord", practiceKind: "writing")
    )
}

@Test("Learning material generation service rejects prose wrapped around the JSON object")
func learningMaterialGenerationServiceRejectsProseWrappedJSON() async {
    await expectGenerationRejects("""
    Sure! Here is the learning material you asked for:
    \(generationJSON(inputKind: "nativeRecord"))
    Hope this helps!
    """)
}

@Test("Learning material generation service rejects analyses above the documented array limits")
func learningMaterialGenerationServiceRejectsOverLimitArrays() async {
    await expectAnalysisRejects(analysisJSON(sentenceCount: 21))
    await expectAnalysisRejects(analysisJSON(memoryCandidateCount: 13))
    await expectAnalysisRejects(analysisJSON(practiceCandidateCount: 7))
}

@Test("Learning material generation service accepts analyses at the documented array limits")
func learningMaterialGenerationServiceAcceptsAnalysesAtArrayLimits() async throws {
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(
            statusCode: 200,
            body: chatResponse(analysisJSON(sentenceCount: 20, memoryCandidateCount: 12, practiceCandidateCount: 6))
        )),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.analyze(sampleAnalysisRequest())

    #expect(result.analysis.sentences.count == 20)
    #expect(result.analysis.memoryCandidates.count == 12)
    #expect(result.analysis.practiceCandidates.count == 6)
}

@Test("Learning material generation service maps provider HTTP status codes to failure categories")
func learningMaterialGenerationServiceMapsProviderHTTPStatusCodes() async {
    await expectGenerationHTTPStatus(401, mapsTo: .authenticationFailed)
    await expectGenerationHTTPStatus(403, mapsTo: .authenticationFailed)
    await expectGenerationHTTPStatus(404, mapsTo: .unsupportedModel)
    await expectGenerationHTTPStatus(429, mapsTo: .rateLimited)
    await expectGenerationHTTPStatus(500, mapsTo: .providerRejected)
}

@Test("Learning material generation service parses Responses output with a leading reasoning item")
func learningMaterialGenerationServiceParsesResponsesOutputWithLeadingReasoningItem() async throws {
    let payload = generationJSON(inputKind: "nativeRecord")
    let body: [String: Any] = [
        "output": [
            ["type": "reasoning", "summary": [String]()],
            [
                "type": "message",
                "content": [
                    ["type": "output_text", "text": payload],
                ],
            ],
        ],
    ]
    let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: 200, body: JSONSerialization.data(withJSONObject: body))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)

    let result = try await service.generate(
        LearningMaterialServiceGenerationRequest(
            endpoint: endpoint(adapterKind: .openAIResponses),
            plaintextSecret: "sk-test-secret",
            input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
            operationID: DiagnosticOperationID(rawValue: "op-reasoning"),
            lengthBucket: .short
        )
    )

    #expect(result.inputKind == .nativeRecord)
    #expect(result.learningText == "I went to a cafe today.")
}

// Removed 2026-07-22 with the Gemini wiring: every closed-set adapter kind now
// dispatches, so the "reserved kind maps to unsupportedProvider before HTTP"
// scenario no longer exists. The mapping code stays as the error vocabulary for
// future kinds; the safety net is the factory's compile-time-exhaustive switch.

private func sampleAnalysisRequest() -> LearningMaterialServiceAnalysisRequest {
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
        operationID: DiagnosticOperationID(rawValue: "op-analyze-validation"),
        lengthBucket: .short
    )
}

private func expectGenerationRejects(_ payload: String) async {
    do {
        let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
            .success(.init(statusCode: 200, body: chatResponse(payload))),
        ])
        let service = LearningMaterialGenerationService(httpClient: httpClient)
        _ = try await service.generate(
            LearningMaterialServiceGenerationRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
                operationID: DiagnosticOperationID(rawValue: "op-rejects"),
                lengthBucket: .short
            )
        )
        Issue.record("Expected invalid structured response error")
    } catch let error as LearningMaterialGenerationServiceError {
        #expect(error.category == .invalidStructuredResponse)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

private func expectAnalysisRejects(_ payload: String) async {
    do {
        let httpClient = try CapturingLearningMaterialHTTPClient(responses: [
            .success(.init(statusCode: 200, body: chatResponse(payload))),
        ])
        let service = LearningMaterialGenerationService(httpClient: httpClient)
        _ = try await service.analyze(sampleAnalysisRequest())
        Issue.record("Expected invalid structured response error")
    } catch let error as LearningMaterialGenerationServiceError {
        #expect(error.category == .invalidStructuredResponse)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

private func expectGenerationHTTPStatus(
    _ statusCode: Int,
    mapsTo category: LearningMaterialGenerationFailureCategory
) async {
    let httpClient = CapturingLearningMaterialHTTPClient(responses: [
        .success(.init(statusCode: statusCode, body: Data(#"{"error":"provider failure"}"#.utf8))),
    ])
    let service = LearningMaterialGenerationService(httpClient: httpClient)
    do {
        _ = try await service.generate(
            LearningMaterialServiceGenerationRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleGenerationInput(sourceText: "今天我去咖啡馆。"),
                operationID: DiagnosticOperationID(rawValue: "op-status-\(statusCode)"),
                lengthBucket: .short
            )
        )
        Issue.record("Expected failure for HTTP \(statusCode)")
    } catch let error as LearningMaterialGenerationServiceError {
        #expect(error.category == category)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
