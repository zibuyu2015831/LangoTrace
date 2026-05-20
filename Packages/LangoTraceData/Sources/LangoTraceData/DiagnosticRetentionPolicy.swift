import Foundation

public struct DiagnosticRetentionPolicy: Equatable, Sendable {
    public var maximumEventCount: Int
    public var maximumAge: TimeInterval

    public init(
        maximumEventCount: Int = 1_000,
        maximumAge: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.maximumEventCount = maximumEventCount
        self.maximumAge = maximumAge
    }
}
