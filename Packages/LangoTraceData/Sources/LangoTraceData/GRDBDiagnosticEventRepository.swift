import Foundation
import GRDB
import LangoTraceCore

public struct GRDBDiagnosticEventRepository: DiagnosticEventRepository, @unchecked Sendable {
    private let databaseQueue: DatabaseQueue

    public init(database: AppDatabase) {
        databaseQueue = database.databaseQueue
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
    }
}

private extension GRDBDiagnosticEventRepository {
    func event(from row: Row) throws -> DiagnosticEvent {
        try DiagnosticEvent(
            id: row["id"],
            name: DiagnosticEventName(rawValue: row["name"] as String) ?? .aiProviderSettingsSaveFailed,
            domain: DiagnosticDomain(rawValue: row["domain"] as String) ?? .appLifecycle,
            level: DiagnosticLevel(rawValue: row["level"] as String) ?? .info,
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
        switch key {
        case "operation_id":
            .operationID(DiagnosticOperationID(rawValue: value))
        case "provider_preset_id":
            .providerPresetID(value)
        case "endpoint_purpose":
            AIProviderEndpointPurpose(rawValue: value).map(DiagnosticAttribute.endpointPurpose)
        case "endpoint_count":
            Int(value).map(DiagnosticAttribute.endpointCount)
        case "enabled_endpoint_count":
            Int(value).map(DiagnosticAttribute.enabledEndpointCount)
        case "model_name":
            .modelName(value)
        case "duration_ms":
            Int(value).map(DiagnosticAttribute.durationMilliseconds)
        case "error_category":
            .errorCategory(value)
        case "failure_phase":
            .failurePhase(value)
        case "platform":
            .platform(value)
        case "app_version":
            .appVersion(value)
        case "diagnostics_mode":
            .diagnosticsMode(value)
        default:
            nil
        }
    }

    func value(from attribute: DiagnosticAttribute) -> String {
        switch attribute {
        case let .operationID(value):
            value.rawValue
        case let .providerPresetID(value):
            value
        case let .endpointPurpose(value):
            value.rawValue
        case let .endpointCount(value),
             let .enabledEndpointCount(value),
             let .durationMilliseconds(value):
            String(value)
        case let .modelName(value),
             let .errorCategory(value),
             let .failurePhase(value),
             let .platform(value),
             let .appVersion(value),
             let .diagnosticsMode(value):
            value
        }
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
