import LangoTraceCore
import SwiftUI

struct ReadingImportSheetView: View {
    @Binding var importTitle: String
    @Binding var importBody: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
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
                    Button(localizedString("common.close"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("common.save"), action: onSave)
                        .disabled(importBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ReadingLibraryDocumentRow: View {
    let document: ReadingLibraryDocumentSummary
    let onOpen: () -> Void
    var isSelected = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(LangoTraceDesign.ColorToken.surfacePanel)
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.title)
                            .font(.headline)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Text(document.sourceFormat.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(LangoTraceDesign.ColorToken.surfacePanel)
                                .clipShape(.capsule)
                            tagCollectionLine
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                            ? LangoTraceDesign.ColorToken.surfacePanel
                            : LangoTraceDesign.ColorToken.surfaceBase
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected
                            ? LangoTraceDesign.ColorToken.textSecondary
                            : LangoTraceDesign.ColorToken.borderSubtle
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(localizedString("tab.reading"))
    }

    @ViewBuilder
    private var tagCollectionLine: some View {
        let labels = document.collectionTitles + document.tagNames.map { "#\($0)" }
        if labels.isEmpty {
            EmptyView()
        } else {
            Text(labels.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .lineLimit(1)
        }
    }
}

struct ReadingLibraryPane: View {
    @ObservedObject var store: ReadingLibraryStore
    let platform: ReadingPlatformRole
    @Binding var isImportSheetPresented: Bool
    @Binding var isFileImporterPresented: Bool
    @Binding var collectionDrafts: [String: String]
    @Binding var tagDrafts: [String: String]
    let onOpenDocument: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            libraryHeader
            ReadingLibraryFilterControls(store: store)
            documentsList
            deletedDocumentsList
        }
        .padding(20)
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "tab.reading", subtitleKey: "reading.library.subtitle")
            importButtons
            searchField
        }
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

