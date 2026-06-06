import Foundation
import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Reading selection explanation service")
struct ReadingSelectionExplanationServiceTests {
    @Test("prompt registry renders selection scope and dynamic context contract")
    func promptRegistryRendersSelectionScopeAndDynamicContextContract() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(
            input: sampleInput(
                selection: "図書館",
                containingSentence: "今日は図書館で読みます。",
                contextText: "朝ごはんを食べました。今日は图书馆で読みます。静かな午後でした。",
                selectionScope: .textFragment,
                contextMode: .currentParagraph
            )
        )

        #expect(prompt.id == "builtin.reading.selection_explanation.v3")
        #expect(prompt.version == "3")
        #expect(prompt.user.contains("selected_text: 図書館"))
        #expect(prompt.user.contains("selection_scope: text_fragment"))
        #expect(prompt.user.contains("context_mode: current_paragraph"))
        #expect(prompt.user.contains("previous_sentence: 朝ごはんを食べました。"))
        #expect(prompt.user.contains("next_sentence: 静かな午後でした。"))
        #expect(prompt.user.contains("containing_paragraph: 朝ごはんを食べました。今日は图书馆で読みます。静かな午後でした。"))
        #expect(prompt.user.contains("grammatical_note"))
    }

    @Test("service builds chat request with selection limited payload and parses response")
    func serviceBuildsChatRequestAndParsesResponse() async throws {
        let httpClient = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSON()))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        let result = try await service.explain(
            ReadingSelectionExplanationServiceRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: "sk-test-secret",
                input: sampleInput(
                    selection: "ticket",
                    containingSentence: "I bought a ticket at the station.",
                    contextText: "I bought a ticket at the station.",
                    selectionScope: .textFragment,
                    contextMode: .fullDocument
                )
            )
        )

        let requests = await httpClient.requests
        #expect(requests.count == 1)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(requests[0].jsonBodyValue("response_format.type") == "json_schema")
        #expect(requests[0].httpBodyText?.contains("selected_text: ticket") == true)
        #expect(requests[0].httpBodyText?.contains("selection_scope: text_fragment") == true)
        #expect(requests[0].httpBodyText?.contains("context_mode: full_document") == true)
        #expect(result.selection == "ticket")
        #expect(result.shortExplanation == "A travel noun in this sentence.")
        #expect(result.grammaticalNote == "Noun, countable.")
    }

    @Test("service parses grammatical_note when present and returns nil when absent")
    func servicesParsesGrammaticalNote() async throws {
        let withNote = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSON(grammaticalNote: "Noun, countable.")))),
        ])
        let withNull = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSON(grammaticalNote: nil)))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: withNote)
        let serviceNull = ReadingSelectionExplanationService(httpClient: withNull)
        let input = sampleInput(
            selection: "ticket",
            containingSentence: "I bought a ticket.",
            contextText: "I bought a ticket.",
            selectionScope: .textFragment,
            contextMode: .fullDocument
        )

        let resultWithNote = try await service.explain(
            ReadingSelectionExplanationServiceRequest(endpoint: endpoint(adapterKind: .openAICompatibleChat), plaintextSecret: nil, input: input)
        )
        let resultWithNull = try await serviceNull.explain(
            ReadingSelectionExplanationServiceRequest(endpoint: endpoint(adapterKind: .openAICompatibleChat), plaintextSecret: nil, input: input)
        )

        #expect(resultWithNote.grammaticalNote == "Noun, countable.")
        #expect(resultWithNull.grammaticalNote == nil)
    }

    @Test("service maps cancellation without parsing or returning stale content")
    func serviceMapsCancellation() async throws {
        let httpClient = CapturingReadingExplanationHTTPClient(responses: [
            .failure(AIProviderHTTPClientError.cancelled),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        await #expect(throws: ReadingSelectionExplanationServiceError(category: .cancelled)) {
            try await service.explain(
                ReadingSelectionExplanationServiceRequest(
                    endpoint: endpoint(adapterKind: .openAICompatibleChat),
                    plaintextSecret: "sk-test-secret",
                    input: sampleInput(
                        selection: "ticket",
                        containingSentence: "I bought a ticket.",
                        contextText: "I bought a ticket.",
                        selectionScope: .sentence,
                        contextMode: .currentParagraph
                    )
                )
            )
        }
    }

    // MARK: - v3 prompt language directives

    @Test("prompt v3 id and schema version reflect upgrade")
    func promptV3IdAndSchemaVersion() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(input: sampleInput(
            selection: "ticket",
            containingSentence: "I bought a ticket.",
            contextText: "I bought a ticket.",
            selectionScope: .sentence,
            contextMode: .fullDocument,
            mode: .bilingualBridge
        ))
        #expect(prompt.id == "builtin.reading.selection_explanation.v3")
        #expect(prompt.version == "3")
        #expect(prompt.schemaVersion == "reading_selection_explanation.v3")
    }

    @Test("sourceLanguage prompt instructs all fields in native language except example_sentence")
    func sourceLanguagePromptHasNativeDirectives() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(input: sampleInput(
            selection: "ticket",
            containingSentence: "I bought a ticket.",
            contextText: "I bought a ticket.",
            selectionScope: .sentence,
            contextMode: .fullDocument,
            mode: .sourceLanguage
        ))
        #expect(prompt.user.contains("explanation_language_mode: sourceLanguage"))
        #expect(prompt.user.contains("short_explanation: zh-Hans"))
        #expect(prompt.user.contains("grammatical_note: zh-Hans"))
        #expect(prompt.user.contains("usage_note: zh-Hans"))
        #expect(prompt.user.contains("example_sentence_translation: zh-Hans"))
    }

    @Test("bilingualBridge prompt uses target for short_explanation and usage, native for grammatical_note")
    func bilingualBridgePromptHasMixedDirectives() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(input: sampleInput(
            selection: "ticket",
            containingSentence: "I bought a ticket.",
            contextText: "I bought a ticket.",
            selectionScope: .sentence,
            contextMode: .fullDocument,
            mode: .bilingualBridge
        ))
        #expect(prompt.user.contains("explanation_language_mode: bilingualBridge"))
        #expect(prompt.user.contains("short_explanation: en"))
        #expect(prompt.user.contains("grammatical_note: zh-Hans"))
        #expect(prompt.user.contains("usage_note: en"))
        #expect(prompt.user.contains("example_sentence_translation: zh-Hans"))
    }

    @Test("targetImmersion prompt instructs all output fields in target language")
    func targetImmersionPromptHasTargetDirectives() {
        let prompt = ReadingSelectionExplanationPromptRegistry.prompt(input: sampleInput(
            selection: "ticket",
            containingSentence: "I bought a ticket.",
            contextText: "I bought a ticket.",
            selectionScope: .sentence,
            contextMode: .fullDocument,
            mode: .targetImmersion
        ))
        #expect(prompt.user.contains("explanation_language_mode: targetImmersion"))
        #expect(prompt.user.contains("short_explanation: en"))
        #expect(prompt.user.contains("grammatical_note: en"))
        #expect(prompt.user.contains("usage_note: en"))
        // immersion: example_sentence_translation is null
        #expect(prompt.user.contains("example_sentence_translation: null"))
    }

    // MARK: - v3 parser

    @Test("parser rejects v2 schema_version")
    func parserRejectsV2SchemaVersion() async throws {
        let httpClient = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSONV2()))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)
        await #expect(throws: ReadingSelectionExplanationServiceError(category: .invalidStructuredResponse)) {
            try await service.explain(ReadingSelectionExplanationServiceRequest(
                endpoint: endpoint(adapterKind: .openAICompatibleChat),
                plaintextSecret: nil,
                input: sampleInput(selection: "ticket", containingSentence: "I bought a ticket.",
                                   contextText: "I bought a ticket.", selectionScope: .sentence,
                                   contextMode: .fullDocument, mode: .bilingualBridge)
            ))
        }
    }

    @Test("parser round-trips explanationLanguageMode and exampleSentenceTranslation from v3 response")
    func parserRoundTripsNewFieldsFromV3() async throws {
        let httpClient = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSONV3(
                mode: .bilingualBridge, translation: "我在网上买了一张票。"
            )))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)
        let result = try await service.explain(ReadingSelectionExplanationServiceRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: nil,
            input: sampleInput(selection: "ticket", containingSentence: "I bought a ticket.",
                               contextText: "I bought a ticket.", selectionScope: .sentence,
                               contextMode: .fullDocument, mode: .bilingualBridge)
        ))
        #expect(result.explanationLanguageMode == .bilingualBridge)
        #expect(result.exampleSentenceTranslation == "我在网上买了一张票。")
    }

    @Test("parser accepts null example_sentence_translation for targetImmersion")
    func parserAcceptsNullTranslationForImmersion() async throws {
        let httpClient = try CapturingReadingExplanationHTTPClient(responses: [
            .success(AIProviderHTTPResponse(statusCode: 200, body: chatResponse(explanationJSONV3(
                mode: .targetImmersion, translation: nil
            )))),
        ])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)
        let result = try await service.explain(ReadingSelectionExplanationServiceRequest(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            plaintextSecret: nil,
            input: sampleInput(selection: "ticket", containingSentence: "I bought a ticket.",
                               contextText: "I bought a ticket.", selectionScope: .sentence,
                               contextMode: .fullDocument, mode: .targetImmersion)
        ))
        #expect(result.explanationLanguageMode == .targetImmersion)
        #expect(result.exampleSentenceTranslation == nil)
    }

    @Test("service rejects unsupported adapters before HTTP")
    func serviceRejectsUnsupportedAdaptersBeforeHTTP() async throws {
        let httpClient = CapturingReadingExplanationHTTPClient(responses: [])
        let service = ReadingSelectionExplanationService(httpClient: httpClient)

        await #expect(throws: ReadingSelectionExplanationServiceError(category: .unsupportedProvider)) {
            try await service.explain(
                ReadingSelectionExplanationServiceRequest(
                    endpoint: endpoint(adapterKind: .anthropicMessages),
                    plaintextSecret: "sk-test-secret",
                    input: sampleInput(
                        selection: "ticket",
                        containingSentence: "I bought a ticket.",
                        contextText: "I bought a ticket.",
                        selectionScope: .sentence,
                        contextMode: .currentParagraph
                    )
                )
            )
        }
        #expect(await httpClient.requests.isEmpty)
    }
}

