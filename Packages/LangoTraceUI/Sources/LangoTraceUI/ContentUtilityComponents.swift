import SwiftUI

struct SecondaryActionChip: View {
    let titleKey: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                localizedText(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .buttonStyle(.plain)
        .background(LangoTraceDesign.ColorToken.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.borderSubtle, lineWidth: 1)
        }
        .accessibilityLabel(localizedText(titleKey))
    }
}

struct CompactPanel: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }
}

struct LocalizedCompactPanel: View {
    let titleKey: String
    let textKey: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                localizedText(titleKey)
                    .font(.headline)
                localizedText(textKey)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }
}

struct InlineStatusLabel: View {
    let text: String
    let localizedTextKey: String?
    let systemImage: String

    init(text: String, systemImage: String) {
        self.text = text
        localizedTextKey = nil
        self.systemImage = systemImage
    }

    init(localizedTextKey: String, systemImage: String) {
        text = localizedTextKey
        self.localizedTextKey = localizedTextKey
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            if let localizedTextKey {
                localizedText(localizedTextKey)
            } else {
                Text(text)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
        .clipShape(Capsule())
    }
}

struct TextPanel: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .langoPanel()
    }
}
