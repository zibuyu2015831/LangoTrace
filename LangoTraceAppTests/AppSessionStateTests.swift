import Foundation
@testable import LangoTrace
import LangoTraceCore
import LangoTraceData
import LangoTraceUI
import XCTest

@MainActor
final class AppSessionStateTests: XCTestCase {
    func testRestoreLanguageSpacePopulatesSpacesAndCurrentSelection() {
        let repository = InMemoryLanguageSpaceRepository(
            spaces: [makeLanguageSpace(id: "space-1")],
            currentSpaceID: "space-1"
        )
        let session = AppSessionState(languageSpaceRepositoryFactory: { repository })

        session.restoreLanguageSpace()

        XCTAssertEqual(session.recoveryState, .restored)
        XCTAssertEqual(session.currentLanguageSpace?.id, "space-1")
        XCTAssertEqual(session.languageSpaces.map(\.id), ["space-1"])
    }

    func testRestoreLanguageSpaceFailureClearsStateAndMarksFailed() {
        let session = AppSessionState(languageSpaceRepositoryFactory: {
            throw LanguageSpaceError.storageUnavailable
        })

        session.restoreLanguageSpace()

        XCTAssertEqual(session.recoveryState, .failed)
        XCTAssertNil(session.currentLanguageSpace)
        XCTAssertTrue(session.languageSpaces.isEmpty)
    }

    func testCompleteWelcomeRoutesToOnboardingWhenIdleWithoutLanguageSpace() {
        let session = AppSessionState(languageSpaceRepositoryFactory: {
            InMemoryLanguageSpaceRepository()
        })

        XCTAssertEqual(session.recoveryState, .idle)
        session.completeWelcome()

        XCTAssertEqual(session.phase, .onboarding)
    }

    func testCompleteWelcomeRoutesToMainWhenRestoredWithLanguageSpace() {
        let repository = InMemoryLanguageSpaceRepository(
            spaces: [makeLanguageSpace(id: "space-1")],
            currentSpaceID: "space-1"
        )
        let session = AppSessionState(languageSpaceRepositoryFactory: { repository })

        session.restoreLanguageSpace()
        XCTAssertEqual(session.recoveryState, .restored)
        session.completeWelcome()

        XCTAssertEqual(session.phase, .main)
    }

    func testCompleteWelcomeKeepsWelcomePhaseAfterFailedRestore() {
        let session = AppSessionState(languageSpaceRepositoryFactory: {
            throw LanguageSpaceError.storageUnavailable
        })

        session.restoreLanguageSpace()
        XCTAssertEqual(session.recoveryState, .failed)
        session.completeWelcome()

        XCTAssertEqual(session.phase, .welcome)
    }

    func testRetryAfterFailedRestoreSucceedsWhenStorageRecovers() {
        let factory = FlakyRepositoryFactory(
            failuresBeforeSuccess: 1,
            repository: InMemoryLanguageSpaceRepository(
                spaces: [makeLanguageSpace(id: "space-1")],
                currentSpaceID: "space-1"
            )
        )
        let session = AppSessionState(languageSpaceRepositoryFactory: { try factory.make() })

        session.restoreLanguageSpace()
        XCTAssertEqual(session.recoveryState, .failed)
        XCTAssertNil(session.currentLanguageSpace)

        // The welcome screen retry button re-runs the same restore entry point.
        session.restoreLanguageSpace()

        XCTAssertEqual(session.recoveryState, .restored)
        XCTAssertEqual(session.currentLanguageSpace?.id, "space-1")
        session.completeWelcome()
        XCTAssertEqual(session.phase, .main)
    }

    func testCreateLanguageSpaceWithValidDraftRoutesToMainWithoutRecoveryFailure() {
        let session = AppSessionState(languageSpaceRepositoryFactory: {
            InMemoryLanguageSpaceRepository()
        })
        session.restoreLanguageSpace()
        session.completeWelcome()
        XCTAssertEqual(session.phase, .onboarding)

        session.createLanguageSpace()

        XCTAssertEqual(session.phase, .main)
        XCTAssertNotNil(session.currentLanguageSpace)
        XCTAssertEqual(session.recoveryState, .restored)
    }

    func testCreateLanguageSpaceStorageFailureMarksRecoveryFailedNotDraftFailure() {
        let session = AppSessionState(languageSpaceRepositoryFactory: {
            throw LanguageSpaceError.storageUnavailable
        })

        session.createLanguageSpace()

        // Storage failure (not draft validation) is what marks recovery as failed.
        XCTAssertEqual(session.recoveryState, .failed)
        XCTAssertNil(session.currentLanguageSpace)
    }

