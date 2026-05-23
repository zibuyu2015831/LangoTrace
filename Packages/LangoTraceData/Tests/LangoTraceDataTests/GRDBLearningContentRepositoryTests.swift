import Foundation
import GRDB
import LangoTraceCore
@testable import LangoTraceData
import Testing

@Test("Learning content migration creates tables and enforces enum checks")
func learningContentMigrationCreatesTablesAndEnforcesEnumChecks() throws {
    let database = try AppDatabase.inMemory()

    try database.databaseQueue.write { db in
        let tableNames = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        #expect(tableNames.contains("entries"))
        #expect(tableNames.contains("learning_materials"))
        #expect(tableNames.contains("learning_material_operations"))

        try insertLanguageSpace(id: "space-1", db: db)

        #expect(throws: DatabaseError.self) {
            try db.execute(
                sql: """
                INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
                VALUES ('entry-1', 'space-1', 'Title', 'Body', 'invalidSource', '生活记录', 100, 100, NULL)
                """
            )
        }

        #expect(throws: DatabaseError.self) {
            try db.execute(
                sql: """
                INSERT INTO entries (id, space_id, title, body, source, scene, created_at, updated_at, deleted_at)
                VALUES ('entry-2', 'missing-space', 'Title', 'Body', 'typedText', '生活记录', 100, 100, NULL)
                """
            )
        }
    }
}

@Test("Learning content migrates a v3 database built by SQL helper")
func learningContentMigratesV3DatabaseBuiltBySQLHelper() throws {
    let queue = try DatabaseQueue()
    try AppDatabaseTestSupport.migrateToV3(queue)
    try queue.write { db in
        try insertLanguageSpace(id: "space-v3", db: db)
        try db.execute(sql: """
        INSERT INTO diagnostic_events (id, name, domain, level, attributes_json, created_at)
        VALUES ('event-1', 'ai_provider_settings.save_started', 'ai_provider_settings', 'info', '{}', 100)
        """)
    }

    let database = try AppDatabase(databaseQueue: queue)
    let repository = GRDBLearningContentRepository(database: database, clock: { Date(timeIntervalSince1970: 200) }, idGenerator: IncrementingIDGenerator().next)

    let entry = try repository.createEntry(
        NewLearningEntryDraft(title: "迁移后记录", body: "今天测试迁移。", source: .typedText, scene: "生活记录"),
        in: "space-v3"
    )

    #expect(entry.spaceID == "space-v3")
    #expect(try repository.entries(for: "space-v3").map(\.id) == [entry.id])
}

@Test("GRDB learning repository creates entries without generated material")
func grdbLearningRepositoryCreatesEntriesWithoutGeneratedMaterial() throws {
    let repository = try makeRepository()

    let entry = try repository.createEntry(
        NewLearningEntryDraft(title: "晚饭散步", body: "晚饭后我绕着小区走了一圈。", source: .typedText, scene: "生活记录"),
        in: "space-1"
    )

    #expect(entry.body == "晚饭后我绕着小区走了一圈。")
    #expect(try repository.currentMaterial(for: entry.id) == nil)
    #expect(try repository.entries(for: "space-1").map(\.id) == [entry.id])
}

@Test("Saving generated material does not modify original entry body and stores current material")
func savingGeneratedMaterialDoesNotModifyEntryBody() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(body: "我今天在咖啡馆写了一页日记。"), in: "space-1")
    let result = sampleGenerationResult(
        entryID: entry.id,
        spaceID: "space-1",
        learningText: "I wrote a page in my journal at a cafe today."
    )

    let material = try repository.saveGeneratedMaterial(result, for: entry.id)

    #expect(material.learningText == "I wrote a page in my journal at a cafe today.")
    #expect(material.analysis.status == .fresh)
    #expect(try repository.entry(id: entry.id)?.body == "我今天在咖啡馆写了一页日记。")
    #expect(try repository.currentMaterial(for: entry.id)?.id == material.id)
    #expect(try repository.memoryItems(for: "space-1").map(\.entryID) == [entry.id])
    #expect(try repository.practiceItems(for: entry.id).count == 1)
}

