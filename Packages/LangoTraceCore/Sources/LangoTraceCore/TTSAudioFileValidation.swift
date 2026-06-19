import Foundation

public struct TTSAudioFileValidationInput: Equatable, Sendable {
    public var stagedFile: MediaArtifactStagedFileReference
    public var declaredFormat: TTSAudioFormat
    public var mimeType: String
    public var byteSizeLimit: Int64

    public init(
        stagedFile: MediaArtifactStagedFileReference,
        declaredFormat: TTSAudioFormat,
        mimeType: String,
        byteSizeLimit: Int64
    ) {
        self.stagedFile = stagedFile
        self.declaredFormat = declaredFormat
        self.mimeType = mimeType
        self.byteSizeLimit = byteSizeLimit
    }
}

public struct TTSAudioFileValidationResult: Equatable, Sendable {
    public var status: TTSAudioValidationStatus
    public var metadata: TTSAudioMetadata?

    public init(status: TTSAudioValidationStatus, metadata: TTSAudioMetadata?) {
        self.status = status
        self.metadata = metadata
    }
}

public protocol TTSAudioFileValidating: Sendable {
    func validateTTSAudioFile(_ input: TTSAudioFileValidationInput) async -> TTSAudioFileValidationResult
}
