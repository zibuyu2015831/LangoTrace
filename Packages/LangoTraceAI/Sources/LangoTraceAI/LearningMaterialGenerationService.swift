@preconcurrency import Foundation
import LangoTraceCore

public struct LearningMaterialServiceGenerationRequest: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var input: LearningMaterialGenerationInput
    public var operationID: DiagnosticOperationID
    public var lengthBucket: LearningMaterialEstimatedTokenBucket

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        input: LearningMaterialGenerationInput,
        operationID: DiagnosticOperationID,
        lengthBucket: LearningMaterialEstimatedTokenBucket
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.input = input
        self.operationID = operationID
        self.lengthBucket = lengthBucket
    }
}

public struct LearningMaterialServiceAnalysisRequest: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var input: LearningMaterialAnalysisInput
    public var operationID: DiagnosticOperationID
    public var lengthBucket: LearningMaterialEstimatedTokenBucket

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        input: LearningMaterialAnalysisInput,
        operationID: DiagnosticOperationID,
        lengthBucket: LearningMaterialEstimatedTokenBucket
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.input = input
        self.operationID = operationID
        self.lengthBucket = lengthBucket
    }
}

public struct LearningMaterialGenerationServiceError: Error, Equatable, Sendable {
    public var category: LearningMaterialGenerationFailureCategory

    public init(category: LearningMaterialGenerationFailureCategory) {
        self.category = category
    }
}

public struct LearningMaterialGenerationService: Sendable {
    private let httpClient: any AIProviderProbeHTTPClient
    private let clock: @Sendable () -> Date

    public init(
        httpClient: any AIProviderProbeHTTPClient,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.clock = clock
    }

    public func generate(
        _ request: LearningMaterialServiceGenerationRequest
    ) async throws -> LearningMaterialGenerationResult {
        let endpoint = try normalizedGenerationEndpoint(request.endpoint)
        let prompt = LearningMaterialPromptRegistry.generatePrompt(
            input: request.input,
            lengthBucket: request.lengthBucket
        )
        let text = try await responseText(
            endpoint: endpoint,
            plaintextSecret: request.plaintextSecret,
            prompt: prompt
        )
        return try parseGenerationJSON(
            text,
            input: request.input,
            endpoint: endpoint,
            prompt: prompt
        )
    }

    public func analyze(
        _ request: LearningMaterialServiceAnalysisRequest
    ) async throws -> LearningMaterialAnalysisResult {
        let endpoint = try normalizedGenerationEndpoint(request.endpoint)
        let prompt = LearningMaterialPromptRegistry.analyzePrompt(
            input: request.input,
            lengthBucket: request.lengthBucket
        )
        let text = try await responseText(
            endpoint: endpoint,
            plaintextSecret: request.plaintextSecret,
            prompt: prompt
        )
        return try parseAnalysisJSON(text, input: request.input)
    }
}

private extension LearningMaterialGenerationService {
    func responseText(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        prompt: LearningMaterialRenderedPrompt
    ) async throws -> String {
        let adapter = try textAdapter(for: endpoint)
        let urlRequest = try makeRequest(adapter: adapter, endpoint: endpoint, secret: plaintextSecret, prompt: prompt)
        let response: AIProviderProbeHTTPResponse
        do {
            response = try await httpClient.send(urlRequest)
        } catch let error as AIProviderProbeHTTPClientError {
            throw serviceError(for: error)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .networkUnavailable)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw LearningMaterialGenerationServiceError(
                category: failureCategory(forHTTPStatusCode: response.statusCode)
            )
        }
        do {
            return try adapter.extractText(fromResponseBody: response.body)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
    }

