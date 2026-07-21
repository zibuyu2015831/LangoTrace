import Foundation
import LangoTraceCore

/// Mines reusable vocabulary / expressions from a companion conversation window
/// (LM03-S2a 交付物 A). Reuses the S1 `CompanionReplyTransport` seam — the same
/// transport the App already wires onto `AIChatStreamingService` — so extraction
/// rides the existing provider path (decision #8) and stays fully testable with a
/// stub. The engine buffers the transport's deltas into one response and parses
/// the fixed JSON contract (`CompanionExtractionPromptRegistry`).
///
/// Privacy shape (plan §D2): the window it sends is the user's own conversation,
/// already shared turn-by-turn with the same provider, re-sent only on the user's
/// explicit "extract" action. This is **not** a system auto-injection — it injects
/// no Memory / profile content (that gated path is S2b).
public struct CompanionExtractionEngine: Sendable {
    private let transport: any CompanionReplyTransport

    public init(transport: any CompanionReplyTransport) {
        self.transport = transport
    }

    /// Extracts candidates from `window` (the conversation turns to mine). Returns
    /// `.success([])` when the model finds nothing (not a failure). `now` /
    /// `idPrefix` are injectable for deterministic tests.
    public func extract(
        window: [CompanionMessage],
        targetLanguageCode: String,
        nativeLanguageCode: String?,
        now: Date = Date(),
        idPrefix: String = "companion-candidate"
    ) async -> Result<[CompanionMemoryCandidate], CompanionExtractionError> {
        let prompt = CompanionExtractionPromptRegistry.extractionPrompt(
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode
        )
        let messages = window.map { message in
            ConversationMessage(
                role: message.role == .assistant ? .assistant : .user,
                content: message.content
            )
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
        return Self.parse(buffer, now: now, idPrefix: idPrefix)
    }

    // MARK: - Parsing

    static func parse(
        _ text: String,
        now: Date,
        idPrefix: String
    ) -> Result<[CompanionMemoryCandidate], CompanionExtractionError> {
        guard let data = jsonData(fromModelText: text) else {
            return .failure(.invalidStructuredOutput)
        }
        let response: ExtractionResponse
        do {
            response = try JSONDecoder().decode(ExtractionResponse.self, from: data)
        } catch {
            return .failure(.invalidStructuredOutput)
        }
        guard response.schemaVersion == CompanionExtractionPromptRegistry.schemaVersion else {
            return .failure(.invalidStructuredOutput)
        }
        var candidates: [CompanionMemoryCandidate] = []
        for (index, item) in response.candidates.enumerated() {
            guard let kind = LearningMemoryCandidate.Kind(rawValue: item.kind),
                  !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return .failure(.invalidStructuredOutput)
            }
            candidates.append(CompanionMemoryCandidate(
                id: "\(idPrefix)-\(index)",
                kind: kind,
                text: item.text,
                explanationNative: item.explanationNative,
                exampleTarget: item.exampleTarget,
                exampleNative: item.exampleNative,
                createdAt: now
            ))
        }
        return .success(candidates)
    }

    /// Strips one wrapping Markdown code fence (the only tolerated wrapper) and
    /// requires the remainder to be a single JSON document — mirroring
    /// `LearningMaterialGenerationService.jsonData(fromModelText:)`.
    private static func jsonData(fromModelText text: String) -> Data? {
        let trimmed = stripCodeFence(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let data = trimmed.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else {
            return nil
        }
        return data
    }

    private static func stripCodeFence(_ text: String) -> String {
        guard text.hasPrefix("```") else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Error mapping

    /// Maps a transport error onto the honest extraction failure vocabulary —
    /// same classification as `CompanionConversationEngine.failure(from:)` plus the
    /// extraction-specific `.invalidStructuredOutput` (raised during parsing, not here).
    static func failure(from error: Error) -> CompanionExtractionError {
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

private struct ExtractionResponse: Decodable {
    var schemaVersion: String
    var candidates: [CandidateResponse]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case candidates
    }
}

private struct CandidateResponse: Decodable {
    var kind: String
    var text: String
    var explanationNative: String
    var exampleTarget: String
    var exampleNative: String

    enum CodingKeys: String, CodingKey {
        case kind
        case text
        case explanationNative = "explanation_native"
        case exampleTarget = "example_target"
        case exampleNative = "example_native"
    }
}
