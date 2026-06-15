import Foundation

public struct SentenceTTSGenerationRequest: Equatable, Sendable {
    public var audioRequest: SentenceAudioRequest
    public var artifactKey: TTSAudioArtifactKey
    public var playableConfiguration: PlayableTTSConfiguration
    public var plaintextSecret: RedactedSecret?

    public init(
        audioRequest: SentenceAudioRequest,
        artifactKey: TTSAudioArtifactKey,
        playableConfiguration: PlayableTTSConfiguration,
        plaintextSecret: RedactedSecret?
    ) {
        self.audioRequest = audioRequest
        self.artifactKey = artifactKey
        self.playableConfiguration = playableConfiguration
        self.plaintextSecret = plaintextSecret
    }
}

public struct SentenceTTSGenerationResult: Equatable, Sendable {
    public var stagedFile: MediaArtifactStagedFileReference
    public var mimeType: String
    public var byteSize: Int64
    public var durationSeconds: Double?
    public var diagnostics: SentenceTTSGenerationDiagnostics

    public init(
        stagedFile: MediaArtifactStagedFileReference,
        mimeType: String,
        byteSize: Int64,
        durationSeconds: Double?,
        diagnostics: SentenceTTSGenerationDiagnostics
    ) {
        self.stagedFile = stagedFile
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.durationSeconds = durationSeconds
        self.diagnostics = diagnostics
    }
}

public struct SentenceTTSGenerationDiagnostics: Equatable, Sendable, CustomStringConvertible {
    public var providerPresetID: String
    public var endpointPurpose: AIProviderEndpointPurpose
    public var modelName: String
    public var outputFormat: TTSAudioFormat
    public var textLengthBucket: SentenceAudioTextLengthBucket
    public var byteSizeBucket: SentenceAudioByteSizeBucket
    public var durationBucket: SentenceAudioDurationBucket
    public var elapsedMilliseconds: Int

    public init(
        providerPresetID: String,
        endpointPurpose: AIProviderEndpointPurpose,
        modelName: String,
        outputFormat: TTSAudioFormat,
        textLengthBucket: SentenceAudioTextLengthBucket,
        byteSizeBucket: SentenceAudioByteSizeBucket,
        durationBucket: SentenceAudioDurationBucket,
        elapsedMilliseconds: Int
    ) {
        self.providerPresetID = providerPresetID
        self.endpointPurpose = endpointPurpose
        self.modelName = modelName
        self.outputFormat = outputFormat
        self.textLengthBucket = textLengthBucket
        self.byteSizeBucket = byteSizeBucket
        self.durationBucket = durationBucket
        self.elapsedMilliseconds = elapsedMilliseconds
    }

    public var description: String {
        [
            "providerPresetID=\(providerPresetID)",
            "endpointPurpose=\(endpointPurpose.rawValue)",
            "modelName=\(modelName)",
            "outputFormat=\(outputFormat.rawValue)",
            "textLengthBucket=\(textLengthBucket.rawValue)",
            "byteSizeBucket=\(byteSizeBucket.rawValue)",
            "durationBucket=\(durationBucket.rawValue)",
            "elapsedMilliseconds=\(elapsedMilliseconds)",
        ].joined(separator: ",")
    }
}

public protocol TTSAudioStagingWriting: Sendable {
    func writeTTSAudioToStaging(_ data: Data, preferredExtension: String) async throws -> MediaArtifactStagedFileReference
}

public protocol SentenceTTSGenerating: Sendable {
    func generateSentenceTTS(_ request: SentenceTTSGenerationRequest) async throws -> SentenceTTSGenerationResult
}
