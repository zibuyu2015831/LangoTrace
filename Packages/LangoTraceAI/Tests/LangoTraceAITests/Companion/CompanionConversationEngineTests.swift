import Foundation
@testable import LangoTraceAI
import LangoTraceCore
import Testing

@Suite("Companion conversation engine")
struct CompanionConversationEngineTests {
    /// Stub transport: yields the preset deltas, then finishes — throwing `error`
    /// after the deltas when one is set (so "streamed some, then failed" is
    /// expressible for the S3a partial-then-error path).
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
                for delta in deltas {
                    continuation.yield(.delta(delta))
                }
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.finish()
            }
        }
    }

    /// Thread-safe sink for the cumulative `onPartial` callbacks (the closure is
    /// `@Sendable`; collect under a lock so the assertions read a stable snapshot).
    private final class PartialCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String] = []
        func append(_ value: String) {
            lock.lock(); values.append(value); lock.unlock()
        }

        var snapshot: [String] {
            lock.lock(); defer { lock.unlock() }; return values
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

    // MARK: - Outbound PII scrub (LM03-S2b-1)

    @Test("outboundScrubCoversHistoryInputAndInjectedFacts — last turn's PII does not egress on replay")
    func outboundScrubCoversHistoryInputAndInjectedFacts() {
        let scrubbingEngine = CompanionConversationEngine(
            transport: StubTransport(deltas: ["ok"]),
            scrub: PIIScrubber.scrub
        )
        // A prior turn contains a phone number (persisted raw, replayed each round).
        let history = [message(0, .user, "call me at 13800138000")]
        let assembled = scrubbingEngine.assembleRequest(
            userInput: "my id is 11010519491231002X",
            history: history,
            persona: .default,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: nil,
            memoryContext: ["reachable at 13900139000"]
        )
        // History replay scrubbed.
        #expect(assembled.messages.first?.content == "call me at \(PIIScrubber.mobilePlaceholder)")
        // Current input scrubbed.
        #expect(assembled.messages.last?.content == "my id is \(PIIScrubber.nationalIDPlaceholder)")
        // Injected memory fact scrubbed (it lands in the system prompt).
        #expect(assembled.system.text.contains(PIIScrubber.mobilePlaceholder))
        #expect(!assembled.system.text.contains("13900139000"))
    }

    @Test("outboundScrubCoversSeedAndBroughtInRecords — 方案A seed + 方案B records are scrubbed (S2b-2 fix)")
    func outboundScrubCoversSeedAndBroughtInRecords() {
        let scrubbingEngine = CompanionConversationEngine(
            transport: StubTransport(deltas: ["ok"]),
            scrub: PIIScrubber.scrub
        )
        let assembled = scrubbingEngine.assembleRequest(
            userInput: "hi",
            history: [],
            persona: .default,
            targetLanguageCode: "en",
            nativeLanguageCode: "zh-Hans",
            proficiencyLevel: "b1",
            seedEntryBody: "call me at 13800138000", // 方案A — previously unscrubbed (S2b-1 gap)
            broughtInRecords: ["my id is 11010519491231002X"] // 方案B auto-sourced
        )
        // Both record bodies scrubbed in the outbound system prompt.
        #expect(assembled.system.text.contains(PIIScrubber.mobilePlaceholder))
        #expect(assembled.system.text.contains(PIIScrubber.nationalIDPlaceholder))
        #expect(!assembled.system.text.contains("13800138000"))
        #expect(!assembled.system.text.contains("11010519491231002X"))
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

    // MARK: - Streaming onPartial (LM03-S3a)

    @Test("onPartialReceivesCumulativeBufferPerDelta — caller sees the growing reply, ending on the full text")
    func onPartialReceivesCumulativeBuffer() async {
        let collector = PartialCollector()
        let outcome = await engine(transport: StubTransport(deltas: ["He", "llo"])).reply(
            userInput: "hi", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: nil,
            proficiencyLevel: "b1", seedEntryBody: nil,
            onPartial: { collector.append($0) }
        )
        // Each callback carries the cumulative buffer so far, in order.
        #expect(collector.snapshot == ["He", "Hello"])
        // The final outcome is still the complete buffered reply.
        #expect(outcome == .reply(text: "Hello", detectedLanguage: nil))
    }

    @Test("emptyStreamNeverCallsOnPartial — no partial bubble for a reply that never arrives")
    func emptyStreamNeverCallsOnPartial() async {
        let collector = PartialCollector()
        let outcome = await engine(transport: StubTransport(deltas: [])).reply(
            userInput: "hi", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: nil,
            proficiencyLevel: "b1", seedEntryBody: nil,
            onPartial: { collector.append($0) }
        )
        #expect(collector.snapshot.isEmpty)
        #expect(outcome == .failure(.empty))
    }

    @Test("partialDeltaThenErrorStillReportsFailure — onPartial fired, but the turn ends as an honest failure")
    func partialDeltaThenErrorStillReportsFailure() async {
        let collector = PartialCollector()
        let outcome = await engine(
            transport: StubTransport(deltas: ["He"], error: AIChatStreamingError.networkUnavailable)
        ).reply(
            userInput: "hi", history: [], persona: .default,
            targetLanguageCode: "en", nativeLanguageCode: nil,
            proficiencyLevel: "b1", seedEntryBody: nil,
            onPartial: { collector.append($0) }
        )
        // The partial was surfaced before the failure...
        #expect(collector.snapshot == ["He"])
        // ...but the outcome is failure: the store discards the partial, never persists it.
        #expect(outcome == .failure(.providerUnavailable))
    }
}
