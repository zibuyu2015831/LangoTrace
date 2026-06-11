import Foundation
import GRDB
import LangoTraceCore

public struct GRDBMediaArtifactRepository: MediaArtifactRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    init(
        databaseQueue: DatabaseQueue,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.databaseQueue = databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }
}

public extension GRDBMediaArtifactRepository {
    func ttsAudioArtifactMetadata(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult {
        try await databaseQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT media_artifacts.*
                FROM media_artifacts
                JOIN tts_audio_artifacts ON tts_audio_artifacts.artifact_id = media_artifacts.id
                WHERE media_artifacts.artifact_type = ?
                  AND media_artifacts.derivation_kind = ?
                  AND media_artifacts.derivation_key_hash = ?
                  AND media_artifacts.file_state = 'ready'
                ORDER BY media_artifacts.invalidated_at IS NULL DESC, media_artifacts.created_at DESC
                LIMIT 1
                """,
                arguments: [
                    MediaArtifactType.ttsSentenceAudio.rawValue,
                    key.derivationKind.rawValue,
                    key.derivationKeyHash,
                ]
            ) else {
                return .miss
            }

            let artifact = try mediaArtifact(from: row)
            guard artifact.invalidatedAt == nil else {
                return .invalidated(.explicitlyInvalidated)
            }

            let accessedAt = clock()
            try db.execute(
                sql: "UPDATE media_artifacts SET last_accessed_at = ? WHERE id = ?",
                arguments: [accessedAt.timeIntervalSince1970, artifact.id]
            )
            var accessed = artifact
            accessed.lastAccessedAt = accessedAt
            return .hit(accessed)
        }
    }

    func practiceRecordingArtifactMetadata(
        for key: PracticeRecordingArtifactKey
    ) async throws -> MediaArtifactLookupResult {
        try await databaseQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT media_artifacts.*
                FROM media_artifacts
                JOIN practice_recording_artifacts
                  ON practice_recording_artifacts.artifact_id = media_artifacts.id
                WHERE media_artifacts.artifact_type = ?
                  AND media_artifacts.derivation_kind = ?
                  AND media_artifacts.derivation_key_hash = ?
                  AND media_artifacts.file_state = 'ready'
                ORDER BY media_artifacts.invalidated_at IS NULL DESC, media_artifacts.created_at DESC
                LIMIT 1
                """,
                arguments: [
                    MediaArtifactType.shadowingRecording.rawValue,
                    key.derivationKind.rawValue,
                    key.derivationKeyHash,
                ]
            ) else {
                return .miss
            }

            let artifact = try mediaArtifact(from: row)
            guard artifact.invalidatedAt == nil else {
                return .invalidated(.explicitlyInvalidated)
            }

            let accessedAt = clock()
            try db.execute(
                sql: "UPDATE media_artifacts SET last_accessed_at = ? WHERE id = ?",
                arguments: [accessedAt.timeIntervalSince1970, artifact.id]
            )
            var accessed = artifact
            accessed.lastAccessedAt = accessedAt
            return .hit(accessed)
        }
    }

    func reserveTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifactCommitReservation {
        try await databaseQueue.write { db in
            if let existing = try activeArtifact(for: input.key, db: db) {
                return MediaArtifactCommitReservation(artifact: existing, wasCreated: false)
            }

            let artifactID = idGenerator()
            let relativePath = try relativePath(for: input.key, artifactID: artifactID)
            let now = input.createdAt
            let policy = MediaArtifactPolicy.defaultDerivedMediaPolicy
            let ownerColumns = ownerColumns(input.owner)
            try db.execute(
                sql: """
                INSERT INTO media_artifacts (
                    id, language_space_id, owner_type, owner_id, owner_sub_id,
                    artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                    mime_type, byte_size, duration_seconds, content_hash, created_at,
                    last_accessed_at, invalidated_at, delete_after, backup_policy,
                    file_state, sync_policy, export_policy
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?)
                """,
                arguments: [
                    artifactID,
                    input.languageSpaceID,
                    ownerColumns.type,
                    ownerColumns.id,
                    ownerColumns.subID,
                    MediaArtifactType.ttsSentenceAudio.rawValue,
                    input.key.derivationKind.rawValue,
                    input.key.derivationKeyHash,
                    relativePath,
                    input.mimeType,
                    input.stagedFile.byteSize,
                    input.durationSeconds,
                    input.stagedFile.contentHash,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    policy.backupPolicy.rawValue,
                    "pending",
                    policy.syncPolicy.rawValue,
                    policy.exportPolicy.rawValue,
                ]
            )
            try insertTTSAudioArtifact(artifactID: artifactID, key: input.key, db: db)
            guard let inserted = try activeArtifact(for: input.key, db: db) else {
                throw MediaArtifactRepositoryError.commitFailed
            }
            return MediaArtifactCommitReservation(artifact: inserted, wasCreated: true)
        }
    }

    func reservePracticeRecordingArtifact(
        _ input: PracticeRecordingArtifactCommitInput
    ) async throws -> MediaArtifactCommitReservation {
        try await databaseQueue.write { db in
            if let existing = try activePracticeRecordingArtifact(for: input.key, db: db) {
                return MediaArtifactCommitReservation(artifact: existing, wasCreated: false)
            }

            let artifactID = idGenerator()
            let relativePath = relativePath(for: input.key, artifactID: artifactID)
            let now = input.createdAt
            let policy = MediaArtifactPolicy.defaultDerivedMediaPolicy
            let ownerColumns = ownerColumns(.practiceSession(id: input.sessionID))
            try db.execute(
                sql: """
                INSERT INTO media_artifacts (
                    id, language_space_id, owner_type, owner_id, owner_sub_id,
                    artifact_type, derivation_kind, derivation_key_hash, relative_file_path,
                    mime_type, byte_size, duration_seconds, content_hash, created_at,
                    last_accessed_at, invalidated_at, delete_after, backup_policy,
                    file_state, sync_policy, export_policy
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?)
                """,
                arguments: [
                    artifactID,
                    input.languageSpaceID,
                    ownerColumns.type,
                    ownerColumns.id,
                    ownerColumns.subID,
                    MediaArtifactType.shadowingRecording.rawValue,
                    input.key.derivationKind.rawValue,
                    input.key.derivationKeyHash,
                    relativePath,
                    input.mimeType,
                    input.stagedFile.byteSize,
                    input.durationSeconds,
                    input.stagedFile.contentHash,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    policy.backupPolicy.rawValue,
                    "pending",
                    policy.syncPolicy.rawValue,
                    policy.exportPolicy.rawValue,
                ]
            )
            try insertPracticeRecording(input, artifactID: artifactID, db: db)
            try insertPracticeRecordingArtifact(input, artifactID: artifactID, db: db)
            guard let inserted = try activePracticeRecordingArtifact(for: input.key, db: db) else {
                throw MediaArtifactRepositoryError.commitFailed
            }
            return MediaArtifactCommitReservation(artifact: inserted, wasCreated: true)
        }
    }

    func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        let reservation = try await reserveTTSAudioArtifact(input)
        try await markArtifactFileReady(artifactID: reservation.artifact.id, at: input.createdAt)
        return reservation.artifact
    }

    func commitPracticeRecordingArtifact(_ input: PracticeRecordingArtifactCommitInput) async throws -> MediaArtifact {
        let reservation = try await reservePracticeRecordingArtifact(input)
        try await markArtifactFileReady(artifactID: reservation.artifact.id, at: input.createdAt)
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE practice_recordings
                SET status = 'ready', ready_at = ?
                WHERE id = ? AND media_artifact_id = ?
                """,
                arguments: [
                    input.createdAt.timeIntervalSince1970,
                    input.recordingID,
                    reservation.artifact.id,
                ]
            )
        }
        return reservation.artifact
    }

    func markArtifactFileReady(artifactID: String, at date: Date) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE media_artifacts
                SET file_state = 'ready', last_accessed_at = ?
                WHERE id = ? AND invalidated_at IS NULL
                """,
                arguments: [date.timeIntervalSince1970, artifactID]
            )
            guard db.changesCount > 0 else {
                throw MediaArtifactRepositoryError.fileReadyUpdateFailed
            }
        }
    }

    func invalidateArtifact(artifactID: String, at date: Date) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE media_artifacts
                SET invalidated_at = ?
                WHERE id = ? AND invalidated_at IS NULL
                """,
                arguments: [date.timeIntervalSince1970, artifactID]
            )
        }
    }

    func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws {
        try await databaseQueue.write { db in
            var conditions = ["media_artifacts.invalidated_at IS NULL"]
            var arguments: StatementArguments = [request.invalidatedAt.timeIntervalSince1970]
            if let languageSpaceID = request.languageSpaceID {
                conditions.append("media_artifacts.language_space_id = ?")
                arguments += [languageSpaceID]
            }
            if let owner = request.owner {
                let columns = ownerColumns(owner)
                conditions.append("media_artifacts.owner_type = ?")
                conditions.append("media_artifacts.owner_id = ?")
                arguments += [columns.type, columns.id]
                if let subID = columns.subID {
                    conditions.append("media_artifacts.owner_sub_id = ?")
                    arguments += [subID]
                }
            }
            if let artifactType = request.artifactType {
                conditions.append("media_artifacts.artifact_type = ?")
                arguments += [artifactType.rawValue]
            }
            if let providerProfileID = request.providerProfileID {
                conditions.append("tts_audio_artifacts.provider_profile_id = ?")
                arguments += [providerProfileID]
            }
            if let ttsEndpointID = request.ttsEndpointID {
                conditions.append("tts_audio_artifacts.tts_endpoint_id = ?")
                arguments += [ttsEndpointID]
            }
            if let configurationFingerprint = request.configurationFingerprint {
                conditions.append("tts_audio_artifacts.configuration_fingerprint = ?")
                arguments += [configurationFingerprint]
            }

            try db.execute(
                sql: """
                UPDATE media_artifacts
                SET invalidated_at = ?
                WHERE id IN (
                    SELECT media_artifacts.id
                    FROM media_artifacts
                    LEFT JOIN tts_audio_artifacts
                      ON tts_audio_artifacts.artifact_id = media_artifacts.id
                    WHERE \(conditions.joined(separator: " AND "))
                )
                """,
                arguments: arguments
            )
        }
    }

    func artifactsForCleanup(_ request: MediaArtifactCleanupRequest) async throws -> [MediaArtifact] {
        try await databaseQueue.read { db in
            let filter = cleanupFilter(for: request)
            let sql = """
            SELECT *
            FROM media_artifacts
            \(filter.conditions.isEmpty ? "" : "WHERE \(filter.conditions.joined(separator: " AND "))")
            ORDER BY last_accessed_at ASC
            """
            let scopedArtifacts = try Row.fetchAll(db, sql: sql, arguments: filter.arguments).map(mediaArtifact(from:))
            guard let targetMaximumBytes = request.targetMaximumBytes else {
                return scopedArtifacts
            }

            var selected: [MediaArtifact] = []
            var selectedIDs = Set<String>()
            var remainingBytes = scopedArtifacts.reduce(Int64(0)) { $0 + $1.byteSize }

            for artifact in scopedArtifacts where artifact.invalidatedAt != nil || isExpired(artifact, at: request.now) {
                selected.append(artifact)
                selectedIDs.insert(artifact.id)
                remainingBytes -= artifact.byteSize
            }

            for artifact in scopedArtifacts where remainingBytes > targetMaximumBytes && !selectedIDs.contains(artifact.id) {
                selected.append(artifact)
                selectedIDs.insert(artifact.id)
                remainingBytes -= artifact.byteSize
            }

            return selected
        }
    }

    func deleteArtifactMetadata(artifactIDs: [String]) async throws {
        guard !artifactIDs.isEmpty else {
            return
        }
        try await databaseQueue.write { db in
            for artifactID in artifactIDs {
                // Rolled-back reservations leave a pending practice_recordings row
                // behind whose media_artifact_id uses ON DELETE RESTRICT. Remove it
                // first so the master row can be deleted.
                try db.execute(
                    sql: """
                    DELETE FROM practice_recordings
                    WHERE media_artifact_id = ? AND status = 'pending'
                    """,
                    arguments: [artifactID]
                )
                do {
                    try db.execute(
                        sql: "DELETE FROM media_artifacts WHERE id = ?",
                        arguments: [artifactID]
                    )
                } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
                    // A non-pending practice recording still references this artifact.
                    // Skip it instead of poisoning the rest of the batch.
                    continue
                }
            }
        }
    }

    func markAccessed(artifactID: String, at date: Date) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE media_artifacts SET last_accessed_at = ? WHERE id = ?",
                arguments: [date.timeIntervalSince1970, artifactID]
            )
        }
    }
}

public enum MediaArtifactRepositoryError: Error, Equatable, Sendable {
    case commitFailed
    case fileReadyUpdateFailed
}

private struct MediaArtifactCleanupFilter {
    var conditions: [String]
    var arguments: StatementArguments
}

private extension GRDBMediaArtifactRepository {
    static let pendingReservationProtectionSeconds: TimeInterval = 3600

    // swiftlint:disable:next function_body_length
    func cleanupFilter(for request: MediaArtifactCleanupRequest) -> MediaArtifactCleanupFilter {
        var conditions: [String] = []
        var arguments: StatementArguments = []
        if let languageSpaceID = request.languageSpaceID {
            conditions.append("language_space_id = ?")
            arguments += [languageSpaceID]
        }
        if let owner = request.owner {
            let columns = ownerColumns(owner)
            conditions.append("owner_type = ?")
            conditions.append("owner_id = ?")
            arguments += [columns.type, columns.id]
            if let subID = columns.subID {
                conditions.append("owner_sub_id = ?")
                arguments += [subID]
            }
        }
        if let artifactType = request.artifactType {
            conditions.append("artifact_type = ?")
            arguments += [artifactType.rawValue]
        }
        // practice_recordings.media_artifact_id uses ON DELETE RESTRICT, so any
        // referenced artifact must never become a cleanup candidate: deleting its
        // file first and then failing the metadata delete would desynchronize
        // metadata and files.
        conditions.append(
            """
            NOT EXISTS (
                SELECT 1
                FROM practice_recordings
                WHERE practice_recordings.media_artifact_id = media_artifacts.id
            )
            """
        )
        // Protect in-flight reservations: pending rows stay out of cleanup until
        // they are old enough to be considered abandoned.
        conditions.append("NOT (file_state = 'pending' AND created_at > ?)")
        arguments += [
            request.now.timeIntervalSince1970 - Self.pendingReservationProtectionSeconds,
        ]
        if request.targetMaximumBytes == nil {
            if request.includeInvalidated {
                // Active master rows that lost their typed extension row can never be
                // looked up again and only block same-key rebuilds, so they are
                // cleanable orphans.
                conditions.append(
                    """
                    (
                        invalidated_at IS NOT NULL
                        OR delete_after <= ?
                        OR (
                            NOT EXISTS (
                                SELECT 1
                                FROM tts_audio_artifacts
                                WHERE tts_audio_artifacts.artifact_id = media_artifacts.id
                            )
                            AND NOT EXISTS (
                                SELECT 1
                                FROM practice_recording_artifacts
                                WHERE practice_recording_artifacts.artifact_id = media_artifacts.id
                            )
                        )
                    )
                    """
                )
                arguments += [request.now.timeIntervalSince1970]
            } else {
                conditions.append("delete_after <= ?")
                arguments += [request.now.timeIntervalSince1970]
            }
        }
        return MediaArtifactCleanupFilter(conditions: conditions, arguments: arguments)
    }

    func activeArtifact(for key: TTSAudioArtifactKey, db: Database) throws -> MediaArtifact? {
        try Row.fetchOne(
            db,
            sql: """
            SELECT media_artifacts.*
            FROM media_artifacts
            JOIN tts_audio_artifacts ON tts_audio_artifacts.artifact_id = media_artifacts.id
            WHERE media_artifacts.artifact_type = ?
              AND media_artifacts.derivation_kind = ?
              AND media_artifacts.derivation_key_hash = ?
              AND media_artifacts.invalidated_at IS NULL
            LIMIT 1
            """,
            arguments: [
                MediaArtifactType.ttsSentenceAudio.rawValue,
                key.derivationKind.rawValue,
                key.derivationKeyHash,
            ]
        ).map(mediaArtifact(from:))
    }

    func activePracticeRecordingArtifact(for key: PracticeRecordingArtifactKey, db: Database) throws -> MediaArtifact? {
        try Row.fetchOne(
            db,
            sql: """
            SELECT media_artifacts.*
            FROM media_artifacts
            JOIN practice_recording_artifacts
              ON practice_recording_artifacts.artifact_id = media_artifacts.id
            WHERE media_artifacts.artifact_type = ?
              AND media_artifacts.derivation_kind = ?
              AND media_artifacts.derivation_key_hash = ?
              AND media_artifacts.invalidated_at IS NULL
            LIMIT 1
            """,
            arguments: [
                MediaArtifactType.shadowingRecording.rawValue,
                key.derivationKind.rawValue,
                key.derivationKeyHash,
            ]
        ).map(mediaArtifact(from:))
    }

    func insertTTSAudioArtifact(artifactID: String, key: TTSAudioArtifactKey, db: Database) throws {
        let source = sourceColumns(key.sentenceSource)
        try db.execute(
            sql: """
            INSERT INTO tts_audio_artifacts (
                artifact_id, sentence_source_type, entry_id, learning_material_id,
                reading_document_id, reading_sentence_id, operation_id, sentence_index,
                sentence_text_hash, target_language_code,
                provider_profile_id, tts_endpoint_id, tts_voice_profile_id,
                adapter_kind, adapter_version, model_name, voice_id_hash,
                output_format, sample_rate, speed, pitch, volume,
                instructions_hash, provider_parameters_hash, configuration_fingerprint
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                artifactID,
                source.type,
                source.entryID,
                source.learningMaterialID,
                source.readingDocumentID,
                source.readingSentenceID,
                source.operationID,
                source.sentenceIndex,
                key.sentenceTextHash,
                key.targetLanguageCode,
                key.providerProfileID,
                key.ttsEndpointID,
                key.ttsVoiceProfileID,
                key.adapterKind,
                key.adapterVersion,
                key.modelName,
                key.voiceIDHash,
                key.outputFormat.rawValue,
                key.sampleRate,
                key.speed,
                key.pitch,
                key.volume,
                key.instructionsHash,
                key.providerParametersHash,
                key.configurationFingerprint,
            ]
        )
    }

    func insertPracticeRecording(
        _ input: PracticeRecordingArtifactCommitInput,
        artifactID: String,
        db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO practice_recordings (
                id, session_id, language_space_id, media_artifact_id, attempt_number,
                status, duration_seconds, byte_size, content_hash, created_at,
                ready_at, invalidated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL)
            """,
            arguments: [
                input.recordingID,
                input.sessionID,
                input.languageSpaceID,
                artifactID,
                input.attemptNumber,
                "pending",
                input.durationSeconds,
                input.stagedFile.byteSize,
                input.stagedFile.contentHash,
                input.createdAt.timeIntervalSince1970,
            ]
        )
    }

    func insertPracticeRecordingArtifact(
        _ input: PracticeRecordingArtifactCommitInput,
        artifactID: String,
        db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO practice_recording_artifacts (
                artifact_id, session_id, recording_id, attempt_number,
                target_text_hash, target_language_code, recording_format,
                sample_rate, channel_count, duration_seconds, content_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                artifactID,
                input.sessionID,
                input.recordingID,
                input.attemptNumber,
                input.key.targetTextHash,
                input.key.targetLanguageCode,
                input.key.recordingFormat.rawValue,
                input.sampleRate,
                input.channelCount,
                input.durationSeconds,
                input.stagedFile.contentHash,
            ]
        )
    }

    func mediaArtifact(from row: Row) throws -> MediaArtifact {
        let policy = MediaArtifactPolicy(
            backupPolicy: MediaArtifactBackupPolicy(rawValue: row["backup_policy"] as String)
                ?? .excludedFromSystemBackup,
            syncPolicy: MediaArtifactSyncPolicy(rawValue: row["sync_policy"] as String) ?? .localOnly,
            exportPolicy: MediaArtifactExportPolicy(rawValue: row["export_policy"] as String) ?? .excludedByDefault
        )
        return MediaArtifact(
            id: row["id"],
            languageSpaceID: row["language_space_id"],
            owner: owner(
                type: row["owner_type"],
                id: row["owner_id"],
                subID: row["owner_sub_id"]
            ),
            type: MediaArtifactType(rawValue: row["artifact_type"] as String) ?? .ttsSentenceAudio,
            derivationKind: MediaArtifactDerivationKind(rawValue: row["derivation_kind"] as String) ?? .ttsAudio,
            derivationKeyHash: row["derivation_key_hash"],
            relativeFilePath: row["relative_file_path"],
            mimeType: row["mime_type"],
            byteSize: row["byte_size"],
            durationSeconds: row["duration_seconds"],
            contentHash: row["content_hash"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            lastAccessedAt: Date(timeIntervalSince1970: row["last_accessed_at"]),
            invalidatedAt: (row["invalidated_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
            deleteAfter: (row["delete_after"] as Double?).map(Date.init(timeIntervalSince1970:)),
            policy: policy
        )
    }

    func isExpired(_ artifact: MediaArtifact, at date: Date) -> Bool {
        guard let deleteAfter = artifact.deleteAfter else {
            return false
        }
        return deleteAfter <= date
    }

    func relativePath(for key: TTSAudioArtifactKey, artifactID: String) throws -> String {
        let fileExtension = try fileExtension(for: key.outputFormat)
        return "ttsSentenceAudio/\(key.targetLanguageCode)/\(artifactID).\(fileExtension)"
    }

    func relativePath(for key: PracticeRecordingArtifactKey, artifactID: String) -> String {
        "shadowingRecording/\(key.targetLanguageCode)/\(artifactID).\(key.recordingFormat.rawValue)"
    }

    func fileExtension(for format: TTSAudioFormat) throws -> String {
        switch format {
        case .mp3:
            "mp3"
        case .wav:
            "wav"
        case .opus:
            "opus"
        case .aac:
            "aac"
        case .flac:
            "flac"
        case .pcm:
            "pcm"
        case .mulaw:
            "mulaw"
        }
    }

    func ownerColumns(_ owner: MediaArtifactOwner) -> MediaArtifactOwnerColumns {
        switch owner {
        case let .entry(id):
            MediaArtifactOwnerColumns(type: "entry", id: id, subID: nil)
        case let .learningMaterial(id):
            MediaArtifactOwnerColumns(type: "learningMaterial", id: id, subID: nil)
        case let .learningMaterialSentence(materialID, sentenceIndex):
            MediaArtifactOwnerColumns(type: "learningMaterialSentence", id: materialID, subID: String(sentenceIndex))
        case let .readingDocumentSentence(documentID, sentenceID):
            MediaArtifactOwnerColumns(type: "readingDocumentSentence", id: documentID, subID: sentenceID)
        case let .practiceSession(id):
            MediaArtifactOwnerColumns(type: "practiceSession", id: id, subID: nil)
        case let .temporaryOperation(id):
            MediaArtifactOwnerColumns(type: "temporaryOperation", id: id, subID: nil)
        }
    }

    func owner(type: String, id: String, subID: String?) -> MediaArtifactOwner {
        switch type {
        case "entry":
            .entry(id: id)
        case "learningMaterial":
            .learningMaterial(id: id)
        case "learningMaterialSentence":
            .learningMaterialSentence(materialID: id, sentenceIndex: Int(subID ?? "") ?? 0)
        case "readingDocumentSentence":
            .readingDocumentSentence(documentID: id, sentenceID: subID ?? "")
        case "practiceSession":
            .practiceSession(id: id)
        default:
            .temporaryOperation(id: id)
        }
    }

    func sourceColumns(_ source: TTSSentenceSource) -> TTSSentenceSourceColumns {
        switch source {
        case let .entry(id, sentenceIndex):
            TTSSentenceSourceColumns(
                type: "entry",
                entryID: id,
                learningMaterialID: nil,
                readingDocumentID: nil,
                readingSentenceID: nil,
                operationID: nil,
                sentenceIndex: sentenceIndex
            )
        case let .learningMaterialSentence(materialID, sentenceIndex):
            TTSSentenceSourceColumns(
                type: "learningMaterialSentence",
                entryID: nil,
                learningMaterialID: materialID,
                readingDocumentID: nil,
                readingSentenceID: nil,
                operationID: nil,
                sentenceIndex: sentenceIndex
            )
        case let .readingDocumentSentence(documentID, sentenceID):
            TTSSentenceSourceColumns(
                type: "readingDocumentSentence",
                entryID: nil,
                learningMaterialID: nil,
                readingDocumentID: documentID,
                readingSentenceID: sentenceID,
                operationID: nil,
                sentenceIndex: nil
            )
        case let .temporary(operationID, sentenceIndex):
            TTSSentenceSourceColumns(
                type: "temporary",
                entryID: nil,
                learningMaterialID: nil,
                readingDocumentID: nil,
                readingSentenceID: nil,
                operationID: operationID,
                sentenceIndex: sentenceIndex
            )
        }
    }
}

private struct MediaArtifactOwnerColumns {
    var type: String
    var id: String
    var subID: String?
}

private struct TTSSentenceSourceColumns {
    var type: String
    var entryID: String?
    var learningMaterialID: String?
    var readingDocumentID: String?
    var readingSentenceID: String?
    var operationID: String?
    var sentenceIndex: Int?
}

