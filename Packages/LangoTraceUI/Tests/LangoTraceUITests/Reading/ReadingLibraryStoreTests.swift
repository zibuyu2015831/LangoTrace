import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading library store", .serialized)
struct ReadingLibraryStoreTests {
    @Test("loads documents for the current language space only")
    func loadsCurrentSpaceOnly() async {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "A"),
                .summary(id: "doc-b", spaceID: "space-b", title: "B"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        await store.reload()

        #expect(store.documents.map(\.id) == ["doc-a"])
        #expect(await actions.listRequests.map(\.spaceID) == ["space-a", "space-a"])
    }

    @Test("imports pasted text through the registry adapter and reloads")
    func importsPastedText() async throws {
        let actions = FakeReadingLibraryActions()
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        try await store.importPastedText(title: "Essay", body: "Read this carefully.")

        #expect(store.documents.map(\.title) == ["Essay"])
        let imported = await actions.importedInputs.first
        #expect(imported?.spaceID == "space-a")
        #expect(imported?.sourceFormat == .pastedText)
        #expect(imported?.adapterID == "builtin.pasted_text")
    }

    @Test("imports markdown files after metadata preflight without storing external path")
    func importsMarkdownFile() async throws {
        let actions = FakeReadingLibraryActions()
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingStore-\(UUID().uuidString)")
            .appendingPathExtension("md")
        try Data("# Heading\n\nBody".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try await store.importFile(url: url)

        let imported = await actions.importedInputs.first
        #expect(imported?.sourceFormat == .markdown)
        #expect(imported?.adapterID == "builtin.markdown")
        #expect(imported?.originalFilename == url.lastPathComponent)
        #expect(imported?.originalFileExtension == "md")
        #expect(imported?.body == "# Heading\n\nBody")
    }

    @Test("search uses normalized query and active document scope")
    func searchUsesNormalizedQuery() async {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "Travel Notes"),
                .summary(id: "doc-b", spaceID: "space-a", title: "Cooking"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions,
            searchReloadDebounce: .zero
        )

        store.updateSearchText(" travel ")
        let didLoad = await waitUntilLibraryCondition {
            store.documents.map(\.id) == ["doc-a"]
        }

        #expect(didLoad)
        let requests = await actions.listRequests
        #expect(requests.contains { $0.query?.normalized == "travel" && !$0.includeDeleted })
    }

    @Test("typing updates search text synchronously and keeps the latest value")
    func typingUpdatesSearchTextSynchronously() async {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "Travel Notes"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions,
            searchReloadDebounce: .zero
        )

        store.updateSearchText("t")
        #expect(store.searchText == "t")
        store.updateSearchText("tr")
        #expect(store.searchText == "tr")
        store.updateSearchText("tra")

        // The source of truth must reflect the latest keystroke immediately,
        // without waiting for any reload to complete.
        #expect(store.searchText == "tra")

