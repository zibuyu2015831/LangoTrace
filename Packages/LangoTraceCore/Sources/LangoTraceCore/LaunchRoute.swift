public enum LaunchRoute: Equatable, Sendable {
    case onboarding
    case main

    public static func route(hasLanguageSpace: Bool) -> LaunchRoute {
        hasLanguageSpace ? .main : .onboarding
    }
}
