import SwiftUI

struct SentencePairActionRow: View {
    let isListening: Bool
    let onListen: () -> Void
    let onPractice: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SentencePairActionButton(
                titleKey: isListening ? "common.pause" : "common.listen",
                systemImage: isListening ? "pause.fill" : "speaker.wave.2",
                isPrimary: false,
                action: onListen
            )
            .accessibilityHint(localizedText("practice.listen.hint"))
            SentencePairActionButton(
                titleKey: "common.practice",
                systemImage: "figure.run",
                isPrimary: true,
                action: onPractice
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SentencePairActionButton: View {
    let titleKey: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(borderStyle, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText(titleKey))
    }

    private var foregroundStyle: Color {
        isPrimary ? LangoTraceDesign.ColorToken.primaryActionForeground : LangoTraceDesign.ColorToken.accent
    }

    private var backgroundStyle: Color {
        isPrimary ? LangoTraceDesign.ColorToken.primaryActionFill : LangoTraceDesign.ColorToken.surfaceAccentMuted
    }

    private var borderStyle: Color {
        isPrimary ? .clear : LangoTraceDesign.ColorToken.borderSubtle
    }
}
