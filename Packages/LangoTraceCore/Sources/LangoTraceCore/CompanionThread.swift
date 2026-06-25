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

    public init(
        id: String,
        languageSpaceID: String,
        sourceEntryID: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.languageSpaceID = languageSpaceID
        self.sourceEntryID = sourceEntryID
        self.createdAt = createdAt
    }
}
