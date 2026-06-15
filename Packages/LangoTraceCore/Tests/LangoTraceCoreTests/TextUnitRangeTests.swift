import LangoTraceCore
import Testing

@Test("TextUnitRange stores lower and upper bounds")
func textUnitRangeStoresLowerAndUpperBounds() {
    let range = TextUnitRange(lowerBound: 5, upperBound: 12)
    #expect(range.lowerBound == 5)
    #expect(range.upperBound == 12)
    #expect(range.length == 7)
}

@Test("TextUnitRange zero-length range is valid")
func textUnitRangeZeroLengthIsValid() {
    let range = TextUnitRange(lowerBound: 10, upperBound: 10)
    #expect(range.length == 0)
}

@Test("TextUnitRange converts to NSRange correctly")
func textUnitRangeConvertsToNSRange() {
    let range = TextUnitRange(lowerBound: 3, upperBound: 8)
    let nsRange = range.toNSRange
    #expect(nsRange.location == 3)
    #expect(nsRange.length == 5)
}

@Test("TextUnitRange converts to Range<String.Index> for ASCII text")
func textUnitRangeConvertsToRangeForASCII() {
    let text = "Hello, World!"
    let range = TextUnitRange(lowerBound: 7, upperBound: 12)
    let swiftRange = range.toRange(in: text)
    #expect(swiftRange != nil)
    #expect(String(text[swiftRange!]) == "World")
}

@Test("TextUnitRange converts to Range<String.Index> for emoji text")
func textUnitRangeConvertsToRangeForEmoji() {
    let text = "Hi 🌍!"
    // "Hi " = 3 UTF-16 units (H, i, space), "🌍" = 2 UTF-16 units (surrogate pair)
    // So "🌍" occupies UTF-16 offsets 3..<5
    let range = TextUnitRange(lowerBound: 3, upperBound: 5)
    let swiftRange = range.toRange(in: text)
    #expect(swiftRange != nil)
    #expect(String(text[swiftRange!]) == "🌍")
}

@Test("TextUnitRange from String.Index range for ASCII")
func textUnitRangeFromStringIndexRangeASCII() {
    let text = "Hello, World!"
    let start = text.index(text.startIndex, offsetBy: 7)
    let end = text.index(text.startIndex, offsetBy: 12)
    let range = TextUnitRange(start ..< end, in: text)
    #expect(range.lowerBound == 7)
    #expect(range.upperBound == 12)
}

@Test("TextUnitRange from String.Index range for emoji")
func textUnitRangeFromStringIndexRangeEmoji() {
    let text = "Hi 🌍!"
    let start = text.index(text.startIndex, offsetBy: 3)
    let end = text.index(text.startIndex, offsetBy: 4)
    let range = TextUnitRange(start ..< end, in: text)
    // "🌍" starts at UTF-16 offset 3 and takes 2 units
    #expect(range.lowerBound == 3)
    #expect(range.upperBound == 5)
}

@Test("TextUnitRange equal ranges compare as equal")
func textUnitRangeEqualRanges() {
    let a = TextUnitRange(lowerBound: 1, upperBound: 5)
    let b = TextUnitRange(lowerBound: 1, upperBound: 5)
    #expect(a == b)
}

@Test("TextUnitRange different ranges compare as not equal")
func textUnitRangeDifferentRanges() {
    let a = TextUnitRange(lowerBound: 1, upperBound: 5)
    let b = TextUnitRange(lowerBound: 1, upperBound: 6)
    #expect(a != b)
}

@Test("TextUnitRange description is human-readable")
func textUnitRangeDescription() {
    let range = TextUnitRange(lowerBound: 3, upperBound: 10)
    #expect(range.description == "3..<10")
}
