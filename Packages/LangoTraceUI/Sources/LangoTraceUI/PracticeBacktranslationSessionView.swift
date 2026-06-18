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
            reviewSection
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

    /// Optional AI critique (E5 Slice 2). The footnote pre-discloses the send
    /// scope and timing; the request only fires on the explicit button tap.
    @ViewBuilder
    private var reviewSection: some View {
        Divider()
        Text(localizedString("practice.backtranslation.review.footnote"))
            .font(.caption)
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        switch viewModel.reviewState {
        case .idle:
            Button {
                viewModel.requestReview()
            } label: {
                Label(localizedString("practice.backtranslation.review.button"), systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .opacity(viewModel.canRequestReview ? 1 : 0.5)
            .disabled(!viewModel.canRequestReview)
        case .sending:
            HStack(spacing: 10) {
                ProgressView()
                Text(localizedString("practice.backtranslation.review.sending"))
                    .font(.subheadline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Spacer()
                Button(localizedString("practice.backtranslation.review.cancel")) {
                    viewModel.cancelReview()
                }
                .buttonStyle(.plain)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            }
        case let .reviewed(result):
            reviewResult(result)
        case let .failed(category):
            CapabilityStatusRow(
                localizedTitleKey: "practice.backtranslation.review.failed.title",
                localizedSummaryKey: reviewFailureSummaryKey(category),
                status: .unavailable,
                systemImage: "exclamationmark.triangle",
                action: nil
            )
        }
    }

    private func reviewResult(_ result: PracticeBacktranslationReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.acknowledgement)
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !result.observations.isEmpty {
                referenceList(
                    titleKey: "practice.backtranslation.review.observations",
                    items: result.observations.map { "\($0.phenomenon): \($0.explanation)" }
                )
            }
            if !result.suggestions.isEmpty {
                referenceList(titleKey: "practice.backtranslation.review.suggestions", items: result.suggestions)
            }
            if let registerNote = result.registerNote, !registerNote.isEmpty {
                referenceBlock(titleKey: "practice.backtranslation.review.registerNote", value: registerNote)
            }
        }
    }

    private func reviewFailureSummaryKey(_ category: PracticeBacktranslationReviewFailureCategory) -> String {
        switch category {
        case .providerNotConfigured: "practice.backtranslation.review.failed.providerNotConfigured"
        case .unsupportedProvider, .unsupportedModel: "practice.backtranslation.review.failed.unsupported"
        case .authenticationFailed: "practice.backtranslation.review.failed.authentication"
        case .rateLimited, .providerRejected: "practice.backtranslation.review.failed.providerRejected"
        case .networkUnavailable: "practice.backtranslation.review.failed.network"
        case .timeout: "practice.backtranslation.review.failed.timeout"
        case .cancelled: "practice.backtranslation.review.failed.providerRejected"
        case .invalidStructuredResponse: "practice.backtranslation.review.failed.invalidResponse"
        }
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
