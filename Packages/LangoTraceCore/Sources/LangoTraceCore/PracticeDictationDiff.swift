import Foundation

/// Pure, local-only string comparison for dictation practice (听写本机对照).
///
/// The diff models the **acoustic / lexical layer** of a dictation attempt
/// (see plan `2026-06-11-07` decision E4-D1): spelling, word form, homophones
/// (`its` / `it's`), and inserted / omitted words each count as one
/// difference. The **orthographic layer** — letter case and standalone
/// punctuation, which are not present in the audio signal — does not count and
/// is stripped during normalization, so both the difference count and the
/// rendered display ignore punctuation.
///
/// All scanning works at `Character` (grapheme cluster) granularity using Swift
/// `String` / `Character` APIs — never UTF-16 offsets — so emoji, CJK, and
/// combining marks are safe (same convention as the reading per-block notes).
/// Difference segment ranges are expressed as half-open `Character` offset
/// ranges into ``Result/renderedAttempt`` for `AttributedString` rendering.
public enum PracticeDictationDiff {
    /// Maximum accepted input length, in `Character` count, per side. Bounds the
    /// worst-case O(n²) LCS so a pathological paste cannot stall the app.
    public static let maxInputLength = 2000

    public enum Failure: Error, Hashable, Sendable {
        case inputTooLong
    }

    /// Classification of a single difference segment.
    public enum SegmentKind: String, Hashable, Sendable {
        /// Reference has a word the attempt omitted.
        case missing
        /// Attempt has a word not present in the reference.
        case extra
        /// Attempt has a word at this position but it differs from the reference.
        case changed
    }

    public struct Segment: Hashable, Sendable {
        public var kind: SegmentKind
        /// Half-open `Character` offset range into ``Result/renderedAttempt``.
        /// For ``SegmentKind/missing`` this is a zero-length insertion point.
        public var range: Range<Int>
        /// The attempt word at this segment (empty for ``SegmentKind/missing``).
        public var attemptText: String
        /// The reference word for ``SegmentKind/missing`` / ``SegmentKind/changed``;
        /// `nil` for ``SegmentKind/extra``.
        public var referenceText: String?

        public init(kind: SegmentKind, range: Range<Int>, attemptText: String, referenceText: String?) {
            self.kind = kind
            self.range = range
            self.attemptText = attemptText
            self.referenceText = referenceText
        }
    }

    public struct Result: Hashable, Sendable {
        /// Number of acoustic/lexical differences (see type docs).
        public var differenceCount: Int
        public var segments: [Segment]
        /// Normalized, punctuation-stripped attempt text for display; segment
        /// ranges index into this string.
        public var renderedAttempt: String

        public init(differenceCount: Int, segments: [Segment], renderedAttempt: String) {
            self.differenceCount = differenceCount
            self.segments = segments
            self.renderedAttempt = renderedAttempt
        }

        /// Persistable summary holding only difference count and segment
        /// classification + ranges (no derived text slices — recomputed at render).
        public var summary: PracticeDictationDiffSummary {
            PracticeDictationDiffSummary(
                differenceCount: differenceCount,
                segments: segments.map {
                    PracticeDictationDiffSummary.Segment(
                        kind: $0.kind.rawValue,
                        lowerBound: $0.range.lowerBound,
                        upperBound: $0.range.upperBound
                    )
                }
            )
        }
    }

    /// Compares a dictation `attempt` against the `reference` sentence.
    ///
    /// - Throws: ``Failure/inputTooLong`` if either side exceeds
    ///   ``maxInputLength`` characters.
    public static func compare(attempt: String, reference: String) throws -> Result {
        guard attempt.count <= maxInputLength, reference.count <= maxInputLength else {
            throw Failure.inputTooLong
        }

        let attemptTokenization = tokenize(attempt)
        let referenceTokens = tokenize(reference).tokens

        let segments = alignedSegments(
            attemptTokens: attemptTokenization.tokens,
            referenceTokens: referenceTokens,
            renderedAttempt: attemptTokenization.rendered
        )
        let differenceCount = segments.count
        return Result(
            differenceCount: differenceCount,
            segments: segments,
            renderedAttempt: attemptTokenization.rendered
        )
    }