@Test("Saving generated material can persist succeeded operation in the same repository write")
func savingGeneratedMaterialPersistsSucceededOperationAtomically() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    let operationID = DiagnosticOperationID(rawValue: "operation-transaction")
    let result = sampleGenerationResult(entryID: entry.id, spaceID: "space-1")

    let material = try repository.saveGeneratedMaterial(
        result,
        for: entry.id,
        operationSummary: LearningMaterialOperationSummary(
            operationID: operationID,
            entryID: entry.id,
            materialID: nil,
            kind: .generate,
            status: .succeeded,
            failureCategory: nil,
            promptID: result.metadata.promptID,
            promptVersion: result.metadata.promptVersion,
            providerProfileID: result.metadata.providerProfileID,
            providerEndpointID: result.metadata.providerEndpointID,
            providerPresetID: result.metadata.providerPresetID,
            modelName: result.metadata.modelName,
            inputKind: result.inputKind,
            estimatedTokenBucket: .short,
            durationMilliseconds: nil,
            createdAt: result.metadata.generatedAt,
            completedAt: Date(timeIntervalSince1970: 101)
        )
    )

    let operations = try repository.operations(for: entry.id)
    #expect(material.id == operations.first?.materialID)
    #expect(operations.count == 1)
    #expect(operations.first?.status == .succeeded)
    #expect(operations.first?.operationID == operationID)
}

@Test("Editing learning text marks analysis stale without changing entry or generated snapshot")
func editingLearningTextMarksAnalysisStale() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(body: "我今天在咖啡馆写了一页日记。"), in: "space-1")
    let material = try repository.saveGeneratedMaterial(sampleGenerationResult(entryID: entry.id, spaceID: "space-1"), for: entry.id)

    let edited = try repository.updateLearningText(materialID: material.id, learningText: "I wrote in my journal at the cafe today.")

    #expect(edited.learningText == "I wrote in my journal at the cafe today.")
    #expect(edited.originalGeneratedText == material.originalGeneratedText)
    #expect(edited.analysis.status == .stale)
    #expect(try repository.entry(id: entry.id)?.body == "我今天在咖啡馆写了一页日记。")
}

@Test("Repository loads material by material id for app orchestration")
func repositoryLoadsMaterialByID() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    let saved = try repository.saveGeneratedMaterial(sampleGenerationResult(entryID: entry.id, spaceID: "space-1"), for: entry.id)

    let loaded = try repository.material(id: saved.id)

    #expect(loaded?.id == saved.id)
    #expect(loaded?.entryID == entry.id)
}

@Test("Replacing analysis keeps edited learning text and refreshes candidates")
func replacingAnalysisKeepsEditedLearningText() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(body: "我今天在咖啡馆写了一页日记。"), in: "space-1")
    let material = try repository.saveGeneratedMaterial(sampleGenerationResult(entryID: entry.id, spaceID: "space-1"), for: entry.id)
    let edited = try repository.updateLearningText(materialID: material.id, learningText: "I wrote in my journal at the cafe today.")

    let refreshed = try repository.replaceAnalysis(sampleAnalysisResult(materialID: edited.id), materialID: edited.id)

    #expect(refreshed.learningText == edited.learningText)
    #expect(refreshed.analysis.status == .fresh)
    #expect(refreshed.analysis.sentences.first?.targetSentence == "I wrote in my journal at the cafe today.")
}

