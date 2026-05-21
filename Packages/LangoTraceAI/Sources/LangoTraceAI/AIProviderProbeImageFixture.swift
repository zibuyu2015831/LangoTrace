import Foundation

public struct AIProviderProbeImageFixture: Sendable {
    public let mimeType: String
    public let data: Data

    public var dataURLString: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    public static func blueSquare() throws -> AIProviderProbeImageFixture {
        guard let url = Bundle.module.url(
            forResource: "blue-square",
            withExtension: "png"
        ) else {
            throw AIProviderProbeImageFixtureError.missingResource
        }
        let data = try Data(contentsOf: url)
        return AIProviderProbeImageFixture(
            mimeType: "image/png",
            data: data
        )
    }
}

public enum AIProviderProbeImageFixtureError: Error, Equatable, Sendable {
    case missingResource
}
