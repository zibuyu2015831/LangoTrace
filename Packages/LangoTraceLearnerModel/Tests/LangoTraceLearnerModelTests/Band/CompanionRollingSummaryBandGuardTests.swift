import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S3b-1 red-line regression guard (ADR-006): the companion rolling summary
/// summarizes only the conversation's own messages — it must never touch the band,
/// AI-generated difficulty, or `learning_text`. Two-pronged: a source-level grep
/// that the summary-specific sources carry no band machinery, and a behavioural
/// assertion that conversation + summary data leaves the band at the seed.
@Suite("Companion rolling summary band guard")
struct CompanionRollingSummaryBandGuardTests {
    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        // Band → Tests-module → Tests → package root → Packages → repo root.
        for _ in 0 ..< 6 {
            root.deleteLastPathComponent()
        }
        return root
    }

    @Test("summarySourcesHaveNoBandMachinery — summary-specific sources reference no band/difficulty symbols")
    func summarySourcesHaveNoBandMachinery() throws {
        let sources = [
            "Packages/LangoTraceCore/Sources/LangoTraceCore/CompanionRollingSummary.swift",
            "Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionSummarizationPromptRegistry.swift",
        ]
        for relativePath in sources {
            let url = repoRoot().appendingPathComponent(relativePath)
            let text = try String(contentsOf: url, encoding: .utf8).lowercased()
            for forbidden in ["derive(", "bandhysteresis", "learning_text", "difficulty"] {
                #expect(!text.contains(forbidden), "\(relativePath) contains forbidden token \(forbidden)")
            }
        }
    }

    @Test("conversationDataDoesNotAffectBand — inserting messages + a summary leaves the band at the seed")
    func conversationDataDoesNotAffectBand() throws {
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
        // Seed a conversation with messages and a rolling summary; the band reads
        // only dictionary_lookup_events (none here), so it stays at the seed.
        let repository = GRDBCompanionRepository(writer: database.writer)
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        for index in 0 ..< 6 {
            _ = try repository.appendMessage(
                threadID: thread.id, role: .user, content: "m\(index)", targetLanguageCode: "en"
            )
        }
        try repository.updateRollingSummary(threadID: thread.id, text: "earlier recap", coversThroughSequence: 3)

        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
        #expect(band.confidence == .low)
    }
}
