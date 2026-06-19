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
    private let readingLibraryActions: ReadingLibraryActions
    private let readingExplanationAction: ReadingExplanationAction
    private let readingTTSAction: ReadingTTSAction
    private let readingCacheStorage: (any ExplanationCacheStorage)?
    private let practiceActions: PracticeActions
    private let photoWritingActions: PhotoWritingActions
    private let loadSettingsStatus: @Sendable () async -> SettingsStatusProjection
    private let interfaceLanguagePreference: InterfaceLanguagePreference
    private let appearancePreference: AppearancePreference
    private let launchRecoveryFailed: Bool
    @Binding private var onboardingDraft: OnboardingDraft
    private let onWelcomeFinished: () -> Void
    private let onRetryLaunchRecovery: () -> Void
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
        readingLibraryActions: ReadingLibraryActions = .disabled,
        readingExplanationAction: @escaping ReadingExplanationAction = { _ in
            throw ReadingLibraryActionError.unavailable
        },
        readingTTSAction: @escaping ReadingTTSAction = { _ in .cancelled },
        readingCacheStorage: (any ExplanationCacheStorage)? = nil,
        practiceActions: PracticeActions = .disabled,
        photoWritingActions: PhotoWritingActions = .disabled,
        loadSettingsStatus: @escaping @Sendable () async -> SettingsStatusProjection = { SettingsStatusProjection() },
        interfaceLanguagePreference: InterfaceLanguagePreference = .system,
        appearancePreference: AppearancePreference = .system,
        launchRecoveryFailed: Bool = false,
        onboardingDraft: Binding<OnboardingDraft>,
        onWelcomeFinished: @escaping () -> Void,
        onRetryLaunchRecovery: @escaping () -> Void = {},
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
        self.readingLibraryActions = readingLibraryActions
        self.readingExplanationAction = readingExplanationAction
        self.readingTTSAction = readingTTSAction
        self.readingCacheStorage = readingCacheStorage
        self.practiceActions = practiceActions
        self.photoWritingActions = photoWritingActions
        self.loadSettingsStatus = loadSettingsStatus
        self.interfaceLanguagePreference = interfaceLanguagePreference
        self.appearancePreference = appearancePreference
        self.launchRecoveryFailed = launchRecoveryFailed
        _onboardingDraft = onboardingDraft
        self.onWelcomeFinished = onWelcomeFinished
        self.onRetryLaunchRecovery = onRetryLaunchRecovery
        self.onCreateLanguageSpace = onCreateLanguageSpace
        self.onAddLanguageSpace = onAddLanguageSpace
        self.onSelectLanguageSpace = onSelectLanguageSpace
        self.onUpdateLanguageSpace = onUpdateLanguageSpace
        self.onDeleteLanguageSpace = onDeleteLanguageSpace
        self.onInterfaceLanguagePreferenceChange = onInterfaceLanguagePreferenceChange
        self.onAppearancePreferenceChange = onAppearancePreferenceChange
    }

    public var body: some View {
        Group {
            switch effectivePhase {
            case .welcome:
                WelcomeView(onFinished: onWelcomeFinished)
                    .safeAreaInset(edge: .bottom) {
                        if Self.showsLaunchRecoveryFailurePanel(
                            phase: effectivePhase,
                            launchRecoveryFailed: launchRecoveryFailed
                        ) {
                            LaunchRecoveryFailurePanel(onRetry: onRetryLaunchRecovery)
                        }
                    }
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
                        readingLibraryActions: readingLibraryActions,
                        readingExplanationAction: readingExplanationAction,
                        readingTTSAction: readingTTSAction,
                        readingCacheStorage: readingCacheStorage,
                        practiceActions: practiceActions,
                        photoWritingActions: photoWritingActions,
                        loadSettingsStatus: loadSettingsStatus,
                        interfaceLanguagePreference: interfaceLanguagePreference,
                        appearancePreference: appearancePreference,
                        onAddLanguageSpace: onAddLanguageSpace,
                        onSelectLanguageSpace: onSelectLanguageSpace,
                        onUpdateLanguageSpace: onUpdateLanguageSpace,
                        onDeleteLanguageSpace: onDeleteLanguageSpace,
                        onInterfaceLanguagePreferenceChange: onInterfaceLanguagePreferenceChange,
                        onAppearancePreferenceChange: onAppearancePreferenceChange
                    )
                    .id(languageSpace.id)
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
        LangoTraceInterfaceChrome.applyLanguage(interfaceLanguagePreference)
    }

    /// Presentation rule for surfacing a failed local-storage launch recovery.
    /// The panel belongs only to the welcome phase, where `completeWelcome`
    /// intentionally keeps the user until storage recovery succeeds.
    static func showsLaunchRecoveryFailurePanel(
        phase: LangoTraceAppPhase,
        launchRecoveryFailed: Bool
    ) -> Bool {
        phase == .welcome && launchRecoveryFailed
    }
}

