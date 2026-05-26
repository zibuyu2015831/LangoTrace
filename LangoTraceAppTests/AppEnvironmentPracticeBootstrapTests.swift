@testable import LangoTrace
import LangoTraceCore
import LangoTraceData
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
