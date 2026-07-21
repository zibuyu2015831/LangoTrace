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
    private let loadSettingsStatus: @Sendable () async -> SettingsStatusProjection
    private var runningOperationsByEntryID: [String: RunningLearningMaterialOperation] = [:]
    private var sentenceAudioPlaybackObservationTasks: [String: Task<Void, Never>] = [:]
    private var sentenceSequence: SentenceSequencePlayback?
    private var sentenceSequenceContext: SentenceSequenceContext?

    @Published private(set) var entries: [LearningEntry] = []
    @Published private(set) var selectedEntry: LearningEntry?
    @Published private(set) var memoryItems: [MemoryItem] = []
    @Published private(set) var settingsCapabilities: [SettingsCapability] = []
    @Published private(set) var generationStates: [String: LearningMaterialGenerationState] = [:]
    @Published private(set) var sentenceAudioPlaybackStates: [String: SentenceAudioPresentationState] = [:]
    /// The sentence currently being auto-played in a continuous reading sequence, or nil when
    /// no sequence is running. Drives the reading page's "now playing" highlight.
    @Published private(set) var activeSequenceSentenceID: String?
    /// entryID → hasCompletedRecording; only entries with a current learning material appear here.
    @Published private(set) var practiceReadiness: [String: Bool] = [:]
    /// E12 settings row values (AI / sync / local data). Defaults to the truthful fresh state
    /// until `refreshSettingsStatus()` runs off the main thread when a settings surface appears.
    @Published private(set) var settingsStatus = SettingsStatusProjection()

    init(
        repository: any LearningContentRepository,
        spaceID: String,
        generationActions: LearningMaterialGenerationActions = .disabled,
        sentenceAudioPlaybackActions: SentenceAudioPlaybackActions = .disabled,
        loadSettingsStatus: @escaping @Sendable () async -> SettingsStatusProjection = { SettingsStatusProjection() }
    ) {
        self.repository = repository
        self.spaceID = spaceID
        self.generationActions = generationActions
        self.sentenceAudioPlaybackActions = sentenceAudioPlaybackActions
        self.loadSettingsStatus = loadSettingsStatus
        reload()
    }

    /// Recomputes settings row values off the main thread (the projection reads SQLite + the
    /// filesystem). Render paths read the cached `settingsStatus`; they never block on this.
    func refreshSettingsStatus() async {
        settingsStatus = await loadSettingsStatus()
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
    func createEntry(title: String, body: String, source: EntrySource, scene: String = "") throws -> LearningEntry {
        let entry = try repository.createEntry(
            spaceID: spaceID,
            title: title,
            body: body,
            source: source,
            scene: scene
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
        // An explicit single-sentence tap takes over from any running continuous sequence.
        cancelSentenceSequenceIfActive()
        return await performSentenceAudioTap(
            rendering: rendering,
            sentence: sentence,
            sentenceIndex: sentenceIndex,
            languageSpace: languageSpace
        )
    }

    @discardableResult
    private func performSentenceAudioTap(
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

    /// Start continuous playback of the whole passage from `index`. The store is the sole
    /// driver of the sequence: it advances only on a sentence's natural completion. Any
    /// external interruption (single-sentence tap, stop, leaving the page) clears the
    /// sequence first, so a sentence going idle for those reasons never auto-advances.
    func playSentenceSequence(
        rendering: LearningRendering,
        languageSpace: LanguageSpacePreview,
        startingAt index: Int = 0
    ) async {
        let sentenceIDs = rendering.sentences.map(\.id)
        guard sentenceIDs.indices.contains(index) else { return }
        var sequence = SentenceSequencePlayback(totalCount: sentenceIDs.count)
        let step = sequence.start(at: index)
        sentenceSequence = sequence
        sentenceSequenceContext = SentenceSequenceContext(
            rendering: rendering,
            languageSpace: languageSpace,
            sentenceIDs: sentenceIDs
        )
        guard case let .play(playIndex) = step else {
            clearSentenceSequence()
            return
        }
        activeSequenceSentenceID = sentenceIDs[playIndex]
        await playSequenceSentence(at: playIndex)
    }

    func stopSentenceSequence() async {
        clearSentenceSequence()
        await stopSentenceAudioPlayback()
    }

    var isSentenceSequenceActive: Bool {
        sentenceSequence?.isActive ?? false
    }

    private func playSequenceSentence(at index: Int) async {
        guard let context = sentenceSequenceContext,
              context.rendering.sentences.indices.contains(index)
        else { return }
        await performSentenceAudioTap(
            rendering: context.rendering,
            sentence: context.rendering.sentences[index],
            sentenceIndex: index,
            languageSpace: context.languageSpace
        )
    }

    private var currentSequenceSentenceID: String? {
        guard let index = sentenceSequence?.currentIndex,
              let context = sentenceSequenceContext,
              context.sentenceIDs.indices.contains(index)
        else { return nil }
        return context.sentenceIDs[index]
    }

    private func clearSentenceSequence() {
        sentenceSequence = nil
        sentenceSequenceContext = nil
        activeSequenceSentenceID = nil
    }

    private func cancelSentenceSequenceIfActive() {
        guard sentenceSequence != nil else { return }
        clearSentenceSequence()
    }

    private func advanceSentenceSequenceIfNeeded(
        sentenceID: String,
        previous: SentenceAudioPresentationState?,
        current: SentenceAudioPresentationState
    ) {
        guard sentenceSequence != nil, currentSequenceSentenceID == sentenceID else { return }
        switch current {
        case .idle:
            // The sequence is the sole driver and external interruptions clear it first, so an
            // active sentence reaching idle here is a natural completion → advance.
            guard previous?.activeKey != nil else { return }
            advanceSentenceSequence()
        case .failed, .requiresConfiguration:
            clearSentenceSequence()
        case .generating, .playing, .paused:
            break
        }
    }

    private func advanceSentenceSequence() {
        guard var sequence = sentenceSequence else { return }
        let step = sequence.advanceAfterCompletion()
        sentenceSequence = sequence
        switch step {
        case let .play(index):
            if let context = sentenceSequenceContext, context.sentenceIDs.indices.contains(index) {
                activeSequenceSentenceID = context.sentenceIDs[index]
            }
            Task { await playSequenceSentence(at: index) }
        case .finished:
            clearSentenceSequence()
        }
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
        let previous = sentenceAudioPlaybackStates[sentenceID]
        if state.activeKey != nil {
            for existingSentenceID in sentenceAudioPlaybackStates.keys where existingSentenceID != sentenceID {
                if sentenceAudioPlaybackStates[existingSentenceID]?.activeKey != nil {
                    sentenceAudioPlaybackStates[existingSentenceID] = .idle
                }
            }
        }
        sentenceAudioPlaybackStates[sentenceID] = state
        advanceSentenceSequenceIfNeeded(sentenceID: sentenceID, previous: previous, current: state)
    }
}

private struct SentenceSequenceContext {
    let rendering: LearningRendering
    let languageSpace: LanguageSpacePreview
    let sentenceIDs: [String]
}

private struct RunningLearningMaterialOperation {
    var operationID: DiagnosticOperationID
    var materialID: String?
    var kind: LearningMaterialOperationKind
    var bucket: LearningMaterialEstimatedTokenBucket
    var task: Task<LearningMaterialGenerationActionResult, Never>
}
