import Foundation
import GRDB
import LangoTraceCore

/// Persists the Language Companion conversation (LM03-S1). One active thread per
/// space; messages are linearly sequenced so "delete this message and everything
/// after it" (ADR-008 §4) is well-defined. Reads / writes through the injected
/// `DatabaseWriter` (the LM02-S1 writer seam).
public struct GRDBCompanionRepository: Sendable {
    private let writer: DatabaseWriter

    public init(writer: DatabaseWriter) {
        self.writer = writer
    }

    // MARK: - Thread

    /// Returns the single active thread for `spaceID`, creating it (with the given
    /// plan-A `sourceEntryID` origin) if none exists yet.
    public func loadOrCreateThread(
        spaceID: String,
        sourceEntryID: String? = nil,
        id: @autoclosure () -> String = UUID().uuidString,
        now: Date = Date()
    ) throws -> CompanionThread {
        try writer.write { db in
            if let existing = try Self.thread(from: Row.fetchOne(
                db,
                sql: "SELECT id, space_id, source_entry_id, created_at FROM companion_threads WHERE space_id = ? ORDER BY created_at ASC, id ASC LIMIT 1",
                arguments: [spaceID]
            )) {
                return existing
            }
            let thread = CompanionThread(
                id: id(),
                languageSpaceID: spaceID,
                sourceEntryID: sourceEntryID,
                createdAt: now
            )
            try db.execute(
                sql: """
                INSERT INTO companion_threads
                (id, space_id, source_entry_id, sync_policy, backup_policy, export_policy, created_at)
                VALUES (?, ?, ?, 'localOnly', 'includedInSystemBackup', 'includedByDefault', ?)
                """,
                arguments: [thread.id, thread.languageSpaceID, thread.sourceEntryID, now.timeIntervalSince1970]
            )
            return thread
        }
    }

    /// Looks up a thread by id (for resolving its space + plan-A seed at send time).
    public func thread(id: String) throws -> CompanionThread? {
        try writer.read { db in
            try Self.thread(from: Row.fetchOne(
                db,
                sql: "SELECT id, space_id, source_entry_id, created_at FROM companion_threads WHERE id = ?",
                arguments: [id]
            ))
        }
    }

    // MARK: - Messages

    /// Appends a message to a thread, assigning the next linear sequence inside
    /// the write transaction. Returns the persisted message.
    @discardableResult
    public func appendMessage(
        threadID: String,
        role: CompanionMessageRole,
        content: String,
        detectedLanguage: String? = nil,
        targetLanguageCode: String,
        inputModality: CompanionInputModality = .text,
        id: @autoclosure () -> String = UUID().uuidString,
        now: Date = Date()
    ) throws -> CompanionMessage {
        try writer.write { db in
            let nextSequence = try (Int.fetchOne(
                db,
                sql: "SELECT MAX(sequence) FROM companion_messages WHERE thread_id = ?",
                arguments: [threadID]
            ).map { $0 + 1 }) ?? 0
            let message = CompanionMessage(
                id: id(),
                threadID: threadID,
                sequence: nextSequence,
                role: role,
                content: content,
                detectedLanguage: detectedLanguage,
                targetLanguageCode: targetLanguageCode,
                inputModality: inputModality,
                audioArtifactID: nil,
                createdAt: now
            )
            try db.execute(
                sql: """
                INSERT INTO companion_messages
                (id, thread_id, sequence, role, content, detected_language, target_language_code,
                 input_modality, audio_artifact_id, sync_policy, backup_policy, export_policy, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, 'localOnly', 'includedInSystemBackup', 'includedByDefault', ?)
                """,
                arguments: [
                    message.id, message.threadID, message.sequence, message.role.rawValue,
                    message.content, message.detectedLanguage, message.targetLanguageCode,
                    message.inputModality.rawValue, now.timeIntervalSince1970,
                ]
            )
            return message
        }
    }

    /// All messages of a thread, ordered by sequence.
    public func messages(threadID: String) throws -> [CompanionMessage] {
        try writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, thread_id, sequence, role, content, detected_language,
                       target_language_code, input_modality, audio_artifact_id, created_at
                FROM companion_messages
                WHERE thread_id = ?
                ORDER BY sequence ASC
                """,
                arguments: [threadID]
            )
            return rows.compactMap(Self.message(from:))
        }
    }

    /// Deletes a message AND every message after it (linear-context self-consistency).
    public func deleteMessageAndSubsequent(messageID: String) throws {
        try writer.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT thread_id, sequence FROM companion_messages WHERE id = ?",
                arguments: [messageID]
            ) else { return }
            let threadID: String = row["thread_id"]
            let sequence: Int = row["sequence"]
            try db.execute(
                sql: "DELETE FROM companion_messages WHERE thread_id = ? AND sequence >= ?",
                arguments: [threadID, sequence]
            )
        }
    }

    /// Removes all messages of a thread (清空 / restart). The thread row and
    /// per-space persona survive; system-level data is untouched (ADR-008 §4).
    public func clearThread(threadID: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM companion_messages WHERE thread_id = ?",
                arguments: [threadID]
            )
        }
    }

    // MARK: - Persona

    /// Loads the per-space persona, or the recommended default if none is stored.
    public func loadPersona(spaceID: String) throws -> CompanionPersona {
        try writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT tone, formality, correction FROM conversation_companions WHERE space_id = ?",
                arguments: [spaceID]
            ) else { return .default }
            return Self.persona(from: row) ?? .default
        }
    }

    public func savePersona(_ persona: CompanionPersona, spaceID: String, now: Date = Date()) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO conversation_companions
                (space_id, tone, formality, correction, sync_policy, backup_policy, export_policy, created_at, updated_at)
                VALUES (?, ?, ?, ?, 'localOnly', 'includedInSystemBackup', 'includedByDefault', ?, ?)
                ON CONFLICT(space_id) DO UPDATE SET
                  tone = excluded.tone,
                  formality = excluded.formality,
                  correction = excluded.correction,
                  updated_at = excluded.updated_at
                """,
                arguments: [
                    spaceID, persona.tone.rawValue, persona.formality.rawValue, persona.correction.rawValue,
                    now.timeIntervalSince1970, now.timeIntervalSince1970,
                ]
            )
        }
    }

    // MARK: - Row decoding

    private static func thread(from row: Row?) -> CompanionThread? {
        guard let row else { return nil }
        return CompanionThread(
            id: row["id"],
            languageSpaceID: row["space_id"],
            sourceEntryID: row["source_entry_id"],
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }

    private static func message(from row: Row) -> CompanionMessage? {
        guard
            let role = CompanionMessageRole(rawValue: row["role"]),
            let modality = CompanionInputModality(rawValue: row["input_modality"])
        else { return nil }
        return CompanionMessage(
            id: row["id"],
            threadID: row["thread_id"],
            sequence: row["sequence"],
            role: role,
            content: row["content"],
            detectedLanguage: row["detected_language"],
            targetLanguageCode: row["target_language_code"],
            inputModality: modality,
            audioArtifactID: row["audio_artifact_id"],
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }

    private static func persona(from row: Row) -> CompanionPersona? {
        guard
            let tone = CompanionTone(rawValue: row["tone"]),
            let formality = CompanionFormality(rawValue: row["formality"]),
            let correction = CompanionCorrection(rawValue: row["correction"])
        else { return nil }
        return CompanionPersona(tone: tone, formality: formality, correction: correction)
    }
}
