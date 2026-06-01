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
    @Published private(set) var selectedCollectionFilter: String?
    @Published private(set) var selectedTagFilter: String?
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
        selectedCollectionFilter = nil
        selectedTagFilter = nil
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

    func importFile(url: URL) async throws {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .typeIdentifierKey])
        let filename = values.name ?? url.lastPathComponent
        let byteSize = values.fileSize ?? 0
        let metadata = ReadingImportPreflight.evaluateFileMetadata(
            filename: filename,
            byteSize: byteSize,
            limits: .verticalSliceDefaults
        )
        guard metadata.decision == .accept, metadata.shouldReadFileBody else {
            importState = .failed
            throw ReadingLibraryStoreError.preflightRejected
        }

        let data = try Data(contentsOf: url)
        let decoded = ReadingImportPreflight.decodeTextData(
            data,
            filename: filename,
            limits: .verticalSliceDefaults
        )
        guard decoded.decision == .accept, let body = decoded.text else {
            importState = .failed
            throw ReadingLibraryStoreError.preflightRejected
        }

        importState = .loading
        let input = fileImportInput(
            url: url,
            filename: filename,
            typeIdentifier: values.typeIdentifier,
            body: body,
            byteSize: data.count
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

    func updateCollectionFilter(_ value: String?) {
        selectedCollectionFilter = normalizedFilter(value)
    }

    func updateTagFilter(_ value: String?) {
        selectedTagFilter = normalizedFilter(value)
    }

    func assignCollection(documentID: String, title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await actions.assignCollection(documentID, languageSpace.id, trimmed)
        await reload()
    }

    func tagDocument(documentID: String, name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await actions.tagDocument(documentID, languageSpace.id, trimmed)
        await reload()
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

    private func normalizedFilter(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fileImportInput(
        url: URL,
        filename: String,
        typeIdentifier: String?,
        body: String,
        byteSize: Int
    ) -> ReadingInlineDocumentImportInput {
        let ext = url.pathExtension.lowercased()
        let sourceFormat: ReadingSourceFormat = ext == "md" ? .markdown : .plainText
        let fallbackUTI = sourceFormat == .markdown
            ? "net.daringfireball.markdown"
            : "public.plain-text"
        return ReadingInlineDocumentImportInput(
            spaceID: languageSpace.id,
            title: url.deletingPathExtension().lastPathComponent,
            body: body,
            sourceFormat: sourceFormat,
            adapterID: sourceFormat == .markdown ? "builtin.markdown" : "builtin.plain_text",
            adapterVersion: 1,
            targetLanguageCode: languageSpace.targetLanguageCode,
            originalFilename: filename,
            originalFileExtension: ext.isEmpty ? nil : ext,
            originalMimeType: sourceFormat == .markdown ? "text/markdown" : "text/plain",
            originalUTI: typeIdentifier ?? fallbackUTI,
            originalByteSize: byteSize
        )
    }
}

enum ReadingLibraryStoreError: Error, Equatable {
    case preflightRejected
}

extension ReadingLibraryStore {
    var availableCollectionFilters: [String] {
        Array(Set(documents.flatMap(\.collectionTitles))).sorted()
    }

    var availableTagFilters: [String] {
        Array(Set(documents.flatMap(\.tagNames))).sorted()
    }

    var filteredDocuments: [ReadingLibraryDocumentSummary] {
        documents.filter { document in
            let collectionMatches = selectedCollectionFilter.map {
                document.collectionTitles.contains($0)
            } ?? true
            let tagMatches = selectedTagFilter.map {
                document.tagNames.contains($0)
            } ?? true
            return collectionMatches && tagMatches
        }
    }
}
