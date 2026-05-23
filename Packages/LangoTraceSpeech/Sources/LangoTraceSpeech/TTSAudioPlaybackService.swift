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
    func play(fileURL: URL) async throws
    func pause() async
    func resume() async throws
    func stop() async
}

public struct TTSAudioPlaybackService: TTSAudioPlaying, Sendable {
    private let engine: any TTSAudioPlaybackEngine

    public init(engine: any TTSAudioPlaybackEngine = DefaultTTSAudioPlaybackEngine()) {
        self.engine = engine
    }

    public func play(_ source: MediaArtifactPlaybackSource) async throws {
        do {
            try await engine.play(fileURL: source.fileURL)
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

        public init() {}

        public func play(fileURL: URL) async throws {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw TTSAudioPlaybackEngineError.fileUnavailable
            }
            do {
                let player = try AVAudioPlayer(contentsOf: fileURL)
                guard player.prepareToPlay() else {
                    throw TTSAudioPlaybackEngineError.initializationFailed
                }
                guard player.play() else {
                    throw TTSAudioPlaybackEngineError.playbackFailed
                }
                self.player = player
            } catch let error as TTSAudioPlaybackEngineError {
                throw error
            } catch {
                throw TTSAudioPlaybackEngineError.initializationFailed
            }
        }

        public func pause() {
            player?.pause()
        }

        public func resume() throws {
            guard let player else {
                throw TTSAudioPlaybackEngineError.playbackFailed
            }
            guard player.play() else {
                throw TTSAudioPlaybackEngineError.playbackFailed
            }
        }

        public func stop() {
            player?.stop()
            player = nil
        }
    }
#else
    public actor DefaultTTSAudioPlaybackEngine: TTSAudioPlaybackEngine {
        public init() {}

        public func play(fileURL _: URL) async throws {
            throw TTSAudioPlaybackEngineError.initializationFailed
        }

        public func pause() {}

        public func resume() async throws {
            throw TTSAudioPlaybackEngineError.playbackFailed
        }

        public func stop() {}
    }
#endif
