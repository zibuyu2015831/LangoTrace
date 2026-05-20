import LangoTraceCore
import SwiftUI

struct OnboardingView: View {
    @Binding var draft: OnboardingDraft
    let onCreateLanguageSpace: () -> Void

    private let onboardingContentMaxWidth: CGFloat = 680
    private let onboardingBottomActionMaxWidth: CGFloat = 520
    private let levelSelectorApproxVisibleRows: CGFloat = 3
    private let padLevelSelectorApproxVisibleRows: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if usesPadLandscapeOnboardingLayout(in: size) {
                padLandscapeOnboardingContent(size: size)
            } else if usesPadPortraitOnboardingLayout(in: size) {
                padPortraitOnboardingContent(size: size)
            } else if usesInlineWideOnboardingLayout(in: size) {
                wideOnboardingContent(size: size)
            } else {
                compactOnboardingContentWithBottomAction
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .langoPageBackground()
    }

    private func usesPadLandscapeOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 980 && size.height >= 680 && size.width > size.height
        #else
            false
        #endif
    }

    private func usesPadPortraitOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 760 && size.height >= 900 && size.height > size.width
        #else
            false
        #endif
    }

    private func usesInlineWideOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 760 && size.height >= 720
        #else
            size.width >= 760 && size.height >= 620
        #endif
    }
}