private actor CapturingReadingExplanationHTTPClient: AIProviderHTTPClient {
    private(set) var requests: [URLRequest] = []
    private var responses: [Result<AIProviderHTTPResponse, Error>]

    init(responses: [Result<AIProviderHTTPResponse, Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest, maximumResponseBytes _: Int) async throws -> AIProviderHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw AIProviderHTTPClientError.networkUnavailable
        }
        return try responses.removeFirst().get()
    }
}

private func sampleInput(
    selection: String,
    containingSentence: String,
    contextText: String,
    selectionScope: ReadingSelectionScope,
    contextMode: ReadingContextMode,
    mode: ExplanationLanguageMode = .bilingualBridge
) -> ReadingSelectionExplanationInput {
    ReadingSelectionExplanationInput(
        documentID: "doc-1",
        sourceAnchorID: "anchor-1",
        selectedText: selection,
        selectionScope: selectionScope,
        containingSentence: containingSentence,
        previousSentence: "朝ごはんを食べました。",
        nextSentence: "静かな午後でした。",
        containingParagraph: "朝ごはんを食べました。今日は图书馆で読みます。静かな午後でした。",
        contextMode: contextMode,
        contextText: contextText,
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        proficiencyLevelCode: "B1",
        explanationLanguageMode: mode
    )
}

