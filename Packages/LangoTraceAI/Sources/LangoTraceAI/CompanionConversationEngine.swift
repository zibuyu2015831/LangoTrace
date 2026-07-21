import Foundation
import LangoTraceCore

/// Transport seam the companion engine sends a multi-turn request through. The
/// App layer adapts `AIChatStreamingService` (binding the resolved endpoint +
/// secret + E6 projection logging); the engine stays transport-agnostic and
/// fully testable with a stub.
public protocol CompanionReplyTransport: Sendable {
    func streamReply(
        system: String,
        messages: [ConversationMessage]
    ) -> AsyncThrowingStream<AIChatStreamEvent, Error>
}

/// Outcome of one companion turn.
public enum CompanionReplyOutcome: Equatable, Sendable {
    /// A complete assistant reply (deltas buffered for the non-streaming S1 UX),
    /// plus the locally detected language of the user input (routing hint only).
    case reply(text: String, detectedLanguage: String?)
    /// An honest failure — the store keeps the user's input and does not fake a
    /// reply (ADR-008 §7). `CompanionReplyFailure` lives in Core.
    case failure(CompanionReplyFailure)
}

/// Outcome of one rolling-summary generation (LM03-S3b-1). On failure the caller
/// must NOT update the persisted summary and must continue the reply unaffected
/// (honest failure — summarization is best-effort context compression, never a
/// blocker for the turn).
public enum CompanionSummarizationOutcome: Equatable, Sendable {
    case summary(String)
    case failure(CompanionReplyFailure)
}

/// Assembles a multi-turn companion request and produces the assistant reply.
///
/// v1 is non-streaming UX: it buffers the transport's deltas and returns the full
/// text (streaming UX is S3). Context window management is a mechanical "keep the
/// system prompt + the most recent N turns" truncation — no summary (S3). The
/// engine reads `history` but never mutates persisted state, and it has **no**
/// access to Memory facts or FTS, so S1 performs zero system-auto-injection
/// (decision #10 trivially satisfied; red line vs LM02 signals).
public struct CompanionConversationEngine: Sendable {
    private let transport: any CompanionReplyTransport
    /// Detects the language of a user message (App wires NaturalLanguage). Only a
    /// routing hint — never overrides the always-target-language reply.
    private let detectLanguage: (@Sendable (String) -> String?)?
    /// Max user/assistant turns sent to the provider (excludes the system prompt).
    private let maximumContextMessages: Int
    /// Outbound-only PII scrub applied to **everything that leaves the device**:
    /// the replayed history, the current input, and the injected memory facts
    /// (LM03-S2b-1 / `PIIScrubber`). Default is identity (S1 / tests). The engine
    /// is the single outbound chokepoint so last turn's PII cannot egress on
    /// replay this turn. Persistence keeps the originals — scrub is send-only.
    private let scrub: @Sendable (String) -> String

    public init(
        transport: any CompanionReplyTransport,
        detectLanguage: (@Sendable (String) -> String?)? = nil,
        maximumContextMessages: Int = 20,
        scrub: @escaping @Sendable (String) -> String = { $0 }
    ) {
        self.transport = transport
        self.detectLanguage = detectLanguage
        self.maximumContextMessages = maximumContextMessages
        self.scrub = scrub
    }

    /// The assembled outbound request: the system prompt and the truncated
    /// transcript that will be sent. Exposed so truncation / target-language /
    /// no-injection behaviour can be asserted directly.
    public func assembleRequest(
        userInput: String,
        history: [CompanionMessage],
        persona: CompanionPersona,
        targetLanguageCode: String,
        nativeLanguageCode: String?,
        proficiencyLevel: String,
        seedEntryBody: String?,
        memoryContext: [String] = [],
        broughtInRecords: [String] = [],
        conversationMemory: String? = nil,
        styleDescriptor: CompanionStyleDescriptor? = nil
    ) -> (system: CompanionRenderedPrompt, messages: [ConversationMessage]) {
        let prompt = CompanionPromptRegistry.systemPrompt(
            persona: persona,
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            proficiencyLevel: proficiencyLevel,
            // Brought-in record bodies (方案A seed + 方案B auto-sourced) are scrubbed
            // on the way out like every other outbound payload — the system prompt is
            // sent to the provider too. (S2b-2 fixes the S2b-1 gap that left
            // seedEntryBody unscrubbed.)
            seedEntryBody: seedEntryBody.map(scrub),
            memoryContext: memoryContext.map(scrub),
            broughtInRecords: broughtInRecords.map(scrub),
            // The rolling summary (LM03-S3b-1) lands in the system prompt too — scrub
            // it on the way out like every other outbound payload.
            conversationMemory: conversationMemory.map(scrub),
            // The Style descriptor (LM03-S4a) carries only quantized categories +
            // a CEFR ceiling — no raw user content — so it is NOT scrubbed (there is
            // nothing to scrub).
            styleDescriptor: styleDescriptor
        )
        // Keep only the most recent turns (system is separate). Truncation acts on
        // the outbound assembly only — `history` (the persisted thread) is untouched.
        // Every replayed turn AND the current input is scrubbed: prior turns are
        // re-sent each round, so scrubbing only the current input would leak.
        let recent = history.suffix(max(0, maximumContextMessages))
        var messages = recent.map { message in
            ConversationMessage(
                role: message.role == .assistant ? .assistant : .user,
                content: scrub(message.content)
            )
        }
        messages.append(ConversationMessage(role: .user, content: scrub(userInput)))
        return (prompt, messages)
    }

