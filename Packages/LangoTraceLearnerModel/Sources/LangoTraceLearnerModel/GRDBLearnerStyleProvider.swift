import Foundation
import GRDB

/// Computes the surface Style imprint on read from the learner's own source-language
/// `entries`, joined to `language_spaces` to know each entry's native / target
/// language (LM02-S2). Mirrors the LM01 Ability provider: `reader.read{}`, no
/// writer, no migration; entry / space deletion cascades for free via the
/// `deleted_at IS NULL` filters.
///
/// **Red line (ADR-006 §4)**: the SQL only FROM/JOINs `entries` + `language_spaces`.
/// It never reads `learning_materials` / `learning_text` / `input_kind` /
/// `memory_candidates` (AI-generated output). Language is decided by the injected
/// `LanguageDetector` over `entries.body` — `entries.source` is NOT a language key.
///
/// Source/target discipline (idea-01 §13.4/§13.5): only entries the detector
/// classifies as the space's **native** language (above a confidence threshold,
/// above a minimum length) count as clean high-confidence signal; target-language
/// bodies are excluded. Metrics are computed mechanically (deterministic) and
/// grouped **per native language** — surface metrics are not cross-language
/// comparable, so they are never arithmetic-averaged across languages.
public struct GRDBLearnerStyleProvider: LearnerStyleProvider {
    private let reader: DatabaseReader
    private let detector: any LanguageDetector
    private let clock: @Sendable () -> Date
    private let minimumBodyLength: Int
    private let confidenceThreshold: Double
    private let evidenceSampleLimit: Int

    public init(
        reader: DatabaseReader,
        detector: any LanguageDetector = NaturalLanguageDetector(),
        clock: @escaping @Sendable () -> Date = Date.init,
        minimumBodyLength: Int = 8,
        confidenceThreshold: Double = 0.5,
        evidenceSampleLimit: Int = 20
    ) {
        self.reader = reader
        self.detector = detector
        self.clock = clock
        self.minimumBodyLength = minimumBodyLength
        self.confidenceThreshold = confidenceThreshold
        self.evidenceSampleLimit = evidenceSampleLimit
    }

    public func styleImprint() throws -> StyleImprint {
        let rows = try reader.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT e.id AS id,
                       e.body AS body,
                       ls.native_language_code AS native_language_code,
                       ls.target_language_code AS target_language_code
                FROM entries e
                JOIN language_spaces ls ON e.space_id = ls.id
                WHERE e.deleted_at IS NULL
                  AND ls.deleted_at IS NULL
                ORDER BY e.created_at ASC, e.id ASC
                """
            )
        }
        return aggregate(rows: rows)
    }

    private struct Accumulator {
        var totalTokens = 0
        var distinctTokens: Set<String> = []
        var longTokens = 0
        var sentenceCount = 0
        var sampleCount = 0
        var evidence: [LearnerEvidenceRef] = []
    }

    private func aggregate(rows: [Row]) -> StyleImprint {
        var order: [String] = []
        var byNative: [String: Accumulator] = [:]

        for row in rows {
            let id: String = row["id"]
            let body: String = row["body"]
            let native: String = row["native_language_code"]
            let target: String = row["target_language_code"]
            guard body.count >= minimumBodyLength,
                  let detection = detector.detect(body),
                  detection.confidence >= confidenceThreshold
            else {
                continue
            }
            // Only the space's native language is clean high-confidence signal;
            // target-language production (or any other language) is excluded.
            guard Self.primarySubtag(detection.language) == Self.primarySubtag(native),
                  Self.primarySubtag(detection.language) != Self.primarySubtag(target)
            else {
                continue
            }
            var accumulator = byNative[native] ?? {
                order.append(native)
                return Accumulator()
            }()
            Self.accumulate(body: body, into: &accumulator)
            accumulator.sampleCount += 1
            if accumulator.evidence.count < evidenceSampleLimit {
                accumulator.evidence.append(LearnerEvidenceRef(sourceType: .entryBody, sourceID: id))
            }
            byNative[native] = accumulator
        }

        let groups = order.compactMap { native -> StyleNativeLanguageImprint? in
            guard let accumulator = byNative[native], accumulator.totalTokens > 0 else { return nil }
            let metrics = StyleSurfaceMetrics(
                averageSentenceLength: Double(accumulator.totalTokens) / Double(max(1, accumulator.sentenceCount)),
                vocabularyRichness: Double(accumulator.distinctTokens.count) / Double(accumulator.totalTokens),
                formalityTendency: Double(accumulator.longTokens) / Double(accumulator.totalTokens)
            )
            return StyleNativeLanguageImprint(
                nativeLanguageCode: native,
                metrics: metrics,
                confidence: .high,
                sampleCount: accumulator.sampleCount,
                evidence: accumulator.evidence
            )
        }
        return StyleImprint(kind: .surface, groups: groups, generatedAt: clock())
    }

    /// Mechanical tokenization (deterministic, no `NaturalLanguage`): CJK glyphs
    /// count as individual tokens; runs of letters/digits count as word tokens;
    /// sentences split on terminal punctuation.
    private static func accumulate(body: String, into accumulator: inout Accumulator) {
        var current = ""
        var sentenceHadContent = false

        func flushWord() {
            guard !current.isEmpty else { return }
            accumulator.totalTokens += 1
            accumulator.distinctTokens.insert(current.lowercased())
            if current.count >= 6 { accumulator.longTokens += 1 }
            current = ""
        }

        for scalar in body.unicodeScalars {
            let character = Character(scalar)
            if Self.isSentenceTerminator(scalar) {
                flushWord()
                if sentenceHadContent {
                    accumulator.sentenceCount += 1
                    sentenceHadContent = false
                }
            } else if Self.isCJK(scalar) {
                flushWord()
                accumulator.totalTokens += 1
                accumulator.distinctTokens.insert(String(character))
                sentenceHadContent = true
            } else if character.isLetter || character.isNumber {
                current.append(character)
                sentenceHadContent = true
            } else {
                flushWord()
            }
        }
        flushWord()
        if sentenceHadContent { accumulator.sentenceCount += 1 }
    }

    private static func isSentenceTerminator(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case ".", "!", "?", "\u{3002}", "\u{FF01}", "\u{FF1F}", "\n": // CJK full-stop / exclamation / question
            true
        default:
            false
        }
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x4E00 ... 0x9FFF, // CJK Unified Ideographs
             0x3040 ... 0x30FF, // Hiragana + Katakana
             0xAC00 ... 0xD7A3: // Hangul syllables
            true
        default:
            false
        }
    }

    private static func primarySubtag(_ code: String) -> String {
        code.split(separator: "-").first.map(String.init)?.lowercased() ?? code.lowercased()
    }
}
