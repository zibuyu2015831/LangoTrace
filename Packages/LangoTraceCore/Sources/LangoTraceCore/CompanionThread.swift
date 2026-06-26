import Foundation

/// A companion conversation container, scoped to one language space (ADR-008 §4:
/// one fixed companion identity + one thread per space, no multi-session). v1
/// keeps at most one active thread per space.
public struct CompanionThread: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var languageSpaceID: String
    /// Plan-A seed (idea-03 §3.6): the entry the user explicitly brought in via
    /// "talk about this record". Weak link — deleting the entry nulls it, the
    /// thread survives. nil for a general cold-start thread.
    public var sourceEntryID: String?
    public var createdAt: Date
    /// Per-conversation learner-profile injection toggle (LM03-S2b-1, second
    /// privacy layer). Persisted in `companion_threads.uses_learner_profile`
    /// (v32, `DEFAULT 1`). When false, no Memory is injected for this thread
    /// regardless of the global consent. Defaults to true (follow global) so a
    /// thread decoded without the column (or constructed in tests) is consistent
    /// with the DB default.
    public var usesLearnerProfile: Bool

    public init(
        id: String,
        languageSpaceID: String,
        sourceEntryID: String? = nil,
        createdAt: Date,
        usesLearnerProfile: Bool = true
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.sourceEntryID = sourceEntryID
        self.createdAt = createdAt
        self.usesLearnerProfile = usesLearnerProfile
    }

    private enum CodingKeys: String, CodingKey {
        case id, languageSpaceID, sourceEntryID, createdAt, usesLearnerProfile
    }

    /// Backward-compatible decoding: a payload encoded before the
    /// `usesLearnerProfile` field existed defaults to `true` (follow global),
    /// matching the v32 column `DEFAULT 1`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        languageSpaceID = try container.decode(String.self, forKey: .languageSpaceID)
        sourceEntryID = try container.decodeIfPresent(String.self, forKey: .sourceEntryID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        usesLearnerProfile = try container.decodeIfPresent(Bool.self, forKey: .usesLearnerProfile) ?? true
    }
}
