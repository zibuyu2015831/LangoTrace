#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = "Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png"
let outputURL = URL(fileURLWithPath: outputPath)
let imageSize = 256
let squareSize = 128
let squareStart = (imageSize - squareSize) / 2
let squareEnd = squareStart + squareSize

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: imageSize,
    pixelsHigh: imageSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: imageSize * 4,
    bitsPerPixel: 32
)
else {
    FileHandle.standardError.write(Data("Failed to allocate AI provider probe bitmap.\n".utf8))
    exit(1)
}

guard let bitmapData = bitmap.bitmapData else {
    FileHandle.standardError.write(Data("Failed to access AI provider probe bitmap bytes.\n".utf8))
    exit(1)
}

for y in 0 ..< imageSize {
    for x in 0 ..< imageSize {
        let offset = (y * imageSize + x) * 4
        let isSquarePixel = x >= squareStart && x < squareEnd && y >= squareStart && y < squareEnd
        bitmapData[offset] = isSquarePixel ? 0 : 255
        bitmapData[offset + 1] = isSquarePixel ? 109 : 255
        bitmapData[offset + 2] = 255
        bitmapData[offset + 3] = 255
    }
}

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode AI provider probe image.\n".utf8))
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
