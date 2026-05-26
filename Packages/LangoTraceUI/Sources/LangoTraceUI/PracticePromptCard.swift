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

            disclosureControls

            if let translationText = presentation.displayedTranslationText {
                translationSection(translationText)
            }

            if isExplanationExpanded, !presentation.explanationParagraphs.isEmpty {
                explanationSection
            }
        }
        .langoPanel()
    }

    private func translationSection(_ translationText: String) -> some View {
        Text(translationText)
            .font(.callout)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(presentation.explanationParagraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.footnote)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var disclosureControls: some View {
        if presentation.shouldShowTranslationToggle || presentation.shouldShowExplanationToggle {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    if presentation.shouldShowTranslationToggle {
                        translationToggle
                    }
                    if presentation.shouldShowExplanationToggle {
                        explanationToggle
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    if presentation.shouldShowTranslationToggle {
                        translationToggle
                    }
                    if presentation.shouldShowExplanationToggle {
                        explanationToggle
                    }
                }
            }
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

struct PracticePromptCardPresentation: Equatable {
    var targetText: String
    var translationText: String?
    var displayedTranslationText: String?
    var explanationText: String?
    var explanationParagraphs: [String]
    var translationToggleTitleKey: String?
    var explanationToggleTitleKey: String?
    var translationAccessibilityValueKey: String?
    var explanationAccessibilityValueKey: String?
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
        explanationParagraphs = Self.normalizedParagraphs(snapshot.noteSnapshot)

        shouldShowTranslationToggle = translationText != nil
        displayedTranslationText = isTranslationExpanded ? translationText : nil
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

    private static func normalizedParagraphs(_ value: String?) -> [String] {
        value?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }
}
