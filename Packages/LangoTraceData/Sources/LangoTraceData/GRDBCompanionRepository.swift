import Foundation
import GRDB
import LangoTraceCore

/// Language-space context for a companion turn (resolved in the Data layer).
public struct CompanionLanguageContext: Equatable, Sendable {
    public let targetLanguageCode: String
    public let nativeLanguageCode: String
    public let level: String

    public init(targetLanguageCode: String, nativeLanguageCode: String, level: String) {
        self.targetLanguageCode = targetLanguageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.level = level
    }
}

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
                sql: "SELECT id, space_id, source_entry_id, created_at, uses_learner_profile FROM companion_threads WHERE space_id = ? ORDER BY created_at ASC, id ASC LIMIT 1",
                arguments: [spaceID]
            )) {
                return existing
            }
            // INSERT omits uses_learner_profile, so the column takes its DEFAULT 1.
            // The returned in-memory thread must mirror that default for read-back
            // consistency with `thread(id:)` (LM03-S2b-1 self-review P1-R2-2).
            let thread = CompanionThread(
                id: id(),
                languageSpaceID: spaceID,
                sourceEntryID: sourceEntryID,
                createdAt: now,
                usesLearnerProfile: true
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

    /// Language-space context the companion engine needs at send time (target /
    /// native language + the static onboarding level baseline). Kept in the Data
    /// layer so the App never touches GRDB directly.
    public func languageContext(spaceID: String) throws -> CompanionLanguageContext? {
        try writer.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT target_language_code, native_language_code, level FROM language_spaces WHERE id = ?",
                arguments: [spaceID]
            ) else { return nil }
            return CompanionLanguageContext(
                targetLanguageCode: row["target_language_code"],
                nativeLanguageCode: row["native_language_code"],
                level: row["level"]
            )
        }
    }

    /// Plan-A: the body of an explicitly brought-in entry (nil if deleted).
    public func entryBody(entryID: String) throws -> String? {
        try writer.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT body FROM entries WHERE id = ? AND deleted_at IS NULL",
                arguments: [entryID]
            )
        }
    }

    /// Looks up a thread by id (for resolving its space + plan-A seed at send time).
    public func thread(id: String) throws -> CompanionThread? {
        try writer.read { db in
            try Self.thread(from: Row.fetchOne(
                db,
                sql: "SELECT id, space_id, source_entry_id, created_at, uses_learner_profile FROM companion_threads WHERE id = ?",
                arguments: [id]
            ))
        }
    }

    /// Sets the per-conversation learner-profile injection toggle (LM03-S2b-1
    /// second privacy layer). When false, no Memory is injected for this thread
    /// regardless of the global consent.
    public func setUsesLearnerProfile(threadID: String, _ usesLearnerProfile: Bool) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE companion_threads SET uses_learner_profile = ? WHERE id = ?",
                arguments: [usesLearnerProfile, threadID]
            )
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

    // MARK: - Memory candidates (LM03-S2a chat reflux)

    /// Persists the candidates extracted from a conversation window, anchored to a
    /// single source message (`messageID`, the same anchor for the whole batch — a
    /// weak link that is nulled if that message is later deleted). The owning
    /// `space_id` is resolved from the thread, so candidates stay space-scoped. The
    /// candidate's own `createdAt` is authoritative (deterministic ordering); the
    /// `messageID` argument — not any value on the candidate — is the persisted
    /// anchor. No-op for an empty batch or an unknown thread.
    public func appendCompanionCandidates(
        threadID: String,
        messageID: String?,
        candidates: [CompanionMemoryCandidate]
    ) throws {
        guard !candidates.isEmpty else { return }
        try writer.write { db in
            guard let spaceID = try String.fetchOne(
                db,
                sql: "SELECT space_id FROM companion_threads WHERE id = ?",
                arguments: [threadID]
            ) else { return }
            for candidate in candidates {
                let timestamp = candidate.createdAt.timeIntervalSince1970
                try db.execute(
                    sql: """
                    INSERT INTO companion_memory_candidates
                    (id, space_id, thread_id, message_id, kind, text, explanation_native,
                     example_target, example_native, status, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)
                    """,
                    arguments: [
                        candidate.id, spaceID, threadID, messageID,
                        candidate.kind.rawValue, candidate.text, candidate.explanationNative,
                        candidate.exampleTarget, candidate.exampleNative,
                        timestamp, timestamp,
                    ]
                )
            }
        }
    }

    /// All chat-reflux candidates for a space, newest first (review-queue order).
    public func companionCandidates(spaceID: String) throws -> [CompanionMemoryCandidate] {
        try writer.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, message_id, kind, text, explanation_native,
                       example_target, example_native, created_at
                FROM companion_memory_candidates
                WHERE space_id = ?
                ORDER BY created_at DESC, id DESC
                """,
                arguments: [spaceID]
            )
            return rows.compactMap(Self.candidate(from:))
        }
    }

    /// Forward read seam (LM03-S2a 交付物 B): the user's target-language utterances
    /// in a space, oldest-first, for a future Ability *production* (fluency) signal
    /// consumer to read. A "target-language" utterance is decided **row-locally** —
    /// `detected_language == target_language_code` on the message itself (the v30
    /// send-time snapshot) — so it never joins `language_spaces` and uses the
    /// historical target language of each message (plan §Phase 2 round-2 fix).
    ///
    /// This is **read-only**: it does not register a `LearnerSourceType`, write the
    /// analysis ledger, or touch `band()` (plan §D3 round-1 narrowing — no
    /// consumer-less dead code; band keeps modelling only the struggling signal).
    /// `after == nil` returns the full history; otherwise only messages strictly
    /// after it. No limit — the window is the caller's decision.
    public func productionUtterances(spaceID: String, after: Date?) throws -> [CompanionMessage] {
        try writer.read { db in
            var sql = """
            SELECT m.id, m.thread_id, m.sequence, m.role, m.content, m.detected_language,
                   m.target_language_code, m.input_modality, m.audio_artifact_id, m.created_at
            FROM companion_messages m
            JOIN companion_threads t ON t.id = m.thread_id
            WHERE t.space_id = ?
              AND m.role = 'user'
              AND m.detected_language IS NOT NULL
              AND m.detected_language = m.target_language_code
            """
            var arguments: [DatabaseValueConvertible] = [spaceID]
            if let after {
                sql += "\n  AND m.created_at > ?"
                arguments.append(after.timeIntervalSince1970)
            }
            sql += "\nORDER BY m.created_at ASC, m.sequence ASC"
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.compactMap(Self.message(from:))
        }
    }

    // MARK: - Row decoding

    private static func thread(from row: Row?) -> CompanionThread? {
        guard let row else { return nil }
        // Older callers (pre-v32) may not select the column; default to true
        // (follow global) when it is absent, matching the DB DEFAULT 1.
        let usesProfile = (row["uses_learner_profile"] as Int64?).map { $0 != 0 } ?? true
        return CompanionThread(
            id: row["id"],
            languageSpaceID: row["space_id"],
            sourceEntryID: row["source_entry_id"],
            createdAt: Date(timeIntervalSince1970: row["created_at"]),
            usesLearnerProfile: usesProfile
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

    private static func candidate(from row: Row) -> CompanionMemoryCandidate? {
        guard let kind = LearningMemoryCandidate.Kind(rawValue: row["kind"]) else { return nil }
        return CompanionMemoryCandidate(
            id: row["id"],
            messageID: row["message_id"],
            kind: kind,
            text: row["text"],
            explanationNative: row["explanation_native"],
            exampleTarget: row["example_target"],
            exampleNative: row["example_native"],
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