@Test("Replacing analysis can persist succeeded operation in the same repository write")
func replacingAnalysisPersistsSucceededOperationAtomically() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    let material = try repository.saveGeneratedMaterial(sampleGenerationResult(entryID: entry.id, spaceID: "space-1"), for: entry.id)
    let result = sampleAnalysisResult(materialID: material.id)
    let operationID = DiagnosticOperationID(rawValue: "analysis-transaction")

    let refreshed = try repository.replaceAnalysis(
        result,
        materialID: material.id,
        operationSummary: LearningMaterialOperationSummary(
            operationID: operationID,
            entryID: entry.id,
            materialID: material.id,
            kind: .analyze,
            status: .succeeded,
            failureCategory: nil,
            promptID: "builtin.learning_material.analyze.v1",
            promptVersion: "1",
            providerProfileID: material.metadata.providerProfileID,
            providerEndpointID: material.metadata.providerEndpointID,
            providerPresetID: material.metadata.providerPresetID,
            modelName: material.metadata.modelName,
            inputKind: material.inputKind,
            estimatedTokenBucket: .short,
            durationMilliseconds: nil,
            createdAt: material.updatedAt,
            completedAt: Date(timeIntervalSince1970: 101)
        )
    )

    let operations = try repository.operations(for: entry.id)
    #expect(refreshed.analysis.status == .fresh)
    #expect(operations.count == 1)
    #expect(operations.first?.materialID == material.id)
    #expect(operations.first?.status == .succeeded)
}

@Test("Operation summaries update one row for lifecycle")
func operationSummariesUpdateOneRowForLifecycle() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    let operationID = DiagnosticOperationID(rawValue: "operation-1")

    try repository.recordOperation(.started(operationID: operationID, entryID: entry.id, kind: .generate, bucket: .short))
    try repository.recordOperation(.failed(
        operationID: operationID,
        entryID: entry.id,
        kind: .generate,
        failureCategory: .timeout,
        bucket: .short,
        completedAt: Date(timeIntervalSince1970: 200)
    ))

    let operations = try repository.operations(for: entry.id)
    #expect(operations.count == 1)
    #expect(operations.first?.operationID == operationID)
    #expect(operations.first?.status == .failed)
    #expect(operations.first?.failureCategory == .timeout)
}

@Test("Deleting entry hides current material memory and practice candidates")
func deletingEntryHidesActiveLearningContent() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    _ = try repository.saveGeneratedMaterial(sampleGenerationResult(entryID: entry.id, spaceID: "space-1"), for: entry.id)

    try repository.deleteEntry(id: entry.id)

    #expect(try repository.entries(for: "space-1").isEmpty)
    #expect(try repository.currentMaterial(for: entry.id) == nil)
    #expect(try repository.memoryItems(for: "space-1").isEmpty)
    #expect(try repository.practiceItems(for: entry.id).isEmpty)
}

@Test("GRDB bridge exposes persisted learning content through UI repository contract")
func grdbBridgeExposesPersistedLearningContent() throws {
    let repository = try makeRepository()
    let bridge = GRDBLearningContentRepositoryBridge(repository: repository)

    let entry = try bridge.createEntry(
        spaceID: "space-1",
        title: "咖啡馆",
        body: "我今天在咖啡馆写了一页日记。",
        source: .typedText
    )
    _ = try repository.saveGeneratedMaterial(
        sampleGenerationResult(
            entryID: entry.id,
            spaceID: "space-1",
            learningText: "I wrote a page in my journal at a cafe today."
        ),
        for: entry.id
    )

    let rendering = bridge.rendering(for: entry.id)

    #expect(bridge.entries(for: "space-1").map(\.id) == [entry.id])
    #expect(bridge.selectedEntry(for: "space-1")?.id == entry.id)
    #expect(rendering?.entryID == entry.id)
    #expect(rendering?.targetText == "I wrote a page in my journal at a cafe today.")
    #expect(rendering?.isMock == false)
    #expect(rendering?.sentences.first?.targetText == "I went to a cafe today.")
    #expect(bridge.practiceItems(for: entry.id).map(\.kind) == [.backTranslation])
    #expect(bridge.memoryItems(for: "space-1").map(\.text) == ["went to"])
    #expect(bridge.practiceSession(for: entry.id)?.isExternalRequestRequired == true)
}

@Test("GRDB bridge does not synthesize local preview material")
func grdbBridgeDoesNotSynthesizeLocalPreviewMaterial() throws {
    let repository = try makeRepository()
    let bridge = GRDBLearningContentRepositoryBridge(repository: repository)
    let entry = try bridge.createEntry(
        spaceID: "space-1",
        title: "散步",
        body: "晚饭后我散步。",
        source: .typedText
    )

    let preview = bridge.generateLocalPreview(for: entry.id, spaceID: "space-1")

    #expect(preview == nil)
    #expect(try repository.currentMaterial(for: entry.id) == nil)
}

