import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S4a red-line regression guard (ADR-006 §10): Style injection reads the
/// Ability band only to set the i+1 complexity ceiling — it must never touch the
/// band derive/write path, AI-generated difficulty, or `learning_text`.
/// Two-pronged: a source-level grep that the S4a-specific sources carry no band
/// machinery, and a behavioural assertion that the band stays at the seed.
@Suite("Companion style projection band guard")
struct CompanionStyleProjectionBandGuardTests {
    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        // Band → Tests-module → Tests → package root → Packages → repo root.
        for _ in 0 ..< 6 {
            root.deleteLastPathComponent()
        }
        return root
    }

    @Test("styleSourcesHaveNoBandMachinery — the projection + descriptor reference no band/difficulty write symbols")
    func styleSourcesHaveNoBandMachinery() throws {
        let sources = [
            "Packages/LangoTraceLearnerModel/Sources/LangoTraceLearnerModel/CompanionStyleProjection.swift",
            "Packages/LangoTraceCore/Sources/LangoTraceCore/CompanionStyleDescriptor.swift",
        ]
        for relativePath in sources {
            let url = repoRoot().appendingPathComponent(relativePath)
            let text = try String(contentsOf: url, encoding: .utf8).lowercased()
            for forbidden in ["derive(", "bandhysteresis", "learning_text", "difficulty"] {
                #expect(!text.contains(forbidden), "\(relativePath) contains forbidden token \(forbidden)")
            }
        }
    }

    @Test("styleProjectionReadsBandWithoutMoving — projecting style leaves the band at the seed")
    func styleProjectionReadsBandWithoutMoving() throws {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let provider = GRDBLearnerBandProvider(
            reader: database.reader,
            blindSpotProvider: GRDBLearnerBlindSpotProvider(reader: database.reader),
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
        // Reading the band for the ceiling and projecting style does not write or
        // move the band — it only reads dictionary_lookup_events (none here).
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        let imprint = StyleImprint(
            kind: .surface,
            groups: [
                StyleNativeLanguageImprint(
                    nativeLanguageCode: "zh-Hans",
                    metrics: StyleSurfaceMetrics(
                        averageSentenceLength: 18, vocabularyRichness: 0.7, formalityTendency: 0.8
                    ),
                    confidence: .high,
                    sampleCount: 8,
                    evidence: []
                ),
            ],
            generatedAt: Date(timeIntervalSince1970: 0)
        )
        let descriptor = CompanionStyleProjection.project(
            imprint: imprint, nativeLanguageCode: "zh-Hans", band: band
        )
        #expect(descriptor?.complexityCeiling == .b1)
        // Re-reading the band still returns the seed: projection never moved it.
        #expect(try provider.band(languageCode: "en", seedLevel: .b1).estimatedLevel == .b1)
    }
}
