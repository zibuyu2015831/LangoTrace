import Foundation
import LangoTraceCore

extension ReadingDocumentStore {
    // Called on document open / replace
    @MainActor
    func loadCacheForDocument() async {
        guard let repo = cacheStorage else { return }
        let docID = documentID
        let rev = contentRevision
        do {
            try await repo.pruneStale(documentID: docID, currentContentRevision: rev)
            let ids = try await repo.loadExplainedSentenceIDs(
                documentID: docID,
                contentRevision: rev
            )
            explainedSentenceIDs = ids
            explanationCache = [:]
        } catch {
            // cache load failure is non-blocking
        }
    }

    /// Returns the sentenceID when the current fragment selection's containing sentence has
    /// a prior explanation but the exact sourceAnchorID is not in memory cache.
    public var overlappingExplainedSentenceID: String? {
        guard let selection = selectedSelection,
              selection.selectionScope == .textFragment,
              explainedSentenceIDs.contains(selection.sentenceID) else { return nil }
        let cacheKey = "\(selection.sourceAnchorID):\(currentExplanationMode.rawValue)"
        guard explanationCache[cacheKey] == nil else { return nil }
        return selection.sentenceID
    }

    /// Fetch the cached entry for the overlapping sentence and display it.
    public func showOverlappingExplainedSentenceResult() {
        guard let sentenceID = overlappingExplainedSentenceID else { return }
        let repo = cacheStorage
        let docID = documentID
        let rev = contentRevision
        Task { @MainActor in
            guard let entry = try? await repo?.lookupBySentenceID(
                documentID: docID,
                contentRevision: rev,
                sentenceID: sentenceID
            ) else { return }
            explanationResult = entry.result
            explanationSource = .cache
            explanationState = .idle
            let key = "\(entry.sourceAnchorID):\(entry.explanationLanguageMode.rawValue)"
            explanationCache[key] = entry
        }
    }

    /// Delete the current explanation from cache and fire a fresh AI request.
    public func regenerateExplanation() {
        guard let selection = selectedSelection ?? fallbackSelection else { return }
        let cacheKey = "\(selection.sourceAnchorID):\(currentExplanationMode.rawValue)"

        if let existing = explanationCache[cacheKey] {
            explanationCache.removeValue(forKey: cacheKey)
            let repo = cacheStorage
            Task { try? await repo?.delete(id: existing.id) }
        }

        explanationResult = nil
        explanationSource = nil

        explainSelection()
    }
}
