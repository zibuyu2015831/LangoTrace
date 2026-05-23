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
}

private func wavFixture(sampleRate: Int, samples: Int) -> Data {
    let channelCount = 1
    let bitsPerSample = 16
    let blockAlign = channelCount * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    let dataSize = samples * blockAlign
    let chunkSize = 36 + dataSize
    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.append(UInt32(chunkSize).littleEndianData)
    data.append(contentsOf: "WAVEfmt ".utf8)
    data.append(UInt32(16).littleEndianData)
    data.append(UInt16(1).littleEndianData)
    data.append(UInt16(channelCount).littleEndianData)
    data.append(UInt32(sampleRate).littleEndianData)
    data.append(UInt32(byteRate).littleEndianData)
    data.append(UInt16(blockAlign).littleEndianData)
    data.append(UInt16(bitsPerSample).littleEndianData)
    data.append(contentsOf: "data".utf8)
    data.append(UInt32(dataSize).littleEndianData)
    data.append(Data(repeating: 0, count: dataSize))
    return data
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
