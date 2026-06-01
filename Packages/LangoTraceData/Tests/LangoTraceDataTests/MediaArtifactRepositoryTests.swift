import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Suite("Media artifact repository")
struct MediaArtifactRepositoryTests {
    @Test("Repository commits and hits TTS audio artifacts by derivation key")
    func repositoryCommitsAndHitsTTSAudioArtifactsByDerivationKey() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.commitInput()

        let artifact = try await repository.commitTTSAudioArtifact(input)
        let lookup = try await repository.ttsAudioArtifactMetadata(for: input.key)

        #expect(artifact.id == "artifact-1")
        #expect(artifact.policy == .defaultDerivedMediaPolicy)
        #expect(artifact.derivationKeyHash == input.key.derivationKeyHash)
        guard case let .hit(accessed) = lookup else {
            Issue.record("Expected repository hit after commit")
            return
        }
        #expect(accessed.id == artifact.id)
        #expect(accessed.lastAccessedAt == Date(timeIntervalSince1970: 500))
    }

    @Test("Repository returns existing active artifact for duplicate TTS key")
    func repositoryReturnsExistingActiveArtifactForDuplicateTTSKey() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.commitInput()

        let first = try await repository.commitTTSAudioArtifact(input)
        let second = try await repository.commitTTSAudioArtifact(input)

        #expect(second == first)
        #expect(try await MediaArtifactTestFixtures.mediaArtifactCount(in: database) == 1)
    }

    @Test("Repository hides pending artifact metadata from lookup until marked ready")
    func repositoryHidesPendingArtifactMetadataUntilReady() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.commitInput()

        let pending = try await repository.reserveTTSAudioArtifact(input).artifact
        let pendingLookup = try await repository.ttsAudioArtifactMetadata(for: input.key)
        try await repository.markArtifactFileReady(artifactID: pending.id, at: Date(timeIntervalSince1970: 450))
        let readyLookup = try await repository.ttsAudioArtifactMetadata(for: input.key)

        #expect(pendingLookup == .miss)
        guard case let .hit(ready) = readyLookup else {
            Issue.record("Expected ready artifact to become visible")
            return
        }
        #expect(ready.id == pending.id)
    }

    @Test("Repository treats changed TTS key fields as cache miss")
    func repositoryTreatsChangedTTSKeyFieldsAsMiss() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        _ = try await repository.commitTTSAudioArtifact(MediaArtifactTestFixtures.commitInput())

        let changedKey = MediaArtifactTestFixtures.key(modelName: "gpt-4o-mini-tts-v2")

        #expect(try await repository.ttsAudioArtifactMetadata(for: changedKey) == .miss)
    }

    @Test("Repository invalidates by owner provider endpoint and configuration")
    func repositoryInvalidatesByOwnerProviderEndpointAndConfiguration() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let input = MediaArtifactTestFixtures.commitInput()
        _ = try await repository.commitTTSAudioArtifact(input)

        try await repository.invalidateArtifacts(
            MediaArtifactInvalidationRequest(
                owner: input.owner,
                artifactType: .ttsSentenceAudio,
                providerProfileID: "profile-1",
                ttsEndpointID: "endpoint-tts",
                configurationFingerprint: "fingerprint-1",
                invalidatedAt: Date(timeIntervalSince1970: 600)
            )
        )

        #expect(
            try await repository.ttsAudioArtifactMetadata(for: input.key)
                == .invalidated(.explicitlyInvalidated)
        )
    }

    @Test("Repository can invalidate one artifact without invalidating sibling cache entries")
    func repositoryInvalidatesOneArtifactWithoutInvalidatingSiblings() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let firstInput = MediaArtifactTestFixtures.commitInput(
            key: MediaArtifactTestFixtures.key(sentenceTextHash: "sentence-hash-1")
        )
        let secondInput = MediaArtifactTestFixtures.commitInput(
            key: MediaArtifactTestFixtures.key(sentenceTextHash: "sentence-hash-2"),
            stagedFile: MediaArtifactStagedFileReference(
                relativeStagingPath: "staging/op-2.tmp",
                byteSize: 128,
                contentHash: "content-hash-2"
            )
        )
        let first = try await repository.commitTTSAudioArtifact(firstInput)
        let second = try await repository.commitTTSAudioArtifact(secondInput)
        try await repository.markArtifactFileReady(artifactID: first.id, at: Date(timeIntervalSince1970: 410))
        try await repository.markArtifactFileReady(artifactID: second.id, at: Date(timeIntervalSince1970: 420))

        try await repository.invalidateArtifact(artifactID: first.id, at: Date(timeIntervalSince1970: 600))

        #expect(
            try await repository.ttsAudioArtifactMetadata(for: firstInput.key)
                == .invalidated(.explicitlyInvalidated)
        )
        guard case let .hit(sibling) = try await repository.ttsAudioArtifactMetadata(for: secondInput.key) else {
            Issue.record("Expected sibling artifact to remain active")
            return
        }
        #expect(sibling.id == second.id)
    }

    @Test("Repository commits temporary TTS source without requiring an entry row")
    func repositoryCommitsTemporaryTTSSourceWithoutEntryForeignKey() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let key = MediaArtifactTestFixtures.key(sentenceSource: .temporary(operationID: "operation-1", sentenceIndex: 0))
        let input = MediaArtifactTestFixtures.commitInput(
            key: key,
            owner: .temporaryOperation(id: "operation-1")
        )

        let artifact = try await repository.commitTTSAudioArtifact(input)

        #expect(artifact.id == "artifact-1")
    }

    @Test("Repository commits reading document sentence TTS source with distinct owner columns")
    func repositoryCommitsReadingDocumentSentenceTTSSource() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let key = MediaArtifactTestFixtures.key(
            sentenceSource: .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1")
        )
        let input = MediaArtifactTestFixtures.commitInput(
            key: key,
            owner: .readingDocumentSentence(documentID: "doc-1", sentenceID: "sentence-1")
        )

        let artifact = try await repository.commitTTSAudioArtifact(input)
        let row = try await database.databaseQueue.read { db in
            try Row.fetchOne(
                db,
                sql: """
                SELECT media_artifacts.owner_type, media_artifacts.owner_id,
                       media_artifacts.owner_sub_id, tts_audio_artifacts.sentence_source_type,
                       tts_audio_artifacts.reading_document_id,
                       tts_audio_artifacts.reading_sentence_id
                FROM media_artifacts
                JOIN tts_audio_artifacts ON tts_audio_artifacts.artifact_id = media_artifacts.id
                WHERE media_artifacts.id = ?
                """,
                arguments: [artifact.id]
            )
        }

        #expect(row?["owner_type"] as String? == "readingDocumentSentence")
        #expect(row?["owner_id"] as String? == "doc-1")
        #expect(row?["owner_sub_id"] as String? == "sentence-1")
        #expect(row?["sentence_source_type"] as String? == "readingDocumentSentence")
        #expect(row?["reading_document_id"] as String? == "doc-1")
        #expect(row?["reading_sentence_id"] as String? == "sentence-1")
    }

    @Test("Repository maps supported TTS output formats to matching file extensions")
    func repositoryMapsSupportedTTSOutputFormatsToMatchingExtensions() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )

        let aac = try await repository.commitTTSAudioArtifact(
            MediaArtifactTestFixtures.commitInput(
                key: MediaArtifactTestFixtures.key(sentenceTextHash: "aac-hash", outputFormat: .aac)
            )
        )
        let opus = try await repository.commitTTSAudioArtifact(
            MediaArtifactTestFixtures.commitInput(
                key: MediaArtifactTestFixtures.key(sentenceTextHash: "opus-hash", outputFormat: .opus),
                stagedFile: MediaArtifactStagedFileReference(
                    relativeStagingPath: "staging/op-2.tmp",
                    byteSize: 128,
                    contentHash: "content-hash-2"
                )
            )
        )

        #expect(aac.relativeFilePath.hasSuffix(".aac"))
        #expect(opus.relativeFilePath.hasSuffix(".opus"))
    }

    @Test("Repository cleanup selects invalidated and oldest artifacts without touching files")
    func repositoryCleanupSelectsInvalidatedAndOldestArtifacts() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let first = try await repository.commitTTSAudioArtifact(MediaArtifactTestFixtures.commitInput())
        _ = try await repository.commitTTSAudioArtifact(
            MediaArtifactTestFixtures.commitInput(
                key: MediaArtifactTestFixtures.key(sentenceTextHash: "sentence-hash-2"),
                stagedFile: MediaArtifactStagedFileReference(
                    relativeStagingPath: "staging/op-2.tmp",
                    byteSize: 128,
                    contentHash: "content-hash-2"
                )
            )
        )
        try await repository.invalidateArtifacts(
            MediaArtifactInvalidationRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                invalidatedAt: Date(timeIntervalSince1970: 700)
            )
        )

        let cleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 800),
                targetMaximumBytes: nil
            )
        )
        try await repository.deleteArtifactMetadata(artifactIDs: [first.id])

        #expect(cleanup.count == 2)
        #expect(try await MediaArtifactTestFixtures.mediaArtifactCount(in: database) == 1)
    }

    @Test("Repository cleanup selects oldest active artifacts until scoped bytes fit capacity")
    func repositoryCleanupSelectsOldestActiveArtifactsForCapacity() async throws {
        let database = try AppDatabase.inMemory()
        try await MediaArtifactTestFixtures.seedPrerequisites(in: database)
        let repository = GRDBMediaArtifactRepository(
            database: database,
            clock: { Date(timeIntervalSince1970: 500) },
            idGenerator: MediaArtifactIDGenerator().next
        )
        let oldest = try await repository.commitTTSAudioArtifact(
            MediaArtifactTestFixtures.commitInput(
                stagedFile: MediaArtifactStagedFileReference(
                    relativeStagingPath: "staging/op-1.tmp",
                    byteSize: 70,
                    contentHash: "content-hash-1"
                )
            )
        )
        _ = try await repository.commitTTSAudioArtifact(
            MediaArtifactTestFixtures.commitInput(
                key: MediaArtifactTestFixtures.key(sentenceTextHash: "sentence-hash-2"),
                stagedFile: MediaArtifactStagedFileReference(
                    relativeStagingPath: "staging/op-2.tmp",
                    byteSize: 40,
                    contentHash: "content-hash-2"
                )
            )
        )

        let cleanup = try await repository.artifactsForCleanup(
            MediaArtifactCleanupRequest(
                languageSpaceID: "space-1",
                artifactType: .ttsSentenceAudio,
                includeInvalidated: true,
                now: Date(timeIntervalSince1970: 800),
                targetMaximumBytes: 40
            )
        )

        #expect(cleanup.map(\.id) == [oldest.id])
    }

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

