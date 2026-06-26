import Foundation

/// A candidate record the companion may bring in as a conversation topic
/// (LM03-S2b-2 方案B). Pure value type sourced from `entries` (id + title + the
/// raw `entries.body`, never FTS-folded text that mixes in AI-generated
/// `learning_text`). The body is the user's own record text only.
public struct CompanionTopicCandidate: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let body: String
    public let createdAt: Date

    public init(id: String, title: String, body: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
