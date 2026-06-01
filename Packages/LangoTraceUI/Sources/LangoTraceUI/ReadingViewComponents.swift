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

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                Text(document.sourceFormat.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                tagCollectionLine
            }
        }
    }

    @ViewBuilder
    private var tagCollectionLine: some View {
        let labels = document.collectionTitles + document.tagNames.map { "#\($0)" }
        if !labels.isEmpty {
            Text(labels.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct ReadingLibraryPane: View {
    @ObservedObject var store: ReadingLibraryStore
    @Binding var isImportSheetPresented: Bool
    @Binding var isFileImporterPresented: Bool
    @Binding var collectionDrafts: [String: String]
    @Binding var tagDrafts: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(titleKey: "tab.reading", subtitleKey: "reading.library.subtitle")
            searchField
            importButtons
            ReadingLibraryFilterControls(store: store)
            documentsList
            deletedDocumentsList
        }
        .padding(20)
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
        VStack(alignment: .leading, spacing: 8) {
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
        }
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
            ReadingLibraryDocumentRow(document: document) {
                Task { await store.openDocument(document.id) }
            }
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
    let selectedText: String?
    let explanationResult: ReadingSelectionExplanationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("reading.inspector.title"))
                .font(.headline)
            if let selectedText {
                Text(selectedText)
                    .font(.callout.weight(.semibold))
                explanationBody
            } else {
                emptyBody
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var explanationBody: some View {
        if let explanationResult {
            Text(explanationResult.shortExplanation)
                .font(.callout)
            Text(explanationResult.meaningInNativeLanguage)
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            emptyBody
        }
    }

    private var emptyBody: some View {
        Text(localizedString("reading.inspector.body"))
            .font(.callout)
            .foregroundStyle(.secondary)
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
