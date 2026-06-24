import CoreGraphics
import Foundation
import ImageIO
@testable import LangoTraceData
import Testing
import UniformTypeIdentifiers

@Suite("AI image sanitizer (photo-writing assist)")
struct AIImageSanitizerTests {
    @Test("downsamples a large image below the max edge and produces a JPEG data URL")
    func downsamplesLargeImage() throws {
        let data = try makeJPEG(width: 2400, height: 1600)
        let sanitized = try AIImageSanitizer.sanitizeForAI(data, maxEdge: 1024, maxBytes: 1_000_000)

        #expect(sanitized.mimeType == "image/jpeg")
        #expect(sanitized.dataURL.hasPrefix("data:image/jpeg;base64,"))
        #expect(!sanitized.base64.isEmpty)
        #expect(sanitized.byteCount <= 1_000_000)

        let size = try #require(pixelSize(ofBase64JPEG: sanitized.base64))
        #expect(max(size.width, size.height) <= 1024)
        // Actually downsampled, not the original 2400px edge.
        #expect(max(size.width, size.height) < 2400)
    }

    @Test("strips GPS metadata from the sanitized image")
    func stripsGPS() throws {
        let data = try makeJPEG(width: 1200, height: 900, latitude: 37.77, longitude: -122.41)
        // Sanity check: the source actually carries GPS.
        #expect(gpsDictionary(ofJPEG: data) != nil)

        let sanitized = try AIImageSanitizer.sanitizeForAI(data)
        let outBytes = try #require(Data(base64Encoded: sanitized.base64))
        #expect(gpsDictionary(ofJPEG: outBytes) == nil)
    }

    @Test("keeps a small image within the byte budget")
    func smallImageWithinBudget() throws {
        let data = try makeJPEG(width: 200, height: 200)
        let sanitized = try AIImageSanitizer.sanitizeForAI(data)
        #expect(sanitized.byteCount > 0)
        #expect(sanitized.byteCount <= AIImageSanitizer.defaultMaxBytes)
    }

    @Test("throws invalidImageData on non-image bytes")
    func rejectsInvalidData() {
        #expect(throws: AIImageSanitizer.SanitizeError.invalidImageData) {
            _ = try AIImageSanitizer.sanitizeForAI(Data("not an image".utf8))
        }
    }

    // MARK: - Fixtures

    private func makeJPEG(width: Int, height: Int, latitude: Double? = nil, longitude: Double? = nil) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw Failure.imageCreationFailed
        }
        // A non-uniform fill so JPEG has something to encode.
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        guard let cgImage = context.makeImage() else { throw Failure.imageCreationFailed }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw Failure.imageCreationFailed
        }
        var props: [CFString: Any] = [:]
        if let latitude, let longitude {
            props[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: abs(latitude),
                kCGImagePropertyGPSLatitudeRef: latitude >= 0 ? "N" : "S",
                kCGImagePropertyGPSLongitude: abs(longitude),
                kCGImagePropertyGPSLongitudeRef: longitude >= 0 ? "E" : "W",
            ] as [CFString: Any]
        }
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.imageCreationFailed }
        return output as Data
    }

    private func pixelSize(ofBase64JPEG base64: String) -> (width: Int, height: Int)? {
        guard let data = Data(base64Encoded: base64),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (w, h)
    }

    private func gpsDictionary(ofJPEG data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        return props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    }

    private enum Failure: Error { case imageCreationFailed }
}
