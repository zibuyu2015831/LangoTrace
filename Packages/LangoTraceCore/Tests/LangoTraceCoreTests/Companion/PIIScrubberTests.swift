import Foundation
@testable import LangoTraceCore
import Testing

@Suite("PII scrubber (LM03-S2b-1 outbound redaction)")
struct PIIScrubberTests {
    @Test("mobileHit — exact 11-digit 1[3-9] number is redacted")
    func mobileHit() {
        #expect(PIIScrubber.scrub("打 13800138000 给我") == "打 \(PIIScrubber.mobilePlaceholder) 给我")
    }

    @Test("mobileBoundary — 10 digits and 1[0-2] prefixes are NOT redacted")
    func mobileBoundary() {
        // 10 digits — too short.
        #expect(PIIScrubber.scrub("1234567890") == "1234567890")
        // 11 digits but prefix 1[0-2] is not a valid mobile.
        #expect(PIIScrubber.scrub("12000000000") == "12000000000")
        // Embedded in a longer digit run — not a standalone mobile.
        #expect(PIIScrubber.scrub("x138001380009x") == "x138001380009x")
    }

    @Test("nationalIDHit — 18-char ID with X check digit is redacted")
    func nationalIDHit() {
        #expect(PIIScrubber.scrub("证件 11010519491231002X 备案")
            == "证件 \(PIIScrubber.nationalIDPlaceholder) 备案")
        // All-digit 18-char ID.
        #expect(PIIScrubber.scrub("110105194912310021")
            == PIIScrubber.nationalIDPlaceholder)
    }

    @Test("nationalIDBoundary — 17 chars or bad check char are NOT redacted")
    func nationalIDBoundary() {
        // 17 digits — too short.
        #expect(PIIScrubber.scrub("11010519491231002") == "11010519491231002")
        // 18th char is a non-X letter — not a valid check char in this rule.
        #expect(PIIScrubber.scrub("11010519491231002Y") == "11010519491231002Y")
    }

    @Test("noFalsePositives — prices, years, short numbers survive")
    func noFalsePositives() {
        #expect(PIIScrubber.scrub("价格 ¥299，年份 2026") == "价格 ¥299，年份 2026")
        #expect(PIIScrubber.scrub("") == "")
        #expect(PIIScrubber.scrub("no pii here") == "no pii here")
    }

    @Test("placeholderIsNeutralNounPhrase — no imperative verb that could read as instruction")
    func placeholderIsNeutralNounPhrase() {
        // Defensive: placeholders must not contain instruction-like imperatives
        // (they may land in a user message body outside the prompt delimiter).
        for placeholder in [PIIScrubber.mobilePlaceholder, PIIScrubber.nationalIDPlaceholder] {
            #expect(placeholder.hasPrefix("["))
            #expect(placeholder.hasSuffix("]"))
            #expect(!placeholder.lowercased().contains("ignore"))
            #expect(!placeholder.contains("请"))
        }
    }
}
