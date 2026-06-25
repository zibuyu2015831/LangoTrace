import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

/// LM03-S2a Phase 3: the chat extraction engine parses the fixed JSON contract
/// into `CompanionMemoryCandidate`s, treats an empty list as success (count 0),
/// and maps transport / parse failures onto the honest `CompanionExtractionError`
/// vocabulary. Reuses the S1 `CompanionReplyTransport` seam (stubbed here).
@Suite("Companion extraction engine")
struct CompanionExtractionEngineTests {
    private struct StubTransport: CompanionReplyTransport {
        var deltas: [String] = []
        var error: Error?

        func streamReply(
            system _: String,
            messages _: [ConversationMessage]
        ) -> AsyncThrowingStream<AIChatStreamEvent, Error> {
            let deltas = deltas
            let error = error
            return AsyncThrowingStream { continuation in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for delta in deltas {
                    continuation.yield(.delta(delta))
                }
                continuation.finish()
            }
        }
    }

    private func message(_ sequence: Int, _ role: CompanionMessageRole, _ content: String) -> CompanionMessage {
        CompanionMessage(
            id: "m\(sequence)",
            threadID: "t1",
            sequence: sequence,
            role: role,
            content: content,
            targetLanguageCode: "en",
            createdAt: Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }

    private func engine(_ transport: StubTransport) -> CompanionExtractionEngine {
        CompanionExtractionEngine(transport: transport)
    }

    private let validJSON = """
    {"schema_version":"1","candidates":[
      {"kind":"phrase","text":"break the ice","explanation_native":"打破沉默",
       "example_target":"Let's break the ice.","example_native":"我们来打破沉默。"},
      {"kind":"word","text":"serene","explanation_native":"宁静的",
       "example_target":"a serene lake","example_native":"一片宁静的湖"}
    ]}
    """

    @Test("parsesStructuredCandidates — maps JSON into reused-kind candidates")
    func parsesStructuredCandidates() async {
        let window = [message(0, .user, "I want a serene place"), message(1, .assistant, "Let's break the ice.")]
        let result = await engine(StubTransport(deltas: [validJSON])).extract(
            window: window, targetLanguageCode: "en", nativeLanguageCode: "zh-Hans",
            now: Date(timeIntervalSince1970: 100), idPrefix: "c"
        )
        guard case let .success(candidates) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(candidates.map(\.kind) == [.phrase, .word])
        #expect(candidates.map(\.text) == ["break the ice", "serene"])
        #expect(candidates.map(\.id) == ["c-0", "c-1"])
        #expect(candidates.allSatisfy { $0.createdAt == Date(timeIntervalSince1970: 100) })
    }

    @Test("toleratesCodeFenceWrapper — strips one ``` fence before parsing")
    func toleratesCodeFenceWrapper() async {
        let fenced = "```json\n\(validJSON)\n```"
        let result = await engine(StubTransport(deltas: [fenced])).extract(
            window: [message(0, .user, "hi")], targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        guard case let .success(candidates) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(candidates.count == 2)
    }

    @Test("emptyCandidatesIsSuccessNotFailure — model found nothing → success count 0")
    func emptyCandidatesIsSuccess() async {
        let json = "{\"schema_version\":\"1\",\"candidates\":[]}"
        let result = await engine(StubTransport(deltas: [json])).extract(
            window: [message(0, .user, "hi")], targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(result == .success([]))
    }

    @Test("invalidJSONIsInvalidStructuredOutput")
    func invalidJSONIsInvalidStructuredOutput() async {
        let result = await engine(StubTransport(deltas: ["not json at all"])).extract(
            window: [message(0, .user, "hi")], targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(result == .failure(.invalidStructuredOutput))
    }

    @Test("missingRequiredFieldIsInvalidStructuredOutput — candidate without text")
    func missingRequiredFieldIsInvalidStructuredOutput() async {
        let json = """
        {"schema_version":"1","candidates":[
          {"kind":"word","explanation_native":"x","example_target":"y","example_native":"z"}
        ]}
        """
        let result = await engine(StubTransport(deltas: [json])).extract(
            window: [message(0, .user, "hi")], targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(result == .failure(.invalidStructuredOutput))
    }

    @Test("unknownKindIsInvalidStructuredOutput")
    func unknownKindIsInvalidStructuredOutput() async {
        let json = """
        {"schema_version":"1","candidates":[
          {"kind":"idiomzzz","text":"x","explanation_native":"x","example_target":"y","example_native":"z"}
        ]}
        """
        let result = await engine(StubTransport(deltas: [json])).extract(
            window: [message(0, .user, "hi")], targetLanguageCode: "en", nativeLanguageCode: "zh-Hans"
        )
        #expect(result == .failure(.invalidStructuredOutput))
    }

    @Test("mapsTransportErrorsOntoHonestFailures")
    func mapsTransportErrors() async {
        let window = [message(0, .user, "hi")]
        let unavailable = await engine(StubTransport(error: AIChatStreamingError.networkUnavailable)).extract(
            window: window, targetLanguageCode: "en", nativeLanguageCode: nil
        )
        #expect(unavailable == .failure(.providerUnavailable))

        let cancelled = await engine(StubTransport(error: AIChatStreamingError.cancelled)).extract(
            window: window, targetLanguageCode: "en", nativeLanguageCode: nil
        )
        #expect(cancelled == .failure(.cancelled))

        let rejected = await engine(
            StubTransport(error: AIChatStreamingError.providerRejected(.authenticationFailed))
        ).extract(window: window, targetLanguageCode: "en", nativeLanguageCode: nil)
        #expect(rejected == .failure(.rejected))
    }

    @Test("companionExtractionProjectionDisclosesConversationAndNoNewCategory")
    func projectionDisclosesConversation() {
        let projection = AIRequestPreviewProjection.companionExtraction(
            endpoint: endpoint(adapterKind: .openAICompatibleChat),
            lengthBucket: .short
        )
        #expect(projection.capability == .companionExtraction)
        // Discloses the conversation as the included category…
        #expect(projection.includedContent == [.companionConversation])
        // …and admits no new outbound category: every privacy guarantee stays excluded.
        #expect(projection.excludedContent.contains(.photoAttachments))
        #expect(projection.excludedContent.contains(.longTermMemory))
        #expect(projection.excludedContent.contains(.historicalEntries))
        #expect(!projection.includedContent.contains(.longTermMemory))
    }
}