    func testDeletingLastLanguageSpaceFallsBackToOnboarding() {
        let repository = InMemoryLanguageSpaceRepository(
            spaces: [makeLanguageSpace(id: "space-1")],
            currentSpaceID: "space-1"
        )
        let session = AppSessionState(languageSpaceRepositoryFactory: { repository })
        session.restoreLanguageSpace()
        session.completeWelcome()
        XCTAssertEqual(session.phase, .main)

        session.deleteLanguageSpace(id: "space-1")

        XCTAssertEqual(session.phase, .onboarding)
        XCTAssertNil(session.currentLanguageSpace)
        XCTAssertTrue(session.languageSpaces.isEmpty)
        XCTAssertEqual(session.recoveryState, .restored)
    }
}

private func makeLanguageSpace(id: String, displayName: String = "English") -> LanguageSpace {
    LanguageSpace(
        id: id,
        nativeLanguageCode: "zh-Hans",
        targetLanguageCode: "en",
        level: .b1,
        displayName: displayName,
        displayNameNormalized: CreateLanguageSpaceInput.normalizedDisplayName(displayName),
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        lastOpenedAt: nil,
        deletedAt: nil
    )
}

private final class FlakyRepositoryFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var remainingFailures: Int
    private let repository: InMemoryLanguageSpaceRepository

    init(failuresBeforeSuccess: Int, repository: InMemoryLanguageSpaceRepository) {
        remainingFailures = failuresBeforeSuccess
        self.repository = repository
    }

    func make() throws -> any LanguageSpaceRepository {
        lock.lock()
        defer { lock.unlock() }
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw LanguageSpaceError.storageUnavailable
        }
        return repository
    }
}

private final class InMemoryLanguageSpaceRepository: LanguageSpaceRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var spaces: [LanguageSpace]
    private var currentSpaceID: String?

    init(spaces: [LanguageSpace] = [], currentSpaceID: String? = nil) {
        self.spaces = spaces
        self.currentSpaceID = currentSpaceID
    }

    func listActiveLanguageSpaces() throws -> [LanguageSpace] {
        lock.lock()
        defer { lock.unlock() }
        return spaces.filter(\.isActive)
    }

    func languageSpace(id: String) throws -> LanguageSpace? {
        lock.lock()
        defer { lock.unlock() }
        return spaces.first { $0.id == id }
    }

    func currentLanguageSpace() throws -> LanguageSpace? {
        lock.lock()
        defer { lock.unlock() }
        return spaces.first { $0.id == currentSpaceID && $0.isActive }
    }

    func createLanguageSpace(input: CreateLanguageSpaceInput) throws -> LanguageSpace {
        lock.lock()
        defer { lock.unlock() }
        let normalized = try input.validated()
        let space = LanguageSpace(
            id: UUID().uuidString,
            nativeLanguageCode: normalized.nativeLanguageCode,
            targetLanguageCode: normalized.targetLanguageCode,
            level: normalized.level,
            displayName: normalized.displayName,
            displayNameNormalized: normalized.displayNameNormalized,
            createdAt: Date(),
            updatedAt: Date(),
            lastOpenedAt: nil,
            deletedAt: nil
        )
        spaces.append(space)
        currentSpaceID = space.id
        return space
    }

    func updateLanguageSpace(id: String, input: UpdateLanguageSpaceInput) throws -> LanguageSpace {
        lock.lock()
        defer { lock.unlock() }
        guard let index = spaces.firstIndex(where: { $0.id == id }) else {
            throw LanguageSpaceError.notFound
        }
        let normalized = try input.validated()
        let existing = spaces[index]
        let updated = LanguageSpace(
            id: existing.id,
            nativeLanguageCode: normalized.nativeLanguageCode,
            targetLanguageCode: normalized.targetLanguageCode,
            level: normalized.level,
            displayName: normalized.displayName,
            displayNameNormalized: normalized.displayNameNormalized,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            lastOpenedAt: existing.lastOpenedAt,
            deletedAt: existing.deletedAt
        )
        spaces[index] = updated
        return updated
    }

    func selectCurrentLanguageSpace(id: String) throws -> LanguageSpace {
        lock.lock()
        defer { lock.unlock() }
        guard let space = spaces.first(where: { $0.id == id && $0.isActive }) else {
            throw LanguageSpaceError.notFound
        }
        currentSpaceID = id
        return space
    }

    func deleteLanguageSpace(id: String) throws -> LanguageSpaceDeletionResult {
        lock.lock()
        defer { lock.unlock() }
        guard spaces.contains(where: { $0.id == id }) else {
            throw LanguageSpaceError.notFound
        }
        spaces.removeAll { $0.id == id }
        let remainingActive = spaces.filter(\.isActive)
        let fallback = remainingActive.first
        currentSpaceID = fallback?.id
        return LanguageSpaceDeletionResult(
            deletedSpaceID: id,
            fallbackCurrentSpace: fallback,
            remainingActiveCount: remainingActive.count
        )
    }

    func duplicateNameExists(displayName _: String, excludingID _: String?) throws -> Bool {
        false
    }
}
