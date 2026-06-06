import LangoTraceCore
import SwiftUI
import UniformTypeIdentifiers

struct ReadingLibraryView: View {
    let platform: ReadingPlatformRole
    @ObservedObject var store: ReadingLibraryStore
    let explanationAction: ReadingExplanationAction
    let ttsAction: ReadingTTSAction
    var onOpenPhoneDocument: ((String) -> Void)?
    @StateObject private var documentStore: ReadingDocumentStore
    @State private var importTitle = ""
    @State private var importBody = ""
    @State private var isImportSheetPresented = false
    @State private var isFileImporterPresented = false
    @State private var collectionDrafts: [String: String] = [:]
    @State private var tagDrafts: [String: String] = [:]

    init(
        platform: ReadingPlatformRole,
        store: ReadingLibraryStore,
        explanationAction: @escaping ReadingExplanationAction,
        ttsAction: @escaping ReadingTTSAction,
        onOpenPhoneDocument: ((String) -> Void)? = nil
    ) {
        self.platform = platform
        self.store = store
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
        self.onOpenPhoneDocument = onOpenPhoneDocument
        _documentStore = StateObject(wrappedValue: ReadingDocumentStore(
            documentID: store.selectedDocument?.id ?? "",
            spaceID: store.languageSpace.id,
            contentRevision: store.selectedDocument?.contentRevision ?? 1,
            nativeLanguageCode: store.languageSpace.nativeLanguageCode,
            targetLanguageCode: store.languageSpace.targetLanguageCode,
            proficiencyLevelCode: store.languageSpace.level.rawValue,
            explanationAction: explanationAction,
            ttsAction: ttsAction
        ))
    }

    var body: some View {
        Group {
            switch platform {
            case .phone:
                phoneLibraryHome
            case .pad, .mac:
                desktopLibraryAndReader
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
        .task(id: documentStoreSyncKey) {
            syncDocumentStore()
        }
        .sheet(isPresented: editorPresentedBinding) {
            if let document = store.selectedDocument {
                ReadingDocumentEditorSheet(
                    title: draftTitleBinding,
                    draftBody: draftBodyBinding,
                    saveState: documentStore.saveState,
                    saveFailure: documentStore.saveFailure,
                    canSave: documentStore.canSaveDraft,
                    sourceFormat: document.sourceFormat,
                    onCancel: { documentStore.cancelEditing() },
                    onSave: { Task { await saveEdits(document) } }
                )
            }
        }
    }

    private var phoneLibraryHome: some View {
        ReadingPhoneLibraryHomeView(
            store: store,
            isImportSheetPresented: $isImportSheetPresented,
            isFileImporterPresented: $isFileImporterPresented,
            onOpenDocument: { documentID in
                Task {
                    await store.openDocument(documentID, platform: .phone)
                    guard store.selectedDocument?.id == documentID else { return }
                    onOpenPhoneDocument?(documentID)
                }
            }
        )
    }

    private var desktopLibraryAndReader: some View {
        let layout = ReadingLayoutModel.platform(platform)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                libraryWorkbenchPane(layout: layout)
                Divider()
                readerWorkbenchPane(layout: layout)
                if layout.showsPersistentInspector {
                    Divider()
                    inspectorWorkbenchPane(layout: layout)
                }
            }
            .background(LangoTraceDesign.ColorToken.surfaceBase)

            VStack(spacing: 0) {
                libraryPane
                Divider()
                readerPane
                if layout.showsPersistentInspector {
                    Divider()
                    inspectorPane
                }
            }
        }
    }

    private func libraryWorkbenchPane(layout: ReadingLayoutModel) -> some View {
        libraryPane
            .frame(width: layout.workspaceStyle == .balancedWorkbench ? 316 : 292)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(LangoTraceDesign.ColorToken.surfaceSidebar)
    }

