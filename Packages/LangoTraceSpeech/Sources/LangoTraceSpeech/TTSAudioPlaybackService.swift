import Foundation
import LangoTraceCore
#if canImport(AVFoundation)
    import AVFoundation
#endif

public enum TTSAudioPlaybackEngineError: Error, Equatable, Sendable {
    case fileUnavailable
    case initializationFailed
    case playbackFailed
}

public protocol TTSAudioPlaybackEngine: Sendable {
    func play(fileURL: URL) async throws -> TTSAudioPlaybackSession
    func pause() async
    func resume() async throws
    func stop() async
}

public struct TTSAudioPlaybackService: TTSAudioPlaying, Sendable {
    private let engine: any TTSAudioPlaybackEngine

    public init(engine: any TTSAudioPlaybackEngine = DefaultTTSAudioPlaybackEngine()) {
        self.engine = engine
    }

    public func play(_ source: MediaArtifactPlaybackSource) async throws -> TTSAudioPlaybackSession {
        do {
            return try await engine.play(fileURL: source.fileURL)
        } catch let error as TTSAudioPlaybackEngineError {
            throw playbackFailure(for: error)
        }
    }

    public func pause() async {
        await engine.pause()
    }

    public func resume() async throws {
        do {
            try await engine.resume()
        } catch let error as TTSAudioPlaybackEngineError {
            throw playbackFailure(for: error)
        }
    }

    public func stop() async {
        await engine.stop()
    }
}

private extension TTSAudioPlaybackService {
    func playbackFailure(for error: TTSAudioPlaybackEngineError) -> SentenceAudioPlaybackFailure {
        switch error {
        case .fileUnavailable:
            .playbackFileUnavailable
        case .initializationFailed:
            .audioEngineInitializationFailed
        case .playbackFailed:
            .playbackFailed
        }
    }
}

#if canImport(AVFoundation)
    public actor DefaultTTSAudioPlaybackEngine: TTSAudioPlaybackEngine {
        private var player: AVAudioPlayer?
        private var playbackDelegate: AVAudioPlayerCompletionDelegate?

        public init() {}

        public func play(fileURL: URL) async throws -> TTSAudioPlaybackSession {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw TTSAudioPlaybackEngineError.fileUnavailable
            }
            do {
                playbackDelegate?.complete(.failure(.cancelled))
                let player = try AVAudioPlayer(contentsOf: fileURL)
                let playbackDelegate = AVAudioPlayerCompletionDelegate()
                player.delegate = playbackDelegate
                guard player.prepareToPlay() else {
                    throw TTSAudioPlaybackEngineError.initializationFailed
                }
                guard player.play() else {
                    throw TTSAudioPlaybackEngineError.playbackFailed
                }
                self.player = player
                self.playbackDelegate = playbackDelegate
                playbackDelegate.completeAfterPlaybackDuration(player.duration)
                return TTSAudioPlaybackSession {
                    await playbackDelegate.result()
                }
            } catch let error as TTSAudioPlaybackEngineError {
                throw error
            } catch {
                throw TTSAudioPlaybackEngineError.initializationFailed
            }
        }

        public func pause() {
            if player != nil {
                playbackDelegate?.cancelFallbackCompletion()
            }
            player?.pause()
        }

        public func resume() throws {
            guard let player else {
                throw TTSAudioPlaybackEngineError.playbackFailed
            }
            guard player.play() else {
                throw TTSAudioPlaybackEngineError.playbackFailed
            }
            playbackDelegate?.completeAfterPlaybackDuration(player.duration - player.currentTime)
        }

        public func stop() {
            player?.stop()
            player = nil
            playbackDelegate?.complete(.failure(.cancelled))
            playbackDelegate = nil
        }
    }

    class TTSAudioPlaybackCompletionMonitor: NSObject, @unchecked Sendable {
        private let lock = NSLock()
        private var storedResult: Result<Void, SentenceAudioPlaybackFailure>?
        private var continuation: CheckedContinuation<Result<Void, SentenceAudioPlaybackFailure>, Never>?
        private var fallbackTask: Task<Void, Never>?

        deinit {
            fallbackTask?.cancel()
        }

        func result() async -> Result<Void, SentenceAudioPlaybackFailure> {
            await withCheckedContinuation { continuation in
                lock.lock()
                if let storedResult {
                    lock.unlock()
                    continuation.resume(returning: storedResult)
                    return
                }
                self.continuation = continuation
                lock.unlock()
            }
        }

        func complete(_ result: Result<Void, SentenceAudioPlaybackFailure>) {
            lock.lock()
            guard storedResult == nil else {
                lock.unlock()
                return
            }
            storedResult = result
            let continuation = continuation
            self.continuation = nil
            fallbackTask?.cancel()
            fallbackTask = nil
            lock.unlock()
            continuation?.resume(returning: result)
        }

        func completeAfterPlaybackDuration(_ duration: TimeInterval, grace: TimeInterval = 0.5) {
            let delay = max(0, duration + grace)
            fallbackTask?.cancel()
            fallbackTask = Task { [weak self] in
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else {
                    return
                }
                self?.complete(.success(()))
            }
        }

        func cancelFallbackCompletion() {
            lock.lock()
            fallbackTask?.cancel()
            fallbackTask = nil
            lock.unlock()
        }

        var hasCompleted: Bool {
            lock.lock()
            defer {
                lock.unlock()
            }
            return storedResult != nil
        }
    }

    private final class AVAudioPlayerCompletionDelegate: TTSAudioPlaybackCompletionMonitor,
        AVAudioPlayerDelegate,
        @unchecked Sendable
    {
        func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
            complete(flag ? .success(()) : .failure(.playbackFailed))
        }

        func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: (any Error)?) {
            complete(.failure(.playbackFailed))
        }
    }
#else
    public actor DefaultTTSAudioPlaybackEngine: TTSAudioPlaybackEngine {
        public init() {}

        public func play(fileURL _: URL) async throws -> TTSAudioPlaybackSession {
            throw TTSAudioPlaybackEngineError.initializationFailed
        }

        public func pause() {}

        public func resume() async throws {
            throw TTSAudioPlaybackEngineError.playbackFailed
        }

        public func stop() {}
    }
#endif
