/// Pure decision model for continuous ("read aloud the whole passage") sentence playback.
///
/// It owns only the sequence position; the orchestrator (the content store) drives audio
/// and feeds it three events: start, natural completion of the current sentence, and stop.
/// Keeping the decision logic here — free of audio, actors, and timers — makes the
/// auto-advance behavior unit-testable without a running playback stack.
///
/// This is the testable core of the continuous-TTS feature (方案 B): the orchestrator holds
/// the continuation intent (an active `currentIndex`) and only advances on a real natural
/// completion, so a sentence going idle because of a user stop never auto-advances.
public struct SentenceSequencePlayback: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        /// Play the sentence at this index.
        case play(Int)
        /// The sequence has nothing (more) to play.
        case finished
    }

    public private(set) var totalCount: Int
    /// The sentence index currently being played, or nil when the sequence is inactive.
    public private(set) var currentIndex: Int?

    public init(totalCount: Int) {
        self.totalCount = max(0, totalCount)
        currentIndex = nil
    }

    public var isActive: Bool {
        currentIndex != nil
    }

    /// Begin the sequence at `index`. Returns the first step to perform.
    public mutating func start(at index: Int) -> Step {
        guard totalCount > 0, index >= 0, index < totalCount else {
            currentIndex = nil
            return .finished
        }
        currentIndex = index
        return .play(index)
    }

    /// The current sentence finished playing naturally. Returns the next step.
    public mutating func advanceAfterCompletion() -> Step {
        guard let current = currentIndex else {
            return .finished
        }
        let next = current + 1
        guard next < totalCount else {
            currentIndex = nil
            return .finished
        }
        currentIndex = next
        return .play(next)
    }

    /// Stop the sequence (user stop, failure, or leaving the surface).
    public mutating func stop() {
        currentIndex = nil
    }
}
