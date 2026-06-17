import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Reading word count")
struct ReadingWordCountTests {
    @Test("English text counts whitespace-delimited words")
    func englishTextCountsWhitespaceWords() {
        #expect(ReadingWordCounter.wordCount(for: "Hello world", languageCode: "en") == 2)
        #expect(ReadingWordCounter.wordCount(for: "She went to the market.", languageCode: "en") == 5)
        #expect(ReadingWordCounter.wordCount(for: "  leading and trailing  ", languageCode: "en") == 3)
    }

    @Test("CJK text counts characters")
    func cjkTextCountsCharacters() {
        // Japanese
        let jpText = "猫が好き"
        #expect(ReadingWordCounter.wordCount(for: jpText, languageCode: "ja") == 4)
        // Chinese
        let zhText = "你好世界"
        #expect(ReadingWordCounter.wordCount(for: zhText, languageCode: "zh") == 4)
    }

    @Test("empty text returns zero")
    func emptyTextReturnsZero() {
        #expect(ReadingWordCounter.wordCount(for: "", languageCode: "en") == 0)
        #expect(ReadingWordCounter.wordCount(for: "   ", languageCode: "en") == 0)
    }

    @Test("unknown language code falls back to whitespace splitting")
    func unknownLanguageCodeFallsBackToWhitespaceSplitting() {
        #expect(ReadingWordCounter.wordCount(for: "one two three", languageCode: "xx") == 3)
    }
}
