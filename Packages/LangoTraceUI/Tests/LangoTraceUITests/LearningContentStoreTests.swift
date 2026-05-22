import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store")
@MainActor
struct LearningContentStoreTests {
    @Test("Store centralizes seed, selection, creation, and derived content reads")
    func storeCentralizesRepositoryReadsAndMutations() {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let store = LearningContentStore(repository: repository, spaceID: "en")

        store.ensureSeeded()
        let originalEntries = store.entries

        #expect(originalEntries.count == 3)
        #expect(store.selectedEntry?.id == originalEntries.first?.id)

        let created = store.createEntry(
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

        let photoEntry = store.createMockPhotoWritingEntry()

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

    @Test("Store runs learning material generation action and exposes generated rendering")
    func storeRunsLearningMaterialGenerationAction() async {
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-1") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry).materialID == "material-operation-1")
        #expect(store.generationState(for: entry).isRunning == false)
        #expect(store.rendering(for: entry)?.targetText == "I went to a cafe today.")
        #expect(store.rendering(for: entry)?.isMock == false)
    }

    @Test("Store blocks overlong learning material generation before action")
    func storeBlocksOverlongLearningMaterialGeneration() async {
        let actionCounter = LearningMaterialActionCallCounter()
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { _, _, _ in
                await actionCounter.increment()
                return .failed(.unknown)
            }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let longText = String(repeating: "我", count: 3100)
        let entry = store.createEntry(title: "Long", body: longText, source: .typedText)

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry) == .blocked(.contentTooLong))
        #expect(await actionCounter.value == 0)
    }

    @Test("Store edits learning text as stale and refreshes analysis without regenerating text")
    func storeEditsLearningTextAndRefreshesAnalysis() async {
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
        let entry = store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

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

private actor LearningMaterialActionCallCounter {
    private var callCount = 0

    var value: Int {
        callCount
    }

    func increment() {
        callCount += 1
    }
}

private func sampleLearningMaterial(
    entryID: String,
    operationID: DiagnosticOperationID
) -> LearningMaterial {
    sampleLearningMaterial(
        materialID: "material-\(operationID.rawValue)",
        entryID: entryID,
        learningText: "I went to a cafe today.",
        operationID: operationID,
        analysisStatus: .fresh
    )
}

private func sampleLearningMaterial(
    materialID: String,
    entryID: String,
    learningText: String,
    operationID _: DiagnosticOperationID = DiagnosticOperationID(rawValue: "operation-1"),
    analysisStatus: LearningMaterialAnalysisStatus
) -> LearningMaterial {
    LearningMaterial(
        id: materialID,
        entryID: entryID,
        spaceID: "en",
        inputKind: .nativeRecord,
        promptMode: .automaticLearningMaterial,
        learningText: learningText,
        originalGeneratedText: "I went to a cafe today.",
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
