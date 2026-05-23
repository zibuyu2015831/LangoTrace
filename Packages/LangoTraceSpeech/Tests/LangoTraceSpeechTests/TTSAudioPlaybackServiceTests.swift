import Foundation
import LangoTraceCore
import LangoTraceSpeech
import Testing

@Suite("TTS audio playback service")
struct TTSAudioPlaybackServiceTests {
    @Test("Playback service delegates ready artifact sources to engine")
    func playbackServiceDelegatesReadySourcesToEngine() async throws {
        let engine = CapturingPlaybackEngine()
        let service = TTSAudioPlaybackService(engine: engine)
        let source = playbackSource()

        try await service.play(source)
        await service.pause()
        try await service.resume()
        await service.stop()

        #expect(await engine.events == [
            .play(source.fileURL),
            .pause,
            .resume,
            .stop,
        ])
    }

    @Test("Playback service maps engine failures to stable playback categories")
    func playbackServiceMapsEngineFailures() async throws {
        let source = playbackSource()
        let missingFile = TTSAudioPlaybackService(engine: CapturingPlaybackEngine(error: .fileUnavailable))
        await #expect(throws: SentenceAudioPlaybackFailure.playbackFileUnavailable) {
            try await missingFile.play(source)
        }

        let failedPlayback = TTSAudioPlaybackService(engine: CapturingPlaybackEngine(error: .playbackFailed))
        await #expect(throws: SentenceAudioPlaybackFailure.playbackFailed) {
            try await failedPlayback.play(source)
        }
    }
}

private actor CapturingPlaybackEngine: TTSAudioPlaybackEngine {
    enum Event: Equatable {
        case play(URL)
        case pause
        case resume
        case stop
    }

    private(set) var events: [Event] = []
    private let error: TTSAudioPlaybackEngineError?

    init(error: TTSAudioPlaybackEngineError? = nil) {
        self.error = error
    }

    func play(fileURL: URL) async throws {
        if let error {
            throw error
        }
        events.append(.play(fileURL))
    }

    func pause() async {
        events.append(.pause)
    }

    func resume() async throws {
        events.append(.resume)
    }

    func stop() async {
        events.append(.stop)
    }
}

private func playbackSource() -> MediaArtifactPlaybackSource {
    MediaArtifactPlaybackSource(
        artifactID: "artifact-1",
        fileURL: URL(fileURLWithPath: "/tmp/MediaArtifacts/tts/artifact.mp3"),
        mimeType: "audio/mpeg",
        byteSize: 1024,
        contentHash: String(repeating: "a", count: 64)
    )
}
