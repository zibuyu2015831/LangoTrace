import LangoTraceData
import SwiftUI

struct LocalListeningPreviewView: View {
    let sentence: RenderingSentence
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    playbackCard
                    TextPanel(
                        title: localizedString("listeningPreview.translation.title"),
                        text: sentence.translation
                    )
                    TextPanel(
                        title: localizedString("listeningPreview.focus.title"),
                        text: localizedString("listeningPreview.focus.body", sentence.note)
                    )
                    TextPanel(
                        title: localizedString("listeningPreview.routine.title"),
                        text: localizedString("listeningPreview.routine.body")
                    )
                    localBoundary
                }
                .padding(20)
            }
        }
        .langoPageBackground()
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            localizedText("listeningPreview.title")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: close) {
                localizedText("common.close")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var playbackCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                VStack(alignment: .leading, spacing: 4) {
                    localizedText("listeningPreview.target.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(sentence.targetText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                isPlaying.toggle()
            } label: {
                Label {
                    localizedText(isPlaying ? "listeningPreview.action.pause" : "listeningPreview.action.play")
                } icon: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .langoPanel()
    }

    private var localBoundary: some View {
        Label {
            localizedText("listeningPreview.localBoundary")
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        } icon: {
            Image(systemName: "lock")
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
        .labelStyle(.titleAndIcon)
    }

    private func close() {
        onDismiss()
        dismiss()
    }
}
