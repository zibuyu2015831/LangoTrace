import Foundation
@testable import LangoTraceAI
import LangoTraceCore

actor CapturingLearningMaterialHTTPClient: AIProviderProbeHTTPClient {
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

func sampleGenerationInput(sourceText: String) -> LearningMaterialGenerationInput {
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

func endpoint(adapterKind: AIProviderAdapterKind) -> AIProviderEndpointInput {
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

func chatResponse(_ content: String) throws -> Data {
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

func responsesResponse(_ content: String) throws -> Data {
    let object: [String: Any] = [
        "output": [
            [
                "content": [
                    [
                        "text": content,
                    ],
                ],
            ],
        ],
    ]
    return try JSONSerialization.data(withJSONObject: object)
}

func generationJSON(
    inputKind: String,
    revisionCategory: String = "grammar",
    memoryKind: String = "phrase",
    memoryDifficulty: String = "easy",
    practiceKind: String = "backTranslation"
) -> String {
    let analysis = analysisObjectJSON(
        sentenceCount: 1,
        memoryCandidateCount: 1,
        practiceCandidateCount: 1,
        memoryKind: memoryKind,
        memoryDifficulty: memoryDifficulty,
        practiceKind: practiceKind
    )
    return """
    {
      "schema_version": "learning_material.v1",
      "input_kind": "\(inputKind)",
      "learning_text": "I went to a cafe today.",
      "revision_notes": [
        {
          "original_text": "I go cafe today.",
          "revised_text": "I went to a cafe today.",
          "reason_native": "用过去式 went，并补充冠词。",
          "category": "\(revisionCategory)"
        }
      ],
      "analysis": \(analysis)
    }
    """
}

func analysisJSON(
    sentenceCount: Int = 1,
    memoryCandidateCount: Int = 0,
    practiceCandidateCount: Int = 0
) -> String {
    let analysis = analysisObjectJSON(
        sentenceCount: sentenceCount,
        memoryCandidateCount: memoryCandidateCount,
        practiceCandidateCount: practiceCandidateCount
    )
    return """
    {
      "schema_version": "learning_material.v1",
      "analysis": \(analysis)
    }
    """
}

func analysisObjectJSON(
    sentenceCount: Int,
    memoryCandidateCount: Int,
    practiceCandidateCount: Int,
    memoryKind: String = "phrase",
    memoryDifficulty: String = "easy",
    practiceKind: String = "backTranslation"
) -> String {
    let sentences = (0 ..< sentenceCount).map(sentenceJSON(position:)).joined(separator: ",\n")
    let memoryCandidates = (0 ..< memoryCandidateCount)
        .map { _ in memoryCandidateJSON(kind: memoryKind, difficulty: memoryDifficulty) }
        .joined(separator: ",\n")
    let practiceCandidates = (0 ..< practiceCandidateCount)
        .map { _ in practiceCandidateJSON(kind: practiceKind) }
        .joined(separator: ",\n")
    return """
    {
      "analysis_basis": "learningText",
      "sentences": [\(sentences)],
      "memory_candidates": [\(memoryCandidates)],
      "practice_candidates": [\(practiceCandidates)]
    }
    """
}

func sentenceJSON(position: Int) -> String {
    """
    {
      "position": \(position),
      "native_sentence": "我今天去了咖啡馆。",
      "target_sentence": "I went to a cafe today.",
      "literal_translation": "I went to cafe today.",
      "natural_translation": "I went to a cafe today.",
      "grammar_notes": [
        {
          "point_native": "过去式",
          "explanation_native": "went 是 go 的过去式。"
        }
      ],
      "key_points": [
        {
          "text": "went to",
          "explanation_native": "表示去了某处。"
        }
      ]
    }
    """
}

func memoryCandidateJSON(kind: String = "phrase", difficulty: String = "easy") -> String {
    """
    {
      "kind": "\(kind)",
      "text": "went to",
      "explanation_native": "表示去了某处。",
      "example_target": "I went to a cafe today.",
      "example_native": "我今天去了咖啡馆。",
      "difficulty": "\(difficulty)",
      "sentence_position": 0
    }
    """
}

func practiceCandidateJSON(kind: String = "backTranslation") -> String {
    """
    {
      "kind": "\(kind)",
      "title_native": "回译",
      "prompt_text": "我今天去了咖啡馆。",
      "answer_text": "I went to a cafe today.",
      "sentence_position": 0
    }
    """
}

extension URLRequest {
    var httpBodyText: String? {
        httpBody.map { String(decoding: $0, as: UTF8.self) }
    }

    func jsonBodyValue(_ dottedPath: String) -> String? {
        jsonBodyValue(at: dottedPath) as? String
    }

    func jsonBodyStringArray(_ dottedPath: String) -> [String]? {
        jsonBodyValue(at: dottedPath) as? [String]
    }

    private func jsonBodyValue(at dottedPath: String) -> Any? {
        guard let httpBody,
              let object = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any]
        else {
            return nil
        }
        return dottedPath.split(separator: ".").reduce(Any?(object)) { partial, key in
            guard let dictionary = partial as? [String: Any] else {
                return nil
            }
            return dictionary[String(key)]
        }
    }
}