        let didLoad = await waitUntilLibraryCondition {
            store.documents.map(\.id) == ["doc-a"]
        }
        #expect(didLoad)
    }

    @Test("soft delete hides active document and restore returns it")
    func deleteAndRestore() async {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "A"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        await store.reload()
        await store.softDelete("doc-a")
        #expect(store.documents.isEmpty)
        #expect(store.deletedDocuments.map(\.id) == ["doc-a"])

        await store.restore("doc-a")
        #expect(store.documents.map(\.id) == ["doc-a"])
        #expect(store.deletedDocuments.isEmpty)
    }

    @Test("soft deleting the selected document clears reader selection and restore does not reselect it")
    func deletingSelectedDocumentClearsSelection() async {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "A"),
            ],
            loadedDocuments: [
                "doc-a": .content(id: "doc-a", spaceID: "space-a", title: "A", body: "Body"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        await store.reload()
        await store.openDocument("doc-a", platform: .pad)
        #expect(store.selectedDocument?.id == "doc-a")
        #expect(store.selectedPresentation != nil)

        await store.softDelete("doc-a")

        #expect(store.selectedDocument == nil)
        #expect(store.selectedPresentation == nil)
        #expect(store.documents.isEmpty)
        #expect(store.deletedDocuments.map(\.id) == ["doc-a"])

        await store.restore("doc-a")

        #expect(store.selectedDocument == nil)
        #expect(store.selectedPresentation == nil)
        #expect(store.documents.map(\.id) == ["doc-a"])
    }

    @Test("assigning collection and tag reloads filterable summaries")
    func collectionAndTagFilters() async throws {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "A"),
                .summary(id: "doc-b", spaceID: "space-a", title: "B"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        await store.reload()
        try await store.assignCollection(documentID: "doc-a", title: "Essays")
        try await store.tagDocument(documentID: "doc-a", name: "Travel")
        store.updateCollectionFilter("Essays")
        store.updateTagFilter("Travel")

        #expect(store.availableCollectionFilters == ["Essays"])
        #expect(store.availableTagFilters == ["Travel"])
        #expect(store.filteredDocuments.map(\.id) == ["doc-a"])
        #expect(await actions.assignedCollections == ["doc-a:space-a:Essays"])
        #expect(await actions.assignedTags == ["doc-a:space-a:Travel"])
    }

    @Test("unsupported file import fails before body import")
    func unsupportedFileImportFailsBeforeImport() async throws {
        let actions = FakeReadingLibraryActions()
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingStore-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        try Data([0x25, 0x50, 0x44, 0x46]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: ReadingLibraryStoreError.preflightRejected) {
            try await store.importFile(url: url)
        }
        #expect(await actions.importedInputs.isEmpty)
    }

    @Test("stale load from prior language space is ignored")
    func staleLoadIgnoredAfterSpaceSwitch() async {
        let actions = ControlledReadingLibraryActions()
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        let firstLoad = Task { await store.reload() }
        await actions.waitForListRequestCount(2)
        store.replaceLanguageSpace(.preview(id: "space-b", targetLanguageCode: "ja"))
        let secondLoad = Task { await store.reload() }
        await actions.waitForListRequestCount(4)
        await actions.completeNextList(spaceID: "space-a", includeDeleted: false, [
            .summary(id: "doc-a", spaceID: "space-a", title: "A"),
        ])
        await actions.completeNextList(spaceID: "space-a", includeDeleted: true, [])
        await actions.completeNextList(spaceID: "space-b", includeDeleted: false, [
            .summary(id: "doc-b", spaceID: "space-b", title: "B"),
        ])
        await actions.completeNextList(spaceID: "space-b", includeDeleted: true, [])
        await firstLoad.value
        await secondLoad.value

        #expect(store.documents.map(\.id) == ["doc-b"])
    }

    @Test("save refreshes library title without dropping current document selection")
    func saveRefreshesLibraryTitleWithoutDroppingCurrentDocumentSelection() async throws {
        let actions = FakeReadingLibraryActions(
            documents: [
                .summary(id: "doc-a", spaceID: "space-a", title: "Original"),
            ],
            loadedDocuments: [
                "doc-a": .content(id: "doc-a", spaceID: "space-a", title: "Original", body: "Body"),
            ]
        )
        let store = ReadingLibraryStore(
            languageSpace: .preview(id: "space-a", targetLanguageCode: "en"),
            actions: actions.actions
        )

        await store.reload()
        await store.openDocument("doc-a", platform: .phone)
        let updated = try ReadingDocumentUpdateInput(
            documentID: "doc-a",
            spaceID: "space-a",
            title: "Updated",
            body: "# Updated",
            sourceFormat: .markdown
        )

        let content = try await store.saveDocumentEdits(updated, platform: .phone)

        #expect(content.title == "Updated")
        #expect(store.documents.map(\.title) == ["Updated"])
        #expect(store.selectedDocument?.id == "doc-a")
        #expect(store.selectedDocument?.title == "Updated")
        #expect(store.selectedPresentation != nil)
    }
}

