import Foundation
import LangoTraceCore
import LangoTraceSpeech
import Testing

@Suite("TTS audio file validator")
struct TTSAudioFileValidatorTests {
    @Test("File validator rejects empty and non audio files with stable categories")
    func fileValidatorRejectsInvalidFiles() async throws {
        let root = temporaryRoot()
        let validator = TTSAudioFileValidator(mediaArtifactsRoot: root)
        try write(Data(), to: root.appendingPathComponent("staging/empty.tmp"))
        try write(Data("not audio".utf8), to: root.appendingPathComponent("staging/text.tmp"))

        let empty = await validator.validateTTSAudioFile(input(relativePath: "staging/empty.tmp"))
        let text = await validator.validateTTSAudioFile(input(relativePath: "staging/text.tmp"))

        #expect(empty.status == .failed(.invalidAudioResponse))
        #expect(text.status == .failed(.audioDecodeFailed))
    }

    @Test("File validator rejects files over size limit")
    func fileValidatorRejectsOversizedFiles() async throws {
        let root = temporaryRoot()
        let validator = TTSAudioFileValidator(mediaArtifactsRoot: root)
        try write(Data("audio".utf8), to: root.appendingPathComponent("staging/audio.tmp"))

        let result = await validator.validateTTSAudioFile(
            input(relativePath: "staging/audio.tmp", byteSizeLimit: 4)
        )

        #expect(result.status == .failed(.invalidAudioResponse))
    }

    @Test("File validator accepts simple WAV file and reports metadata")
    func fileValidatorAcceptsWAVFile() async throws {
        let root = temporaryRoot()
        let validator = TTSAudioFileValidator(mediaArtifactsRoot: root)
        let wav = wavFixture(sampleRate: 16000, samples: 3200)
        try write(wav, to: root.appendingPathComponent("staging/audio.wav"))

        let result = await validator.validateTTSAudioFile(
            input(
                relativePath: "staging/audio.wav",
                byteSize: Int64(wav.count),
                contentHash: "hash",
                declaredFormat: .wav,
                mimeType: "audio/wav",
                byteSizeLimit: 10_000
            )
        )

        #expect(result.status == .succeeded)
        #expect(result.metadata?.format == .wav)
        #expect(result.metadata?.byteCount == wav.count)
        #expect(result.metadata?.sampleRate == 16000)
    }

    private func input(
        relativePath: String,
        byteSize: Int64 = 8,
        contentHash: String = "hash",
        declaredFormat: TTSAudioFormat = .mp3,
        mimeType: String = "audio/mpeg",
        byteSizeLimit: Int64 = 1_000
    ) -> TTSAudioFileValidationInput {
        TTSAudioFileValidationInput(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: relativePath,
                byteSize: byteSize,
                contentHash: contentHash
            ),
            declaredFormat: declaredFormat,
            mimeType: mimeType,
            byteSizeLimit: byteSizeLimit
        )
    }
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("MediaArtifacts", isDirectory: true)
}

private func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
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
