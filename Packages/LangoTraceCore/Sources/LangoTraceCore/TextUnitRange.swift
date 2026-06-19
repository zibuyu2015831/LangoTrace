import Foundation

/// A half-open range expressed in **UTF-16 code unit offsets** from the start
/// of a source string.
///
/// Using UTF-16 code units matches the conventions of `NSRange`,
/// `UITextView.selectedRange`, and `NSTextView.selectedRange`, making this
/// type directly compatible with AppKit / UIKit text selection APIs without
/// unit conversion.
///
/// - Important: Do **not** add integer offsets computed from
///   `String.count` (which counts `Character` / grapheme clusters) to a
///   `TextUnitRange` offset — the units are incompatible for strings
///   containing emoji, CJK, or other multi-UTF-16-scalar content.
public struct TextUnitRange: Equatable, Sendable, CustomStringConvertible {
    /// Lower bound, in UTF-16 code units from the start of the source text.
    public var lowerBound: Int
    /// Upper bound, in UTF-16 code units from the start of the source text.
    public var upperBound: Int

    public init(lowerBound: Int, upperBound: Int) {
        precondition(lowerBound >= 0, "TextUnitRange lowerBound must be non-negative")
        precondition(upperBound >= lowerBound, "TextUnitRange upperBound must be >= lowerBound")
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    /// Length in UTF-16 code units.
    public var length: Int {
        upperBound - lowerBound
    }

    /// Converts to `NSRange` for interoperability with Foundation text APIs.
    public var toNSRange: NSRange {
        NSRange(location: lowerBound, length: length)
    }

    /// Creates a `TextUnitRange` from a `Range<String.Index>` by computing
    /// UTF-16 code unit offsets relative to the start of `string`.
    public init(_ range: Range<String.Index>, in string: String) {
        lowerBound = range.lowerBound.utf16Offset(in: string)
        upperBound = range.upperBound.utf16Offset(in: string)
    }

    /// Converts to a `Range<String.Index>` for subscripting the source string.
    ///
    /// Returns `nil` if the UTF-16 boundaries do not correspond to valid
    /// grapheme cluster boundaries in `string` (e.g., the range splits a
    /// surrogate pair).
    public func toRange(in string: String) -> Range<String.Index>? {
        Range(toNSRange, in: string)
    }

    public var description: String {
        "\(lowerBound)..<\(upperBound)"
    }
}
