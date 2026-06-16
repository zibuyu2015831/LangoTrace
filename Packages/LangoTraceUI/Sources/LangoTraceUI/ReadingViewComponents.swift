import LangoTraceCore
import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

private func copyToPasteboard(_ text: String) {
    #if canImport(UIKit)
        UIPasteboard.general.string = text
    #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    #endif
}

struct ReadingImportSheetView: View {
    @Binding var importTitle: String
    @Binding var importBody: String
    var errorTextKey: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(localizedString("reading.import.title.placeholder"), text: $importTitle)
                    .langoTextFieldStyle()
                TextEditor(text: $importBody)
                    .frame(minHeight: 220)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LangoTraceDesign.ColorToken.borderSubtle)
                    }
                if let errorTextKey {
                    Label {
                        Text(localizedString(errorTextKey))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
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
                            Text(document.sourceFormat.displayName)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? LangoTraceDesign.ColorToken.surfacePanel
                            : LangoTraceDesign.ColorToken.surfaceBase
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                            ? LangoTraceDesign.ColorToken.accent.opacity(0.4)
                            : LangoTraceDesign.ColorToken.borderSubtle
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: isSelected ? Color.clear : LangoTraceDesign.ColorToken.shadow,
                radius: 4,
                x: 0,
                y: 1
            )
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
            if store.importState == .failed {
                Label {
                    Text(localizedString("reading.import.error.generic"))
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
            }
            searchField
        }
    }

    private var searchField: some View {
        TextField(
            localizedString("reading.library.search.placeholder"),
            text: Binding(
                get: { store.searchText },
                set: { value in
                    store.updateSearchText(value)
                }
            )
        )
        .langoTextFieldStyle()
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
        .buttonStyle(.bordered)
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

private struct ReadingActionPill: View {
    let titleKey: String
    let systemImage: String
    let isPrimary: Bool
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            pillContent
                .foregroundStyle(foregroundColor)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isPrimary ? Color.clear : LangoTraceDesign.ColorToken.borderSubtle,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var pillContent: some View {
        if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .tint(foregroundColor)
                Text(localizedString(titleKey))
            }
        } else {
            Label(localizedString(titleKey), systemImage: systemImage)
        }
    }

    private var foregroundColor: Color {
        if isPrimary { return LangoTraceDesign.ColorToken.primaryActionForeground }
        return LangoTraceDesign.ColorToken.accent
    }

    private var backgroundColor: Color {
        isPrimary ? LangoTraceDesign.ColorToken.primaryActionFill : LangoTraceDesign.ColorToken.surfaceAccentMuted
    }
}

struct ReadingInspectorPane: View {
    let selection: ReadingSelectionContext?
    let explanationResult: ReadingSelectionExplanationResult?
    var explanationState: ReadingAsyncState = .idle
    var audioState: ReadingAsyncState = .idle
    var explanationSource: ExplanationResultSource?
    let onExplain: () -> Void
    let onListen: () -> Void
    var onRegenerate: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("reading.inspector.title"))
                    .font(.headline)
                if selection == nil {
                    Text(localizedString("reading.inspector.body"))
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
            }

            if let selection {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(selection.scopeTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                            .clipShape(Capsule())
                        if explanationSource == .cache {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.caption2)
                                Text(localizedString("reading.explanation.source.cached"))
                                    .font(.caption2)
                            }
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        }
                        Spacer()
                    }
                    Text(selection.selectedText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .lineLimit(4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LangoTraceDesign.ColorToken.surfaceSelected)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 10) {
                    ReadingActionPill(
                        titleKey: "reading.action.explain",
                        systemImage: "sparkles",
                        isPrimary: true,
                        isLoading: explanationState == .loading,
                        action: onExplain
                    )
                    ReadingActionPill(
                        titleKey: "common.listen",
                        systemImage: "speaker.wave.2",
                        isPrimary: false,
                        isLoading: audioState == .loading,
                        action: onListen
                    )
                    if explanationSource == .cache, let onRegenerate {
                        ReadingActionPill(
                            titleKey: "reading.explanation.regenerate",
                            systemImage: "arrow.clockwise",
                            isPrimary: false,
                            action: onRegenerate
                        )
                    }
                    Spacer(minLength: 0)
                }

                ReadingExplanationResultView(
                    result: explanationResult,
                    state: explanationState
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LangoTraceDesign.ColorToken.surfaceBase)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Transient copy button

/// Icon-only copy button that briefly switches to a checkmark on success.
/// Conforms to the §4.19 transient icon confirmation pattern: 1.5 s success
/// state, `.snappy` animation, `.symbolEffect(.replace)` icon transition,
/// accent color in success state, re-trigger guard.
private struct ReadingCopyButton: View {
    let text: String
    @State private var isCopied = false

