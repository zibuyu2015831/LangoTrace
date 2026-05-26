import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PracticePromptCard: View {
    let snapshot: PracticeSentenceSnapshot
    let isTranslationExpanded: Bool
    let isExplanationExpanded: Bool
    let onToggleTranslation: () -> Void
    let onToggleExplanation: () -> Void

    private var presentation: PracticePromptCardPresentation {
        PracticePromptCardPresentation(
            snapshot: snapshot,
            isTranslationExpanded: isTranslationExpanded,
            isExplanationExpanded: isExplanationExpanded
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(presentation.targetText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let translationText = presentation.translationText {
                translationSection(translationText)
            }

            if presentation.shouldShowExplanationToggle {
                explanationToggle
            }

            if isExplanationExpanded, let explanationText = presentation.explanationText {
                Text(explanationText)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: PracticePromptCardLayout.collapsedMinHeight, alignment: .topLeading)
        .langoPanel()
    }

    private func translationSection(_ translationText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(localizedString("practice.prompt.translation.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Spacer(minLength: 8)
                if presentation.shouldShowTranslationToggle {
                    translationToggle
                }
            }

            Text(translationText)
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .lineLimit(presentation.translationLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var translationToggle: some View {
        Button {
            onToggleTranslation()
        } label: {
            Text(localizedString(presentation.translationToggleTitleKey ?? "practice.prompt.translation.expand"))
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        .accessibilityValue(localizedText(presentation.translationAccessibilityValueKey ?? "accessibility.hidden"))
        .accessibilityHint(localizedText("practice.prompt.translation.toggle.hint"))
    }

    private var explanationToggle: some View {
        Button {
            onToggleExplanation()
        } label: {
            Text(localizedString(presentation.explanationToggleTitleKey ?? "practice.prompt.explanation.expand"))
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        .accessibilityValue(localizedText(presentation.explanationAccessibilityValueKey ?? "accessibility.hidden"))
        .accessibilityHint(localizedText("practice.prompt.explanation.toggle.hint"))
    }
}

private enum PracticePromptCardLayout {
    static let collapsedMinHeight: CGFloat = 220
}

struct PracticePromptCardPresentation: Equatable {
    static let collapsedTranslationLineLimit = 2
    static let translationDisclosureCharacterThreshold = 42

    var targetText: String
    var translationText: String?
    var explanationText: String?
    var translationLineLimit: Int?
    var translationToggleTitleKey: String?
    var explanationToggleTitleKey: String?
    var translationAccessibilityValueKey: String?
    var explanationAccessibilityValueKey: String?
    var translationNeedsDisclosure: Bool
    var shouldShowTranslationToggle: Bool
    var shouldShowExplanationToggle: Bool

    init(
        snapshot: PracticeSentenceSnapshot,
        isTranslationExpanded: Bool,
        isExplanationExpanded: Bool
    ) {
        targetText = snapshot.targetTextSnapshot
        translationText = Self.normalizedText(snapshot.translationSnapshot)
        explanationText = Self.normalizedText(snapshot.noteSnapshot)

        translationNeedsDisclosure = Self.needsTranslationDisclosure(translationText)
        shouldShowTranslationToggle = translationNeedsDisclosure
        translationLineLimit = translationNeedsDisclosure && !isTranslationExpanded
            ? Self.collapsedTranslationLineLimit
            : nil
        translationToggleTitleKey = shouldShowTranslationToggle
            ? (isTranslationExpanded ? "practice.prompt.translation.collapse" : "practice.prompt.translation.expand")
            : nil

        shouldShowExplanationToggle = explanationText != nil
        explanationToggleTitleKey = shouldShowExplanationToggle
            ? (isExplanationExpanded ? "practice.prompt.explanation.collapse" : "practice.prompt.explanation.expand")
            : nil
        translationAccessibilityValueKey = shouldShowTranslationToggle
            ? (isTranslationExpanded ? "accessibility.visible" : "accessibility.hidden")
            : nil
        explanationAccessibilityValueKey = shouldShowExplanationToggle
            ? (isExplanationExpanded ? "accessibility.visible" : "accessibility.hidden")
            : nil
    }

    private static func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func needsTranslationDisclosure(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return value.count > translationDisclosureCharacterThreshold || value.contains("\n")
    }
}
