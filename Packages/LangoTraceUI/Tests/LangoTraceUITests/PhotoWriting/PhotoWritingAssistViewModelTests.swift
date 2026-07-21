import Foundation
import LangoTraceCore
@testable import LangoTraceUI
import Testing

private func photoAssistTestSpace() -> LanguageSpacePreview {
    LanguageSpacePreview(
        id: "space-1",
        name: "英语",
        nativeLanguage: "中文",
        nativeLanguageCode: "zh-Hans",
        targetLanguage: "English",
        targetLanguageCode: "en",
        level: .b1
    )
}

private func photoAssistSuggestionsResult() -> PhotoWritingAssistResult {
    PhotoWritingAssistResult(
        schemaVersion: "photo_writing_assist.v1",
        mode: .writingSuggestions,
        payload: .writingSuggestions(.init(
            sceneSummary: "一只猫坐在窗边。",
            writingAngles: ["天气"],
            usefulExpressions: [.init(targetText: "by the window", nativeGloss: "在窗边")],
            guidingQuestions: ["你看到了什么？"]
        ))
    )
}

private func photoAssistDraftResult() -> PhotoWritingAssistResult {
    PhotoWritingAssistResult(
        schemaVersion: "photo_writing_assist.v1",
        mode: .sourceLanguageDraft,
        payload: .sourceLanguageDraft(.init(
            draft: "今天我看到一只猫。",
            keyVocabularyHints: [.init(targetText: "cat", nativeGloss: "猫")]
        ))
    )
}

@Suite("Photo-writing assist view model")
@MainActor
struct PhotoWritingAssistViewModelTests {
    private func space() -> LanguageSpacePreview {
        photoAssistTestSpace()
    }

