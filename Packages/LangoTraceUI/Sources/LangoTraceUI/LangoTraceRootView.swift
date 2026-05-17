import LangoTraceCore
import LangoTraceData
import SwiftUI

#if os(iOS)
    import UIKit
#endif

public enum LangoTraceAppPhase: Equatable, Sendable {
    case welcome
    case onboarding
    case main
}

public struct LangoTraceRootView: View {
    private let phase: LangoTraceAppPhase
    private let languageSpace: LanguageSpacePreview?
    private let learningContentRepository: InMemoryLearningContentRepository
    @Binding private var onboardingDraft: OnboardingDraft
    private let onWelcomeFinished: () -> Void
    private let onCreateLanguageSpace: () -> Void

    public init(
        phase: LangoTraceAppPhase,
        languageSpace: LanguageSpacePreview?,
        learningContentRepository: InMemoryLearningContentRepository,
        onboardingDraft: Binding<OnboardingDraft>,
        onWelcomeFinished: @escaping () -> Void,
        onCreateLanguageSpace: @escaping () -> Void
    ) {
        self.phase = phase
        self.languageSpace = languageSpace
        self.learningContentRepository = learningContentRepository
        _onboardingDraft = onboardingDraft
        self.onWelcomeFinished = onWelcomeFinished
        self.onCreateLanguageSpace = onCreateLanguageSpace
    }

    public var body: some View {
        Group {
            switch effectivePhase {
            case .welcome:
                WelcomeView(onFinished: onWelcomeFinished)
            case .onboarding:
                OnboardingView(
                    draft: $onboardingDraft,
                    onCreateLanguageSpace: onCreateLanguageSpace
                )
            case .main:
                PlatformMainView(
                    languageSpace: languageSpace ?? onboardingDraft.makeLanguageSpacePreview(),
                    learningContentRepository: learningContentRepository
                )
            }
        }
        .tint(LangoTraceDesign.ColorToken.teal)
    }

    private var effectivePhase: LangoTraceAppPhase {
        switch phase {
        case .welcome:
            .welcome
        case .onboarding:
            .onboarding
        case .main:
            switch LaunchRoute.route(
                requestedPhase: .main,
                hasLanguageSpace: languageSpace != nil
            ) {
            case .onboarding:
                .onboarding
            case .main:
                .main
            }
        }
    }
}

private struct PlatformMainView: View {
    let languageSpace: LanguageSpacePreview
    let learningContentRepository: InMemoryLearningContentRepository

    var body: some View {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadMainView(languageSpace: languageSpace, contentRepository: learningContentRepository)
            } else {
                PhoneMainView(languageSpace: languageSpace, contentRepository: learningContentRepository)
            }
        #elseif os(macOS)
            MacMainView(
                languageSpace: languageSpace,
                contentRepository: learningContentRepository
            )
        #endif
    }
}
