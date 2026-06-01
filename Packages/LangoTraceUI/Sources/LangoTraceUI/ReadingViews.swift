import LangoTraceCore
import SwiftUI

struct ReadingLibraryView: View {
    let platform: ReadingPlatformRole
    @ObservedObject var store: ReadingLibraryStore
    let explanationAction: ReadingExplanationAction
    let ttsAction: ReadingTTSAction
    @State private var importTitle = ""
    @State private var importBody = ""
    @State private var isImportSheetPresented = false
    @State private var selectedText: String?
    @State private var selectedSentenceID: String?
    @State private var explanationResult: ReadingSelectionExplanationResult?
    @State private var explanationState: ReadingAsyncState = .idle
    @State private var audioState: ReadingAsyncState = .idle

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

            if store.documents.isEmpty {
                ContentUnavailableView(
                    localizedString("reading.library.empty.title"),
                    systemImage: "book.closed",
                    description: Text(localizedString("reading.library.empty.body"))
                )
            } else {
                List(store.documents, id: \.id) { document in
                    Button {
                        Task { await store.openDocument(document.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                            Text(document.sourceFormat.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await store.softDelete(document.id) }
                        } label: {
                            Label(localizedString("reading.library.delete"), systemImage: "trash")
                        }
                    }
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
        selectedText = block.text
        selectedSentenceID = block.id
        explanationResult = nil
        explanationState = .idle
    }

    private func explainSelectedText() async {
        guard let selectedText, let selectedSentenceID else { return }
        explanationState = .loading
        do {
            explanationResult = try await explanationAction(
                ReadingExplanationRequest(
                    documentID: store.selectedDocument?.id ?? "",
                    spaceID: store.languageSpace.id,
                    selectedText: selectedText,
                    sentenceID: selectedSentenceID,
                    containingSentence: selectedText,
                    contextText: selectedText,
                    nativeLanguageCode: store.languageSpace.nativeLanguageCode,
                    targetLanguageCode: store.languageSpace.targetLanguageCode,
                    proficiencyLevelCode: store.languageSpace.level.rawValue
                )
            )
            explanationState = .idle
        } catch {
            explanationState = .failed
        }
    }

    private func play(_ block: ReadingBlockPresentation) async {
        audioState = .loading
        await ttsAction(
            ReadingTTSRequest(
                documentID: store.selectedDocument?.id ?? "",
                spaceID: store.languageSpace.id,
                sentenceID: block.id,
                text: block.text,
                targetLanguageCode: store.languageSpace.targetLanguageCode
            )
        )
        audioState = .idle
    }
}
