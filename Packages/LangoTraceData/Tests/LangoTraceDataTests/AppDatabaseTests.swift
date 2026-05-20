import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("AppDatabase in-memory factory owns language space migrations")
func appDatabaseInMemoryFactoryOwnsLanguageSpaceMigrations() throws {
    let clock = FixedClock(epochSeconds: 100)
    let database = try AppDatabase.inMemory()
    let repository = GRDBLanguageSpaceRepository(
        database: database,
        clock: clock.now,
        idGenerator: { "space-1" }
    )

    let created = try repository.createLanguageSpace(
        input: CreateLanguageSpaceInput(
            nativeLanguageCode: "zh-Hans",
            targetLanguageCode: "en",
            level: .a2,
            displayName: "English"
        )
    )

    #expect(created.id == "space-1")
    #expect(try repository.currentLanguageSpace()?.id == "space-1")
}

@Test("AppDatabase persistent factory creates the parent directory")
func appDatabasePersistentFactoryCreatesParentDirectory() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent("LangoTrace.sqlite")

    _ = try AppDatabase.persistent(at: databaseURL)

    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
        atPath: databaseURL.deletingLastPathComponent().path,
        isDirectory: &isDirectory
    )
    #expect(exists)
    #expect(isDirectory.boolValue)
}

private final class FixedClock: @unchecked Sendable {
    private let epochSeconds: TimeInterval

    init(epochSeconds: TimeInterval) {
        self.epochSeconds = epochSeconds
    }

    func now() -> Date {
        Date(timeIntervalSince1970: epochSeconds)
    }
}
