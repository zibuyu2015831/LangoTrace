import LangoTraceData
import SwiftUI

struct EntryTimelineRow: View {
    let entry: LearningEntry
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
                    Text("\(entry.displaySourceTitle) · \(targetLanguage) · \(entry.scene)")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(entry.practiceSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
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
        .accessibilityLabel("\(entry.title)，\(entry.displaySourceTitle)，\(entry.practiceSummary)")
        .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
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
                status: memoryItems.isEmpty ? .unavailable : .mockOnly,
                systemImage: "doc.text",
                action: nil
            )
            CapabilityStatusRow(
                title: localizedString("memory.layer.language.title"),
                summary: localizedString("memory.layer.language.summary", memoryItems.count),
                status: memoryItems.isEmpty ? .unavailable : .mockOnly,
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
    let onPractice: () -> Void
    @State private var isListeningPreviewPresented = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(sentence.translation)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Text(sentence.targetText)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                Text(sentence.note)
                    .font(.caption)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    isListeningPreviewPresented = true
                } label: {
                    localizedText("common.listen")
                }
                .buttonStyle(.bordered)
                .accessibilityHint(localizedText("practice.listen.hint"))
                Button(action: onPractice) {
                    localizedText("common.practice")
                        .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                }
                .buttonStyle(.borderedProminent)
                .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            }
        }
        .langoPanel()
        .sheet(isPresented: $isListeningPreviewPresented) {
            LocalListeningPreviewView(sentence: sentence) {
                isListeningPreviewPresented = false
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct RequestPreviewCard: View {
    let entry: LearningEntry
    let rendering: LearningRendering?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                localizedText("requestPreview.title")
            } icon: {
                Image(systemName: "eye")
            }
            .font(.headline)
            Text(previewCopy.body)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var previewCopy: RequestPreviewCopy {
        if rendering?.isMock == false {
            return .externalRequest(entryTitle: entry.title, promptLabel: rendering?.promptLabel)
        }

        return .localMock(entryTitle: entry.title, promptLabel: rendering?.promptLabel)
    }
}

struct CapabilityStatusRow: View {
    let title: String
    let localizedTitleKey: String?
    let summary: String
    let localizedSummaryKey: String?
    let status: CapabilityStatus
    let systemImage: String
    let action: (() -> Void)?

    init(
        title: String,
        summary: String,
        status: CapabilityStatus,
        systemImage: String,
        action: (() -> Void)?
    ) {
        self.title = title
        localizedTitleKey = nil
        self.summary = summary
        localizedSummaryKey = nil
        self.status = status
        self.systemImage = systemImage
        self.action = action
    }

    init(
        localizedTitleKey: String,
        summary: String,
        status: CapabilityStatus,
        systemImage: String,
        action: (() -> Void)?
    ) {
        title = localizedTitleKey
        self.localizedTitleKey = localizedTitleKey
        self.summary = summary
        localizedSummaryKey = nil
        self.status = status
        self.systemImage = systemImage
        self.action = action
    }

    init(
        localizedTitleKey: String,
        localizedSummaryKey: String,
        status: CapabilityStatus,
        systemImage: String,
        action: (() -> Void)?
    ) {
        title = localizedTitleKey
        self.localizedTitleKey = localizedTitleKey
        summary = localizedSummaryKey
        self.localizedSummaryKey = localizedSummaryKey
        self.status = status
        self.systemImage = systemImage
        self.action = action
    }

    init(
        title: String,
        localizedSummaryKey: String,
        status: CapabilityStatus,
        systemImage: String,
        action: (() -> Void)?
    ) {
        self.title = title
        localizedTitleKey = nil
        summary = localizedSummaryKey
        self.localizedSummaryKey = localizedSummaryKey
        self.status = status
        self.systemImage = systemImage
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
                    CapabilityStatusBadge(status: status)
                }
                summaryText
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
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
        titleText + Text("，") + localizedText(status.localizedTitleKey)
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
