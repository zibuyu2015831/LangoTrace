import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Companion conversation engine")
struct CompanionConversationEngineTests {
    /// Stub transport: yields preset deltas, or finishes throwing `error`.
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

    private func engine(
        transport: StubTransport = StubTransport(deltas: ["ok"]),
        detect: (@Sendable (String) -> String?)? = nil,
        maxContext: Int = 20
    ) -> CompanionConversationEngine {
        CompanionConversationEngine(
            transport: transport,
            detectLanguage: detect,
            maximumContextMessages: maxContext
        )
    }

    // MARK: - Assembly

    @Test("contextWindowTruncatesOldestKeepsRecent — keeps the most recent N turns plus the new input")
    func contextWindowTruncatesOldestKeepsRecent() {
        let history = (0 ..< 30).map { message($0, $0.isMultiple(of: 2) ? .user : .assistant, "h\($0)") }
        let assembled = engine(maxContext: 10).assembleRequest(
            userInput: "new",
            history: history,
            persona: .default,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: nil
        )
        // 10 most recent history turns + the new user input.
        #expect(assembled.messages.count == 11)
        #expect(assembled.messages.first?.content == "h20")
        #expect(assembled.messages.last?.content == "new")
        #expect(assembled.messages.last?.role == .user)
    }

    @Test("truncationDoesNotMutatePersistedThread — the passed history is untouched")
    func truncationDoesNotMutatePersistedThread() {
        let history = (0 ..< 30).map { message($0, .user, "h\($0)") }
        _ = engine(maxContext: 5).assembleRequest(
            userInput: "new", history: history, persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(history.count == 30)
    }

    @Test("engineNeverInjectsMemoryFactsInS1 — outbound content is exactly history + user input, nothing injected")
    func engineNeverInjectsMemoryFactsInS1() {
        let history = [message(0, .user, "a"), message(1, .assistant, "b")]
        let assembled = engine().assembleRequest(
            userInput: "c", history: history, persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(assembled.messages.map(\.content) == ["a", "b", "c"])
        #expect(assembled.messages.map(\.role) == [.user, .assistant, .user])
    }

    @Test("languageRoutingNeverOverridesTargetLanguageReply — always-target directive holds even when input is native")
    func languageRoutingNeverOverridesTargetLanguageReply() async {
        let outcome = await engine(
            transport: StubTransport(deltas: ["hi"]),
            detect: { _ in "zh-Hans" }
        ).reply(
            userInput: "你好", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(outcome == .reply(text: "hi", detectedLanguage: "zh-Hans"))
        let assembled = engine().assembleRequest(
            userInput: "你好", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(assembled.system.directives.contains(.alwaysReplyTargetLanguage))
    }

    // MARK: - Reply buffering & failure

    @Test("Buffers deltas into a full non-streaming reply")
    func buffersDeltas() async {
        let outcome = await engine(transport: StubTransport(deltas: ["Hel", "lo"])).reply(
            userInput: "hi", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: nil,
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(outcome == .reply(text: "Hello", detectedLanguage: nil))
    }

    @Test("Empty stream is an empty failure, not a faked reply")
    func emptyStreamIsFailure() async {
        let outcome = await engine(transport: StubTransport(deltas: [])).reply(
            userInput: "hi", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: nil,
            proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(outcome == .failure(.empty))
    }

    @Test("Maps transport errors onto honest failure categories")
    func mapsTransportErrors() async {
        let unavailable = await engine(
            transport: StubTransport(error: AIChatStreamingError.networkUnavailable)
        ).reply(
            userInput: "hi", history: [], persona: .default, targetLanguageCode: "en",
            nativeLanguageCode: nil, proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(unavailable == .failure(.providerUnavailable))

        let cancelled = await engine(
            transport: StubTransport(error: AIChatStreamingError.cancelled)
        ).reply(
            userInput: "hi", history: [], persona: .default, targetLanguageCode: "en",
            nativeLanguageCode: nil, proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(cancelled == .failure(.cancelled))

        let unsupported = await engine(
            transport: StubTransport(error: AIChatStreamingError.unsupportedProvider)
        ).reply(
            userInput: "hi", history: [], persona: .default, targetLanguageCode: "en",
            nativeLanguageCode: nil, proficiencyLevel: "b1", seedEntryBody: nil
        )
        #expect(unsupported == .failure(.providerUnavailable))
    }
}
