import LangoTraceCore
import SwiftUI

/// Shared local-search palette used by the macOS command palette overlay and the
/// iPad search sheet (E9). Renders grouped, space-scoped results from the
/// fully local FTS index; selecting a hit calls `onSelect`. The footer discloses
/// that search is scoped to the current language space.
struct SearchPaletteView: View {
    let spaceID: String
    let onSelect: (SearchHit) -> Void
    let onClose: () -> Void

    @Environment(\.localSearchActions) private var localSearchActions
    @StateObject private var store: SearchPaletteStore

    @FocusState private var queryFieldFocused: Bool

    init(spaceID: String, onSelect: @escaping (SearchHit) -> Void, onClose: @escaping () -> Void) {
        self.spaceID = spaceID
        self.onSelect = onSelect
        self.onClose = onClose
        _store = StateObject(wrappedValue: SearchPaletteStore(spaceID: spaceID, actions: .disabled))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            queryField
            Divider()
            content
            Divider()
            footer
        }
        .frame(maxWidth: 640)
        .background(LangoTraceDesign.ColorToken.elevatedPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            store.reconnect(localSearchActions)
            await store.prepare()
            queryFieldFocused = true
        }
    }

    private var queryField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField(localizedString("search.placeholder"), text: queryBinding)
                .textFieldStyle(.plain)
                .focused($queryFieldFocused)
                .onSubmit {
                    if let hit = store.selectedHit {
                        onSelect(hit)
                    }
                }
            if store.isIndexing {
                ProgressView().controlSize(.small)
            }
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if store.showsZeroState {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.results.groups, id: \.kind) { group in
                        groupView(group)
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 360)
        }
    }

    private func groupView(_ group: SearchResultGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            localizedText(groupTitleKey(group.kind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            ForEach(group.hits) { hit in
                Button {
                    onSelect(hit)
                } label: {
                    hitRow(hit)
                }
                .buttonStyle(.plain)
                .background(
                    hit.id == store.selectedHitID
                        ? LangoTraceDesign.ColorToken.accent.opacity(0.12)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func hitRow(_ hit: SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hit.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .lineLimit(1)
            if !hit.snippet.isEmpty {
                Text(hit.snippet)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        localizedText("search.zeroState")
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
    }

    private var footer: some View {
        localizedText("search.scope.currentSpace")
            .font(.caption)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .padding(12)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { store.query },
            set: { store.updateQuery($0) }
        )
    }

    private func groupTitleKey(_ kind: SearchObjectKind) -> String {
        switch kind {
        case .entry: "search.group.entry"
        case .readingDocument: "search.group.reading"
        case .memoryItem: "search.group.memory"
        }
    }
}
