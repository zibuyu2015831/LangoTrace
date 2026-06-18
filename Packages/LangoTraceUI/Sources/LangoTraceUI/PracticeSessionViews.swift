import LangoTraceCore
import LangoTraceData
import SwiftUI

struct PracticeSentenceListView: View {
    let entry: LearningEntry
    let rendering: LearningRendering?
    let languageSpace: LanguageSpacePreview
    let sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState]
    let practiceActions: PracticeActions
    let onListenSentence: (LearningRendering, RenderingSentence, Int) -> Void
    let onPracticeSentence: (PracticeSessionRouteSeed) -> Void

    @State private var selectedExerciseType: PracticeExerciseType = .shadowing
    @State private var practicedSentenceIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(titleKey: "practice.shadowing.title", subtitle: entry.title)
                if let rendering {
                    let presentation = listPresentation(for: rendering)
                    if presentation.shouldShowModeSelector {
                        practiceModePicker(modes: presentation.availableModes)
                    }
                    if let continueTarget = presentation.continueTarget,
                       rendering.sentences.indices.contains(continueTarget.sentenceIndex)
                    {
                        continueButton(
                            target: continueTarget,
                            rendering: rendering,
                            sentence: rendering.sentences[continueTarget.sentenceIndex]
                        )
                    }
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        VStack(alignment: .leading, spacing: 8) {
                            SentencePairView(
                                index: index + 1,
                                sentence: sentence,
                                playbackState: sentenceAudioPlaybackStates[sentence.id] ?? .idle,
                                onListen: {
                                    onListenSentence(rendering, sentence, index)
                                },
                                onPractice: {
                                    onPracticeSentence(seed(for: rendering, sentence: sentence, index: index))
                                }
                            )
                            if presentation.rows.indices.contains(index),
                               presentation.rows[index].isPracticed
                            {
                                practicedStatus
                                    .padding(.horizontal, 14)
                            }
                        }
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
        .task(id: practiceProgressTaskID) {
            await loadPracticedSentenceIDs()
        }
    }

    private var practiceModeAvailability: PracticeModeAvailability {
        PracticeModeAvailability(availableModes: practiceActions.availableExerciseTypes)
    }

    private var practiceProgressTaskID: String {
        [
            rendering?.id ?? "no-rendering",
            selectedExerciseType.rawValue,
            practiceActions.availableExerciseTypes.map(\.rawValue).joined(separator: ","),
        ].joined(separator: "::")
    }

    private func listPresentation(for rendering: LearningRendering) -> PracticeSentenceListPresentation {
        PracticeSentenceListPresentation(
            sentences: rendering.sentences,
            selectedMode: selectedExerciseType,
            practicedSentenceIDs: practicedSentenceIDs,
            availability: practiceModeAvailability
        )
    }

    private func seed(
        for rendering: LearningRendering,
        sentence: RenderingSentence,
        index: Int
    ) -> PracticeSessionRouteSeed {
        PracticeSessionRouteSeed(
            entry: entry,
            rendering: rendering,
            sentence: sentence,
            sentenceIndex: index,
            targetLanguageCode: languageSpace.targetLanguageCode,
            exerciseType: selectedExerciseType,
            capturedAt: Date()
        )
    }

    private func loadPracticedSentenceIDs() async {
        guard let rendering else {
            practicedSentenceIDs = []
            return
        }
        do {
            practicedSentenceIDs = try await practiceActions.completedSentenceIDs(rendering.id, selectedExerciseType)
        } catch {
            practicedSentenceIDs = []
        }
    }

    private func practiceModePicker(modes: [PracticeExerciseType]) -> some View {
        Picker(selection: $selectedExerciseType) {
            ForEach(modes, id: \.self) { mode in
                localizedText(mode.localizedTitleKey)
                    .tag(mode)
            }
        } label: {
            localizedText("practice.sentenceList.modePicker")
        }
        .pickerStyle(.segmented)
    }

    private func continueButton(
        target: PracticeSentenceListContinueTarget,
        rendering: LearningRendering,
        sentence: RenderingSentence
    ) -> some View {
        Button {
            onPracticeSentence(seed(for: rendering, sentence: sentence, index: target.sentenceIndex))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.semibold))
                Text(localizedString(target.titleKey, target.position))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .background(LangoTraceDesign.ColorToken.surfaceAccentMuted.opacity(0.7))
            .foregroundStyle(LangoTraceDesign.ColorToken.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var practicedStatus: some View {
        Label {
            localizedText("practice.sentenceList.practiced")
        } icon: {
            Image(systemName: "checkmark.circle.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(LangoTraceDesign.ColorToken.stateReady)
        .accessibilityElement(children: .combine)
    }
}

private extension PracticeExerciseType {
    var localizedTitleKey: String {
        switch self {
        case .shadowing:
            "practice.modes.shadowing"
        case .dictation:
            "practice.modes.dictation"
        case .backtranslation:
            "practice.modes.backtranslation"
        }
    }
}

/// Routes a practice sentence to the view for its exercise type. The three
/// platform shells share this single entry; the exercise type carried by the
/// route seed selects shadowing vs. dictation.
struct PracticeSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions
    let onPlayDemo: @MainActor @Sendable () async -> SentenceAudioPresentationState
    let onStopDemo: @MainActor @Sendable () async -> Void
    let onNavigateSentence: (PracticeSessionRouteSeed) -> Void

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
    }

    var body: some View {
        switch routeSeed.snapshot.exerciseType {
        case .dictation:
            PracticeDictationSessionView(
                languageSpaceID: languageSpaceID,
                routeSeed: routeSeed,
                actions: actions,
                onPlayDemo: onPlayDemo,
                onStopDemo: onStopDemo,
                onNavigateSentence: onNavigateSentence
            )
        case .backtranslation:
            PracticeBacktranslationSessionView(
                languageSpaceID: languageSpaceID,
                routeSeed: routeSeed,
                actions: actions,
                onNavigateSentence: onNavigateSentence
            )
        case .shadowing:
            PracticeShadowingSessionView(
                languageSpaceID: languageSpaceID,
                routeSeed: routeSeed,
                actions: actions,
                onPlayDemo: onPlayDemo,
                onStopDemo: onStopDemo,
                onNavigateSentence: onNavigateSentence
            )
        }
    }
}

