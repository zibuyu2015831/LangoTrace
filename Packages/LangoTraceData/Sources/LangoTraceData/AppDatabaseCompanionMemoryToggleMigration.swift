import Foundation
import GRDB

extension AppDatabase {
    /// `companion_threads.uses_learner_profile` (LM03-S2b-1, v32): the
    /// per-conversation learner-profile injection toggle — the second of the two
    /// privacy layers gating Memory injection (the first is the global one-time
    /// consent in `UserDefaults`).
    ///
    /// `INTEGER NOT NULL DEFAULT 1` so every existing thread defaults to "follow
    /// the global consent" (matching `CompanionThread.usesLearnerProfile`'s `true`
    /// default). When 0, no Memory is injected for that thread regardless of the
    /// global consent. This is a per-conversation preference, not derived data, so
    /// it rides the thread's existing sync/backup/export policy (the column lives
    /// on `companion_threads`, which is already local-only + recoverable).
    static func createCompanionMemoryToggleInfrastructure(_ db: Database) throws {
        try db.execute(sql: """
        ALTER TABLE companion_threads
        ADD COLUMN uses_learner_profile INTEGER NOT NULL DEFAULT 1
        """)
    }
}
