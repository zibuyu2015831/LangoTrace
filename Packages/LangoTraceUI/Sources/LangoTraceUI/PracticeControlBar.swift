import LangoTraceCore
import SwiftUI

struct PracticeControlBar: View {
    let session: PracticeSession
    let isRecording: Bool
    let isPlayingDemo: Bool
    let isPlayingRecording: Bool
    let onPlayDemo: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onPlayRecording: () -> Void
    let onComplete: () -> Void

    private var presentation: PracticeControlBarPresentation {
        PracticeControlBarPresentation(
            session: session,
            isRecording: isRecording,
            isPlayingRecording: isPlayingRecording
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                secondaryButton(
                    title: localizedString("common.listen"),
                    icon: "speaker.wave.2",
                    action: onPlayDemo,
                    disabled: isRecording || isPlayingRecording
                )
                secondaryButton(
                    title: localizedString("practice.recording.playback"),
                    icon: "play.circle",
                    action: onPlayRecording,
                    disabled: isRecording || isPlayingDemo || session.latestReadyRecordingID == nil
                )
            }
            Button(action: primaryAction) {
                Label {
                    Text(localizedString(presentation.primaryTitleKey))
                } icon: {
                    Image(systemName: presentation.primaryIcon)
                }
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
            .disabled(primaryDisabled)
        }
        .langoPanel(padding: 14)
    }

    private func secondaryButton(
        title: String,
        icon: String,
        action: @escaping () -> Void,
        disabled: Bool
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
    }

    private var primaryDisabled: Bool {
        session.status == .completed || isPlayingDemo || isPlayingRecording
    }

    private func primaryAction() {
        if isRecording {
            onStopRecording()
        } else if session.latestReadyRecordingID != nil {
            onComplete()
        } else {
            onStartRecording()
        }
    }
}

struct PracticeControlBarPresentation: Equatable {
    var primaryTitleKey: String
    var primaryIcon: String

    init(session: PracticeSession, isRecording: Bool, isPlayingRecording: Bool) {
        if isRecording {
            primaryTitleKey = "practice.recording.stop"
            primaryIcon = "stop.fill"
        } else if isPlayingRecording {
            primaryTitleKey = "practice.recording.playing"
            primaryIcon = "play.circle"
        } else if session.status == .completed {
            primaryTitleKey = "common.keepCompleted"
            primaryIcon = "checkmark"
        } else if session.latestReadyRecordingID != nil {
            primaryTitleKey = "practice.action.markComplete"
            primaryIcon = "checkmark"
        } else {
            primaryTitleKey = "practice.recording.start"
            primaryIcon = "record.circle"
        }
    }
}
