import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store")
@MainActor
struct LearningContentStoreTests {
    @Test("Store centralizes seed, selection, creation, and derived content reads")
    func storeCentralizesRepositoryReadsAndMutations() throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let store = LearningContentStore(repository: repository, spaceID: "en")

        store.ensureSeeded()
        let originalEntries = store.entries

        #expect(originalEntries.count == 3)
        #expect(store.selectedEntry?.id == originalEntries.first?.id)

        let created = try store.createEntry(
            title: "Evening walk",
            body: "I walked after dinner.",
            source: .typedText
        )

        #expect(store.entries.first?.id == created.id)
        #expect(store.selectedEntry?.id == created.id)
        #expect(store.rendering(for: created) == nil)
        #expect(store.practiceItems(for: created).isEmpty)
        #expect(store.practiceSession(for: created) == nil)
        #expect(!store.memoryItems.contains { $0.entryID == created.id })

        let preview = store.generateLocalPreview(for: created)

        #expect(preview?.entryID == created.id)
        #expect(store.rendering(for: created)?.entryID == created.id)
        #expect(store.practiceItems(for: created).count == 1)
        #expect(store.practiceSession(for: created)?.entryID == created.id)
        #expect(store.memoryItems.contains { $0.entryID == created.id })
        #expect(store.settingsCapabilities.map(\.kind).contains(.interfaceLanguage))
        #expect(store.settingsCapabilities.map(\.kind).contains(.importExport))
        #expect(!store.settingsCapabilities.map(\.kind.title).contains("export"))

        let photoEntry = try store.createMockPhotoWritingEntry()

