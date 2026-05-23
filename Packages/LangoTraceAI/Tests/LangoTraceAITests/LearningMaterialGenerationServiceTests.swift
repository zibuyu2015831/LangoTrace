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
    #expect(result.inputKind == .nativeRecord)
    #expect(result.learningText == "I went to a cafe today.")
    #expect(result.analysis.sentences.first?.targetSentence == "I went to a cafe today.")
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

private actor CapturingLearningMaterialHTTPClient: AIProviderProbeHTTPClient {
    private(set) var requests: [URLRequest] = []
    private var responses: [Result<AIProviderProbeHTTPResponse, Error>]

    init(responses: [Result<AIProviderProbeHTTPResponse, Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> AIProviderProbeHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIProviderProbeHTTPClientError.transportUnavailable
        }
        let response = responses.removeFirst()
        switch response {
        case let .success(response):
            return response
        case let .failure(error):
            throw error
        }
    }
}

private func sampleGenerationInput(sourceText: String) -> LearningMaterialGenerationInput {
    LearningMaterialGenerationInput(
        entryID: "entry-1",
        spaceID: "space-1",
        sourceText: sourceText,
        entrySource: .typedText,
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        proficiencyLevelCode: "b1",
        promptMode: .automaticLearningMaterial
    )
}

private func endpoint(adapterKind: AIProviderAdapterKind) -> AIProviderEndpointInput {
    AIProviderEndpointInput(
        id: "endpoint-1",
        profileID: "profile-1",
        purpose: .textGeneration,
        isEnabled: true,
        providerPresetID: "openai",
        adapterKind: adapterKind,
        baseURL: "https://api.openai.com/v1",
        modelName: "gpt-4.1-mini",
        credentialID: "credential-1",
        supportsImageInput: false,
        imageInputEnabled: false,
        requestTimeoutSeconds: 30
    )
}

private func chatResponse(_ content: String) throws -> Data {
    let object: [String: Any] = [
        "choices": [
            [
                "message": [
                    "content": content,
                ],
            ],
        ],
    ]
    return try JSONSerialization.data(withJSONObject: object)
}

private func generationJSON(inputKind: String) -> String {
    """
    {
      "schema_version": "learning_material.v1",
      "input_kind": "\(inputKind)",
      "learning_text": "I went to a cafe today.",
      "revision_notes": [
        {
          "original_text": "I go cafe today.",
          "revised_text": "I went to a cafe today.",
          "reason_native": "用过去式 went，并补充冠词。",
          "category": "grammar"
        }
      ],
      "analysis": {
        "sentences": [
          {
            "native_sentence": "我今天去了咖啡馆。",
            "target_sentence": "I went to a cafe today.",
            "literal_translation": "I went to cafe today.",
            "natural_translation": "I went to a cafe today.",
            "grammar_notes": ["went 是 go 的过去式。"],
            "key_points": ["went to"]
          }
        ],
        "memory_candidates": [
          {
            "kind": "phrase",
            "text": "went to",
            "explanation_native": "表示去了某处。",
            "example_target": "I went to a cafe today.",
            "example_native": "我今天去了咖啡馆。",
            "difficulty": "easy"
          }
        ],
        "practice_candidates": [
          {
            "kind": "backTranslation",
            "title": "回译",
            "prompt_text": "我今天去了咖啡馆。",
            "answer_text": "I went to a cafe today."
          }
        ]
      }
    }
    """
}

private func analysisJSON() -> String {
    """
    {
      "schema_version": "learning_material.v1",
      "analysis": {
        "sentences": [
          {
            "native_sentence": "我今天去了咖啡馆。",
            "target_sentence": "I went to a cafe today.",
            "literal_translation": "I went to cafe today.",
            "natural_translation": "I went to a cafe today.",
            "grammar_notes": ["went 是 go 的过去式。"],
            "key_points": ["went to"]
          }
        ],
        "memory_candidates": [],
        "practice_candidates": []
      }
    }
    """
}

private extension URLRequest {
    var httpBodyText: String? {
        httpBody.map { String(decoding: $0, as: UTF8.self) }
    }

    func jsonBodyValue(_ dottedPath: String) -> String? {
        guard let httpBody,
              let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any]
        else {
            return nil
        }
        let value = dottedPath.split(separator: ".").reduce(Any?(object)) { partial, key in
            guard let dictionary = partial as? [String: Any] else {
                return nil
            }
            return dictionary[String(key)]
        }
        return value as? String
    }
}
