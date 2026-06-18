import LangoTraceCore
import Testing

@Suite("Sentence sequence playback")
struct SentenceSequencePlaybackTests {
    @Test("Starting plays the requested sentence and marks the sequence active")
    func startPlaysRequestedSentence() {
        var sequence = SentenceSequencePlayback(totalCount: 3)

        #expect(sequence.start(at: 0) == .play(0))
        #expect(sequence.isActive)
        #expect(sequence.currentIndex == 0)
    }

    @Test("Completion advances to the next sentence until the end, then finishes")
    func completionAdvancesUntilEnd() {
        var sequence = SentenceSequencePlayback(totalCount: 3)
        _ = sequence.start(at: 0)

        #expect(sequence.advanceAfterCompletion() == .play(1))
        #expect(sequence.advanceAfterCompletion() == .play(2))
        #expect(sequence.advanceAfterCompletion() == .finished)
        #expect(sequence.isActive == false)
    }

    @Test("Starting partway through advances from that point")
    func startPartway() {
        var sequence = SentenceSequencePlayback(totalCount: 3)
        _ = sequence.start(at: 1)

        #expect(sequence.advanceAfterCompletion() == .play(2))
        #expect(sequence.advanceAfterCompletion() == .finished)
    }

    @Test("Stopping deactivates the sequence so completion no longer advances")
    func stopHaltsAdvance() {
        var sequence = SentenceSequencePlayback(totalCount: 3)
        _ = sequence.start(at: 0)

        sequence.stop()
        #expect(sequence.isActive == false)
        #expect(sequence.advanceAfterCompletion() == .finished)
    }

    @Test("Empty or out-of-range starts finish immediately")
    func emptyOrOutOfRangeFinishes() {
        var empty = SentenceSequencePlayback(totalCount: 0)
        #expect(empty.start(at: 0) == .finished)
        #expect(empty.isActive == false)

        var outOfRange = SentenceSequencePlayback(totalCount: 2)
        #expect(outOfRange.start(at: 5) == .finished)
        #expect(outOfRange.start(at: -1) == .finished)
    }
}
