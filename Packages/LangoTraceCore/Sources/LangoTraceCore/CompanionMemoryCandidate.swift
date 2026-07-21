import Foundation

/// A vocabulary / expression candidate extracted from a Language Companion
/// conversation (LM03-S2a, the inbound "chat-reflux" half of the record → chat →
/// memory loop, idea-03 §3.8).
///
/// It deliberately reuses `LearningMemoryCandidate.Kind` rather than minting a new
/// kind vocabulary: chat-sourced and learning-material-sourced candidates share
/// the same review semantics, so a future deposit pipeline (plan 10/11) can merge
/// the two onto one review surface (plan §D1). It is persisted in its own
/// `companion_memory_candidates` table (not `memory_candidates`, whose
/// `entry_id` / `material_id` are NOT NULL) — physical isolation, pipeline-level
/// reuse (plan §D1).
///
/// Like `memory_candidates`, a candidate is **recomputable derived data**: it is a
/// review staging row, not main data. Main-data status is reached only when the
/// user promotes it to a memory item (`learner_memory_facts`, plan 10/11). Deleting
/// the thread cascade-deletes its candidates; deleting the single source message
/// nulls `messageID` (the weak reference) but keeps the candidate (plan §D4 / §ADR-008 §4).
public struct CompanionMemoryCandidate: Equatable, Identifiable, Sendable {
    public var id: String
    /// Weak reference to the companion message this candidate was anchored to.
    /// `nil` once that message is deleted (DB `ON DELETE SET NULL`) — the candidate
    /// itself survives, and the UI shows a "source message deleted" state.
    public var messageID: String?
    public var kind: LearningMemoryCandidate.Kind
    public var text: String
    public var explanationNative: String
    public var exampleTarget: String
    public var exampleNative: String
    public var createdAt: Date

    public init(
        id: String,
        messageID: String? = nil,
        kind: LearningMemoryCandidate.Kind,
        text: String,
        explanationNative: String,
        exampleTarget: String,
        exampleNative: String,
        createdAt: Date
    ) {
        self.id = id
        self.messageID = messageID
        self.kind = kind
        self.text = text
        self.explanationNative = explanationNative
        self.exampleTarget = exampleTarget
        self.exampleNative = exampleNative
        self.createdAt = createdAt
    }
}
