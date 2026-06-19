import Foundation
@testable import LangoTraceCore
import Testing

@Suite("Sentence TTS generation contracts")
struct SentenceTTSGenerationContractTests {
    @Test("Staged generation result carries only artifact-safe metadata")
    func generationResultCarriesArtifactSafeMetadata() {
        let staged = MediaArtifactStagedFileReference(
            relativeStagingPath: "staging/operation-1.tmp",
            byteSize: 2048,
            contentHash: String(repeating: "b", count: 64)
        )
        let result = SentenceTTSGenerationResult(
            stagedFile: staged,
            mimeType: "audio/mpeg",
            byteSize: 2048,
            durationSeconds: 1.4,
            diagnostics: SentenceTTSGenerationDiagnostics(
                providerPresetID: "openai",
                endpointPurpose: .tts,
                modelName: "tts-1",
                outputFormat: .mp3,
                textLengthBucket: .short,
                byteSizeBucket: .small,
                durationBucket: .short,
                elapsedMilliseconds: 320
            )
        )

        #expect(result.stagedFile.relativeStagingPath == "staging/operation-1.tmp")
        #expect(result.mimeType == "audio/mpeg")
        #expect(result.diagnostics.textLengthBucket == .short)
        #expect(!String(describing: result.diagnostics).contains("My private sentence"))
    }

    @Test("Sentence TTS diagnostic events and attributes are typed and allowlisted")
    func sentenceTTSDiagnosticsAreTypedAndAllowlisted() {
        #expect(DiagnosticEventName.sentenceTTSGenerationStarted.rawValue == "sentence_tts_generation.started")
        #expect(DiagnosticEventName.sentenceTTSGenerationSucceeded.rawValue == "sentence_tts_generation.succeeded")
        #expect(DiagnosticEventName.sentenceTTSGenerationFailed.rawValue == "sentence_tts_generation.failed")
        #expect(DiagnosticEventName.sentenceAudioPlaybackStarted.rawValue == "sentence_audio_playback.started")
        #expect(DiagnosticEventName.sentenceAudioPlaybackCompleted.rawValue == "sentence_audio_playback.completed")
        #expect(DiagnosticEventName.sentenceAudioPlaybackFailed.rawValue == "sentence_audio_playback.failed")

        #expect(DiagnosticAttribute.outputFormat(.mp3).key == "output_format")
        #expect(DiagnosticAttribute.textLengthBucket(.short).key == "text_length_bucket")
        #expect(DiagnosticAttribute.byteSizeBucket(.small).key == "byte_size_bucket")
        #expect(DiagnosticAttribute.durationBucket(.short).key == "duration_bucket")
        #expect(DiagnosticAttribute.cacheResult(.hit).key == "cache_result")
    }
}
