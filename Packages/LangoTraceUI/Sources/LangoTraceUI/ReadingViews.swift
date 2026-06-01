import LangoTraceCore
import SwiftUI

struct ReadingLibraryView: View {
    let platform: ReadingPlatformRole
    @ObservedObject var store: ReadingLibraryStore
    @State private var importTitle = ""
    @State private var importBody = ""
    @State private var isImportSheetPresented = false

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
                    readingBlock(block, style: activePresentation.style)
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
            Text(localizedString("reading.inspector.body"))
                .font(.callout)
                .foregroundStyle(.secondary)
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
}