private extension OnboardingView {
    private var compactOnboardingContentWithBottomAction: some View {
        ZStack {
            ScrollView {
                onboardingFormContent
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 148)
                    .frame(maxWidth: onboardingContentMaxWidth, alignment: .leading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            createButton
        }
    }

    private func wideOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                onboardingFormContent
                inlineCreateButton
            }
            .padding(.horizontal, 24)
            .padding(.top, onboardingWideTopPadding(in: size))
            .padding(.bottom, 64)
            .frame(maxWidth: onboardingContentMaxWidth, minHeight: size.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private func padPortraitOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                padPortraitValueStrip
                languageForm(levelVisibleRows: padLevelSelectorApproxVisibleRows)
                inlineCreateButton
            }
            .padding(.horizontal, 28)
            .padding(.top, padPortraitTopPadding(in: size))
            .padding(.bottom, 58)
            .frame(maxWidth: 700, minHeight: size.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private func padLandscapeOnboardingContent(size: CGSize) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: padLandscapeColumnSpacing(in: size)) {
                padLandscapeLeftPane(size: size)
                padLandscapeRightPane(size: size)
            }
            .frame(minHeight: size.height, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    private func padLandscapeLeftPane(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 42) {
            header
                .padding(.leading, size.width >= 1260 ? 44 : 32)
            padOnboardingValueList
                .padding(.leading, size.width >= 1260 ? 44 : 32)
                .padding(.top, size.height >= 900 ? 28 : 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 430, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, padLandscapeHorizontalPadding(in: size))
        .padding(.trailing, 36)
        .padding(.top, padLandscapeTopPadding(in: size))
        .padding(.bottom, 76)
        .frame(width: size.width * 0.36, alignment: .topLeading)
    }

    private func padLandscapeRightPane(size: CGSize) -> some View {
        VStack(alignment: .center, spacing: 26) {
            languageForm(levelVisibleRows: padLevelSelectorApproxVisibleRows)
                .frame(maxWidth: 760)
            inlineCreateButton(maxWidth: 640)
        }
        .padding(.horizontal, padLandscapeRightHorizontalPadding(in: size))
        .padding(.top, padLandscapeTopPadding(in: size))
        .padding(.bottom, 54)
        .frame(width: size.width * 0.58, alignment: .top)
        .frame(minHeight: size.height, alignment: .top)
    }

    private var onboardingFormContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            languageForm
        }
    }

    private func onboardingWideTopPadding(in size: CGSize) -> CGFloat {
        size.height >= 1180 ? 78 : (size.height >= 900 ? 64 : 44)
    }

    private func padPortraitTopPadding(in size: CGSize) -> CGFloat {
        size.height >= 1180 ? 118 : (size.height >= 1020 ? 88 : 72)
    }

    private func padLandscapeTopPadding(in size: CGSize) -> CGFloat {
        size.height >= 900 ? 156 : 118
    }

    private func padLandscapeHorizontalPadding(in size: CGSize) -> CGFloat {
        size.width >= 1260 ? 96 : 80
    }

    private func padLandscapeColumnSpacing(in size: CGSize) -> CGFloat {
        size.width >= 1260 ? 56 : 40
    }

    private func padLandscapeRightHorizontalPadding(in size: CGSize) -> CGFloat {
        size.width >= 1260 ? 48 : 36
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LangoTraceDesign.ColorToken.gold)
                    .frame(width: 8, height: 8)
                localizedText("onboarding.eyebrow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            localizedText("onboarding.title")
                .font(.system(.largeTitle, design: .default, weight: .semibold))
            localizedText("onboarding.subtitle")
                .font(.body.weight(.regular))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageForm: some View {
        languageForm(levelVisibleRows: levelSelectorApproxVisibleRows)
    }

    private func languageForm(levelVisibleRows: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            nativeLanguagePickerRow
            Divider()
            targetLanguagePickerRow
            Divider()
            currentLevelSection(levelVisibleRows: levelVisibleRows)
        }
        .langoPanel(padding: 18)
        .langoSoftShadow()
    }

    private var nativeLanguagePickerRow: some View {
        PickerRow(
            titleKey: "onboarding.nativeLanguage",
            systemImage: "person.text.rectangle"
        ) {
            LanguageMenu(
                titleKey: "onboarding.nativeLanguage",
                selectedLanguage: draft.resolvedNativeLanguage,
                languages: LearningLanguage.supportedNativeLanguages,
                onSelect: { language in
                    draft.nativeLanguageCode = language.code
                    draft = draft.normalized()
                }
            )
        }
    }

    private var targetLanguagePickerRow: some View {
        PickerRow(
            titleKey: "onboarding.targetLanguage",
            systemImage: "text.bubble"
        ) {
            LanguageMenu(
                titleKey: "onboarding.targetLanguage",
                selectedLanguage: draft.resolvedTargetLanguage,
                languages: draft.availableTargetLanguages,
                onSelect: { language in
                    draft.targetLanguageCode = language.code
                    draft = draft.normalized()
                }
            )
        }
    }

    private func currentLevelSection(levelVisibleRows: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                    .frame(width: 30, height: 30)
                    .background(LangoTraceDesign.ColorToken.paleTeal)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    localizedText("onboarding.level.title")
                        .font(.headline)
                    localizedText("onboarding.level.summary")
                        .font(.footnote)
                        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            compactLevelSelector(visibleRows: levelVisibleRows)
        }
    }

    private var padOnboardingValueItems: [PadOnboardingValueItem] {
        [
            PadOnboardingValueItem(
                id: "record", systemImage: "camera",
                titleKey: "onboarding.value.record.title", subtitleKey: "onboarding.value.record.subtitle"
            ),
            PadOnboardingValueItem(
                id: "practice", systemImage: "book",
                titleKey: "onboarding.value.practice.title", subtitleKey: "onboarding.value.practice.subtitle"
            ),
            PadOnboardingValueItem(
                id: "trace", systemImage: "leaf",
                titleKey: "onboarding.value.trace.title", subtitleKey: "onboarding.value.trace.subtitle"
            ),
        ]
    }

    private var padPortraitValueStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 26) {
                ForEach(padOnboardingValueItems) { item in
                    PadOnboardingValueStripItem(item: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(padOnboardingValueItems) { item in
                    PadOnboardingValueListItem(item: item)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var padOnboardingValueList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(padOnboardingValueItems.enumerated()), id: \.element.id) { index, item in
                PadOnboardingValueListItem(item: item)

                if index < padOnboardingValueItems.count - 1 {
                    Divider()
                        .padding(.vertical, 24)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func compactLevelSelector(visibleRows: CGFloat) -> some View {
        OnboardingCompactLevelSelector(
            selectedLevel: $draft.level,
            targetLanguageNativeName: draft.resolvedTargetLanguage.nativeName,
            visibleRows: visibleRows
        )
    }

    private var createButtonContent: some View {
        createButtonContent(maxWidth: onboardingBottomActionMaxWidth)
    }

    private func createButtonContent(maxWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(createSummary)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            Button(action: onCreateLanguageSpace) {
                Label {
                    localizedText("onboarding.createSpace")
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(LangoTraceDesign.ColorToken.whiteInk)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .controlSize(.large)
            .tint(LangoTraceDesign.ColorToken.deepTeal)
            .accessibilityHint(
                localizedString("onboarding.createSpace.accessibilityHint", draft.resolvedTargetLanguage.nativeName)
            )
            localStorageFootnote
        }
        .frame(maxWidth: maxWidth)
    }

    private var localStorageFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "lock")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
            localizedText("onboarding.privacy.footnote")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var createButton: some View {
        createButtonContent
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(.regularMaterial)
    }

    private var inlineCreateButton: some View {
        inlineCreateButton(maxWidth: onboardingBottomActionMaxWidth)
    }

    private func inlineCreateButton(maxWidth: CGFloat) -> some View {
        createButtonContent(maxWidth: maxWidth)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var createSummary: String {
        "\(draft.resolvedNativeLanguage.displayTitle(for: .selectedValue)) -> " +
            "\(draft.resolvedTargetLanguage.displayTitle(for: .selectedValue)) · \(draft.level.rawValue)"
    }
}
