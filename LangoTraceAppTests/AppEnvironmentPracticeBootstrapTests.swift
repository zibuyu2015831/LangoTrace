import CryptoKit
import Foundation
@testable import LangoTrace
import LangoTraceCore
import LangoTraceData
import LangoTraceSpeech
import LangoTraceUI
import XCTest

final class AppEnvironmentPracticeBootstrapTests: XCTestCase {
    func testBootstrapDoesNotFallBackToDisabledPracticeActions() async throws {
        let environment = AppEnvironment.bootstrap()
        let languageRepository = try environment.makeLanguageSpaceRepository()
        let languageSpace = try languageRepository.createLanguageSpace(
            input: CreateLanguageSpaceInput(
                nativeLanguageCode: "zh-Hans",
                targetLanguageCode: "en",
                level: .a1,
                displayName: "Bootstrap Practice Test \(UUID().uuidString)"
            )
        )
        do {
            _ = try await environment.practiceActions.createOrRestoreShadowingSession(
                languageSpace.id,
                PracticeSentenceSnapshot(
                    entryID: "missing-entry",
                    learningMaterialID: "missing-material",
                    sentenceID: "missing-sentence",
                    sentenceIndex: 0,
                    targetTextSnapshot: "I booked the train this morning.",
                    targetTextHash: String(repeating: "a", count: 64),
                    targetLanguageCode: "en",
                    translationSnapshot: "我今天早上订了火车票。",
                    noteSnapshot: nil,
                    sourceEntryBodyHash: nil,
                    materialAnalysisSourceHash: nil,
                    exerciseType: .shadowing,
                    capturedAt: Date(timeIntervalSince1970: 1)
                )
            )
            XCTFail("Practice actions unexpectedly used the disabled fallback.")
        } catch {
            XCTAssertFalse(String(describing: error).contains("disabled-"))
        }
    }

