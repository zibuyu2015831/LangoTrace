import LangoTraceCore
import SwiftUI
import UniformTypeIdentifiers

struct ReadingLibraryView: View {
    let platform: ReadingPlatformRole
    @ObservedObject var store: ReadingLibraryStore
    let explanationAction: ReadingExplanationAction
    let ttsAction: ReadingTTSAction
    @State private var importTitle = ""
    @State private var importBody = ""
    @State private var isImportSheetPresented = false
    @State private var isFileImporterPresented = false
    @State private var selectedText: String?
    @State private var selectedSentenceID: String?
    @State private var explanationResult: ReadingSelectionExplanationResult?
    @State private var explanationState: ReadingAsyncState = .idle
    @State private var audioState: ReadingAsyncState = .idle
    @State private var selectionGeneration = 0
    @State private var collectionDrafts: [String: String] = [:]
    @State private var tagDrafts: [String: String] = [:]

    private var activePresentation: ReadingDocumentPresentation {
        if let selectedPresentation = store.selectedPresentation {
            return selectedPresentation
        }
        let markdown = """
        # Reading

        Import pasted text, `.txt`, or Markdown documents into the local reading library.

        > AI explanation and TTS are explicit actions for the selected text or sentence.
        """
        return ReadingMarkdownBlockRenderer.render(
            document: ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown),
            appearance: .default,
            platform: platform
        )
    }

    var body: some View {
        Group {
            switch platform {
            case .phone:
                NavigationStack {
                    libraryAndReader
                        .navigationTitle(localizedString("tab.reading"))
                }
            case .pad, .mac:
                libraryAndReader
            }
        }
        .sheet(isPresented: $isImportSheetPresented) {
            importSheet
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            Task { try? await store.importFile(url: url) }
        }
        .task {
            await store.reload()
        }
    }

    private var libraryAndReader: some View {
        let layout = ReadingLayoutModel.platform(platform)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                libraryPane
                    .frame(width: platform == .mac ? 300 : 280)
                Divider()
                readerPane
                    .frame(maxWidth: .infinity, alignment: .leading)
                if layout.primaryColumnCount == 3 {
                    Divider()
                    inspectorPane
                        .frame(width: 260)
                }
            }
            VStack(spacing: 0) {
                libraryPane
                Divider()
                readerPane
                Divider()
                inspectorPane
            }
        }
    }

    private var libraryPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "tab.reading", subtitleKey: "reading.library.subtitle")
            TextField(
                localizedString("reading.library.search.placeholder"),
                text: Binding(
                    get: { store.searchText },
                    set: { value in
                        Task { await store.updateSearchText(value) }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            Button {
                isImportSheetPresented = true
            } label: {
                Label(localizedString("reading.library.import.paste"), systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)

            Button {
                isFileImporterPresented = true
            } label: {
                Label(localizedString("reading.library.import.file"), systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)

            libraryFilters

            if store.filteredDocuments.isEmpty {
                ContentUnavailableView(
                    localizedString("reading.library.empty.title"),
                    systemImage: "book.closed",
                    description: Text(localizedString("reading.library.empty.body"))
                )
            } else {
                List(store.filteredDocuments, id: \.id) { document in
                    Button {
                        Task { await store.openDocument(document.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                            Text(document.sourceFormat.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            tagCollectionLine(document)
                        }
                    }
                    .contextMenu {
                        Button {
                            collectionDrafts[document.id] = collectionDrafts[document.id, default: ""]
                        } label: {
                            Label(localizedString("reading.library.collection.assign"), systemImage: "folder.badge.plus")
                        }
                        Button {
                            tagDrafts[document.id] = tagDrafts[document.id, default: ""]
                        } label: {
                            Label(localizedString("reading.library.tag.assign"), systemImage: "tag")
                        }
                        Button(role: .destructive) {
                            Task { await store.softDelete(document.id) }
                        } label: {
                            Label(localizedString("reading.library.delete"), systemImage: "trash")
                        }
                    }
                    inlineMetadataEditors(document)
                }
                .listStyle(.plain)
            }

            if !store.deletedDocuments.isEmpty {
                DisclosureGroup(localizedString("reading.library.deleted")) {
                    ForEach(store.deletedDocuments, id: \.id) { document in
                        HStack {
                            Text(document.title)
                            Spacer()
                            Button {
                                Task { await store.restore(document.id) }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(localizedString("reading.library.restore"))
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private var libraryFilters: some View {
        HStack(spacing: 8) {
            Picker(
                localizedString("reading.library.collection.filter"),
                selection: Binding(
                    get: { store.selectedCollectionFilter ?? "" },
                    set: { store.updateCollectionFilter($0.isEmpty ? nil : $0) }
                )
            ) {
                Text(localizedString("reading.library.filter.all")).tag("")
                ForEach(store.availableCollectionFilters, id: \.self) { title in
                    Text(title).tag(title)
                }
            }
            .pickerStyle(.menu)

            Picker(
                localizedString("reading.library.tag.filter"),
                selection: Binding(
                    get: { store.selectedTagFilter ?? "" },
                    set: { store.updateTagFilter($0.isEmpty ? nil : $0) }
                )
            ) {
                Text(localizedString("reading.library.filter.all")).tag("")
                ForEach(store.availableTagFilters, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var readerPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: activePresentation.style.paragraphSpacing) {
                ForEach(activePresentation.blocks, id: \.id) { block in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            select(block)
                        } label: {
                            readingBlock(block, style: activePresentation.style)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        if selectedSentenceID == block.id {
                            HStack(spacing: 8) {
                                Button {
                                    Task { await explainSelectedText() }
                                } label: {
                                    Label(localizedString("reading.action.explain"), systemImage: "sparkles")
                                }
                                .disabled(explanationState == .loading)

                                Button {
                                    Task { await play(block) }
                                } label: {
                                    Label(localizedString("common.listen"), systemImage: "speaker.wave.2")
                                }
                                .disabled(audioState == .loading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: activePresentation.style.readingWidth.points, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("reading.inspector.title"))
                .font(.headline)
            if let selectedText {
                Text(selectedText)
                    .font(.callout.weight(.semibold))
                if let explanationResult {
                    Text(explanationResult.shortExplanation)
                        .font(.callout)
                    Text(explanationResult.meaningInNativeLanguage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(localizedString("reading.inspector.body"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(localizedString("reading.inspector.body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(localizedString("reading.import.title.placeholder"), text: $importTitle)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $importBody)
                    .frame(minHeight: 220)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LangoTraceDesign.ColorToken.borderSubtle)
                    }
                Spacer()
            }
            .padding(20)
            .navigationTitle(localizedString("reading.library.import.paste"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("common.close")) {
                        isImportSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("common.save")) {
                        Task {
                            try? await store.importPastedText(title: importTitle, body: importBody)
                            importTitle = ""
                            importBody = ""
                            isImportSheetPresented = false
                        }
                    }
                    .disabled(importBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func tagCollectionLine(_ document: ReadingLibraryDocumentSummary) -> some View {
        let labels = document.collectionTitles + document.tagNames.map { "#\($0)" }
        if !labels.isEmpty {
            Text(labels.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func inlineMetadataEditors(_ document: ReadingLibraryDocumentSummary) -> some View {
        if collectionDrafts[document.id] != nil {
            HStack {
                TextField(
                    localizedString("reading.library.collection.placeholder"),
                    text: Binding(
                        get: { collectionDrafts[document.id] ?? "" },
                        set: { collectionDrafts[document.id] = $0 }
                    )
                )
                Button(localizedString("common.save")) {
                    let value = collectionDrafts[document.id] ?? ""
                    Task {
                        try? await store.assignCollection(documentID: document.id, title: value)
                        collectionDrafts[document.id] = nil
                    }
                }
            }
        }
        if tagDrafts[document.id] != nil {
            HStack {
                TextField(
                    localizedString("reading.library.tag.placeholder"),
                    text: Binding(
                        get: { tagDrafts[document.id] ?? "" },
                        set: { tagDrafts[document.id] = $0 }
                    )
                )
                Button(localizedString("common.save")) {
                    let value = tagDrafts[document.id] ?? ""
                    Task {
                        try? await store.tagDocument(documentID: document.id, name: value)
                        tagDrafts[document.id] = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func readingBlock(_ block: ReadingBlockPresentation, style: ReadingPresentationStyle) -> some View {
        switch block.kind {
        case let .heading(level):
            Text(block.text)
                .font(level == 1 ? .title2.weight(.semibold) : .headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
        case .blockquote:
            Text(block.text)
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(LangoTraceDesign.ColorToken.borderSubtle)
                        .frame(width: 3)
                }
        case .codeBlock:
            Text(block.text)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(LangoTraceDesign.ColorToken.surfacePanel)
                .clipShape(.rect(cornerRadius: 8))
        default:
            Text(block.text)
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .lineSpacing(style.lineSpacing)
        }
    }

    private func select(_ block: ReadingBlockPresentation) {
        selectionGeneration += 1
        selectedText = block.text
        selectedSentenceID = block.id
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
    }

    private func explainSelectedText() async {
        guard let selectedText, let selectedSentenceID else { return }
        selectionGeneration += 1
        let token = selectionGeneration
        let documentID = store.selectedDocument?.id ?? ""
        let spaceID = store.languageSpace.id
        explanationState = .loading
        do {
            let result = try await explanationAction(
                ReadingExplanationRequest(
                    documentID: documentID,
                    spaceID: spaceID,
                    selectedText: selectedText,
                    sentenceID: selectedSentenceID,
                    containingSentence: selectedText,
                    contextText: selectedText,
                    nativeLanguageCode: store.languageSpace.nativeLanguageCode,
                    targetLanguageCode: store.languageSpace.targetLanguageCode,
                    proficiencyLevelCode: store.languageSpace.level.rawValue
                )
            )
            guard isCurrentSelection(token: token, text: selectedText, sentenceID: selectedSentenceID, documentID: documentID, spaceID: spaceID) else { return }
            explanationResult = result
            explanationState = .idle
        } catch {
            guard isCurrentSelection(token: token, text: selectedText, sentenceID: selectedSentenceID, documentID: documentID, spaceID: spaceID) else { return }
            explanationState = .failed
        }
    }

    private func play(_ block: ReadingBlockPresentation) async {
        selectionGeneration += 1
        let token = selectionGeneration
        let documentID = store.selectedDocument?.id ?? ""
        let spaceID = store.languageSpace.id
        audioState = .loading
        await ttsAction(
            ReadingTTSRequest(
                documentID: documentID,
                spaceID: spaceID,
                sentenceID: block.id,
                text: block.text,
                targetLanguageCode: store.languageSpace.targetLanguageCode
            )
        )
        guard isCurrentSelection(token: token, text: block.text, sentenceID: block.id, documentID: documentID, spaceID: spaceID) else { return }
        audioState = .idle
    }

    private func isCurrentSelection(
        token: Int,
        text: String,
        sentenceID: String,
        documentID: String,
        spaceID: String
    ) -> Bool {
        token == selectionGeneration
            && selectedText == text
            && selectedSentenceID == sentenceID
            && (store.selectedDocument?.id ?? "") == documentID
            && store.languageSpace.id == spaceID
    }
}
