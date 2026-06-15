import LangoTraceCore
@testable import LangoTraceUI
import Testing

@MainActor
@Suite("Reading document store explanation cache")
struct ReadingDocumentStoreExplanationCacheTests {
    // MARK: - Cache hit: result delivered without calling explanationAction

    @Test("cache hit delivers result without AI request")
    func cacheHitDeliversResultWithoutAIRequest() async {
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
            cacheStorage: mockRepo
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
    func cacheMissCallsExplanationActionAndPopulatesCache() async {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheStorage: mockRepo
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

        // Repository insert is dispatched as a fire-and-forget Task in
        // ReadingDocumentStore (`Task { try? await repo?.insert(...) }`) and is
        // not awaited before explanationState flips to .idle, so poll until it
        // lands instead of reading once and racing the detached task.
        var insertCount = await mockRepo.insertCount
        var insertSpins = 0
        while insertCount == 0, insertSpins < 1000 {
            await Task.yield()
            insertCount = await mockRepo.insertCount
            insertSpins += 1
        }
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
    func regenerateExplanationFiresNewAIRequest() async {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheStorage: mockRepo
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

        // Repository delete is dispatched as a fire-and-forget Task in
        // ReadingDocumentStore (`Task { try? await repo?.delete(...) }`), so poll
        // until it lands instead of reading once and racing the detached task.
        var deleteCount = await mockRepo.deleteCount
        var deleteSpins = 0
        while deleteCount == 0, deleteSpins < 1000 {
            await Task.yield()
            deleteCount = await mockRepo.deleteCount
            deleteSpins += 1
        }
        #expect(deleteCount == 1)
    }

    // MARK: - explanationSource reflects cache vs fresh

    @Test("explanationSource reflects cache vs fresh")
    func explanationSourceReflectsOrigin() async {
        let mockRepo = MockReadingExplanationCacheRepository()
        let controlled = ControlledCacheExplanationAction()
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: controlled.explain,
            ttsAction: { _ in },
            cacheStorage: mockRepo
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

    // MARK: - Document switch mid cache load discards stale backfill

    @Test("document switch mid cache load discards stale explained sentence backfill")
    func documentSwitchMidCacheLoadDiscardsStaleBackfill() async {
        let repo = GatedReadingExplanationCacheRepository(
            explainedSentenceIDsByDocumentID: [
                "doc-2": ["stale-sentence"],
                "doc-3": [],
            ]
        )
        let store = ReadingDocumentStore(
            documentID: "doc-1",
            spaceID: "space-1",
            explanationAction: { _ in .sample(selection: "word") },
            ttsAction: { _ in },
            cacheStorage: repo
        )

        store.replaceDocument(documentID: "doc-2", spaceID: "space-1")
        await repo.waitForLoadCount(1)
        store.replaceDocument(documentID: "doc-3", spaceID: "space-1")
        await repo.waitForLoadCount(2)

        await repo.releaseLoad(documentID: "doc-2")
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(!store.explainedSentenceIDs.contains("stale-sentence"))

        await repo.releaseLoad(documentID: "doc-3")
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(store.documentID == "doc-3")
        #expect(store.explainedSentenceIDs.isEmpty)
    }

    // MARK: - clearSelection resets explanationSource

    @Test("clearSelection resets explanationSource")
    func clearSelectionResetsSource() {
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
        let hash = StableHashing.sha256Hex(selectedText)
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
    private var pendingResult: Result<ReadingSelectionExplanationResult, Error>?

    func explain(_ request: ReadingExplanationRequest) async throws -> ReadingSelectionExplanationResult {
        requests.append(request)
        // Race-safe: if complete() already arrived (store launches explain on a
        // detached task, so the test may complete before this registers), return
        // the buffered result instead of suspending forever.
        if let pendingResult {
            self.pendingResult = nil
            return try pendingResult.get()
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }

    func complete(_ result: Result<ReadingSelectionExplanationResult, Error>) {
        if let cont = continuation {
            continuation = nil
            cont.resume(with: result)
        } else {
            pendingResult = result
        }
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

private actor GatedReadingExplanationCacheRepository: ReadingExplanationCacheRepositoryProtocol {
    private let explainedSentenceIDsByDocumentID: [String: Set<String>]
    private var pendingLoads: [(documentID: String, continuation: CheckedContinuation<Void, Never>)] = []
    private var loadCount = 0

    init(explainedSentenceIDsByDocumentID: [String: Set<String>]) {
        self.explainedSentenceIDsByDocumentID = explainedSentenceIDsByDocumentID
    }

    func insert(_: ReadingExplanationCacheEntry) async throws {}

    func lookup(
        documentID _: String,
        sourceAnchorID _: String,
        mode _: ExplanationLanguageMode
    ) async throws -> ReadingExplanationCacheEntry? {
        nil
    }

    func lookupBySentenceID(
        documentID _: String,
        contentRevision _: Int,
        sentenceID _: String
    ) async throws -> ReadingExplanationCacheEntry? {
        nil
    }

    func loadExplainedSentenceIDs(
        documentID: String,
        contentRevision _: Int
    ) async throws -> Set<String> {
        loadCount += 1
        await withCheckedContinuation { continuation in
            pendingLoads.append((documentID: documentID, continuation: continuation))
        }
        return explainedSentenceIDsByDocumentID[documentID] ?? []
    }

    func delete(id _: String) async throws {}

    func pruneStale(documentID _: String, currentContentRevision _: Int) async throws {}

    func releaseLoad(documentID: String) {
        guard let index = pendingLoads.firstIndex(where: { $0.documentID == documentID }) else { return }
        let pending = pendingLoads.remove(at: index)
        pending.continuation.resume()
    }

    func waitForLoadCount(_ count: Int) async {
        while loadCount < count {
            await Task.yield()
        }
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