    private var importButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                pasteButton
                importButton
            }
            VStack(alignment: .leading, spacing: 8) {
                pasteButton
                importButton
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
        .controlSize(platform == .mac ? .regular : .large)
    }

    private var importButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            Label(localizedString("reading.library.import.file"), systemImage: "doc.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(platform == .mac ? .regular : .large)
    }

    @ViewBuilder
    private var documentsList: some View {
        if store.filteredDocuments.isEmpty {
            ContentUnavailableView(
                localizedString("reading.library.empty.title"),
                systemImage: "book.closed",
                description: Text(localizedString("reading.library.empty.body"))
            )
        } else {
            List(store.filteredDocuments, id: \.id) { document in
                documentListItem(document)
            }
            .listStyle(.plain)
        }
    }

    private func documentListItem(_ document: ReadingLibraryDocumentSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ReadingLibraryDocumentRow(
                document: document,
                onOpen: {
                    onOpenDocument(document.id)
                },
                isSelected: store.selectedDocument?.id == document.id && platform != .phone
            )
            .contextMenu {
                metadataContextMenu(for: document)
            }
            ReadingLibraryMetadataEditors(
                document: document,
                collectionDrafts: $collectionDrafts,
                tagDrafts: $tagDrafts,
                onSaveCollection: { value in
                    try? await store.assignCollection(documentID: document.id, title: value)
                },
                onSaveTag: { value in
                    try? await store.tagDocument(documentID: document.id, name: value)
                }
            )
        }
    }

    @ViewBuilder
    private func metadataContextMenu(for document: ReadingLibraryDocumentSummary) -> some View {
        Button {
            collectionDrafts[document.id] = collectionDrafts[document.id, default: ""]
        } label: {
            Label(
                localizedString("reading.library.collection.assign"),
                systemImage: "folder.badge.plus"
            )
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

    @ViewBuilder
    private var deletedDocumentsList: some View {
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
}

struct ReadingLibraryFilterControls: View {
    @ObservedObject var store: ReadingLibraryStore

    var body: some View {
        HStack(spacing: 8) {
            ReadingLibraryFilterMenu(
                label: localizedString("reading.library.collection.filter"),
                value: store.selectedCollectionFilter ?? localizedString("reading.library.filter.all"),
                options: store.availableCollectionFilters
            ) { selection in
                store.updateCollectionFilter(selection)
            }

            ReadingLibraryFilterMenu(
                label: localizedString("reading.library.tag.filter"),
                value: store.selectedTagFilter ?? localizedString("reading.library.filter.all"),
                options: store.availableTagFilters
            ) { selection in
                store.updateTagFilter(selection)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ReadingLibraryFilterMenu: View {
    let label: String
    let value: String
    let options: [String]
    let onSelect: (String?) -> Void

    var body: some View {
        Menu {
            Button(localizedString("reading.library.filter.all")) {
                onSelect(nil)
            }
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LangoTraceDesign.ColorToken.surfacePanel)
            .clipShape(.capsule)
        }
    }
}

struct ReadingLibraryMetadataEditors: View {
    let document: ReadingLibraryDocumentSummary
    @Binding var collectionDrafts: [String: String]
    @Binding var tagDrafts: [String: String]
    let onSaveCollection: (String) async -> Void
    let onSaveTag: (String) async -> Void

    var body: some View {
        VStack(spacing: 8) {
            if collectionDrafts[document.id] != nil {
                metadataEditor(
                    placeholderKey: "reading.library.collection.placeholder",
                    value: Binding(
                        get: { collectionDrafts[document.id] ?? "" },
                        set: { collectionDrafts[document.id] = $0 }
                    ),
                    onSave: saveCollection
                )
            }
            if tagDrafts[document.id] != nil {
                metadataEditor(
                    placeholderKey: "reading.library.tag.placeholder",
                    value: Binding(
                        get: { tagDrafts[document.id] ?? "" },
                        set: { tagDrafts[document.id] = $0 }
                    ),
                    onSave: saveTag
                )
            }
        }
    }

    private func saveCollection() {
        let value = collectionDrafts[document.id] ?? ""
        Task {
            await onSaveCollection(value)
            collectionDrafts[document.id] = nil
        }
    }

    private func saveTag() {
        let value = tagDrafts[document.id] ?? ""
        Task {
            await onSaveTag(value)
            tagDrafts[document.id] = nil
        }
    }

    private func metadataEditor(
        placeholderKey: String,
        value: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        HStack {
            TextField(localizedString(placeholderKey), text: value)
            Button(localizedString("common.save"), action: onSave)
        }
    }
}

struct ReadingInspectorPane: View {
    let selection: ReadingSelectionContext?
    let explanationResult: ReadingSelectionExplanationResult?
    var explanationState: ReadingAsyncState = .idle
    var audioState: ReadingAsyncState = .idle
    let onExplain: () -> Void
    let onListen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString("reading.inspector.title"))
                    .font(.headline)
                Text(inspectorSubtitle)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }

            if let selection {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selection.scopeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(selection.selectedText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    Text(selection.contextModeTitle)
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LangoTraceDesign.ColorToken.surfacePanel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 10) {
                    Button(action: onExplain) {
                        Label(localizedString("reading.action.explain"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(explanationState == .loading)

                    Button(action: onListen) {
                        Label(localizedString("common.listen"), systemImage: "speaker.wave.2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(audioState == .loading)

                    Menu {
                        Button(localizedString("reading.action.translate")) {}
                            .disabled(true)
                        Button(localizedString("reading.action.grammar")) {}
                            .disabled(true)
                    } label: {
                        Label(localizedString("reading.action.more"), systemImage: "ellipsis.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }

                explanationBody
            } else {
                emptyBody
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfaceBase)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var explanationBody: some View {
        if explanationState == .loading {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView()
                Text(localizedString("reading.inspector.body"))
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        } else if let explanationResult {
            VStack(alignment: .leading, spacing: 12) {
                Text(explanationResult.shortExplanation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(explanationResult.meaningInNativeLanguage)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        } else if explanationState == .failed {
            VStack(alignment: .leading, spacing: 10) {
                Label(localizedString("reading.inspector.title"), systemImage: "exclamationmark.circle")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(localizedString("reading.inspector.body"))
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        Text(localizedString("reading.inspector.body"))
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
    }

    private var inspectorSubtitle: String {
        if explanationState == .loading {
            return localizedString("reading.library.subtitle")
        }
        return localizedString("reading.inspector.body")
    }
}

struct ReadingCompactLearningPanel: View {
    let selection: ReadingSelectionContext
    let explanationResult: ReadingSelectionExplanationResult?
    let explanationState: ReadingAsyncState
    let audioState: ReadingAsyncState
    let panelState: ReadingCompactLearningPanelState
    let onExplain: () -> Void
    let onListen: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(LangoTraceDesign.ColorToken.borderSubtle)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selection.scopeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(selection.selectedText)
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    Text(selection.contextModeTitle)
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button(action: onExplain) {
                    Label(localizedString("reading.action.explain"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(explanationState == .loading)

                Button(action: onListen) {
                    Label(localizedString("common.listen"), systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(audioState == .loading)

                Menu {
                    Button(localizedString("reading.action.translate")) {}
                        .disabled(true)
                    Button(localizedString("reading.action.grammar")) {}
                        .disabled(true)
                } label: {
                    Label(localizedString("reading.action.more"), systemImage: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }

            Group {
                if panelState == .loading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(localizedString("reading.panel.loading"))
                            .font(.callout)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                } else if panelState == .content, let explanationResult {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(explanationResult.shortExplanation)
                            .font(.callout)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        Text(explanationResult.meaningInNativeLanguage)
                            .font(.callout)
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                } else if panelState == .failed {
                    Text(localizedString("reading.panel.failed"))
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LangoTraceDesign.ColorToken.borderSubtle)
                .frame(height: 1)
        }
    }
}

private extension ReadingSelectionContext {
    var scopeTitle: String {
        switch selectionScope {
        case .sentence:
            localizedString("reading.selection.scope.sentence")
        case .textFragment:
            localizedString("reading.selection.scope.fragment")
        }
    }

    var contextModeTitle: String {
        switch contextMode {
        case .fullDocument:
            localizedString("reading.selection.context.fullDocument")
        case .adjacentParagraphs:
            localizedString("reading.selection.context.adjacentParagraphs")
        case .currentParagraph:
            localizedString("reading.selection.context.currentParagraph")
        }
    }
}

struct ReadingBlockView: View {
    let block: ReadingBlockPresentation
    let style: ReadingPresentationStyle

    var body: some View {
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
}
