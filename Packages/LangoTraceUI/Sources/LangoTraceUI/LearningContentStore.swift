import Combine
import Foundation
import LangoTraceCore
import LangoTraceData

@MainActor
final class LearningContentStore: ObservableObject {
    private let repository: any LearningContentRepository
    private let spaceID: String
    private let generationActions: LearningMaterialGenerationActions
    private let sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
    private var runningOperationsByEntryID: [String: RunningLearningMaterialOperation] = [:]
    private var sentenceAudioPlaybackObservationTasks: [String: Task<Void, Never>] = [:]

    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var selectedEntry: LearningEntry?
    @Published private(set) var memoryItems: [MemoryItem] = []
    @Published private(set) var settingsCapabilities: [SettingsCapability] = []
    @Published private(set) var generationStates: [String: LearningMaterialGenerationState] = [:]
    @Published private(set) var sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState] = [:]
    /// entryID → hasCompletedRecording; only entries with a current learning material appear here.
    @Published private(set) var practiceReadiness: [String: Bool] = [:]

    init(
        repository: any LearningContentRepository,
        spaceID: String,
        generationActions: LearningMaterialGenerationActions = .disabled,
        sentenceAudioPlaybackActions: SentenceAudioPlaybackActions = .disabled
    ) {
        self.repository = repository
        self.spaceID = spaceID
        self.generationActions = generationActions
        self.sentenceAudioPlaybackActions = sentenceAudioPlaybackActions
        reload()
    }

    deinit {
        for runningOperation in runningOperationsByEntryID.values {
            runningOperation.task.cancel()
        }
        for task in sentenceAudioPlaybackObservationTasks.values {
            task.cancel()
        }
    }

    func ensureSeeded() {
        repository.ensureSeeded(spaceID: spaceID)
        reload()
    }

    func selectEntry(_ entry: LearningEntry) {
        guard entry.spaceID == spaceID else {
            return
        }

        repository.selectEntry(id: entry.id, spaceID: spaceID)
        reload()
    }

    @discardableResult
    func createEntry(title: String, body: String, source: EntrySource) throws -> LearningEntry {
        let entry = try repository.createEntry(
            spaceID: spaceID,
            title: title,
            body: body,
            source: source
        )
        reload()
        return entry
    }

    func deleteEntry(id: String) throws {
        try repository.deleteEntry(id: id)
        reload()
    }

    func rendering(for entry: LearningEntry) -> LearningRendering? {
        rendering(for: entry.id)
    }

    func rendering(for entryID: String) -> LearningRendering? {
        repository.rendering(for: entryID)
    }

    @discardableResult
    func updateEntryBody(entryID: String, body: String) throws -> LearningEntry {
        let entry = try repository.updateEntryBody(entryID: entryID, spaceID: spaceID, body: body)
        reload()
        return entry
    }

    func sourceEntryIsStale(for entry: LearningEntry) -> Bool {
        guard let rendering = rendering(for: entry) else {
            return false
        }
        return rendering.sourceEntryBodyHash != LearningMaterialTextHash.sha256(for: entry.body)
    }

    @discardableResult
    func generateLocalPreview(for entry: LearningEntry) -> LearningRendering? {
        guard entry.spaceID == spaceID else {
            return nil
        }

        let rendering = repository.generateLocalPreview(for: entry.id, spaceID: spaceID)
        reload()
        return rendering
    }

    func practiceItems(for entry: LearningEntry) -> [PracticeItem] {
        repository.practiceItems(for: entry.id)
    }

    func practiceItems(for entryID: String) -> [PracticeItem] {
        repository.practiceItems(for: entryID)
    }

    func practiceSession(for entry: LearningEntry) -> PracticeSessionState? {
        repository.practiceSession(for: entry.id)
    }

    func practiceSession(for entryID: String) -> PracticeSessionState? {
        repository.practiceSession(for: entryID)
    }

    func memoryItems(for entry: LearningEntry) -> [MemoryItem] {
        memoryItems.filter { $0.entryID == entry.id }
    }

    func generationState(for entry: LearningEntry) -> LearningMaterialGenerationState {
        generationState(for: entry.id)
    }

    func generationState(for entryID: String) -> LearningMaterialGenerationState {
        if let state = generationStates[entryID] {
            return state
        }
        if let rendering = rendering(for: entryID) {
            return .generated(materialID: rendering.id)
        }
        return .idle
    }

    func generateLearningMaterial(
        for entry: LearningEntry,
        languageSpace: LanguageSpacePreview
    ) async {
        guard entry.spaceID == spaceID else {
            return
        }
        guard generationState(for: entry).canStartGeneration else {
            // Keep the in-flight display state untouched; only record the blocked trigger for diagnostics.
            await recordBlockedOperation(for: entry.id, kind: .generate, category: .operationInProgress, bucket: .short)
            return
        }
        let sourceText = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            generationStates[entry.id] = .blocked(.contentEmpty)
            await recordBlockedOperation(for: entry.id, kind: .generate, category: .contentEmpty, bucket: .short)
            return
        }
        let lengthBucket = LearningMaterialLengthEstimator.bucket(for: sourceText)
        guard lengthBucket != .tooLong else {
            generationStates[entry.id] = .blocked(.contentTooLong)
            await recordBlockedOperation(for: entry.id, kind: .generate, category: .contentTooLong, bucket: lengthBucket)
            return
        }

        let operationID = generationActions.operationIDGenerator()
        let input = LearningMaterialGenerationInput(
            entryID: entry.id,
            spaceID: spaceID,
            sourceText: sourceText,
            entrySource: entry.source,
            nativeLanguageCode: languageSpace.nativeLanguage,
            targetLanguageCode: languageSpace.targetLanguageCode,
            proficiencyLevelCode: languageSpace.level.rawValue.lowercased(),
            promptMode: .automaticLearningMaterial
        )

        let task = Task {
            await generationActions.generateMaterial(input, operationID, lengthBucket)
        }
        runningOperationsByEntryID[entry.id] = RunningLearningMaterialOperation(
            operationID: operationID,
            materialID: nil,
            kind: .generate,
            bucket: lengthBucket,
            task: task
        )
        generationStates[entry.id] = .generating(operationID: operationID)
        let result = await task.value
        guard runningOperationsByEntryID[entry.id]?.operationID == operationID else {
            return
        }
        runningOperationsByEntryID[entry.id] = nil
        switch result {
        case let .generated(material):
            repository.saveRendering(Self.rendering(from: material))
            generationStates[entry.id] = state(for: material)
            reload()
        case let .failed(category):
            generationStates[entry.id] = .failed(
                LearningMaterialGenerationFailureDisplay(category: category, operationID: operationID)
            )
        }
    }

    func updateLearningText(
        materialID: String,
        entryID: String,
        learningText: String
    ) async {
        guard runningOperationsByEntryID[entryID] == nil else {
            return
        }
        let result = await generationActions.updateLearningText(materialID, learningText)
        guard runningOperationsByEntryID[entryID] == nil else {
            return
        }
        switch result {
        case let .generated(material):
            repository.saveRendering(Self.rendering(from: material))
            generationStates[entryID] = state(for: material)
            reload()
        case let .failed(category):
            generationStates[entryID] = .failed(
                LearningMaterialGenerationFailureDisplay(
                    category: category,
                    materialID: materialID,
                    analysisIsStale: generationState(for: entryID).analysisIsStale
                )
            )
        }
    }

    func analyzeCurrentLearningText(
        for entry: LearningEntry,
        languageSpace: LanguageSpacePreview
    ) async {
        guard entry.spaceID == spaceID,
              let rendering = rendering(for: entry)
        else {
            return
        }
        guard generationState(for: entry).canStartGeneration else {
            // Keep the in-flight display state untouched; only record the blocked trigger for diagnostics.
            await recordBlockedOperation(for: entry.id, kind: .analyze, category: .operationInProgress, bucket: .short)
            return
        }
        let learningText = rendering.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !learningText.isEmpty else {
            generationStates[entry.id] = .blocked(.contentEmpty)
            await recordBlockedOperation(for: entry.id, kind: .analyze, category: .contentEmpty, bucket: .short)
            return
        }
        let lengthBucket = LearningMaterialLengthEstimator.bucket(for: learningText)
        guard lengthBucket != .tooLong else {
            generationStates[entry.id] = .blocked(.contentTooLong)
            await recordBlockedOperation(for: entry.id, kind: .analyze, category: .contentTooLong, bucket: lengthBucket)
            return
        }
        let operationID = generationActions.operationIDGenerator()
        let input = LearningMaterialAnalysisInput(
            materialID: rendering.id,
            learningText: learningText,
            nativeLanguageCode: languageSpace.nativeLanguage,
            targetLanguageCode: languageSpace.targetLanguageCode,
            proficiencyLevelCode: languageSpace.level.rawValue.lowercased()
        )
        let task = Task {
            await generationActions.analyzeCurrentText(input, operationID, lengthBucket)
        }
        runningOperationsByEntryID[entry.id] = RunningLearningMaterialOperation(
            operationID: operationID,
            materialID: rendering.id,
            kind: .analyze,
            bucket: lengthBucket,
            task: task
        )
        generationStates[entry.id] = .analyzing(materialID: rendering.id, operationID: operationID)
        let result = await task.value
        guard runningOperationsByEntryID[entry.id]?.operationID == operationID else {
            return
        }
        runningOperationsByEntryID[entry.id] = nil
        switch result {
        case let .generated(material):
            repository.saveRendering(Self.rendering(from: material))
            generationStates[entry.id] = state(for: material)
            reload()
        case let .failed(category):
            generationStates[entry.id] = .failed(
                LearningMaterialGenerationFailureDisplay(
                    category: category,
                    operationID: operationID,
                    materialID: rendering.id,
                    analysisIsStale: true
                )
            )
        }
    }

    func cancelLearningMaterialGeneration(for entry: LearningEntry) async {
        guard entry.spaceID == spaceID,
              let running = runningOperationsByEntryID[entry.id]
        else {
            return
        }
        running.task.cancel()
        runningOperationsByEntryID[entry.id] = nil
        generationStates[entry.id] = .cancelled(materialID: running.materialID)
        await generationActions.cancelOperation(
            running.operationID,
            entry.id,
            running.materialID,
            running.kind,
            running.bucket
        )
    }

    func entry(id: String) -> LearningEntry? {
        entries.first { $0.id == id }
    }

    func capability(kind: SettingsCapability.Kind) -> SettingsCapability? {
        settingsCapabilities.first { $0.kind == kind }
    }

    private func reload() {
        entries = repository.entries(for: spaceID)
        selectedEntry = repository.selectedEntry(for: spaceID)
        memoryItems = repository.memoryItems(for: spaceID)
        settingsCapabilities = repository.settingsCapabilities(for: spaceID)
        practiceReadiness = repository.learningPracticeReadiness(for: spaceID)
    }

    private func recordBlockedOperation(
        for entryID: String,
        kind: LearningMaterialOperationKind,
        category: LearningMaterialGenerationFailureCategory,
        bucket: LearningMaterialEstimatedTokenBucket
    ) async {
        await generationActions.recordBlockedOperation(
            generationActions.operationIDGenerator(),
            entryID,
            kind,
            category,
            bucket
        )
    }

    private func state(for material: LearningMaterial) -> LearningMaterialGenerationState {
        switch material.analysis.status {
        case .stale:
            .editing(materialID: material.id, analysisIsStale: true)
        case .fresh:
            .generated(materialID: material.id)
        case .missing, .failed:
            .editing(materialID: material.id, analysisIsStale: true)
        }
    }

    private static func rendering(from material: LearningMaterial) -> LearningRendering {
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
}