final class MediaArtifactIDGenerator: @unchecked Sendable {
    private var nextValue = 0

    func next() -> String {
        nextValue += 1
        return "artifact-\(nextValue)"
    }
}

enum MediaArtifactTestFixtures {
    static func seedPrerequisites(in database: AppDatabase) async throws {
        let aiRepository = GRDBAIProviderConfigurationRepository(database: database)
        let ttsRepository = GRDBTTSProviderSettingsRepository(database: database)
        try await aiRepository.saveProfile(profileWithTTSEndpoint())
        let voice = try TTSVoiceProfile.make(
            id: "voice-en",
            endpointID: "endpoint-tts",
            languageCode: "en",
            adapterKind: .openAIAudioSpeech,
            modelName: "gpt-4o-mini-tts",
            voiceID: "alloy",
            outputFormat: .mp3,
            lastSuccessfulConfigurationFingerprint: "fingerprint-1",
            lastTestStatus: .succeeded
        )
        try await ttsRepository.saveSettings(
            TTSProviderSettings(endpointID: "endpoint-tts", adapterKind: .openAIAudioSpeech),
            voiceProfiles: [voice]
        )
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
            try db.execute(
                sql: """
                INSERT INTO entries (
                    id, space_id, title, body, source, scene, created_at, updated_at, deleted_at
                ) VALUES ('entry-1', 'space-1', 'Title', 'Body', 'typedText', '生活记录', 1, 1, NULL)
                """
            )
            try db.execute(
                sql: """
                INSERT INTO learning_materials (
                    id, entry_id, space_id, input_kind, prompt_mode, learning_text,
                    original_generated_text, source_entry_body_hash, analysis_source_hash,
                    analysis_status, prompt_id, prompt_version, provider_profile_id,
                    provider_endpoint_id, provider_preset_id, model_name, is_current,
                    created_at, updated_at, deleted_at
                ) VALUES (
                    'material-1', 'entry-1', 'space-1', 'nativeRecord', 'automaticLearningMaterial',
                    'Learning text', 'Learning text', 'source-hash', 'analysis-hash',
                    'fresh', 'prompt', '1', 'profile-1', 'endpoint-tts', 'openai',
                    'gpt-4o-mini', 1, 1, 1, NULL
                )
                """
            )
        }
    }

    static func key(
        sentenceSource: TTSSentenceSource = .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        sentenceTextHash: String = "sentence-hash-1",
        modelName: String = "gpt-4o-mini-tts",
        outputFormat: TTSAudioFormat = .mp3
    ) -> TTSAudioArtifactKey {
        TTSAudioArtifactKey(
            sentenceSource: sentenceSource,
            sentenceTextHash: sentenceTextHash,
            targetLanguageCode: "en",
            providerProfileID: "profile-1",
            ttsEndpointID: "endpoint-tts",
            ttsVoiceProfileID: "voice-en",
            adapterKind: TTSProviderAdapterKind.openAIAudioSpeech.rawValue,
            adapterVersion: "2026-05-23",
            modelName: modelName,
            voiceIDHash: "voice-hash",
            outputFormat: outputFormat,
            sampleRate: nil,
            speed: 1.0,
            pitch: nil,
            volume: nil,
            instructionsHash: nil,
            providerParametersHash: "params-hash",
            configurationFingerprint: "fingerprint-1"
        )
    }

    static func commitInput(
        key: TTSAudioArtifactKey = key(),
        owner: MediaArtifactOwner = .learningMaterialSentence(materialID: "material-1", sentenceIndex: 0),
        stagedFile: MediaArtifactStagedFileReference = MediaArtifactStagedFileReference(
            relativeStagingPath: "staging/op-1.tmp",
            byteSize: 256,
            contentHash: "content-hash-1"
        )
    ) -> TTSAudioArtifactCommitInput {
        TTSAudioArtifactCommitInput(
            key: key,
            languageSpaceID: "space-1",
            owner: owner,
            stagedFile: stagedFile,
            mimeType: "audio/mpeg",
            durationSeconds: 1.5,
            createdAt: Date(timeIntervalSince1970: 400)
        )
    }

    static func mediaArtifactCount(in database: AppDatabase) async throws -> Int {
        try await database.databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM media_artifacts") ?? -1
        }
    }

    static func practiceRecordingKey(
        recordingID: String = "recording-1",
        attemptNumber: Int = 1,
        targetTextHash: String = "target-hash-1"
    ) -> PracticeRecordingArtifactKey {
        PracticeRecordingArtifactKey(
            sessionID: "session-1",
            recordingID: recordingID,
            attemptNumber: attemptNumber,
            targetTextHash: targetTextHash,
            targetLanguageCode: "en",
            recordingFormat: .m4a,
            createdAtBucket: "2026-05-26T00"
        )
    }

    static func practiceRecordingCommitInput(
        key: PracticeRecordingArtifactKey = practiceRecordingKey(),
        stagedFile: MediaArtifactStagedFileReference = MediaArtifactStagedFileReference(
            relativeStagingPath: "staging/practice-recording.tmp",
            byteSize: 512,
            contentHash: "practice-content-hash"
        )
    ) -> PracticeRecordingArtifactCommitInput {
        PracticeRecordingArtifactCommitInput(
            key: key,
            languageSpaceID: "space-1",
            sessionID: "session-1",
            recordingID: key.recordingID,
            attemptNumber: key.attemptNumber,
            stagedFile: stagedFile,
            mimeType: "audio/mp4",
            durationSeconds: 1.4,
            sampleRate: 44100,
            channelCount: 1,
            createdAt: Date(timeIntervalSince1970: 400)
        )
    }

    static func seedPracticeSession(in database: AppDatabase) async throws {
        try await database.databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO learning_material_sentences (
                    id, material_id, position, native_sentence, target_sentence,
                    literal_translation, natural_translation, grammar_notes_json,
                    key_points_json, created_at, updated_at
                ) VALUES (
                    'sentence-1', 'material-1', 0, '我今天早上订了火车票。',
                    'I booked the train this morning.', 'I booked the train this morning.',
                    '我今天早上订了火车票。', '[]', '[]', 1, 1
                )
                """
            )
            try db.execute(
                sql: """
                INSERT INTO practice_sessions (
                    id, language_space_id, entry_id, learning_material_id, sentence_id,
                    sentence_index, target_text_snapshot, translation_snapshot, note_snapshot,
                    target_text_hash, target_language_code, source_entry_body_hash,
                    material_analysis_source_hash, exercise_type, status, problem_marked,
                    completed_recording_id, completed_at, created_at, updated_at, soft_deleted_at
                ) VALUES (
                    'session-1', 'space-1', 'entry-1', 'material-1', 'sentence-1',
                    0, 'I booked the train this morning.', '我今天早上订了火车票。',
                    'booked 表示已经完成预订。', 'target-hash-1', 'en', 'source-hash',
                    'analysis-hash', 'shadowing', 'inProgress', 0, NULL, NULL, 10, 10, NULL
                )
                """
            )
        }
    }

    static func seedReadyPracticeRecording(artifactID: String, in database: AppDatabase) async throws {
        try await database.databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE practice_recordings
                SET status = 'ready', ready_at = 402
                WHERE id = 'recording-1' AND media_artifact_id = ?
                """,
                arguments: [artifactID]
            )
            try db.execute(
                sql: """
                UPDATE practice_sessions
                SET status = 'completed', completed_recording_id = 'recording-1', completed_at = 403
                WHERE id = 'session-1'
                """
            )
        }
    }

    private static func profileWithTTSEndpoint() throws -> AIProviderConfigurationProfile {
        let now = Date(timeIntervalSince1970: 100)
        let ttsEndpoint = try AIProviderEndpointConfiguration(
            input: AIProviderEndpointInput(
                id: "endpoint-tts",
                profileID: "profile-1",
                purpose: .tts,
                isEnabled: true,
                providerPresetID: "openai",
                adapterKind: .openAIResponses,
                baseURL: "https://api.openai.com/v1",
                modelName: "gpt-4o-mini-tts",
                credentialID: nil,
                supportsImageInput: false,
                imageInputEnabled: false
            ),
            createdAt: now,
            updatedAt: now
        )
        return AIProviderConfigurationProfile(
            id: "profile-1",
            displayName: "Default AI Provider",
            isDefault: true,
            status: .configured,
            createdAt: now,
            updatedAt: now,
            endpoints: [ttsEndpoint],
            credentials: []
        )
    }
}
