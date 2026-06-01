import Foundation
import LangoTraceCore

public enum ReadingAsyncState: Equatable, Sendable {
    case idle
    case loading
    case failed
}

public final class ReadingDocumentStore: @unchecked Sendable {
    public private(set) var documentID: String
    public private(set) var spaceID: String
    public private(set) var selectedText: String?
    public private(set) var selectedSentenceID: String?
    public private(set) var containingSentence: String = ""
    public private(set) var explanationState: ReadingAsyncState = .idle
    public private(set) var explanationResult: ReadingSelectionExplanationResult?
    public private(set) var audioState: ReadingAsyncState = .idle

    private let explanationAction: ReadingExplanationAction
    private let ttsAction: ReadingTTSAction
    private let nativeLanguageCode: String
    private let targetLanguageCode: String
    private let proficiencyLevelCode: String
    private var generation = 0

    public init(
        documentID: String,
        spaceID: String,
        nativeLanguageCode: String = "",
        targetLanguageCode: String = "",
        proficiencyLevelCode: String = "",
        explanationAction: @escaping ReadingExplanationAction,
        ttsAction: @escaping ReadingTTSAction
    ) {
        self.documentID = documentID
        self.spaceID = spaceID
        self.nativeLanguageCode = nativeLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.explanationAction = explanationAction
        self.ttsAction = ttsAction
    }

    public func selectText(_ text: String, sentenceID: String?, containingSentence: String = "") {
        selectedText = text
        selectedSentenceID = sentenceID
        self.containingSentence = containingSentence
        explanationResult = nil
        explanationState = .idle
        invalidateInFlightWork()
    }

    public func replaceDocument(documentID: String, spaceID: String) {
        self.documentID = documentID
        self.spaceID = spaceID
        selectedText = nil
        selectedSentenceID = nil
        containingSentence = ""
        explanationResult = nil
        explanationState = .idle
        audioState = .idle
        invalidateInFlightWork()
    }

    public func explainSelection() async {
        guard explanationState != .loading, let selectedText else {
            return
        }
        explanationState = .loading
        let token = nextToken()
        let request = ReadingExplanationRequest(
            documentID: documentID,
            spaceID: spaceID,
            selectedText: selectedText,
            sentenceID: selectedSentenceID,
            containingSentence: containingSentence,
            contextText: containingSentence,
            nativeLanguageCode: nativeLanguageCode,
            targetLanguageCode: targetLanguageCode,
            proficiencyLevelCode: proficiencyLevelCode
        )
        Task { [weak self] in
            do {
                let result = try await self?.explanationAction(request)
                guard let result else { return }
                self?.completeExplanation(result, token: token, request: request)
            } catch {
                self?.failExplanation(token: token, request: request)
            }
        }
        await Task.yield()
    }

    public func playSentence(sentenceID: String, text: String) async {
        guard audioState != .loading else {
            return
        }
        audioState = .loading
        let token = nextToken()
        let request = ReadingTTSRequest(
            documentID: documentID,
            spaceID: spaceID,
            sentenceID: sentenceID,
            text: text,
            targetLanguageCode: targetLanguageCode
        )
        Task { [weak self] in
            await self?.ttsAction(request)
            self?.completeTTS(token: token, request: request)
        }
        await Task.yield()
    }

    private func nextToken() -> Int {
        generation += 1
        return generation
    }

    private func invalidateInFlightWork() {
        generation += 1
    }

    private func isCurrent(token: Int, documentID: String, spaceID: String) -> Bool {
        token == generation && self.documentID == documentID && self.spaceID == spaceID
    }

    private func completeExplanation(
        _ result: ReadingSelectionExplanationResult,
        token: Int,
        request: ReadingExplanationRequest
    ) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID),
              selectedText == request.selectedText,
              selectedSentenceID == request.sentenceID
        else {
            if explanationState == .loading {
                explanationState = .idle
            }
            return
        }
        explanationResult = result
        explanationState = .idle
    }

    private func failExplanation(token: Int, request: ReadingExplanationRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            explanationState = .idle
            return
        }
        explanationState = .failed
    }

    private func completeTTS(token: Int, request: ReadingTTSRequest) {
        guard isCurrent(token: token, documentID: request.documentID, spaceID: request.spaceID) else {
            audioState = .idle
            return
        }
        audioState = .idle
    }
}