    // MARK: - Tokenization

    private struct Token {
        /// Token text as displayed (original case, straight apostrophes).
        var text: String
        /// Case-folded form used for equality during alignment.
        var folded: String
        /// `Character` offset range into the rendered string.
        var range: Range<Int>
        var isCJK: Bool
    }

    /// Scans `raw` into word tokens, dropping standalone punctuation and
    /// collapsing whitespace, and builds the rendered display string with each
    /// token's `Character` range recorded in a single pass.
    private static func tokenize(_ raw: String) -> (rendered: String, tokens: [Token]) {
        let normalized = raw.precomposedStringWithCanonicalMapping

        // First pass: extract word strings (and whether each is a CJK glyph),
        // discarding punctuation and whitespace separators.
        var words: [(text: String, isCJK: Bool)] = []
        var current = ""

        func flushWord() {
            guard !current.isEmpty else { return }
            // Trim word-internal connectors (apostrophe / hyphen) that ended up
            // at a boundary, e.g. a trailing quote.
            let trimmed = trimConnectors(current)
            if !trimmed.isEmpty {
                words.append((text: trimmed, isCJK: false))
            }
            current = ""
        }

        for character in normalized {
            if isCJK(character) {
                flushWord()
                words.append((text: String(character), isCJK: true))
            } else if character.isLetter || character.isNumber {
                current.append(character)
            } else if isWordConnector(character) {
                // Keep only when joining an in-progress word; normalize curly
                // apostrophes to straight so its / it's compares stably.
                if !current.isEmpty {
                    current.append(character == "’" ? "'" : character)
                }
            } else {
                flushWord()
            }
        }
        flushWord()

        // Second pass: build rendered string applying the join rule (no space
        // between two adjacent CJK glyphs; single space otherwise) and record
        // each token's Character offset range.
        var rendered = ""
        var offset = 0
        var tokens: [Token] = []
        for (index, word) in words.enumerated() {
            if index > 0 {
                let previous = words[index - 1]
                let joinWithSpace = !(previous.isCJK && word.isCJK)
                if joinWithSpace {
                    rendered.append(" ")
                    offset += 1
                }
            }
            let length = word.text.count
            tokens.append(
                Token(
                    text: word.text,
                    folded: word.text.lowercased(),
                    range: offset ..< (offset + length),
                    isCJK: word.isCJK
                )
            )
            rendered.append(word.text)
            offset += length
        }

        return (rendered, tokens)
    }

    private static func trimConnectors(_ word: String) -> String {
        var characters = Array(word)
        while let first = characters.first, isWordConnector(first) {
            characters.removeFirst()
        }
        while let last = characters.last, isWordConnector(last) {
            characters.removeLast()
        }
        return String(characters)
    }

    private static func isWordConnector(_ character: Character) -> Bool {
        character == "'" || character == "’" || character == "-"
    }