    private func readerWorkbenchPane(layout: ReadingLayoutModel) -> some View {
        ScrollView {
            readerWorkbenchBody(layout: layout)
                .padding(.horizontal, layout.workspaceStyle == .balancedWorkbench ? 28 : 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LangoTraceDesign.ColorToken.surfaceBase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func inspectorWorkbenchPane(layout: ReadingLayoutModel) -> some View {
        inspectorPane
            .frame(width: layout.workspaceStyle == .balancedWorkbench ? 292 : 268)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(LangoTraceDesign.ColorToken.surfaceInspector)
    }

    private var libraryPane: some View {
        ReadingLibraryPane(
            store: store,
            platform: platform,
            isImportSheetPresented: $isImportSheetPresented,
            isFileImporterPresented: $isFileImporterPresented,
            collectionDrafts: $collectionDrafts,
            tagDrafts: $tagDrafts,
            onOpenDocument: { documentID in
                Task { await store.openDocument(documentID, platform: platform) }
            }
        )
    }

    private var readerPane: some View {
        Group {
            if let document = store.selectedDocument {
                if let presentation = store.selectedPresentation {
                    readerContent(document: document, presentation: presentation, includeOuterPadding: true)
                } else {
                    ReadingReaderEmptyState()
                }
            } else {
                ReadingReaderEmptyState()
            }
        }
    }

    private func readerWorkbenchBody(layout: ReadingLayoutModel) -> some View {
        Group {
            if let document = store.selectedDocument {
                if let presentation = store.selectedPresentation {
                    readerContent(document: document, presentation: presentation, includeOuterPadding: false)
                } else {
                    ReadingReaderEmptyState()
                        .frame(
                            maxWidth: layout.workspaceStyle == .balancedWorkbench ? 780 : 720,
                            minHeight: layout.workspaceStyle == .balancedWorkbench ? 460 : 420,
                            alignment: .center
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ReadingReaderEmptyState()
                    .frame(
                        maxWidth: layout.workspaceStyle == .balancedWorkbench ? 780 : 720,
                        minHeight: layout.workspaceStyle == .balancedWorkbench ? 460 : 420,
                        alignment: .center
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func readerContent(
        document: ReadingLibraryDocumentContent,
        presentation: ReadingDocumentPresentation,
        includeOuterPadding: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ReadingDocumentHeader(document: document) {
                documentStore.beginEditing(document: document)
            }
            ReadingDocumentCanvas(
                presentation: presentation,
                selectedSelection: documentStore.selectedSelection,
                onSelectFragment: { text, block, offset, length in
                    documentStore.selectTextFragment(
                        selectedText: text,
                        blockID: block.id,
                        characterOffset: offset,
                        characterLength: length,
                        sentencePresentations: block.sentences,
                        blockText: block.text
                    )
                },
                onClearSelection: {
                    documentStore.clearSelection()
                }
            )
        }
        .padding(includeOuterPadding ? 24 : 28)
        .frame(maxWidth: presentation.style.readingWidth.points + 56, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfacePanel)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inspectorPane: some View {
        ReadingInspectorPane(
            selection: documentStore.selectedSelection,
            explanationResult: documentStore.explanationResult,
            explanationState: documentStore.explanationState,
            audioState: documentStore.audioState,
            onExplain: { documentStore.explainSelection() },
            onListen: { documentStore.playSelectionSentence() }
        )
    }

    private var documentStoreSyncKey: String {
        let selectedID = store.selectedDocument?.id ?? "none"
        let revision = store.selectedDocument?.contentRevision ?? 0
        return "\(store.languageSpace.id)|\(selectedID)|\(revision)"
    }

    private var editorPresentedBinding: Binding<Bool> {
        Binding(
            get: { documentStore.isEditorPresented },
            set: { presented in
                if !presented {
                    documentStore.cancelEditing()
                }
            }
        )
    }

    private var draftTitleBinding: Binding<String> {
        Binding(
            get: { documentStore.draftTitle },
            set: { documentStore.updateDraft(title: $0, body: documentStore.draftBody) }
        )
    }

    private var draftBodyBinding: Binding<String> {
        Binding(
            get: { documentStore.draftBody },
            set: { documentStore.updateDraft(title: documentStore.draftTitle, body: $0) }
        )
    }

    private func syncDocumentStore() {
        if let document = store.selectedDocument {
            documentStore.replaceDocument(
                documentID: document.id,
                spaceID: document.spaceID,
                contentRevision: document.contentRevision
            )
        } else {
            documentStore.replaceDocument(documentID: "", spaceID: store.languageSpace.id, contentRevision: 1)
        }
    }

    private func saveEdits(_ document: ReadingLibraryDocumentContent) async {
        do {
            documentStore.markSavingEdit()
            let input = try ReadingDocumentUpdateInput(
                documentID: document.id,
                spaceID: document.spaceID,
                title: documentStore.draftTitle,
                body: documentStore.draftBody,
                sourceFormat: document.sourceFormat
            )
            let updated = try await store.saveDocumentEdits(input, platform: platform)
            documentStore.completeSavingEdit(with: updated)
        } catch {
            documentStore.failSavingEdit(error)
        }
    }
}

struct ReadingDocumentDetailView: View {
    let platform: ReadingPlatformRole
    let documentID: String
    @ObservedObject var store: ReadingLibraryStore
    let explanationAction: ReadingExplanationAction
    let ttsAction: ReadingTTSAction
    @StateObject private var documentStore: ReadingDocumentStore

    init(
        platform: ReadingPlatformRole,
        documentID: String,
        store: ReadingLibraryStore,
        explanationAction: @escaping ReadingExplanationAction,
        ttsAction: @escaping ReadingTTSAction
    ) {
        self.platform = platform
        self.documentID = documentID
        self.store = store
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
        _documentStore = StateObject(wrappedValue: ReadingDocumentStore(
            documentID: documentID,
            spaceID: store.languageSpace.id,
            contentRevision: store.selectedDocument?.contentRevision ?? 1,
            nativeLanguageCode: store.languageSpace.nativeLanguageCode,
            targetLanguageCode: store.languageSpace.targetLanguageCode,
            proficiencyLevelCode: store.languageSpace.level.rawValue,
            explanationAction: explanationAction,
            ttsAction: ttsAction
        ))
    }

    var body: some View {
        Group {
            if activeDocument != nil {
                if let presentation = activePresentation {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ReadingDocumentCanvas(
                                presentation: presentation,
                                selectedSelection: documentStore.selectedSelection,
                                onSelectFragment: { text, block, offset, length in
                                    documentStore.selectTextFragment(
                                        selectedText: text,
                                        blockID: block.id,
                                        characterOffset: offset,
                                        characterLength: length,
                                        sentencePresentations: block.sentences,
                                        blockText: block.text
                                    )
                                },
                                onClearSelection: {
                                    documentStore.clearSelection()
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: presentation.style.readingWidth.points, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(activeDocument?.title ?? localizedString("tab.reading"))
        .readingInlineTitleDisplayMode()
        .task(id: documentID) {
            if activeDocument?.id != documentID {
                await store.openDocument(documentID, platform: platform)
            }
        }
        .task(id: detailDocumentSyncKey) {
            syncDetailDocumentStore()
        }
        .toolbar {
            if let document = activeDocument {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        documentStore.beginEditing(document: document)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(localizedString("settings.languageSpace.management.edit"))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let selection = documentStore.selectedSelection,
               documentStore.compactLearningPanelState != .hidden
            {
                ReadingCompactLearningPanel(
                    selection: selection,
                    explanationResult: documentStore.explanationResult,
                    explanationState: documentStore.explanationState,
                    audioState: documentStore.audioState,
                    panelState: documentStore.compactLearningPanelState,
                    onExplain: { documentStore.explainSelection() },
                    onListen: { documentStore.playSelectionSentence() },
                    onClear: { documentStore.clearSelection() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.22), value: documentStore.compactLearningPanelState)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: documentStore.selectedSelection != nil)
        .sheet(isPresented: editorPresentedBinding) {
            if let document = activeDocument {
                ReadingDocumentEditorSheet(
                    title: draftTitleBinding,
                    draftBody: draftBodyBinding,
                    saveState: documentStore.saveState,
                    saveFailure: documentStore.saveFailure,
                    canSave: documentStore.canSaveDraft,
                    sourceFormat: document.sourceFormat,
                    onCancel: { documentStore.cancelEditing() },
                    onSave: { Task { await saveDetailEdits(document) } }
                )
            }
        }
    }

    private var activeDocument: ReadingLibraryDocumentContent? {
        guard store.selectedDocument?.id == documentID else { return nil }
        return store.selectedDocument
    }

    private var activePresentation: ReadingDocumentPresentation? {
        guard activeDocument != nil else { return nil }
        return store.selectedPresentation
    }

    private var detailDocumentSyncKey: String {
        let revision = activeDocument?.contentRevision ?? 0
        return "\(store.languageSpace.id)|\(documentID)|\(revision)"
    }

    private var editorPresentedBinding: Binding<Bool> {
        Binding(
            get: { documentStore.isEditorPresented },
            set: { presented in
                if !presented {
                    documentStore.cancelEditing()
                }
            }
        )
    }

    private var draftTitleBinding: Binding<String> {
        Binding(
            get: { documentStore.draftTitle },
            set: { documentStore.updateDraft(title: $0, body: documentStore.draftBody) }
        )
    }

    private var draftBodyBinding: Binding<String> {
        Binding(
            get: { documentStore.draftBody },
            set: { documentStore.updateDraft(title: documentStore.draftTitle, body: $0) }
        )
    }

    private func syncDetailDocumentStore() {
        if let document = activeDocument {
            documentStore.replaceDocument(
                documentID: document.id,
                spaceID: document.spaceID,
                contentRevision: document.contentRevision
            )
        }
    }

    private func saveDetailEdits(_ document: ReadingLibraryDocumentContent) async {
        do {
            documentStore.markSavingEdit()
            let input = try ReadingDocumentUpdateInput(
                documentID: document.id,
                spaceID: document.spaceID,
                title: documentStore.draftTitle,
                body: documentStore.draftBody,
                sourceFormat: document.sourceFormat
            )
            let updated = try await store.saveDocumentEdits(input, platform: platform)
            documentStore.completeSavingEdit(with: updated)
        } catch {
            documentStore.failSavingEdit(error)
        }
    }
}

private struct ReadingPhoneLibraryHomeView: View {
    @ObservedObject var store: ReadingLibraryStore
    @Binding var isImportSheetPresented: Bool
    @Binding var isFileImporterPresented: Bool
    let onOpenDocument: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if showsEmptyLibraryState {
                    ReadingEmptyLibraryCard(
                        onPaste: { isImportSheetPresented = true },
                        onImportFile: { isFileImporterPresented = true }
                    )
                } else {
                    actionsBar
                    searchField
                    filterControls
                    documentList
                    deletedDocuments
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationTitle(localizedString("tab.reading"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("tab.reading"))
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            Text(localizedString("reading.library.subtitle"))
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
    }

    private var actionsBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pasteButton
                importFileButton
            }
            VStack(alignment: .leading, spacing: 10) {
                pasteButton
                importFileButton
            }
        }
    }

    private var pasteButton: some View {
        Button {
            isImportSheetPresented = true
        } label: {
            Label(localizedString("reading.library.import.paste"), systemImage: "doc.on.clipboard")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var importFileButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            Label(localizedString("reading.library.import.file"), systemImage: "doc.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var searchField: some View {
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
    }

    private var filterControls: some View {
        ReadingLibraryFilterControls(store: store)
    }

    private var documentList: some View {
        Group {
            if store.filteredDocuments.isEmpty {
                ContentUnavailableView(
                    localizedString("reading.library.empty.title"),
                    systemImage: "book.closed",
                    description: Text(localizedString("reading.library.empty.body"))
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.filteredDocuments, id: \.id) { document in
                        ReadingLibraryDocumentRow(document: document) {
                            onOpenDocument(document.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deletedDocuments: some View {
        if !store.deletedDocuments.isEmpty {
            DisclosureGroup(localizedString("reading.library.deleted")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.deletedDocuments, id: \.id) { document in
                        HStack {
                            Text(document.title)
                                .font(.callout)
                            Spacer()
                            Button {
                                Task { await store.restore(document.id) }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(localizedString("reading.library.restore"))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.top, 4)
        }
    }

    private var showsEmptyLibraryState: Bool {
        store.documents.isEmpty
            && store.deletedDocuments.isEmpty
            && store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.selectedCollectionFilter == nil
            && store.selectedTagFilter == nil
    }
}

private struct ReadingDocumentHeader: View {
    let document: ReadingLibraryDocumentContent
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(document.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Text(document.sourceFormat.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LangoTraceDesign.ColorToken.surfaceMuted)
                        .clipShape(.capsule)
                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(localizedString("settings.languageSpace.management.edit"))
                    }
                }
            }

            HStack(spacing: 8) {
                Label(storeLine, systemImage: "globe")
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
    }

    private var storeLine: String {
        document.targetLanguageCode.uppercased()
    }
}

private struct ReadingDocumentEditorSheet: View {
    @Binding var title: String
    @Binding var draftBody: String
    let saveState: ReadingAsyncState
    let saveFailure: ReadingDocumentSaveFailure?
    let canSave: Bool
    let sourceFormat: ReadingSourceFormat
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(localizedString("entryEditor.titleField"), text: $title)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $draftBody)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 320)
                    .background(LangoTraceDesign.ColorToken.surfacePanel)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                HStack {
                    Text(sourceFormat.rawValue)
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Spacer()
                    if let saveFailure {
                        Text(localizedString(saveFailure.messageKey))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(20)
            .navigationTitle(localizedString("settings.languageSpace.management.editTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("common.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("common.save"), action: onSave)
                        .disabled(saveState == .loading || !canSave)
                }
            }
        }
    }
}

private struct ReadingDocumentCanvas: View {
    let presentation: ReadingDocumentPresentation
    let selectedSelection: ReadingSelectionContext?
    var onSelectFragment: (String, ReadingBlockPresentation, Int, Int) -> Void
    var onClearSelection: () -> Void
    @State private var blockHeights: [String: CGFloat] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: presentation.style.paragraphSpacing) {
            ForEach(presentation.blocks, id: \.id) { block in
                if block.sentences.isEmpty {
                    ReadingBlockView(block: block, style: presentation.style)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    selectableBlock(block)
                }
            }
        }
    }

    private func selectableBlock(_ block: ReadingBlockPresentation) -> some View {
        let committedRange: NSRange? = {
            guard let sel = selectedSelection, sel.blockID == block.id else { return nil }
            let text = block.text
            guard
                let startIdx = text.index(
                    text.startIndex,
                    offsetBy: sel.characterOffset,
                    limitedBy: text.endIndex
                ),
                let endIdx = text.index(
                    startIdx,
                    offsetBy: sel.characterLength,
                    limitedBy: text.endIndex
                )
            else { return nil }
            return NSRange(startIdx ..< endIdx, in: text)
        }()

        return ReadingSelectableTextView(
            blockText: block.text,
            blockKind: block.kind,
            inlineRuns: block.inlineRuns,
            lineSpacing: presentation.style.lineSpacing,
            committedHighlightRange: committedRange,
            onSelectionChange: { text, offset, length in
                onSelectFragment(text, block, offset, length)
            },
            onSelectionCleared: {
                onClearSelection()
            },
            height: Binding(
                get: { blockHeights[block.id, default: 44] },
                set: { blockHeights[block.id] = $0 }
            )
        )
        .frame(height: blockHeights[block.id, default: 44])
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct ReadingEmptyLibraryCard: View {
    let onPaste: () -> Void
    let onImportFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .frame(width: 52, height: 52)
                .background(LangoTraceDesign.ColorToken.surfacePanel)
                .clipShape(.circle)
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("reading.library.empty.title"))
                    .font(.title3.weight(.semibold))
                Text(localizedString("reading.library.empty.body"))
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Button(action: onPaste) {
                    Label(localizedString("reading.library.import.paste"), systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onImportFile) {
                    Label(localizedString("reading.library.import.file"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfaceBase)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ReadingReaderEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.title2)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .frame(width: 52, height: 52)
                .background(LangoTraceDesign.ColorToken.surfacePanel)
                .clipShape(.circle)
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("reading.library.empty.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(localizedString("reading.inspector.body"))
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfacePanel)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension View {
    @ViewBuilder
    func readingInlineTitleDisplayMode() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
