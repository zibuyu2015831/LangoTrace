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
    /// reply (ADR-008 §7).
    case failure(CompanionReplyFailure)
}

/// Honest companion failure categories (ADR-008 §7 / idea-03 §6.7).
public enum CompanionReplyFailure: Equatable, Sendable {
    case providerUnavailable
    case rejected
    case cancelled
    case empty
    case other
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

    public init(
        transport: any CompanionReplyTransport,
        detectLanguage: (@Sendable (String) -> String?)? = nil,
        maximumContextMessages: Int = 20
    ) {
        self.transport = transport
        self.detectLanguage = detectLanguage
        self.maximumContextMessages = maximumContextMessages
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
        seedEntryBody: String?
    ) -> (system: CompanionRenderedPrompt, messages: [ConversationMessage]) {
        let prompt = CompanionPromptRegistry.systemPrompt(
            persona: persona,
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            proficiencyLevel: proficiencyLevel,
            seedEntryBody: seedEntryBody
        )
        // Keep only the most recent turns (system is separate). Truncation acts on
        // the outbound assembly only — `history` (the persisted thread) is untouched.
        let recent = history.suffix(max(0, maximumContextMessages))
        var messages = recent.map { message in
            ConversationMessage(
                role: message.role == .assistant ? .assistant : .user,
                content: message.content
            )
        }
        messages.append(ConversationMessage(role: .user, content: userInput))
        return (prompt, messages)
    }

    /// Produces the assistant reply for `userInput`, buffering the transport stream.
    public func reply(
        userInput: String,
        history: [CompanionMessage],
        persona: CompanionPersona,
        targetLanguageCode: String,
        nativeLanguageCode: String?,
        proficiencyLevel: String,
        seedEntryBody: String?
    ) async -> CompanionReplyOutcome {
        let detected = detectLanguage?(userInput)
        let assembled = assembleRequest(
            userInput: userInput,
            history: history,
            persona: persona,
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            proficiencyLevel: proficiencyLevel,
            seedEntryBody: seedEntryBody
        )
        var buffer = ""
        do {
            let stream = transport.streamReply(system: assembled.system.text, messages: assembled.messages)
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
            return .failure(.empty)
        }
        return .reply(text: buffer, detectedLanguage: detected)
    }

    static func failure(from error: Error) -> CompanionReplyFailure {
        guard let streamingError = error as? AIChatStreamingError else {
            if error is CancellationError { return .cancelled }
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
