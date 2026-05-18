import LangoTraceCore
import SwiftUI

struct LanguageSpaceFooter: View {
    let languageSpace: LanguageSpacePreview
    let aiStatus: AIProviderStatus
    let syncStatus: SyncProviderStatus
    let isCompact: Bool
    var onLanguageSpace: (() -> Void)?
    var onAIStatus: (() -> Void)?
    var onSyncStatus: (() -> Void)?
    var onSettings: (() -> Void)?

    @State private var activePopover: PrivacyStatusPopover?

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    onLanguageSpace?()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageSpace.name)
                            .font(isCompact ? .callout.weight(.semibold) : .headline)
                            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                            .lineLimit(1)
                        Text(languageSpace.displayContext)
                            .font(.footnote)
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    localizedString("languageSpace.current.accessibilityLabel", languageSpace.displayContext)
                )

                HStack(spacing: isCompact ? 4 : 6) {
                    PrivacyStatusIconButton(
                        title: aiStatus.title,
                        value: aiStatus.value,
                        summary: aiStatus.summary,
                        systemImage: aiStatus.systemImage,
                        severity: aiStatus.severity,
                        isCompact: isCompact
                    ) {
                        if let onAIStatus {
                            onAIStatus()
                        } else {
                            activePopover = .ai(aiStatus)
                        }
                    }

                    PrivacyStatusIconButton(
                        title: syncStatus.title,
                        value: syncStatus.value,
                        summary: syncStatus.summary,
                        systemImage: syncStatus.systemImage,
                        severity: syncStatus.severity,
                        isCompact: isCompact
                    ) {
                        if let onSyncStatus {
                            onSyncStatus()
                        } else {
                            activePopover = .sync(syncStatus)
                        }
                    }
                }

                Button {
                    onSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)
                        .background(LangoTraceDesign.ColorToken.elevatedPaper)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("tab.settings"))
            }
        }
        .padding(.top, isCompact ? 10 : 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LangoTraceDesign.ColorToken.hairline)
                .frame(height: 1)
        }
        .overlay(alignment: .topTrailing) {
            if let activePopover {
                PrivacyStatusTipView(popover: activePopover, isCompact: isCompact) {
                    self.activePopover = nil
                }
                .offset(y: isCompact ? -138 : -150)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottomTrailing)))
                .zIndex(2)
            }
        }
    }
}

private enum PrivacyStatusPopover: Identifiable {
    case ai(AIProviderStatus)
    case sync(SyncProviderStatus)

    var id: String {
        switch self {
        case let .ai(status):
            "ai-\(status)"
        case let .sync(status):
            "sync-\(status)"
        }
    }

    var title: String {
        switch self {
        case let .ai(status):
            status.title
        case let .sync(status):
            status.title
        }
    }

    var value: String {
        switch self {
        case let .ai(status):
            status.value
        case let .sync(status):
            status.value
        }
    }

    var summary: String {
        switch self {
        case let .ai(status):
            status.summary
        case let .sync(status):
            status.summary
        }
    }
}

private struct PrivacyStatusIconButton: View {
    let title: String
    let value: String
    let summary: String
    let systemImage: String
    let severity: PrivacyStatusSeverity
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isCompact ? 13 : 16, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: visualSize, height: visualSize)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(title)：\(value)。\(summary)")
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(summary)
    }

    private var visualSize: CGFloat {
        isCompact ? 30 : 36
    }

    private var hitSize: CGFloat {
        isCompact ? 34 : 44
    }

    private var foregroundColor: Color {
        switch severity {
        case .inactive:
            LangoTraceDesign.ColorToken.mutedInk
        case .active:
            LangoTraceDesign.ColorToken.deepTeal
        case .warning:
            LangoTraceDesign.ColorToken.gold
        case .error:
            LangoTraceDesign.ColorToken.stateError
        }
    }

    private var backgroundColor: Color {
        switch severity {
        case .inactive:
            LangoTraceDesign.ColorToken.elevatedPaper
        case .active:
            LangoTraceDesign.ColorToken.paleTeal
        case .warning:
            LangoTraceDesign.ColorToken.paleGold
        case .error:
            LangoTraceDesign.ColorToken.dangerMuted
        }
    }

    private var borderColor: Color {
        switch severity {
        case .inactive:
            LangoTraceDesign.ColorToken.hairline
        case .active:
            LangoTraceDesign.ColorToken.teal.opacity(0.28)
        case .warning:
            LangoTraceDesign.ColorToken.gold.opacity(0.36)
        case .error:
            LangoTraceDesign.ColorToken.stateError.opacity(0.30)
        }
    }
}

private struct PrivacyStatusTipView: View {
    let popover: PrivacyStatusPopover
    let isCompact: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(popover.title)
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedText("privacyStatus.close"))
            }
            Text(popover.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.deepTeal)
            Text(popover.summary)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: isCompact ? 274 : 220, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.elevatedPaper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
        }
        .langoSoftShadow()
    }
}