    @Test("sends the sanitized image, never the raw picker bytes (P1-2)")
    func sendsSanitizedImageNotRawBytes() async {
        let recorder = AssistRecorder()
        let sentinel = SanitizedAIImage(base64: "U0FOSVRJWkVE", mimeType: "image/jpeg", byteCount: 9)
        let rawBytes = Data("RAW-PICKER-BYTES".utf8)
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { data in
                await recorder.recordSanitizeInput(data)
                return sentinel
            },
            requestAssist: { _, image in
                await recorder.recordSentImage(image)
                return photoAssistSuggestionsResult()
            }
        )
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)

        viewModel.requestAssist(imageData: rawBytes, note: "note")
        await viewModel.drainForTesting()

        // The sanitizer saw the raw bytes...
        #expect(await recorder.sanitizeInput == rawBytes)
        // ...but the request only ever received the sanitized sentinel.
        #expect(await recorder.sentImage == sentinel)
        #expect(await recorder.sentImage?.base64 != rawBytes.base64EncodedString())
    }

    @Test("a successful request lands on a result state")
    func successProducesResult() async {
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { _ in SanitizedAIImage(base64: "QQ==", mimeType: "image/jpeg", byteCount: 1) },
            requestAssist: { _, _ in photoAssistSuggestionsResult() }
        )
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)
        viewModel.requestAssist(imageData: Data([0x1]), note: "")
        await viewModel.drainForTesting()
        #expect(viewModel.state == .result(photoAssistSuggestionsResult()))
    }

    @Test("image-input-not-enabled surfaces a guidance failure, not a hard error")
    func imageInputNotEnabledSurfacesGuidance() async {
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { _ in SanitizedAIImage(base64: "QQ==", mimeType: "image/jpeg", byteCount: 1) },
            requestAssist: { _, _ in throw PhotoWritingAssistRequestFailure(category: .imageInputNotEnabled) }
        )
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)
        viewModel.requestAssist(imageData: Data([0x1]), note: "")
        await viewModel.drainForTesting()
        #expect(viewModel.state == .failed(.imageInputNotEnabled))
        #expect(viewModel.isImageInputGuidance)
    }

    @Test("the second trigger supersedes the first; the stale task cannot clobber state")
    func secondTriggerSupersedesFirst() async {
        let gate = Gate()
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { _ in SanitizedAIImage(base64: "QQ==", mimeType: "image/jpeg", byteCount: 1) },
            requestAssist: { input, _ in
                if input.mode == .writingSuggestions {
                    // First call: block until cancelled.
                    await gate.waitUntilCancelledForever()
                    return photoAssistSuggestionsResult()
                }
                return photoAssistDraftResult()
            }
        )
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)

        viewModel.selectedMode = .writingSuggestions
        viewModel.requestAssist(imageData: Data([0x1]), note: "")
        // Supersede with a draft-mode request that returns immediately.
        viewModel.selectedMode = .sourceLanguageDraft
        viewModel.requestAssist(imageData: Data([0x1]), note: "")
        await viewModel.drainForTesting()

        #expect(viewModel.state == .result(photoAssistDraftResult()))
    }

    @Test("cancel returns to idle and never sets a result")
    func cancelReturnsToIdle() async {
        let gate = Gate()
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { _ in SanitizedAIImage(base64: "QQ==", mimeType: "image/jpeg", byteCount: 1) },
            requestAssist: { _, _ in
                await gate.waitUntilCancelledForever()
                return photoAssistSuggestionsResult()
            }
        )
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)
        viewModel.requestAssist(imageData: Data([0x1]), note: "")
        #expect(viewModel.state == .sending)
        viewModel.cancel()
        await viewModel.drainForTesting()
        #expect(viewModel.state == .idle)
    }

    @Test("only the native-language draft is adoptable; suggestions are read-only")
    func adoptableTextOnlyForDraft() async {
        let actions = PhotoWritingActions(
            importPhoto: { _, _, _ in },
            sanitizeImage: { _ in SanitizedAIImage(base64: "QQ==", mimeType: "image/jpeg", byteCount: 1) },
            requestAssist: { input, _ in
                input.mode == .sourceLanguageDraft ? photoAssistDraftResult() : photoAssistSuggestionsResult()
            }
        )
        let suggestionsVM = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)
        suggestionsVM.selectedMode = .writingSuggestions
        suggestionsVM.requestAssist(imageData: Data([0x1]), note: "")
        await suggestionsVM.drainForTesting()
        #expect(suggestionsVM.adoptableText == nil)

        let draftVM = PhotoWritingAssistViewModel(languageSpace: space(), actions: actions)
        draftVM.selectedMode = .sourceLanguageDraft
        draftVM.requestAssist(imageData: Data([0x1]), note: "")
        await draftVM.drainForTesting()
        #expect(draftVM.adoptableText == "今天我看到一只猫。")
    }

    @Test("input carries the language space codes and the lowercased level")
    func inputCarriesLanguageCodes() {
        let viewModel = PhotoWritingAssistViewModel(languageSpace: space(), actions: .disabled)
        viewModel.selectedMode = .sourceLanguageDraft
        let input = viewModel.makeInput(note: "hi")
        #expect(input.mode == .sourceLanguageDraft)
        #expect(input.nativeLanguageCode == "zh-Hans")
        #expect(input.targetLanguageCode == "en")
        #expect(input.proficiencyLevelCode == "b1")
        #expect(input.userNote == "hi")
    }
}

private actor AssistRecorder {
    private(set) var sanitizeInput: Data?
    private(set) var sentImage: SanitizedAIImage?

    func recordSanitizeInput(_ data: Data) {
        sanitizeInput = data
    }

    func recordSentImage(_ image: SanitizedAIImage) {
        sentImage = image
    }
}

private actor Gate {
    func waitUntilCancelledForever() async {
        // Suspend on a long sleep that throws when the task is cancelled; the
        // model's cancellation path then resolves. Swallow the error so the
        // closure signature stays non-throwing.
        try? await Task.sleep(nanoseconds: 60_000_000_000)
    }
}
