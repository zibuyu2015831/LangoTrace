import LangoTraceCore
import SwiftUI

struct OnboardingCompactLevelSelector: View {
    @Binding var selectedLevel: LanguageLevel
    let targetLanguageNativeName: String
    let visibleRows: CGFloat

    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 8

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: rowSpacing) {
                ForEach(LanguageLevel.allCases, id: \.self) { level in
                    compactLevelRow(for: level)
                }
            }
        }
        .frame(maxHeight: levelSelectorMaxHeight)
        .scrollIndicators(.visible)
        .accessibilityLabel(localizedText("onboarding.level.title"))
        .accessibilityHint(localizedString("onboarding.level.accessibilityHint", targetLanguageNativeName))
    }

    private var levelSelectorMaxHeight: CGFloat {
        rowMinHeight * visibleRows + rowSpacing * (visibleRows - 1)
    }

    private func compactLevelRow(for level: LanguageLevel) -> some View {
        let selected = selectedLevel == level

        return Button {
            selectedLevel = level
        } label: {
            HStack(spacing: 10) {
                Text(level.rawValue)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                    .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    localizedText(onboardingLevelTitleKey(for: level))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.ink)
                    localizedText(onboardingLevelDescriptionKey(for: level))
                        .font(.caption)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? LangoTraceDesign.ColorToken.teal : LangoTraceDesign.ColorToken.hairline)
            }
            .frame(minHeight: max(rowMinHeight, LangoTraceDesign.Density.minimumTouchTarget))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? LangoTraceDesign.ColorToken.paleTeal : LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        selected
                            ? LangoTraceDesign.ColorToken.teal.opacity(0.55)
                            : LangoTraceDesign.ColorToken.hairline,
                        lineWidth: selected ? 1.2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(level.rawValue), \(localizedString(onboardingLevelTitleKey(for: level)))"))
        .accessibilityValue(localizedText(onboardingLevelDescriptionKey(for: level)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func onboardingLevelTitleKey(for level: LanguageLevel) -> String {
        switch level {
        case .a1:
            "onboarding.level.a1.title"
        case .a2:
            "onboarding.level.a2.title"
        case .b1:
            "onboarding.level.b1.title"
        case .b2:
            "onboarding.level.b2.title"
        case .c1:
            "onboarding.level.c1.title"
        case .c2:
            "onboarding.level.c2.title"
        }
    }

    private func onboardingLevelDescriptionKey(for level: LanguageLevel) -> String {
        switch level {
        case .a1:
            "onboarding.level.a1.description"
        case .a2:
            "onboarding.level.a2.description"
        case .b1:
            "onboarding.level.b1.description"
        case .b2:
            "onboarding.level.b2.description"
        case .c1:
            "onboarding.level.c1.description"
        case .c2:
            "onboarding.level.c2.description"
        }
    }
}