@Test("GRDB bridge surfaces create failures instead of returning unsaved entries")
func grdbBridgeSurfacesCreateFailures() throws {
    let repository = try makeRepository()
    let bridge = GRDBLearningContentRepositoryBridge(repository: repository)

    #expect(throws: Error.self) {
        _ = try bridge.createEntry(
            spaceID: "missing-space",
            title: "Missing",
            body: "This should not become an unsaved entry.",
            source: .typedText
        )
    }
}

private func makeRepository() throws -> GRDBLearningContentRepository {
    let database = try AppDatabase.inMemory()
    try database.databaseQueue.write { db in
        try insertLanguageSpace(id: "space-1", db: db)
    }
    return GRDBLearningContentRepository(
        database: database,
        clock: { Date(timeIntervalSince1970: 100) },
        idGenerator: IncrementingIDGenerator().next
    )
}

private func sampleDraft(body: String = "今天我去咖啡馆。") -> NewLearningEntryDraft {
    NewLearningEntryDraft(title: "咖啡馆", body: body, source: .typedText, scene: "生活记录")
}

private func sampleGenerationResult(
    entryID: String,
    spaceID: String,
    learningText: String = "I went to a cafe today."
) -> LearningMaterialGenerationResult {
    LearningMaterialGenerationResult(
        entryID: entryID,
        spaceID: spaceID,
        inputKind: .nativeRecord,
        promptMode: .automaticLearningMaterial,
        learningText: learningText,
        revisionSummary: [],
        analysis: sampleAnalysis(),
        metadata: LearningMaterialGenerationMetadata(
            promptID: "builtin.learning_material.generate.v1",
            promptVersion: "1",
            providerProfileID: "profile-1",
            providerEndpointID: "endpoint-1",
            providerPresetID: "openai",
            modelName: "gpt-4.1-mini",
            generatedAt: Date(timeIntervalSince1970: 100)
        )
    )
}

private func sampleAnalysisResult(materialID: String) -> LearningMaterialAnalysisResult {
    LearningMaterialAnalysisResult(materialID: materialID, analysis: sampleAnalysis(targetSentence: "I wrote in my journal at the cafe today."))
}

private func sampleAnalysis(targetSentence: String = "I went to a cafe today.") -> LearningMaterialAnalysis {
    LearningMaterialAnalysis(
        status: .fresh,
        sourceTextHash: "",
        sentences: [
            LearningSentenceAnalysis(
                id: "sentence-1",
                nativeSentence: "我今天去咖啡馆。",
                targetSentence: targetSentence,
                literalTranslation: "I today went to cafe.",
                naturalTranslation: targetSentence,
                grammarNotes: ["Past tense verb"],
                keyPoints: ["went to"],
                position: 0
            ),
        ],
        memoryCandidates: [
            LearningMemoryCandidate(
                id: "memory-1",
                sentenceID: "sentence-1",
                kind: .phrase,
                text: "went to",
                explanationNative: "表示去了某处",
                exampleTarget: targetSentence,
                exampleNative: "我今天去了咖啡馆。",
                difficulty: .easy
            ),
        ],
        practiceCandidates: [
            LearningPracticeCandidate(
                id: "practice-1",
                sentenceID: "sentence-1",
                kind: .backTranslation,
                title: "回译",
                promptText: "我今天去了咖啡馆。",
                answerText: targetSentence
            ),
        ]
    )
}

private func insertLanguageSpace(id: String, db: Database) throws {
    try db.execute(
        sql: """
        INSERT INTO language_spaces (
            id, native_language_code, target_language_code, level,
            display_name, display_name_normalized, created_at, updated_at,
            last_opened_at, deleted_at
        ) VALUES (?, 'zh-Hans', 'en', 'b1', 'English', 'english', 1, 1, 1, NULL)
        """,
        arguments: [id]
    )
}

private final class IncrementingIDGenerator: @unchecked Sendable {
    private var nextValue = 0

    func next() -> String {
        nextValue += 1
        return "generated-\(nextValue)"
    }
}

