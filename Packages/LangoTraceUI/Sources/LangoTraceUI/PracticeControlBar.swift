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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                phasePill(.shadowing)
                phasePill(.recording)
                phasePill(.completion)
            }
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
                    Text(primaryTitle)
                } icon: {
                    Image(systemName: primaryIcon)
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

    private func phasePill(_ phase: PracticeSessionPhase) -> some View {
        Text(title(for: phase))
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(phase == session.currentStep ? .white : LangoTraceDesign.ColorToken.accent)
            .background(
                phase == session.currentStep
                    ? LangoTraceDesign.ColorToken.accent
                    : LangoTraceDesign.ColorToken.surfaceAccentMuted
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func title(for phase: PracticeSessionPhase) -> String {
        switch phase {
        case .shadowing:
            localizedString("practiceStep.shadow")
        case .recording:
            localizedString("practiceStep.record")
        case .completion:
            localizedString("practiceStep.completed")
        }
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

    private var primaryTitle: String {
        if isRecording {
            return localizedString("practice.recording.stop")
        }
        if isPlayingRecording {
            return localizedString("practice.recording.playing")
        }
        if session.status == .completed {
            return localizedString("common.keepCompleted")
        }
        if session.latestReadyRecordingID != nil {
            return localizedString("practiceStep.completed")
        }
        return localizedString("practice.recording.start")
    }

    private var primaryIcon: String {
        if isRecording {
            return "stop.fill"
        }
        if session.latestReadyRecordingID != nil {
            return "checkmark"
        }
        return "record.circle"
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
