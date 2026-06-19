import Foundation

/// A wrapper that stores a secret string while preventing accidental leakage
/// through `description`, `debugDescription`, string interpolation, or `Mirror`.
///
/// Use this type for API keys, tokens, and other credential values that must
/// never appear in logs, debug output, or error descriptions.
///
/// - Important: ``unsafeUnwrappedValue`` reveals the underlying plaintext.
///   Only call it in code paths that genuinely require the raw secret
///   (e.g., constructing an Authorization header, writing to Keychain).
public struct RedactedSecret: Equatable, Sendable, CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable
{
    private let value: String

    public init(_ value: String) {
        self.value = value
    }

    /// Reveals the underlying secret.
    ///
    /// Use only when the plaintext is required (e.g., constructing authorization
    /// headers, Keychain storage). All other access paths produce `"<redacted>"`.
    public var unsafeUnwrappedValue: String {
        value
    }

    // MARK: - Redacted representations

    public var description: String {
        "<redacted>"
    }

    public var debugDescription: String {
        "<redacted>"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [])
    }

    // MARK: - Constant-time equality

    public static func == (lhs: Self, rhs: Self) -> Bool {
        let lhsBytes = [UInt8](lhs.value.utf8)
        let rhsBytes = [UInt8](rhs.value.utf8)
        // Capture length mismatch as a non-zero accumulator so the comparison
        // does not short-circuit on the first differing byte.
        var result: UInt8 = lhsBytes.count == rhsBytes.count ? 0 : 1
        let commonCount = max(lhsBytes.count, rhsBytes.count)
        for i in 0 ..< commonCount {
            let l = i < lhsBytes.count ? lhsBytes[i] : 0
            let r = i < rhsBytes.count ? rhsBytes[i] : 0
            result |= l ^ r
        }
        return result == 0
    }
}
