import LangoTraceCore
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
    @Binding private var onboardingDraft: OnboardingDraft
    private let onWelcomeFinished: () -> Void
    private let onCreateLanguageSpace: () -> Void

    public init(
        phase: LangoTraceAppPhase,
        languageSpace: LanguageSpacePreview?,
        onboardingDraft: Binding<OnboardingDraft>,
        onWelcomeFinished: @escaping () -> Void,
        onCreateLanguageSpace: @escaping () -> Void
    ) {
        self.phase = phase
        self.languageSpace = languageSpace
        _onboardingDraft = onboardingDraft
        self.onWelcomeFinished = onWelcomeFinished
        self.onCreateLanguageSpace = onCreateLanguageSpace
    }

    public var body: some View {
        Group {
            switch phase {
            case .welcome:
                WelcomeView(onFinished: onWelcomeFinished)
            case .onboarding:
                OnboardingView(
                    draft: $onboardingDraft,
                    onCreateLanguageSpace: onCreateLanguageSpace
                )
            case .main:
                PlatformMainView(languageSpace: languageSpace ?? onboardingDraft.makeLanguageSpacePreview())
            }
        }
        .tint(LangoTraceDesign.ColorToken.teal)
    }
}

private struct PlatformMainView: View {
    let languageSpace: LanguageSpacePreview

    var body: some View {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadMainView(languageSpace: languageSpace)
            } else {
                PhoneMainView(languageSpace: languageSpace)
            }
        #elseif os(macOS)
            MacMainView(languageSpace: languageSpace)
        #endif
    }
}
