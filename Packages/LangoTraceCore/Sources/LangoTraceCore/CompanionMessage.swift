import Foundation

/// Role of a persisted companion message. Only `user` / `assistant` are stored —
/// the `system` persona prompt is assembled per request from the Prompt Registry
/// (idea-03 §3.3), never persisted as a transcript row.
public enum CompanionMessageRole: String, Codable, CaseIterable, Equatable, Sendable {
    case user
    case assistant
}

/// How a user message was entered. v1 is always `text`; `voice` is a forward
/// seam so the future voice-input slice does not require a breaking migration
/// (idea-03 §3.7, see docs/architecture/notes/2026-06-25-companion-voice-input-and-engine-boundary-notes.md).
public enum CompanionInputModality: String, Codable, CaseIterable, Equatable, Sendable {
    case text
    case voice
}

/// One ordered turn in a companion thread. `sequence` is the linear position
/// (UNIQUE per thread) that makes "delete this message and everything after it"
/// well-defined (ADR-008 §4 linear-context self-consistency).
public struct CompanionMessage: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var threadID: String
    public var sequence: Int
    public var role: CompanionMessageRole
    public var content: String
    /// Locally detected language of a user message (NaturalLanguage), or nil.
    /// Only a routing hint — never overrides the always-target-language reply.
    public var detectedLanguage: String?
    public var targetLanguageCode: String
    public var inputModality: CompanionInputModality
    /// Forward seam (v1 always nil): id of an associated audio artifact.
    public var audioArtifactID: String?
    public var createdAt: Date

    public init(
        id: String,
        threadID: String,
        sequence: Int,
        role: CompanionMessageRole,
        content: String,
        detectedLanguage: String? = nil,
        targetLanguageCode: String,
        inputModality: CompanionInputModality = .text,
        audioArtifactID: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.threadID = threadID
        self.sequence = sequence
        self.role = role
        self.content = content
        self.detectedLanguage = detectedLanguage
        self.targetLanguageCode = targetLanguageCode
        self.inputModality = inputModality
        self.audioArtifactID = audioArtifactID
        self.createdAt = createdAt
    }
}

/// Pure deletion semantics for a linear companion thread (ADR-008 §4): deleting a
/// message removes that message AND every message after it, so the remaining
/// context stays self-consistent. Lives in Core so the repository and the store
/// share one definition and it can be unit-tested without a database.
public enum CompanionConversation {
    /// Returns the messages that survive after deleting `id` and all subsequent
    /// messages (by `sequence`). If `id` is not present, returns the input
    /// unchanged. The result preserves the input ordering.
    public static func messagesAfterDeleting(
        _ id: String,
        in messages: [CompanionMessage]
    ) -> [CompanionMessage] {
        guard let cutoff = messages.first(where: { $0.id == id })?.sequence else {
            return messages
        }
        return messages.filter { $0.sequence < cutoff }
    }
}
