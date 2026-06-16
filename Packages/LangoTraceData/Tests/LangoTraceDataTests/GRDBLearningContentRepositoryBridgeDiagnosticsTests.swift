import Foundation
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Bridge read path diagnostics")
struct GRDBLearningContentRepositoryBridgeDiagnosticsTests {
    @Test("entries read failure emits diagnostic event")
    func entriesReadFailureEmitsDiagnosticEvent() async throws {
        let repository = FailingReadLearningContentRepository()
        let logger = InMemoryDiagnosticLogger()
        let bridge = GRDBLearningContentRepositoryBridge(
            repository: repository,
            diagnosticLogger: logger,
            clock: { Date(timeIntervalSince1970: 100) }
        )

        let result = bridge.entries(for: "space-1")

        #expect(result.isEmpty)

        // Allow fire-and-forget Task to complete
        try await Task.sleep(for: .milliseconds(50))

        let events = await logger.events()
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.name == .learningContentRepositoryReadFailed)
        #expect(event.domain == .dataStorage)
        #expect(event.level == .warning)
        #expect(event.outcome == .failed)
        #expect(event.createdAt == Date(timeIntervalSince1970: 100))
        let opAttr = event.attributes.first { $0.key == "repository_read_operation" }
        #expect(opAttr?.valueDescription == "entries")
    }

    @Test("practiceItems read failure emits diagnostic event")
    func practiceItemsReadFailureEmitsDiagnosticEvent() async throws {
        let repository = FailingReadLearningContentRepository()
        let logger = InMemoryDiagnosticLogger()
        let bridge = GRDBLearningContentRepositoryBridge(
            repository: repository,
            diagnosticLogger: logger,
            clock: { Date(timeIntervalSince1970: 100) }
        )

        let result = bridge.practiceItems(for: "entry-1")

        #expect(result.isEmpty)

        try await Task.sleep(for: .milliseconds(50))

        let events = await logger.events()
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.name == .learningContentRepositoryReadFailed)
        let opAttr = event.attributes.first { $0.key == "repository_read_operation" }
        #expect(opAttr?.valueDescription == "practiceItems")
    }

    @Test("memoryItems read failure emits diagnostic event")
    func memoryItemsReadFailureEmitsDiagnosticEvent() async throws {
        let repository = FailingReadLearningContentRepository()
        let logger = InMemoryDiagnosticLogger()
        let bridge = GRDBLearningContentRepositoryBridge(
            repository: repository,
            diagnosticLogger: logger,
            clock: { Date(timeIntervalSince1970: 100) }
        )

        let result = bridge.memoryItems(for: "space-1")

        #expect(result.isEmpty)

        try await Task.sleep(for: .milliseconds(50))

        let events = await logger.events()
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.name == .learningContentRepositoryReadFailed)
        let opAttr = event.attributes.first { $0.key == "repository_read_operation" }
        #expect(opAttr?.valueDescription == "memoryItems")
    }

    @Test("successful reads do not emit diagnostic events")
    func successfulReadsDoNotEmitDiagnosticEvents() async throws {
        let database = try AppDatabase.inMemory()
        try await database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO language_spaces (
                    id, native_language_code, target_language_code, level,
                    display_name, display_name_normalized, created_at, updated_at,
                    last_opened_at, deleted_at
                ) VALUES ('space-1', 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
                """
            )
        }
        let repository = GRDBLearningContentRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 100) },
            idGenerator: { "generated-1" }
        )
        let logger = InMemoryDiagnosticLogger()
        let bridge = GRDBLearningContentRepositoryBridge(
            repository: repository,
            diagnosticLogger: logger,
            clock: { Date(timeIntervalSince1970: 100) }
        )

        // Successful reads
        _ = bridge.entries(for: "space-1")
        _ = bridge.practiceItems(for: "entry-1")
        _ = bridge.memoryItems(for: "space-1")

        try await Task.sleep(for: .milliseconds(50))

        let events = await logger.events()
        #expect(events.isEmpty)
    }

    @Test("disabled logger does not affect bridge behavior")
    func disabledLoggerDoesNotAffectBridgeBehavior() {
        let repository = FailingReadLearningContentRepository()
        let bridge = GRDBLearningContentRepositoryBridge(
            repository: repository,
            diagnosticLogger: DisabledDiagnosticLogger(),
            clock: { Date(timeIntervalSince1970: 100) }
        )

        // Should still return empty arrays gracefully
        #expect(bridge.entries(for: "space-1").isEmpty)
        #expect(bridge.practiceItems(for: "entry-1").isEmpty)
        #expect(bridge.memoryItems(for: "space-1").isEmpty)
    }
}

/// A repository that throws on read operations,
/// allowing the bridge to exercise its error-capture path.
private struct FailingReadLearningContentRepository: GRDBLearningContentRepositoryProtocol {
    func entries(for _: String) throws -> [LearningEntry] {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func practiceItems(for _: String) throws -> [PracticeItem] {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func memoryItems(for _: String) throws -> [MemoryItem] {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func currentMaterial(for _: String) throws -> LearningMaterial? {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func createEntry(_: NewLearningEntryDraft, in _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func updateEntryBody(entryID _: String, spaceID _: String, body _: String) throws -> LearningEntry {
        throw LearningContentRepositoryError.databaseUnavailable
    }

    func learningPracticeReadiness(for _: String) throws -> [String: Bool] {
        throw LearningContentRepositoryError.databaseUnavailable
    }
}