private func explanationJSONV3(
    mode: ExplanationLanguageMode = .bilingualBridge,
    grammaticalNote: String? = "Noun, countable.",
    translation: String? = "我在网上买了一张票。"
) -> String {
    let note = grammaticalNote.map { "\"\($0)\"" } ?? "null"
    let trans = translation.map { "\"\($0)\"" } ?? "null"
    return """
    {
      "schema_version": "reading_selection_explanation.v3",
      "selection": "ticket",
      "short_explanation": "A travel noun in this sentence.",
      "meaning_in_native_language": "票",
      "usage_note": "Used for trains, events, and travel.",
      "example_sentence": "I bought a ticket online.",
      "example_sentence_translation": \(trans),
      "grammatical_note": \(note),
      "explanation_language_mode": "\(mode.rawValue)"
    }
    """
}

private func explanationJSONV2(grammaticalNote: String? = "Noun, countable.") -> String {
    let note = grammaticalNote.map { "\"\($0)\"" } ?? "null"
    return """
    {
      "schema_version": "reading_selection_explanation.v2",
      "selection": "ticket",
      "short_explanation": "A travel noun in this sentence.",
      "meaning_in_native_language": "票",
      "usage_note": "Used for trains, events, and travel.",
      "example_sentence": "I bought a ticket online.",
      "grammatical_note": \(note)
    }
    """
}

// Keep backward-compatible alias for existing tests
private func explanationJSON(grammaticalNote: String? = "Noun, countable.") -> String {
    explanationJSONV3(grammaticalNote: grammaticalNote)
}
