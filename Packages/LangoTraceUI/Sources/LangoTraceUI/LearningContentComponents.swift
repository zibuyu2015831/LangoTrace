import LangoTraceCore
import LangoTraceData
import SwiftUI

struct EntryTimelineRow: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    let targetLanguage: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isSelected ? LangoTraceDesign.ColorToken.accent : LangoTraceDesign.ColorToken.borderSubtle)
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    Text("\(entry.displaySourceTitle) · \(targetLanguage) · \(entry.displayScene)")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    EntryMaterialStatusPill(entry: entry, rendering: rendering)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                    .stroke(rowStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: action) {
                localizedText("entryDetail.title")
            }
        }
        .accessibilityLabel(
            localizedString(
                "entry.timeline.accessibilityLabel",
                entry.title,
                entry.displaySourceTitle,
                localizedString(materialStatusAccessibilityKey)
            )
        )
        .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
    }

    private var materialStatusAccessibilityKey: String {
        switch materialStatus(entry: entry, rendering: rendering) {
        case .noMaterial: "entry.material.status.none"
        case .stale: "entry.material.status.stale"
        case .fresh: "entry.material.status.fresh"
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return LangoTraceDesign.ColorToken.surfaceRaised
        }

        return isHovered ? LangoTraceDesign.ColorToken.elevatedPaper : .clear
    }

    private var rowStroke: Color {
        if isSelected {
            return LangoTraceDesign.ColorToken.accent.opacity(0.35)
        }

        return isHovered ? LangoTraceDesign.ColorToken.hairline : .clear
    }
}

struct MemoryLayerSummaryView: View {
    let memoryItems: [MemoryItem]

    private var contentMemoryCount: Int {
        Set(memoryItems.map(\.entryID)).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CapabilityStatusRow(
                title: localizedString("memory.layer.content.title"),
                summary: localizedString("memory.layer.content.summary", contentMemoryCount),
                status: memoryItems.isEmpty ? .unavailable : .ready,
                systemImage: "doc.text",
                action: nil
            )
            CapabilityStatusRow(
                title: localizedString("memory.layer.language.title"),
                summary: localizedString("memory.layer.language.summary", memoryItems.count),
                status: memoryItems.isEmpty ? .unavailable : .ready,
                systemImage: "text.book.closed",
                action: nil
            )
            CapabilityStatusRow(
                localizedTitleKey: "memory.layer.study.title",
                localizedSummaryKey: "memory.layer.study.summary",
                status: .unavailable,
                systemImage: "calendar.badge.clock",
                action: nil
            )
        }
    }
}

struct SentencePairView: View {
    let index: Int
    let sentence: RenderingSentence
    let playbackState: SentenceAudioPresentationState
    let onListen: () -> Void
    let onPractice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(index)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                    .clipShape(Circle())
                Spacer(minLength: 12)
                SentencePairActionRow(
                    playbackState: playbackState,
                    onListen: onListen,
                    onPractice: onPractice
                )
            }
            sentenceContent
        }
        .langoPanel(padding: 14)
    }

    private var sentenceContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sentence.translation)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(sentence.targetText)
                .font(.body.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(sentence.note)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RequestPreviewCard: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    /// Real "will-send" projection (nil when generation is not configured or on
    /// surfaces that do not supply one).
    var projection: AIRequestPreviewProjection?

    private var model: RequestPreviewCardModel {
        RequestPreviewCardModel(projection: projection, entry: entry, rendering: rendering)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                localizedText("requestPreview.title")
            } icon: {
                Image(systemName: "eye")
            }
            .font(.headline)
            content
            Divider()
            localizedText("requestPreview.notSent")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Label {
                localizedText("requestPreview.localMock")
            } icon: {
                Image(systemName: "lock")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.privacyLocal)
        }
        .langoPanel()
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case let .localDraft(body):
            previewBody(body)
        case .offline:
            previewBody(localizedString("requestPreview.realtime.offline"))
        case let .projected(provider, modelName, lengthLabel, includedLabels):
            VStack(alignment: .leading, spacing: 6) {
                fieldRow("requestPreview.field.provider", provider)
                fieldRow("requestPreview.field.model", modelName)
                fieldRow("requestPreview.field.length", lengthLabel)
                localizedText("requestPreview.includes.header")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                ForEach(includedLabels, id: \.self) { label in
                    Text("· \(label)")
                        .font(.callout)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                }
            }
        }
    }

    private func previewBody(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func fieldRow(_ titleKey: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            localizedText(titleKey)
                .font(.caption)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
    }
}

