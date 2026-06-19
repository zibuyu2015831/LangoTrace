import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Practice backtranslation session view model")
@MainActor
struct PracticeBacktranslationSessionTests {
    @Test("Reference card stays hidden until the user reveals it")
    func referenceCardHiddenUntilUserReveals() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I booked the train this morning"

        #expect(viewModel.phase == .answering)
        #expect(viewModel.visibleReference == nil)

        await viewModel.reveal()

        #expect(viewModel.phase == .revealed)
        let reference = viewModel.visibleReference
        #expect(reference?.referenceSentence == "I booked the train this morning.")
        #expect(reference?.grammarNotes == ["Present perfect for recent past"])
        #expect(reference?.keyPoints == ["booked"])
    }

    @Test("Revealing persists the attempt with the snapshot reference text, decoupled from the analysis seam")
    func revealPersistsAttemptWithSnapshotReference() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()

        #expect(viewModel.failure == nil)
        #expect(actions.lastSubmission?.attemptText == "I have booked the train")
        #expect(actions.lastSubmission?.referenceText == "I booked the train this morning.")
    }

    @Test("Reference degrades to the snapshot when the analysis seam returns nothing")
    func revealDegradesToSnapshotWhenAnalysisMissing() async {
        let actions = BacktranslationPracticeActions()
        actions.analysis = nil
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()

        let reference = viewModel.visibleReference
        #expect(reference?.referenceSentence == "I booked the train this morning.")
        #expect(reference?.grammarNotes == ["参考表达不止一种，意思贴近即可。"])
        #expect(reference?.naturalTranslation == nil)
        // The attempt still persists even when the seam yields nothing.
        #expect(actions.lastSubmission?.referenceText == "I booked the train this morning.")
    }

    @Test("Persistence failure keeps the revealed reference so the user does not lose it")
    func persistenceFailureKeepsRevealedState() async {
        let actions = BacktranslationPracticeActions()
        actions.shouldFailSubmit = true
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()

        #expect(viewModel.phase == .revealed)
        #expect(viewModel.visibleReference != nil)
        #expect(viewModel.failure == .attemptSaveFailed)
    }

    @Test("Retry returns to answering and hides the reference again")
    func retryReturnsToAnsweringAndHidesReference() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()
        viewModel.retry()

        #expect(viewModel.phase == .answering)
        #expect(viewModel.attemptText.isEmpty)
        #expect(viewModel.visibleReference == nil)
    }

    @Test("Revealing the reference never auto-sends an AI critique (explicit trigger only)")
    func revealNeverAutoSendsReview() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()

        // Reveal + persistence happened, but no critique request was constructed.
        #expect(actions.reviewCallCount == 0)
        #expect(viewModel.reviewState == .idle)
        #expect(viewModel.canRequestReview)
    }

    @Test("Explicit requestReview sends exactly the three short texts and surfaces the result")
    func explicitRequestReviewSendsAndSurfacesResult() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()
        viewModel.requestReview()
        await viewModel.drainReviewForTesting()

        #expect(actions.reviewCallCount == 1)
        #expect(actions.lastReviewSubmission?.userAttempt == "I have booked the train")
        #expect(actions.lastReviewSubmission?.nativeSentence == "我今天早上订了火车票。")
        #expect(actions.lastReviewSubmission?.referenceSentence == "I booked the train this morning.")
        if case let .reviewed(result) = viewModel.reviewState {
            #expect(result.acknowledgement == "Nice work.")
        } else {
            Issue.record("expected reviewed state")
        }
    }

    @Test("A critique failure surfaces a precise category, not a network mask")
    func reviewFailureSurfacesCategory() async {
        let actions = BacktranslationPracticeActions()
        actions.reviewFailure = .providerNotConfigured
        let viewModel = makeViewModel(actions: actions)

        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        await viewModel.reveal()
        viewModel.requestReview()
        await viewModel.drainReviewForTesting()

        #expect(viewModel.reviewState == .failed(.providerNotConfigured))
    }

    @Test("requestReview is unavailable before the reference is revealed")
    func reviewUnavailableBeforeReveal() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions)
        await viewModel.load()
        viewModel.attemptText = "I have booked the train"
        #expect(viewModel.canRequestReview == false)
        viewModel.requestReview()
        #expect(actions.reviewCallCount == 0)
    }

    @Test("A missing native prompt shows the guidance state and blocks answering")
    func missingPromptShowsGuidanceAndBlocksAnswer() async {
        let actions = BacktranslationPracticeActions()
        let viewModel = makeViewModel(actions: actions, snapshot: snapshot(translation: nil))

        await viewModel.load()
        viewModel.attemptText = "anything"

        #expect(viewModel.isGuidanceState)
        #expect(viewModel.canReveal == false)
        #expect(viewModel.session == nil)

        await viewModel.reveal()
        #expect(viewModel.phase == .answering)
        #expect(actions.lastSubmission == nil)
    }

    private func makeViewModel(
        actions: BacktranslationPracticeActions,
        snapshot: PracticeSentenceSnapshot? = nil
    ) -> PracticeBacktranslationSessionViewModel {
        PracticeBacktranslationSessionViewModel(
            languageSpaceID: "space-1",
            snapshot: snapshot ?? self.snapshot(),
            actions: actions.actions
        )
    }

    private func snapshot(translation: String? = "我今天早上订了火车票。") -> PracticeSentenceSnapshot {
        PracticeSentenceSnapshot(
            entryID: "entry-1",
            learningMaterialID: "material-1",
            sentenceID: "sentence-1",
            sentenceIndex: 0,
            targetTextSnapshot: "I booked the train this morning.",
            targetTextHash: String(repeating: "a", count: 64),
            targetLanguageCode: "en",
            translationSnapshot: translation,
            noteSnapshot: "参考表达不止一种，意思贴近即可。",
            sourceEntryBodyHash: "source-hash",
            materialAnalysisSourceHash: nil,
            exerciseType: .backtranslation,
            capturedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private final class BacktranslationPracticeActions: @unchecked Sendable {
    var shouldFailSubmit = false
    var analysis: LearningSentenceAnalysis? = LearningSentenceAnalysis(
        id: "sentence-1",
        nativeSentence: "我今天早上订了火车票。",
        targetSentence: "I booked the train this morning.",
        literalTranslation: "I this morning booked the train.",
        naturalTranslation: "I booked the train this morning.",
        grammarNotes: ["Present perfect for recent past"],
        keyPoints: ["booked"],
        position: 0
    )
    private(set) var lastSubmission: PracticeBacktranslationAttemptSubmission?
    private(set) var reviewCallCount = 0
    private(set) var lastReviewSubmission: PracticeBacktranslationReviewSubmission?
    var reviewResult = PracticeBacktranslationReviewResult(
        schemaVersion: "practice_backtranslation_review.v1",
        acknowledgement: "Nice work.",
        observations: [PracticeBacktranslationReviewObservation(phenomenon: "tense", explanation: "past vs present")],
        suggestions: ["Try present tense."],
        registerNote: nil
    )
    var reviewFailure: PracticeBacktranslationReviewFailureCategory?

    var actions: PracticeActions {
        PracticeActions(
            availableExerciseTypes: [.shadowing, .dictation, .backtranslation],
            createOrRestoreSession: { _, snapshot in
                PracticeSession(
                    id: "backtranslation-session-1",
                    languageSpaceID: "space-1",
                    snapshot: snapshot,
                    createdAt: Date(timeIntervalSince1970: 1)
                )
            },
            startRecording: { _ in throw PracticeActionFailure.disabled },
            stopRecording: { session, _ in session },
            complete: { session, _ in session },
            playRecording: { _, _ in throw PracticeActionFailure.disabled },
            submitBacktranslationAttempt: { [weak self] _, submission in
                if self?.shouldFailSubmit == true {
                    throw PracticeActionFailure.attemptSaveFailed
                }
                self?.lastSubmission = submission
            },
            fetchSentenceAnalysis: { [weak self] _, _ in
                self?.analysis
            },
            reviewBacktranslation: { [weak self] _, submission in
                self?.reviewCallCount += 1
                self?.lastReviewSubmission = submission
                if let category = self?.reviewFailure {
                    throw PracticeBacktranslationReviewFailure(category: category)
                }
                guard let result = self?.reviewResult else {
                    throw PracticeBacktranslationReviewFailure(category: .providerRejected)
                }
                return result
            }
        )
    }
}
