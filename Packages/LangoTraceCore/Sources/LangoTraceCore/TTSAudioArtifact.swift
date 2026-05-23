import CryptoKit
import Foundation

public enum TTSSentenceSource: Equatable, Sendable {
    case entry(id: String, sentenceIndex: Int)
    case learningMaterialSentence(materialID: String, sentenceIndex: Int)
    case temporary(operationID: String, sentenceIndex: Int)
}

public struct TTSAudioArtifactKey: Equatable, Sendable {
    public var sentenceSource: TTSSentenceSource
    public var sentenceTextHash: String
    public var targetLanguageCode: String
    public var providerProfileID: String
    public var ttsEndpointID: String
    public var ttsVoiceProfileID: String
    public var adapterKind: String
    public var adapterVersion: String
    public var modelName: String
    public var voiceIDHash: String
    public var outputFormat: TTSAudioFormat
    public var sampleRate: Int?
    public var speed: Double?
    public var pitch: Double?
    public var volume: Double?
    public var instructionsHash: String?
    public var providerParametersHash: String?
    public var configurationFingerprint: String

    public init(
        sentenceSource: TTSSentenceSource,
        sentenceTextHash: String,
        targetLanguageCode: String,
        providerProfileID: String,
        ttsEndpointID: String,
        ttsVoiceProfileID: String,
        adapterKind: String,
        adapterVersion: String,
        modelName: String,
        voiceIDHash: String,
        outputFormat: TTSAudioFormat,
        sampleRate: Int?,
        speed: Double?,
        pitch: Double?,
        volume: Double?,
        instructionsHash: String?,
        providerParametersHash: String?,
        configurationFingerprint: String
    ) {
        self.sentenceSource = sentenceSource
        self.sentenceTextHash = sentenceTextHash
        self.targetLanguageCode = targetLanguageCode
        self.providerProfileID = providerProfileID
        self.ttsEndpointID = ttsEndpointID
        self.ttsVoiceProfileID = ttsVoiceProfileID
        self.adapterKind = adapterKind
        self.adapterVersion = adapterVersion
        self.modelName = modelName
        self.voiceIDHash = voiceIDHash
        self.outputFormat = outputFormat
        self.sampleRate = sampleRate
        self.speed = speed
        self.pitch = pitch
        self.volume = volume
        self.instructionsHash = instructionsHash
        self.providerParametersHash = providerParametersHash
        self.configurationFingerprint = configurationFingerprint
    }

    public var derivationKind: MediaArtifactDerivationKind {
        .ttsAudio
    }

    public var derivationKeyHash: String {
        Self.sha256Hex(for: canonicalRepresentation)
    }
}

public struct TTSAudioArtifactCommitInput: Sendable {
    public var key: TTSAudioArtifactKey
    public var languageSpaceID: String
    public var owner: MediaArtifactOwner
    public var stagedFile: MediaArtifactStagedFileReference
    public var mimeType: String
    public var durationSeconds: Double?
    public var createdAt: Date

    public init(
        key: TTSAudioArtifactKey,
        languageSpaceID: String,
        owner: MediaArtifactOwner,
        stagedFile: MediaArtifactStagedFileReference,
        mimeType: String,
        durationSeconds: Double?,
        createdAt: Date
    ) {
        self.key = key
        self.languageSpaceID = languageSpaceID
        self.owner = owner
        self.stagedFile = stagedFile
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }
}

public struct TTSAudioArtifactMetadata: Equatable, Sendable {
    public var artifact: MediaArtifact
    public var key: TTSAudioArtifactKey

    public init(artifact: MediaArtifact, key: TTSAudioArtifactKey) {
        self.artifact = artifact
        self.key = key
    }
}

private extension TTSAudioArtifactKey {
    var canonicalRepresentation: String {
        [
            "adapterKind=\(adapterKind)",
            "adapterVersion=\(adapterVersion)",
            "configurationFingerprint=\(configurationFingerprint)",
            "instructionsHash=\(instructionsHash ?? "")",
            "modelName=\(modelName)",
            "outputFormat=\(outputFormat.rawValue)",
            "pitch=\(Self.canonicalNumber(pitch))",
            "providerParametersHash=\(providerParametersHash ?? "")",
            "providerProfileID=\(providerProfileID)",
            "sampleRate=\(sampleRate.map(String.init) ?? "")",
            "sentenceSource=\(sentenceSource.canonicalRepresentation)",
            "sentenceTextHash=\(sentenceTextHash)",
            "speed=\(Self.canonicalNumber(speed))",
            "targetLanguageCode=\(targetLanguageCode)",
            "ttsEndpointID=\(ttsEndpointID)",
            "ttsVoiceProfileID=\(ttsVoiceProfileID)",
            "voiceIDHash=\(voiceIDHash)",
            "volume=\(Self.canonicalNumber(volume))",
        ].joined(separator: "\n")
    }

    static func canonicalNumber(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    static func sha256Hex(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension TTSSentenceSource {
    var canonicalRepresentation: String {
        switch self {
        case let .entry(id, sentenceIndex):
            "entry|\(id)|\(sentenceIndex)"
        case let .learningMaterialSentence(materialID, sentenceIndex):
            "learningMaterialSentence|\(materialID)|\(sentenceIndex)"
        case let .temporary(operationID, sentenceIndex):
            "temporary|\(operationID)|\(sentenceIndex)"
        }
    }
}
