import Foundation
import LangoTraceCore
#if canImport(AVFoundation)
    import AVFoundation
#endif

public struct DefaultTTSAudioValidationService: TTSAudioValidationService {
    private let previewStore: (any TTSAudioPreviewStore)?

    public init(previewStore: (any TTSAudioPreviewStore)? = nil) {
        self.previewStore = previewStore
    }

    public func validateAudio(
        _ bytes: Data,
        declaredFormat: TTSAudioFormat,
        contentType: String?,
        previewPolicy: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        guard !bytes.isEmpty else {
            return failure(.invalidAudioResponse)
        }
        guard isAudioContentType(contentType) else {
            return failure(.invalidAudioResponse)
        }

        switch declaredFormat {
        case .wav:
            guard let metadata = wavMetadata(bytes) else {
                return failure(.audioDecodeFailed)
            }
            return await success(metadata: metadata, bytes: bytes, previewPolicy: previewPolicy)
        case .mp3:
            guard let metadata = decodedAudioMetadata(bytes, format: .mp3) else {
                return failure(.audioDecodeFailed)
            }
            return await success(metadata: metadata, bytes: bytes, previewPolicy: previewPolicy)
        default:
            return failure(.unsupportedAudioFormat)
        }
    }
}

public actor InMemoryTTSAudioPreviewStore: TTSAudioPreviewStore {
    private let maxRetainedPreviews: Int
    private var audioByID: [String: Data] = [:]
    private var retainedIDsInInsertionOrder: [String] = []

    public init(maxRetainedPreviews: Int = 1) {
        self.maxRetainedPreviews = max(1, maxRetainedPreviews)
    }

    public func storePreviewAudio(
        _ bytes: Data,
        format: TTSAudioFormat
    ) -> TTSAudioPreviewResource {
        let id = UUID().uuidString
        audioByID[id] = bytes
        retainedIDsInInsertionOrder.append(id)
        while retainedIDsInInsertionOrder.count > maxRetainedPreviews {
            audioByID[retainedIDsInInsertionOrder.removeFirst()] = nil
        }
        return TTSAudioPreviewResource(
            id: id,
            storage: .memory,
            byteCount: bytes.count,
            format: format
        )
    }

    public func audioData(for resource: TTSAudioPreviewResource) -> Data? {
        guard resource.storage == .memory,
              let id = resource.id
        else {
            return nil
        }
        return audioByID[id]
    }

    public func removeAudio(for resource: TTSAudioPreviewResource) {
        guard let id = resource.id else {
            return
        }
        audioByID[id] = nil
        retainedIDsInInsertionOrder.removeAll { $0 == id }
    }

    public func removeAll() {
        audioByID.removeAll()
        retainedIDsInInsertionOrder.removeAll()
    }
}

#if canImport(AVFoundation)
    public actor DefaultTTSAudioPreviewPlaybackService: TTSAudioPreviewPlaybackService {
        private let previewStore: any TTSAudioPreviewStore
        private var activePlayer: AVAudioPlayer?
        private var cleanupTask: Task<Void, Never>?

        public init(previewStore: any TTSAudioPreviewStore) {
            self.previewStore = previewStore
        }

        public func playPreview(_ resource: TTSAudioPreviewResource) async throws {
            guard resource.storage == .memory else {
                throw TTSAudioPreviewPlaybackError.unsupportedPreviewResource
            }
            guard let bytes = await previewStore.audioData(for: resource) else {
                throw TTSAudioPreviewPlaybackError.missingPreviewAudio
            }
            stopActivePreview()
            let player = try AVAudioPlayer(data: bytes)
            player.prepareToPlay()
            guard player.play() else {
                throw TTSAudioPreviewPlaybackError.playbackFailed
            }
            activePlayer = player
            scheduleCleanup(afterPlaybackDuration: player.duration)
        }

        var activePreviewPlayerCount: Int {
            activePlayer == nil ? 0 : 1
        }

        private func stopActivePreview() {
            cleanupTask?.cancel()
            cleanupTask = nil
            activePlayer?.stop()
            activePlayer = nil
        }

        private func scheduleCleanup(afterPlaybackDuration duration: TimeInterval, grace: TimeInterval = 0.5) {
            let delay = max(0, duration + grace)
            cleanupTask = Task { [weak self] in
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else {
                    return
                }
                await self?.releaseFinishedPreviewPlayer()
            }
        }

        private func releaseFinishedPreviewPlayer() {
            // Re-check on the actor: a replacement preview may have cancelled this cleanup
            // after the sleep already finished, in which case the new player must survive.
            guard !Task.isCancelled else {
                return
            }
            activePlayer = nil
            cleanupTask = nil
        }
    }
