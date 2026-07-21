import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// LM03-S2a red-line regression guard (plan §复查方法 / round-1 P1-2): the chat
/// reflux slice must NOT let companion data feed the band. Production utterances
/// are a *positive / fluency* signal; the band models only the *struggling*
/// (negative) signal, and wiring production into the struggling aggregate would be
/// semantically wrong (speaking more ≠ struggling more). S2a ships only a forward
/// read seam, so the band must stay byte-for-byte source-clean of `companion` and
/// behaviourally unaffected by chat rows.
@Suite("Companion reflux band guard")
struct CompanionRefluxBandGuardTests {
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

    /// Source-level guard: the band provider source never references `companion`.
    @Test("bandProviderSourceUnchangedNoCompanionJoin — source has no companion reference")
    func bandProviderSourceHasNoCompanionReference() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 4 {
            root.deleteLastPathComponent()
        } // Band → Tests-module → Tests → package root
        let source = root
            .appendingPathComponent("Sources/LangoTraceLearnerModel/GRDBLearnerBandProvider.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        #expect(!text.lowercased().contains("companion"))
    }

    /// Behavioural guard: inserting companion messages + candidates (which would
    /// look like a high "production" signal) leaves the band at the seed, because
    /// the band reads only `dictionary_lookup_events`, never companion tables.
    @Test("companionRowsDoNotAffectBand — band stays at seed with only chat data")
    func companionRowsDoNotAffectBand() throws {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        let blindSpots = GRDBLearnerBlindSpotProvider(reader: database.reader)
        let provider = GRDBLearnerBandProvider(
            reader: database.reader,
            blindSpotProvider: blindSpots,
            strugglingThreshold: 3
        )
        let repository = GRDBCompanionRepository(writer: database.writer)
        try database.writer.write { try seedSpace($0, id: "s1") }
        let thread = try repository.loadOrCreateThread(spaceID: "s1", id: "t1")
        for index in 0 ..< 5 {
            let message = try repository.appendMessage(
                threadID: thread.id, role: .user, content: "utterance \(index)",
                detectedLanguage: "en", targetLanguageCode: "en", id: "m\(index)"
            )
            try repository.appendCompanionCandidates(
                threadID: thread.id, messageID: message.id,
                candidates: [
                    CompanionMemoryCandidate(
                        id: "c\(index)", kind: .word, text: "w\(index)",
                        explanationNative: "n", exampleTarget: "t", exampleNative: "v",
                        createdAt: Date(timeIntervalSince1970: Double(index))
                    ),
                ]
            )
        }
        // No dictionary lookups at all → band must remain the seed, low confidence.
        let band = try provider.band(languageCode: "en", seedLevel: .b1)
        #expect(band.estimatedLevel == .b1)
        #expect(band.confidence == .low)
    }
}
