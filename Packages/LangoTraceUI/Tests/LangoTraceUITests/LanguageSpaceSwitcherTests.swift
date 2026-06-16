import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Language space switcher")
struct LanguageSpaceSwitcherTests {
    @Test("Switcher presentation keeps the current space first and selected")
    func switcherPresentationKeepsCurrentSpaceFirst() {
        let spaces = [
            languageSpace(id: "ja", displayName: "日语空间", targetLanguageCode: "ja", lastOpenedAt: date(20)),
            languageSpace(id: "en", displayName: "英语空间", targetLanguageCode: "en", lastOpenedAt: date(10)),
            languageSpace(id: "fr", displayName: "法语空间", targetLanguageCode: "fr", lastOpenedAt: date(30)),
        ]

        let presentation = LanguageSpaceSwitcherPresentation(spaces: spaces, currentSpaceID: "en")

        #expect(presentation.rows.map(\.space.id) == ["en", "fr", "ja"])
        #expect(presentation.rows[0].isCurrent)
        #expect(!presentation.rows[0].isSelectable)
        #expect(presentation.rows[1].isSelectable)
    }

    @Test("Switcher presentation does not make the current row selectable")
    func switcherPresentationDoesNotSelectCurrentRow() {
        let spaces = [
            languageSpace(id: "en", displayName: "英语空间", targetLanguageCode: "en", lastOpenedAt: date(10)),
            languageSpace(id: "ja", displayName: "日语空间", targetLanguageCode: "ja", lastOpenedAt: date(20)),
        ]

        let presentation = LanguageSpaceSwitcherPresentation(spaces: spaces, currentSpaceID: "en")

        #expect(presentation.rows[0].selectionID == nil)
        #expect(presentation.rows[1].selectionID == "ja")
    }

    @Test("Phone main routes language space chrome to switcher sheet")
    func phoneMainRoutesLanguageSpaceChromeToSwitcherSheet() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainView.swift"), encoding: .utf8)

        #expect(source.contains("case .languageSpaceSwitcher"))
        #expect(source.contains("presentedSheet = .languageSpaceSwitcher"))
        #expect(!source.contains("case .languageSpaceSummary"))
        #expect(!source.contains("presentedSheet = .languageSpaceSummary"))
        #expect(source.contains("LanguageSpaceSwitcherSheet("))
        #expect(source.contains("onManage:"))
        #expect(source.contains(".settings(.languageSpace)"))
    }

    @Test("Switcher sheet uses actions and reuses the language space editor")
    func switcherSheetUsesActionsAndEditor() throws {
        let source = try String(contentsOf: sourceFileURL(named: "LanguageSpaceSwitcherSheet.swift"), encoding: .utf8)

        #expect(source.contains("struct LanguageSpaceSwitcherSheet"))
        #expect(source.contains("let spaces: [LanguageSpace]"))
        #expect(source.contains("let currentSpaceID: String?"))
        #expect(source.contains("let onSelect: (String) -> Void"))
        #expect(source.contains("let onAdd: (CreateLanguageSpaceInput) -> Void"))
        #expect(source.contains("let onManage: () -> Void"))
        #expect(source.contains("LanguageSpaceEditorView("))
        #expect(source.contains("LanguageSpaceSwitcherPresentation"))
    }

    @Test("Switcher localization keys include English and Simplified Chinese")
    func switcherLocalizationKeysIncludeEnglishAndSimplifiedChinese() throws {
        let catalog = try String(contentsOf: sourceFileURL(named: "Resources/Localizable.xcstrings"), encoding: .utf8)
        let keys = [
            "languageSpace.switcher.title",
            "languageSpace.switcher.allSection",
            "languageSpace.switcher.add",
            "languageSpace.switcher.manage",
            "languageSpace.switcher.localFirstFootnote",
            "languageSpace.switcher.currentBadge",
        ]

        for key in keys {
            #expect(catalog.contains("\"\(key)\""))
        }
        #expect(catalog.contains("\"value\": \"Language Spaces\""))
        #expect(catalog.contains("\"value\": \"语言空间\""))
        #expect(catalog.contains("\"value\": \"Add Learning Language\""))
        #expect(catalog.contains("\"value\": \"添加学习语言\""))
    }

    private func languageSpace(
        id: String,
        displayName: String,
        targetLanguageCode: String,
        lastOpenedAt: Date?
    ) -> LanguageSpace {
        LanguageSpace(
            id: id,
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: targetLanguageCode,
            level: .b1,
            displayName: displayName,
            displayNameNormalized: displayName,
            createdAt: date(0),
            updatedAt: date(0),
            lastOpenedAt: lastOpenedAt,
            deletedAt: nil
        )
    }

    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + offset)
    }

    private func sourceFileURL(named relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LangoTraceUI")
            .appendingPathComponent(relativePath)
    }
}