extension LearningContentStore {
    func sentenceAudioPlaybackState(for sentenceID: String) -> SentenceAudioPresentationState {
        sentenceAudioPlaybackStates[sentenceID] ?? .idle
    }

    @discardableResult
    func handleSentenceAudioTap(
        rendering: LearningRendering,
        sentence: RenderingSentence,
        sentenceIndex: Int,
        languageSpace: LanguageSpacePreview
    ) async -> SentenceAudioPresentationState {
        let request = SentenceAudioRequest(
            languageSpaceID: languageSpace.id,
            owner: .learningMaterialSentence(materialID: rendering.id, sentenceIndex: sentenceIndex),
            sentenceSource: .learningMaterialSentence(materialID: rendering.id, sentenceIndex: sentenceIndex),
            sentenceIndex: sentenceIndex,
            targetText: sentence.targetText,
            targetLanguageCode: languageSpace.targetLanguageCode
        )
        let state = await sentenceAudioPlaybackActions.handleTap(request)
        setSentenceAudioPlaybackState(state, for: sentence.id)
        observeSentenceAudioPlaybackState(for: sentence.id, request: request)
        return state
    }

    func handlePracticeDemoTap(
        routeSeed: PracticeSessionRouteSeed,
        languageSpace: LanguageSpacePreview
    ) async -> SentenceAudioPresentationState {
        let request = SentenceAudioRequest(
            languageSpaceID: languageSpace.id,
            owner: .learningMaterialSentence(
                materialID: routeSeed.learningMaterialID,
                sentenceIndex: routeSeed.sentenceIndex
            ),
            sentenceSource: .learningMaterialSentence(
                materialID: routeSeed.learningMaterialID,
                sentenceIndex: routeSeed.sentenceIndex
            ),
            sentenceIndex: routeSeed.sentenceIndex,
            targetText: routeSeed.snapshot.targetTextSnapshot,
            targetLanguageCode: routeSeed.targetLanguageCode
        )
        let state = await sentenceAudioPlaybackActions.handleTap(request)
        setSentenceAudioPlaybackState(state, for: routeSeed.sentenceID)
        observeSentenceAudioPlaybackState(for: routeSeed.sentenceID, request: request)
        return state
    }

