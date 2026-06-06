import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading document store explanation cache")
struct ReadingDocumentStoreExplanationCacheTests {
    // MARK: - Cache hit: result delivered without calling explanationAction

    @Test("cache hit delivers result without AI request")
    func cacheHitDeliversResultWithoutAIRequest() async throws {
        let mockRepo = MockReadingExplanationCacheRepository()
        let counter = CallCounter()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in
                await counter.increment()
                return .sample(selection: "test")
            },
            ttsAction: { _ in },
            cacheRepository: mockRepo
        )

        // Seed a selection and manually populate the in-memory cache by completing an explain.
        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "ticket",
            sentenceID: "s1",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)
        store.explainSelection()
        // Wait for the AI task to finish and cache to be populated
        while store.explanationState == .loading {
            await Task.yield()
        }
        #expect(store.explanationResult != nil)
        #expect(store.explanationSource == .fresh)
        let firstAICallCount = await counter.count

        // Reset result/source/state but keep in-memory cache, then re-select same selection
        store.selectedSelection = selection
        store.explanationResult = nil
        store.explanationSource = nil
        store.explanationState = .idle

        // Second explain should hit in-memory cache
        store.explainSelection()
        await Task.yield()

        #expect(store.explanationResult != nil)
        #expect(store.explanationSource == .cache)
        #expect(store.explanationState == .idle)
        // No new AI call was made
        let secondAICallCount = await counter.count
        #expect(secondAICallCount == firstAICallCount)
    }

    // MARK: - Cache miss: calls explanationAction and populates cache

    @Test("cache miss calls explanationAction and populates cache")
    func cacheMissCallsExplanationActionAndPopulatesCache() async throws {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheRepository: mockRepo
        )

        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "clocktower",
            sentenceID: "s1",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)
        store.explainSelection()

        #expect(store.explanationState == .loading)
        #expect(store.explanationSource == nil)

        await controlled.complete(.success(.sample(selection: "clocktower")))
        while store.explanationState == .loading {
            await Task.yield()
        }

        #expect(store.explanationResult != nil)
        #expect(store.explanationSource == .fresh)
        #expect(store.explanationState == .idle)

        // Cache should now have an entry
        let cacheKey = "\(selection.sourceAnchorID):bilingualBridge"
        #expect(store.explanationCache[cacheKey] != nil)

        // Repository insert should have been called
        let insertCount = await mockRepo.insertCount
        #expect(insertCount == 1)
    }

    // MARK: - explainedSentenceIDs updated after successful explain

    @Test("explainedSentenceIDs updated after successful explain")
    func explainedSentenceIDsUpdatedAfterExplain() async {
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in }
        )

        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "mystery",
            sentenceID: "sentence-42",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)
        store.explainSelection()
        await controlled.complete(.success(.sample(selection: "mystery")))
        while store.explanationState == .loading {
            await Task.yield()
        }

        #expect(store.explainedSentenceIDs.contains("sentence-42"))
    }

    // MARK: - regenerateExplanation fires new AI request

    @Test("regenerateExplanation fires new AI request")
    func regenerateExplanationFiresNewAIRequest() async throws {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheRepository: mockRepo
        )

        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "library",
            sentenceID: "s1",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)
        // First explain — populates cache
        store.explainSelection()
        await controlled.complete(.success(.sample(selection: "library")))
        while store.explanationState == .loading {
            await Task.yield()
        }
        #expect(store.explanationSource == .fresh)

        let requestCountBefore = await controlled.requestCount()

        // Regenerate — should clear cache and fire a new AI request
        store.regenerateExplanation()
        #expect(store.explanationResult == nil)
        #expect(store.explanationSource == nil)
        #expect(store.explanationState == .loading)

        await controlled.complete(.success(.sample(selection: "library")))
        while store.explanationState == .loading {
            await Task.yield()
        }

        let requestCountAfter = await controlled.requestCount()
        #expect(requestCountAfter == requestCountBefore + 1)
        #expect(store.explanationSource == .fresh)

        // Repository delete should have been called once
        let deleteCount = await mockRepo.deleteCount
        #expect(deleteCount == 1)
    }

    // MARK: - explanationSource reflects cache vs fresh

    @Test("explanationSource reflects cache vs fresh")
    func explanationSourceReflectsOrigin() async throws {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheRepository: mockRepo
        )

        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "station",
            sentenceID: "s1",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)

        // Fresh request
        store.explainSelection()
        #expect(store.explanationSource == nil)
        await controlled.complete(.success(.sample(selection: "station")))
        while store.explanationState == .loading {
            await Task.yield()
        }
        #expect(store.explanationSource == .fresh)

        // Reset result but keep selection and cache
        store.explanationResult = nil
        store.explanationSource = nil
        store.explanationState = .idle

        // Cache hit
        store.explainSelection()
        await Task.yield()
        #expect(store.explanationSource == .cache)
    }

    // MARK: - clearSelection resets explanationSource

    @Test("clearSelection resets explanationSource")
    func clearSelectionResetsSource() async {
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in }
        )

        let selection = ReadingSelectionContext.cacheTestSample(
            selectedText: "word",
            sentenceID: "s1",
            documentID: "doc-1",
            contentRevision: 1
        )
        store.selectSelection(selection)
        store.explanationSource = .cache

        store.clearSelection()

        #expect(store.explanationSource == nil)
    }
}