        #expect(store.entries.first?.id == photoEntry.id)
        #expect(photoEntry.source == .photoWriting)
        #expect(store.rendering(for: photoEntry)?.isMock == true)
        #expect(store.practiceItems(for: photoEntry).map(\.kind).contains(.listening))
        #expect(store.practiceSession(for: photoEntry)?.isLocalOnly == true)
        #expect(store.memoryItems.contains { $0.entryID == photoEntry.id })
    }

    @Test("Store selection ignores entries outside the active space")
    func storeSelectionIgnoresEntriesOutsideActiveSpace() {
        let repository = InMemoryLearningContentRepository.seeded(spaceID: "en")
        let store = LearningContentStore(repository: repository, spaceID: "en")
        store.ensureSeeded()
        let originalSelection = store.selectedEntry?.id

        let foreignEntry = LearningEntry(
            id: "foreign-entry",
            spaceID: "ja",
            title: "Foreign",
            body: "Foreign",
            source: .typedText,
            scene: "Fixture",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        store.selectEntry(foreignEntry)

        #expect(store.selectedEntry?.id == originalSelection)
    }

    @Test("Store routes sentence audio taps through injected action contract")
    func storeRoutesSentenceAudioTapsThroughActions() async throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let recorder = SentenceAudioPlaybackActionRecorder()
        let store = LearningContentStore(
            repository: repository,
            spaceID: "space-1",
            sentenceAudioPlaybackActions: SentenceAudioPlaybackActions(
                handleTap: { request in
                    await recorder.record(request)
                    return .playing(SentenceAudioKey(
                        sentenceSource: request.sentenceSource,
                        sentenceTextHash: "hash",
                        targetLanguageCode: request.targetLanguageCode,
                        configurationFingerprint: "fingerprint"
                    ))
                },
                presentationState: { _ in .idle }
            )
        )
        let entry = try store.createEntry(title: "Walk", body: "I walked home.", source: .typedText)
        let rendering = try #require(store.generateLocalPreview(for: entry))
        let sentence = try #require(rendering.sentences.first)
        let languageSpace = LanguageSpacePreview(
            id: "space-1",
            name: "English",
            nativeLanguage: "zh-Hans",
            targetLanguage: "English",
            targetLanguageCode: "en",
            level: .a1
        )

        await store.handleSentenceAudioTap(
            rendering: rendering,
            sentence: sentence,
            sentenceIndex: 0,
            languageSpace: languageSpace
        )

        let request = try await #require(recorder.requests.first)
        #expect(request.languageSpaceID == "space-1")
        #expect(request.sentenceIndex == 0)
        #expect(request.targetText == sentence.targetText)
        #expect(store.sentenceAudioPlaybackState(for: sentence.id).activeKey?.targetLanguageCode == "en")
    }

    @Test("Store runs learning material generation action and exposes generated rendering")
    func storeRunsLearningMaterialGenerationAction() async throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry).materialID == "material-operation-1")
        #expect(store.generationState(for: entry).isRunning == false)
        #expect(store.rendering(for: entry)?.targetText == "I went to a cafe today.")
        #expect(store.rendering(for: entry)?.isMock == false)
    }

    @Test("Store blocks overlong learning material generation before action")
    func storeBlocksOverlongLearningMaterialGeneration() async throws {
        let actionCounter = LearningMaterialActionCallCounter()
        let blockedRecorder = LearningMaterialBlockedOperationRecorder()
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { _, _, _ in
                await actionCounter.increment()
                return .failed(.unknown)
            },
            recordBlockedOperation: { operationID, entryID, kind, category, bucket in
                await blockedRecorder.record(operationID, entryID, kind, category, bucket)
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "blocked-operation") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let longText = String(repeating: "我", count: 3100)
        let entry = try store.createEntry(title: "Long", body: longText, source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry) == .blocked(.contentTooLong))
        #expect(await actionCounter.value == 0)
        #expect(await blockedRecorder.records == [
            LearningMaterialBlockedOperationRecord(
                operationID: DiagnosticOperationID(rawValue: "blocked-operation"),
                entryID: entry.id,
                kind: .generate,
                category: .contentTooLong,
                bucket: .tooLong
            ),
        ])
    }

    @Test("Store cancels running generation and discards late result")
    func storeCancelsRunningGenerationAndDiscardsLateResult() async throws {
        let gate = LearningMaterialGenerationGate()
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                await gate.waitUntilReleased()
                return .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            cancelOperation: { operationID, _, _, _, _ in
                await gate.recordCancelled(operationID)
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-cancel") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        let task = Task {
            await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.cancelLearningMaterialGeneration(for: entry)
        await gate.release()
        await task.value

        #expect(store.generationState(for: entry) == LearningMaterialGenerationState.cancelled(materialID: nil))
        #expect(store.rendering(for: entry) == nil)
        #expect(await gate.cancelledOperations == [DiagnosticOperationID(rawValue: "operation-cancel")])
    }

    @Test("Store edits learning text as stale and refreshes analysis without regenerating text")
    func storeEditsLearningTextAndRefreshesAnalysis() async throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            updateLearningText: { materialID, learningText in
                .generated(sampleLearningMaterial(
                    materialID: materialID,
                    entryID: "entry-1-en",
                    learningText: learningText,
                    analysisStatus: .stale
                ))
            },
            analyzeCurrentText: { input, operationID, _ in
                .generated(sampleLearningMaterial(
                    materialID: input.materialID,
                    entryID: "entry-1-en",
                    learningText: input.learningText,
                    operationID: operationID,
                    analysisStatus: .fresh
                ))
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        await store.updateLearningText(
            materialID: "material-operation-1",
            entryID: entry.id,
            learningText: "I wrote at a cafe today."
        )

        #expect(store.generationState(for: entry).analysisIsStale == true)
        #expect(store.rendering(for: entry)?.targetText == "I wrote at a cafe today.")

        await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry).analysisIsStale == false)
        #expect(store.rendering(for: entry)?.targetText == "I wrote at a cafe today.")
        #expect(store.rendering(for: entry)?.sentences.first?.targetText == "I wrote at a cafe today.")
    }

    @Test("Store updates source entry body and derives stale source material state")
    func storeUpdatesSourceEntryBodyAndDerivesSourceStaleState() async throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(
                    entryID: input.entryID,
                    operationID: operationID,
                    sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: input.sourceText)
                ))
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)
        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        let updated = try store.updateEntryBody(entryID: entry.id, body: "今天我去图书馆。")

        #expect(updated.body == "今天我去图书馆。")
        #expect(store.selectedEntry?.body == "今天我去图书馆。")
        #expect(store.entries.first?.body == "今天我去图书馆。")
        #expect(store.sourceEntryIsStale(for: updated))
        #expect(store.rendering(for: updated)?.targetText == "I went to a cafe today.")
    }

    @Test("Store regeneration clears source stale while learning text edit only marks analysis stale")
    func storeRegenerationClearsSourceStaleAndLearningTextEditKeepsSourceFreshness() async throws {
        let generationText = LearningMaterialGenerationText("I went to a cafe today.")
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                let text = await generationText.value
                return .generated(sampleLearningMaterial(
                    entryID: input.entryID,
                    learningText: text,
                    operationID: operationID,
                    sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: input.sourceText)
                ))
            },
            updateLearningText: { materialID, learningText in
                .generated(sampleLearningMaterial(
                    materialID: materialID,
                    entryID: "entry-1-en",
                    learningText: learningText,
                    analysisStatus: .stale,
                    sourceEntryBodyHash: LearningMaterialTextHash.sha256(for: "今天我去图书馆。")
                ))
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)
        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        let updated = try store.updateEntryBody(entryID: entry.id, body: "今天我去图书馆。")

        #expect(store.sourceEntryIsStale(for: updated))

        await generationText.update("I went to the library today.")
        await store.generateLearningMaterial(for: updated, languageSpace: sampleLanguageSpace())

        #expect(!store.sourceEntryIsStale(for: updated))

        await store.updateLearningText(
            materialID: "material-operation-1",
            entryID: updated.id,
            learningText: "I wrote at the library today."
        )

        #expect(store.generationState(for: updated).analysisIsStale)
        #expect(!store.sourceEntryIsStale(for: updated))
    }

    @Test("Store keeps stale material retry context when reanalysis fails")
    func storeKeepsStaleMaterialRetryContextWhenReanalysisFails() async throws {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            updateLearningText: { materialID, learningText in
                .generated(sampleLearningMaterial(
                    materialID: materialID,
                    entryID: "entry-1-en",
                    learningText: learningText,
                    analysisStatus: .stale
                ))
            },
            analyzeCurrentText: { _, _, _ in
                .failed(.networkUnavailable)
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        await store.updateLearningText(
            materialID: "material-operation-1",
            entryID: entry.id,
            learningText: "I wrote at a cafe today."
        )
        await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())

        let state = store.generationState(for: entry)
        #expect(state.materialID == "material-operation-1")
        #expect(state.analysisIsStale)
        #expect(state.canStartGeneration)
        #expect(state.operationID?.rawValue == "operation-1")
    }

    private func sampleLanguageSpace() -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: "en",
            name: "English",
            nativeLanguage: "zh-Hans",
            targetLanguage: "English",
            targetLanguageCode: "en",
            level: .b1
        )
    }
}