#else
    public actor DefaultTTSAudioPreviewPlaybackService: TTSAudioPreviewPlaybackService {
        public init(previewStore _: any TTSAudioPreviewStore) {}

        public func playPreview(_: TTSAudioPreviewResource) async throws {
            throw TTSAudioPreviewPlaybackError.unsupportedPreviewResource
        }
    }
#endif

private extension DefaultTTSAudioValidationService {
    func isAudioContentType(_ contentType: String?) -> Bool {
        guard let contentType else {
            return true
        }
        return contentType.lowercased().contains("audio")
    }

    func success(
        metadata: TTSAudioMetadata,
        bytes: Data,
        previewPolicy: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult {
        let previewResource: TTSAudioPreviewResource? = if previewPolicy == .shortLived {
            if let previewStore {
                await previewStore.storePreviewAudio(bytes, format: metadata.format)
            } else {
                TTSAudioPreviewResource(
                    storage: .memory,
                    byteCount: bytes.count,
                    format: metadata.format
                )
            }
        } else {
            nil
        }
        return TTSAudioValidationResult(
            status: .succeeded,
            metadata: metadata,
            previewResource: previewResource
        )
    }

    func failure(_ category: AIProviderValidationErrorCategory) -> TTSAudioValidationResult {
        TTSAudioValidationResult(status: .failed(category), metadata: nil, previewResource: nil)
    }

    func wavMetadata(_ bytes: Data) -> TTSAudioMetadata? {
        guard bytes.count >= 12,
              String(data: bytes[0 ..< 4], encoding: .ascii) == "RIFF",
              String(data: bytes[8 ..< 12], encoding: .ascii) == "WAVE"
        else {
            return nil
        }

        let riffSize = Int(readUInt32(bytes, offset: 4)) + 8
        var offset = 12
        var sampleRate: Int?
        var byteRate: Int?
        var dataSize: Int?

        while offset + 8 <= riffSize {
            let chunkID = String(data: bytes[offset ..< (offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = Int(readUInt32(bytes, offset: offset + 4))

            if chunkID == "fmt " {
                // Minimum fmt chunk is 16 bytes (PCM), extended fmt may be larger
                guard offset + 8 + 16 <= bytes.count else { return nil }
                sampleRate = Int(readUInt32(bytes, offset: offset + 12))
                byteRate = Int(readUInt32(bytes, offset: offset + 16))
            } else if chunkID == "data" {
                dataSize = chunkSize
            }
            // Skip other chunks (LIST, fact, etc.) — they are valid WAV structures

            // Chunks are word-aligned: advance by chunkSize rounded up to even
            let advance = 8 + chunkSize + (chunkSize % 2)
            offset += advance
        }

        guard let sampleRate, sampleRate > 0,
              let byteRate, byteRate > 0,
              let dataSize, dataSize > 0
        else {
            return nil
        }

        let duration = Double(dataSize) / Double(byteRate)
        return TTSAudioMetadata(
            format: .wav,
            byteCount: bytes.count,
            durationSeconds: (duration * 1000).rounded() / 1000,
            sampleRate: sampleRate
        )
    }

    func decodedAudioMetadata(_ bytes: Data, format: TTSAudioFormat) -> TTSAudioMetadata? {
        #if canImport(AVFoundation)
            do {
                let player = try AVAudioPlayer(data: bytes)
                guard player.prepareToPlay() else {
                    return nil
                }
                let duration = player.duration.isFinite && player.duration > 0
                    ? (player.duration * 1000).rounded() / 1000
                    : nil
                return TTSAudioMetadata(
                    format: format,
                    byteCount: bytes.count,
                    durationSeconds: duration,
                    sampleRate: nil
                )
            } catch {
                return nil
            }
        #else
            return nil
        #endif
    }

    func readUInt32(_ bytes: Data, offset: Int) -> UInt32 {
        let slice = bytes[offset ..< (offset + 4)]
        return slice.enumerated().reduce(UInt32(0)) { partial, pair in
            partial | UInt32(pair.element) << UInt32(pair.offset * 8)
        }
    }
}
