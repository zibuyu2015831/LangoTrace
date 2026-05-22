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

    public func generate(_ request: LearningMaterialServiceGenerationRequest) async throws -> LearningMaterialGenerationResult {
        let endpoint = try normalizedGenerationEndpoint(request.endpoint)
        let prompt = LearningMaterialPromptRegistry.generatePrompt(input: request.input, lengthBucket: request.lengthBucket)
        let urlRequest = try makeRequest(endpoint: endpoint, secret: request.plaintextSecret, prompt: prompt)
        let response: AIProviderProbeHTTPResponse
        do {
            response = try await httpClient.send(urlRequest)
        } catch let error as AIProviderProbeHTTPClientError {
            throw serviceError(for: error)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .networkUnavailable)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LearningMaterialGenerationServiceError(category: .providerRejected)
        }
        let text = try parseText(from: response.body, adapterKind: endpoint.adapterKind)
        return try parseGenerationJSON(
            text,
            input: request.input,
            endpoint: endpoint,
            prompt: prompt
        )
    }
}

private extension LearningMaterialGenerationService {
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
        switch endpoint.adapterKind {
        case .openAICompatibleChat, .openAIResponses:
            return endpoint
        case .anthropicMessages, .geminiGenerateContent:
            throw LearningMaterialGenerationServiceError(category: .unsupportedProvider)
        }
    }

    func makeRequest(
        endpoint: AIProviderEndpointInput,
        secret: String?,
        prompt: LearningMaterialRenderedPrompt
    ) throws -> URLRequest {
        guard let url = URL(string: endpointURL(endpoint)) else {
            throw LearningMaterialGenerationServiceError(category: .providerNotConfigured)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret, !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any]
        switch endpoint.adapterKind {
        case .openAICompatibleChat:
            body = [
                "model": endpoint.modelName,
                "temperature": 0.2,
                "messages": [
                    ["role": "system", "content": prompt.system],
                    ["role": "user", "content": prompt.user],
                ],
            ]
        case .openAIResponses:
            body = [
                "model": endpoint.modelName,
                "temperature": 0.2,
                "input": [
                    ["role": "system", "content": prompt.system],
                    ["role": "user", "content": prompt.user],
                ],
            ]
        case .anthropicMessages, .geminiGenerateContent:
            throw LearningMaterialGenerationServiceError(category: .unsupportedProvider)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if let timeout = endpoint.requestTimeoutSeconds {
            request.timeoutInterval = timeout
        }
        return request
    }

    func endpointURL(_ endpoint: AIProviderEndpointInput) -> String {
        let trimmed = endpoint.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = endpoint.adapterKind == .openAIResponses ? "responses" : "chat/completions"
        if trimmed.hasSuffix(suffix) {
            return trimmed
        }
        return "\(trimmed)/\(suffix)"
    }

    func parseText(from data: Data, adapterKind: AIProviderAdapterKind) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        switch adapterKind {
        case .openAICompatibleChat:
            guard let choices = object["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String
            else {
                throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
            }
            return content
        case .openAIResponses:
            if let outputText = object["output_text"] as? String {
                return outputText
            }
            guard let output = object["output"] as? [[String: Any]],
                  let first = output.first,
                  let content = first["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String
            else {
                throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
            }
            return text
        case .anthropicMessages, .geminiGenerateContent:
            throw LearningMaterialGenerationServiceError(category: .unsupportedProvider)
        }
    }

    func parseGenerationJSON(
        _ text: String,
        input: LearningMaterialGenerationInput,
        endpoint: AIProviderEndpointInput,
        prompt: LearningMaterialRenderedPrompt
    ) throws -> LearningMaterialGenerationResult {
        guard let data = text.data(using: .utf8) else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        let response: GenerationResponse
        do {
            response = try JSONDecoder().decode(GenerationResponse.self, from: data)
        } catch {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        guard response.schemaVersion == LearningMaterialPromptRegistry.schemaVersion,
              let inputKind = LearningMaterialInputKind(rawValue: response.inputKind),
              !response.learningText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        let analysis = try materialAnalysis(from: response.analysis)
        return LearningMaterialGenerationResult(
            entryID: input.entryID,
            spaceID: input.spaceID,
            inputKind: inputKind,
            promptMode: .automaticLearningMaterial,
            learningText: response.learningText,
            revisionSummary: response.revisionNotes.enumerated().map { index, revision in
                LearningRevision(
                    id: "revision-\(index)",
                    originalText: revision.originalText,
                    revisedText: revision.revisedText,
                    reasonNative: revision.reasonNative,
                    category: LearningRevision.Category(rawValue: revision.category) ?? .clarity,
                    position: index
                )
            },
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

    func materialAnalysis(from response: AnalysisResponse) throws -> LearningMaterialAnalysis {
        guard !response.sentences.isEmpty else {
            throw LearningMaterialGenerationServiceError(category: .invalidStructuredResponse)
        }
        return LearningMaterialAnalysis(
            status: .fresh,
            sourceTextHash: "",
            sentences: response.sentences.enumerated().map { index, sentence in
                LearningSentenceAnalysis(
                    id: "sentence-\(index)",
                    nativeSentence: sentence.nativeSentence,
                    targetSentence: sentence.targetSentence,
                    literalTranslation: sentence.literalTranslation,
                    naturalTranslation: sentence.naturalTranslation,
                    grammarNotes: sentence.grammarNotes,
                    keyPoints: sentence.keyPoints,
                    position: index
                )
            },
            memoryCandidates: response.memoryCandidates.enumerated().map { index, candidate in
                LearningMemoryCandidate(
                    id: "memory-\(index)",
                    sentenceID: nil,
                    kind: LearningMemoryCandidate.Kind(rawValue: candidate.kind) ?? .phrase,
                    text: candidate.text,
                    explanationNative: candidate.explanationNative,
                    exampleTarget: candidate.exampleTarget,
                    exampleNative: candidate.exampleNative,
                    difficulty: LearningMemoryCandidate.Difficulty(rawValue: candidate.difficulty) ?? .medium
                )
            },
            practiceCandidates: response.practiceCandidates.enumerated().map { index, candidate in
                LearningPracticeCandidate(
                    id: "practice-\(index)",
                    sentenceID: nil,
                    kind: LearningPracticeCandidate.Kind(rawValue: candidate.kind) ?? .backTranslation,
                    title: candidate.title,
                    promptText: candidate.promptText,
                    answerText: candidate.answerText
                )
            }
        )
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
    var sentences: [SentenceResponse]
    var memoryCandidates: [MemoryCandidateResponse]
    var practiceCandidates: [PracticeCandidateResponse]

    enum CodingKeys: String, CodingKey {
        case sentences
        case memoryCandidates = "memory_candidates"
        case practiceCandidates = "practice_candidates"
    }
}

private struct SentenceResponse: Decodable {
    var nativeSentence: String
    var targetSentence: String
    var literalTranslation: String
    var naturalTranslation: String
    var grammarNotes: [String]
    var keyPoints: [String]

    enum CodingKeys: String, CodingKey {
        case nativeSentence = "native_sentence"
        case targetSentence = "target_sentence"
        case literalTranslation = "literal_translation"
        case naturalTranslation = "natural_translation"
        case grammarNotes = "grammar_notes"
        case keyPoints = "key_points"
    }
}

private struct MemoryCandidateResponse: Decodable {
    var kind: String
    var text: String
    var explanationNative: String
    var exampleTarget: String
    var exampleNative: String
    var difficulty: String

    enum CodingKeys: String, CodingKey {
        case kind
        case text
        case explanationNative = "explanation_native"
        case exampleTarget = "example_target"
        case exampleNative = "example_native"
        case difficulty
    }
}

private struct PracticeCandidateResponse: Decodable {
    var kind: String
    var title: String
    var promptText: String
    var answerText: String

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case promptText = "prompt_text"
        case answerText = "answer_text"
    }
}
