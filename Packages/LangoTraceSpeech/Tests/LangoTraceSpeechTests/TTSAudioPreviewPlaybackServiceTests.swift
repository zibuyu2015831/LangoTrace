import Foundation
import LangoTraceCore
@testable import LangoTraceSpeech
import Testing

#if canImport(AVFoundation)
    @Suite("TTS audio preview playback service")
    struct TTSAudioPreviewPlaybackServiceTests {
        @Test("Replaying a preview stops and replaces the previous preview player")
        func replayingPreviewStopsAndReplacesPreviousPreviewPlayer() async throws {
            let previewStore = InMemoryTTSAudioPreviewStore(maxRetainedPreviews: 2)
            let service = DefaultTTSAudioPreviewPlaybackService(previewStore: previewStore)
            let wav = wavFixture(sampleRate: 16000, samples: 3200)
            let first = await previewStore.storePreviewAudio(wav, format: .wav)
            let second = await previewStore.storePreviewAudio(wav, format: .wav)

            do {
                try await service.playPreview(first)
                try await service.playPreview(second)
            } catch TTSAudioPreviewPlaybackError.playbackFailed {
                // Headless test environments without an audio output device cannot start playback.
                return
            }

            #expect(await service.activePreviewPlayerCount == 1)
        }

        @Test("Finished preview players are released after the playback duration elapses")
        func finishedPreviewPlayersAreReleasedAfterPlaybackDuration() async throws {
            let previewStore = InMemoryTTSAudioPreviewStore()
            let service = DefaultTTSAudioPreviewPlaybackService(previewStore: previewStore)
            // 800 samples at 16 kHz is a 0.05 second clip.
            let wav = wavFixture(sampleRate: 16000, samples: 800)
            let resource = await previewStore.storePreviewAudio(wav, format: .wav)

            do {
                try await service.playPreview(resource)
            } catch TTSAudioPreviewPlaybackError.playbackFailed {
                // Headless test environments without an audio output device cannot start playback.
                return
            }

            #expect(await service.activePreviewPlayerCount == 1)
            // Wait past clip duration (0.05 s) plus the 0.5 s cleanup grace period.
            try await Task.sleep(nanoseconds: 1_000_000_000)
            #expect(await service.activePreviewPlayerCount == 0)
        }
    }
#endif
