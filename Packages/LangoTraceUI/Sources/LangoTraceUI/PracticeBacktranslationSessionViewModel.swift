import Foundation
import LangoTraceCore

/// The reference shown after the user reveals it: the target-language reference
/// sentence plus existing analysis (no new content is generated). Built from the
/// lazily fetched `LearningSentenceAnalysis`, with the sentence snapshot as a
/// graceful fallback. Backtranslation never judges right/wrong, so this carries
/// no score, diff, or correctness signal — only reference material.
struct PracticeBacktranslationReference: Equatable {
    var referenceSentence: String
    var naturalTranslation: String?
    var literalTranslation: String?
    var grammarNotes: [String]
    var keyPoints: [String]

    init(analysis: LearningSentenceAnalysis?, snapshot: PracticeSentenceSnapshot) {
        let fallbackReference = snapshot.targetTextSnapshot
        let fallbackNotes = Self.snapshotNotes(snapshot)

        guard let analysis else {
            referenceSentence = fallbackReference
            naturalTranslation = nil
            literalTranslation = nil
            grammarNotes = fallbackNotes
            keyPoints = []
            return
        }

        let target = analysis.targetSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        referenceSentence = target.isEmpty ? fallbackReference : analysis.targetSentence
        naturalTranslation = Self.cleaned(analysis.naturalTranslation, excluding: referenceSentence)
        literalTranslation = Self.cleaned(analysis.literalTranslation, excluding: nil)
        let notes = analysis.grammarNotes.filter { !$0.isEmpty }
        grammarNotes = notes.isEmpty ? fallbackNotes : notes
        keyPoints = analysis.keyPoints.filter { !$0.isEmpty }
    }

    private static func snapshotNotes(_ snapshot: PracticeSentenceSnapshot) -> [String] {
        guard let note = snapshot.noteSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty
        else {
            return []
        }
        return [note]
    }

    private static func cleaned(_ value: String, excluding reference: String?) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != reference else {
            return nil
        }
        return value
    }
}

/// State machine for a single backtranslation sentence: read the native-language
/// meaning, write your own target-language expression, then reveal the
/// reference for comparison. The reference is withheld until the user reveals it,
/// the comparison is purely a side-by-side read (no scoring, no AI), and the
/// attempt is local primary data persisted on reveal.
@MainActor
final class PracticeBacktranslationSessionViewModel: ObservableObject {
    enum Phase: Equatable {
        case answering
        case revealed
    }

    /// Optional AI critique state (E5 Slice 2). Starts `idle`; only moves to
    /// `sending` on an explicit "Ask AI to review" tap — never automatically.
    enum ReviewState: Equatable {
        case idle
        case sending
        case reviewed(PracticeBacktranslationReviewResult)
        case failed(PracticeBacktranslationReviewFailureCategory)
    }

    private let languageSpaceID: String
    private let snapshot: PracticeSentenceSnapshot
    private let actions: PracticeActions

    @Published private(set) var session: PracticeSession?
    @Published private(set) var isLoading = false
    @Published private(set) var phase: Phase = .answering
    @Published var attemptText = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var failure: PracticeActionFailure?
    @Published private(set) var reference: PracticeBacktranslationReference?
    @Published private(set) var reviewState: ReviewState = .idle
    private var reviewTask: Task<Void, Never>?

    init(
        languageSpaceID: String,
        snapshot: PracticeSentenceSnapshot,
        actions: PracticeActions
    ) {
        self.languageSpaceID = languageSpaceID
        self.snapshot = snapshot
        self.actions = actions
    }

    /// The native-language meaning to translate from. Nil when the snapshot has
    /// no translation, which puts the session into the guidance state.
    var promptText: String? {
        guard let translation = snapshot.translationSnapshot?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !translation.isEmpty
        else {
            return nil
        }
        return translation
    }

    /// Without a native prompt the sentence cannot be posed for backtranslation;
    /// the view shows guidance to generate learning material instead of an empty
    /// prompt, and answering is blocked.
    var isGuidanceState: Bool {
        promptText == nil
    }

