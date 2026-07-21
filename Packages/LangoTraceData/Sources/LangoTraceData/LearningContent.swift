import Foundation
import LangoTraceCore

/// A repository for learning content entries and their associated materials.
///
/// Conforming types are expected to be used from the main actor context.
/// The primary consumer (`LearningContentStore`) is `@MainActor`, and all
/// protocol methods are synchronous. Full `@MainActor` protocol isolation
/// is deferred to E0b (UI architecture debt) to avoid cascading async
/// changes across all implementations and test sites.
public protocol LearningContentRepository: AnyObject {
    func ensureSeeded(spaceID: String)
    func entries(for spaceID: String) -> [LearningEntry]
    func selectedEntry(for spaceID: String) -> LearningEntry?
    func selectEntry(id: String, spaceID: String)
    @discardableResult
    func createEntry(spaceID: String, title: String, body: String, source: EntrySource, scene: String) throws -> LearningEntry
    func deleteEntry(id: String) throws
    @discardableResult
    func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry
    @discardableResult
    func updateEntryScene(entryID: String, spaceID: String, scene: String) throws -> LearningEntry
    @discardableResult
    func generateLocalPreview(for entryID: String, spaceID: String) -> LearningRendering?
    func rendering(for entryID: String) -> LearningRendering?
    func practiceItems(for entryID: String) -> [PracticeItem]
    func memoryItems(for spaceID: String) -> [MemoryItem]
    func settingsCapabilities(for spaceID: String) -> [SettingsCapability]
    func practiceSession(for entryID: String) -> PracticeSessionState?
    func saveRendering(_ rendering: LearningRendering)
    /// Returns a dictionary from entryID to hasCompletedRecording for all entries
    /// that have a current learning material in the given space.
    /// Entries without any learning material are absent from the result.
    func learningPracticeReadiness(for spaceID: String) -> [String: Bool]
    /// Returns the rich per-sentence analysis for a material sentence by its
    /// position, or `nil` if absent. The backtranslation reference card (E5)
    /// reads this lazily on reveal; the lossy `RenderingSentence` projection
    /// cannot carry `naturalTranslation` / `literalTranslation` / `keyPoints`.
    /// Fully local, read-only.
    func sentenceAnalysis(materialID: String, sentenceIndex: Int) -> LearningSentenceAnalysis?
}

public final class InMemoryLearningContentRepository: LearningContentRepository {
    private var entriesBySpace: [String: [LearningEntry]]
    private var selectedEntryIDs: [String: String]
    private var renderingsByEntryID: [String: LearningRendering]
    private var practiceItemsByEntryID: [String: [PracticeItem]]
    private var memoryItemsBySpace: [String: [MemoryItem]]
    private var nextEntryNumber: Int

    public init(
        seedEntries: [LearningEntry],
        renderings: [LearningRendering] = [],
        practiceItems: [PracticeItem] = [],
        memoryItems: [MemoryItem] = []
    ) {
        entriesBySpace = Dictionary(grouping: seedEntries, by: \.spaceID)
        selectedEntryIDs = entriesBySpace.compactMapValues { $0.first?.id }
        renderingsByEntryID = Dictionary(uniqueKeysWithValues: renderings.map { ($0.entryID, $0) })
        practiceItemsByEntryID = Dictionary(grouping: practiceItems, by: \.entryID)
        memoryItemsBySpace = Dictionary(grouping: memoryItems, by: \.spaceID)
        nextEntryNumber = seedEntries.count + 1
    }

    public static func seeded(spaceID: String) -> InMemoryLearningContentRepository {
        let entries = SeedLearningContent.entries(spaceID: spaceID)
        return InMemoryLearningContentRepository(
            seedEntries: entries,
            renderings: SeedLearningContent.renderings,
            practiceItems: SeedLearningContent.practiceItems,
            memoryItems: SeedLearningContent.memoryItems(spaceID: spaceID)
        )
    }

    public func ensureSeeded(spaceID: String) {
        guard entriesBySpace[spaceID, default: []].isEmpty else {
            return
        }

        let seeded = Self.seeded(spaceID: spaceID)
        entriesBySpace[spaceID] = seeded.entries(for: spaceID)
        selectedEntryIDs[spaceID] = seeded.selectedEntry(for: spaceID)?.id
        seeded.renderingsByEntryID.forEach { renderingsByEntryID[$0.key] = $0.value }
        seeded.practiceItemsByEntryID.forEach { practiceItemsByEntryID[$0.key] = $0.value }
        memoryItemsBySpace[spaceID] = seeded.memoryItems(for: spaceID)
    }

