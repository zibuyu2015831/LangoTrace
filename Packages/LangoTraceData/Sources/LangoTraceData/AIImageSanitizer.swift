import CoreGraphics
import Foundation
import ImageIO
import LangoTraceCore
import UniformTypeIdentifiers

/// Produces the privacy-sanitized, downsampled image the AI request boundary
/// accepts (`SanitizedAIImage`). This is the **single entry** that turns raw
/// camera-roll / `PhotosPicker` bytes into something sendable (self-review P1-1 /
/// P1-2): there is no path that hands the stored original or the 256px list
/// thumbnail to an AI request.
///
/// It downsamples to a controlled max edge and re-encodes JPEG, lowering quality
/// until the result fits the byte budget. Like `PhotoImportPipeline`, it relies
/// on ImageIO's thumbnail re-render, which produces a fresh image carrying none
/// of the source's EXIF/GPS metadata — so the sent bytes are both smaller and
/// metadata-free.
public enum AIImageSanitizer {
    /// Longest-edge ceiling for the image sent to the model. Large enough for the
    /// model to read a scene, small enough to keep the request light.
    public static let defaultMaxEdge = 1024
    /// Encoded byte ceiling (pre-base64). Stays under
    /// `PhotoWritingAssistService.maximumImageBytes` with margin.
    public static let defaultMaxBytes = 1_000_000

    public enum SanitizeError: Error, Equatable, Sendable {
        case invalidImageData
        case encodingFailed
        case cannotFitByteBudget
    }

    private static let qualitySteps: [CGFloat] = [0.7, 0.6, 0.5, 0.4, 0.3]

    /// Sanitizes `data` into a `SanitizedAIImage`, or throws if the bytes are not
    /// a decodable image or cannot be brought under `maxBytes`.
    public static func sanitizeForAI(
        _ data: Data,
        maxEdge: Int = defaultMaxEdge,
        maxBytes: Int = defaultMaxBytes
    ) throws -> SanitizedAIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw SanitizeError.invalidImageData
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw SanitizeError.invalidImageData
        }
        for quality in qualitySteps {
            guard let jpeg = encodeJPEG(image, quality: quality) else {
                throw SanitizeError.encodingFailed
            }
            if jpeg.count <= maxBytes {
                return SanitizedAIImage(
                    base64: jpeg.base64EncodedString(),
                    mimeType: "image/jpeg",
                    byteCount: jpeg.count
                )
            }
        }
        throw SanitizeError.cannotFitByteBudget
    }

    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