private actor FakeReadingLibraryActions {
    struct ListRequest {
        var spaceID: String
        var includeDeleted: Bool
        var query: ReadingLibrarySearchQuery?
    }

    private var storedDocuments: [ReadingLibraryDocumentSummary]
    private var storedLoadedDocuments: [String: ReadingLibraryDocumentContent]
    private(set) var importedInputs: [ReadingInlineDocumentImportInput] = []
    private(set) var listRequests: [ListRequest] = []
    private(set) var assignedCollections: [String] = []
    private(set) var assignedTags: [String] = []

    init(
        documents: [ReadingLibraryDocumentSummary] = [],
        loadedDocuments: [String: ReadingLibraryDocumentContent] = [:]
    ) {
        storedDocuments = documents
        storedLoadedDocuments = loadedDocuments
    }

    nonisolated var actions: ReadingLibraryActions {
        ReadingLibraryActions(
            listDocuments: { [self] spaceID, includeDeleted, query in
                await list(spaceID: spaceID, includeDeleted: includeDeleted, query: query)
            },
            importPastedText: { [self] input in
                await importInput(input)
            },
            loadDocument: { [self] id, _ in
                await loadDocument(id: id)
            },
            updateDocument: { [self] input in
                try await updateDocument(input)
            },
            softDeleteDocument: { [self] id, spaceID in
                await softDelete(id: id, spaceID: spaceID)
            },
            restoreDocument: { [self] id, spaceID in
                await restore(id: id, spaceID: spaceID)
            },
            markDocumentOpened: { _, _ in },
            assignCollection: { [self] id, spaceID, title in
                await assignCollection(id: id, spaceID: spaceID, title: title)
            },
            tagDocument: { [self] id, spaceID, name in
                await tag(id: id, spaceID: spaceID, name: name)
            }
        )
    }

    private func list(
        spaceID: String,
        includeDeleted: Bool,
        query: ReadingLibrarySearchQuery?
    ) -> [ReadingLibraryDocumentSummary] {
        listRequests.append(.init(spaceID: spaceID, includeDeleted: includeDeleted, query: query))
        return storedDocuments.filter { document in
            document.spaceID == spaceID
                && (includeDeleted || document.libraryStatus == .active)
                && (query == nil || document.title.lowercased().contains(query?.normalized ?? ""))
        }
    }

    private func importInput(_ input: ReadingInlineDocumentImportInput) -> ReadingLibraryDocumentSummary {
        importedInputs.append(input)
        let document = ReadingLibraryDocumentSummary.summary(
            id: "doc-\(storedDocuments.count + 1)",
            spaceID: input.spaceID,
            title: input.title,
            format: input.sourceFormat
        )
        storedDocuments.append(document)
        storedLoadedDocuments[document.id] = .content(
            id: document.id,
            spaceID: input.spaceID,
            title: input.title,
            body: input.body,
            format: input.sourceFormat
        )
        return document
    }

    private func loadDocument(id: String) -> ReadingLibraryDocumentContent? {
        storedLoadedDocuments[id]
    }

    private func updateDocument(_ input: ReadingDocumentUpdateInput) throws -> ReadingLibraryDocumentContent {
        guard var document = storedLoadedDocuments[input.documentID] else {
            throw ReadingLibraryActionError.unavailable
        }
        document.title = input.title
        document.body = input.body
        document.contentRevision += 1
        document.structureVersion += 1
        storedLoadedDocuments[input.documentID] = document
        storedDocuments = storedDocuments.map { summary in
            guard summary.id == input.documentID else { return summary }
            var copy = summary
            copy.title = input.title
            return copy
        }
        return document
    }

    private func softDelete(id: String, spaceID: String) {
        storedDocuments = storedDocuments.map { document in
            guard document.id == id, document.spaceID == spaceID else { return document }
            var copy = document
            copy.libraryStatus = .softDeleted
            return copy
        }
    }

    private func restore(id: String, spaceID: String) {
        storedDocuments = storedDocuments.map { document in
            guard document.id == id, document.spaceID == spaceID else { return document }
            var copy = document
            copy.libraryStatus = .active
            return copy
        }
    }

    private func assignCollection(id: String, spaceID: String, title: String) {
        assignedCollections.append("\(id):\(spaceID):\(title)")
        storedDocuments = storedDocuments.map { document in
            guard document.id == id, document.spaceID == spaceID else { return document }
            var copy = document
            if !copy.collectionTitles.contains(title) {
                copy.collectionTitles.append(title)
            }
            return copy
        }
    }

    private func tag(id: String, spaceID: String, name: String) {
        assignedTags.append("\(id):\(spaceID):\(name)")
        storedDocuments = storedDocuments.map { document in
            guard document.id == id, document.spaceID == spaceID else { return document }
            var copy = document
            if !copy.tagNames.contains(name) {
                copy.tagNames.append(name)
            }
            return copy
        }
    }
}

