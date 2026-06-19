import Foundation
import LangoTraceCore

public actor InMemoryDiagnosticEventRepository: DiagnosticEventRepository {
    private var events: [DiagnosticEvent] = []

    public init() {}

    public func record(_ event: DiagnosticEvent) {
        events.append(event)
    }

    public func recentEvents(limit: Int) -> [DiagnosticEvent] {
        guard limit > 0 else {
            return []
        }

        return Array(
            events
                .sorted { first, second in
                    if first.createdAt == second.createdAt {
                        return first.id > second.id
                    }
                    return first.createdAt > second.createdAt
                }
                .prefix(limit)
        )
    }

    public func prune(keepingMostRecent count: Int, newerThan cutoff: Date) {
        events.removeAll { $0.createdAt < cutoff }

        guard count > 0 else {
            events.removeAll()
            return
        }

        events = Array(
            events
                .sorted { first, second in
                    if first.createdAt == second.createdAt {
                        return first.id > second.id
                    }
                    return first.createdAt > second.createdAt
                }
                .prefix(count)
        )
    }
}
