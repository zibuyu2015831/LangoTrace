import Foundation

public protocol DiagnosticLogging: Sendable {
    func record(_ event: DiagnosticEvent) async
}

public protocol DiagnosticEventRepository: Sendable {
    func record(_ event: DiagnosticEvent) async throws
    func recentEvents(limit: Int) async throws -> [DiagnosticEvent]
    func prune(keepingMostRecent count: Int, newerThan cutoff: Date) async throws
}

public struct DisabledDiagnosticLogger: DiagnosticLogging {
    public init() {}

    public func record(_: DiagnosticEvent) async {}
}

public actor InMemoryDiagnosticLogger: DiagnosticLogging {
    private var recordedEvents: [DiagnosticEvent] = []

    public init() {}

    public func record(_ event: DiagnosticEvent) {
        recordedEvents.append(event)
    }

    public func events() -> [DiagnosticEvent] {
        recordedEvents
    }
}
