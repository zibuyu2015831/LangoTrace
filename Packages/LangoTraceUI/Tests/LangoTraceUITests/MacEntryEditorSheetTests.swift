import Foundation
import Testing

@Suite("Mac entry editor sheet")
struct MacEntryEditorSheetTests {
    @Test("Mac entry editor uses a custom overlay instead of the system sheet")
    func macEntryEditorUsesCustomOverlayInsteadOfSystemSheet() throws {
        let macMainView = try String(contentsOf: sourceFileURL(named: "MacMainView.swift"), encoding: .utf8)

        #expect(macMainView.contains("MacEntryEditorOverlay("))
        #expect(!macMainView.contains(".sheet(isPresented: $isEntryEditorPresented)"))
        #expect(macMainView.contains("isEntryEditorPresented = false"))
        #expect(macMainView.contains(".onTapGesture"))
        #expect(macMainView.contains("onCancel"))
        #expect(macMainView.contains("onSave"))
    }

    @Test("Mac entry editor has a platform-specific design component")
    func macEntryEditorHasPlatformSpecificDesignComponent() throws {
        let source = try String(contentsOf: sourceFileURL(named: "MacEntryEditorSheet.swift"), encoding: .utf8)

        for expected in [
            "#if os(macOS)",
            "struct MacEntryEditorSheet",
            "let onCancel: () -> Void",
            "private var canSave: Bool",
            "bodyText.trimmingCharacters(in: .whitespacesAndNewlines)",
            "LangoTraceDesign.ColorToken.paper",
            "LangoTraceDesign.ColorToken.elevatedPaper",
            "LangoTraceDesign.ColorToken.hairline",
            "LangoTraceDesign.ColorToken.accent",
            ".keyboardShortcut(.cancelAction)",
        ] {
            #expect(source.contains(expected))
        }
    }

    @Test("Mac entry editor does not reuse the mobile Form layout")
    func macEntryEditorDoesNotReuseMobileFormLayout() throws {
        let source = try String(contentsOf: sourceFileURL(named: "MacEntryEditorSheet.swift"), encoding: .utf8)
        let macComponent = try #require(source.range(of: "#if os(macOS)")?.lowerBound)
        let mobileComponent = try #require(
            source.range(of: "#endif", range: macComponent ..< source.endIndex)?.lowerBound
        )
        let macSource = String(source[macComponent ..< mobileComponent])

        #expect(!macSource.contains("Form {"))
        #expect(macSource.contains("TextEditor(text: $bodyText)"))
        #expect(macSource.contains("onSave(title, bodyText)"))
        #expect(macSource.contains("onCancel()"))
    }

    @Test("Shared phone supporting views do not own Mac editor presentation")
    func sharedPhoneSupportingViewsDoNotOwnMacEditorPresentation() throws {
        let source = try String(contentsOf: sourceFileURL(named: "PhoneMainSupportingViews.swift"), encoding: .utf8)

        #expect(!source.contains("struct MacEntryEditorSheet"))
    }

    private func sourceFileURL(named fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("LangoTraceUI")
            .appendingPathComponent(fileName)
    }
}
