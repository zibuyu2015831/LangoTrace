import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S2b-2 red-line regression guard (ADR-006): 方案B topic finding reads only
/// the user's own record bodies (`entries.body`); it must never touch the band,
/// AI-generated difficulty, or `learning_text`. Source-level grep that the
/// selection layer carries no band machinery + behavioural assertion that record
/// data leaves the band at the seed.
@Suite("Companion topic selection band guard")
struct CompanionTopicSelectionBandGuardTests {
    @Test("selectionSourceHasNoBandMachinery — selection layer references no band/difficulty symbols")
    func selectionSourceHasNoBandMachinery() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 4 {
            root.deleteLastPathComponent()
        } // Band → Tests-module → Tests → package root
        let source = root
            .appendingPathComponent("Sources/LangoTraceLearnerModel/CompanionTopicSelection.swift")
        let text = try String(contentsOf: source, encoding: .utf8).lowercased()
        for forbidden in ["derive(", "bandhysteresis", "learning_text", "difficulty"] {
            #expect(!text.contains(forbidden))
        }
    }

    @Test("recordSelectionDoesNotAffectBand — selecting a topic leaves the band at the seed")
    func recordSelectionDoesNotAffectBand() throws {
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
        let candidates = (0 ..< 3).map {
            CompanionTopicCandidate(id: "e\($0)", title: "t", body: "record \($0)", createdAt: Date(timeIntervalSince1970: TimeInterval($0)))
        }
        _ = CompanionTopicSelection.select(candidates: candidates)
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
        #expect(band.confidence == .low)
    }
}
