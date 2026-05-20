public protocol DiagnosticLogging: Sendable {
    func record(_ event: DiagnosticEvent) async
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
