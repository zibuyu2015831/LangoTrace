import Foundation
import GRDB
import LangoTraceCore

public struct GRDBLearningContentRepository: @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let clock: @Sendable () -> Date
    private let idGenerator: @Sendable () -> String
    private let diagnosticLogger: any DiagnosticLogging
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    public init(
        database: AppDatabase,
        clock: @escaping @Sendable () -> Date = Date.init,
        idGenerator: @escaping @Sendable () -> String = { UUID().uuidString },
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger()
    ) {
        databaseQueue = database.databaseQueue
        self.clock = clock
        self.idGenerator = idGenerator
        self.diagnosticLogger = diagnosticLogger
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
                title: title,
                body: body,
                source: draft.source,
                scene: scene,
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

    public func updateEntryBody(entryID: String, spaceID: String, body: String) throws -> LearningEntry {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LearningContentRepositoryError.emptyEntryBody }

        return try databaseQueue.write { db in
            guard let existing = try fetchActiveEntry(id: entryID, db: db) else {
                throw LearningContentRepositoryError.entryNotFound
            }
            guard existing.spaceID == spaceID else {
                throw LearningContentRepositoryError.spaceMismatch
            }
            let now = clock().timeIntervalSince1970
            try db.execute(
                sql: """
                UPDATE entries
                SET body = ?, updated_at = ?
                WHERE id = ? AND space_id = ? AND deleted_at IS NULL
                """,
                arguments: [trimmed, now, entryID, spaceID]
            )
            guard let entry = try fetchActiveEntry(id: entryID, db: db) else {
                throw LearningContentRepositoryError.entryNotFound
            }
            return entry
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

    /// Returns the rich per-sentence analysis for a material sentence by its
    /// position, or `nil` if no such sentence exists. This is the read seam for
    /// backtranslation (E5): the lossy `RenderingSentence` projection drops
    /// `naturalTranslation` / `literalTranslation` / `keyPoints`, so a fuller
    /// analysis read is needed. Reuses the existing `sentence(from:)` row parser.
    /// Fully local, read-only — no network.
    public func sentenceAnalysis(materialID: String, sentenceIndex: Int) throws -> LearningSentenceAnalysis? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM learning_material_sentences
                WHERE material_id = ? AND position = ?
                LIMIT 1
                """,
                arguments: [materialID, sentenceIndex]
            ) else {
                return nil
            }
            return try sentence(from: row)
        }
    }

    public func saveGeneratedMaterial(_ result: LearningMaterialGenerationResult, for entryID: String) throws -> LearningMaterial {
        try databaseQueue.write { db in
            try saveGeneratedMaterial(result, for: entryID, db: db)
        }
    }

    public func saveGeneratedMaterial(
        _ result: LearningMaterialGenerationResult,
        for entryID: String,
        operationSummary: LearningMaterialOperationSummary
    ) throws -> LearningMaterial {
        try databaseQueue.write { db in
            guard try !isOperationCancelled(operationSummary.operationID, db: db) else {
                throw LearningContentRepositoryError.operationCancelled
            }
            let material = try saveGeneratedMaterial(result, for: entryID, db: db)
            var summary = operationSummary
            summary.materialID = material.id
            try recordOperation(summary, db: db)
            return material
        }
    }

    private func saveGeneratedMaterial(
        _ result: LearningMaterialGenerationResult,
        for entryID: String,
        db: Database
    ) throws -> LearningMaterial {
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
        let sourceEntryBodyHash = LearningMaterialTextHash.sha256(for: entry.body)
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
            sourceEntryBodyHash: sourceEntryBodyHash,
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
            try replaceAnalysis(result, materialID: materialID, db: db)
        }
    }

    public func replaceAnalysis(
        _ result: LearningMaterialAnalysisResult,
        materialID: String,
        operationSummary: LearningMaterialOperationSummary
    ) throws -> LearningMaterial {
        try databaseQueue.write { db in
            let material = try replaceAnalysis(result, materialID: materialID, db: db)
            var summary = operationSummary
            summary.materialID = material.id
            try recordOperation(summary, db: db)
            return material
        }
    }

    private func replaceAnalysis(
        _ result: LearningMaterialAnalysisResult,
        materialID: String,
        db: Database
    ) throws -> LearningMaterial {
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

    public func recordOperation(_ summary: LearningMaterialOperationSummary) throws {
        try databaseQueue.write { db in
            try recordOperation(summary, db: db)
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

    public func learningPracticeReadiness(for spaceID: String) throws -> [String: Bool] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT e.id AS entry_id,
                       EXISTS(
                           SELECT 1 FROM practice_sessions ps
                           WHERE ps.entry_id = e.id
                             AND ps.completed_recording_id IS NOT NULL
                       ) AS has_completed_recording
                FROM entries e
                JOIN learning_materials lm ON lm.entry_id = e.id
                    AND lm.deleted_at IS NULL
                    AND lm.is_current = 1
                WHERE e.space_id = ? AND e.deleted_at IS NULL
                """,
                arguments: [spaceID]
            )
            var result: [String: Bool] = [:]
            for row in rows {
                let entryID: String = row["entry_id"]
                let hasCompleted: Bool = (row["has_completed_recording"] as Int) != 0
                result[entryID] = hasCompleted
            }
            return result
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
    func recordOperation(_ summary: LearningMaterialOperationSummary, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO learning_material_operations (
                id, operation_id, entry_id, material_id, operation_kind, status,
                failure_category, prompt_id, prompt_version, provider_profile_id,
                provider_endpoint_id, provider_preset_id, model_name, input_kind,
                estimated_token_bucket, duration_ms, created_at, completed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(operation_id) DO UPDATE SET
                material_id = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.material_id
                    ELSE excluded.material_id
                END,
                status = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.status
                    ELSE excluded.status
                END,
                failure_category = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.failure_category
                    ELSE excluded.failure_category
                END,
                provider_profile_id = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.provider_profile_id
                    ELSE excluded.provider_profile_id
                END,
                provider_endpoint_id = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.provider_endpoint_id
                    ELSE excluded.provider_endpoint_id
                END,
                provider_preset_id = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.provider_preset_id
                    ELSE excluded.provider_preset_id
                END,
                model_name = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.model_name
                    ELSE excluded.model_name
                END,
                input_kind = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.input_kind
                    ELSE excluded.input_kind
                END,
                estimated_token_bucket = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.estimated_token_bucket
                    ELSE excluded.estimated_token_bucket
                END,
                duration_ms = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.duration_ms
                    ELSE excluded.duration_ms
                END,
                completed_at = CASE
                    WHEN learning_material_operations.status = 'cancelled'
                    THEN learning_material_operations.completed_at
                    ELSE excluded.completed_at
                END
            """,
            arguments: operationArguments(summary)
        )
    }

    func isOperationCancelled(_ operationID: DiagnosticOperationID, db: Database) throws -> Bool {
        try String.fetchOne(
            db,
            sql: "SELECT status FROM learning_material_operations WHERE operation_id = ?",
            arguments: [operationID.rawValue]
        ) == LearningMaterialOperationStatus.cancelled.rawValue
    }

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
        sourceEntryBodyHash: String,
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
                original_generated_text, source_entry_body_hash, analysis_source_hash, analysis_status,
                prompt_id, prompt_version, provider_profile_id, provider_endpoint_id,
                provider_preset_id, model_name, is_current, created_at, updated_at, deleted_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
            """,
            arguments: [
                id,
                entryID,
                spaceID,
                inputKind.rawValue,
                promptMode.rawValue,
                learningText,
                originalGeneratedText,
                sourceEntryBodyHash,
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
        // Prefix all child IDs with materialID to ensure global uniqueness across
        // multiple generations of the same entry. The AI service produces deterministic
        // positional IDs (e.g. "sentence-0") that would collide if inserted as-is.
        for sentence in analysis.sentences {
            let persistedSentenceID = "\(materialID)-\(sentence.id)"
            try db.execute(
                sql: """
                INSERT INTO learning_material_sentences (
                    id, material_id, position, native_sentence, target_sentence,
                    literal_translation, natural_translation, grammar_notes_json,
                    key_points_json, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    persistedSentenceID,
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
            let persistedRevisionID = "\(materialID)-\(revision.id)"
            try db.execute(
                sql: """
                INSERT INTO learning_material_revision_notes (
                    id, material_id, position, original_text, revised_text,
                    reason_native, category, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    persistedRevisionID,
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
            let persistedCandidateID = "\(materialID)-\(candidate.id)"
            let persistedSentenceRef = candidate.sentenceID.map { "\(materialID)-\($0)" }
            try db.execute(
                sql: """
                INSERT INTO memory_candidates (
                    id, space_id, entry_id, material_id, sentence_id, kind, text,
                    explanation_native, example_target, example_native, difficulty,
                    status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)
                """,
                arguments: [
                    persistedCandidateID,
                    spaceID,
                    entryID,
                    materialID,
                    persistedSentenceRef,
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
            let persistedCandidateID = "\(materialID)-\(candidate.id)"
            let persistedSentenceRef = candidate.sentenceID.map { "\(materialID)-\($0)" }
            try db.execute(
                sql: """
                INSERT INTO practice_candidates (
                    id, space_id, entry_id, material_id, sentence_id, kind, title,
                    prompt_text, answer_text, status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)
                """,
                arguments: [
                    persistedCandidateID,
                    spaceID,
                    entryID,
                    materialID,
                    persistedSentenceRef,
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
            source: StoredEnumDecoding.decode(EntrySource.self, from: row["source"] as String, fallback: .typedText, context: "entries.source", diagnosticLogger: diagnosticLogger, clock: clock),
            scene: row["scene"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
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
        let status = StoredEnumDecoding.decode(
            LearningMaterialAnalysisStatus.self,
            from: row["analysis_status"] as String,
            fallback: .missing,
            context: "learning_materials.analysis_status",
            diagnosticLogger: diagnosticLogger,
            clock: clock
        )
        return LearningMaterial(
            id: materialID,
            entryID: row["entry_id"],
            spaceID: row["space_id"],
            inputKind: StoredEnumDecoding.decode(
                LearningMaterialInputKind.self,
                from: row["input_kind"] as String,
                fallback: .uncertain,
                context: "learning_materials.input_kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            promptMode: StoredEnumDecoding.decode(
                LearningMaterialPromptMode.self,
                from: row["prompt_mode"] as String,
                fallback: .automaticLearningMaterial,
                context: "learning_materials.prompt_mode",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            learningText: row["learning_text"],
            originalGeneratedText: row["original_generated_text"],
            sourceEntryBodyHash: row["source_entry_body_hash"],
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
            category: StoredEnumDecoding.decode(
                LearningRevision.Category.self,
                from: row["category"] as String,
                fallback: .clarity,
                context: "learning_revisions.category",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            position: row["position"]
        )
    }

    func memoryCandidate(from row: Row) -> LearningMemoryCandidate {
        LearningMemoryCandidate(
            id: row["id"],
            sentenceID: row["sentence_id"],
            kind: StoredEnumDecoding.decode(
                LearningMemoryCandidate.Kind.self,
                from: row["kind"] as String,
                fallback: .phrase,
                context: "learning_memory_candidates.kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            text: row["text"],
            explanationNative: row["explanation_native"],
            exampleTarget: row["example_target"],
            exampleNative: row["example_native"],
            difficulty: StoredEnumDecoding.decode(
                LearningMemoryCandidate.Difficulty.self,
                from: row["difficulty"] as String,
                fallback: .medium,
                context: "learning_memory_candidates.difficulty",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            )
        )
    }

    func practiceCandidate(from row: Row) -> LearningPracticeCandidate {
        LearningPracticeCandidate(
            id: row["id"],
            sentenceID: row["sentence_id"],
            kind: StoredEnumDecoding.decode(
                LearningPracticeCandidate.Kind.self,
                from: row["kind"] as String,
                fallback: .backTranslation,
                context: "learning_practice_candidates.kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
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
            kind: StoredEnumDecoding.decode(
                PracticeItem.Kind.self,
                from: row["kind"] as String,
                fallback: .backTranslation,
                context: "practice_items.kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            summary: row["prompt_text"]
        )
    }

    func operation(from row: Row) -> LearningMaterialOperationSummary {
        LearningMaterialOperationSummary(
            operationID: DiagnosticOperationID(rawValue: row["operation_id"]),
            entryID: row["entry_id"],
            materialID: row["material_id"],
            kind: StoredEnumDecoding.decode(
                LearningMaterialOperationKind.self,
                from: row["operation_kind"] as String,
                fallback: .generate,
                context: "learning_material_operations.operation_kind",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            status: StoredEnumDecoding.decode(
                LearningMaterialOperationStatus.self,
                from: row["status"] as String,
                fallback: .failed,
                context: "learning_material_operations.status",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            failureCategory: (row["failure_category"] as String?).flatMap(LearningMaterialGenerationFailureCategory.init(rawValue:)),
            promptID: row["prompt_id"],
            promptVersion: row["prompt_version"],
            providerProfileID: row["provider_profile_id"],
            providerEndpointID: row["provider_endpoint_id"],
            providerPresetID: row["provider_preset_id"],
            modelName: row["model_name"],
            inputKind: (row["input_kind"] as String?).flatMap(LearningMaterialInputKind.init(rawValue:)),
            estimatedTokenBucket: StoredEnumDecoding.decode(
                LearningMaterialEstimatedTokenBucket.self,
                from: row["estimated_token_bucket"] as String,
                fallback: .short,
                context: "learning_material_operations.estimated_token_bucket",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
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
    case databaseUnavailable
    case emptyEntryBody
    case emptyLearningText
    case languageSpaceNotFound
    case entryNotFound
    case materialNotFound
    case entryMismatch
    case spaceMismatch
    case operationCancelled
}

private struct VersionedStringList: Codable {
    var schemaVersion = 1
    var values: [String]
}
