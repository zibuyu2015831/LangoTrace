import Foundation
import LangoTraceCore
@testable import LangoTraceSpeech
import Testing

@Suite("TTS audio playback service")
struct TTSAudioPlaybackServiceTests {
    @Test("Playback service delegates ready artifact sources to engine")
    func playbackServiceDelegatesReadySourcesToEngine() async throws {
        let engine = CapturingPlaybackEngine()
        let service = TTSAudioPlaybackService(engine: engine)
        let source = playbackSource()

        let session = try await service.play(source)
        await service.pause()
        try await service.resume()
        await service.stop()

        switch await session.completion() {
        case .success:
            break
        case let .failure(failure):
            Issue.record("Expected successful playback completion, got \(failure)")
        }
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

    @Test("Playback completion monitor falls back after expected audio duration")
    func playbackCompletionMonitorFallsBackAfterExpectedDuration() async {
        let monitor = TTSAudioPlaybackCompletionMonitor()

        monitor.completeAfterPlaybackDuration(0.001, grace: 0.001)

        switch await monitor.result() {
        case .success:
            break
        case let .failure(failure):
            Issue.record("Expected fallback success, got \(failure)")
        }
    }

    @Test("Playback completion monitor keeps explicit result ahead of fallback")
    func playbackCompletionMonitorKeepsExplicitResultAheadOfFallback() async {
        let monitor = TTSAudioPlaybackCompletionMonitor()

        monitor.completeAfterPlaybackDuration(10, grace: 0)
        monitor.complete(.failure(.cancelled))

        switch await monitor.result() {
        case .success:
            Issue.record("Expected explicit cancellation to win")
        case let .failure(failure):
            #expect(failure == .cancelled)
        }
    }

    @Test("Playback completion monitor can cancel duration fallback while paused")
    func playbackCompletionMonitorCanCancelDurationFallbackWhilePaused() async throws {
        let monitor = TTSAudioPlaybackCompletionMonitor()

        monitor.completeAfterPlaybackDuration(0.001, grace: 0.001)
        monitor.cancelFallbackCompletion()
        try await Task.sleep(nanoseconds: 5_000_000)

        #expect(!monitor.hasCompleted)
    }

    @Test("Playback completion monitor replaces a pending fallback when rescheduled")
    func playbackCompletionMonitorReplacesPendingFallbackWhenRescheduled() async throws {
        let monitor = TTSAudioPlaybackCompletionMonitor()

        monitor.completeAfterPlaybackDuration(10, grace: 0)
        monitor.completeAfterPlaybackDuration(0.001, grace: 0.001)
        monitor.cancelFallbackCompletion()
        try await Task.sleep(nanoseconds: 5_000_000)

        #expect(!monitor.hasCompleted)
    }

    @Test("Playback completion monitor stays consistent under concurrent fallback access")
    func playbackCompletionMonitorStaysConsistentUnderConcurrentFallbackAccess() async {
        // Exercises the lock-protected fallback task state; the pre-fix code raced on
        // `fallbackTask` between scheduling, cancellation, and completion (visible under TSan).
        for _ in 0 ..< 50 {
            let monitor = TTSAudioPlaybackCompletionMonitor()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    monitor.completeAfterPlaybackDuration(0.0001, grace: 0)
                }
                group.addTask {
                    monitor.cancelFallbackCompletion()
                }
                group.addTask {
                    monitor.completeAfterPlaybackDuration(10, grace: 0)
                }
                group.addTask {
                    monitor.complete(.failure(.cancelled))
                }
            }

            switch await monitor.result() {
            case .success:
                break
            case let .failure(failure):
                #expect(failure == .cancelled)
            }
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

    func play(fileURL: URL) async throws -> TTSAudioPlaybackSession {
        if let error {
            throw error
        }
        events.append(.play(fileURL))
        return .completed
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
