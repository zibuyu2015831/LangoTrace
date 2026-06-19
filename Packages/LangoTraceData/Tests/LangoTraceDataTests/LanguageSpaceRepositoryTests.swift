import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("Repository allows duplicate target languages and duplicate display names")
func repositoryAllowsDuplicateTargetLanguagesAndNames() throws {
    let clock = TestClock(epochSeconds: 1000)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let first = try repository.createLanguageSpace(input: englishInput(name: "英语空间"))
    clock.advance(to: 1010)
    let second = try repository.createLanguageSpace(input: englishInput(name: "英语空间"))

    let spaces = try repository.listActiveLanguageSpaces()
    let spaceIDs = spaces.map(\.id)
    let targetLanguageCodes = Set(spaces.map(\.targetLanguageCode))
    #expect(spaceIDs == [second.id, first.id])
    #expect(targetLanguageCodes == ["en"])
    #expect(try repository.duplicateNameExists(displayName: " 英语空间 ", excludingID: String?.none))
    let duplicateExcludingSecond = try repository.duplicateNameExists(displayName: " 英语空间 ", excludingID: second.id)
    #expect(duplicateExcludingSecond)
}

@Test("Repository stores current language space as local app state")
func repositoryStoresCurrentLanguageSpaceAsLocalAppState() throws {
    let clock = TestClock(epochSeconds: 2000)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let first = try repository.createLanguageSpace(input: englishInput(name: "English A"))
    clock.advance(to: 2010)
    let second = try repository.createLanguageSpace(input: englishInput(name: "English B"))
    clock.advance(to: 2020)
    let selected = try repository.selectCurrentLanguageSpace(id: first.id)

    #expect(second.targetLanguageCode == first.targetLanguageCode)
    #expect(selected.id == first.id)
    #expect(try repository.currentLanguageSpace()?.id == first.id)
}

@Test("Deleting current language space falls back to the most recently opened active space")
func deletingCurrentLanguageSpaceFallsBackToMostRecentlyOpenedActiveSpace() throws {
    let clock = TestClock(epochSeconds: 3000)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let first = try repository.createLanguageSpace(input: englishInput(name: "English A"))
    clock.advance(to: 3010)
    let second = try repository.createLanguageSpace(input: englishInput(name: "English B"))
    clock.advance(to: 3020)
    _ = try repository.selectCurrentLanguageSpace(id: first.id)

    clock.advance(to: 3030)
    let result = try repository.deleteLanguageSpace(id: first.id)

    #expect(result.deletedSpaceID == first.id)
    #expect(result.fallbackCurrentSpace?.id == second.id)
    #expect(result.remainingActiveCount == 1)
    #expect(try repository.currentLanguageSpace()?.id == second.id)
    let activeIDs = try repository.listActiveLanguageSpaces().map(\.id)
    #expect(activeIDs == [second.id])
}

@Test("Deleting final language space clears current state and hides soft deleted spaces")
func deletingFinalLanguageSpaceClearsCurrentState() throws {
    let clock = TestClock(epochSeconds: 4000)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let space = try repository.createLanguageSpace(input: englishInput(name: "English"))

    clock.advance(to: 4010)
    let result = try repository.deleteLanguageSpace(id: space.id)

    #expect(result.deletedSpaceID == space.id)
    #expect(result.fallbackCurrentSpace == nil)
    #expect(result.remainingActiveCount == 0)
    #expect(try repository.currentLanguageSpace() == nil)
    #expect(try repository.listActiveLanguageSpaces().isEmpty)
    let duplicateAfterDelete = try repository.duplicateNameExists(displayName: "English", excludingID: String?.none)
    #expect(!duplicateAfterDelete)
}

@Test("Repository falls back and repairs current state when current id is missing")
func repositoryRepairsMissingCurrentLanguageSpaceID() throws {
    let clock = TestClock(epochSeconds: 4500)
    let databaseURL = temporaryDatabaseURL()
    let repository = try GRDBLanguageSpaceRepository.persistent(at: databaseURL, clock: clock.now)

    let first = try repository.createLanguageSpace(input: englishInput(name: "English A"))
    clock.advance(to: 4510)
    let second = try repository.createLanguageSpace(input: englishInput(name: "English B"))

    let databaseQueue = try DatabaseQueue(path: databaseURL.path)
    try databaseQueue.write { db in
        try db.execute(
            sql: """
            UPDATE app_state
            SET value = ?, updated_at = ?
            WHERE key = ?
            """,
            arguments: ["missing-space", 4520, "current_language_space_id"]
        )
    }

    clock.advance(to: 4530)
    let repairedCurrent = try repository.currentLanguageSpace()

    #expect(repairedCurrent?.id == second.id)
    #expect(try repository.currentLanguageSpace()?.id == second.id)
    #expect(first.id != second.id)
}

@Test("Repository rejects selecting or updating deleted language spaces")
func repositoryRejectsDeletedLanguageSpaceMutations() throws {
    let clock = TestClock(epochSeconds: 4600)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let space = try repository.createLanguageSpace(input: englishInput(name: "English"))
    _ = try repository.deleteLanguageSpace(id: space.id)

    #expect(throws: LanguageSpaceError.deleted) {
        try repository.selectCurrentLanguageSpace(id: space.id)
    }
    #expect(throws: LanguageSpaceError.deleted) {
        try repository.updateLanguageSpace(id: space.id, input: updateEnglishInput(name: "Renamed"))
    }
}

@Test("Repository uses injected UTC epoch seconds for timestamps")
func repositoryUsesInjectedEpochSecondsForTimestamps() throws {
    let clock = TestClock(epochSeconds: 5000)
    let repository = try GRDBLanguageSpaceRepository.inMemory(clock: clock.now)

    let created = try repository.createLanguageSpace(input: englishInput(name: "English"))
    clock.advance(to: 5100)
    let updated = try repository.updateLanguageSpace(
        id: created.id,
        input: updateEnglishInput(name: "Updated English")
    )

    #expect(created.createdAt.timeIntervalSince1970 == 5000)
    #expect(created.updatedAt.timeIntervalSince1970 == 5000)
    #expect(created.lastOpenedAt?.timeIntervalSince1970 == 5000)
    #expect(updated.createdAt.timeIntervalSince1970 == 5000)
    #expect(updated.updatedAt.timeIntervalSince1970 == 5100)
}

@Test("Database location uses Application Support LangoTrace directory")
func databaseLocationUsesApplicationSupportDirectory() throws {
    let fileManager = FileManager.default

    let databaseURL = try LanguageSpaceDatabaseLocation.defaultDatabaseURL(fileManager: fileManager)

    #expect(databaseURL.lastPathComponent == "LangoTrace.sqlite")
    #expect(databaseURL.deletingLastPathComponent().lastPathComponent == "LangoTrace")
    #expect(databaseURL.path.contains("Application Support"))
}

private func englishInput(name: String) -> CreateLanguageSpaceInput {
    CreateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        displayName: name
    )
}

private func updateEnglishInput(name: String) -> UpdateLanguageSpaceInput {
    UpdateLanguageSpaceInput(
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        displayName: name
    )
}

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("LangoTrace.sqlite")
}

private final class TestClock: @unchecked Sendable {
    private var epochSeconds: TimeInterval

    init(epochSeconds: TimeInterval) {
        self.epochSeconds = epochSeconds
    }

    func now() -> Date {
        Date(timeIntervalSince1970: epochSeconds)
    }

    func advance(to epochSeconds: TimeInterval) {
        self.epochSeconds = epochSeconds
    }
}
