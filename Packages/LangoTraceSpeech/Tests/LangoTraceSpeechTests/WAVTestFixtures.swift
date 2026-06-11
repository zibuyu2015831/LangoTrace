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

extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
