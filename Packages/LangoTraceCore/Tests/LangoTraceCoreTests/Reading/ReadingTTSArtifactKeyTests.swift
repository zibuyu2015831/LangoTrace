@testable import LangoTraceCore
import Testing

@Suite("Reading TTS artifact key")
struct ReadingTTSArtifactKeyTests {
    @Test("reading sentence source is independent from learning material source")
    func readingSentenceSourceDoesNotCollide() {
        let reading = sampleKey(
            source: .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1")
        )
        let learning = sampleKey(
            source: .learningMaterialSentence(materialID: "doc-1", sentenceIndex: 1)
        )

        #expect(reading.sentenceSource == .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1"))
        #expect(reading.derivationKeyHash != learning.derivationKeyHash)
    }

    @Test("reading sentence source can be used by sentence audio request")
    func readingSentenceSourceFitsSentenceAudioRequest() {
        let request = SentenceAudioRequest(
            languageSpaceID: "space-1",
            owner: .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1"),
            sentenceSource: .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1"),
            sentenceIndex: 0,
            targetText: "This private reading sentence should not be logged.",
            targetLanguageCode: "en"
        )

        #expect(request.sentenceSource == .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1"))
        #expect(request.nonSensitiveSummary.textLengthBucket == .short)
        #expect(!String(describing: request.nonSensitiveSummary).contains("private reading sentence"))
    }

    private func sampleKey(source: TTSSentenceSource) -> TTSAudioArtifactKey {
        TTSAudioArtifactKey(
            sentenceSource: source,
            sentenceTextHash: "sentence-hash",
            targetLanguageCode: "en",
            providerProfileID: "profile-1",
            ttsEndpointID: "endpoint-tts",
            ttsVoiceProfileID: "voice-en",
            adapterKind: "openai_audio_speech",
            adapterVersion: "2026-05-23",
            modelName: "tts-1",
            voiceIDHash: "voice-hash",
            outputFormat: .mp3,
            sampleRate: nil,
            speed: 1.0,
            pitch: nil,
            volume: nil,
            instructionsHash: nil,
            providerParametersHash: nil,
            configurationFingerprint: "fingerprint-1"
        )
    }
}