    var body: some View {
        Button {
            guard !isCopied else { return }
            copyToPasteboard(text)
            withAnimation(.snappy) { isCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.snappy) { isCopied = false }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(
                    isCopied
                        ? LangoTraceDesign.ColorToken.accent
                        : LangoTraceDesign.ColorToken.textSecondary
                )
                .frame(width: 28, height: 28)
                .background(
                    isCopied
                        ? LangoTraceDesign.ColorToken.surfaceAccentMuted
                        : LangoTraceDesign.ColorToken.surfaceMuted
                )
                .clipShape(.circle)
                .contentTransition(.symbolEffect(.replace))
                // Keep the 28pt visual while extending the hit area to the minimum touch target.
                .frame(
                    width: LangoTraceDesign.Density.minimumTouchTarget,
                    height: LangoTraceDesign.Density.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isCopied
                ? localizedString("common.copied")
                : localizedString("common.copy")
        )
    }
}

struct ReadingCompactLearningPanel: View {
    let selection: ReadingSelectionContext
    let explanationResult: ReadingSelectionExplanationResult?
    let explanationState: ReadingAsyncState
    let audioState: ReadingAsyncState
    let panelState: ReadingCompactLearningPanelState
    var explanationSource: ExplanationResultSource?
    let onExplain: () -> Void
    let onListen: () -> Void
    let onClear: () -> Void
    var onRegenerate: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(LangoTraceDesign.ColorToken.borderSubtle)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.height > 50 {
                                onClear()
                            }
                        }
                )

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(selection.scopeTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                            .clipShape(Capsule())
                        if explanationSource == .cache {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark.fill")
                                    .font(.caption2)
                                Text(localizedString("reading.explanation.source.cached"))
                                    .font(.caption2)
                            }
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        }
                    }
                    Text(selection.selectedText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
                ReadingCopyButton(text: selection.selectedText)
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(LangoTraceDesign.ColorToken.surfaceMuted)
                        .clipShape(.circle)
                        // Keep the 28pt visual while extending the hit area to the minimum touch target.
                        .frame(
                            width: LangoTraceDesign.Density.minimumTouchTarget,
                            height: LangoTraceDesign.Density.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("common.close"))
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ReadingActionPill(
                    titleKey: "reading.action.explain",
                    systemImage: "sparkles",
                    isPrimary: true,
                    isLoading: explanationState == .loading,
                    action: onExplain
                )
                ReadingActionPill(
                    titleKey: "common.listen",
                    systemImage: "speaker.wave.2",
                    isPrimary: false,
                    isLoading: audioState == .loading,
                    action: onListen
                )
                if explanationSource == .cache, let onRegenerate {
                    ReadingActionPill(
                        titleKey: "reading.explanation.regenerate",
                        systemImage: "arrow.clockwise",
                        isPrimary: false,
                        action: onRegenerate
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            if panelState == .content || panelState == .loading || panelState == .failed {
                HStack {
                    Text(localizedString("reading.panel.explanation.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 2)
            }

            ReadingExplanationResultView(
                result: panelState == .content ? explanationResult : nil,
                state: panelState == .loading ? .loading : (panelState == .failed ? .failed : .idle),
                cardBackground: LangoTraceDesign.ColorToken.surfaceMuted
            )
            .padding(.horizontal, 20)
            .padding(.top, panelState == .content || panelState == .loading || panelState == .failed ? 4 : 12)

            Spacer().frame(height: 24)
        }
        .background {
            LangoTraceDesign.ColorToken.surfacePanel
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LangoTraceDesign.ColorToken.borderSubtle)
                .frame(height: 0.5)
        }
        .shadow(color: LangoTraceDesign.ColorToken.shadow, radius: 8, x: 0, y: -3)
    }
}

// MARK: - Shared explanation result display

struct ReadingExplanationResultView: View {
    let result: ReadingSelectionExplanationResult?
    let state: ReadingAsyncState
    var cardBackground: Color = LangoTraceDesign.ColorToken.surfacePanel

    var body: some View {
        Group {
            if state == .loading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(localizedString("reading.panel.loading"))
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if state == .failed {
                Text(localizedString("reading.panel.failed"))
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let result {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.shortExplanation)
                        .font(.body)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    let hasMetadata = !result.meaningInNativeLanguage.isEmpty
                        || result.grammaticalNote?.isEmpty == false
                        || !result.usageNote.isEmpty
                        || !result.exampleSentence.isEmpty
                    if hasMetadata {
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            if !result.meaningInNativeLanguage.isEmpty {
                                ReadingResultRow(
                                    label: localizedString("reading.result.translation"),
                                    value: result.meaningInNativeLanguage
                                )
                            }
                            if let grammar = result.grammaticalNote, !grammar.isEmpty {
                                ReadingResultRow(
                                    label: localizedString("reading.result.grammar"),
                                    value: grammar
                                )
                            }
                            if !result.usageNote.isEmpty {
                                ReadingResultRow(
                                    label: localizedString("reading.result.usage"),
                                    value: result.usageNote
                                )
                            }
                            if !result.exampleSentence.isEmpty {
                                ReadingResultRow(
                                    label: localizedString("reading.result.example"),
                                    value: result.exampleSentence,
                                    isItalic: true
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct ReadingResultRow: View {
    let label: String
    let value: String
    var isItalic = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .frame(minWidth: 48, alignment: .leading)
            Text(value)
                .font(.callout)
                .italic(isItalic)
                .foregroundStyle(
                    isItalic
                        ? LangoTraceDesign.ColorToken.textSecondary
                        : LangoTraceDesign.ColorToken.textPrimary
                )
                .fixedSize(horizontal: false, vertical: true)
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