    /// Produces the assistant reply for `userInput`, buffering the transport stream.
    ///
    /// `onPartial` is invoked once per transport delta with the **cumulative**
    /// buffer so far (LM03-S3a streaming UX) — the App routes it to a UI-only
    /// in-flight bubble. It never touches persisted state: only the complete
    /// buffered text in the returned `.reply` is persisted, and a stream that
    /// fails after some deltas still returns `.failure` (the caller discards the
    /// partial — honest failure, ADR-008 §7). Default is a no-op (non-streaming
    /// callers / tests).
    public func reply(
        userInput: String,
        history: [CompanionMessage],
        persona: CompanionPersona,
        targetLanguageCode: String,
        nativeLanguageCode: String?,
        proficiencyLevel: String,
        seedEntryBody: String?,
        memoryContext: [String] = [],
        broughtInRecords: [String] = [],
        conversationMemory: String? = nil,
        styleDescriptor: CompanionStyleDescriptor? = nil,
        onPartial: @Sendable (String) -> Void = { _ in }
    ) async -> CompanionReplyOutcome {
        // Detect on the raw input (routing hint); the outbound payload is scrubbed
        // inside assembleRequest.
        let detected = detectLanguage?(userInput)
        let assembled = assembleRequest(
            userInput: userInput,
            history: history,
            persona: persona,
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            proficiencyLevel: proficiencyLevel,
            seedEntryBody: seedEntryBody,
            memoryContext: memoryContext,
            broughtInRecords: broughtInRecords,
            conversationMemory: conversationMemory,
            styleDescriptor: styleDescriptor
        )
        var buffer = ""
        do {
            let stream = transport.streamReply(system: assembled.system.text, messages: assembled.messages)
            for try await event in stream {
                switch event {
                case let .delta(text):
                    buffer += text
                    // Surface the growing reply for the streaming UI. Cumulative so
                    // the consumer can render the full bubble without re-joining.
                    onPartial(buffer)
                }
            }
        } catch {
            return .failure(Self.failure(from: error))
        }
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(CompanionReplyFailure.empty)
        }
        return .reply(text: buffer, detectedLanguage: detected)
    }

    /// Whether a send should (re)build the rolling summary first (LM03-S3b-1).
    /// Pure function so the threshold/window policy is unit-testable in isolation
    /// (self-review P0-3) rather than buried in the App send path. True when the
    /// conversation is past `threshold` AND there are turns that have aged out of
    /// the recent-verbatim window but are not yet folded into the summary (watermark
    /// nil = nothing folded yet).
    public static func shouldSummarize(
        messageCount: Int,
        watermark: Int?,
        threshold: Int = 24,
        recentVerbatimWindow: Int = 12
    ) -> Bool {
        guard messageCount > threshold else { return false }
        let oldestVerbatimSequence = messageCount - recentVerbatimWindow
        guard let watermark else { return true }
        return watermark < oldestVerbatimSequence
    }

    /// Folds the earlier conversation turns (`messagesToFold`) — and the prior
    /// summary if any — into an updated rolling summary (LM03-S3b-1). Non-streaming:
    /// buffers the transport and returns the full text. Outbound content is scrubbed
    /// like every other payload (the folded turns + the prior summary). On any
    /// transport error it returns `.failure`; the caller leaves the persisted
    /// summary untouched and continues the reply (best-effort, never blocks).
    public func summarize(
        messagesToFold: [CompanionMessage],
        existingSummary: String?,
        targetLanguageCode: String,
        nativeLanguageCode: String?
    ) async -> CompanionSummarizationOutcome {
        let prompt = CompanionSummarizationPromptRegistry.summarizationPrompt(
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode
        )
        var messages: [ConversationMessage] = []
        if let existingSummary, !existingSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(ConversationMessage(
                role: .user,
                content: "Prior summary to fold in:\n\(scrub(existingSummary))"
            ))
        }
        // The folded turns are supplied as reference content, scrubbed on the way out.
        for message in messagesToFold {
            messages.append(ConversationMessage(
                role: message.role == .assistant ? .assistant : .user,
                content: scrub(message.content)
            ))
        }
        var buffer = ""
        do {
            let stream = transport.streamReply(system: prompt.text, messages: messages)
            for try await event in stream {
                switch event {
                case let .delta(text):
                    buffer += text
                }
            }
        } catch {
            return .failure(Self.failure(from: error))
        }
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(CompanionReplyFailure.empty)
        }
        return .summary(buffer)
    }

    static func failure(from error: Error) -> CompanionReplyFailure {
        guard let streamingError = error as? AIChatStreamingError else {
            if error is CancellationError {
                return .cancelled
            }
            return .other
        }
        switch streamingError {
        case .cancelled:
            return .cancelled
        case .unsupportedProvider, .timedOut, .networkUnavailable:
            return .providerUnavailable
        case .providerRejected:
            return .rejected
        case .responseTooLarge, .invalidResponse:
            return .other
        }
    }
}
