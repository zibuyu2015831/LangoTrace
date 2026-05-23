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

    public func ttsAudioArtifactMetadata(for key: TTSAudioArtifactKey) async throws -> MediaArtifactLookupResult {
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

    public func commitTTSAudioArtifact(_ input: TTSAudioArtifactCommitInput) async throws -> MediaArtifact {
        try await databaseQueue.write { db in
            if let existing = try activeArtifact(for: input.key, db: db) {
                return existing
            }

            let artifactID = idGenerator()
            let relativePath = relativePath(for: input.key, artifactID: artifactID)
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
                    sync_policy, export_policy
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?)
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
                    policy.syncPolicy.rawValue,
                    policy.exportPolicy.rawValue,
                ]
            )
            try insertTTSAudioArtifact(artifactID: artifactID, key: input.key, db: db)
            guard let inserted = try activeArtifact(for: input.key, db: db) else {
                throw MediaArtifactRepositoryError.commitFailed
            }
            return inserted
        }
    }

    public func invalidateArtifacts(_ request: MediaArtifactInvalidationRequest) async throws {
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

    public func artifactsForCleanup(_ request: MediaArtifactCleanupRequest) async throws -> [MediaArtifact] {
        try await databaseQueue.read { db in
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
            if request.includeInvalidated {
                conditions.append("(invalidated_at IS NOT NULL OR delete_after <= ?)")
                arguments += [request.now.timeIntervalSince1970]
            } else {
                conditions.append("delete_after <= ?")
                arguments += [request.now.timeIntervalSince1970]
            }

            let sql = """
            SELECT *
            FROM media_artifacts
            \(conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))")
            ORDER BY last_accessed_at ASC
            """
            return try Row.fetchAll(db, sql: sql, arguments: arguments).map(mediaArtifact(from:))
        }
    }

    public func deleteArtifactMetadata(artifactIDs: [String]) async throws {
        guard !artifactIDs.isEmpty else {
            return
        }
        try await databaseQueue.write { db in
            try db.execute(
                sql: "DELETE FROM media_artifacts WHERE id IN \(SQLPlaceholders.placeholders(for: artifactIDs))",
                arguments: StatementArguments(artifactIDs)
            )
        }
    }

    public func markAccessed(artifactID: String, at date: Date) async throws {
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
}

private extension GRDBMediaArtifactRepository {
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

    func insertTTSAudioArtifact(artifactID: String, key: TTSAudioArtifactKey, db: Database) throws {
        let source = sourceColumns(key.sentenceSource)
        try db.execute(
            sql: """
            INSERT INTO tts_audio_artifacts (
                artifact_id, sentence_source_type, entry_id, learning_material_id,
                sentence_index, sentence_text_hash, target_language_code,
                provider_profile_id, tts_endpoint_id, tts_voice_profile_id,
                adapter_kind, adapter_version, model_name, voice_id_hash,
                output_format, sample_rate, speed, pitch, volume,
                instructions_hash, provider_parameters_hash, configuration_fingerprint
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                artifactID,
                source.type,
                source.entryID,
                source.learningMaterialID,
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

    func relativePath(for key: TTSAudioArtifactKey, artifactID: String) -> String {
        let fileExtension = key.outputFormat.rawValue == "wav" ? "wav" : "mp3"
        return "ttsSentenceAudio/\(key.targetLanguageCode)/\(artifactID).\(fileExtension)"
    }

    func ownerColumns(_ owner: MediaArtifactOwner) -> MediaArtifactOwnerColumns {
        switch owner {
        case let .entry(id):
            MediaArtifactOwnerColumns(type: "entry", id: id, subID: nil)
        case let .learningMaterial(id):
            MediaArtifactOwnerColumns(type: "learningMaterial", id: id, subID: nil)
        case let .learningMaterialSentence(materialID, sentenceIndex):
            MediaArtifactOwnerColumns(type: "learningMaterialSentence", id: materialID, subID: String(sentenceIndex))
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
                sentenceIndex: sentenceIndex
            )
        case let .learningMaterialSentence(materialID, sentenceIndex):
            TTSSentenceSourceColumns(
                type: "learningMaterialSentence",
                entryID: nil,
                learningMaterialID: materialID,
                sentenceIndex: sentenceIndex
            )
        case let .temporary(operationID, sentenceIndex):
            TTSSentenceSourceColumns(
                type: "temporary",
                entryID: operationID,
                learningMaterialID: nil,
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
    var sentenceIndex: Int?
}

private enum SQLPlaceholders {
    static func placeholders(for values: [some DatabaseValueConvertible]) -> String {
        "(\(Array(repeating: "?", count: values.count).joined(separator: ",")))"
    }
}
