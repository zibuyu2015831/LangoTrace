import Foundation

/// Deterministic, outbound-only structured-PII redaction (LM03-S2b-1).
///
/// A defense-in-depth layer applied to *everything* that leaves the device in a
/// companion request — the injected learner-memory fragments, the current user
/// input, **and the replayed conversation history** (the engine re-sends prior
/// turns every round, so scrubbing only the current input would let last turn's
/// phone number egress this turn). It is **not** a substitute for the injection
/// consent gate; the one-time preview + per-conversation toggle remain the
/// primary control (spec/008 §2 / ADR-008 §6).
///
/// Invariant: scrubbing is an **outbound projection only**. It never rewrites the
/// persisted `companion_messages` / `learner_memory_facts` originals (those are
/// recoverable main data, ADR-008 §4) — "存原文、发脱敏".
///
/// v1 coverage is intentionally narrow and deterministic ("宁少杀勿多杀"):
/// mainland-China mobile numbers and 18-digit national ID numbers. Email /
/// address / passport / international numbers are out of scope (v2).
public enum PIIScrubber {
    /// Neutral noun-phrase placeholders (no imperative verb, so the replacement
    /// can never be read as an instruction when it lands in a user message body
    /// outside the system-prompt delimiter region — AI-17).
    public static let mobilePlaceholder = "[已隐去手机号]"
    public static let nationalIDPlaceholder = "[已隐去身份证号]"

    /// Mainland-China mobile: exactly 11 digits, 1 followed by 3-9, not embedded
    /// in a longer digit run.
    private static let mobileRegex = makeRegex("(?<![0-9])1[3-9][0-9]{9}(?![0-9])")

    /// 18-character national ID: 17 digits + a check character (digit or X/x), not
    /// embedded in a longer alphanumeric ID-like run.
    private static let nationalIDRegex = makeRegex("(?<![0-9Xx])[0-9]{17}[0-9Xx](?![0-9Xx])")

    /// Compiles a compile-time-constant pattern. The patterns are fixed literals
    /// covered by `PIIScrubberTests`; an invalid one is a programmer error surfaced
    /// loudly rather than force-tried (avoids `force_try`).
    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Invalid PII regex pattern: \(pattern)")
        }
        return regex
    }

    /// Returns `text` with structured PII replaced by neutral placeholders.
    /// National ID is matched first (18 chars) so an ID is never partially
    /// consumed by the 11-digit mobile rule.
    public static func scrub(_ text: String) -> String {
        var result = replace(in: text, regex: nationalIDRegex, with: nationalIDPlaceholder)
        result = replace(in: result, regex: mobileRegex, with: mobilePlaceholder)
        return result
    }

    private static func replace(in text: String, regex: NSRegularExpression, with replacement: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
