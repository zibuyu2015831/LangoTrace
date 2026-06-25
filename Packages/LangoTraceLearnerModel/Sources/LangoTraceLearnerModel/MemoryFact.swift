import Foundation

/// Category of a Memory-layer fact (ADR-006 §2 / idea-01 §13.1). Closed v1 set:
/// life facts, preferences, learning goals, and relationships — the kinds a user
/// would explicitly tell the App to remember about their life.
public enum MemoryFactKind: String, CaseIterable, Sendable, Equatable {
    case lifeFact
    case preference
    case goal
    case relationship
}

/// Who may see a Memory fact (idea-01 §12.5).
///
/// - `global`: overview-visible and future-companion usable. The v1 default for
///   **explicitly saved** facts — the user actively told the App, so the冷启动
///   红利 applies (ADR-006 §3).
/// - `companionOnly`: reserved for v2 auto-extraction, where the conservative
///   default is to keep an inferred fact out of the overview until corroborated.
public enum MemoryFactVisibility: String, CaseIterable, Sendable, Equatable {
    case global
    case companionOnly
}

/// A system-level (cross-language-space) Memory fact the user explicitly asked
/// the App to remember (ADR-006 §3). Pure value type; persistence is owned by
/// `GRDBLearnerMemoryRepository`, the storage policy invariants (local-only,
/// included-in-backup, included-in-recoverable-backup) live in the schema.
///
/// v1 has **no auto-extraction**: every fact originates from an explicit user
/// action, so `source` defaults to `.manualMemory`.
public struct MemoryFact: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: MemoryFactKind
    public let text: String
    /// Reserved ranking weight for future companion Memory injection (LM03). v1
    /// stores it but does not rank on it.
    public let salience: Int
    public let visibility: MemoryFactVisibility
    public let source: LearnerSourceType
    /// Optional weak link to the entry the user was looking at when they saved
    /// the fact. `ON DELETE SET NULL` in storage — a fact outlives its source.
    public let sourceEntryID: String?
    public let createdAt: Date
    public let softDeletedAt: Date?

    public init(
        id: String,
        kind: MemoryFactKind,
        text: String,
        salience: Int = 0,
        visibility: MemoryFactVisibility = .global,
        source: LearnerSourceType = .manualMemory,
        sourceEntryID: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        softDeletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.salience = salience
        self.visibility = visibility
        self.source = source
        self.sourceEntryID = sourceEntryID
        self.createdAt = createdAt
        self.softDeletedAt = softDeletedAt
    }

    /// Provenance reference (ADR-006 §9), derived from the weak source-entry link.
    /// `nil` when the fact has no recorded source entry.
    public var evidence: LearnerEvidenceRef? {
        guard let sourceEntryID else { return nil }
        return LearnerEvidenceRef(sourceType: source, sourceID: sourceEntryID)
    }
}
