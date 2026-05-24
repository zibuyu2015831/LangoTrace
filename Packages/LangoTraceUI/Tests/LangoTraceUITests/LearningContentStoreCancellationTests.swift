import Foundation
import LangoTraceCore
import LangoTraceData
@testable import LangoTraceUI
import Testing

@Suite("Learning content store cancellation")
@MainActor
struct LearningContentStoreCancellationTests {
    @Test("Store cancellation propagates to running generation task")
    func storeCancellationPropagatesToRunningGenerationTask() async throws {
        let gate = LearningMaterialGenerationCancellationGate()
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                let outcome = await gate.waitUntilCancelledOrReleased()
                if outcome == .cancelled {
                    return .failed(.cancelled)
                }
                return .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            cancelOperation: { operationID, _, _, _, _ in
                await gate.recordCancelled(operationID)
            },
            operationIDGenerator: { DiagnosticOperationID(rawValue: "operation-cancel-task") }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)

        let task = Task {
            await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.cancelLearningMaterialGeneration(for: entry)
        await task.value

        let observedCancellation = await gate.observedCancellation
        #expect(observedCancellation)
        #expect(await gate.cancelledOperations == [DiagnosticOperationID(rawValue: "operation-cancel-task")])
        #expect(store.generationState(for: entry) == LearningMaterialGenerationState.cancelled(materialID: nil))
    }

    @Test("Store cancellation propagates to running analysis task")
    func storeCancellationPropagatesToRunningAnalysisTask() async throws {
        let gate = LearningMaterialGenerationCancellationGate()
        let operationIDs = OperationIDSequence([
            DiagnosticOperationID(rawValue: "operation-generate-before-analysis"),
            DiagnosticOperationID(rawValue: "operation-cancel-analysis"),
        ])
        let repository = InMemoryLearningContentRepository(seedEntries: [])
        let actions = LearningMaterialGenerationActions(
            generateMaterial: { input, operationID, _ in
                .generated(sampleLearningMaterial(entryID: input.entryID, operationID: operationID))
            },
            analyzeCurrentText: { _, _, _ in
                let outcome = await gate.waitUntilCancelledOrReleased()
                return outcome == .cancelled ? .failed(.cancelled) : .failed(.unknown)
            },
            cancelOperation: { operationID, _, _, _, _ in
                await gate.recordCancelled(operationID)
            },
            operationIDGenerator: { operationIDs.next() }
        )
        let store = LearningContentStore(repository: repository, spaceID: "en", generationActions: actions)
        let entry = try store.createEntry(title: "Cafe", body: "今天我去咖啡馆。", source: .typedText)
        await store.generateLearningMaterial(for: entry, languageSpace: sampleLanguageSpace())

        let task = Task {
            await store.analyzeCurrentLearningText(for: entry, languageSpace: sampleLanguageSpace())
        }
        await gate.waitUntilStarted()

        await store.cancelLearningMaterialGeneration(for: entry)
        await task.value

        let observedCancellation = await gate.observedCancellation
        #expect(observedCancellation)
        #expect(await gate.cancelledOperations == [DiagnosticOperationID(rawValue: "operation-cancel-analysis")])
        #expect(store.generationState(for: entry)
            == LearningMaterialGenerationState.cancelled(materialID: "material-operation-generate-before-analysis"))
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

private enum LearningMaterialGenerationCancellationOutcome {
    case cancelled
    case released
}

private actor LearningMaterialGenerationCancellationGate {
    private var started = false
    private var didObserveCancellation = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var cancellations: [DiagnosticOperationID] = []

    var cancelledOperations: [DiagnosticOperationID] {
        cancellations
    }

    var observedCancellation: Bool {
        didObserveCancellation
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func waitUntilCancelledOrReleased() async -> LearningMaterialGenerationCancellationOutcome {
        started = true
        startContinuations.forEach { $0.resume() }
        startContinuations.removeAll()
        let deadline = ContinuousClock.now + .milliseconds(500)
        while ContinuousClock.now < deadline {
            if Task.isCancelled {
                didObserveCancellation = true
                return .cancelled
            }
            await Task.yield()
        }
        return .released
    }

    func recordCancelled(_ operationID: DiagnosticOperationID) {
        cancellations.append(operationID)
    }
}

private final class OperationIDSequence: @unchecked Sendable {
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
