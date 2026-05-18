import LangoTraceData
import SwiftUI

struct EntryTimelineRow: View {
    let entry: LearningEntry
    let targetLanguage: String
    let isSelected: Bool
    let action: () -> Void

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
            .background(isSelected ? LangoTraceDesign.ColorToken.surfaceRaised : .clear)
            .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                    .stroke(isSelected ? LangoTraceDesign.ColorToken.accent.opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title)，\(entry.displaySourceTitle)，\(entry.practiceSummary)")
        .accessibilityValue(localizedText(isSelected ? "accessibility.selected" : "accessibility.unselected"))
    }
}

struct SideItem: View {
    let title: String
    let subtitle: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? LangoTraceDesign.ColorToken.surfaceRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LangoTraceDesign.Radius.control, style: .continuous)
                .stroke(active ? LangoTraceDesign.ColorToken.accent.opacity(0.25) : Color.clear, lineWidth: 1)
        }
    }
}

struct SentencePairView: View {
    let index: Int
    let sentence: RenderingSentence
    let onPractice: () -> Void

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
                Button {} label: {
                    localizedText("common.listen")
                }
                .buttonStyle(.bordered)
                .accessibilityHint(localizedText("practice.listen.hint"))
                Button(action: onPractice) {
                    localizedText("common.practice")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .langoPanel()
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
        }
    }
}

struct PracticeControlBar: View {
    let steps: [PracticeSessionStep]
    let currentStep: PracticeSessionStep
    let onSelectStep: (PracticeSessionStep) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(steps, id: \.self) { step in
                    Button {
                        onSelectStep(step)
                    } label: {
                        Text(step.displayTitle)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(step == currentStep ? .white : LangoTraceDesign.ColorToken.accent)
                    .background(
                        step == currentStep
                            ? LangoTraceDesign.ColorToken.accent
                            : LangoTraceDesign.ColorToken.surfaceAccentMuted
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel(step.displayTitle)
                    .accessibilityValue(accessibilityValue(for: step))
                }
            }
            Button(action: onNext) {
                Label {
                    localizedText(currentStep == .completed ? "common.keepCompleted" : "common.nextStep")
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .langoPanel(padding: 14)
    }

    private func accessibilityValue(for step: PracticeSessionStep) -> Text {
        step == currentStep
            ? localizedText("common.currentStep")
            : localizedText("common.switchable")
    }
}