    public func entries(for spaceID: String) -> [LearningEntry] {
        entriesBySpace[spaceID, default: []]
    }

    public func selectedEntry(for spaceID: String) -> LearningEntry? {
        guard let selectedID = selectedEntryIDs[spaceID] else {
            return entries(for: spaceID).first
        }

        return entries(for: spaceID).first { $0.id == selectedID }
    }

    public func selectEntry(id: String, spaceID: String) {
        guard entries(for: spaceID).contains(where: { $0.id == id }) else {
            return
        }

        selectedEntryIDs[spaceID] = id
    }

    @discardableResult
    public func createEntry(
        spaceID: String,
        title: String,
        body: String,
        source: EntrySource,
        scene: String
    ) throws -> LearningEntry {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScene = scene.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryID = "entry-\(nextEntryNumber)-\(spaceID)"
        nextEntryNumber += 1

        let entry = LearningEntry(
            id: entryID,
            spaceID: spaceID,
            title: trimmedTitle,
            body: trimmedBody,
            source: source,
            scene: trimmedScene,
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_800_000_000 + nextEntryNumber)),
            practiceStatus: .practiced(sessionCount: 1)
        )

        entriesBySpace[spaceID, default: []].insert(entry, at: 0)
        selectedEntryIDs[spaceID] = entry.id
        return entry
    }

    public func deleteEntry(id: String) throws {
        for (spaceID, entries) in entriesBySpace {
            guard let index = entries.firstIndex(where: { $0.id == id }) else {
                continue
            }
            entriesBySpace[spaceID]?.remove(at: index)
            if selectedEntryIDs[spaceID] == id {
                selectedEntryIDs[spaceID] = entriesBySpace[spaceID]?.first?.id
            }
            renderingsByEntryID[id] = nil
            practiceItemsByEntryID[id] = nil
            return
        }
        throw LearningContentRepositoryError.entryNotFound
    }

    @discardableResult
    public func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw LearningContentRepositoryError.emptyEntryBody }
        guard var entries = entriesBySpace[spaceID],
              let index = entries.firstIndex(where: { $0.id == entryID })
        else {
            throw LearningContentRepositoryError.entryNotFound
        }

        entries[index].body = trimmedBody
        entriesBySpace[spaceID] = entries
        return entries[index]
    }

    @discardableResult
    public func updateEntryScene(entryID: String, spaceID: String, scene: String) throws -> LearningEntry {
        let trimmedScene = scene.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var entries = entriesBySpace[spaceID],
              let index = entries.firstIndex(where: { $0.id == entryID })
        else {
            throw LearningContentRepositoryError.entryNotFound
        }

        entries[index].scene = trimmedScene
        entriesBySpace[spaceID] = entries
        return entries[index]
    }

    @discardableResult
    public func generateLocalPreview(for entryID: String, spaceID: String) -> LearningRendering? {
        guard let entry = entries(for: spaceID).first(where: { $0.id == entryID }) else {
            return nil
        }

        if let existingRendering = renderingsByEntryID[entry.id] {
            return existingRendering
        }

        let rendering = Self.makeMockRendering(for: entry)
        renderingsByEntryID[entry.id] = rendering
        practiceItemsByEntryID[entry.id] = [
            PracticeItem(
                id: "\(entry.id)-practice-shadowing",
                entryID: entry.id,
                title: "跟读",
                kind: .shadowing,
                summary: "选择 1 句开始跟读"
            ),
        ]
        memoryItemsBySpace[spaceID, default: []].insert(
            MemoryItem(
                id: "\(entry.id)-memory",
                spaceID: spaceID,
                entryID: entry.id,
                text: "everyday expression",
                note: "Extracted from a life record entry."
            ),
            at: 0
        )

        return rendering
    }

    public func rendering(for entryID: String) -> LearningRendering? {
        renderingsByEntryID[entryID]
    }

    public func saveRendering(_ rendering: LearningRendering) {
        renderingsByEntryID[rendering.entryID] = rendering
    }

    public func practiceItems(for entryID: String) -> [PracticeItem] {
        practiceItemsByEntryID[entryID, default: []]
    }

    public func memoryItems(for spaceID: String) -> [MemoryItem] {
        memoryItemsBySpace[spaceID, default: []]
    }

    /// In-memory fixture statuses: kinds without a real backend behind this
    /// mock repository stay `.mockOnly`. Metadata and ordering come from
    /// `SettingsCapabilityCatalog`.
    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        SettingsCapabilityCatalog.capabilities(statuses: [
            .companion: .ready,
            .languageSpace: .mockOnly,
            .interfaceLanguage: .mockOnly,
            .appearance: .ready,
            .aiProvider: .mockOnly,
            .sync: .unavailable,
            .localData: .mockOnly,
            .privacy: .ready,
            .importExport: .unavailable,
        ])
    }

    public func practiceSession(for entryID: String) -> PracticeSessionState? {
        guard let rendering = rendering(for: entryID) else {
            return nil
        }

        return PracticeSessionState(
            entryID: entryID,
            providerLabel: rendering.providerLabel,
            isExternalRequestRequired: false,
            steps: PracticeSessionStep.allCases,
            targetText: rendering.targetText
        )
    }

    public func learningPracticeReadiness(for spaceID: String) -> [String: Bool] {
        let entries = entriesBySpace[spaceID, default: []]
        var result: [String: Bool] = [:]
        for entry in entries {
            guard renderingsByEntryID[entry.id] != nil else { continue }
            result[entry.id] = false
        }
        return result
    }

    /// Maps a stored rendering sentence (keyed by rendering id == materialID,
    /// position == sentenceIndex) to a `LearningSentenceAnalysis`. The mock
    /// rendering only carries `targetText` / `translation` / `note`, so the
    /// richer fields degrade gracefully (empty / single note).
    public func sentenceAnalysis(materialID: String, sentenceIndex: Int) -> LearningSentenceAnalysis? {
        guard let rendering = renderingsByEntryID.values.first(where: { $0.id == materialID }),
              rendering.sentences.indices.contains(sentenceIndex)
        else {
            return nil
        }
        let sentence = rendering.sentences[sentenceIndex]
        return LearningSentenceAnalysis(
            id: sentence.id,
            nativeSentence: sentence.translation,
            targetSentence: sentence.targetText,
            literalTranslation: "",
            naturalTranslation: sentence.targetText,
            grammarNotes: sentence.note.isEmpty ? [] : [sentence.note],
            keyPoints: [],
            position: sentenceIndex
        )
    }

    private static func makeMockRendering(for entry: LearningEntry) -> LearningRendering {
        let targetText = "I wrote down a small moment from my day, and I can turn it into language practice."
        return LearningRendering(
            id: "\(entry.id)-rendering",
            entryID: entry.id,
            targetText: targetText,
            promptLabel: "自然表达",
            providerLabel: "LangoTrace Draft",
            isMock: true,
            sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: entry.body),
            sentences: [
                RenderingSentence(
                    id: "\(entry.id)-sentence-1",
                    translation: entry.body.isEmpty ? "" : entry.body,
                    targetText: targetText,
                    note: "适合改写成自然目标语言表达。"
                ),
            ]
        )
    }
}