    private static func isCJK(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            let value = scalar.value
            let isHan =
                (0x4E00 ... 0x9FFF).contains(value) || // CJK Unified Ideographs
                (0x3400 ... 0x4DBF).contains(value) || // Extension A
                (0x20000 ... 0x2A6DF).contains(value) || // Extension B
                (0x3040 ... 0x309F).contains(value) || // Hiragana
                (0x30A0 ... 0x30FF).contains(value) || // Katakana
                (0xAC00 ... 0xD7AF).contains(value) // Hangul syllables
            if isHan {
                return true
            }
        }
        return false
    }

    // MARK: - Alignment

    /// Aligns attempt vs reference tokens by LCS (case-folded), then walks the
    /// gaps between matched anchors. Within each gap, attempt and reference
    /// tokens are paired positionally as ``SegmentKind/changed``; surplus
    /// attempt tokens become ``SegmentKind/extra`` and surplus reference tokens
    /// become ``SegmentKind/missing``. Difference count per gap is therefore
    /// `max(attemptGap, referenceGap)`.
    private static func alignedSegments(
        attemptTokens: [Token],
        referenceTokens: [Token],
        renderedAttempt: String
    ) -> [Segment] {
        let matches = longestCommonSubsequence(attemptTokens, referenceTokens)

        var segments: [Segment] = []
        var attemptIndex = 0
        var referenceIndex = 0

        func emitGap(attemptUpTo: Int, referenceUpTo: Int, insertionOffset: Int) {
            let attemptGap = Array(attemptTokens[attemptIndex ..< attemptUpTo])
            let referenceGap = Array(referenceTokens[referenceIndex ..< referenceUpTo])
            let paired = min(attemptGap.count, referenceGap.count)

            for offset in 0 ..< paired {
                let attemptToken = attemptGap[offset]
                segments.append(
                    Segment(
                        kind: .changed,
                        range: attemptToken.range,
                        attemptText: attemptToken.text,
                        referenceText: referenceGap[offset].text
                    )
                )
            }
            if attemptGap.count > referenceGap.count {
                for offset in paired ..< attemptGap.count {
                    let attemptToken = attemptGap[offset]
                    segments.append(
                        Segment(
                            kind: .extra,
                            range: attemptToken.range,
                            attemptText: attemptToken.text,
                            referenceText: nil
                        )
                    )
                }
            } else if referenceGap.count > attemptGap.count {
                for offset in paired ..< referenceGap.count {
                    segments.append(
                        Segment(
                            kind: .missing,
                            range: insertionOffset ..< insertionOffset,
                            attemptText: "",
                            referenceText: referenceGap[offset].text
                        )
                    )
                }
            }
        }

        for match in matches {
            let insertionOffset = attemptTokens[match.attempt].range.lowerBound
            emitGap(attemptUpTo: match.attempt, referenceUpTo: match.reference, insertionOffset: insertionOffset)
            attemptIndex = match.attempt + 1
            referenceIndex = match.reference + 1
        }
        let tailInsertion = renderedAttempt.count
        emitGap(attemptUpTo: attemptTokens.count, referenceUpTo: referenceTokens.count, insertionOffset: tailInsertion)

        return segments
    }

    private struct Match {
        var attempt: Int
        var reference: Int
    }

    private static func longestCommonSubsequence(_ lhs: [Token], _ rhs: [Token]) -> [Match] {
        let lhsCount = lhs.count
        let rhsCount = rhs.count
        guard lhsCount > 0, rhsCount > 0 else { return [] }

        // lengths[row][col] = LCS length of lhs[row...] and rhs[col...].
        var lengths = [[Int]](repeating: [Int](repeating: 0, count: rhsCount + 1), count: lhsCount + 1)
        for row in stride(from: lhsCount - 1, through: 0, by: -1) {
            for col in stride(from: rhsCount - 1, through: 0, by: -1) {
                if lhs[row].folded == rhs[col].folded {
                    lengths[row][col] = lengths[row + 1][col + 1] + 1
                } else {
                    lengths[row][col] = max(lengths[row + 1][col], lengths[row][col + 1])
                }
            }
        }

        var matches: [Match] = []
        var row = 0
        var col = 0
        while row < lhsCount, col < rhsCount {
            if lhs[row].folded == rhs[col].folded {
                matches.append(Match(attempt: row, reference: col))
                row += 1
                col += 1
            } else if lengths[row + 1][col] >= lengths[row][col + 1] {
                row += 1
            } else {
                col += 1
            }
        }
        return matches
    }
}

/// Persistable summary of a dictation diff: difference count plus per-segment
/// classification and `Character` ranges. Text slices are recomputed at render
/// time, so no derived strings are stored (plan §13 review note).
public struct PracticeDictationDiffSummary: Codable, Hashable, Sendable {
    public struct Segment: Codable, Hashable, Sendable {
        public var kind: String
        public var lowerBound: Int
        public var upperBound: Int

        public init(kind: String, lowerBound: Int, upperBound: Int) {
            self.kind = kind
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        }
    }

    public var differenceCount: Int
    public var segments: [Segment]

    public init(differenceCount: Int, segments: [Segment]) {
        self.differenceCount = differenceCount
        self.segments = segments
    }
}
