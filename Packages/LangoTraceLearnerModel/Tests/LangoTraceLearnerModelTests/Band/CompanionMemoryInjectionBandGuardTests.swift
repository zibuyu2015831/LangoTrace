import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S2b-1 red-line regression guard (ADR-006): companion Memory injection
/// reads only the user's life facts (`learner_memory_facts`); it must never touch
/// the band, AI-generated difficulty, or `learning_text`. Two-pronged: a
/// source-level grep that the selection layer carries no band machinery, and a
/// behavioural assertion that facts + chat data leave the band at the seed.
@Suite("Companion memory injection band guard")
struct CompanionMemoryInjectionBandGuardTests {
    @Test("selectionSourceHasNoBandMachinery — selection layer references no band/difficulty symbols")
    func selectionSourceHasNoBandMachinery() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 4 {
            root.deleteLastPathComponent()
        } // Band → Tests-module → Tests → package root
        let source = root
            .appendingPathComponent("Sources/LangoTraceLearnerModel/CompanionMemorySelection.swift")
        let text = try String(contentsOf: source, encoding: .utf8).lowercased()
        for forbidden in ["derive(", "bandhysteresis", "learning_text", "difficulty"] {
            #expect(!text.contains(forbidden))
        }
    }

    @Test("factsDoNotAffectBand — selecting + chat data leaves the band at the seed")
    func factsDoNotAffectBand() throws {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let blindSpots = GRDBLearnerBlindSpotProvider(reader: database.reader)
        let provider = GRDBLearnerBandProvider(
            reader: database.reader,
            blindSpotProvider: blindSpots,
            strugglingThreshold: 3
        )
        try database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO language_spaces
                (id, native_language_code, target_language_code, level,
                 display_name, display_name_normalized, created_at, updated_at)
                VALUES ('s1', 'zh-Hans', 'en', 'b1', 's1', 's1', 0, 0)
                """
            )
        }
        // Selecting memory facts does not consult the band; the band reads only
        // dictionary_lookup_events (none here) → stays at the seed.
        let facts = (0 ..< 6).map {
            MemoryFact(id: "f\($0)", kind: .lifeFact, text: "fact \($0)", createdAt: Date(timeIntervalSince1970: TimeInterval($0)))
        }
        _ = CompanionMemorySelection.select(facts: facts)
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
        #expect(band.confidence == .low)
    }
}
