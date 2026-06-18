import LangoTraceCore
import SwiftUI

/// Backtranslation session: read the native-language meaning, write your own
/// target-language expression, then reveal the reference for a side-by-side
/// read. The reference is withheld until revealed, the comparison is never
/// scored (never judged right or wrong), and revealing it is a purely local
/// action — no AI, no network. Sentences without learning material show
/// guidance instead.
struct PracticeBacktranslationSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions
    let onNavigateSentence: (PracticeSessionRouteSeed) -> Void

    @StateObject private var viewModel: PracticeBacktranslationSessionViewModel

    init(
        languageSpaceID: String,
        routeSeed: PracticeSessionRouteSeed,
        actions: PracticeActions,
        onNavigateSentence: @escaping (PracticeSessionRouteSeed) -> Void = { _ in }
    ) {
        self.languageSpaceID = languageSpaceID
        self.routeSeed = routeSeed
        self.actions = actions
        self.onNavigateSentence = onNavigateSentence
        _viewModel = StateObject(
            wrappedValue: PracticeBacktranslationSessionViewModel(
                languageSpaceID: languageSpaceID,
                snapshot: routeSeed.snapshot,
                actions: actions
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isGuidanceState {
                    guidanceCard
                } else {
                    promptCard
                    if viewModel.phase == .answering {
                        inputCard
                    } else if let reference = viewModel.visibleReference {
                        referenceCard(reference)
                    }
                }
                PracticeSentenceNavigationBar(
                    routeSeed: routeSeed,
                    isNavigationDisabled: viewModel.isSubmitting,
                    onNavigate: navigateSentence
                )
                if let failure = viewModel.failure {
                    CapabilityStatusRow(
                        localizedTitleKey: "practice.failure.title",
                        localizedSummaryKey: failure.localizedSummaryKey,
                        status: .unavailable,
                        systemImage: "exclamationmark.triangle",
                        action: nil
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle(localizedText("practice.title"))
        .langoPracticeInlineNavigationTitle()
        .langoPageBackground()
        .task {
            await viewModel.load()
        }
    }

    private var guidanceCard: some View {
        CapabilityStatusRow(
            localizedTitleKey: "practice.backtranslation.guidance.title",
            localizedSummaryKey: "practice.backtranslation.guidance.summary",
            status: .unavailable,
            systemImage: "doc.text.magnifyingglass",
            action: nil
        )
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("practice.backtranslation.prompt"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Text(viewModel.promptText ?? "")
                .font(.title3.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("practice.backtranslation.yourAnswer"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField(
                localizedString("practice.backtranslation.input.placeholder"),
                text: $viewModel.attemptText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3 ... 6)
            .langoBacktranslationInputAutocorrectionDisabled()
            .padding(12)
            .background(LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            )
            Button {
                Task { await viewModel.reveal() }
            } label: {
                Text(localizedString("practice.backtranslation.reveal"))
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
            .background(LangoTraceDesign.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(viewModel.canReveal ? 1 : 0.5)
            .disabled(!viewModel.canReveal)
        }
        .langoPanel()
    }

    private func referenceCard(_ reference: PracticeBacktranslationReference) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            answerRecap
            referenceBlock(
                titleKey: "practice.backtranslation.reference",
                value: reference.referenceSentence,
                emphasized: true
            )
            if let natural = reference.naturalTranslation {
                referenceBlock(titleKey: "practice.backtranslation.naturalTranslation", value: natural)
            }
            if let literal = reference.literalTranslation {
                referenceBlock(titleKey: "practice.backtranslation.literalTranslation", value: literal)
            }
            if !reference.grammarNotes.isEmpty {
                referenceList(titleKey: "practice.backtranslation.notes", items: reference.grammarNotes)
            }
            if !reference.keyPoints.isEmpty {
                referenceList(titleKey: "practice.backtranslation.keyPoints", items: reference.keyPoints)
            }
            Text(localizedString("practice.backtranslation.hint"))
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                viewModel.retry()
            } label: {
                Label(localizedString("practice.backtranslation.retry"), systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
        .langoPanel()
    }

    private var answerRecap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString("practice.backtranslation.yourAnswer"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Text(viewModel.attemptText)
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func referenceBlock(titleKey: String, value: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString(titleKey))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Text(value)
                .font(emphasized ? .body.weight(.medium) : .body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func referenceList(titleKey: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString(titleKey))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("· \(item)")
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func navigateSentence(direction: PracticeSentenceNavigationDirection) {
        guard !viewModel.isSubmitting,
              let nextSeed = routeSeed.neighboringSeed(direction: direction, capturedAt: Date())
        else {
            return
        }
        onNavigateSentence(nextSeed)
    }
}

private extension View {
    @ViewBuilder
    func langoBacktranslationInputAutocorrectionDisabled() -> some View {
        #if os(iOS)
            autocorrectionDisabled(true)
        #else
            self
        #endif
    }
}
