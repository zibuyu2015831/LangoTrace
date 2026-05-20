import Foundation
import OSLog

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

public struct RepositoryDiagnosticLogger: DiagnosticLogging {
    private let repository: any DiagnosticEventRepository

    public init(repository: any DiagnosticEventRepository) {
        self.repository = repository
    }

    public func record(_ event: DiagnosticEvent) async {
        try? await repository.record(event)
    }
}

public struct CompositeDiagnosticLogger: DiagnosticLogging {
    private let loggers: [any DiagnosticLogging]

    public init(loggers: [any DiagnosticLogging]) {
        self.loggers = loggers
    }

    public func record(_ event: DiagnosticEvent) async {
        for logger in loggers {
            await logger.record(event)
        }
    }
}

public struct ConsoleDiagnosticLogger: DiagnosticLogging {
    private let logger: Logger
    private let minimumLevel: DiagnosticLevel

    public init(
        subsystem: String = "com.zibuyu.LangoTrace",
        category: String = "diagnostics",
        minimumLevel: DiagnosticLevel = .info
    ) {
        logger = Logger(subsystem: subsystem, category: category)
        self.minimumLevel = minimumLevel
    }

    public func record(_ event: DiagnosticEvent) async {
        guard event.level.priority >= minimumLevel.priority else {
            return
        }

        let message = "\(event.name.rawValue) \(event.outcome?.rawValue ?? "none")"
        switch event.level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
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

private extension DiagnosticLevel {
    var priority: Int {
        switch self {
        case .debug:
            0
        case .info:
            1
        case .warning:
            2
        case .error:
            3
        }
    }
}
