import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PracticeSentenceListView: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    let languageSpace: LanguageSpacePreview
    let sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState]
    let onListenSentence: (LearningRendering, RenderingSentence, Int) -> Void
    let onPracticeSentence: (PracticeSessionRouteSeed) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(titleKey: "practice.shadowing.title", subtitle: entry.title)
                if let rendering {
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        SentencePairView(
                            index: index + 1,
                            sentence: sentence,
                            playbackState: sentenceAudioPlaybackStates[sentence.id] ?? .idle,
                            onListen: {
                                onListenSentence(rendering, sentence, index)
                            },
                            onPractice: {
                                onPracticeSentence(
                                    PracticeSessionRouteSeed(
                                        entry: entry,
                                        rendering: rendering,
                                        sentence: sentence,
                                        sentenceIndex: index,
                                        targetLanguageCode: languageSpace.targetLanguageCode,
                                        capturedAt: Date()
                                    )
                                )
                            }
                        )
                    }
                } else {
                    CapabilityStatusRow(
                        localizedTitleKey: "practice.noContent.title",
                        localizedSummaryKey: "practice.noContent.summary",
                        status: .unavailable,
                        systemImage: "waveform",
                        action: nil
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle(localizedText("practice.title"))
        .langoPageBackground()
    }
}

struct PracticeSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions
    let onPlayDemo: @MainActor @Sendable () async -> SentenceAudioPresentationState
    let onStopDemo: @MainActor @Sendable () async -> Void
    let onNavigateSentence: (PracticeSessionRouteSeed) -> Void

    @StateObject private var viewModel: PracticeSessionViewModel
    @State private var isTranslationExpanded = false
    @State private var isExplanationExpanded = false

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
        self.onPlayDemo = onPlayDemo
        self.onStopDemo = onStopDemo
        self.onNavigateSentence = onNavigateSentence
        _viewModel = StateObject(
            wrappedValue: PracticeSessionViewModel(
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
                PracticePromptCard(
                    snapshot: routeSeed.snapshot,
                    isTranslationExpanded: isTranslationExpanded,
                    isExplanationExpanded: isExplanationExpanded,
                    onToggleTranslation: {
                        isTranslationExpanded.toggle()
                    },
                    onToggleExplanation: {
                        isExplanationExpanded.toggle()
                    }
                )
                if let session = viewModel.session {
                    PracticeControlBar(
                        session: session,
                        isRecording: viewModel.isRecording,
                        isPlayingDemo: viewModel.isPlayingDemo,
                        isPlayingRecording: viewModel.isPlayingRecording,
                        onPlayDemo: {
                            Task { await viewModel.playDemo() }
                        },
                        onStartRecording: {
                            Task { await viewModel.startRecording() }
                        },
                        onStopRecording: {
                            Task { await viewModel.stopRecording() }
                        },
                        onPlayRecording: {
                            Task { await viewModel.playLatestRecording() }
                        },
                        onComplete: {
                            Task { await viewModel.completeLatestRecording() }
                        }
                    )
                    PracticeSentenceNavigationBar(
                        routeSeed: routeSeed,
                        isNavigationDisabled: viewModel.isRecording || viewModel.isPlayingRecording,
                        onNavigate: navigateSentence
                    )
                    if let failure = viewModel.visibleFailure {
                        CapabilityStatusRow(
                            localizedTitleKey: "practice.failure.title",
                            localizedSummaryKey: failure.localizedSummaryKey,
                            status: .unavailable,
                            systemImage: "exclamationmark.triangle",
                            action: nil
                        )
                    }
                } else {
                    CapabilityStatusRow(
                        localizedTitleKey: "practice.noContent.title",
                        localizedSummaryKey: "practice.noContent.summary",
                        status: .unavailable,
                        systemImage: "waveform",
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
        .onChange(of: routeSeed.practiceRouteIdentity) { _, _ in
            resetPromptDisclosures()
        }
    }

    private func navigateSentence(direction: PracticeSentenceNavigationDirection) {
        guard !viewModel.isRecording,
              !viewModel.isPlayingRecording,
              let nextSeed = routeSeed.neighboringSeed(direction: direction, capturedAt: Date())
        else {
            return
        }

        Task {
            if viewModel.isPlayingDemo {
                await viewModel.stopDemoPlayback()
            }
            resetPromptDisclosures()
            onNavigateSentence(nextSeed)
        }
    }

    private func resetPromptDisclosures() {
        isTranslationExpanded = false
        isExplanationExpanded = false
    }
}

private struct PracticeSentenceNavigationBar: View {
    let routeSeed: PracticeSessionRouteSeed
    let isNavigationDisabled: Bool
    let onNavigate: (PracticeSentenceNavigationDirection) -> Void

    private var presentation: PracticeSentenceNavigationBarPresentation {
        PracticeSentenceNavigationBarPresentation(
            routeSeed: routeSeed,
            isNavigationDisabled: isNavigationDisabled
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            previousButton
            Spacer(minLength: 8)
            Text(positionSummary)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .layoutPriority(1)
                .accessibilityLabel(positionSummary)
            Spacer(minLength: 8)
            nextButton
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .contain)
    }

    private var previousButton: some View {
        Button {
            onNavigate(.previous)
        } label: {
            Label(localizedString(presentation.previousTitleKey), systemImage: "chevron.left")
                .frame(minHeight: 44)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            presentation.isPreviousDisabled
                ? LangoTraceDesign.ColorToken.textSecondary
                : LangoTraceDesign.ColorToken.accent
        )
        .disabled(presentation.isPreviousDisabled)
        .accessibilityHint(localizedString("practice.navigation.previous.hint"))
    }

    private var nextButton: some View {
        Button {
            onNavigate(.next)
        } label: {
            Label(localizedString(presentation.nextTitleKey), systemImage: "chevron.right")
                .labelStyle(.titleAndIcon)
                .frame(minHeight: 44)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            presentation.isNextDisabled
                ? LangoTraceDesign.ColorToken.textSecondary
                : LangoTraceDesign.ColorToken.accent
        )
        .disabled(presentation.isNextDisabled)
        .accessibilityHint(localizedString("practice.navigation.next.hint"))
    }

    private var positionSummary: String {
        localizedString(
            presentation.positionKey,
            presentation.currentPosition,
            presentation.totalCount
        )
    }
}

struct PracticeSentenceNavigationBarPresentation: Equatable {
    var previousTitleKey: String
    var positionKey: String
    var currentPosition: Int
    var totalCount: Int
    var nextTitleKey: String
    var isPreviousDisabled: Bool
    var isNextDisabled: Bool

    init(routeSeed: PracticeSessionRouteSeed, isNavigationDisabled: Bool) {
        let projection = routeSeed.navigationProjection
        previousTitleKey = "practice.navigation.previous"
        positionKey = projection.positionKey
        currentPosition = projection.currentPosition
        totalCount = projection.totalCount
        nextTitleKey = "practice.navigation.next"
        isPreviousDisabled = isNavigationDisabled || !routeSeed.hasPreviousSentence
        isNextDisabled = isNavigationDisabled || !routeSeed.hasNextSentence
    }
}

private extension View {
    @ViewBuilder
    func langoPracticeInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
