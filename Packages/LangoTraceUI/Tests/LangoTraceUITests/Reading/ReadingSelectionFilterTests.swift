import Foundation
@testable import LangoTraceUI
import Testing

@Suite("Reading selection filter")
struct ReadingSelectionFilterTests {
    @Test("shouldTriggerPanel returns correct results for ASCII text")
    func shouldTriggerPanelReturnsTrueForNormalWord() {
        #expect(shouldTriggerPanel(for: "hello") == true)
        #expect(shouldTriggerPanel(for: "ab") == true)
        #expect(shouldTriggerPanel(for: "a") == false)
        #expect(shouldTriggerPanel(for: "  ") == false)
        #expect(shouldTriggerPanel(for: "") == false)
        #expect(shouldTriggerPanel(for: " a ") == false)
        #expect(shouldTriggerPanel(for: "a ") == false)
    }

    @Test("shouldTriggerPanel handles CJK characters correctly")
    func shouldTriggerPanelHandlesCJKCharacters() {
        #expect(shouldTriggerPanel(for: "你好") == true)
        #expect(shouldTriggerPanel(for: "的") == false)
        #expect(shouldTriggerPanel(for: "図書館") == true)
        #expect(shouldTriggerPanel(for: "今日") == true)
        #expect(shouldTriggerPanel(for: " 的 ") == false)
    }
}

@Suite("Character range NSRange conversion")
struct CharacterRangeConversionTests {
    @Test("characterRange converts basic ASCII NSRange correctly")
    func characterRangeConvertsASCII() {
        let text = "Hello world"
        let nsRange = NSRange(location: 6, length: 5) // "world"
        let result = characterRange(from: nsRange, in: text)
        #expect(result?.offset == 6)
        #expect(result?.length == 5)
    }

    @Test("characterRange handles CJK text where each character is one code unit")
    func characterRangeHandlesCJK() {
        let text = "今日は"
        let nsRange = NSRange(location: 1, length: 2) // "日は"
        let result = characterRange(from: nsRange, in: text)
        #expect(result?.offset == 1)
        #expect(result?.length == 2)
    }

    @Test("characterRange correctly handles emoji spanning two UTF-16 units")
    func characterRangeHandlesEmoji() {
        // "Hi 👋 there": "Hi " = 3 UTF-16 units, "👋" = 2 UTF-16 units
        let text = "Hi \u{1F44B} there"
        let nsRange = NSRange(location: 3, length: 2) // the emoji "👋"
        let result = characterRange(from: nsRange, in: text)
        // Swift String counts "👋" as 1 character, at Swift offset 3
        #expect(result?.offset == 3)
        #expect(result?.length == 1)
    }

    @Test("characterRange returns nil for an out-of-bounds NSRange")
    func characterRangeReturnsNilForOutOfBounds() {
        let text = "Short"
        let nsRange = NSRange(location: 10, length: 5)
        #expect(characterRange(from: nsRange, in: text) == nil)
    }

    @Test("characterRange returns nil for a zero-length range at a valid position")
    func characterRangeHandlesZeroLength() {
        let text = "Hello"
        let nsRange = NSRange(location: 2, length: 0)
        let result = characterRange(from: nsRange, in: text)
        #expect(result?.offset == 2)
        #expect(result?.length == 0)
    }
}
