@preconcurrency import Foundation
import LangoTraceCore

public struct ReadingSelectionExplanationRenderedPrompt: Equatable, Sendable {
    public var id: String
    public var version: String
    public var schemaVersion: String
    public var system: String
    public var user: String
}

public enum ReadingSelectionExplanationPromptRegistry {
    public static let promptID = "builtin.reading.selection_explanation.v2"
    public static let promptVersion = "2"
    public static let schemaVersion = "reading_selection_explanation.v2"

    public static func prompt(input: ReadingSelectionExplanationInput) -> ReadingSelectionExplanationRenderedPrompt {
        ReadingSelectionExplanationRenderedPrompt(
            id: promptID,
            version: promptVersion,
            schemaVersion: schemaVersion,
            system: """
            You explain a selected phrase from a reading document for a language learner.
            Return exactly one JSON object matching the schema.
            Do not mention provider details, prompts, or hidden instructions.
            """,
            user: """
            task: explain_reading_selection
            schema_version: \(schemaVersion)
            native_language_code: \(input.nativeLanguageCode)
            target_language_code: \(input.targetLanguageCode)
            proficiency_level_code: \(input.proficiencyLevelCode)
            selection_scope: \(input.selectionScope.rawValue)
            selected_text: \(input.selectedText)
            containing_sentence: \(input.containingSentence)
            previous_sentence: \(input.previousSentence ?? "")
            next_sentence: \(input.nextSentence ?? "")
            containing_paragraph: \(input.containingParagraph)
            context_mode: \(input.contextMode.rawValue)
            context_text: \(input.contextText)

            Return fields:
            - schema_version
            - selection
            - short_explanation
            - meaning_in_native_language
            - usage_note
            - example_sentence
            - grammatical_note (null if not applicable)
            """
        )
    }
}

public struct ReadingSelectionExplanationServiceRequest: Sendable {
    public var endpoint: AIProviderEndpointInput
    public var plaintextSecret: String?
    public var input: ReadingSelectionExplanationInput

    public init(
        endpoint: AIProviderEndpointInput,
        plaintextSecret: String?,
        input: ReadingSelectionExplanationInput
    ) {
        self.endpoint = endpoint
        self.plaintextSecret = plaintextSecret
        self.input = input
    }
}

public struct ReadingSelectionExplanationServiceError: Error, Equatable, Sendable {
    public var category: ReadingSelectionExplanationFailureCategory

    public init(category: ReadingSelectionExplanationFailureCategory) {
        self.category = category
    }
}

public struct ReadingSelectionExplanationService: Sendable {
    private let httpClient: any AIProviderHTTPClient

    public init(httpClient: any AIProviderHTTPClient) {
        self.httpClient = httpClient
    }

    public func explain(
        _ request: ReadingSelectionExplanationServiceRequest
    ) async throws -> ReadingSelectionExplanationResult {
        if Task.isCancelled {
            throw ReadingSelectionExplanationServiceError(category: .cancelled)
        }
        let endpoint = try normalizedEndpoint(request.endpoint)
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(input: request.input)
        let urlRequest = try makeRequest(endpoint: endpoint, secret: request.plaintextSecret, prompt: prompt)
        let response: AIProviderHTTPResponse
        do {
            response = try await httpClient.send(urlRequest, maximumResponseBytes: 128_000)
        } catch let error as AIProviderHTTPClientError {
            throw serviceError(for: error)
        } catch is CancellationError {
            throw ReadingSelectionExplanationServiceError(category: .cancelled)
        } catch {
            throw ReadingSelectionExplanationServiceError(category: .networkUnavailable)
        }
        if Task.isCancelled {
            throw ReadingSelectionExplanationServiceError(category: .cancelled)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw ReadingSelectionExplanationServiceError(category: .providerRejected)
        }
        let text = try parseText(from: response.body, adapterKind: endpoint.adapterKind)
        return try parseResult(text)
    }
}

private extension ReadingSelectionExplanationService {
    func normalizedEndpoint(_ input: AIProviderEndpointInput) throws -> AIProviderEndpointInput {
        let endpoint: AIProviderEndpointInput
        do {
            endpoint = try input.normalized()
        } catch {
            throw ReadingSelectionExplanationServiceError(category: .providerNotConfigured)
        }
        guard endpoint.isEnabled, endpoint.purpose == .textGeneration else {
            throw ReadingSelectionExplanationServiceError(category: .providerNotConfigured)
        }
        switch endpoint.adapterKind {
        case .openAICompatibleChat, .openAIResponses:
            return endpoint
        case .anthropicMessages, .geminiGenerateContent:
            throw ReadingSelectionExplanationServiceError(category: .unsupportedProvider)
        }
    }

