import LangoTraceCore
import SwiftUI

struct SentencePairActionRow: View {
    let playbackState: SentenceAudioPresentationState
    let onListen: () -> Void
    let onPractice: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SentencePairActionButton(
                titleKey: playbackState.listenButtonTitleKey,
                systemImage: playbackState.listenButtonSystemImage,
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

private extension SentenceAudioPresentationState {
    var listenButtonTitleKey: String {
        switch self {
        case .playing, .generating:
            "common.pause"
        case .idle, .paused, .requiresConfiguration, .failed:
            "common.listen"
        }
    }

    var listenButtonSystemImage: String {
        switch self {
        case .generating:
            "waveform"
        case .playing:
            "pause.fill"
        case .paused, .idle, .requiresConfiguration, .failed:
            "speaker.wave.2"
        }
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