private actor SentenceAudioPlaybackActionRecorder {
    private(set) var requests: [SentenceAudioRequest] = []

    func record(_ request: SentenceAudioRequest) {
        requests.append(request)
    }
}

private actor LearningMaterialActionCallCounter {
    private var callCount = 0

    var value: Int {
        callCount
    }

    func increment() {
        callCount += 1
    }
}

private struct LearningMaterialBlockedOperationRecord: Equatable {
    var operationID: DiagnosticOperationID
    var entryID: String
    var kind: LearningMaterialOperationKind
    var category: LearningMaterialGenerationFailureCategory
    var bucket: LearningMaterialEstimatedTokenBucket
}

private actor LearningMaterialBlockedOperationRecorder {
    private var values: [LearningMaterialBlockedOperationRecord] = []

    var records: [LearningMaterialBlockedOperationRecord] {
        values
    }

    func record(
        _ operationID: DiagnosticOperationID,
        _ entryID: String,
        _ kind: LearningMaterialOperationKind,
        _ category: LearningMaterialGenerationFailureCategory,
        _ bucket: LearningMaterialEstimatedTokenBucket
    ) {
        values.append(
            LearningMaterialBlockedOperationRecord(
                operationID: operationID,
                entryID: entryID,
                kind: kind,
                category: category,
                bucket: bucket
            )
        )
    }
}

