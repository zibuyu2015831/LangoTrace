import Foundation

public enum TTSAudioValidationStatus: Equatable, Sendable {
    case succeeded
    case failed(AIProviderValidationErrorCategory)
}

public enum TTSAudioPreviewPolicy: Equatable, Sendable {
    case none
    case shortLived
}

public enum TTSAudioPreviewStorage: Equatable, Sendable {
    case memory
}

public struct TTSAudioPreviewResource: Equatable, Sendable {
    public var id: String?
    public var storage: TTSAudioPreviewStorage
    public var byteCount: Int
    public var format: TTSAudioFormat?
    public var persistentFileURL: URL?

    public init(
        id: String? = nil,
        storage: TTSAudioPreviewStorage,
        byteCount: Int,
        format: TTSAudioFormat? = nil,
        persistentFileURL: URL? = nil
    ) {
        self.id = id
        self.storage = storage
        self.byteCount = byteCount
        self.format = format
        self.persistentFileURL = persistentFileURL
    }
}

public struct TTSAudioMetadata: Equatable, Sendable {
    public var format: TTSAudioFormat
    public var byteCount: Int
    public var durationSeconds: Double?
    public var sampleRate: Int?

    public init(
        format: TTSAudioFormat,
        byteCount: Int,
        durationSeconds: Double?,
        sampleRate: Int?
    ) {
        self.format = format
        self.byteCount = byteCount
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
    }
}

public struct TTSAudioValidationResult: Equatable, Sendable {
    public var status: TTSAudioValidationStatus
    public var metadata: TTSAudioMetadata?
    public var previewResource: TTSAudioPreviewResource?

    public init(
        status: TTSAudioValidationStatus,
        metadata: TTSAudioMetadata?,
        previewResource: TTSAudioPreviewResource?
    ) {
        self.status = status
        self.metadata = metadata
        self.previewResource = previewResource
    }
}

public protocol TTSAudioValidationService: Sendable {
    func validateAudio(
        _ bytes: Data,
        declaredFormat: TTSAudioFormat,
        contentType: String?,
        previewPolicy: TTSAudioPreviewPolicy
    ) async -> TTSAudioValidationResult
}

public protocol TTSAudioPreviewStore: Sendable {
    func storePreviewAudio(
        _ bytes: Data,
        format: TTSAudioFormat
    ) async -> TTSAudioPreviewResource
    func audioData(for resource: TTSAudioPreviewResource) async -> Data?
}

public enum TTSAudioPreviewPlaybackError: Error, Equatable, Sendable {
    case unsupportedPreviewResource
    case missingPreviewAudio
    case playbackFailed
}

public protocol TTSAudioPreviewPlaybackService: Sendable {
    func playPreview(_ resource: TTSAudioPreviewResource) async throws
}
