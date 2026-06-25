import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 3 compute-on-read blind-spot provider: aggregation by
/// language re-running `PracticeDictationDiff.compare()`, the dictation-only
/// filter, the red-line exclusion of AI judgement / learning text, the recompute
/// size bound, and natural cascade on source / space soft-delete.
@Suite("GRDB learner blind spot provider")
struct GRDBLearnerBlindSpotProviderTests {
    private func makeProvider(limit: Int = 200) throws -> (GRDBLearnerBlindSpotProvider, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (GRDBLearnerBlindSpotProvider(reader: database.reader, recomputeLimit: limit), queue)
    }

    private func seedSpace(_ db: Database, id: String, code: String, deleted: Bool = false) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at, deleted_at)
            VALUES (?, 'zh-Hans', ?, 'b1', ?, ?, 0, 0, ?)
            """,
            arguments: [id, code, id, id, deleted ? 1.0 : nil]
        )
        // Parent chain for the attempt FKs (entry → material → session), once per space.
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES (?, ?, 't', 'b', 'typedText', 'd', 0, 0)
            """,
            arguments: ["entry-\(id)", id]
        )
        try db.execute(
            sql: """
            INSERT INTO learning_materials
            (id, entry_id, space_id, input_kind, prompt_mode, learning_text, original_generated_text,
             analysis_source_hash, analysis_status, prompt_id, prompt_version, provider_preset_id,
             model_name, is_current, created_at, updated_at)
            VALUES (?, ?, ?, 'nativeRecord', 'automaticLearningMaterial', 'lt', 'og', 'h', 'fresh', 'p', 'v', 'openai', 'm', 1, 0, 0)
            """,
            arguments: ["material-\(id)", "entry-\(id)", id]
        )
        try db.execute(
            sql: """
            INSERT INTO practice_sessions
            (id, language_space_id, entry_id, learning_material_id, sentence_index,
             target_text_snapshot, target_text_hash, target_language_code, exercise_type,
             status, problem_marked, created_at, updated_at)
            VALUES (?, ?, ?, ?, 0, 'ref', 'h', ?, 'dictation', 'inProgress', 0, 0, 0)
            """,
            arguments: ["session-\(id)", id, "entry-\(id)", "material-\(id)", code]
        )
    }

    private func seedAttempt(
        _ db: Database,
        id: String,
        spaceID: String,
        attempt: String,
        reference: String,
        exerciseType: String = "dictation",
        hasDiff: Bool = true,
        createdAt: Double = 0,
        softDeleted: Bool = false,
        attemptNumber: Int = 1
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO practice_text_attempts
            (id, session_id, language_space_id, exercise_type, attempt_number, attempt_text,
             reference_text_snapshot, diff_difference_count, diff_summary_json, created_at, soft_deleted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id, "session-\(spaceID)", spaceID, exerciseType, attemptNumber, attempt, reference,
                hasDiff ? 1 : nil, hasDiff ? "{\"differenceCount\":1,\"segments\":[]}" : nil,
                createdAt, softDeleted ? 1.0 : nil,
            ]
        )
    }

    @Test("aggregates by language re-running compare to recover word text")
    func aggregatesByLanguageReRunningCompare() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en")
            // Two dictation attempts both render "their" as "there".
            try seedAttempt(db, id: "a1", spaceID: "space-en", attempt: "there is a cat", reference: "their is a cat")
            try seedAttempt(db, id: "a2", spaceID: "space-en", attempt: "there is a dog", reference: "their is a dog", createdAt: 1, attemptNumber: 2)
        }
        let spots = try provider.blindSpots(languageCode: "en")
        let changed = try #require(spots.first { $0.kind == .changed && $0.representativeText == "their" })
        #expect(changed.occurrenceCount == 2)
        #expect(changed.evidence.count == 2)
        #expect(changed.evidence.allSatisfy { $0.sourceType == .practiceTextAttempt })
    }

    @Test("backtranslation attempts (no diff) are excluded")
    func backtranslationAttemptsExcluded() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en")
            try seedAttempt(
                db, id: "bt", spaceID: "space-en", attempt: "wrong", reference: "right",
                exerciseType: "backtranslation", hasDiff: false
            )
        }
        #expect(try provider.blindSpots(languageCode: "en").isEmpty)
    }

    @Test("red line: AI candidate text and learning text never surface as blind spots")
    func redLineExcludesAICandidateAndLearningText() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en")
            try seedAttempt(db, id: "a1", spaceID: "space-en", attempt: "there cat", reference: "their cat")
            // Seed AI-only material text carrying a unique sentinel the provider must
            // never read. (memory_candidates / learning_materials are off-limits, §4.)
            try db.execute(sql: "UPDATE learning_materials SET learning_text = 'SENTINELAI zzz' WHERE id = 'material-space-en'")
        }
        let spots = try provider.blindSpots(languageCode: "en")
        #expect(spots.contains { $0.representativeText == "their" })
        #expect(!spots.contains { $0.representativeText.contains("SENTINELAI") })
    }

    @Test("recompute is bounded to the most recent N attempts")
    func recomputeBoundedToRecentNAttempts() throws {
        let (provider, queue) = try makeProvider(limit: 2)
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en")
            // Oldest attempt carries a unique error word; with LIMIT 2 it must drop.
            try seedAttempt(db, id: "old", spaceID: "space-en", attempt: "oldword", reference: "ancientword", createdAt: 0)
            try seedAttempt(db, id: "m1", spaceID: "space-en", attempt: "there a", reference: "their a", createdAt: 1, attemptNumber: 2)
            try seedAttempt(db, id: "m2", spaceID: "space-en", attempt: "there b", reference: "their b", createdAt: 2, attemptNumber: 3)
        }
        let spots = try provider.blindSpots(languageCode: "en")
        #expect(!spots.contains { $0.representativeText == "ancientword" })
        #expect(spots.contains { $0.representativeText == "their" })
    }

    @Test("soft-deleted attempt drops from blind spots (natural cascade)")
    func softDeletedAttemptDropsFromBlindSpots() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en")
            try seedAttempt(db, id: "a1", spaceID: "space-en", attempt: "there x", reference: "their x", softDeleted: true)
        }
        #expect(try provider.blindSpots(languageCode: "en").isEmpty)
    }

    @Test("soft-deleted language space contributes no blind spots")
    func softDeletedLanguageSpaceContributesNoBlindSpots() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { db in
            try seedSpace(db, id: "space-en", code: "en", deleted: true)
            try seedAttempt(db, id: "a1", spaceID: "space-en", attempt: "there y", reference: "their y")
        }
        #expect(try provider.blindSpots(languageCode: "en").isEmpty)
    }
}
