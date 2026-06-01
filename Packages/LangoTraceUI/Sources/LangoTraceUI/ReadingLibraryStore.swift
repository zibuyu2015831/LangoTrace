import Combine
import Foundation
import LangoTraceCore

@MainActor
final class ReadingLibraryStore: ObservableObject {
    private let actions: ReadingLibraryActions
    private var generation = 0

    @Published private(set) var languageSpace: LanguageSpacePreview
    @Published private(set) var documents: [ReadingLibraryDocumentSummary] = []
    @Published private(set) var deletedDocuments: [ReadingLibraryDocumentSummary] = []
    @Published private(set) var searchText = ""
    @Published private(set) var loadState: ReadingAsyncState = .idle
    @Published private(set) var importState: ReadingAsyncState = .idle
    @Published private(set) var selectedDocument: ReadingLibraryDocumentContent?
    @Published private(set) var selectedPresentation: ReadingDocumentPresentation?

    init(
        languageSpace: LanguageSpacePreview,
        actions: ReadingLibraryActions = .disabled
    ) {
        self.languageSpace = languageSpace
        self.actions = actions
    }

    func replaceLanguageSpace(_ languageSpace: LanguageSpacePreview) {
        guard self.languageSpace.id != languageSpace.id else {
            self.languageSpace = languageSpace
            return
        }
        self.languageSpace = languageSpace
        documents = []
        deletedDocuments = []
        selectedDocument = nil
        selectedPresentation = nil
        searchText = ""
        invalidateInFlightWork()
    }

    func reload() async {
        loadState = .loading
        let token = nextToken()
        let spaceID = languageSpace.id
        let query = ReadingLibrarySearchQuery(rawValue: searchText)
        do {
            async let active = actions.listDocuments(spaceID, false, query)
            async let deleted = actions.listDocuments(spaceID, true, nil)
            let loadedActive = try await active
            let loadedDeleted = try await deleted.filter { $0.libraryStatus == .softDeleted }
            guard isCurrent(token: token, spaceID: spaceID) else { return }
            documents = loadedActive
            deletedDocuments = loadedDeleted
            loadState = .idle
        } catch {
            guard isCurrent(token: token, spaceID: spaceID) else { return }
            loadState = .failed
        }
    }

    func updateSearchText(_ text: String) async {
        searchText = text
        await reload()
    }

    func importPastedText(title: String, body: String) async throws {
        let result = ReadingImportPreflight.evaluatePastedText(
            body,
            limits: .verticalSliceDefaults
        )
        guard result.decision == .accept else {
            importState = .failed
            throw ReadingLibraryStoreError.preflightRejected
        }

        importState = .loading
        let input = ReadingInlineDocumentImportInput(
            spaceID: languageSpace.id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? String(body.prefix(40))
                : title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body,
            sourceFormat: .pastedText,
            adapterID: "builtin.pasted_text",
            adapterVersion: 1,
            targetLanguageCode: languageSpace.targetLanguageCode,
            originalFilename: nil,
            originalFileExtension: nil,
            originalMimeType: "text/plain",
            originalUTI: "public.plain-text",
            originalByteSize: Data(body.utf8).count
        )
        do {
            _ = try await actions.importPastedText(input)
            importState = .idle
            await reload()
        } catch {
            importState = .failed
            throw error
        }
    }

    func openDocument(_ id: String) async {
        let token = nextToken()
        let spaceID = languageSpace.id
        do {
            try await actions.markDocumentOpened(id, spaceID)
            guard let document = try await actions.loadDocument(id, spaceID) else {
                guard isCurrent(token: token, spaceID: spaceID) else { return }
                selectedDocument = nil
                selectedPresentation = nil
                return
            }
            let presentation = ReadingMarkdownBlockRenderer.render(
                document: ReadingMarkdownParser.parse(document.body, sourceFormat: document.sourceFormat),
                appearance: .default,
                platform: .phone
            )
            guard isCurrent(token: token, spaceID: spaceID) else { return }
            selectedDocument = document
            selectedPresentation = presentation
        } catch {
            guard isCurrent(token: token, spaceID: spaceID) else { return }
            selectedDocument = nil
            selectedPresentation = nil
        }
    }

    func softDelete(_ id: String) async {
        do {
            try await actions.softDeleteDocument(id, languageSpace.id)
            await reload()
        } catch {
            loadState = .failed
        }
    }

    func restore(_ id: String) async {
        do {
            try await actions.restoreDocument(id, languageSpace.id)
            await reload()
        } catch {
            loadState = .failed
        }
    }

    private func nextToken() -> Int {
        generation += 1
        return generation
    }

    private func invalidateInFlightWork() {
        generation += 1
    }

    private func isCurrent(token: Int, spaceID: String) -> Bool {
        token == generation && languageSpace.id == spaceID
    }
}

enum ReadingLibraryStoreError: Error, Equatable {
    case preflightRejected
}
