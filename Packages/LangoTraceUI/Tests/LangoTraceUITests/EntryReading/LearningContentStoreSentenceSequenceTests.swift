import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store sentence sequence")
@MainActor
struct LearningContentStoreSentenceSequenceTests {
    @Test("Playing a sequence auto-advances through every sentence then deactivates")
    func sequenceAutoAdvancesThroughAllSentences() async {
        let recorder = IndexRecorder()
        let store = makeStore(actions: autoCompletingActions(recorder: recorder))
        let rendering = makeRendering(sentenceCount: 3)

        await store.playSentenceSequence(rendering: rendering, languageSpace: space(), startingAt: 0)

        let finished = await waitUntil { !store.isSentenceSequenceActive }
        #expect(finished)
        #expect(store.activeSequenceSentenceID == nil)
        let played = await recorder.indices
        #expect(played == [0, 1, 2])
    }

    @Test("An explicit single-sentence tap cancels the running sequence")
    func explicitTapCancelsSequence() async {
        let store = makeStore(actions: stayPlayingActions())
        let rendering = makeRendering(sentenceCount: 3)

        await store.playSentenceSequence(rendering: rendering, languageSpace: space(), startingAt: 0)
        #expect(store.isSentenceSequenceActive)

        await store.handleSentenceAudioTap(
            rendering: rendering,
            sentence: rendering.sentences[2],
            sentenceIndex: 2,
            languageSpace: space()
        )

        #expect(!store.isSentenceSequenceActive)
        #expect(store.activeSequenceSentenceID == nil)
    }

    @Test("Stopping the sequence deactivates it")
    func stopDeactivatesSequence() async {
        let store = makeStore(actions: stayPlayingActions())
        let rendering = makeRendering(sentenceCount: 3)

        await store.playSentenceSequence(rendering: rendering, languageSpace: space(), startingAt: 0)
        #expect(store.isSentenceSequenceActive)

        await store.stopSentenceSequence()
        #expect(!store.isSentenceSequenceActive)
        #expect(store.activeSequenceSentenceID == nil)
    }

    // MARK: - Fixtures

    private func makeStore(actions: SentenceAudioPlaybackActions) -> LearningContentStore {
        LearningContentStore(
            repository: InMemoryLearningContentRepository(seedEntries: []),
            spaceID: "space-1",
            sentenceAudioPlaybackActions: actions
        )
    }

    private func makeRendering(sentenceCount: Int) -> LearningRendering {
        LearningRendering(
            id: "material-1",
            entryID: "entry-1",
            targetText: "Full text.",
            promptLabel: "natural",
            providerLabel: "Local Mock",
            isMock: true,
            sourceEntryBodyHash: "hash",
            sentences: (0 ..< sentenceCount).map { index in
                RenderingSentence(
                    id: "sentence-\(index)",
                    translation: "译文\(index)",
                    targetText: "Sentence \(index).",
                    note: "note-\(index)"
                )
            }
        )
    }

    private func space() -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: "space-1",
            name: "English",
            nativeLanguage: "zh-Hans",
            targetLanguage: "English",
            targetLanguageCode: "en",
            level: .a1
        )
    }

    private func autoCompletingActions(recorder: IndexRecorder) -> SentenceAudioPlaybackActions {
        SentenceAudioPlaybackActions(
            handleTap: { request in
                await recorder.record(request.sentenceIndex)
                return .playing(sequenceTestKey(for: request))
            },
            presentationState: { _ in .idle },
            stateUpdates: { request in
                let key = sequenceTestKey(for: request)
                return AsyncStream { continuation in
                    continuation.yield(.playing(key))
                    continuation.yield(.idle) // simulate natural completion
                    continuation.finish()
                }
            },
            stopActivePlayback: {}
        )
    }

    private func stayPlayingActions() -> SentenceAudioPlaybackActions {
        SentenceAudioPlaybackActions(
            handleTap: { request in .playing(sequenceTestKey(for: request)) },
            presentationState: { _ in .idle },
            stateUpdates: { request in
                let key = sequenceTestKey(for: request)
                return AsyncStream { continuation in
                    continuation.yield(.playing(key))
                    // Never completes: the sequence stays on the current sentence.
                }
            },
            stopActivePlayback: {}
        )
    }
}

private func sequenceTestKey(for request: SentenceAudioRequest) -> SentenceAudioKey {
    SentenceAudioKey(
        sentenceSource: request.sentenceSource,
        sentenceTextHash: "hash-\(request.sentenceIndex)",
        targetLanguageCode: request.targetLanguageCode,
        configurationFingerprint: "fingerprint"
    )
}

private actor IndexRecorder {
    private(set) var indices: [Int] = []

    func record(_ index: Int) {
        indices.append(index)
    }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while !condition(), ContinuousClock.now < deadline {
        await Task.yield()
    }
    return condition()
}
