import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Sentence audio playback core contracts")
struct SentenceAudioPlaybackTests {
    @Test("Presentation states and failure categories cover playback lifecycle")
    func presentationStatesAndFailuresCoverPlaybackLifecycle() {
        let key = sampleKey()

        #expect(SentenceAudioPresentationState.idle.isTerminal == false)
        #expect(SentenceAudioPresentationState.generating(key).activeKey == key)
        #expect(SentenceAudioPresentationState.playing(key).activeKey == key)
        #expect(SentenceAudioPresentationState.paused(key).activeKey == key)
        #expect(SentenceAudioPresentationState.requiresConfiguration(.requiresRetest).isRecoverableConfigurationIssue)
        #expect(SentenceAudioPresentationState.failed(.playbackSourceUnavailable).isTerminal)

        let requiredFailures: Set<SentenceAudioPlaybackFailure> = [
            .configurationUnavailable,
            .credentialMissing,
            .notTested,
            .requiresRetest,
            .failedLastTest,
            .unsupportedProvider,
            .networkFailed,
            .authenticationFailed,
            .nonAudioResponse,
            .audioTooLarge,
            .mediaArtifactWriteFailed,
            .persistentFileValidationFailed,
            .stagingWriteFailed,
            .playbackSourceUnavailable,
            .playbackFileUnavailable,
            .audioEngineInitializationFailed,
            .playbackFailed,
            .rateLimited,
            .quotaExceeded,
            .cancelled,
        ]
        #expect(Set(SentenceAudioPlaybackFailure.allCases) == requiredFailures)
    }

    @Test("Core generation contracts keep sensitive text out of summaries")
    func generationContractsKeepSensitiveTextOutOfSummaries() {
        let request = SentenceAudioRequest(
            languageSpaceID: "space-1",
            owner: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 3),
            sentenceSource: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 3),
            sentenceIndex: 3,
            targetText: "My private sentence should not be logged",
            targetLanguageCode: "en"
        )
        let summary = request.nonSensitiveSummary

        #expect(summary.languageSpaceID == "space-1")
        #expect(summary.targetLanguageCode == "en")
        #expect(summary.sentenceIndex == 3)
        #expect(summary.textLengthBucket == .short)
        #expect(!String(describing: summary).contains("private sentence"))
    }

    @Test("Playback source exposes only resolver produced file URLs")
    func playbackSourceContractUsesReadyArtifactIdentity() {
        let source = MediaArtifactPlaybackSource(
            artifactID: "artifact-1",
            fileURL: URL(fileURLWithPath: "/tmp/MediaArtifacts/tts/artifact.mp3"),
            mimeType: "audio/mpeg",
            byteSize: 1_024,
            contentHash: String(repeating: "a", count: 64)
        )

        #expect(source.artifactID == "artifact-1")
        #expect(source.fileURL.isFileURL)
        #expect(source.byteSize == 1_024)
        #expect(source.contentHash.count == 64)
    }

    @Test("Sentence audio reducer handles pause resume cancel and sentence switch")
    func reducerHandlesCoreTransitions() {
        let first = sampleKey(sentenceTextHash: "first")
        let second = sampleKey(sentenceTextHash: "second")
        var state = SentenceAudioPlaybackCoordinatorState()

        #expect(state.reduce(.tap(first)) == [.start(first)])
        #expect(state.activeKey == first)
        #expect(state.presentationState(for: first) == .idle)

        #expect(state.reduce(.generationStarted(first)) == [])
        #expect(state.presentationState(for: first) == .generating(first))

        #expect(state.reduce(.tap(first)) == [.cancelGeneration(first)])
        #expect(state.activeKey == nil)
        #expect(state.presentationState(for: first) == .idle)

        #expect(state.reduce(.tap(first)) == [.start(first)])
        #expect(state.reduce(.playbackStarted(first)) == [])
        #expect(state.presentationState(for: first) == .playing(first))

        #expect(state.reduce(.tap(first)) == [.pause(first)])
        #expect(state.presentationState(for: first) == .paused(first))

        #expect(state.reduce(.tap(first)) == [.resume(first)])
        #expect(state.presentationState(for: first) == .playing(first))

        #expect(state.reduce(.tap(second)) == [.stopPlayback(first), .start(second)])
        #expect(state.activeKey == second)
        #expect(state.presentationState(for: first) == .idle)
        #expect(state.presentationState(for: second) == .idle)
    }

    private func sampleKey(sentenceTextHash: String = "sentence-hash") -> SentenceAudioKey {
        SentenceAudioKey(
            sentenceSource: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
            sentenceTextHash: sentenceTextHash,
            targetLanguageCode: "en",
            configurationFingerprint: "fingerprint-1"
        )
    }
}