// MARK: - Test helpers

private extension ReadingSelectionContext {
    static func cacheTestSample(
        selectedText: String,
        sentenceID: String,
        documentID: String,
        contentRevision: Int
    ) -> ReadingSelectionContext {
        let hash = ReadingTextSegmenter.sha256Hex(selectedText)
        let anchorID = ReadingTextSegmenter.sourceAnchorID(
            documentID: documentID,
            contentRevision: contentRevision,
            structureVersion: 0,
            blockID: sentenceID,
            sentenceID: sentenceID,
            selectedTextHash: hash,
            characterOffset: 0,
            characterLength: selectedText.count
        )
        return ReadingSelectionContext(
            sourceAnchorID: anchorID,
            blockID: sentenceID,
            sentenceID: sentenceID,
            selectionScope: .sentence,
            selectedText: selectedText,
            selectedTextHash: hash,
            characterOffset: 0,
            characterLength: selectedText.count,
            containingSentence: selectedText,
            previousSentence: nil,
            nextSentence: nil,
            containingParagraph: selectedText,
            contextMode: .currentParagraph,
            contextText: selectedText
        )
    }
}

private extension ReadingSelectionExplanationResult {
    static func sample(selection: String) -> ReadingSelectionExplanationResult {
        ReadingSelectionExplanationResult(
            schemaVersion: "reading_selection_explanation.v3",
            selection: selection,
            shortExplanation: "Explanation for \(selection)",
            meaningInNativeLanguage: "释义",
            usageNote: "Usage note.",
            exampleSentence: "Example sentence.",
            grammaticalNote: "Noun."
        )
    }
}

private actor ControlledCacheExplanationAction {
    private(set) var requests: [ReadingExplanationRequest] = []
    private var continuation: CheckedContinuation<ReadingSelectionExplanationResult, Error>?

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }

    func complete(_ result: Result<ReadingSelectionExplanationResult, Error>) {
        guard let cont = continuation else { return }
        self.continuation = nil
        cont.resume(with: result)
    }

    func requestCount() -> Int {
        requests.count
    }
}

private actor CallCounter {
    private(set) var count: Int = 0

    func increment() {
        count += 1
    }
}

private actor MockReadingExplanationCacheRepository: ReadingExplanationCacheRepositoryProtocol {
    private(set) var insertCount: Int = 0
    private(set) var deleteCount: Int = 0
    private var entries: [String: ReadingExplanationCacheEntry] = [:]

    func insert(_ entry: ReadingExplanationCacheEntry) async throws {
        insertCount += 1
        entries[entry.id] = entry
    }

    func lookup(
        documentID: String,
        sourceAnchorID: String,
        mode: ExplanationLanguageMode
    ) async throws -> ReadingExplanationCacheEntry? {
        entries.values.first {
            $0.documentID == documentID &&
                $0.sourceAnchorID == sourceAnchorID &&
                $0.explanationLanguageMode == mode
        }
    }

    func lookupBySentenceID(
        documentID: String,
        contentRevision: Int,
        sentenceID: String
    ) async throws -> ReadingExplanationCacheEntry? {
        entries.values.first {
            $0.documentID == documentID &&
                $0.contentRevision == contentRevision &&
                $0.sentenceID == sentenceID
        }
    }

    func loadExplainedSentenceIDs(
        documentID: String,
        contentRevision: Int
    ) async throws -> Set<String> {
        Set(entries.values
            .filter { $0.documentID == documentID && $0.contentRevision == contentRevision }
            .map(\.sentenceID))
    }

    func delete(id: String) async throws {
        deleteCount += 1
        entries.removeValue(forKey: id)
    }

    func pruneStale(documentID: String, currentContentRevision: Int) async throws {
        entries = entries.filter {
            $0.value.documentID != documentID ||
                $0.value.contentRevision == currentContentRevision
        }
    }
}