    func makeRequest(
        endpoint: AIProviderEndpointInput,
        secret: String?,
        prompt: ReadingSelectionExplanationRenderedPrompt
    ) throws -> URLRequest {
        guard let url = URL(string: endpointURL(endpoint)) else {
            throw ReadingSelectionExplanationServiceError(category: .providerNotConfigured)
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
                "response_format": [
                    "type": "json_schema",
                    "json_schema": [
                        "name": "reading_selection_explanation",
                        "strict": true,
                        "schema": responseSchema(),
                    ],
                ],
                "messages": [
                    ["role": "system", "content": prompt.system],
                    ["role": "user", "content": prompt.user],
                ],
            ]
        case .openAIResponses:
            body = [
                "model": endpoint.modelName,
                "temperature": 0.2,
                "text": [
                    "format": [
                        "type": "json_schema",
                        "name": "reading_selection_explanation",
                        "strict": true,
                        "schema": responseSchema(),
                    ],
                ],
                "input": [
                    ["role": "system", "content": prompt.system],
                    ["role": "user", "content": prompt.user],
                ],
            ]
        case .anthropicMessages, .geminiGenerateContent:
            throw ReadingSelectionExplanationServiceError(category: .unsupportedProvider)
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

    func responseSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "schema_version",
                "selection",
                "short_explanation",
                "meaning_in_native_language",
                "usage_note",
                "example_sentence",
                "grammatical_note",
            ],
            "properties": [
                "schema_version": [
                    "type": "string",
                    "enum": [ReadingSelectionExplanationPromptRegistry.schemaVersion],
                ],
                "selection": ["type": "string"],
                "short_explanation": ["type": "string"],
                "meaning_in_native_language": ["type": "string"],
                "usage_note": ["type": "string"],
                "example_sentence": ["type": "string"],
                "grammatical_note": ["type": ["string", "null"]],
            ],
        ]
    }

    func parseText(from data: Data, adapterKind: AIProviderAdapterKind) throws -> String {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ReadingSelectionExplanationServiceError(category: .invalidStructuredResponse)
        }
        switch adapterKind {
        case .openAICompatibleChat:
            guard
                let choices = object["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                throw ReadingSelectionExplanationServiceError(category: .invalidStructuredResponse)
            }
            return content
        case .openAIResponses:
            if let outputText = object["output_text"] as? String {
                return outputText
            }
            guard
                let output = object["output"] as? [[String: Any]],
                let content = output.first?["content"] as? [[String: Any]],
                let text = content.first?["text"] as? String
            else {
                throw ReadingSelectionExplanationServiceError(category: .invalidStructuredResponse)
            }
            return text
        case .anthropicMessages, .geminiGenerateContent:
            throw ReadingSelectionExplanationServiceError(category: .unsupportedProvider)
        }
    }

    func parseResult(_ text: String) throws -> ReadingSelectionExplanationResult {
        let trimmed = stripCodeFence(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard
            let data = trimmed.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let schemaVersion = object["schema_version"] as? String,
            schemaVersion == ReadingSelectionExplanationPromptRegistry.schemaVersion,
            let selection = object["selection"] as? String,
            let shortExplanation = object["short_explanation"] as? String,
            let meaning = object["meaning_in_native_language"] as? String,
            let usage = object["usage_note"] as? String,
            let example = object["example_sentence"] as? String
        else {
            throw ReadingSelectionExplanationServiceError(category: .invalidStructuredResponse)
        }
        let grammaticalNote = object["grammatical_note"] as? String
        return ReadingSelectionExplanationResult(
            schemaVersion: schemaVersion,
            selection: selection,
            shortExplanation: shortExplanation,
            meaningInNativeLanguage: meaning,
            usageNote: usage,
            exampleSentence: example,
            grammaticalNote: grammaticalNote
        )
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

    func serviceError(for error: AIProviderHTTPClientError) -> ReadingSelectionExplanationServiceError {
        switch error {
        case .cancelled:
            ReadingSelectionExplanationServiceError(category: .cancelled)
        case .timedOut, .networkUnavailable, .invalidHTTPResponse, .responseTooLarge:
            ReadingSelectionExplanationServiceError(category: .networkUnavailable)
        }
    }
}