struct PracticeShadowingSessionView: View {
    let languageSpaceID: String
    let routeSeed: PracticeSessionRouteSeed
    let actions: PracticeActions
    let onPlayDemo: @MainActor @Sendable () async -> SentenceAudioPresentationState
    let onStopDemo: @MainActor @Sendable () async -> Void
    let onNavigateSentence: (PracticeSessionRouteSeed) -> Void

    @StateObject private var viewModel: PracticeSessionViewModel
    @State private var isTranslationExpanded = false
    @State private var isExplanationExpanded = false
    @State private var controlDeckHeight: CGFloat = 0

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
        let layout = PracticeShadowingLayout.resolve(
            hasSession: viewModel.session != nil,
            hasVisibleFailure: viewModel.visibleFailure != nil
        )
        // Single ScrollView main scroller + bottom-docked control deck (safeAreaInset),
        // so macOS keeps its dedicated, un-nested scrolling (spec 013) while the sentence
        // becomes a vertically-centered Hero that fills the viewport.
        GeometryReader { proxy in
            ScrollView {
                stageContent
                    .frame(maxWidth: stageMaxWidth)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(0, proxy.size.height - controlDeckHeight),
                        alignment: layout.stageFrameAlignment
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if layout.rendersControlDeck, let session = viewModel.session {
                    controlDeck(session: session)
                        .background(
                            GeometryReader { deckProxy in
                                Color.clear.preference(
                                    key: PracticeControlDeckHeightKey.self,
                                    value: deckProxy.size.height
                                )
                            }
                        )
                }
            }
        }
        .onPreferenceChange(PracticeControlDeckHeightKey.self) { controlDeckHeight = $0 }
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

    private let stageMaxWidth: CGFloat = 560

    private var stageContent: some View {
        VStack(alignment: .center, spacing: 18) {
            PracticePromptCard(
                snapshot: routeSeed.snapshot,
                isTranslationExpanded: isTranslationExpanded,
                isExplanationExpanded: isExplanationExpanded,
                isCentered: true,
                onToggleTranslation: {
                    isTranslationExpanded.toggle()
                },
                onToggleExplanation: {
                    isExplanationExpanded.toggle()
                }
            )
            if viewModel.session != nil {
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
    }

    /// Bottom-docked transport: control bar first, in-record navigation after it
    /// (spec 003 §4.3 keeps the navigation below the action card and free of card chrome).
    private func controlDeck(session: PracticeSession) -> some View {
        VStack(spacing: 12) {
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
                }
            )
            PracticeSentenceNavigationBar(
                routeSeed: routeSeed,
                isNavigationDisabled: viewModel.isRecording || viewModel.isPlayingRecording,
                onNavigate: navigateSentence
            )
        }
        .frame(maxWidth: stageMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                LangoTraceDesign.ColorToken.elevatedPaper
                Rectangle()
                    .fill(LangoTraceDesign.ColorToken.hairline)
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
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

struct PracticeSentenceNavigationBar: View {
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

extension View {
    @ViewBuilder
    func langoPracticeInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}
