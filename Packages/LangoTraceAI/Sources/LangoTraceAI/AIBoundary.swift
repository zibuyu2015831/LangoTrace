public protocol AIProvider: Sendable {}

public struct DisabledAIProvider: AIProvider {
    public init() {}
}
