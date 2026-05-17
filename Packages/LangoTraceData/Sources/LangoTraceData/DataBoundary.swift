import LangoTraceCore

public protocol LanguageSpaceRepository: Sendable {}

public struct EmptyLanguageSpaceRepository: LanguageSpaceRepository {
    public init() {}
}