    var canReveal: Bool {
        !isGuidanceState
            && !attemptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    /// The reference, exposed only after the user reveals it. Returns nil while
    /// answering so the answer can never be read prematurely.
    var visibleReference: PracticeBacktranslationReference? {
        phase == .revealed ? reference : nil
    }

    func load() async {
        guard session == nil, !isGuidanceState else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            session = try await actions.createOrRestoreSession(languageSpaceID, snapshot)
            failure = nil
        } catch {
            failure = .missingSession
        }
    }

    /// Reveals the reference and persists the attempt. The rich analysis is
    /// fetched lazily here (not pre-loaded into the snapshot); persistence uses
    /// the snapshot's reference text and is decoupled from the analysis seam, so
    /// a seam miss degrades the card without dropping the attempt.
    func reveal() async {
        guard let session, canReveal else {
            return
        }

        let analysis = try? await actions.fetchSentenceAnalysis(
            snapshot.learningMaterialID,
            snapshot.sentenceIndex
        )
        reference = PracticeBacktranslationReference(analysis: analysis, snapshot: snapshot)
        phase = .revealed
        failure = nil

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await actions.submitBacktranslationAttempt(
                session,
                PracticeBacktranslationAttemptSubmission(
                    attemptText: attemptText,
                    referenceText: snapshot.targetTextSnapshot
                )
            )
        } catch {
            failure = .attemptSaveFailed
        }
    }

    /// Whether the explicit "Ask AI to review" action is offered. Only after the
    /// reference is revealed, with a real attempt + reference, and not mid-send.
    var canRequestReview: Bool {
        guard phase == .revealed, reviewState != .sending else {
            return false
        }
        return promptText != nil
            && !attemptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && reviewReferenceSentence != nil
    }

    /// Explicitly sends the attempt for an optional AI critique. This is the ONLY
    /// path that constructs an outbound request — reveal / load / navigation never
    /// send anything (core decision 10: sensitive content only on explicit
    /// trigger).
    func requestReview() {
        guard canRequestReview,
              let nativeSentence = promptText,
              let referenceSentence = reviewReferenceSentence
        else {
            return
        }
        let submission = PracticeBacktranslationReviewSubmission(
            nativeSentence: nativeSentence,
            userAttempt: attemptText,
            referenceSentence: referenceSentence
        )
        reviewState = .sending
        reviewTask?.cancel()
        reviewTask = Task { [weak self, languageSpaceID, actions] in
            do {
                let result = try await actions.reviewBacktranslation(languageSpaceID, submission)
                guard let self, !Task.isCancelled else { return }
                reviewState = .reviewed(result)
            } catch is CancellationError {
                guard let self else { return }
                reviewState = .idle
            } catch let failure as PracticeBacktranslationReviewFailure {
                guard let self else { return }
                self.reviewState = failure.category == .cancelled ? .idle : .failed(failure.category)
            } catch {
                guard let self else { return }
                reviewState = .failed(.providerRejected)
            }
        }
    }

    /// Test seam: awaits the in-flight critique task so deterministic tests can
    /// observe the resolved `reviewState`.
    func drainReviewForTesting() async {
        await reviewTask?.value
    }

    /// Cancels an in-flight critique and returns to the revealed state.
    func cancelReview() {
        reviewTask?.cancel()
        reviewTask = nil
        if reviewState == .sending {
            reviewState = .idle
        }
    }

    /// The reference sentence sent for critique — the revealed reference, falling
    /// back to the snapshot's target text.
    private var reviewReferenceSentence: String? {
        if let reference {
            return reference.referenceSentence
        }
        let snapshotReference = snapshot.targetTextSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshotReference.isEmpty ? nil : snapshot.targetTextSnapshot
    }

    /// Starts a fresh attempt: hides the reference, clears the input, and resets
    /// any critique.
    func retry() {
        reviewTask?.cancel()
        reviewTask = nil
        phase = .answering
        attemptText = ""
        reference = nil
        failure = nil
        reviewState = .idle
    }
}
