import LangoTraceCore
import SwiftUI

/// Shared low-pressure review session (E8): target text first, reveal note +
/// example, then a two-option feedback. Used as a full-screen push on iPhone and
/// a centered sheet on iPad / macOS. Fully local.
struct MemoryReviewSessionView: View {
    let spaceID: String
    let onClose: () -> Void

    @Environment(\.memoryReviewActions) private var memoryReviewActions
    @StateObject private var store: MemoryReviewSessionViewModel

    init(spaceID: String, onClose: @escaping () -> Void) {
        self.spaceID = spaceID
        self.onClose = onClose
        _store = StateObject(wrappedValue: MemoryReviewSessionViewModel(spaceID: spaceID, actions: .disabled))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            switch store.phase {
            case .loading:
                ProgressView()
            case .empty:
                emptyState
            case .reviewing:
                reviewCard
            case .finished:
                finishedState
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
        .task {
            store.reconnect(memoryReviewActions)
            await store.load()
        }
    }

    private var header: some View {
        HStack {
            localizedText("memory.review.title")
                .font(.headline)
            Spacer()
            if store.phase == .reviewing {
                Text("\(store.reviewedCount + 1) / \(store.totalCount)")
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        LocalizedCompactPanel(
            titleKey: "memory.review.empty.title",
            textKey: "memory.review.empty.body",
            systemImage: "checkmark.circle"
        )
    }

    private var finishedState: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocalizedCompactPanel(
                titleKey: "memory.review.finished.title",
                textKey: "memory.review.finished.body",
                systemImage: "sparkles"
            )
            Button(localizedString("memory.review.done")) { onClose() }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
    }

    @ViewBuilder
    private var reviewCard: some View {
        if let item = store.currentItem {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.text)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.isRevealed {
                    revealedDetail(item)
                    feedbackButtons
                } else {
                    Button {
                        store.reveal()
                    } label: {
                        localizedText("memory.review.reveal")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
                    .background(LangoTraceDesign.ColorToken.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .langoPanel()
        }
    }

    private func revealedDetail(_ item: DepositedMemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.note)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !item.exampleTarget.isEmpty {
                Text(item.exampleTarget)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            }
            if !item.exampleNative.isEmpty {
                Text(item.exampleNative)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
        }
    }

    private var feedbackButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                feedbackButton("memory.review.needsAnotherLook") { await store.submit(.needsAnotherLook) }
                feedbackButton("memory.review.remembered") { await store.submit(.remembered) }
            }
            Button {
                Task { await store.masterCurrent() }
            } label: {
                localizedText("memory.review.markMastered")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
    }

    private func feedbackButton(_ titleKey: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            localizedText(titleKey)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LangoTraceDesign.ColorToken.ink)
        .background(LangoTraceDesign.ColorToken.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
