import Foundation
@testable import LangoTraceUI
import Testing

/// Guards the photo-writing assist localization keys and — critically — that the
/// privacy disclosure now lives in the pre-send confirmation dialog. The always-on
/// in-page banner was removed for a cleaner page, so the confirmation message is the
/// single place the send scope is disclosed before the photo leaves the device.
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

    @Test("the always-on in-page privacy banner key is gone")
    func standalonePrivacyNoticeRemoved() throws {
        let strings = try catalogStrings()
        #expect(strings["photoWriting.privacy.notice"] == nil)
    }

    @Test("the pre-send confirmation discloses the photo send scope")
    func confirmationMessageDisclosesSendScope() throws {
        let strings = try catalogStrings()
        let values = try localizedValues(localizations(for: "photoWriting.assist.confirm.message", in: strings))
        let byLocale = Dictionary(uniqueKeysWithValues: values)

        let zh = try #require(byLocale["zh-Hans"])
        #expect(zh.contains("照片"))
        #expect(zh.contains("发送"))

        let en = try #require(byLocale["en"])
        #expect(en.localizedCaseInsensitiveContains("photo"))
        #expect(en.localizedCaseInsensitiveContains("sent"))
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
