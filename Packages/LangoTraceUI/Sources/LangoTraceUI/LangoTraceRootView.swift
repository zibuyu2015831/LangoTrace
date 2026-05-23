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
    private let languageSpaces: [LanguageSpace]
    private let learningContentRepository: any LearningContentRepository
    private let learningMaterialGenerationActions: LearningMaterialGenerationActions
    private let sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
    private let interfaceLanguagePreference: InterfaceLanguagePreference
    private let appearancePreference: AppearancePreference
    @Binding private var onboardingDraft: OnboardingDraft
    private let onWelcomeFinished: () -> Void
    private let onCreateLanguageSpace: () -> Void
    private let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    private let onSelectLanguageSpace: (String) -> Void
    private let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    private let onDeleteLanguageSpace: (String) -> Void
    private let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    private let onAppearancePreferenceChange: (AppearancePreference) -> Void

    public init(
        phase: LangoTraceAppPhase,
        languageSpace: LanguageSpacePreview?,
        languageSpaces: [LanguageSpace] = [],
        learningContentRepository: any LearningContentRepository,
        learningMaterialGenerationActions: LearningMaterialGenerationActions = .disabled,
        sentenceAudioPlaybackActions: SentenceAudioPlaybackActions = .disabled,
        interfaceLanguagePreference: InterfaceLanguagePreference = .system,
        appearancePreference: AppearancePreference = .system,
        onboardingDraft: Binding<OnboardingDraft>,
        onWelcomeFinished: @escaping () -> Void,
        onCreateLanguageSpace: @escaping () -> Void,
        onAddLanguageSpace: @escaping (CreateLanguageSpaceInput) -> Void = { _ in },
        onSelectLanguageSpace: @escaping (String) -> Void = { _ in },
        onUpdateLanguageSpace: @escaping (String, UpdateLanguageSpaceInput) -> Void = { _, _ in },
        onDeleteLanguageSpace: @escaping (String) -> Void = { _ in },
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void = { _ in },
        onAppearancePreferenceChange: @escaping (AppearancePreference) -> Void = { _ in }
    ) {
        self.phase = phase
        self.languageSpace = languageSpace
        self.languageSpaces = languageSpaces
        self.learningContentRepository = learningContentRepository
        self.learningMaterialGenerationActions = learningMaterialGenerationActions
        self.sentenceAudioPlaybackActions = sentenceAudioPlaybackActions
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.appearancePreference = appearancePreference
        _onboardingDraft = onboardingDraft
        self.onWelcomeFinished = onWelcomeFinished
        self.onCreateLanguageSpace = onCreateLanguageSpace
        self.onAddLanguageSpace = onAddLanguageSpace
        self.onSelectLanguageSpace = onSelectLanguageSpace
        self.onUpdateLanguageSpace = onUpdateLanguageSpace
        self.onDeleteLanguageSpace = onDeleteLanguageSpace
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        self.onAppearancePreferenceChange = onAppearancePreferenceChange
        LocalizedChromeLanguageResolver.use(
            languageCode: interfaceLanguagePreference.resolvedLanguageCode(
                systemLanguageCodes: Bundle.main.preferredLocalizations
            )
        )
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
                if let languageSpace {
                    PlatformMainView(
                        languageSpace: languageSpace,
                        languageSpaces: languageSpaces,
                        learningContentRepository: learningContentRepository,
                        learningMaterialGenerationActions: learningMaterialGenerationActions,
                        sentenceAudioPlaybackActions: sentenceAudioPlaybackActions,
                        interfaceLanguagePreference: interfaceLanguagePreference,
                        appearancePreference: appearancePreference,
                        onAddLanguageSpace: onAddLanguageSpace,
                        onSelectLanguageSpace: onSelectLanguageSpace,
                        onUpdateLanguageSpace: onUpdateLanguageSpace,
                        onDeleteLanguageSpace: onDeleteLanguageSpace,
                        onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                        onAppearancePreferenceChange: onAppearancePreferenceChange
                    )
                } else {
                    OnboardingView(
                        draft: $onboardingDraft,
                        onCreateLanguageSpace: onCreateLanguageSpace
                    )
                }
            }
        }
        .onAppear(perform: applyInterfaceChromeLanguage)
        .onChange(of: interfaceLanguagePreference) {
            applyInterfaceChromeLanguage()
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

    private func applyInterfaceChromeLanguage() {
        let resolvedLanguageCode = interfaceLanguagePreference.resolvedLanguageCode(
            systemLanguageCodes: Bundle.main.preferredLocalizations
        )
        LocalizedChromeLanguageResolver.use(languageCode: resolvedLanguageCode)
    }
}

