import Foundation
import GRDB
import LangoTraceCore

public struct GRDBLearningContentRepository: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func createEntry(_ draft: NewLearningEntryDraft, in spaceID: String) throws -> LearningEntry {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let scene = draft.scene.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw LearningContentRepositoryError.emptyEntryBody }

        return try databaseQueue.write { db in
            guard try activeLanguageSpaceExists(spaceID, db: db) else {
                throw LearningContentRepositoryError.languageSpaceNotFound
            }
            let now = clock()
            let entry = LearningEntry(
                id: idGenerator(),
                spaceID: spaceID,
                title: title.isEmpty ? "生活记录" : title,
                body: body,
                source: draft.source,
                scene: scene.isEmpty ? "生活记录" : scene,
                createdAt: now
            )
            try db.execute(
                sql: """
                INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
                """,
                arguments: [
                    entry.id,
                    entry.spaceID,
                    entry.title,
                    entry.body,
                    entry.source.rawValue,
                    entry.scene,
                    entry.createdAt.timeIntervalSince1970,
                    entry.createdAt.timeIntervalSince1970,
                ]
            )
            return entry
        }
    }

    public func entries(for spaceID: String) throws -> [LearningEntry] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM entries
                WHERE space_id = ? AND deleted_at IS NULL
                ORDER BY created_at DESC
                """,
                arguments: [spaceID]
            ).map(entry(from:))
        }
    }

    public func entry(id: String) throws -> LearningEntry? {
        try databaseQueue.read { db in
            try fetchActiveEntry(id: id, db: db)
        }
    }

    public func currentMaterial(for entryID: String) throws -> LearningMaterial? {
        try databaseQueue.read { db in
            try fetchCurrentMaterial(entryID: entryID, db: db)
        }
    }

    public func material(id: String) throws -> LearningMaterial? {
        try databaseQueue.read { db in
            try fetchMaterial(id: id, db: db)
        }
    }

    public func saveGeneratedMaterial(_ result: LearningMaterialGenerationResult, for entryID: String) throws -> LearningMaterial {
        try databaseQueue.write { db in
            guard entryID == result.entryID else {
                throw LearningContentRepositoryError.entryMismatch
            }
            guard let entry = try fetchActiveEntry(id: entryID, db: db) else {
                throw LearningContentRepositoryError.entryNotFound
            }
            guard entry.spaceID == result.spaceID else {
                throw LearningContentRepositoryError.spaceMismatch
            }

            let now = clock()
            let materialID = idGenerator()
            let analysis = analysisWithFreshHash(result.analysis, learningText: result.learningText)
            try db.execute(
                sql: "UPDATE learning_materials SET is_current = 0, updated_at = ? WHERE entry_id = ? AND deleted_at IS NULL",
                arguments: [now.timeIntervalSince1970, entryID]
            )
            try insertMaterial(
                id: materialID,
                entryID: entryID,
                spaceID: entry.spaceID,
                inputKind: result.inputKind,
                promptMode: result.promptMode,
                learningText: result.learningText,
                originalGeneratedText: result.learningText,
                analysis: analysis,
                metadata: result.metadata,
                isCurrent: true,
                now: now,
                db: db
            )
            try replaceAnalysisRows(
                analysis,
                revisionSummary: result.revisionSummary,
                materialID: materialID,
                entryID: entryID,
                spaceID: entry.spaceID,
                now: now,
                db: db
            )
            guard let material = try fetchMaterial(id: materialID, db: db) else {
                throw LearningContentRepositoryError.materialNotFound
            }
            return material
        }
    }

    public func updateLearningText(materialID: String, learningText: String) throws -> LearningMaterial {
        let trimmed = learningText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LearningContentRepositoryError.emptyLearningText }
        return try databaseQueue.write { db in
            guard try fetchMaterial(id: materialID, db: db) != nil else {
                throw LearningContentRepositoryError.materialNotFound
            }
            let now = clock()
            try db.execute(
                sql: """
                UPDATE learning_materials
                SET learning_text = ?, analysis_status = ?, analysis_source_hash = ?, updated_at = ?
                WHERE id = ? AND deleted_at IS NULL
                """,
                arguments: [
                    trimmed,
                    LearningMaterialAnalysisStatus.stale.rawValue,
                    LearningMaterialTextHash.sha256(for: trimmed),
                    now.timeIntervalSince1970,
                    materialID,
                ]
            )
            guard let material = try fetchMaterial(id: materialID, db: db) else {
                throw LearningContentRepositoryError.materialNotFound
            }
            return material
        }
    }

    public func replaceAnalysis(_ result: LearningMaterialAnalysisResult, materialID: String) throws -> LearningMaterial {
        try databaseQueue.write { db in
            guard result.materialID == materialID,
                  let material = try fetchMaterial(id: materialID, db: db),
                  let entry = try fetchActiveEntry(id: material.entryID, db: db)
            else {
                throw LearningContentRepositoryError.materialNotFound
            }
            let now = clock()
            let analysis = analysisWithFreshHash(result.analysis, learningText: material.learningText)
            try deleteAnalysisRows(materialID: materialID, db: db)
            try replaceAnalysisRows(
                analysis,
                revisionSummary: material.revisionSummary,
                materialID: materialID,
                entryID: entry.id,
                spaceID: entry.spaceID,
                now: now,
                db: db
            )
            try db.execute(
                sql: """
                UPDATE learning_materials
                SET analysis_status = ?, analysis_source_hash = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    LearningMaterialAnalysisStatus.fresh.rawValue,
                    analysis.sourceTextHash,
                    now.timeIntervalSince1970,
                    materialID,
                ]
            )
            guard let refreshed = try fetchMaterial(id: materialID, db: db) else {
                throw LearningContentRepositoryError.materialNotFound
            }
            return refreshed
        }
    }

    public func recordOperation(_ summary: LearningMaterialOperationSummary) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO learning_material_operations (
                    id, operation_id, entry_id, material_id, operation_kind, status,
                    failure_category, prompt_id, prompt_version, provider_profile_id,
                    provider_endpoint_id, provider_preset_id, model_name, input_kind,
                    estimated_token_bucket, duration_ms, created_at, completed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(operation_id) DO UPDATE SET
                    material_id = excluded.material_id,
                    status = excluded.status,
                    failure_category = excluded.failure_category,
                    provider_profile_id = excluded.provider_profile_id,
                    provider_endpoint_id = excluded.provider_endpoint_id,
                    provider_preset_id = excluded.provider_preset_id,
                    model_name = excluded.model_name,
                    input_kind = excluded.input_kind,
                    estimated_token_bucket = excluded.estimated_token_bucket,
                    duration_ms = excluded.duration_ms,
                    completed_at = excluded.completed_at
                """,
                arguments: operationArguments(summary)
            )
        }
    }

    public func operations(for entryID: String) throws -> [LearningMaterialOperationSummary] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM learning_material_operations WHERE entry_id = ? ORDER BY created_at DESC",
                arguments: [entryID]
            ).map(operation(from:))
        }
    }

    public func memoryItems(for spaceID: String) throws -> [MemoryItem] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT memory_candidates.*
                FROM memory_candidates
                JOIN entries ON entries.id = memory_candidates.entry_id
                JOIN learning_materials ON learning_materials.id = memory_candidates.material_id
                WHERE memory_candidates.space_id = ?
                  AND entries.deleted_at IS NULL
                  AND learning_materials.deleted_at IS NULL
                  AND learning_materials.is_current = 1
                ORDER BY memory_candidates.created_at DESC
                """,
                arguments: [spaceID]
            ).map(memoryItem(from:))
        }
    }

    public func practiceItems(for entryID: String) throws -> [PracticeItem] {
        try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT practice_candidates.*
                FROM practice_candidates
                JOIN entries ON entries.id = practice_candidates.entry_id
                JOIN learning_materials ON learning_materials.id = practice_candidates.material_id
                WHERE practice_candidates.entry_id = ?
                  AND entries.deleted_at IS NULL
                  AND learning_materials.deleted_at IS NULL
                  AND learning_materials.is_current = 1
                ORDER BY practice_candidates.created_at DESC
                """,
                arguments: [entryID]
            ).map(practiceItem(from:))
        }
    }

    public func deleteEntry(id: String) throws {
        try databaseQueue.write { db in
            let now = clock().timeIntervalSince1970
            try db.execute(
                sql: "UPDATE entries SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL",
                arguments: [now, now, id]
            )
            try db.execute(
                sql: "UPDATE learning_materials SET deleted_at = ?, updated_at = ? WHERE entry_id = ? AND deleted_at IS NULL",
                arguments: [now, now, id]
            )
        }
    }
}

private extension GRDBLearningContentRepository {
    func activeLanguageSpaceExists(_ id: String, db: Database) throws -> Bool {
        try Bool.fetchOne(
            db,
            sql: "SELECT 1 FROM language_spaces WHERE id = ? AND deleted_at IS NULL",
            arguments: [id]
        ) ?? false
    }

    func fetchActiveEntry(id: String, db: Database) throws -> LearningEntry? {
        try Row.fetchOne(
            db,
            sql: "SELECT * FROM entries WHERE id = ? AND deleted_at IS NULL",
            arguments: [id]
        ).map(entry(from:))
    }

    func fetchCurrentMaterial(entryID: String, db: Database) throws -> LearningMaterial? {
        try Row.fetchOne(
            db,
            sql: """
            SELECT *
            FROM learning_materials
            WHERE entry_id = ? AND is_current = 1 AND deleted_at IS NULL
            LIMIT 1
            """,
            arguments: [entryID]
        ).flatMap { try material(from: $0, db: db) }
    }

    func fetchMaterial(id: String, db: Database) throws -> LearningMaterial? {
        try Row.fetchOne(
            db,
            sql: "SELECT * FROM learning_materials WHERE id = ? AND deleted_at IS NULL",
            arguments: [id]
        ).flatMap { try material(from: $0, db: db) }
    }

    // swiftlint:disable:next function_parameter_count
    func insertMaterial(
        id: String,
        entryID: String,
        spaceID: String,
        inputKind: LearningMaterialInputKind,
        promptMode: LearningMaterialPromptMode,
        learningText: String,
        originalGeneratedText: String,
        analysis: LearningMaterialAnalysis,
        metadata: LearningMaterialGenerationMetadata,
        isCurrent: Bool,
        now: Date,
        db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO learning_materials (
                id, entry_id, space_id, input_kind, prompt_mode, learning_text,
                original_generated_text, analysis_source_hash, analysis_status,
                prompt_id, prompt_version, provider_profile_id, provider_endpoint_id,
                provider_preset_id, model_name, is_current, created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
            """,
            arguments: [
                id,
                entryID,
                spaceID,
                inputKind.rawValue,
                promptMode.rawValue,
                learningText,
                originalGeneratedText,
                analysis.sourceTextHash,
                analysis.status.rawValue,
                metadata.promptID,
                metadata.promptVersion,
                metadata.providerProfileID,
                metadata.providerEndpointID,
                metadata.providerPresetID,
                metadata.modelName,
                isCurrent,
                now.timeIntervalSince1970,
                now.timeIntervalSince1970,
            ]
        )
    }

    func replaceAnalysisRows(
        _ analysis: LearningMaterialAnalysis,
        revisionSummary: [LearningRevision],
        materialID: String,
        entryID: String,
        spaceID: String,
        now: Date,
        db: Database
    ) throws {
        for sentence in analysis.sentences {
            try db.execute(
                sql: """
                INSERT INTO learning_material_sentences (
                    id, material_id, position, native_sentence, target_sentence,
                    literal_translation, natural_translation, grammar_notes_json,
                    key_points_json, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    sentence.id,
                    materialID,
                    sentence.position,
                    sentence.nativeSentence,
                    sentence.targetSentence,
                    sentence.literalTranslation,
                    sentence.naturalTranslation,
                    encodedJSON(VersionedStringList(values: sentence.grammarNotes)),
                    encodedJSON(VersionedStringList(values: sentence.keyPoints)),
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                ]
            )
        }
        for revision in revisionSummary {
            try db.execute(
                sql: """
                INSERT INTO learning_material_revision_notes (
                    id, material_id, position, original_text, revised_text,
                    reason_native, category, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    revision.id,
                    materialID,
                    revision.position,
                    revision.originalText,
                    revision.revisedText,
                    revision.reasonNative,
                    revision.category.rawValue,
                    now.timeIntervalSince1970,
                ]
            )
        }
        for candidate in analysis.memoryCandidates {
            try db.execute(
                sql: """
                INSERT INTO memory_candidates (
                    id, space_id, entry_id, material_id, sentence_id, kind, text,
                    explanation_native, example_target, example_native, difficulty,
                    status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)
                """,
                arguments: [
                    candidate.id,
                    spaceID,
                    entryID,
                    materialID,
                    candidate.sentenceID,
                    candidate.kind.rawValue,
                    candidate.text,
                    candidate.explanationNative,
                    candidate.exampleTarget,
                    candidate.exampleNative,
                    candidate.difficulty.rawValue,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                ]
            )
        }
        for candidate in analysis.practiceCandidates {
            try db.execute(
                sql: """
                INSERT INTO practice_candidates (
                    id, space_id, entry_id, material_id, sentence_id, kind, title,
                    prompt_text, answer_text, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)
                """,
                arguments: [
                    candidate.id,
                    spaceID,
                    entryID,
                    materialID,
                    candidate.sentenceID,
                    candidate.kind.rawValue,
                    candidate.title,
                    candidate.promptText,
                    candidate.answerText,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                ]
            )
        }
    }

    func deleteAnalysisRows(materialID: String, db: Database) throws {
        try db.execute(sql: "DELETE FROM memory_candidates WHERE material_id = ?", arguments: [materialID])
        try db.execute(sql: "DELETE FROM practice_candidates WHERE material_id = ?", arguments: [materialID])
        try db.execute(sql: "DELETE FROM learning_material_revision_notes WHERE material_id = ?", arguments: [materialID])
        try db.execute(sql: "DELETE FROM learning_material_sentences WHERE material_id = ?", arguments: [materialID])
    }

    func analysisWithFreshHash(_ analysis: LearningMaterialAnalysis, learningText: String) -> LearningMaterialAnalysis {
        LearningMaterialAnalysis(
            status: .fresh,
            sourceTextHash: LearningMaterialTextHash.sha256(for: learningText),
            sentences: analysis.sentences,
            memoryCandidates: analysis.memoryCandidates,
            practiceCandidates: analysis.practiceCandidates
        )
    }

    func entry(from row: Row) -> LearningEntry {
        LearningEntry(
            id: row["id"],
            spaceID: row["space_id"],
            title: row["title"],
            body: row["body"],
            source: EntrySource(rawValue: row["source"] as String) ?? .typedText,
            scene: row["scene"],
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }

    func material(from row: Row, db: Database) throws -> LearningMaterial {
        let materialID: String = row["id"]
        let sentences = try Row.fetchAll(
            db,
            sql: "SELECT * FROM learning_material_sentences WHERE material_id = ? ORDER BY position",
            arguments: [materialID]
        ).map(sentence(from:))
        let revisions = try Row.fetchAll(
            db,
            sql: "SELECT * FROM learning_material_revision_notes WHERE material_id = ? ORDER BY position",
            arguments: [materialID]
        ).map(revision(from:))
        let memory = try Row.fetchAll(
            db,
            sql: "SELECT * FROM memory_candidates WHERE material_id = ? ORDER BY created_at DESC",
            arguments: [materialID]
        ).map(memoryCandidate(from:))
        let practice = try Row.fetchAll(
            db,
            sql: "SELECT * FROM practice_candidates WHERE material_id = ? ORDER BY created_at DESC",
            arguments: [materialID]
        ).map(practiceCandidate(from:))
        let status = LearningMaterialAnalysisStatus(rawValue: row["analysis_status"] as String) ?? .missing
        return LearningMaterial(
            id: materialID,
            entryID: row["entry_id"],
            spaceID: row["space_id"],
            inputKind: LearningMaterialInputKind(rawValue: row["input_kind"] as String) ?? .uncertain,
            promptMode: LearningMaterialPromptMode(rawValue: row["prompt_mode"] as String) ?? .automaticLearningMaterial,
            learningText: row["learning_text"],
            originalGeneratedText: row["original_generated_text"],
            revisionSummary: revisions,
            analysis: LearningMaterialAnalysis(
                status: status,
                sourceTextHash: row["analysis_source_hash"],
                sentences: sentences,
                memoryCandidates: memory,
                practiceCandidates: practice
            ),
            metadata: LearningMaterialGenerationMetadata(
                promptID: row["prompt_id"],
                promptVersion: row["prompt_version"],
                providerProfileID: row["provider_profile_id"],
                providerEndpointID: row["provider_endpoint_id"],
                providerPresetID: row["provider_preset_id"],
                modelName: row["model_name"],
                generatedAt: Date(timeIntervalSince1970: row["created_at"])
            ),
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"]),
            isCurrent: row["is_current"]
        )
    }

    func sentence(from row: Row) throws -> LearningSentenceAnalysis {
        try LearningSentenceAnalysis(
            id: row["id"],
            nativeSentence: row["native_sentence"],
            targetSentence: row["target_sentence"],
            literalTranslation: row["literal_translation"],
            naturalTranslation: row["natural_translation"],
            grammarNotes: decodedJSON(row["grammar_notes_json"] as String, as: VersionedStringList.self).values,
            keyPoints: decodedJSON(row["key_points_json"] as String, as: VersionedStringList.self).values,
            position: row["position"]
        )
    }

    func revision(from row: Row) -> LearningRevision {
        LearningRevision(
            id: row["id"],
            originalText: row["original_text"],
            revisedText: row["revised_text"],
            reasonNative: row["reason_native"],
            category: LearningRevision.Category(rawValue: row["category"] as String) ?? .clarity,
            position: row["position"]
        )
    }

    func memoryCandidate(from row: Row) -> LearningMemoryCandidate {
        LearningMemoryCandidate(
            id: row["id"],
            sentenceID: row["sentence_id"],
            kind: LearningMemoryCandidate.Kind(rawValue: row["kind"] as String) ?? .phrase,
            text: row["text"],
            explanationNative: row["explanation_native"],
            exampleTarget: row["example_target"],
            exampleNative: row["example_native"],
            difficulty: LearningMemoryCandidate.Difficulty(rawValue: row["difficulty"] as String) ?? .medium
        )
    }

    func practiceCandidate(from row: Row) -> LearningPracticeCandidate {
        LearningPracticeCandidate(
            id: row["id"],
            sentenceID: row["sentence_id"],
            kind: LearningPracticeCandidate.Kind(rawValue: row["kind"] as String) ?? .backTranslation,
            title: row["title"],
            promptText: row["prompt_text"],
            answerText: row["answer_text"]
        )
    }

    func memoryItem(from row: Row) -> MemoryItem {
        MemoryItem(
            id: row["id"],
            spaceID: row["space_id"],
            entryID: row["entry_id"],
            text: row["text"],
            note: row["explanation_native"]
        )
    }

    func practiceItem(from row: Row) -> PracticeItem {
        PracticeItem(
            id: row["id"],
            entryID: row["entry_id"],
            title: row["title"],
            kind: PracticeItem.Kind(rawValue: row["kind"] as String) ?? .backTranslation,
            summary: row["prompt_text"]
        )
    }

    func operation(from row: Row) -> LearningMaterialOperationSummary {
        LearningMaterialOperationSummary(
            operationID: DiagnosticOperationID(rawValue: row["operation_id"]),
            entryID: row["entry_id"],
            materialID: row["material_id"],
            kind: LearningMaterialOperationKind(rawValue: row["operation_kind"] as String) ?? .generate,
            status: LearningMaterialOperationStatus(rawValue: row["status"] as String) ?? .failed,
            failureCategory: (row["failure_category"] as String?).flatMap(LearningMaterialGenerationFailureCategory.init(rawValue:)),
            promptID: row["prompt_id"],
            promptVersion: row["prompt_version"],
            providerProfileID: row["provider_profile_id"],
            providerEndpointID: row["provider_endpoint_id"],
            providerPresetID: row["provider_preset_id"],
            modelName: row["model_name"],
            inputKind: (row["input_kind"] as String?).flatMap(LearningMaterialInputKind.init(rawValue:)),
            estimatedTokenBucket: LearningMaterialEstimatedTokenBucket(rawValue: row["estimated_token_bucket"] as String) ?? .short,
            durationMilliseconds: row["duration_ms"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            completedAt: (row["completed_at"] as Double?).map(Date.init(timeIntervalSince1970:))
        )
    }

    func operationArguments(_ summary: LearningMaterialOperationSummary) -> StatementArguments {
        [
            idGenerator(),
            summary.operationID.rawValue,
            summary.entryID,
            summary.materialID,
            summary.kind.rawValue,
            summary.status.rawValue,
            summary.failureCategory?.rawValue,
            summary.promptID,
            summary.promptVersion,
            summary.providerProfileID,
            summary.providerEndpointID,
            summary.providerPresetID,
            summary.modelName,
            summary.inputKind?.rawValue,
            summary.estimatedTokenBucket.rawValue,
            summary.durationMilliseconds,
            summary.createdAt.timeIntervalSince1970,
            summary.completedAt?.timeIntervalSince1970,
        ]
    }

    func encodedJSON(_ value: some Encodable) throws -> String {
        try String(decoding: jsonEncoder.encode(value), as: UTF8.self)
    }

    func decodedJSON<T: Decodable>(_ value: String, as type: T.Type) throws -> T {
        try jsonDecoder.decode(type, from: Data(value.utf8))
    }
}

public enum LearningContentRepositoryError: Error, Equatable, Sendable {
    case emptyEntryBody
    case emptyLearningText
    case languageSpaceNotFound
    case entryNotFound
    case materialNotFound
    case entryMismatch
    case spaceMismatch
}

private struct VersionedStringList: Codable {
    var schemaVersion = 1
    var values: [String]
}
