import Foundation
import GRDB
import LangoTraceData
@testable import LangoTraceLearnerModel
import Testing

/// Covers the `LearnerContextProvider.memoryFacts(visibility:)` read seam: `nil`
/// returns all active facts (governance / overview), a non-nil value filters to
/// that visibility (future companion consumption), and soft-deleted facts are
/// excluded.
@Suite("Learner context provider memory facts")
struct LearnerContextProviderMemoryFactsTests {
    private func makeStack() throws -> (GRDBLearnerContextProvider, GRDBLearnerMemoryRepository) {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(databaseQueue: queue)
        return (
            GRDBLearnerContextProvider(reader: database.reader),
            GRDBLearnerMemoryRepository(writer: database.writer)
        )
    }

    @Test("nil visibility returns all active facts; filter narrows to a visibility")
    func visibilityFilterNarrowsResults() throws {
        let (provider, repository) = try makeStack()
        try repository.save(MemoryFact(
            id: "g1", kind: .lifeFact, text: "a", visibility: .global,
            createdAt: Date(timeIntervalSince1970: 1)
        ))
        try repository.save(MemoryFact(
            id: "c1", kind: .preference, text: "b", visibility: .companionOnly,
            createdAt: Date(timeIntervalSince1970: 2)
        ))

        #expect(try provider.memoryFacts(visibility: nil).map(\.id) == ["g1", "c1"])
        #expect(try provider.memoryFacts(visibility: .global).map(\.id) == ["g1"])
        #expect(try provider.memoryFacts(visibility: .companionOnly).map(\.id) == ["c1"])
    }

    @Test("soft-deleted facts are excluded from the read seam")
    func softDeletedFactsExcluded() throws {
        let (provider, repository) = try makeStack()
        try repository.save(MemoryFact(id: "g1", kind: .lifeFact, text: "a"))
        try repository.softDelete(id: "g1")
        #expect(try provider.memoryFacts(visibility: nil).isEmpty)
    }
}
