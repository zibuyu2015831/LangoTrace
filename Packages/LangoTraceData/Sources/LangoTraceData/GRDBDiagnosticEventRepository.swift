import Foundation
import GRDB
import LangoTraceCore

public struct GRDBDiagnosticEventRepository: DiagnosticEventRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue
    private let retentionPolicy: DiagnosticRetentionPolicy
    private let clock: @Sendable () -> Date
    private let diagnosticLogger: any DiagnosticLogging

    public init(
        database: AppDatabase,
        retentionPolicy: DiagnosticRetentionPolicy = DiagnosticRetentionPolicy(),
        clock: @escaping @Sendable () -> Date = Date.init,
        diagnosticLogger: any DiagnosticLogging = DisabledDiagnosticLogger()
    ) {
        databaseQueue = database.databaseQueue
        self.retentionPolicy = retentionPolicy
        self.clock = clock
        self.diagnosticLogger = diagnosticLogger
    }

    public func record(_ event: DiagnosticEvent) async throws {
        try await databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO diagnostic_events (
                    id, name, domain, level, outcome, operation_id,
                    attributes_json, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id,
                    event.name.rawValue,
                    event.domain.rawValue,
                    event.level.rawValue,
                    event.outcome?.rawValue,
                    operationID(in: event.attributes)?.rawValue,
                    attributesJSON(from: event.attributes),
                    event.createdAt.timeIntervalSince1970,
                ]
            )
            try prune(
                db,
                keepingMostRecent: retentionPolicy.maximumEventCount,
                newerThan: clock().addingTimeInterval(-retentionPolicy.maximumAge)
            )
        }
    }

    public func recentEvents(limit: Int) async throws -> [DiagnosticEvent] {
        guard limit > 0 else {
            return []
        }

        return try await databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT *
                FROM diagnostic_events
                ORDER BY created_at DESC, id DESC
                LIMIT ?
                """,
                arguments: [limit]
            ).map(event(from:))
        }
    }

    public func prune(keepingMostRecent count: Int, newerThan cutoff: Date) async throws {
        try await databaseQueue.write { db in
            try prune(db, keepingMostRecent: count, newerThan: cutoff)
        }
    }
}

private extension GRDBDiagnosticEventRepository {
    static let attributeDecoders: [String: @Sendable (String) -> DiagnosticAttribute?] = [
        "operation_id": { .operationID(DiagnosticOperationID(rawValue: $0)) },
        "provider_preset_id": { .providerPresetID($0) },
        "endpoint_purpose": { AIProviderEndpointPurpose(rawValue: $0).map(DiagnosticAttribute.endpointPurpose) },
        "endpoint_count": { Int($0).map(DiagnosticAttribute.endpointCount) },
        "enabled_endpoint_count": { Int($0).map(DiagnosticAttribute.enabledEndpointCount) },
        "model_name": { .modelName($0) },
        "duration_ms": { Int($0).map(DiagnosticAttribute.durationMilliseconds) },
        "error_category": { .errorCategory($0) },
        "failure_phase": { .failurePhase($0) },
        "adapter_kind": { AIProviderAdapterKind(rawValue: $0).map(DiagnosticAttribute.adapterKind) },
        "probe_capability": { AIProviderProbeCapability(rawValue: $0).map(DiagnosticAttribute.probeCapability) },
        "probe_capability_status": {
            AIProviderProbeCapabilityStatus(rawValue: $0).map(DiagnosticAttribute.probeCapabilityStatus)
        },
        "language_support_failure_reason": { .languageSupportFailureReason($0) },
        "platform": { .platform($0) },
        "app_version": { .appVersion($0) },
        "diagnostics_mode": { .diagnosticsMode($0) },
        "output_format": { TTSAudioFormat(rawValue: $0).map(DiagnosticAttribute.outputFormat) },
        "text_length_bucket": { SentenceAudioTextLengthBucket(rawValue: $0).map(DiagnosticAttribute.textLengthBucket) },
        "byte_size_bucket": { SentenceAudioByteSizeBucket(rawValue: $0).map(DiagnosticAttribute.byteSizeBucket) },
        "duration_bucket": { SentenceAudioDurationBucket(rawValue: $0).map(DiagnosticAttribute.durationBucket) },
        "cache_result": { SentenceAudioCacheResult(rawValue: $0).map(DiagnosticAttribute.cacheResult) },
        "http_status_code": { Int($0).map(DiagnosticAttribute.httpStatusCode) },
    ]

    func prune(_ db: Database, keepingMostRecent count: Int, newerThan cutoff: Date) throws {
        try db.execute(
            sql: "DELETE FROM diagnostic_events WHERE created_at < ?",
            arguments: [cutoff.timeIntervalSince1970]
        )

        guard count > 0 else {
            try db.execute(sql: "DELETE FROM diagnostic_events")
            return
        }

        try db.execute(
            sql: """
            DELETE FROM diagnostic_events
            WHERE id NOT IN (
                SELECT id
                FROM diagnostic_events
                ORDER BY created_at DESC, id DESC
                LIMIT ?
            )
            """,
            arguments: [count]
        )
    }

    func event(from row: Row) throws -> DiagnosticEvent {
        try DiagnosticEvent(
            id: row["id"],
            name: StoredEnumDecoding.decode(
                DiagnosticEventName.self,
                from: row["name"] as String,
                fallback: .aiProviderSettingsSaveFailed,
                context: "diagnostic_events.name",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            domain: StoredEnumDecoding.decode(
                DiagnosticDomain.self,
                from: row["domain"] as String,
                fallback: .appLifecycle,
                context: "diagnostic_events.domain",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            level: StoredEnumDecoding.decode(
                DiagnosticLevel.self,
                from: row["level"] as String,
                fallback: .info,
                context: "diagnostic_events.level",
                diagnosticLogger: diagnosticLogger,
                clock: clock
            ),
            outcome: (row["outcome"] as String?).flatMap(DiagnosticOutcome.init(rawValue:)),
            attributes: attributes(from: row["attributes_json"]),
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }

    func attributesJSON(from attributes: [DiagnosticAttribute]) throws -> String {
        let objects = attributes.map { attribute in
            [
                "key": attribute.key,
                "value": value(from: attribute),
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: objects)
        return String(decoding: data, as: UTF8.self)
    }

    func attributes(from json: String) throws -> [DiagnosticAttribute] {
        let data = Data(json.utf8)
        guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }

        return objects.compactMap { object in
            guard let key = object["key"], let value = object["value"] else {
                return nil
            }
            return attribute(key: key, value: value)
        }
    }

    func attribute(key: String, value: String) -> DiagnosticAttribute? {
        Self.attributeDecoders[key]?(value)
    }

    func value(from attribute: DiagnosticAttribute) -> String {
        attribute.valueDescription
    }

    func operationID(in attributes: [DiagnosticAttribute]) -> DiagnosticOperationID? {
        for attribute in attributes {
            if case let .operationID(operationID) = attribute {
                return operationID
            }
        }
        return nil
    }
}
