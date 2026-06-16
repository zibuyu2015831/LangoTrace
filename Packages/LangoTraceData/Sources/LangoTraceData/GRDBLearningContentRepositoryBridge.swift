import Foundation
import LangoTraceCore

/// Internal protocol abstracting the GRDB repository read operations
/// that the bridge wraps. Enables test injection of failing implementations.
protocol GRDBLearningContentRepositoryProtocol: Sendable {
    func entries(for spaceID: String) throws -> [LearningEntry]
    func practiceItems(for entryID: String) throws -> [PracticeItem]
    func memoryItems(for spaceID: String) throws -> [MemoryItem]
    func currentMaterial(for entryID: String) throws -> LearningMaterial?
    func createEntry(_ draft: NewLearningEntryDraft, in spaceID: String) throws -> LearningEntry
    func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry
    func learningPracticeReadiness(for spaceID: String) throws -> [String: Bool]
}

extension GRDBLearningContentRepository: GRDBLearningContentRepositoryProtocol {}

public final class GRDBLearningContentRepositoryBridge: LearningContentRepository {
    private let repository: any GRDBLearningContentRepositoryProtocol
    private let diagnosticLogger: any DiagnosticLogging
    private let clock: @Sendable () -> Date
    private var selectedEntryIDs: [String: String] = [:]

    public init(
        repository: GRDBLearningContentRepository,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
    }

    init(
        repository: any GRDBLearningContentRepositoryProtocol,
        diagnosticLogger: any DiagnosticLogging,
        clock: @escaping @Sendable () -> Date
    ) {
        self.repository = repository
        self.diagnosticLogger = diagnosticLogger
        self.clock = clock
    }

    public func ensureSeeded(spaceID _: String) {}

    public func entries(for spaceID: String) -> [LearningEntry] {
        do {
            return try repository.entries(for: spaceID)
        } catch {
            emitReadFailed(operation: "entries", error: error)
            return []
        }
    }

    public func selectedEntry(for spaceID: String) -> LearningEntry? {
        let entries = entries(for: spaceID)
        if let selectedID = selectedEntryIDs[spaceID],
           let selected = entries.first(where: { $0.id == selectedID })
        {
            return selected
        }
        return entries.first
    }

    public func selectEntry(id: String, spaceID: String) {
        guard entries(for: spaceID).contains(where: { $0.id == id }) else {
            return
        }
        selectedEntryIDs[spaceID] = id
    }

    @discardableResult
    public func createEntry(spaceID: String, title: String, body: String, source: EntrySource) throws -> LearningEntry {
        let draft = NewLearningEntryDraft(title: title, body: body, source: source, scene: "")
        let entry = try repository.createEntry(draft, in: spaceID)
        selectedEntryIDs[spaceID] = entry.id
        return entry
    }

    @discardableResult
    public func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry {
        let entry = try repository.updateEntryBody(entryID: entryID, spaceID: spaceID, body: body)
        selectedEntryIDs[spaceID] = entry.id
        return entry
    }

    @discardableResult
    public func createMockPhotoWritingEntry(spaceID: String) throws -> LearningEntry {
        try createEntry(
            spaceID: spaceID,
            title: "窗边早餐",
            body: "早上在窗边吃早餐，阳光照在桌子上。我突然觉得今天可以慢一点开始。",
            source: .photoWriting
        )
    }

    @discardableResult
    public func generateLocalPreview(for entryID: String, spaceID _: String) -> LearningRendering? {
        rendering(for: entryID)
    }

    public func rendering(for entryID: String) -> LearningRendering? {
        guard let material = try? repository.currentMaterial(for: entryID) else {
            return nil
        }
        return Self.rendering(from: material)
    }

    public func saveRendering(_ rendering: LearningRendering) {
        // No-op: the generation action already persists the material to the GRDB database
        // via saveGeneratedMaterial() before returning .generated(material). The bridge's
        // rendering(for:) reads directly from GRDB, so no additional save is needed here.
        _ = rendering
    }

    public func practiceItems(for entryID: String) -> [PracticeItem] {
        do {
            return try repository.practiceItems(for: entryID)
        } catch {
            emitReadFailed(operation: "practiceItems", error: error)
            return []
        }
    }

