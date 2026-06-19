import Foundation

func wavFixture(sampleRate: Int, samples: Int) -> Data {
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

/// WAV fixture with an extended fmt chunk (40 bytes instead of 16),
/// followed by a LIST chunk, then the data chunk.
/// This exercises the RIFF chunk walker's ability to skip non-fmt/non-data chunks
/// and handle fmt chunks larger than the minimum 16 bytes.
func wavFixtureWithExtendedFmtAndListChunk(sampleRate: Int, samples: Int) -> Data {
    let channelCount = 1
    let bitsPerSample = 16
    let blockAlign = channelCount * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    let dataSize = samples * blockAlign

    // Extended fmt: 16 base + 24 extension bytes = 40 byte fmt chunk data
    let fmtChunkSize = 40
    // LIST chunk: "LIST" + 4 size + "INFO" + 4 bytes of data = 12 byte LIST chunk data
    let listChunkData = Data("INFOtest".utf8)
    let listChunkSize = listChunkData.count

    let totalChunkData = 4 + // "WAVE"
        8 + fmtChunkSize + // "fmt " header + data
        8 + listChunkSize + // "LIST" header + data
        8 + dataSize // "data" header + data
    let riffSize = totalChunkData

    var data = Data()
    // RIFF header
    data.append(contentsOf: "RIFF".utf8)
    data.append(UInt32(riffSize).littleEndianData)
    data.append(contentsOf: "WAVE".utf8)

    // Extended fmt chunk
    data.append(contentsOf: "fmt ".utf8)
    data.append(UInt32(fmtChunkSize).littleEndianData)
    data.append(UInt16(1).littleEndianData) // PCM format
    data.append(UInt16(channelCount).littleEndianData)
    data.append(UInt32(sampleRate).littleEndianData)
    data.append(UInt32(byteRate).littleEndianData)
    data.append(UInt16(blockAlign).littleEndianData)
    data.append(UInt16(bitsPerSample).littleEndianData)
    // Extension: cbSize + valid bits per sample + channel mask + subformat GUID
    data.append(UInt16(24).littleEndianData) // cbSize (extension size)
    data.append(UInt16(bitsPerSample).littleEndianData) // valid bits per sample
    data.append(UInt32(0).littleEndianData) // channel mask (mono center)
    data.append(Data(repeating: 0, count: 16)) // subformat GUID (PCM)

    // LIST chunk
    data.append(contentsOf: "LIST".utf8)
    data.append(UInt32(listChunkSize).littleEndianData)
    data.append(listChunkData)

    // data chunk
    data.append(contentsOf: "data".utf8)
    data.append(UInt32(dataSize).littleEndianData)
    data.append(Data(repeating: 0, count: dataSize))

    return data
}

extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
