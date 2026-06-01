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
            ReadingImportSheetView(
                importTitle: $importTitle,
                importBody: $importBody,
                onCancel: {
                    isImportSheetPresented = false
                },
                onSave: {
                    Task {
                        try? await store.importPastedText(title: importTitle, body: importBody)
                        importTitle = ""
                        importBody = ""
                        isImportSheetPresented = false
                    }
                }
            )
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
        ReadingLibraryPane(
            store: store,
            isImportSheetPresented: $isImportSheetPresented,
            isFileImporterPresented: $isFileImporterPresented,
            collectionDrafts: $collectionDrafts,
            tagDrafts: $tagDrafts
        )
    }

    private var readerPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: activePresentation.style.paragraphSpacing) {
                ForEach(activePresentation.blocks, id: \.id) { block in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            select(block)
                        } label: {
                            ReadingBlockView(block: block, style: activePresentation.style)
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
        ReadingInspectorPane(
            selectedText: selectedText,
            explanationResult: explanationResult
        )
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
            guard isCurrentSelection(
                token: token,
                text: selectedText,
                sentenceID: selectedSentenceID,
                documentID: documentID,
                spaceID: spaceID
            ) else { return }
            explanationResult = result
            explanationState = .idle
        } catch {
            guard isCurrentSelection(
                token: token,
                text: selectedText,
                sentenceID: selectedSentenceID,
                documentID: documentID,
                spaceID: spaceID
            ) else { return }
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
        guard isCurrentSelection(
            token: token,
            text: block.text,
            sentenceID: block.id,
            documentID: documentID,
            spaceID: spaceID
        ) else { return }
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