    public func memoryItems(for spaceID: String) -> [MemoryItem] {
        do {
            return try repository.memoryItems(for: spaceID)
        } catch {
            emitReadFailed(operation: "memoryItems", error: error)
            return []
        }
    }

    public func settingsCapabilities(for _: String) -> [SettingsCapability] {
        Self.settingsCapabilities
    }

    public func practiceSession(for entryID: String) -> PracticeSessionState? {
        guard let rendering = rendering(for: entryID) else {
            return nil
        }
        return PracticeSessionState(
            entryID: entryID,
            providerLabel: rendering.providerLabel,
            isExternalRequestRequired: true,
            steps: PracticeSessionStep.allCases,
            targetText: rendering.targetText
        )
    }

    public func learningPracticeReadiness(for spaceID: String) -> [String: Bool] {
        do {
            return try repository.learningPracticeReadiness(for: spaceID)
        } catch {
            emitReadFailed(operation: "learningPracticeReadiness", error: error)
            return [:]
        }
    }
}

private extension GRDBLearningContentRepositoryBridge {
    func emitReadFailed(operation: String, error: Error) {
        let event = DiagnosticEvent(
            id: UUID().uuidString,
            name: .learningContentRepositoryReadFailed,
            domain: .dataStorage,
            level: .warning,
            outcome: .failed,
            attributes: [
                .repositoryReadOperation(operation),
                .errorCategory(String(describing: error)),
            ],
            createdAt: clock()
        )
        Task { [diagnosticLogger] in
            await diagnosticLogger.record(event)
        }
    }

    static func rendering(from material: LearningMaterial) -> LearningRendering {
        LearningRendering(
            id: material.id,
            entryID: material.entryID,
            targetText: material.learningText,
            promptLabel: material.metadata.promptID,
            providerLabel: material.metadata.modelName,
            isMock: false,
            sourceEntryBodyHash: material.sourceEntryBodyHash,
            sentences: material.analysis.sentences.map { sentence in
                RenderingSentence(
                    id: sentence.id,
                    translation: sentence.nativeSentence,
                    targetText: sentence.targetSentence,
                    note: sentence.grammarNotes.joined(separator: "\n")
                )
            }
        )
    }

    static var settingsCapabilities: [SettingsCapability] {
        [
            SettingsCapability(
                kind: .languageSpace,
                status: .ready,
                summary: "settings.languageSpace.summary",
                detail: "settings.languageSpace.detail",
                nextRequirement: "settings.languageSpace.nextRequirement"
            ),
            SettingsCapability(
                kind: .interfaceLanguage,
                status: .mockOnly,
                summary: "settings.interfaceLanguage.summary",
                detail: "settings.interfaceLanguage.detail",
                nextRequirement: "settings.interfaceLanguage.nextRequirement"
            ),
            SettingsCapability(
                kind: .appearance,
                status: .ready,
                summary: "settings.appearance.summary",
                detail: "settings.appearance.detail",
                nextRequirement: "settings.appearance.nextRequirement"
            ),
            SettingsCapability(
                kind: .aiProvider,
                status: .ready,
                summary: "settings.aiProvider.summary",
                detail: "settings.aiProvider.detail",
                nextRequirement: "settings.aiProvider.nextRequirement"
            ),
            SettingsCapability(
                kind: .sync,
                status: .unavailable,
                summary: "settings.sync.summary",
                detail: "settings.sync.detail",
                nextRequirement: "settings.sync.nextRequirement"
            ),
            SettingsCapability(
                kind: .localData,
                status: .ready,
                summary: "settings.localData.summary",
                detail: "settings.localData.detail",
                nextRequirement: "settings.localData.nextRequirement"
            ),
            SettingsCapability(
                kind: .privacy,
                status: .ready,
                summary: "settings.privacy.summary",
                detail: "settings.privacy.detail",
                nextRequirement: "settings.privacy.nextRequirement"
            ),
            SettingsCapability(
                kind: .importExport,
                status: .unavailable,
                summary: "settings.importExport.summary",
                detail: "settings.importExport.detail",
                nextRequirement: "settings.importExport.nextRequirement"
            ),
        ]
    }
}
