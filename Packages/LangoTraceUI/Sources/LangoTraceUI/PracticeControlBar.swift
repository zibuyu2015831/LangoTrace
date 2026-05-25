import LangoTraceCore
import SwiftUI

struct PracticeControlBar: View {
    let session: PracticeSession
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                phasePill(.shadowing)
                phasePill(.recording)
                phasePill(.completion)
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

    private var primaryTitle: String {
        if isRecording {
            return localizedString("practice.recording.stop")
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
        session.status == .completed
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
