import Foundation
import GRDB
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM01 Ability knowledge-coverage aggregation: compute-on-read from
/// active deposited `memory_items` joined to `language_spaces.target_language_code`,
/// merge-by-text with occurrence counts and provenance, soft-delete cascade, cross-space
/// merge by language code, and the ADR-006 §4 red line (AI candidates never feed coverage).
///
/// Fixtures are seeded with raw SQL on a queue the test owns, so no internal Data symbols
/// are needed. The migrated schema (v26) is applied by `AppDatabase(databaseQueue:)`.
@Suite("GRDB learner context provider")
struct GRDBLearnerContextProviderTests {
    private let fixedDate = Date(timeIntervalSince1970: 1000)

    private func makeDatabase() throws -> (AppDatabase, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (database, queue)
    }

    private func insertSpace(_ db: Database, id: String, code: String, name: String) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level, display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', ?, 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, code, name, name]
        )
    }

    private func insertMemoryItem(
        _ db: Database,
        id: String,
        spaceID: String,
        kind: String,
        text: String,
        createdAt: Double,
        softDeletedAt: Double? = nil
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO memory_items
            (id, space_id, source_kind, kind, text, note, example_target, example_native, difficulty, created_at, soft_deleted_at)
            VALUES (?, ?, 'candidate', ?, ?, 'n', 'e', 'en', 'medium', ?, ?)
            """,
            arguments: [id, spaceID, kind, text, createdAt, softDeletedAt]
        )
    }

    @Test("aggregates deposited items by language code, merging duplicate texts")
    func aggregatesByLanguageCode() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en", code: "en", name: "English")
            try insertMemoryItem(db, id: "m1", spaceID: "s-en", kind: "wordPhrase", text: "croissant", createdAt: 1)
            try insertMemoryItem(db, id: "m2", spaceID: "s-en", kind: "wordPhrase", text: "croissant", createdAt: 2)
            try insertMemoryItem(db, id: "m3", spaceID: "s-en", kind: "sentence", text: "I ate a croissant.", createdAt: 3)
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        let coverage = try provider.abilityCoverage(languageCode: "en")

        #expect(coverage.languageCode == "en")
        #expect(coverage.generatedAt == fixedDate)
        #expect(coverage.entries.map(\.text) == ["croissant", "I ate a croissant."])
        let croissant = coverage.entries.first { $0.text == "croissant" }
        #expect(croissant?.kind == .wordPhrase)
        #expect(croissant?.occurrenceCount == 2)
        #expect(croissant?.evidence.map(\.sourceID) == ["m1", "m2"])
        #expect(croissant?.evidence.allSatisfy { $0.sourceType == .memoryItem } == true)
    }

    @Test("two spaces of the same language merge into one coverage; renaming a space does not split it")
    func crossSpaceMergeByCode() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en-1", code: "en", name: "English A")
            try insertSpace(db, id: "s-en-2", code: "en", name: "English B")
            try insertMemoryItem(db, id: "m1", spaceID: "s-en-1", kind: "wordPhrase", text: "apple", createdAt: 1)
            try insertMemoryItem(db, id: "m2", spaceID: "s-en-2", kind: "wordPhrase", text: "apple", createdAt: 2)
            try insertMemoryItem(db, id: "m3", spaceID: "s-en-2", kind: "wordPhrase", text: "pear", createdAt: 3)
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        let coverage = try provider.abilityCoverage(languageCode: "en")

        #expect(coverage.entries.map(\.text) == ["apple", "pear"])
        #expect(coverage.entries.first { $0.text == "apple" }?.occurrenceCount == 2)
    }

    @Test("a different language's deposits are not counted")
    func otherLanguageExcluded() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en", code: "en", name: "English")
            try insertSpace(db, id: "s-ja", code: "ja", name: "Japanese")
            try insertMemoryItem(db, id: "m1", spaceID: "s-en", kind: "wordPhrase", text: "apple", createdAt: 1)
            try insertMemoryItem(db, id: "m2", spaceID: "s-ja", kind: "wordPhrase", text: "りんご", createdAt: 2)
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        #expect(try provider.abilityCoverage(languageCode: "en").entries.map(\.text) == ["apple"])
        #expect(try provider.abilityCoverage(languageCode: "ja").entries.map(\.text) == ["りんご"])
    }

    @Test("soft-deleted items drop out; a sibling space still contributes")
    func softDeleteCascades() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en-1", code: "en", name: "English A")
            try insertSpace(db, id: "s-en-2", code: "en", name: "English B")
            try insertMemoryItem(db, id: "m1", spaceID: "s-en-1", kind: "wordPhrase", text: "apple", createdAt: 1, softDeletedAt: 50)
            try insertMemoryItem(db, id: "m2", spaceID: "s-en-2", kind: "wordPhrase", text: "pear", createdAt: 2)
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        #expect(try provider.abilityCoverage(languageCode: "en").entries.map(\.text) == ["pear"])
    }

    @Test("a soft-deleted language space contributes nothing")
    func softDeletedSpaceExcluded() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en", code: "en", name: "English")
            try db.execute(sql: "UPDATE language_spaces SET deleted_at = 50 WHERE id = 's-en'")
            try insertMemoryItem(db, id: "m1", spaceID: "s-en", kind: "wordPhrase", text: "apple", createdAt: 1)
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        #expect(try provider.abilityCoverage(languageCode: "en").entries.isEmpty)
    }

    @Test("an empty language returns empty coverage, not an error")
    func emptyCoverage() throws {
        let (database, _) = try makeDatabase()
        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        let coverage = try provider.abilityCoverage(languageCode: "en")
        #expect(coverage.entries.isEmpty)
        #expect(coverage.languageCode == "en")
    }

    /// ADR-006 §4 red line: an AI candidate that was never deposited must not appear in
    /// coverage. We seed the full candidate chain (entry → material → candidate) for a
    /// knowledge point that is NEVER deposited, alongside one that IS deposited, and assert
    /// only the deposited text surfaces.
    @Test("an undeposited AI candidate never appears in coverage")
    func undepositedCandidateExcluded() throws {
        let (database, queue) = try makeDatabase()
        try queue.write { db in
            try insertSpace(db, id: "s-en", code: "en", name: "English")
            try db.execute(
                sql: """
                INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
                VALUES ('e1', 's-en', 'T', 'B', 'typedText', 'life', 0, 0)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO learning_materials
                (id, entry_id, space_id, input_kind, prompt_mode, learning_text, original_generated_text,
                 analysis_source_hash, analysis_status, prompt_id, prompt_version, provider_preset_id,
                 model_name, is_current, created_at, updated_at)
                VALUES ('lm1', 'e1', 's-en', 'nativeRecord', 'automaticLearningMaterial', 'L', 'O', 'h', 'fresh',
                 'p', 'v', 'preset', 'model', 1, 0, 0)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO memory_candidates
                (id, space_id, entry_id, material_id, kind, text, explanation_native, example_target,
                 example_native, difficulty, status, created_at, updated_at)
                VALUES ('c1', 's-en', 'e1', 'lm1', 'word', 'candidate-only-word', 'x', 'e', 'n',
                 'medium', 'candidate', 0, 0)
                """
            )
            // The only deposited knowledge point:
            try insertMemoryItem(
                db, id: "m1", spaceID: "s-en", kind: "wordPhrase", text: "deposited-word", createdAt: 1
            )
        }

        let provider = GRDBLearnerContextProvider(reader: database.reader, clock: { fixedDate })
        let texts = try provider.abilityCoverage(languageCode: "en").entries.map(\.text)
        #expect(texts == ["deposited-word"])
        #expect(!texts.contains("candidate-only-word"))
    }
}
