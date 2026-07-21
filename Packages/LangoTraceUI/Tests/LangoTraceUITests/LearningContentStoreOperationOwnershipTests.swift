import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store operation ownership")
@MainActor
struct LearningContentStoreOperationOwnershipTests {
    @Test("Second generate trigger while running keeps generating state and first result lands")
    func secondGenerateTriggerWhileRunningKeepsStateAndFirstResultLands() async throws {
        let gate = LearningMaterialOperationGate()
        let blockedRecorder = BlockedOperationCategoryRecorder()
        let operationIDs = OwnershipOperationIDSequence([
            DiagnosticOperationID(rawValue: "operation-first"),
            DiagnosticOperationID(rawValue: "operation-blocked"),
        ])
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                await gate.waitUntilReleased()
                return .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            recordBlockedOperation: { _, _, _, category, _ in
                await blockedRecorder.record(category)
            },
            operationIDGenerator: { operationIDs.next() }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        let firstRun = Task {
            await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry)
            == .generating(operationID: DiagnosticOperationID(rawValue: "operation-first")))
        #expect(await blockedRecorder.categories == [.operationInProgress])

        await gate.release()
        await firstRun.value

        #expect(store.generationState(for: entry) == .generated(materialID: "material-operation-first"))
        #expect(store.rendering(for: entry)?.targetText == "I went to a cafe today.")

        await store.cancelLearningMaterialGeneration(for: entry)

        #expect(store.generationState(for: entry) == .generated(materialID: "material-operation-first"))
    }

    @Test("Second analyze trigger while running keeps analyzing state and first result lands")
    func secondAnalyzeTriggerWhileRunningKeepsStateAndFirstResultLands() async throws {
        let gate = LearningMaterialOperationGate()
        let blockedRecorder = BlockedOperationCategoryRecorder()
        let operationIDs = OwnershipOperationIDSequence([
            DiagnosticOperationID(rawValue: "operation-generate"),
            DiagnosticOperationID(rawValue: "operation-analyze"),
            DiagnosticOperationID(rawValue: "operation-blocked"),
        ])
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            analyzeCurrentText: { input, _, _ in
                await gate.waitUntilReleased()
                return .generated(sampleLearningMaterial(
                    materialID: input.materialID,
                    entryID: "entry-1-en",
                    learningText: input.learningText,
                    analysisStatus: .fresh
                ))
            },
            recordBlockedOperation: { _, _, _, category, _ in
                await blockedRecorder.record(category)
            },
            operationIDGenerator: { operationIDs.next() }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)
        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        let firstRun = Task {
            await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())

        #expect(store.generationState(for: entry) == .analyzing(
            materialID: "material-operation-generate",
            operationID: DiagnosticOperationID(rawValue: "operation-analyze")
        ))
        #expect(await blockedRecorder.categories == [.operationInProgress])

        await gate.release()
        await firstRun.value

        #expect(store.generationState(for: entry) == .generated(materialID: "material-operation-generate"))

        await store.cancelLearningMaterialGeneration(for: entry)

        #expect(store.generationState(for: entry) == .generated(materialID: "material-operation-generate"))
    }

    @Test("Learning text update is ignored while an operation is running")
    func learningTextUpdateIsIgnoredWhileOperationIsRunning() async throws {
        let gate = LearningMaterialOperationGate()
        let updateCounter = LearningTextUpdateCallCounter()
        let operationIDs = OwnershipOperationIDSequence([
            DiagnosticOperationID(rawValue: "operation-generate"),
            DiagnosticOperationID(rawValue: "operation-analyze"),
        ])
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            updateLearningText: { materialID, learningText in
                await updateCounter.increment()
                return .generated(sampleLearningMaterial(
                    materialID: materialID,
                    entryID: "entry-1-en",
                    learningText: learningText,
                    analysisStatus: .stale
                ))
            },
            analyzeCurrentText: { input, _, _ in
                await gate.waitUntilReleased()
                return .generated(sampleLearningMaterial(
                    materialID: input.materialID,
                    entryID: "entry-1-en",
                    learningText: input.learningText,
                    analysisStatus: .fresh
                ))
            },
            operationIDGenerator: { operationIDs.next() }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)
        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        let analyzeRun = Task {
            await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.updateLearningText(
            materialID: "material-operation-generate",
            entryID: entry.id,
            learningText: "I wrote at a cafe today."
        )

        #expect(await updateCounter.value == 0)
        #expect(store.generationState(for: entry) == .analyzing(
            materialID: "material-operation-generate",
            operationID: DiagnosticOperationID(rawValue: "operation-analyze")
        ))

        await gate.release()
        await analyzeRun.value

        #expect(store.generationState(for: entry) == .generated(materialID: "material-operation-generate"))
    }

    @Test("Store deallocates while a sentence audio state stream is still open")
    func storeDeallocatesWhileSentenceAudioStateStreamStillOpen() async throws {
        let stream = OpenEndedSentenceAudioStateStream()
        var store: LearningContentStore? = LearningContentStore(
            repository: InMemoryLearningContentRepository(seedEntries: []),
            spaceID: "space-1",
            sentenceAudioPlaybackActions: SentenceAudioPlaybackActions(
                handleTap: { request in
                    .playing(SentenceAudioKey(
                        sentenceSource: request.sentenceSource,
                        sentenceTextHash: "hash",
                        targetLanguageCode: request.targetLanguageCode,
                        configurationFingerprint: "fingerprint"
                    ))
                },
                presentationState: { _ in .idle },
                stateUpdates: { _ in
                    stream.stream()
                }
            )
        )
        weak var weakStore = store
        let entry = try #require(try store?.createEntry(title: "Walk", body: "I walked home.", source: .typedText))
        let rendering = try #require(store?.generateLocalPreview(for: entry))
        let sentence = try #require(rendering.sentences.first)

        await store?.handleSentenceAudioTap(
            rendering: rendering,
            sentence: sentence,
            sentenceIndex: 0,
            languageSpace: sampleLanguageSpace(id: "space-1")
        )
        #expect(store?.sentenceAudioPlaybackState(for: sentence.id).activeKey != nil)

        store = nil
        let didDeallocate = await waitUntilOwnership {
            weakStore == nil
        }

        #expect(didDeallocate)
    }

    private func sampleLanguageSpace(id: String = "en") -> LanguageSpacePreview {
        LanguageSpacePreview(
            id: id,
            name: "English",
            nativeLanguage: "zh-Hans",
            targetLanguage: "English",
            targetLanguageCode: "en",
            level: .b1
        )
    }
}

