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
        // whitespace around single CJK char
        #expect(shouldTriggerPanel(for: " 的 ") == false)
    }
}