private struct LaunchRecoveryFailurePanel: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                localizedText("launchRecovery.failed.title")
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            } icon: {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(LangoTraceDesign.ColorToken.stateError)
            }
            localizedText("launchRecovery.failed.message")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onRetry) {
                localizedText("launchRecovery.retry")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(LangoTraceDesign.ColorToken.teal)
        }
        .padding(16)
        .frame(maxWidth: 520, alignment: .topLeading)
        .background(LangoTraceDesign.ColorToken.elevatedPaper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LangoTraceDesign.ColorToken.stateError.opacity(0.30), lineWidth: 1)
        }
        .langoSoftShadow()
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .accessibilityElement(children: .contain)
    }
}

private struct PlatformMainView: View {
    let languageSpace: LanguageSpacePreview
    let languageSpaces: [LanguageSpace]
    let learningMaterialGenerationActions: LearningMaterialGenerationActions
    let sentenceAudioPlaybackActions: SentenceAudioPlaybackActions
    let readingLibraryActions: ReadingLibraryActions
    let readingExplanationAction: ReadingExplanationAction
    let readingTTSAction: ReadingTTSAction
    let readingCacheStorage: (any ExplanationCacheStorage)?
    let practiceActions: PracticeActions
    let photoWritingActions: PhotoWritingActions
    let loadSettingsStatus: @Sendable () async -> SettingsStatusProjection
    let interfaceLanguagePreference: InterfaceLanguagePreference
    let appearancePreference: AppearancePreference
    let onAddLanguageSpace: (CreateLanguageSpaceInput) -> Void
    let onSelectLanguageSpace: (String) -> Void
    let onUpdateLanguageSpace: (String, UpdateLanguageSpaceInput) -> Void
    let onDeleteLanguageSpace: (String) -> Void
    let onInterfaceLanguagePreferenceChange: (InterfaceLanguagePreference) -> Void
    let onAppearancePreferenceChange: (AppearancePreference) -> Void
    @StateObject private var contentStore: LearningContentStore
    @StateObject private var readingLibraryStore: ReadingLibraryStore

    init(
        languageSpace: LanguageSpacePreview,
        languageSpaces: [LanguageSpace],
        learningContentRepository: any LearningContentRepository,
        learningMaterialGenerationActions: LearningMaterialGenerationActions,
        sentenceAudioPlaybackActions: SentenceAudioPlaybackActions,
        readingLibraryActions: ReadingLibraryActions,
        readingExplanationAction: @escaping ReadingExplanationAction,
        readingTTSAction: @escaping ReadingTTSAction,
        readingCacheStorage: (any ExplanationCacheStorage)? = nil,
        practiceActions: PracticeActions,
        photoWritingActions: PhotoWritingActions,
        loadSettingsStatus: @escaping @Sendable () async -> SettingsStatusProjection,
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
        self.readingLibraryActions = readingLibraryActions
        self.readingExplanationAction = readingExplanationAction
        self.readingTTSAction = readingTTSAction
        self.readingCacheStorage = readingCacheStorage
        self.practiceActions = practiceActions
        self.photoWritingActions = photoWritingActions
        self.loadSettingsStatus = loadSettingsStatus
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
                sentenceAudioPlaybackActions: sentenceAudioPlaybackActions,
                loadSettingsStatus: loadSettingsStatus
            )
        )
        _readingLibraryStore = StateObject(
            wrappedValue: ReadingLibraryStore(
                languageSpace: languageSpace,
                actions: readingLibraryActions
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
                    readingLibraryStore: readingLibraryStore,
                    readingExplanationAction: readingExplanationAction,
                    readingTTSAction: readingTTSAction,
                    readingCacheStorage: readingCacheStorage,
                    practiceActions: practiceActions,
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
                    readingLibraryStore: readingLibraryStore,
                    readingExplanationAction: readingExplanationAction,
                    readingTTSAction: readingTTSAction,
                    readingCacheStorage: readingCacheStorage,
                    practiceActions: practiceActions,
                    photoWritingActions: photoWritingActions,
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
                readingLibraryStore: readingLibraryStore,
                readingExplanationAction: readingExplanationAction,
                readingTTSAction: readingTTSAction,
                readingCacheStorage: readingCacheStorage,
                practiceActions: practiceActions,
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