private enum AppDatabaseTestSupport {
    // swiftlint:disable:next function_body_length
    static func migrateToV3(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_language_space_infrastructure") { db in
            try db.execute(sql: """
            CREATE TABLE language_spaces (
                id TEXT PRIMARY KEY,
                native_language_code TEXT NOT NULL,
                target_language_code TEXT NOT NULL,
                level TEXT NOT NULL,
                display_name TEXT NOT NULL,
                display_name_normalized TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                last_opened_at REAL,
                deleted_at REAL
            )
            """)
            try db.execute(sql: "CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT, updated_at REAL NOT NULL)")
        }
        migrator.registerMigration("v2_create_ai_provider_configuration") { db in
            try db.execute(sql: """
            CREATE TABLE ai_provider_profiles (
                id TEXT PRIMARY KEY,
                display_name TEXT NOT NULL,
                is_default BOOLEAN NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                last_validated_at REAL,
                last_validation_status TEXT,
                deleted_at REAL
            )
            """)
            try db.execute(sql: """
            CREATE TABLE ai_provider_credentials (
                id TEXT PRIMARY KEY,
                profile_id TEXT NOT NULL REFERENCES ai_provider_profiles(id) ON DELETE CASCADE,
                provider_preset_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                label TEXT NOT NULL,
                keychain_service TEXT NOT NULL,
                keychain_account TEXT NOT NULL,
                keychain_access_group TEXT,
                keychain_synchronizable BOOLEAN NOT NULL,
                keychain_accessibility TEXT NOT NULL,
                secret_presence TEXT NOT NULL,
                cleanup_state TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                last_resolved_at REAL,
                deleted_at REAL
            )
            """)
            try db.execute(sql: """
            CREATE TABLE ai_provider_endpoints (
                id TEXT PRIMARY KEY,
                profile_id TEXT NOT NULL REFERENCES ai_provider_profiles(id) ON DELETE CASCADE,
                purpose TEXT NOT NULL,
                is_enabled BOOLEAN NOT NULL,
                provider_preset_id TEXT NOT NULL,
                adapter_kind TEXT NOT NULL,
                base_url TEXT NOT NULL,
                model_name TEXT NOT NULL,
                credential_id TEXT REFERENCES ai_provider_credentials(id) ON DELETE RESTRICT,
                supports_image_input BOOLEAN NOT NULL,
                image_input_enabled BOOLEAN NOT NULL,
                request_timeout_seconds REAL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                deleted_at REAL
            )
            """)
            try db.execute(sql: """
            CREATE TABLE ai_provider_custom_headers (
              id TEXT PRIMARY KEY,
              endpoint_id TEXT NOT NULL REFERENCES ai_provider_endpoints(id) ON DELETE CASCADE,
              header_name TEXT NOT NULL,
              header_name_normalized TEXT NOT NULL,
              value_kind TEXT NOT NULL,
              plain_value TEXT,
              credential_id TEXT REFERENCES ai_provider_credentials(id) ON DELETE RESTRICT,
              created_at REAL NOT NULL,
              updated_at REAL NOT NULL
            )
            """)
            try db.execute(sql: """
            CREATE TABLE ai_provider_validation_events (
              id TEXT PRIMARY KEY,
              profile_id TEXT NOT NULL REFERENCES ai_provider_profiles(id) ON DELETE CASCADE,
              endpoint_id TEXT REFERENCES ai_provider_endpoints(id) ON DELETE SET NULL,
              event_type TEXT NOT NULL,
              status TEXT NOT NULL,
              error_category TEXT,
              provider_preset_id TEXT NOT NULL,
              model_name TEXT,
              duration_ms INTEGER,
              created_at REAL NOT NULL
            )
            """)
        }
        migrator.registerMigration("v3_create_diagnostic_events") { db in
            try db.execute(sql: """
            CREATE TABLE diagnostic_events (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                domain TEXT NOT NULL,
                level TEXT NOT NULL,
                outcome TEXT,
                operation_id TEXT,
                attributes_json TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """)
        }
        try migrator.migrate(queue)
    }
}
