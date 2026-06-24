import LangoTraceCore
import SwiftUI

/// Renders a photo-writing assist result. Non-destructive by design: writing
/// suggestions are read-only scaffolding; only the native-language draft offers
/// an explicit "use this draft" action that appends to the writing area.
struct PhotoWritingAssistResultPanel: View {
    let result: PhotoWritingAssistResult
    /// Non-nil only when the result is adoptable (the native draft).
    let onAdopt: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result.payload {
            case let .writingSuggestions(suggestions):
                section("photoWriting.assist.result.scene") {
                    Text(suggestions.sceneSummary)
                        .font(.callout)
                }
                section("photoWriting.assist.result.angles") {
                    bulletList(suggestions.writingAngles)
                }
                section("photoWriting.assist.result.expressions") {
                    expressionList(suggestions.usefulExpressions)
                }
                section("photoWriting.assist.result.questions") {
                    bulletList(suggestions.guidingQuestions)
                }
            case let .sourceLanguageDraft(draft):
                section("photoWriting.assist.result.draft") {
                    Text(draft.draft)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !draft.keyVocabularyHints.isEmpty {
                    section("photoWriting.assist.result.vocab") {
                        expressionList(draft.keyVocabularyHints)
                    }
                }
            }

            HStack(spacing: 12) {
                if let onAdopt {
                    Button(action: onAdopt) {
                        localizedText("photoWriting.assist.adopt")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(action: onDismiss) {
                    localizedText("photoWriting.assist.dismiss")
                }
                .buttonStyle(.borderless)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ titleKey: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            localizedText(titleKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("• \(item)")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func expressionList(_ items: [PhotoWritingAssistExpression]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                (Text(item.targetText).font(.callout.weight(.medium))
                    + Text(" — \(item.nativeGloss)").font(.callout)
                    .foregroundColor(LangoTraceDesign.ColorToken.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
