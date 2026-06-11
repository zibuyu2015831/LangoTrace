import LangoTraceCore
@testable import LangoTraceUI
import Testing

@Suite("Sentence pair listen button state mapping")
struct SentencePairListenButtonStateTests {
    @Test("Failed playback gets a distinct retry presentation")
    func failedPlaybackGetsDistinctRetryPresentation() {
        let state = SentenceAudioPresentationState.failed(.networkFailed)

        #expect(state.listenButtonTitleKey == "sentenceAudio.listen.retry")
        #expect(state.listenButtonSystemImage == "exclamationmark.arrow.circlepath")
        #expect(state.listenButtonAccessibilityHintKey == "sentenceAudio.listen.failed.hint")
        #expect(state.listenButtonTitleKey != SentenceAudioPresentationState.idle.listenButtonTitleKey)
        #expect(state.listenButtonSystemImage != SentenceAudioPresentationState.idle.listenButtonSystemImage)
    }

    @Test("Configuration-required playback gets a needs-setup presentation")
    func configurationRequiredPlaybackGetsNeedsSetupPresentation() {
        let state = SentenceAudioPresentationState.requiresConfiguration(.notConfigured)

        #expect(state.listenButtonTitleKey == "sentenceAudio.listen.needsSetup")
        #expect(state.listenButtonSystemImage == "speaker.badge.exclamationmark")
        #expect(state.listenButtonAccessibilityHintKey == "sentenceAudio.listen.needsSetup.hint")
        #expect(state.listenButtonSystemImage != SentenceAudioPresentationState.idle.listenButtonSystemImage)
        #expect(state.listenButtonSystemImage
            != SentenceAudioPresentationState.failed(.networkFailed).listenButtonSystemImage)
    }

    @Test("Idle and paused playback keep the default listen presentation")
    func idleAndPausedPlaybackKeepDefaultListenPresentation() {
        #expect(SentenceAudioPresentationState.idle.listenButtonTitleKey == "common.listen")
        #expect(SentenceAudioPresentationState.idle.listenButtonSystemImage == "speaker.wave.2")
        #expect(SentenceAudioPresentationState.idle.listenButtonAccessibilityHintKey == "practice.listen.hint")
    }
}