private actor LearningMaterialGenerationGate {
    private var started = false
    private var released = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []
    private var cancellations: [DiagnosticOperationID] = []

    var cancelledOperations: [DiagnosticOperationID] {
        cancellations
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func waitUntilReleased() async {
        started = true
        startContinuations.forEach { $0.resume() }
        startContinuations.removeAll()
        if released { return }
        await withCheckedContinuation { continuation in
            releaseContinuations.append(continuation)
        }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }

    func recordCancelled(_ operationID: DiagnosticOperationID) {
        cancellations.append(operationID)
    }
}

private actor LearningMaterialGenerationText {
    private var text: String

    init(_ text: String) {
        self.text = text
    }

    var value: String {
        text
    }

    func update(_ text: String) {
        self.text = text
    }
}

private func sampleLearningMaterial(
    entryID: String,
    operationID: DiagnosticOperationID,
    sourceEntryBodyHash: String = LearningMaterialTextHash.sha256(for: "今天我去咖啡馆。")
) -> LearningMaterial {
    sampleLearningMaterial(
        materialID: "material-\(operationID.rawValue)",
        entryID: entryID,
        learningText: "I went to a cafe today.",
        operationID: operationID,
        analysisStatus: .fresh,
        sourceEntryBodyHash: sourceEntryBodyHash
    )
}

private func sampleLearningMaterial(
    entryID: String,
    learningText: String,
    operationID: DiagnosticOperationID,
    sourceEntryBodyHash: String
) -> LearningMaterial {
    sampleLearningMaterial(
        materialID: "material-\(operationID.rawValue)",
        entryID: entryID,
        learningText: learningText,
        operationID: operationID,
        analysisStatus: .fresh,
        sourceEntryBodyHash: sourceEntryBodyHash
    )
}

private func sampleLearningMaterial(
    materialID: String,
    entryID: String,
    learningText: String,
    operationID _: DiagnosticOperationID = DiagnosticOperationID(rawValue: "operation-1"),
    analysisStatus: LearningMaterialAnalysisStatus,
    sourceEntryBodyHash: String = LearningMaterialTextHash.sha256(for: "今天我去咖啡馆。")
) -> LearningMaterial {
    LearningMaterial(
        id: materialID,
        entryID: entryID,
        spaceID: "en",
        inputKind: .nativeRecord,
        promptMode: .automaticLearningMaterial,
        learningText: learningText,
        originalGeneratedText: "I went to a cafe today.",
        sourceEntryBodyHash: sourceEntryBodyHash,
        revisionSummary: [],
        analysis: LearningMaterialAnalysis(
            status: analysisStatus,
            sourceTextHash: "hash",
            sentences: [
                LearningSentenceAnalysis(
                    id: "sentence-1",
                    nativeSentence: "我今天去咖啡馆。",
                    targetSentence: learningText,
                    literalTranslation: "I today went cafe.",
                    naturalTranslation: learningText,
                    grammarNotes: ["went is past tense."],
                    keyPoints: ["went to"],
                    position: 0
                ),
            ],
            memoryCandidates: [],
            practiceCandidates: []
        ),
        metadata: LearningMaterialGenerationMetadata(
            promptID: "builtin.learning_material.generate.v1",
            promptVersion: "1",
            providerProfileID: "profile-1",
            providerEndpointID: "endpoint-1",
            providerPresetID: "openai",
            modelName: "gpt-4.1-mini",
            generatedAt: Date(timeIntervalSince1970: 0)
        ),
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0),
        isCurrent: true
    )
}
