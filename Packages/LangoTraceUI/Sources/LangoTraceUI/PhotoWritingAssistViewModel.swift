import Foundation
import LangoTraceCore

/// State machine for the explicit photo-writing AI assist action on the
/// photo-writing screen. Starts `idle`; only moves to `sending` on an explicit
/// user tap (after
/// the request-preview confirmation) — never automatically on photo selection,
/// scroll, or navigation (core decision 10).
///
/// The photo is routed through `actions.sanitizeImage` before any request, so a
/// request can only ever carry the downsampled, EXIF/GPS-stripped image — never
/// the raw picker bytes (privacy floor P1-2). Re-triggering cancels the prior
/// in-flight task; cancelling returns to idle and never touches the user's draft.
@MainActor
final class PhotoWritingAssistViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case sending
        case result(PhotoWritingAssistResult)
        case failed(PhotoWritingAssistFailureCategory)
    }

    @Published private(set) var state: State = .idle
    @Published var selectedMode: PhotoWritingAssistMode = .writingSuggestions

    private let languageSpace: LanguageSpacePreview
    private let actions: PhotoWritingActions
    private var task: Task<Void, Never>?
    /// Monotonic token so a superseded or cancelled task can never clobber the
    /// state of a newer request (reentrancy correctness, P1-7).
    private var generation = 0

    init(languageSpace: LanguageSpacePreview, actions: PhotoWritingActions) {
        self.languageSpace = languageSpace
        self.actions = actions
    }

    var isSending: Bool {
        state == .sending
    }

    /// The failure where the endpoint can take images but the user has not
    /// enabled image input: the view shows guidance (open AI Provider settings)
    /// rather than a hard error.
    var isImageInputGuidance: Bool {
        if case .failed(.imageInputNotEnabled) = state {
            return true
        }
        return false
    }

    /// The text to append non-destructively to the draft when the user adopts the
    /// result. Only the native-language draft is directly adoptable; writing
    /// suggestions are read-only scaffolding (no overwrite of the user's text).
    var adoptableText: String? {
        guard case let .result(result) = state else {
            return nil
        }
        switch result.payload {
        case let .sourceLanguageDraft(draft):
            return draft.draft
        case .writingSuggestions:
            return nil
        }
    }

    /// Builds the non-image input for the current mode from the language space.
    func makeInput(note: String) -> PhotoWritingAssistInput {
        PhotoWritingAssistInput(
            mode: selectedMode,
            userNote: note,
            nativeLanguageCode: languageSpace.nativeLanguageCode,
            targetLanguageCode: languageSpace.targetLanguageCode,
            proficiencyLevelCode: languageSpace.level.rawValue.lowercased()
        )
    }

    /// Sends the photo (sanitized first) + note for assist. The ONLY path that
    /// builds an outbound request. Re-triggering cancels any in-flight task.
    func requestAssist(imageData: Data, note: String) {
        let input = makeInput(note: note)
        task?.cancel()
        generation += 1
        let myGeneration = generation
        state = .sending
        task = Task { [weak self, actions] in
            do {
                let sanitized = try await actions.sanitizeImage(imageData)
                try Task.checkCancellation()
                let result = try await actions.requestAssist(input, sanitized)
                guard let self, !Task.isCancelled, generation == myGeneration else { return }
                state = .result(result)
            } catch is CancellationError {
                guard let self, generation == myGeneration else { return }
                if state == .sending {
                    state = .idle
                }
            } catch let failure as PhotoWritingAssistRequestFailure {
                guard let self, self.generation == myGeneration else { return }
                self.state = failure.category == .cancelled ? .idle : .failed(failure.category)
            } catch {
                guard let self, generation == myGeneration else { return }
                state = .failed(.providerRejected)
            }
        }
    }

    /// Cancels an in-flight request and returns to idle. Never touches the draft.
    /// Bumps the generation so the cancelled task cannot reassert any state.
    func cancel() {
        task?.cancel()
        task = nil
        generation += 1
        if state == .sending {
            state = .idle
        }
    }

    /// Dismisses the current result / failure back to idle (e.g. after adopting).
    func reset() {
        task?.cancel()
        task = nil
        generation += 1
        state = .idle
    }

    /// Test seam: awaits the in-flight task so deterministic tests can observe the
    /// resolved state.
    func drainForTesting() async {
        await task?.value
    }
}