public final class UnavailableLearningContentRepository: LearningContentRepository {
    public init() {}

    public func ensureSeeded(spaceID _: String) {}

    public func entries(for _: String) -> [LearningEntry] {
        []
    }

    public func selectedEntry(for _: String) -> LearningEntry? {
        nil
    }

    public func selectEntry(id _: String, spaceID _: String) {}

    public func createEntry(spaceID _: String, title _: String, body _: String, source _: EntrySource, scene _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func deleteEntry(id _: String) throws {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func updateEntryBody(entryID _: String, spaceID _: String, body _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func updateEntryScene(entryID _: String, spaceID _: String, scene _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    public func generateLocalPreview(for _: String, spaceID _: String) -> LearningRendering? {
        nil
    }

    public func rendering(for _: String) -> LearningRendering? {
        nil
    }

    public func saveRendering(_: LearningRendering) {}

    public func practiceItems(for _: String) -> [PracticeItem] {
        []
    }

    public func memoryItems(for _: String) -> [MemoryItem] {
        []
    }

    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        []
    }

    public func practiceSession(for _: String) -> PracticeSessionState? {
        nil
    }

    public func learningPracticeReadiness(for _: String) -> [String: Bool] {
        [:]
    }

    public func sentenceAnalysis(materialID _: String, sentenceIndex _: Int) -> LearningSentenceAnalysis? {
        nil
    }
}
