import Foundation
import LangoTraceCore

public extension ReadingDocumentStore {
    func beginEditing(document: ReadingLibraryDocumentContent) {
        draftTitle = document.title
        draftBody = document.body
        saveState = .idle
        saveFailure = nil
        isEditorPresented = true
    }

    func updateDraft(title: String, body: String) {
        draftTitle = title
        draftBody = body
        if saveState == .failed {
            saveState = .idle
            saveFailure = nil
        }
    }

    func markSavingEdit() {
        saveState = .loading
        saveFailure = nil
    }

    func completeSavingEdit(with document: ReadingLibraryDocumentContent) {
        replaceDocument(
            documentID: document.id,
            spaceID: document.spaceID,
            contentRevision: document.contentRevision
        )
        draftTitle = document.title
        draftBody = document.body
        saveState = .idle
        saveFailure = nil
        isEditorPresented = false
    }

    func failSavingEdit(_ error: Error) {
        saveState = .failed
        if let updateError = error as? ReadingDocumentUpdateError, updateError == .emptyBody {
            saveFailure = .emptyBody
        } else {
            saveFailure = .generic
        }
    }

    func cancelEditing() {
        isEditorPresented = false
        saveState = .idle
        saveFailure = nil
    }
}
