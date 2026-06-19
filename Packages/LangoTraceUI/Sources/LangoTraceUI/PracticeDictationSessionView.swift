import LangoTraceCore
import SwiftUI

/// Dictation session: listen to the existing TTS for a sentence, type what you
/// heard, then compare locally against the reference. The reference is withheld
/// until the answer is submitted (no peeking while listening), and the diff is a
/// purely local string comparison — never an AI request.
struct PracticeDictationSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions
    let onNavigateSentence: (PracticeSessionRouteSeed) -> Void

    @StateObject private var viewModel: PracticeDictationSessionViewModel

    init(
        languageSpaceID: String,
        routeSeed: PracticeSessionRouteSeed,
        actions: PracticeActions,
        onPlayDemo: @escaping @MainActor @Sendable () async -> SentenceAudioPresentationState = { .idle },
        onStopDemo: @escaping @MainActor @Sendable () async -> Void = {},
        onNavigateSentence: @escaping (PracticeSessionRouteSeed) -> Void = { _ in }
    ) {
        self.languageSpaceID = languageSpaceID
        self.routeSeed = routeSeed
        self.actions = actions
        self.onNavigateSentence = onNavigateSentence
        _viewModel = StateObject(
            wrappedValue: PracticeDictationSessionViewModel(
                languageSpaceID: languageSpaceID,
                snapshot: routeSeed.snapshot,
                actions: actions,
                playDemo: onPlayDemo,
                stopDemo: onStopDemo
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                listenCard
                if viewModel.phase == .listening {
                    inputCard
                } else if let result = viewModel.diffResult {
                    comparedCard(result: result)
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

    private var listenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await viewModel.playDemo() }
            } label: {
                Label(localizedString("practice.dictation.listen"), systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(viewModel.isPlayingDemo)

            Text(localizedString("practice.dictation.listenCount", viewModel.listenCount))
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .accessibilityLabel(localizedString("practice.dictation.listenCount", viewModel.listenCount))
        }
        .langoPanel()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("practice.dictation.yourAnswer"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            TextField(
                localizedString("practice.dictation.input.placeholder"),
                text: $viewModel.attemptText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3 ... 6)
            .langoDictationInputAutocorrectionDisabled()
            .padding(12)
            .background(LangoTraceDesign.ColorToken.elevatedPaper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LangoTraceDesign.ColorToken.hairline, lineWidth: 1)
            )
            Button {
                Task { await viewModel.submit() }
            } label: {
                Text(localizedString("practice.dictation.submit"))
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
            .background(LangoTraceDesign.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(viewModel.canSubmit ? 1 : 0.5)
            .disabled(!viewModel.canSubmit)
        }
        .langoPanel()
    }

    private func comparedCard(result: PracticeDictationDiff.Result) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString("practice.dictation.yourAnswer"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                Text(attributedAttempt(result))
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reference = viewModel.visibleReferenceText {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localizedString("practice.dictation.reference"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    Text(reference)
                        .font(.body)
                        .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(localizedString("practice.dictation.differenceSummary", result.differenceCount))
                .font(.footnote.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.warning)
                .accessibilityLabel(localizedString("practice.dictation.differenceSummary", result.differenceCount))
            Button {
                viewModel.retry()
            } label: {
                Label(localizedString("practice.dictation.retry"), systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
        .langoPanel()
    }

    /// Underlines each acoustic/lexical difference in the user's own answer
    /// (shape + warn color), satisfying "not by color alone" together with the
    /// difference-count text. `missing` segments have no attempt-side span and
    /// are reflected only in the count.
    private func attributedAttempt(_ result: PracticeDictationDiff.Result) -> AttributedString {
        var attributed = AttributedString(result.renderedAttempt)
        let rendered = result.renderedAttempt
        for segment in result.segments where segment.range.lowerBound < segment.range.upperBound {
            let lower = rendered.index(rendered.startIndex, offsetBy: segment.range.lowerBound)
            let upper = rendered.index(rendered.startIndex, offsetBy: segment.range.upperBound)
            guard let attributedRange = Range(lower ..< upper, in: attributed) else {
                continue
            }
            attributed[attributedRange].underlineStyle = .single
            attributed[attributedRange].foregroundColor = LangoTraceDesign.ColorToken.warning
        }
        return attributed
    }

    private func navigateSentence(direction: PracticeSentenceNavigationDirection) {
        guard !viewModel.isSubmitting,
              let nextSeed = routeSeed.neighboringSeed(direction: direction, capturedAt: Date())
        else {
            return
        }
        Task {
            await viewModel.prepareForNavigation()
            onNavigateSentence(nextSeed)
        }
    }
}

private extension View {
    @ViewBuilder
    func langoDictationInputAutocorrectionDisabled() -> some View {
        #if os(iOS)
            autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        #else
            self
        #endif
    }
}
