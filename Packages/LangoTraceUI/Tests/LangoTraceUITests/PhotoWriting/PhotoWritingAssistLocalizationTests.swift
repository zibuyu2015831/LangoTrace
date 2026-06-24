import Foundation
@testable import LangoTraceUI
import Testing

/// Guards the photo-writing assist localization keys and — critically — that the
/// privacy notice no longer makes an unconditional "never sent" promise now that
/// the explicit assist action does send the photo (self-review P1-2 atomicity).
@Suite("Photo-writing assist localization")
struct PhotoWritingAssistLocalizationTests {
    private let requiredAssistKeys = [
        "photoWriting.assist.button",
        "photoWriting.assist.mode.suggestions",
        "photoWriting.assist.mode.draft",
        "photoWriting.assist.confirm.title",
        "photoWriting.assist.confirm.message",
        "photoWriting.assist.confirm.send",
        "photoWriting.assist.sending",
        "photoWriting.assist.adopt",
        "photoWriting.assist.dismiss",
        "photoWriting.assist.result.scene",
        "photoWriting.assist.result.angles",
        "photoWriting.assist.result.expressions",
        "photoWriting.assist.result.questions",
        "photoWriting.assist.result.draft",
        "photoWriting.assist.result.vocab",
        "photoWriting.assist.guidance.imageInputDisabled",
        "photoWriting.assist.error.generic",
    ]

    @Test("every assist key is present in en and zh-Hans")
    func assistKeysPresent() throws {
        let strings = try catalogStrings()
        for key in requiredAssistKeys {
            let localizations = try localizations(for: key, in: strings)
            #expect(localizations["en"] != nil, "\(key) missing en")
            #expect(localizations["zh-Hans"] != nil, "\(key) missing zh-Hans")
        }
    }

    @Test("the privacy notice no longer promises the photo is never sent")
    func privacyNoticeNoLongerUnconditional() throws {
        let strings = try catalogStrings()
        let values = try localizedValues(localizations(for: "photoWriting.privacy.notice", in: strings))
        let byLocale = Dictionary(uniqueKeysWithValues: values)

        let zh = try #require(byLocale["zh-Hans"])
        // The old unconditional promise must be gone...
        #expect(!zh.contains("不会发送给 AI Provider。"))
        // ...replaced by per-action accurate copy.
        #expect(zh.contains("默认"))
        #expect(zh.contains("看图") || zh.contains("发送给"))

        let en = try #require(byLocale["en"])
        #expect(!en.localizedCaseInsensitiveContains("never sent to AI"))
        #expect(en.localizedCaseInsensitiveContains("only sent"))
    }

    // MARK: - Helpers

    private func catalogStrings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }

    private func localizations(for key: String, in strings: [String: Any]) throws -> [String: Any] {
        let entry = try #require(strings[key] as? [String: Any], "missing catalog key \(key)")
        return try #require(entry["localizations"] as? [String: Any])
    }

    private func localizedValues(_ localizations: [String: Any]) throws -> [(String, String)] {
        try localizations.map { locale, value in
            let localization = try #require(value as? [String: Any])
            let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
            let localizedValue = try #require(stringUnit["value"] as? String)
            return (locale, localizedValue)
        }
    }
}