private actor ControlledReadingLibraryActions {
    private struct PendingList {
        var spaceID: String
        var includeDeleted: Bool
        var continuation: CheckedContinuation<[ReadingLibraryDocumentSummary], Error>
    }

    private var continuations: [PendingList] = []

    nonisolated var actions: ReadingLibraryActions {
        ReadingLibraryActions(
            listDocuments: { [self] spaceID, includeDeleted, _ in
                try await list(spaceID: spaceID, includeDeleted: includeDeleted)
            },
            importPastedText: { _ in
                .summary(id: "unused", spaceID: "unused", title: "unused")
            },
            loadDocument: { _, _ in nil },
            updateDocument: { input in
                .content(
                    id: input.documentID,
                    spaceID: input.spaceID,
                    title: input.title,
                    body: input.body,
                    format: input.sourceFormat
                )
            },
            softDeleteDocument: { _, _ in },
            restoreDocument: { _, _ in },
            markDocumentOpened: { _, _ in },
            assignCollection: { _, _, _ in },
            tagDocument: { _, _, _ in }
        )
    }

    private func list(spaceID: String, includeDeleted: Bool) async throws -> [ReadingLibraryDocumentSummary] {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(PendingList(
                spaceID: spaceID,
                includeDeleted: includeDeleted,
                continuation: continuation
            ))
        }
    }

    func waitForListRequestCount(_ count: Int) async {
        while continuations.count < count {
            await Task.yield()
        }
    }

    func completeNextList(
        spaceID: String,
        includeDeleted: Bool,
        _ documents: [ReadingLibraryDocumentSummary]
    ) {
        guard let index = continuations.firstIndex(where: {
            $0.spaceID == spaceID && $0.includeDeleted == includeDeleted
        }) else {
            return
        }
        continuations.remove(at: index).continuation.resume(returning: documents)
    }
}

private extension ReadingLibraryDocumentSummary {
    static func summary(
        id: String,
        spaceID: String,
        title: String,
        format: ReadingSourceFormat = .plainText
    ) -> ReadingLibraryDocumentSummary {
        ReadingLibraryDocumentSummary(
            id: id,
            spaceID: spaceID,
            title: title,
            sourceFormat: format,
            importStatus: .ready,
            libraryStatus: .active,
            tagNames: [],
            collectionTitles: [],
            lastOpenedAt: nil
        )
    }
}

private extension ReadingLibraryDocumentContent {
    static func content(
        id: String,
        spaceID: String,
        title: String,
        body: String,
        format: ReadingSourceFormat = .markdown
    ) -> ReadingLibraryDocumentContent {
        ReadingLibraryDocumentContent(
            id: id,
            spaceID: spaceID,
            title: title,
            body: body,
            sourceFormat: format,
            targetLanguageCode: "en",
            contentRevision: 1,
            structureVersion: 1
        )
    }
}

private extension LanguageSpacePreview {
    static func preview(id: String, targetLanguageCode: String) -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: id,
            name: "Space \(id)",
            nativeLanguage: "中文",
            targetLanguage: targetLanguageCode,
            targetLanguageCode: targetLanguageCode,
            level: .a2
        )
    }
}

@MainActor
private func waitUntilLibraryCondition(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while !condition(), ContinuousClock.now < deadline {
        await Task.yield()
    }
    return condition()
}
