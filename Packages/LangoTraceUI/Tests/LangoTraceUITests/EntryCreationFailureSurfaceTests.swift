import Foundation
import Testing

@Suite("Entry creation and import failure surfacing")
struct EntryCreationFailureSurfaceTests {
    @Test("Phone and pad entry editors propagate creation failures instead of swallowing them")
    func phoneAndPadEntryEditorsPropagateCreationFailures() throws {
        let phone = try source("PhoneMainView.swift")
        let pad = try source("PadMainView.swift")
        let editor = try source("PhoneMainSupportingViews.swift")

        #expect(phone.contains("let entry = try contentStore.createEntry("))
        #expect(!phone.contains("try? contentStore.createEntry("))
        #expect(pad.contains("let entry = try contentStore.createEntry("))
        #expect(!pad.contains("try? contentStore.createEntry("))
        #expect(editor.contains("let onSave: (String, String) throws -> Void"))
        #expect(editor.contains("saveErrorKey = \"entryEditor.saveFailed\""))
    }

    @Test("Mac entry editor keeps the draft, reports failure, and guards background dismissal")
    func macEntryEditorKeepsDraftReportsFailureAndGuardsBackgroundDismissal() throws {
        let macMain = try source("MacMainView.swift")
        let macSheet = try source("MacEntryEditorSheet.swift")

        #expect(macMain.contains("func saveEntry(title: String, body: String) throws"))
        #expect(!macMain.contains("try? contentStore.createEntry("))
        #expect(macMain.contains("guard !hasDraftContent else { return }"))
        #expect(macSheet.contains("saveErrorKey = \"entryEditor.saveFailed\""))
        #expect(macSheet.contains("@Binding var hasDraftContent: Bool"))
    }

    @Test("Reading import failures keep the sheet open and surface an error line")
    func readingImportFailuresKeepSheetOpenAndSurfaceErrorLine() throws {
        let views = try source("ReadingViews.swift")
        let components = try source("ReadingViewComponents.swift")

        #expect(views.contains("try await store.importPastedText(title: importTitle, body: importBody)"))
        #expect(!views.contains("try? await store.importPastedText"))
        #expect(views.contains("reading.import.error.generic"))
        #expect(components.contains("var errorTextKey: String?"))
    }

    @Test("Photo writing import failures are not swallowed after entry creation")
    func photoWritingImportFailuresAreNotSwallowedAfterEntryCreation() throws {
        let phone = try source("PhoneMainView.swift")
        let actions = try source("PhotoWritingActions.swift")

        #expect(phone.contains("let entry = try coordinator.save(body: body, imageData: imageData, spaceID: languageSpace.id)"))
        #expect(!phone.contains("try? photoWritingActions.importPhoto"))
        #expect(actions.contains("Throwing is fatal to the photo-writing"))
        #expect(!actions.contains("Throwing is non-fatal"))
    }

    private func source(_ name: String) throws -> String {
        try String(contentsOf: langoTraceUISourceFileURL(named: name), encoding: .utf8)
    }
}
