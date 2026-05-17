public enum LaunchPhaseIntent: Equatable, Sendable {
    case onboarding
    case main
}

public enum LaunchRoute: Equatable, Sendable {
    case onboarding
    case main

    public static func route(hasLanguageSpace: Bool) -> LaunchRoute {
        hasLanguageSpace ? .main : .onboarding
    }

    public static func route(
        requestedPhase: LaunchPhaseIntent,
        hasLanguageSpace: Bool
    ) -> LaunchRoute {
        switch requestedPhase {
        case .onboarding:
            .onboarding
        case .main:
            route(hasLanguageSpace: hasLanguageSpace)
        }
    }
}
