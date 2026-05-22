import LangoTraceData
import SwiftUI

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
                .foregroundStyle(LangoTraceDesign.ColorToken.primaryActionForeground)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.primaryActionFill)
        }
        .langoPanel(padding: 14)
    }

    private func accessibilityValue(for step: PracticeSessionStep) -> Text {
        step == currentStep
            ? localizedText("common.currentStep")
            : localizedText("common.switchable")
    }
}
