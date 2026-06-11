import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Media artifact core contracts")
struct MediaArtifactTests {
    @Test("TTS audio artifact key hash is stable and excludes sensitive plain values")
    func ttsAudioArtifactKeyHashIsStableAndNonSensitive() {
        let key = sampleKey()
        let sameFields = sampleKey()

        #expect(key.derivationKind == .ttsAudio)
        #expect(key.derivationKeyHash == sameFields.derivationKeyHash)
        #expect(key.derivationKeyHash.count == 64)
        #expect(!key.derivationKeyHash.contains("Hello"))
        #expect(!key.derivationKeyHash.contains("alloy"))
        #expect(!key.derivationKeyHash.contains("speak warmly"))
    }

    @Test("TTS audio artifact key changes when output-affecting fields change")
    func ttsAudioArtifactKeyChangesForOutputAffectingFields() {
        let base = sampleKey()

        #expect(sampleKey(sentenceTextHash: "different-text").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(targetLanguageCode: "ja").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(ttsVoiceProfileID: "voice-profile-2").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(voiceIDHash: "voice-hash-2").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(modelName: "tts-2").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(outputFormat: .wav).derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(adapterVersion: "2026-05-24").derivationKeyHash != base.derivationKeyHash)
        #expect(sampleKey(configurationFingerprint: "fingerprint-2").derivationKeyHash != base.derivationKeyHash)
    }

    @Test("TTS audio artifact key hashes negative zero and positive zero identically")
    func ttsAudioArtifactKeyHashesNegativeZeroAndPositiveZeroIdentically() {
        let negativeZero = sampleKey(speed: -0.0)
        let positiveZero = sampleKey(speed: 0.0)

        #expect(negativeZero == positiveZero)
        #expect(negativeZero.derivationKeyHash == positiveZero.derivationKeyHash)
    }

    @Test("Default media artifact policies are local only and excluded by default")
    func defaultMediaArtifactPoliciesAreLocalOnlyExcludedByDefault() {
        let policy = MediaArtifactPolicy.defaultDerivedMediaPolicy

        #expect(policy.backupPolicy == .excludedFromSystemBackup)
        #expect(policy.syncPolicy == .localOnly)
        #expect(policy.exportPolicy == .excludedByDefault)
    }

    @Test("TTS file validation input exposes only staged relative file references")
    func ttsFileValidationInputUsesStagedReferenceWithoutPreviewResource() {
        let input = TTSAudioFileValidationInput(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/op-1.tmp",
                byteSize: 128,
                contentHash: String(repeating: "a", count: 64)
            ),
            declaredFormat: .mp3,
            mimeType: "audio/mpeg",
            byteSizeLimit: 1000
        )
        let result = TTSAudioFileValidationResult(
            status: .succeeded,
            metadata: TTSAudioMetadata(
                format: .mp3,
                byteCount: 128,
                durationSeconds: 1.2,
                sampleRate: nil
            )
        )

        #expect(input.stagedFile.relativeStagingPath == "staging/op-1.tmp")
        #expect(!input.stagedFile.relativeStagingPath.hasPrefix("/"))
        #expect(result.metadata?.byteCount == 128)
    }

    private func sampleKey(
        sentenceTextHash: String = "sentence-hash",
        targetLanguageCode: String = "en",
        ttsVoiceProfileID: String = "voice-profile-1",
        adapterVersion: String = "2026-05-23",
        modelName: String = "tts-1",
        voiceIDHash: String = "voice-hash-1",
        outputFormat: TTSAudioFormat = .mp3,
        speed: Double? = 1.0,
        configurationFingerprint: String = "fingerprint-1"
    ) -> TTSAudioArtifactKey {
        TTSAudioArtifactKey(
            sentenceSource: .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
            sentenceTextHash: sentenceTextHash,
            targetLanguageCode: targetLanguageCode,
            providerProfileID: "profile-1",
            ttsEndpointID: "endpoint-1",
            ttsVoiceProfileID: ttsVoiceProfileID,
            adapterKind: TTSProviderAdapterKind.openAIAudioSpeech.rawValue,
            adapterVersion: adapterVersion,
            modelName: modelName,
            voiceIDHash: voiceIDHash,
            outputFormat: outputFormat,
            sampleRate: nil,
            speed: speed,
            pitch: nil,
            volume: nil,
            instructionsHash: "instructions-hash",
            providerParametersHash: "params-hash",
            configurationFingerprint: configurationFingerprint
        )
    }
}
