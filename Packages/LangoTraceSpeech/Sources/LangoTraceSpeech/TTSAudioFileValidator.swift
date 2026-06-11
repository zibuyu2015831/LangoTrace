import Foundation
import LangoTraceCore

public struct TTSAudioFileValidator: TTSAudioFileValidating, Sendable {
    private let mediaArtifactsRoot: URL
    private let bytesValidator: DefaultTTSAudioValidationService

    public init(
        mediaArtifactsRoot: URL,
        bytesValidator: DefaultTTSAudioValidationService = DefaultTTSAudioValidationService()
    ) {
        self.mediaArtifactsRoot = mediaArtifactsRoot
        self.bytesValidator = bytesValidator
    }

    public func validateTTSAudioFile(_ input: TTSAudioFileValidationInput) async -> TTSAudioFileValidationResult {
        guard input.stagedFile.byteSize <= input.byteSizeLimit else {
            return TTSAudioFileValidationResult(status: .failed(.invalidAudioResponse), metadata: nil)
        }
        guard let fileURL = stagedURL(relativePath: input.stagedFile.relativeStagingPath) else {
            return TTSAudioFileValidationResult(status: .failed(.invalidAudioResponse), metadata: nil)
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let actualByteSize = (attributes[.size] as? NSNumber)?.int64Value,
                  actualByteSize == input.stagedFile.byteSize
            else {
                return TTSAudioFileValidationResult(status: .failed(.invalidAudioResponse), metadata: nil)
            }
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                return TTSAudioFileValidationResult(status: .failed(.invalidAudioResponse), metadata: nil)
            }
            let result = await bytesValidator.validateAudio(
                data,
                declaredFormat: input.declaredFormat,
                contentType: input.mimeType,
                previewPolicy: .none
            )
            return TTSAudioFileValidationResult(status: result.status, metadata: result.metadata)
        } catch {
            return TTSAudioFileValidationResult(status: .failed(.invalidAudioResponse), metadata: nil)
        }
    }
}

private extension TTSAudioFileValidator {
    func stagedURL(relativePath: String) -> URL? {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..")
        else {
            return nil
        }
        return mediaArtifactsRoot.appendingPathComponent(relativePath)
    }
}