struct CapabilityStatusRow: View {
    let title: String
    let localizedTitleKey: String?
    let summary: String
    let localizedSummaryKey: String?
    let status: CapabilityStatus
    let systemImage: String
    let showsStatusBadge: Bool
    let action: (() -> Void)?
    /// E12: an already-resolved, localized muted value shown at the trailing edge of the
    /// settings list (e.g. the current AI provider / sync / appearance value). The settings
    /// main list uses this in place of a status badge.
    private var resolvedTrailingValue: String?

    /// Attaches a trailing muted value to the row. Returns a modified copy so the existing
    /// initializers stay unchanged.
    func trailingValue(_ value: String?) -> CapabilityStatusRow {
        var copy = self
        copy.resolvedTrailingValue = value
        return copy
    }

    init(
        title: String,
        summary: String,
        status: CapabilityStatus,
        systemImage: String,
        showsStatusBadge: Bool = true,
        action: (() -> Void)?
    ) {
        self.title = title
        localizedTitleKey = nil
        self.summary = summary
        localizedSummaryKey = nil
        self.status = status
        self.systemImage = systemImage
        self.showsStatusBadge = showsStatusBadge
        self.action = action
    }

    init(
        localizedTitleKey: String,
        summary: String,
        status: CapabilityStatus,
        systemImage: String,
        showsStatusBadge: Bool = true,
        action: (() -> Void)?
    ) {
        title = localizedTitleKey
        self.localizedTitleKey = localizedTitleKey
        self.summary = summary
        localizedSummaryKey = nil
        self.status = status
        self.systemImage = systemImage
        self.showsStatusBadge = showsStatusBadge
        self.action = action
    }

    init(
        localizedTitleKey: String,
        localizedSummaryKey: String,
        status: CapabilityStatus,
        systemImage: String,
        showsStatusBadge: Bool = true,
        action: (() -> Void)?
    ) {
        title = localizedTitleKey
        self.localizedTitleKey = localizedTitleKey
        summary = localizedSummaryKey
        self.localizedSummaryKey = localizedSummaryKey
        self.status = status
        self.systemImage = systemImage
        self.showsStatusBadge = showsStatusBadge
        self.action = action
    }

    init(
        title: String,
        localizedSummaryKey: String,
        status: CapabilityStatus,
        systemImage: String,
        showsStatusBadge: Bool = true,
        action: (() -> Void)?
    ) {
        self.title = title
        localizedTitleKey = nil
        summary = localizedSummaryKey
        self.localizedSummaryKey = localizedSummaryKey
        self.status = status
        self.systemImage = systemImage
        self.showsStatusBadge = showsStatusBadge
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                rowContent(trailingImage: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityHint(summaryText)
        } else {
            rowContent(trailingImage: nil)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabelText)
                .accessibilityHint(summaryText)
        }
    }

    private func rowContent(trailingImage: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    titleText
                        .font(.headline)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    if showsStatusBadge {
                        CapabilityStatusBadge(status: status)
                    }
                }
                summaryText
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let resolvedTrailingValue {
                Text(resolvedTrailingValue)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .padding(.top, 7)
            }
            if let trailingImage {
                Image(systemName: trailingImage)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .padding(.top, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }

    private var titleText: Text {
        if let localizedTitleKey {
            localizedText(localizedTitleKey)
        } else {
            Text(title)
        }
    }

    private var summaryText: Text {
        if let localizedSummaryKey {
            localizedText(localizedSummaryKey)
        } else {
            Text(summary)
        }
    }

    private var accessibilityLabelText: Text {
        guard showsStatusBadge else {
            return titleText
        }
        return titleText + localizedText("accessibility.listSeparator") + localizedText(status.localizedTitleKey)
    }

    private var statusColor: Color {
        switch status.visualTone {
        case .ready:
            LangoTraceDesign.ColorToken.stateReady
        case .localMock:
            LangoTraceDesign.ColorToken.stateLocalMock
        case .unavailable:
            LangoTraceDesign.ColorToken.stateUnavailable
        case .warning:
            LangoTraceDesign.ColorToken.stateWarning
        case .error:
            LangoTraceDesign.ColorToken.stateError
        case .info:
            LangoTraceDesign.ColorToken.accent
        }
    }
}
