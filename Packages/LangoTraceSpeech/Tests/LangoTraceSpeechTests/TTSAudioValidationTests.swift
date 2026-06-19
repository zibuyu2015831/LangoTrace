import Foundation
import LangoTraceCore
import LangoTraceSpeech
import Testing

@Suite("TTS audio validation")
struct TTSAudioValidationTests {
    @Test("Validator rejects empty and non audio bytes with stable categories")
    func validatorRejectsInvalidAudioBytesWithStableCategories() async {
        let validator = DefaultTTSAudioValidationService()

        let empty = await validator.validateAudio(
            Data(),
            declaredFormat: .mp3,
            contentType: "audio/mpeg",
            previewPolicy: .shortLived
        )
        let text = await validator.validateAudio(
            Data("not audio".utf8),
            declaredFormat: .mp3,
            contentType: "text/plain",
            previewPolicy: .shortLived
        )

        #expect(empty.status == .failed(.invalidAudioResponse))
        #expect(text.status == .failed(.invalidAudioResponse))
    }

    @Test("Validator accepts simple WAV bytes and reports metadata")
    func validatorAcceptsSimpleWAVBytesAndReportsMetadata() async throws {
        let validator = DefaultTTSAudioValidationService()
        let wav = wavFixture(sampleRate: 16000, samples: 3200)

        let result = await validator.validateAudio(
            wav,
            declaredFormat: .wav,
            contentType: "audio/wav",
            previewPolicy: .shortLived
        )

        let metadata = try #require(result.metadata)
        #expect(result.status == .succeeded)
        #expect(metadata.format == .wav)
        #expect(metadata.byteCount == wav.count)
        #expect(metadata.sampleRate == 16000)
        #expect(metadata.durationSeconds == 0.2)
    }

    @Test("Validator rejects MP3 header bytes that are not decodable audio")
    func validatorRejectsMP3HeaderBytesThatAreNotDecodableAudio() async {
        let validator = DefaultTTSAudioValidationService()

        let result = await validator.validateAudio(
            Data([0x49, 0x44, 0x33]),
            declaredFormat: .mp3,
            contentType: "audio/mpeg",
            previewPolicy: .shortLived
        )

        #expect(result.status == .failed(.audioDecodeFailed))
        #expect(result.metadata == nil)
        #expect(result.previewResource == nil)
    }

    @Test("Validator accepts WAV with extended fmt chunk and LIST chunk")
    func validatorAcceptsWAVWithExtendedFmtAndListChunk() async throws {
        let validator = DefaultTTSAudioValidationService()
        let wav = wavFixtureWithExtendedFmtAndListChunk(sampleRate: 22050, samples: 2205)

        let result = await validator.validateAudio(
            wav,
            declaredFormat: .wav,
            contentType: "audio/wav",
            previewPolicy: .shortLived
        )

        let metadata = try #require(result.metadata)
        #expect(result.status == .succeeded)
        #expect(metadata.format == .wav)
        #expect(metadata.byteCount == wav.count)
        #expect(metadata.sampleRate == 22050)
        #expect(metadata.durationSeconds == 0.1)
    }

    @Test("Short lived preview does not create persistent media artifact URL")
    func shortLivedPreviewDoesNotCreatePersistentMediaArtifactURL() async {
        let validator = DefaultTTSAudioValidationService()

        let result = await validator.validateAudio(
            wavFixture(sampleRate: 16000, samples: 3200),
            declaredFormat: .wav,
            contentType: "audio/wav",
            previewPolicy: .shortLived
        )

        #expect(result.previewResource?.storage == .memory)
        #expect(result.previewResource?.persistentFileURL == nil)
    }

    @Test("Short lived preview resource resolves through Speech store without exposing bytes to UI")
    func shortLivedPreviewResourceResolvesThroughSpeechStore() async throws {
        let previewStore = InMemoryTTSAudioPreviewStore()
        let validator = DefaultTTSAudioValidationService(previewStore: previewStore)
        let wav = wavFixture(sampleRate: 16000, samples: 3200)

        let result = await validator.validateAudio(
            wav,
            declaredFormat: .wav,
            contentType: "audio/wav",
            previewPolicy: .shortLived
        )

        let resource = try #require(result.previewResource)
        #expect(resource.id != nil)
        #expect(resource.persistentFileURL == nil)
        #expect(await previewStore.audioData(for: resource) == wav)
    }

    @Test("Preview store keeps only the most recent preview audio by default")
    func previewStoreKeepsOnlyMostRecentPreviewAudioByDefault() async {
        let previewStore = InMemoryTTSAudioPreviewStore()

        let first = await previewStore.storePreviewAudio(Data("first".utf8), format: .wav)
        let second = await previewStore.storePreviewAudio(Data("second".utf8), format: .wav)

        #expect(await previewStore.audioData(for: first) == nil)
        #expect(await previewStore.audioData(for: second) == Data("second".utf8))
    }

    @Test("Preview store supports removing a single preview and clearing all previews")
    func previewStoreSupportsRemovingSinglePreviewAndClearingAllPreviews() async {
        let previewStore = InMemoryTTSAudioPreviewStore(maxRetainedPreviews: 2)

        let first = await previewStore.storePreviewAudio(Data("first".utf8), format: .wav)
        let second = await previewStore.storePreviewAudio(Data("second".utf8), format: .wav)
        await previewStore.removeAudio(for: first)

        #expect(await previewStore.audioData(for: first) == nil)
        #expect(await previewStore.audioData(for: second) == Data("second".utf8))

        await previewStore.removeAll()

        #expect(await previewStore.audioData(for: second) == nil)
    }
}