    func testDisabledPracticeActionsExposeRecordingPlaybackFailure() async {
        let actions = PracticeActions.disabled
        await XCTAssertThrowsErrorAsync {
            try await actions.playRecording(
                PracticeSession(
                    id: "session-1",
                    languageSpaceID: "space-1",
                    snapshot: PracticeSentenceSnapshot(
                        entryID: "entry-1",
                        learningMaterialID: "material-1",
                        sentenceID: "sentence-1",
                        sentenceIndex: 0,
                        targetTextSnapshot: "I booked the train this morning.",
                        targetTextHash: String(repeating: "a", count: 64),
                        targetLanguageCode: "en",
                        translationSnapshot: nil,
                        noteSnapshot: nil,
                        sourceEntryBodyHash: nil,
                        materialAnalysisSourceHash: nil,
                        exerciseType: .shadowing,
                        capturedAt: Date(timeIntervalSince1970: 1)
                    ),
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                "recording-1"
            )
        }
    }

    func testPracticeActionsAssemblyRefreshesSessionAfterRecordingStop() async throws {
        let database = try AppDatabase.inMemory()
        let material = try seedPracticeSessionPrerequisites(in: database)
        let mediaRoot = temporaryMediaRoot()
        let fileStore = try LocalMediaArtifactFileStore(rootDirectory: mediaRoot)
        let actions = try PracticeActionsAssembly.makeActions(
            database: database,
            mediaArtifactsRoot: mediaRoot,
            recordingEngine: FakeAppPracticeRecordingEngine(fileStore: fileStore)
        )
        let session = try await actions.createOrRestoreShadowingSession(
            "space-1",
            practiceSnapshot(entryID: material.entryID, materialID: material.id)
        )

        let start = try await actions.startRecording(session)
        let stopped = try await actions.stopRecording(start.session, start.recordingID)

        XCTAssertEqual(stopped.latestReadyRecordingID, start.recordingID)
    }

    func testPracticeActionsAssemblyRecordsFailureDiagnosticsWhenRecordingStopFails() async throws {
        let database = try AppDatabase.inMemory()
        let material = try seedPracticeSessionPrerequisites(in: database)
        let mediaRoot = temporaryMediaRoot()
        let logger = InMemoryDiagnosticLogger()
        let actions = try PracticeActionsAssembly.makeActions(
            database: database,
            mediaArtifactsRoot: mediaRoot,
            recordingEngine: FailingAppPracticeRecordingEngine(),
            diagnosticLogger: logger
        )
        let session = try await actions.createOrRestoreShadowingSession(
            "space-1",
            practiceSnapshot(entryID: material.entryID, materialID: material.id)
        )

        let start = try await actions.startRecording(session)
        do {
            _ = try await actions.stopRecording(start.session, start.recordingID)
            XCTFail("Expected stop recording to fail")
        } catch {}

        let events = await logger.events()
        let failureEvent = events.first { $0.name == .practiceRecordingFailed }
        XCTAssertEqual(failureEvent?.domain, .practiceRecording)
        XCTAssertEqual(failureEvent?.outcome, .failed)
        XCTAssertEqual(failureEvent?.attributes.contains(.failurePhase("recording_stop")), true)
        XCTAssertEqual(failureEvent?.attributes.contains(.errorCategory("stop_failed")), true)
        XCTAssertFalse(String(describing: events).contains("I booked the train this morning."))
        XCTAssertFalse(String(describing: events).contains(mediaRoot.path))
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> some Any,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {}
}

private actor FakeAppPracticeRecordingEngine: PracticeRecordingEngine {
    private let fileStore: LocalMediaArtifactFileStore
    private var activeRequest: PracticeRecordingStartRequest?

    init(fileStore: LocalMediaArtifactFileStore) {
        self.fileStore = fileStore
    }

    func requestPermission() async -> PracticeMicrophonePermission {
        .authorized
    }

    func start(_ request: PracticeRecordingStartRequest) async throws {
        activeRequest = request
        let url = try fileStore.absoluteURLForInternalUse(relativePath: request.stagingRelativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("recording".utf8).write(to: url)
    }

    func stop(recordingID: String) async throws -> PracticeRecordingEngineStopResult {
        guard let activeRequest, activeRequest.recordingID == recordingID else {
            throw PracticeRecordingFailure.noActiveRecording
        }
        let url = try fileStore.absoluteURLForInternalUse(relativePath: activeRequest.stagingRelativePath)
        let data = try Data(contentsOf: url)
        self.activeRequest = nil
        return PracticeRecordingEngineStopResult(
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: activeRequest.stagingRelativePath,
                byteSize: Int64(data.count),
                contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            ),
            durationSeconds: 1.2,
            byteSize: Int64(data.count),
            contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        )
    }

    func cancel(recordingID _: String) async {}
}

private actor FailingAppPracticeRecordingEngine: PracticeRecordingEngine {
    func requestPermission() async -> PracticeMicrophonePermission {
        .authorized
    }

    func start(_: PracticeRecordingStartRequest) async throws {}

    func stop(recordingID _: String) async throws -> PracticeRecordingEngineStopResult {
        throw PracticeRecordingFailure.stopFailed
    }

    func cancel(recordingID _: String) async {}
}

private func temporaryMediaRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("MediaArtifacts", isDirectory: true)
}

private func practiceSnapshot(entryID: String, materialID: String) -> PracticeSentenceSnapshot {
    PracticeSentenceSnapshot(
        entryID: entryID,
        learningMaterialID: materialID,
        sentenceID: "sentence-1",
        sentenceIndex: 0,
        targetTextSnapshot: "I booked the train this morning.",
        targetTextHash: "target-hash-1",
        targetLanguageCode: "en",
        translationSnapshot: "我今天早上订了火车票。",
        noteSnapshot: "booked 表示已经完成预订。",
        sourceEntryBodyHash: "source-hash",
        materialAnalysisSourceHash: "analysis-hash",
        exerciseType: .shadowing,
        capturedAt: Date(timeIntervalSince1970: 100)
    )
}

private func seedPracticeSessionPrerequisites(in database: AppDatabase) throws -> LearningMaterial {
    let languageRepository = GRDBLanguageSpaceRepository(
        database: database,
        clock: { Date(timeIntervalSince1970: 1) },
        idGenerator: { "space-1" }
    )
    _ = try languageRepository.createLanguageSpace(
        input: CreateLanguageSpaceInput(
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "en",
            level: .b1,
            displayName: "English"
        )
    )
    let ids = LockedIDGenerator(["entry-1", "material-1"])
    let contentRepository = GRDBLearningContentRepository(
        database: database,
        clock: { Date(timeIntervalSince1970: 2) },
        idGenerator: { ids.next() }
    )
    let entry = try contentRepository.createEntry(
        NewLearningEntryDraft(
            title: "Morning commute",
            body: "我今天早上订了火车票。",
            source: .typedText,
            scene: "生活记录"
        ),
        in: "space-1"
    )
    return try contentRepository.saveGeneratedMaterial(
        LearningMaterialGenerationResult(
            entryID: entry.id,
            spaceID: entry.spaceID,
            inputKind: .nativeRecord,
            promptMode: .automaticLearningMaterial,
            learningText: "I booked the train this morning.",
            revisionSummary: [],
            analysis: LearningMaterialAnalysis(
                status: .fresh,
                sourceTextHash: "analysis-hash",
                sentences: [
                    LearningSentenceAnalysis(
                        id: "sentence-1",
                        nativeSentence: "我今天早上订了火车票。",
                        targetSentence: "I booked the train this morning.",
                        literalTranslation: "I booked the train this morning.",
                        naturalTranslation: "我今天早上订了火车票。",
                        grammarNotes: [],
                        keyPoints: [],
                        position: 0
                    ),
                ],
                memoryCandidates: [],
                practiceCandidates: []
            ),
            metadata: LearningMaterialGenerationMetadata(
                promptID: "prompt",
                promptVersion: "1",
                providerProfileID: "profile-1",
                providerEndpointID: "endpoint-tts",
                providerPresetID: "openai",
                modelName: "gpt-4o-mini",
                generatedAt: Date(timeIntervalSince1970: 2)
            )
        ),
        for: entry.id
    )
}

private final class LockedIDGenerator: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String]

    init(_ ids: [String]) {
        self.ids = ids
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        guard !ids.isEmpty else {
            return UUID().uuidString
        }
        return ids.removeFirst()
    }
}
