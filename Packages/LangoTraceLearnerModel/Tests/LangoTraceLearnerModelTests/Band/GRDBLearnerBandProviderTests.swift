import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02-S4b band re-estimation (highest-risk slice): it builds the
/// band from **independent behaviour signals** (userAuthored lookups + recurring
/// errors), excludes AI-generated-source lookups, never reads AI difficulty, and
/// never overwrites the user-visible `LanguageLevel`.
@Suite("GRDB learner band provider")
struct GRDBLearnerBandProviderTests {
    private func makeProvider(strugglingThreshold: Int = 3) throws -> (GRDBLearnerBandProvider, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let blindSpots = GRDBLearnerBlindSpotProvider(reader: database.reader)
        let provider = GRDBLearnerBandProvider(
            reader: database.reader,
            blindSpotProvider: blindSpots,
            strugglingThreshold: strugglingThreshold
        )
        return (provider, queue)
    }

    private func seedSpace(_ db: Database, id: String, target: String = "en") throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at)
            VALUES (?, 'zh-Hans', ?, 'b1', ?, ?, 0, 0)
            """,
            arguments: [id, target, id, id]
        )
    }

    private func seedLookup(_ db: Database, id: String, space: String, origin: String = "userAuthored") throws {
        try db.execute(
            sql: """
            INSERT INTO dictionary_lookup_events
            (id, language_space_id, looked_up_term, source_content_id, source_content_origin,
             sync_policy, backup_policy, export_policy, occurred_at)
            VALUES (?, ?, 'term', 'doc', ?, 'localOnly', 'excludedFromSystemBackup', 'excludedByDefault', 0)
            """,
            arguments: [id, space, origin]
        )
    }

    @Test("a low struggling signal keeps the band at the seed, low confidence")
    func lowSignalKeepsSeedBand() throws {
        let (provider, queue) = try makeProvider()
        try queue.write { try seedSpace($0, id: "s1") }
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
        #expect(band.confidence == .low)
        #expect(band.languageCode == "en")
    }

    @Test("a strong struggling signal nudges the band down one level (more support)")
    func strongSignalNudgesBandDown() throws {
        let (provider, queue) = try makeProvider(strugglingThreshold: 3)
        try queue.write { db in
            try seedSpace(db, id: "s1")
            try seedLookup(db, id: "l1", space: "s1")
            try seedLookup(db, id: "l2", space: "s1")
            try seedLookup(db, id: "l3", space: "s1")
        }
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .a2) // one level down from B1
    }

    @Test("AI-generated-source lookups are excluded from the band signal")
    func bandExcludesAIGeneratedSourceLookups() throws {
        let (provider, queue) = try makeProvider(strugglingThreshold: 3)
        try queue.write { db in
            try seedSpace(db, id: "s1")
            // Three aiGenerated lookups must NOT count toward struggling.
            try seedLookup(db, id: "a1", space: "s1", origin: "aiGenerated")
            try seedLookup(db, id: "a2", space: "s1", origin: "aiGenerated")
            try seedLookup(db, id: "a3", space: "s1", origin: "aiGenerated")
        }
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1) // aiGenerated excluded → low signal → seed
    }

    @Test("band computation never reads AI-generated difficulty / learning text")
    func bandComputationNeverReadsAIDifficulty() throws {
        let (provider, queue) = try makeProvider(strugglingThreshold: 3)
        try queue.write { db in
            try seedSpace(db, id: "s1")
            try db.execute(sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at)
            VALUES ('e1', 's1', 't', 'b', 'typedText', 'd', 0, 0)
            """)
            // AI difficulty / learning text carrying a sentinel — must not affect band.
            try db.execute(sql: """
            INSERT INTO learning_materials
            (id, entry_id, space_id, input_kind, prompt_mode, learning_text, original_generated_text,
             analysis_source_hash, analysis_status, prompt_id, prompt_version, provider_preset_id,
             model_name, is_current, created_at, updated_at)
            VALUES ('m1', 'e1', 's1', 'nativeRecord', 'automaticLearningMaterial', 'SENTINELAI', 'SENTINELAI',
             'h', 'fresh', 'p', 'v', 'openai', 'm', 1, 0, 0)
            """)
        }
        // No lookups / blind spots → seed band, unaffected by the AI material.
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
    }

    @Test("band never overwrites the user-visible LanguageLevel label")
    func bandNeverOverwritesUserLanguageLevel() throws {
        let (provider, queue) = try makeProvider(strugglingThreshold: 1)
        try queue.write { db in
            try seedSpace(db, id: "s1")
            try seedLookup(db, id: "l1", space: "s1")
        }
        _ = try provider.band(languageCode: "en", seedLevel: .b1)
        // The stored label is untouched by band estimation.
        let storedLevel = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT level FROM language_spaces WHERE id = 's1'")
        }
        #expect(storedLevel == "b1")
    }
}
