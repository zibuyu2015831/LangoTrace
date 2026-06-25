import Foundation
import GRDB
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the LM02 Slice 2 compute-on-read Style provider: per-native-language
/// grouping, target-language exclusion, the red-line that only `entries.body` is
/// read (never AI-generated text), natural cascade on entry/space delete, and
/// graceful handling of short / non-natural text. Language detection is injected
/// (a deterministic stub) so the assertions don't depend on `NaturalLanguage`.
@Suite("GRDB learner style provider")
struct GRDBLearnerStyleProviderTests {
    /// Deterministic detector: classifies a body by a closure.
    private struct StubDetector: LanguageDetector {
        let classify: @Sendable (String) -> (language: String, confidence: Double)?
        func detect(_ text: String) -> (language: String, confidence: Double)? {
            classify(text)
        }
    }

    private func makeProvider(
        detector: any LanguageDetector
    ) throws -> (GRDBLearnerStyleProvider, DatabaseQueue) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (
            GRDBLearnerStyleProvider(
                reader: database.reader,
                detector: detector,
                clock: { Date(timeIntervalSince1970: 0) }
            ),
            queue
        )
    }

    private func seedSpace(_ db: Database, id: String, native: String, target: String, deleted: Bool = false) throws {
        try db.execute(
            sql: """
            INSERT INTO language_spaces
            (id, native_language_code, target_language_code, level,
             display_name, display_name_normalized, created_at, updated_at, deleted_at)
            VALUES (?, ?, ?, 'b1', ?, ?, 0, 0, ?)
            """,
            arguments: [id, native, target, id, id, deleted ? 1.0 : nil]
        )
    }

    private func seedEntry(_ db: Database, id: String, spaceID: String, body: String, deleted: Bool = false) throws {
        try db.execute(
            sql: """
            INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
            VALUES (?, ?, 't', ?, 'typedText', 'd', 0, 0, ?)
            """,
            arguments: [id, spaceID, body, deleted ? 1.0 : nil]
        )
    }

    @Test("aggregates source-language entries into per-native-language groups (system level)")
    func aggregatesByNativeLanguageSystemLevel() throws {
        // Detector: bodies starting "ZH" → zh-Hans, "JA" → ja.
        let detector = StubDetector { text in
            if text.hasPrefix("ZH") { return ("zh-Hans", 0.99) }
            if text.hasPrefix("JA") { return ("ja", 0.99) }
            return nil
        }
        let (provider, queue) = try makeProvider(detector: detector)
        try queue.write { db in
            try seedSpace(db, id: "s1", native: "zh-Hans", target: "en")
            try seedSpace(db, id: "s2", native: "ja", target: "en")
            try seedEntry(db, id: "e1", spaceID: "s1", body: "ZH 今天我去公园散步了非常开心。")
            try seedEntry(db, id: "e2", spaceID: "s2", body: "JA 今日は公園を散歩してとても楽しかった。")
        }
        let imprint = try provider.styleImprint()
        #expect(imprint.kind == .surface)
        // System-level: both native languages present, grouped (never averaged).
        #expect(Set(imprint.groups.map(\.nativeLanguageCode)) == ["zh-Hans", "ja"])
        let zh = try #require(imprint.groups.first { $0.nativeLanguageCode == "zh-Hans" })
        #expect(zh.confidence == .high)
        #expect(zh.sampleCount == 1)
        #expect(zh.evidence.contains { $0.sourceID == "e1" && $0.sourceType == .entryBody })
    }

    @Test("target-language body is excluded from the clean source signal")
    func targetLanguageBodyExcludedViaInjectedDetector() throws {
        // The space's native is zh-Hans, target is en; this body is detected English.
        let detector = StubDetector { _ in ("en", 0.99) }
        let (provider, queue) = try makeProvider(detector: detector)
        try queue.write { db in
            try seedSpace(db, id: "s1", native: "zh-Hans", target: "en")
            try seedEntry(db, id: "e1", spaceID: "s1", body: "I went to the park today and it was very nice.")
        }
        // Detected target language → excluded → no high-confidence group.
        #expect(try provider.styleImprint().groups.isEmpty)
    }

    @Test("red line: never reads AI-generated learning text / candidates")
    func neverReadsAIGeneratedText() throws {
        let detector = StubDetector { text in text.hasPrefix("ZH") ? ("zh-Hans", 0.99) : nil }
        let (provider, queue) = try makeProvider(detector: detector)
        try queue.write { db in
            try seedSpace(db, id: "s1", native: "zh-Hans", target: "en")
            try seedEntry(db, id: "e1", spaceID: "s1", body: "ZH 今天我去公园散步了非常开心。")
            // Seed AI material text carrying a sentinel — must never be read (§4).
            try db.execute(sql: """
            INSERT INTO learning_materials
            (id, entry_id, space_id, input_kind, prompt_mode, learning_text, original_generated_text,
             analysis_source_hash, analysis_status, prompt_id, prompt_version, provider_preset_id,
             model_name, is_current, created_at, updated_at)
            VALUES ('m1', 'e1', 's1', 'nativeRecord', 'automaticLearningMaterial',
             'SENTINELAI', 'SENTINELAI', 'h', 'fresh', 'p', 'v', 'openai', 'm', 1, 0, 0)
            """)
        }
        let imprint = try provider.styleImprint()
        // The native group exists from the entry body, and no evidence points at
        // the AI material (Style only reads entries.body).
        #expect(!imprint.groups.isEmpty)
        #expect(imprint.groups.allSatisfy { $0.evidence.allSatisfy { $0.sourceID != "m1" } })
    }

    @Test("soft-deleted entry and space contribute nothing (natural cascade)")
    func deletedEntryAndSpaceCascade() throws {
        let detector = StubDetector { _ in ("zh-Hans", 0.99) }
        let (provider, queue) = try makeProvider(detector: detector)
        try queue.write { db in
            try seedSpace(db, id: "s1", native: "zh-Hans", target: "en")
            try seedSpace(db, id: "s2", native: "zh-Hans", target: "en", deleted: true)
            try seedEntry(db, id: "e1", spaceID: "s1", body: "今天我去公园散步了非常开心快乐。", deleted: true)
            try seedEntry(db, id: "e2", spaceID: "s2", body: "另一个空间的记录内容在这里写了一些。")
        }
        // e1 soft-deleted, s2 soft-deleted → both excluded.
        #expect(try provider.styleImprint().groups.isEmpty)
    }

    @Test("does not crash on short or low-confidence text; empty entries yield empty imprint")
    func neverCrashesOnShortOrNonNaturalText() throws {
        let detector = StubDetector { text in
            // Low confidence for short text.
            text.count < 8 ? ("zh-Hans", 0.2) : ("zh-Hans", 0.99)
        }
        let (provider, queue) = try makeProvider(detector: detector)
        try queue.write { db in
            try seedSpace(db, id: "s1", native: "zh-Hans", target: "en")
            try seedEntry(db, id: "e1", spaceID: "s1", body: "嗯。")
            try seedEntry(db, id: "e2", spaceID: "s1", body: "！！！")
        }
        // Short / low-confidence bodies are skipped, not crashing.
        #expect(try provider.styleImprint().groups.isEmpty)
    }

    @Test("real NaturalLanguage detector classifies a strong sample (macOS smoke)")
    func realDetectorSmoke() {
        // Covers the default NLLanguageRecognizer path; NaturalLanguage is
        // Apple-only, so this runs on the macOS runner.
        let detector = NaturalLanguageDetector()
        let result = detector.detect("The quick brown fox jumps over the lazy dog and runs across the green field.")
        #expect(result?.language.hasPrefix("en") == true)
        #expect((result?.confidence ?? 0) > 0)
    }
}
