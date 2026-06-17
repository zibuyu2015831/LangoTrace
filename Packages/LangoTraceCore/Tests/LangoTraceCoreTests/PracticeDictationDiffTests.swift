import LangoTraceCore
import Testing

@Suite("Practice dictation diff (本机对照)")
struct PracticeDictationDiffTests {
    /// 原型示例：stay vs stays 应为 1 处差异（词形差异计入声学/词汇层）。
    @Test("Third-person -s word-form difference counts as one difference and locates the changed word")
    func thirdPersonSDifferenceCountsAsOneDifference() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "The owner says he only stay for three hours a day.",
            reference: "The owner says he only stays for three hours a day."
        )
        #expect(result.differenceCount == 1)
        #expect(result.segments.count == 1)
        let segment = try #require(result.segments.first)
        #expect(segment.kind == .changed)
        // 差异段定位到用户作答里的 "stay"。
        let lower = result.renderedAttempt.index(result.renderedAttempt.startIndex, offsetBy: segment.range.lowerBound)
        let upper = result.renderedAttempt.index(result.renderedAttempt.startIndex, offsetBy: segment.range.upperBound)
        #expect(String(result.renderedAttempt[lower ..< upper]) == "stay")
        #expect(segment.referenceText == "stays")
    }

    @Test("Punctuation-only difference counts as zero differences")
    func punctuationOnlyDifferenceCountsZero() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "Hello, world!",
            reference: "Hello world"
        )
        #expect(result.differenceCount == 0)
        #expect(result.segments.isEmpty)
    }

    @Test("Case-only difference counts as zero differences")
    func caseOnlyDifferenceCountsZero() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "the OWNER Says",
            reference: "The owner says"
        )
        #expect(result.differenceCount == 0)
        #expect(result.segments.isEmpty)
    }

    @Test("Homophone its/it's counts as a difference")
    func homophoneApostropheDifferenceCounts() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "its a good day",
            reference: "it's a good day"
        )
        #expect(result.differenceCount == 1)
        let segment = try #require(result.segments.first)
        #expect(segment.kind == .changed)
        #expect(segment.referenceText == "it's")
    }

    @Test("Curly and straight apostrophes are treated as equal")
    func curlyApostropheEqualsStraight() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "it’s fine",
            reference: "it's fine"
        )
        #expect(result.differenceCount == 0)
    }

    @Test("Missing word counts and is classified as missing")
    func missingWordCountsAsMissing() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "the owner says",
            reference: "the owner always says"
        )
        #expect(result.differenceCount == 1)
        let segment = try #require(result.segments.first)
        #expect(segment.kind == .missing)
        #expect(segment.referenceText == "always")
    }

    @Test("Extra word counts and is classified as extra")
    func extraWordCountsAsExtra() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "the lazy owner says",
            reference: "the owner says"
        )
        #expect(result.differenceCount == 1)
        let segment = try #require(result.segments.first)
        #expect(segment.kind == .extra)
        let lower = result.renderedAttempt.index(result.renderedAttempt.startIndex, offsetBy: segment.range.lowerBound)
        let upper = result.renderedAttempt.index(result.renderedAttempt.startIndex, offsetBy: segment.range.upperBound)
        #expect(String(result.renderedAttempt[lower ..< upper]) == "lazy")
    }

    @Test("Emoji and CJK mixed input produces in-bounds ranges without crashing")
    func emojiAndCJKSafeRanges() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "今天 天气 很好 😀 today",
            reference: "今天 天气 不好 today"
        )
        // 范围全部落在 renderedAttempt 边界内，可安全切片。
        let count = result.renderedAttempt.count
        for segment in result.segments {
            #expect(segment.range.lowerBound >= 0)
            #expect(segment.range.upperBound <= count)
            #expect(segment.range.lowerBound <= segment.range.upperBound)
        }
    }

    @Test("Identical input produces zero differences")
    func identicalInputProducesZeroDifferences() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "The quick brown fox",
            reference: "The quick brown fox"
        )
        #expect(result.differenceCount == 0)
        #expect(result.segments.isEmpty)
    }

    @Test("Input over the character limit is rejected")
    func inputOverLimitRejected() {
        let long = String(repeating: "a ", count: PracticeDictationDiff.maxInputLength)
        #expect(throws: PracticeDictationDiff.Failure.inputTooLong) {
            _ = try PracticeDictationDiff.compare(attempt: long, reference: "short")
        }
    }

    @Test("Diff summary round-trips difference count and segment classification")
    func diffSummaryRoundTrips() throws {
        let result = try PracticeDictationDiff.compare(
            attempt: "The owner says he only stay for three hours a day.",
            reference: "The owner says he only stays for three hours a day."
        )
        let summary = result.summary
        #expect(summary.differenceCount == 1)
        #expect(summary.segments.count == 1)
        #expect(summary.segments.first?.kind == "changed")
    }
}
