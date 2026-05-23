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
            guard bytes.starts(with: [0x49, 0x44, 0x33]) || bytes.starts(with: [0xFF]) else {
                return failure(.audioDecodeFailed)
            }
            let metadata = TTSAudioMetadata(
                format: .mp3,
                byteCount: bytes.count,
                durationSeconds: nil,
                sampleRate: nil
            )
            return await success(metadata: metadata, bytes: bytes, previewPolicy: previewPolicy)
        default:
            return failure(.unsupportedAudioFormat)
        }
    }
}

public actor InMemoryTTSAudioPreviewStore: TTSAudioPreviewStore {
    private var audioByID: [String: Data] = [:]

    public init() {}

    public func storePreviewAudio(
        _ bytes: Data,
        format: TTSAudioFormat
    ) -> TTSAudioPreviewResource {
        let id = UUID().uuidString
        audioByID[id] = bytes
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
}

#if canImport(AVFoundation)
    public actor DefaultTTSAudioPreviewPlaybackService: TTSAudioPreviewPlaybackService {
        private let previewStore: any TTSAudioPreviewStore
        private var activePlayers: [String: AVAudioPlayer] = [:]

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
            let player = try AVAudioPlayer(data: bytes)
            player.prepareToPlay()
            guard player.play() else {
                throw TTSAudioPreviewPlaybackError.playbackFailed
            }
            activePlayers[resource.id ?? UUID().uuidString] = player
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
        guard bytes.count >= 44,
              String(data: bytes[0 ..< 4], encoding: .ascii) == "RIFF",
              String(data: bytes[8 ..< 12], encoding: .ascii) == "WAVE",
              String(data: bytes[12 ..< 16], encoding: .ascii) == "fmt ",
              String(data: bytes[36 ..< 40], encoding: .ascii) == "data"
        else {
            return nil
        }

        let sampleRate = Int(readUInt32(bytes, offset: 24))
        let byteRate = Int(readUInt32(bytes, offset: 28))
        let dataSize = Int(readUInt32(bytes, offset: 40))
        guard sampleRate > 0, byteRate > 0, dataSize > 0 else {
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

    func readUInt32(_ bytes: Data, offset: Int) -> UInt32 {
        let slice = bytes[offset ..< (offset + 4)]
        return slice.enumerated().reduce(UInt32(0)) { partial, pair in
            partial | UInt32(pair.element) << UInt32(pair.offset * 8)
        }
    }
}