private struct PlatformMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    let learningMaterialGenerationActions: LearningMaterialGenerationActions
    let sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void
    @StateObject private var contentStore: LearningContentStore

    init(
        languageSpace: LanguageSpacePreview,
        languageSpaces: [LanguageSpace],
        learningContentRepository: any LearningContentRepository,
        learningMaterialGenerationActions: LearningMaterialGenerationActions,
        sentenceAudioPlaybackActions: SentenceAudioPlaybackActions,
        interfaceLanguagePreference: InterfaceLanguagePreference,
        appearancePreference: AppearancePreference,
        onAddLanguageSpace: @escaping (CreateLanguageSpaceInput) -> Void,
        onSelectLanguageSpace: @escaping (String) -> Void,
        onUpdateLanguageSpace: @escaping (String, UpdateLanguageSpaceInput) -> Void,
        onDeleteLanguageSpace: @escaping (String) -> Void,
        onInterfaceLanguagePreferenceChange: @escaping (InterfaceLanguagePreference) -> Void,
        onAppearancePreferenceChange: @escaping (AppearancePreference) -> Void
    ) {
        self.languageSpace = languageSpace
        self.languageSpaces = languageSpaces
        self.learningMaterialGenerationActions = learningMaterialGenerationActions
        self.sentenceAudioPlaybackActions = sentenceAudioPlaybackActions
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.appearancePreference = appearancePreference
        self.onAddLanguageSpace = onAddLanguageSpace
        self.onSelectLanguageSpace = onSelectLanguageSpace
        self.onUpdateLanguageSpace = onUpdateLanguageSpace
        self.onDeleteLanguageSpace = onDeleteLanguageSpace
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        self.onAppearancePreferenceChange = onAppearancePreferenceChange
        _contentStore = StateObject(
            wrappedValue: LearningContentStore(
                repository: learningContentRepository,
                spaceID: languageSpace.id,
                generationActions: learningMaterialGenerationActions,
                sentenceAudioPlaybackActions: sentenceAudioPlaybackActions
            )
        )
    }

    var body: some View {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadMainView(
                    languageSpace: languageSpace,
                    languageSpaces: languageSpaces,
                    contentStore: contentStore,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    appearancePreference: appearancePreference,
                    onAddLanguageSpace: onAddLanguageSpace,
                    onSelectLanguageSpace: onSelectLanguageSpace,
                    onUpdateLanguageSpace: onUpdateLanguageSpace,
                    onDeleteLanguageSpace: onDeleteLanguageSpace,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                    onAppearancePreferenceChange: onAppearancePreferenceChange
                )
            } else {
                PhoneMainView(
                    languageSpace: languageSpace,
                    languageSpaces: languageSpaces,
                    contentStore: contentStore,
                    interfaceLanguagePreference: interfaceLanguagePreference,
                    appearancePreference: appearancePreference,
                    onAddLanguageSpace: onAddLanguageSpace,
                    onSelectLanguageSpace: onSelectLanguageSpace,
                    onUpdateLanguageSpace: onUpdateLanguageSpace,
                    onDeleteLanguageSpace: onDeleteLanguageSpace,
                    onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                    onAppearancePreferenceChange: onAppearancePreferenceChange
                )
            }
        #elseif os(macOS)
            MacMainView(
                languageSpace: languageSpace,
                languageSpaces: languageSpaces,
                contentStore: contentStore,
                interfaceLanguagePreference: interfaceLanguagePreference,
                appearancePreference: appearancePreference,
                onAddLanguageSpace: onAddLanguageSpace,
                onSelectLanguageSpace: onSelectLanguageSpace,
                onUpdateLanguageSpace: onUpdateLanguageSpace,
                onDeleteLanguageSpace: onDeleteLanguageSpace,
                onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                onAppearancePreferenceChange: onAppearancePreferenceChange
            )
        #endif
    }
}