/// Holds the stream continuation alive without yielding so the stream never finishes on its own.
private final class OpenEndedSentenceAudioStateStream: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<SentenceAudioPresentationState>.Continuation?

    func stream() -> AsyncStream<SentenceAudioPresentationState> {
        AsyncStream { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }
    }
}

private actor LearningMaterialOperationGate {
    private var started = false
    private var released = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        if started {
            return
        }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func waitUntilReleased() async {
        started = true
        startContinuations.forEach { $0.resume() }
        startContinuations.removeAll()
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseContinuations.append(continuation)
        }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private actor BlockedOperationCategoryRecorder {
    private var values: [LearningMaterialGenerationFailureCategory] = []

    var categories: [LearningMaterialGenerationFailureCategory] {
        values
    }

    func record(_ category: LearningMaterialGenerationFailureCategory) {
        values.append(category)
    }
}

private actor LearningTextUpdateCallCounter {
    private var callCount = 0

    var value: Int {
        callCount
    }

    func increment() {
        callCount += 1
    }
}

private final class OwnershipOperationIDSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [DiagnosticOperationID]

    init(_ values: [DiagnosticOperationID]) {
        self.values = values
    }

    func next() -> DiagnosticOperationID {
        lock.lock()
        defer { lock.unlock() }
        if values.isEmpty {
            return DiagnosticOperationID(rawValue: "operation-fallback")
        }
        return values.removeFirst()
    }
}

@MainActor
private func waitUntilOwnership(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + .nanoseconds(Int(timeoutNanoseconds))
    while !condition(), ContinuousClock.now < deadline {
        await Task.yield()
    }
    return condition()
}
