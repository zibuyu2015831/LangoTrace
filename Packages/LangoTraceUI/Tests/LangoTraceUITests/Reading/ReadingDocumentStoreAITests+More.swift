import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
extension ReadingDocumentStoreAITests {
    @Test("save failure maps empty body validation to explicit user-facing error")
    func saveFailureMapsEmptyBodyValidation() {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in .cancelled }
        )

        store.beginEditing(document: ReadingLibraryDocumentContent(
            id: "doc-1",
            spaceID: "space-1",
            title: "Title",
            body: "Body",
            sourceFormat: .plainText,
            targetLanguageCode: "en",
            contentRevision: 1,
            structureVersion: 1
        ))
        store.markSavingEdit()
        store.failSavingEdit(ReadingDocumentUpdateError.emptyBody)

        #expect(store.saveState == .failed)
        #expect(store.saveFailure?.messageKey == "reading.editor.error.emptyBody")
        #expect(store.isEditorPresented)
    }
}

private extension ReadingSelectionExplanationResult {
    static func sample(selection: String) -> ReadingSelectionExplanationResult {
        ReadingSelectionExplanationResult(
            schemaVersion: "reading_selection_explanation.v3",
            selection: selection,
            shortExplanation: "Explanation",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage",
            exampleSentence: "Example.",
            grammaticalNote: "Noun, singular."
        )
    }
}