    func stopSentenceAudioPlayback() async {
        await sentenceAudioPlaybackActions.stopActivePlayback()
    }

    private func observeSentenceAudioPlaybackState(for sentenceID: String, request: SentenceAudioRequest) {
        sentenceAudioPlaybackObservationTasks[sentenceID]?.cancel()
        let actions = sentenceAudioPlaybackActions
        sentenceAudioPlaybackObservationTasks[sentenceID] = Task { [weak self] in
            let stream = await actions.stateUpdates(request)
            for await state in stream {
                guard !Task.isCancelled else {
                    return
                }
                // Only hold `self` strongly per event so an unfinished stream cannot keep the store alive.
                guard let self else {
                    return
                }
                await MainActor.run {
                    self.setSentenceAudioPlaybackState(state, for: sentenceID)
                }
            }
        }
    }

    private func setSentenceAudioPlaybackState(_ state: SentenceAudioPresentationState, for sentenceID: String) {
        if state.activeKey != nil {
            for existingSentenceID in sentenceAudioPlaybackStates.keys where existingSentenceID != sentenceID {
                if sentenceAudioPlaybackStates[existingSentenceID]?.activeKey != nil {
                    sentenceAudioPlaybackStates[existingSentenceID] = .idle
                }
            }
        }
        sentenceAudioPlaybackStates[sentenceID] = state
    }
}

private struct RunningLearningMaterialOperation {
    var operationID: DiagnosticOperationID
    var materialID: String?
    var kind: LearningMaterialOperationKind
    var bucket: LearningMaterialEstimatedTokenBucket
    var task: Task<LearningMaterialGenerationActionResult, Never>
}
