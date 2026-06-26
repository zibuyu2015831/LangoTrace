import Foundation
import GRDB

extension AppDatabase {
    /// `companion_threads.rolling_summary` + watermark (LM03-S3b-1, v33): the
    /// rolling conversation summary ("对话记忆") that keeps a long companion
    /// conversation grounded without re-sending the whole transcript.
    ///
    /// Three nullable columns added to the existing `companion_threads` row
    /// (one thread per space, so a 1:1 cache lives naturally on the row — no join):
    ///
    /// - `rolling_summary`           — the summary text (null = none / invalidated)
    /// - `summary_covers_through_sequence` — watermark: the summary folds every
    ///   message with `sequence <= this`. This is what makes the delete-and-after
    ///   invalidation rule decidable (idea-03 §3.2).
    /// - `summary_updated_at`        — when it was last (re)built.
    ///
    /// `ADD COLUMN` with no default leaves every existing v30 thread at NULL (no
    /// summary yet), which is safe. The summary is a **derived cache** over
    /// `companion_messages`: it rides the thread row's existing backup/export lane
    /// (it cannot be column-excluded, and is harmless on restore — regenerable and
    /// consistent with the co-backed-up messages its watermark references) and is
    /// not synced (`companion_threads` is local-only). No `summary_fingerprint`:
    /// v1 invalidates then re-summarizes (simple + correct); a fingerprint
    /// ("skip rebuild when unchanged") is a deferred v2 optimization.
    static func createCompanionRollingSummaryInfrastructure(_ db: Database) throws {
        try db.execute(sql: "ALTER TABLE companion_threads ADD COLUMN rolling_summary TEXT")
        try db.execute(sql: "ALTER TABLE companion_threads ADD COLUMN summary_covers_through_sequence INTEGER")
        try db.execute(sql: "ALTER TABLE companion_threads ADD COLUMN summary_updated_at REAL")
    }
}
