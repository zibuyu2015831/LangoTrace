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
    private let learningContentRepository: any LearningContentRepository
    private let interfaceLanguagePreference: InterfaceLanguagePreference
    @Binding private var onboardingDraft: OnboardingDraft
    private let onWelcomeFinished: () -> Void
    private let onCreateLanguageSpace: () -> Void
    private let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void

    public init(
        phase: LangoTraceAppPhase,
        languageSpace: LanguageSpacePreview?,
        learningContentRepository: any LearningContentRepository,
        interfaceLanguagePreference: InterfaceLanguagePreference = .system,
        onboardingDraft: Binding<OnboardingDraft>,
        onWelcomeFinished: @escaping () -> Void,
        onCreateLanguageSpace: @escaping () -> Void,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void = { _ in }
    ) {
        self.phase = phase
        self.languageSpace = languageSpace
        self.learningContentRepository = learningContentRepository
        self.interfaceLanguagePreference = interfaceLanguagePreference
        _onboardingDraft = onboardingDraft
        self.onWelcomeFinished = onWelcomeFinished
        self.onCreateLanguageSpace = onCreateLanguageSpace
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
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
                    learningContentRepository: learningContentRepository,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
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
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    @StateObject private var contentStore: LearningContentStore

    init(
        languageSpace: LanguageSpacePreview,
        learningContentRepository: any LearningContentRepository,
        interfaceLanguagePreference: InterfaceLanguagePreference,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void
    ) {
        self.languageSpace = languageSpace
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        _contentStore = StateObject(
            wrappedValue: LearningContentStore(
                repository: learningContentRepository,
                spaceID: languageSpace.id
            )
        )
    }

    var body: some View {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadMainView(
                    languageSpace: languageSpace,
                    contentStore: contentStore,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
                )
            } else {
                PhoneMainView(
                    languageSpace: languageSpace,
                    contentStore: contentStore,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
                )
            }
        #elseif os(macOS)
            MacMainView(
                languageSpace: languageSpace,
                contentStore: contentStore,
                interfaceLanguagePreference: interfaceLanguagePreference,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange
            )
        #endif
    }
}
