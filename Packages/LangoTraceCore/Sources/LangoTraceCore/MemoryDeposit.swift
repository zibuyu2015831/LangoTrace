import Foundation

/// Deposit "kind" of a memory item (E7). Coarser than the five analysis
/// candidate kinds: word/phrase deposits become `wordPhrase`; sentence-level
/// candidates (pattern, grammar point, error pattern) become `sentence`.
public enum MemoryItemKind: String, Codable, CaseIterable, Equatable, Sendable {
    case wordPhrase
    case sentence

    /// Maps the analysis candidate kind onto the deposit kind.
    public init(_ candidateKind: LearningMemoryCandidate.Kind) {
        switch candidateKind {
        case .word, .phrase:
            self = .wordPhrase
        case .sentencePattern, .grammarPoint, .errorPattern:
            self = .sentence
        }
    }
}

/// Spaced-review lifecycle state of a deposited memory item. Consumed by E8's
/// review queue (which adds no schema — these columns are E7's contract).
public enum MemoryReviewState: String, Codable, CaseIterable, Equatable, Sendable {
    case new
    case scheduled
    case mastered
}

/// Source a memory item was deposited from. v1 supports candidate deposits;
/// reading-selection deposits are deferred until that source has an identity
/// key for idempotency.
public enum MemoryItemSourceKind: String, Codable, CaseIterable, Equatable, Sendable {
    case candidate
}

/// Input to deposit a memory item from an analysis candidate (E7). The deposit
/// snapshots the candidate's text/example so it survives candidate reanalysis
/// (which CASCADE-deletes `memory_candidates`).
public struct MemoryDepositInput: Equatable, Sendable {
    public var spaceID: String
    public var entryID: String
    public var sourceCandidateID: String
    public var kind: MemoryItemKind
    public var text: String
    public var note: String
    public var exampleTarget: String
    public var exampleNative: String
    public var difficulty: LearningMemoryCandidate.Difficulty

    public init(
        spaceID: String,
        entryID: String,
        sourceCandidateID: String,
        kind: MemoryItemKind,
        text: String,
        note: String,
        exampleTarget: String,
        exampleNative: String,
        difficulty: LearningMemoryCandidate.Difficulty
    ) {
        self.spaceID = spaceID
        self.entryID = entryID
        self.sourceCandidateID = sourceCandidateID
        self.kind = kind
        self.text = text
        self.note = note
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.difficulty = difficulty
    }

    /// Builds a deposit input from an analysis candidate plus its owning entry.
    public init(candidate: LearningMemoryCandidate, spaceID: String, entryID: String) {
        self.init(
            spaceID: spaceID,
            entryID: entryID,
            sourceCandidateID: candidate.id,
            kind: MemoryItemKind(candidate.kind),
            text: candidate.text,
            note: candidate.explanationNative,
            exampleTarget: candidate.exampleTarget,
            exampleNative: candidate.exampleNative,
            difficulty: candidate.difficulty
        )
    }
}

/// A deposited memory item — user main data (spec 007 §3.1.1), owned by a
/// language space (ADR-004), snapshotted from its source so it survives source
/// reanalysis. Carries the spaced-review lifecycle columns E8 consumes.
public struct DepositedMemoryItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var spaceID: String
    public var entryID: String?
    public var sourceKind: MemoryItemSourceKind
    public var sourceCandidateID: String?
    public var kind: MemoryItemKind
    public var text: String
    public var note: String
    public var exampleTarget: String
    public var exampleNative: String
    public var difficulty: LearningMemoryCandidate.Difficulty
    public var reviewState: MemoryReviewState
    public var reviewRung: Int
    public var reviewDueAt: Date?
    public var lastReviewedAt: Date?
    public var reviewCount: Int
    public var masteredAt: Date?
    public var createdAt: Date

    public init(
        id: String,
        spaceID: String,
        entryID: String?,
        sourceKind: MemoryItemSourceKind,
        sourceCandidateID: String?,
        kind: MemoryItemKind,
        text: String,
        note: String,
        exampleTarget: String,
        exampleNative: String,
        difficulty: LearningMemoryCandidate.Difficulty,
        reviewState: MemoryReviewState = .new,
        reviewRung: Int = 0,
        reviewDueAt: Date? = nil,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0,
        masteredAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.spaceID = spaceID
        self.entryID = entryID
        self.sourceKind = sourceKind
        self.sourceCandidateID = sourceCandidateID
        self.kind = kind
        self.text = text
        self.note = note
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.difficulty = difficulty
        self.reviewState = reviewState
        self.reviewRung = reviewRung
        self.reviewDueAt = reviewDueAt
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
        self.masteredAt = masteredAt
        self.createdAt = createdAt
    }
}

/// Persistence boundary for deposited memory items (E7). Deposits are idempotent
/// per source candidate; reads exclude soft-deleted rows.
public protocol MemoryItemRepository: Sendable {
    /// Deposits a memory item; if the source candidate was already deposited,
    /// returns the existing item (idempotent).
    func deposit(_ input: MemoryDepositInput) async throws -> DepositedMemoryItem
    func listMemoryItems(spaceID: String) async throws -> [DepositedMemoryItem]
    /// Source-candidate ids already deposited in a space (for the "已加入" state).
    func depositedCandidateIDs(spaceID: String) async throws -> Set<String>
    /// Entry ids that have at least one deposited memory item (drives the
    /// `settled` timeline filter).
    func depositedEntryIDs(spaceID: String) async throws -> Set<String>
    func softDelete(id: String) async throws
}
