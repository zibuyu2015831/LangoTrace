import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

extension MediaArtifactRepositoryTests {
    @Test("Repository reserves and looks up ready practice recording artifacts by key")
    func repositoryReservesAndLooksUpReadyPracticeRecordingArtifactsByKey() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSession(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.practiceRecordingCommitInput()

        let reserved = try await repository.reservePracticeRecordingArtifact(input).artifact
        let pendingLookup = try await repository.practiceRecordingArtifactMetadata(for: input.key)
        try await repository.markArtifactFileReady(artifactID: reserved.id, at: Date(timeIntervalSince1970: 450))
        let readyLookup = try await repository.practiceRecordingArtifactMetadata(for: input.key)

        #expect(reserved.type == .shadowingRecording)
        #expect(reserved.derivationKind == .practiceRecording)
        #expect(pendingLookup == .miss)
        guard case let .hit(ready) = readyLookup else {
            Issue.record("Expected ready practice recording artifact to become visible")
            return
        }
        #expect(ready.id == reserved.id)
    }

    @Test("Resaving provider profile invalidates dependent TTS artifacts and allows same-key re-reservation")
    func resavingProviderProfileInvalidatesDependentTTSArtifactsAndAllowsReReservation() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.commitInput()
        _ = try await repository.commitTTSAudioArtifact(input)

        let aiRepository = GRDBAIProviderConfigurationRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 600) }
        )
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "tts-1",
            voiceID: "alloy",
            outputFormat: .mp3,
            lastSuccessfulConfigurationFingerprint: "fingerprint-1",
            lastTestStatus: .succeeded
        )
        try await aiRepository.saveProfile(
            MediaArtifactTestFixtures.profileWithTTSEndpoint(),
            ttsSettings: TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            ttsVoiceProfiles: [voice]
        )

        let invalidatedCount = try await database.databaseQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM media_artifacts WHERE invalidated_at IS NOT NULL"
            ) ?? -1
        }
        let lookup = try await repository.ttsAudioArtifactMetadata(for: input.key)
        let reservation = try await repository.reserveTTSAudioArtifact(input)

        #expect(invalidatedCount == 1)
        #expect(lookup == .miss)
        #expect(reservation.wasCreated)
    }

    @Test("Repository cleanup protects recent pending reservations from selection")
    func repositoryCleanupProtectsRecentPendingReservations() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        _ = try await repository.reserveTTSAudioArtifact(MediaArtifactTestFixtures.commitInput())

        let recentCleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 500),
                targetMaximumBytes: 0
            )
        )
        let staleCleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 400 + 7200),
                targetMaximumBytes: 0
            )
        )

        #expect(recentCleanup.isEmpty)
        #expect(staleCleanup.count == 1)
    }

    @Test("Marking a missing artifact file ready fails instead of silently succeeding")
    func markingMissingArtifactFileReadyFails() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )

        await #expect(throws: MediaArtifactRepositoryError.fileReadyUpdateFailed) {
            try await repository.markArtifactFileReady(
                artifactID: "missing-artifact",
                at: Date(timeIntervalSince1970: 450)
            )
        }
    }

    @Test("Repository cleanup does not select artifacts referenced by uncompleted session recordings")
    func repositoryCleanupDoesNotSelectArtifactsReferencedByUncompletedSessionRecordings() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSession(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        _ = try await repository.commitPracticeRecordingArtifact(
            MediaArtifactTestFixtures.practiceRecordingCommitInput()
        )

        let cleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .shadowingRecording,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 800),
                targetMaximumBytes: 0
            )
        )

        #expect(cleanup.isEmpty)
    }

    @Test("Repository cleanup does not select completed practice recording artifacts")
    func repositoryCleanupDoesNotSelectCompletedPracticeRecordingArtifacts() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        try await MediaArtifactTestFixtures.seedPracticeSession(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.practiceRecordingCommitInput()

        let artifact = try await repository.commitPracticeRecordingArtifact(input)
        try await MediaArtifactTestFixtures.seedReadyPracticeRecording(
            artifactID: artifact.id,
            in: database
        )

        let cleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .shadowingRecording,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 800),
                targetMaximumBytes: 0
            )
        )

        #expect(cleanup.isEmpty)
    }
}