    /// Resolves the shared text-request adapter for the endpoint kind, mapping
    /// the reserved (`anthropicMessages` / `geminiGenerateContent`) kinds to the
    /// service's `unsupportedProvider` category.
    func textAdapter(for endpoint: AIProviderEndpointInput) throws -> any AIProviderTextRequestAdapter {
        do {
            return try AIProviderTextRequestAdapterFactory.adapter(for: endpoint.adapterKind)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .unsupportedProvider)
        }
    }

    func failureCategory(forHTTPStatusCode statusCode: Int) -> LearningMaterialGenerationFailureCategory {
        switch AIProviderHTTPStatusErrorMapper.errorCategory(forHTTPStatusCode: statusCode) {
        case .authenticationFailed:
            .authenticationFailed
        case .rateLimited:
            .rateLimited
        case .unsupportedModel:
            .unsupportedModel
        default:
            .providerRejected
        }
    }

    func normalizedGenerationEndpoint(_ input: AIProviderEndpointInput) throws -> AIProviderEndpointInput {
        let endpoint: AIProviderEndpointInput
        do {
            endpoint = try input.normalized()
        } catch {
            throw LearningMaterialGenerationServiceError(category: .providerNotConfigured)
        }
        guard endpoint.isEnabled, endpoint.purpose == .textGeneration else {
            throw LearningMaterialGenerationServiceError(category: .providerNotConfigured)
        }
        // Adapter-kind support (incl. the reserved anthropic / gemini kinds) is
        // resolved at the single dispatch point in `textAdapter(for:)`.
        return endpoint
    }

    func makeRequest(
        adapter: any AIProviderTextRequestAdapter,
        endpoint: AIProviderEndpointInput,
        secret: String?,
        prompt: LearningMaterialRenderedPrompt
    ) throws -> URLRequest {
        let body = adapter.structuredCompletionBody(
            model: endpoint.modelName,
            system: prompt.system,
            user: prompt.user,
            temperature: 0.2,
            structuredOutputName: jsonSchemaName(for: prompt),
            schema: jsonSchema(for: prompt)
        )
        do {
            return try adapter.makeRequest(
                baseURL: endpoint.baseURL,
                secret: secret,
                timeoutSeconds: endpoint.requestTimeoutSeconds,
                body: body
            )
        } catch AIProviderTextRequestAdapterError.invalidEndpointURL {
            throw LearningMaterialGenerationServiceError(category: .providerNotConfigured)
        }
    }

    func jsonSchemaName(for prompt: LearningMaterialRenderedPrompt) -> String {
        prompt.id == LearningMaterialPromptRegistry.analysisPromptID
            ? "learning_material_analysis"
            : "learning_material_generation"
    }

    func jsonSchema(for prompt: LearningMaterialRenderedPrompt) -> [String: Any] {
        prompt.id == LearningMaterialPromptRegistry.analysisPromptID
            ? analysisResponseSchema()
            : generationResponseSchema()
    }

    func generationResponseSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["schema_version", "input_kind", "learning_text", "revision_notes", "analysis"],
            "properties": [
                "schema_version": ["type": "string", "enum": [LearningMaterialPromptRegistry.schemaVersion]],
                "input_kind": [
                    "type": "string",
                    "enum": ["nativeRecord", "targetWriting", "mixed", "uncertain"],
                ],
                "learning_text": ["type": "string"],
                "revision_notes": [
                    "type": "array",
                    "items": revisionNoteSchema(),
                ],
                "analysis": analysisSchema(),
            ],
        ]
    }

    func analysisResponseSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["schema_version", "analysis"],
            "properties": [
                "schema_version": ["type": "string", "enum": [LearningMaterialPromptRegistry.schemaVersion]],
                "analysis": analysisSchema(),
            ],
        ]
    }

    func analysisSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["analysis_basis", "sentences", "memory_candidates", "practice_candidates"],
            "properties": [
                "analysis_basis": ["type": "string", "enum": ["learningText"]],
                "sentences": [
                    "type": "array",
                    "items": sentenceSchema(),
                ],
                "memory_candidates": [
                    "type": "array",
                    "items": memoryCandidateSchema(),
                ],
                "practice_candidates": [
                    "type": "array",
                    "items": practiceCandidateSchema(),
                ],
            ],
        ]
    }

    func sentenceSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "position", "native_sentence", "target_sentence", "literal_translation",
                "natural_translation", "grammar_notes", "key_points",
            ],
            "properties": [
                "position": ["type": "integer"],
                "native_sentence": ["type": "string"],
                "target_sentence": ["type": "string"],
                "literal_translation": ["type": "string"],
                "natural_translation": ["type": "string"],
                "grammar_notes": [
                    "type": "array",
                    "minItems": 1,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["point_native", "explanation_native"],
                        "properties": [
                            "point_native": ["type": "string"],
                            "explanation_native": ["type": "string"],
                        ],
                    ],
                ],
                "key_points": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["text", "explanation_native"],
                        "properties": [
                            "text": ["type": "string"],
                            "explanation_native": ["type": "string"],
                        ],
                    ],
                ],
            ],
        ]
    }

    func revisionNoteSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["original_text", "revised_text", "reason_native", "category"],
            "properties": [
                "original_text": ["type": "string"],
                "revised_text": ["type": "string"],
                "reason_native": ["type": "string"],
                "category": [
                    "type": "string",
                    "enum": ["grammar", "wordChoice", "naturalness", "clarity", "tone", "structure"],
                ],
            ],
        ]
    }

    func memoryCandidateSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "kind", "text", "explanation_native", "example_target",
                "example_native", "difficulty", "sentence_position",
            ],
            "properties": [
                "kind": [
                    "type": "string",
                    "enum": ["word", "phrase", "sentencePattern", "grammarPoint", "errorPattern"],
                ],
                "text": ["type": "string"],
                "explanation_native": ["type": "string"],
                "example_target": ["type": "string"],
                "example_native": ["type": "string"],
                "difficulty": ["type": "string", "enum": ["easy", "medium", "hard"]],
                "sentence_position": ["type": ["integer", "null"]],
            ],
        ]
    }

    func practiceCandidateSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["kind", "title_native", "prompt_text", "answer_text", "sentence_position"],
            "properties": [
                "kind": ["type": "string", "enum": ["listening", "shadowing", "dictation", "backTranslation"]],
                "title_native": ["type": "string"],
                "prompt_text": ["type": "string"],
                "answer_text": ["type": "string"],
                "sentence_position": ["type": ["integer", "null"]],
            ],
        ]
    }

    func parseGenerationJSON(
        _ text: String,
        input: LearningMaterialGenerationInput,
        endpoint: AIProviderEndpointInput,
        prompt: LearningMaterialRenderedPrompt
    ) throws -> LearningMaterialGenerationResult {
        let data = try jsonData(fromModelText: text)
        let response: GenerationResponse
        do {
            response = try JSONDecoder().decode(GenerationResponse.self, from: data)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        guard response.schemaVersion == LearningMaterialPromptRegistry.schemaVersion,
              let inputKind = LearningMaterialInputKind(rawValue: response.inputKind),
              !response.learningText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              response.learningText.count <= ResponseLimit.maximumLearningTextLength,
              response.revisionNotes.count <= ResponseLimit.maximumRevisionNotes
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        let revisionSummary = try response.revisionNotes.enumerated().map { index, revision -> LearningRevision in
            guard let category = LearningRevision.Category(rawValue: revision.category),
                  isWithinLimit(revision.originalText, maximumLength: ResponseLimit.maximumExampleLength),
                  isWithinLimit(revision.revisedText, maximumLength: ResponseLimit.maximumExampleLength),
                  isWithinLimit(revision.reasonNative, maximumLength: ResponseLimit.maximumExplanationLength)
            else {
                throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
            }
            return LearningRevision(
                id: "revision-\(index)",
                originalText: revision.originalText,
                revisedText: revision.revisedText,
                reasonNative: revision.reasonNative,
                category: category,
                position: index
            )
        }
        let analysis = try materialAnalysis(from: response.analysis)
        return LearningMaterialGenerationResult(
            entryID: input.entryID,
            spaceID: input.spaceID,
            inputKind: inputKind,
            promptMode: .automaticLearningMaterial,
            learningText: response.learningText,
            revisionSummary: revisionSummary,
            analysis: analysis,
            metadata: LearningMaterialGenerationMetadata(
                promptID: prompt.id,
                promptVersion: prompt.version,
                providerProfileID: endpoint.profileID,
                providerEndpointID: endpoint.id,
                providerPresetID: endpoint.providerPresetID,
                modelName: endpoint.modelName,
                generatedAt: clock()
            )
        )
    }

    func parseAnalysisJSON(
        _ text: String,
        input: LearningMaterialAnalysisInput
    ) throws -> LearningMaterialAnalysisResult {
        let data = try jsonData(fromModelText: text)
        let response: AnalysisOnlyResponse
        do {
            response = try JSONDecoder().decode(AnalysisOnlyResponse.self, from: data)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        guard response.schemaVersion == LearningMaterialPromptRegistry.schemaVersion else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return try LearningMaterialAnalysisResult(
            materialID: input.materialID,
            analysis: materialAnalysis(from: response.analysis)
        )
    }

    /// Strips one wrapping Markdown code fence (the only documented tolerance
    /// in the prompt registry parsing contract) and requires the remaining
    /// text to be a single JSON document. Natural-language prose around the
    /// JSON object is rejected as an invalid structured response.
    func jsonData(fromModelText text: String) throws -> Data {
        let trimmed = stripCodeFence(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let data = trimmed.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return data
    }

    func stripCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```") else {
            return text
        }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Array and string limits mirrored from the registry contract in
    /// `docs/prompts/learning-material/one-tap-learning-material.md`.
    enum ResponseLimit {
        static let maximumSentences = 20
        static let maximumMemoryCandidates = 12
        static let maximumPracticeCandidates = 6
        static let maximumRevisionNotes = 12
        static let maximumGrammarNotesPerSentence = 3
        static let maximumKeyPointsPerSentence = 3
        static let maximumLearningTextLength = 12000
        static let maximumTitleLength = 80
        static let maximumPointLength = 160
        static let maximumNoteLength = 400
        static let maximumExplanationLength = 500
        static let maximumExampleLength = 600
        static let maximumSentenceLength = 800
    }

    func isWithinLimit(_ value: String, maximumLength: Int) -> Bool {
        !value.isEmpty && value.count <= maximumLength
    }

    func materialAnalysis(from response: AnalysisResponse) throws -> LearningMaterialAnalysis {
        guard response.analysisBasis == "learningText" else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        guard !response.sentences.isEmpty,
              response.sentences.count <= ResponseLimit.maximumSentences,
              response.memoryCandidates.count <= ResponseLimit.maximumMemoryCandidates,
              response.practiceCandidates.count <= ResponseLimit.maximumPracticeCandidates
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return try LearningMaterialAnalysis(
            status: .fresh,
            sourceTextHash: "",
            sentences: response.sentences.enumerated().map { index, sentence in
                try validatedSentenceAnalysis(sentence, index: index)
            },
            memoryCandidates: response.memoryCandidates.enumerated().map { index, candidate in
                try validatedMemoryCandidate(candidate, index: index, sentences: response.sentences)
            },
            practiceCandidates: response.practiceCandidates.enumerated().map { index, candidate in
                try validatedPracticeCandidate(candidate, index: index, sentences: response.sentences)
            }
        )
    }

    func validatedSentenceAnalysis(
        _ sentence: SentenceResponse,
        index: Int
    ) throws -> LearningSentenceAnalysis {
        guard sentence.grammarNotes.count <= ResponseLimit.maximumGrammarNotesPerSentence,
              sentence.keyPoints.count <= ResponseLimit.maximumKeyPointsPerSentence,
              isWithinLimit(sentence.nativeSentence, maximumLength: ResponseLimit.maximumSentenceLength),
              isWithinLimit(sentence.targetSentence, maximumLength: ResponseLimit.maximumSentenceLength),
              isWithinLimit(sentence.literalTranslation, maximumLength: ResponseLimit.maximumSentenceLength),
              isWithinLimit(sentence.naturalTranslation, maximumLength: ResponseLimit.maximumSentenceLength),
              sentence.grammarNotes.allSatisfy({ note in
                  isWithinLimit(note.pointNative, maximumLength: ResponseLimit.maximumPointLength)
                      && isWithinLimit(note.explanationNative, maximumLength: ResponseLimit.maximumNoteLength)
              }),
              sentence.keyPoints.allSatisfy({ keyPoint in
                  isWithinLimit(keyPoint.text, maximumLength: ResponseLimit.maximumPointLength)
                      && isWithinLimit(keyPoint.explanationNative, maximumLength: ResponseLimit.maximumNoteLength)
              })
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return LearningSentenceAnalysis(
            id: "sentence-\(index)",
            nativeSentence: sentence.nativeSentence,
            targetSentence: sentence.targetSentence,
            literalTranslation: sentence.literalTranslation,
            naturalTranslation: sentence.naturalTranslation,
            grammarNotes: sentence.grammarNotes.map(\.displayText),
            keyPoints: sentence.keyPoints.map(\.displayText),
            position: index
        )
    }

    func validatedMemoryCandidate(
        _ candidate: MemoryCandidateResponse,
        index: Int,
        sentences: [SentenceResponse]
    ) throws -> LearningMemoryCandidate {
        guard let kind = LearningMemoryCandidate.Kind(rawValue: candidate.kind),
              let difficulty = LearningMemoryCandidate.Difficulty(rawValue: candidate.difficulty),
              isWithinLimit(candidate.text, maximumLength: ResponseLimit.maximumPointLength),
              isWithinLimit(candidate.explanationNative, maximumLength: ResponseLimit.maximumExplanationLength),
              isWithinLimit(candidate.exampleTarget, maximumLength: ResponseLimit.maximumExampleLength),
              isWithinLimit(candidate.exampleNative, maximumLength: ResponseLimit.maximumExampleLength)
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return LearningMemoryCandidate(
            id: "memory-\(index)",
            sentenceID: sentenceID(for: candidate.sentencePosition, in: sentences),
            kind: kind,
            text: candidate.text,
            explanationNative: candidate.explanationNative,
            exampleTarget: candidate.exampleTarget,
            exampleNative: candidate.exampleNative,
            difficulty: difficulty
        )
    }

    func validatedPracticeCandidate(
        _ candidate: PracticeCandidateResponse,
        index: Int,
        sentences: [SentenceResponse]
    ) throws -> LearningPracticeCandidate {
        guard let kind = LearningPracticeCandidate.Kind(rawValue: candidate.kind),
              isWithinLimit(candidate.titleNative, maximumLength: ResponseLimit.maximumTitleLength),
              isWithinLimit(candidate.promptText, maximumLength: ResponseLimit.maximumExampleLength),
              isWithinLimit(candidate.answerText, maximumLength: ResponseLimit.maximumExampleLength)
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return LearningPracticeCandidate(
            id: "practice-\(index)",
            sentenceID: sentenceID(for: candidate.sentencePosition, in: sentences),
            kind: kind,
            title: candidate.titleNative,
            promptText: candidate.promptText,
            answerText: candidate.answerText
        )
    }

    func sentenceID(for position: Int?, in sentences: [SentenceResponse]) -> String? {
        guard let position,
              let index = sentences.firstIndex(where: { $0.position == position })
        else {
            return nil
        }
        return "sentence-\(index)"
    }

    func serviceError(for error: AIProviderProbeHTTPClientError) -> LearningMaterialGenerationServiceError {
        switch error {
        case .timedOut:
            LearningMaterialGenerationServiceError(category: .timeout)
        case .cancelled:
            LearningMaterialGenerationServiceError(category: .cancelled)
        case .transportUnavailable:
            LearningMaterialGenerationServiceError(category: .networkUnavailable)
        }
    }
}

private struct AnalysisOnlyResponse: Decodable {
    var schemaVersion: String
    var analysis: AnalysisResponse

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case analysis
    }
}

private struct GenerationResponse: Decodable {
    var schemaVersion: String
    var inputKind: String
    var learningText: String
    var revisionNotes: [RevisionResponse]
    var analysis: AnalysisResponse

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case inputKind = "input_kind"
        case learningText = "learning_text"
        case revisionNotes = "revision_notes"
        case analysis
    }
}

private struct RevisionResponse: Decodable {
    var originalText: String
    var revisedText: String
    var reasonNative: String
    var category: String

    enum CodingKeys: String, CodingKey {
        case originalText = "original_text"
        case revisedText = "revised_text"
        case reasonNative = "reason_native"
        case category
    }
}

private struct AnalysisResponse: Decodable {
    var analysisBasis: String
    var sentences: [SentenceResponse]
    var memoryCandidates: [MemoryCandidateResponse]
    var practiceCandidates: [PracticeCandidateResponse]

    enum CodingKeys: String, CodingKey {
        case analysisBasis = "analysis_basis"
        case sentences
        case memoryCandidates = "memory_candidates"
        case practiceCandidates = "practice_candidates"
    }
}

private struct SentenceResponse: Decodable {
    var position: Int
    var nativeSentence: String
    var targetSentence: String
    var literalTranslation: String
    var naturalTranslation: String
    var grammarNotes: [GrammarNoteResponse]
    var keyPoints: [KeyPointResponse]

    enum CodingKeys: String, CodingKey {
        case position
        case nativeSentence = "native_sentence"
        case targetSentence = "target_sentence"
        case literalTranslation = "literal_translation"
        case naturalTranslation = "natural_translation"
        case grammarNotes = "grammar_notes"
        case keyPoints = "key_points"
    }
}

private struct GrammarNoteResponse: Decodable {
    var pointNative: String
    var explanationNative: String

    var displayText: String {
        "\(pointNative): \(explanationNative)"
    }

    enum CodingKeys: String, CodingKey {
        case pointNative = "point_native"
        case explanationNative = "explanation_native"
    }
}

private struct KeyPointResponse: Decodable {
    var text: String
    var explanationNative: String

    var displayText: String {
        "\(text): \(explanationNative)"
    }

    enum CodingKeys: String, CodingKey {
        case text
        case explanationNative = "explanation_native"
    }
}

private struct MemoryCandidateResponse: Decodable {
    var kind: String
    var text: String
    var explanationNative: String
    var exampleTarget: String
    var exampleNative: String
    var difficulty: String
    var sentencePosition: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case text
        case explanationNative = "explanation_native"
        case exampleTarget = "example_target"
        case exampleNative = "example_native"
        case difficulty
        case sentencePosition = "sentence_position"
    }
}

private struct PracticeCandidateResponse: Decodable {
    var kind: String
    var titleNative: String
    var promptText: String
    var answerText: String
    var sentencePosition: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case titleNative = "title_native"
        case promptText = "prompt_text"
        case answerText = "answer_text"
        case sentencePosition = "sentence_position"
    }
}
