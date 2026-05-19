import LangoTraceCore
import SwiftUI

struct OnboardingView: View {
    @Binding var draft: OnboardingDraft
    let onCreateLanguageSpace: () -> Void

    private let onboardingContentMaxWidth: CGFloat = 680
    private let onboardingBottomActionMaxWidth: CGFloat = 520

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if usesInlineWideOnboardingLayout(in: size) {
                wideOnboardingContent(size: size)
            } else {
                compactOnboardingContentWithBottomAction
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .langoPageBackground()
    }

    private func usesInlineWideOnboardingLayout(in size: CGSize) -> Bool {
        #if os(iOS)
            size.width >= 760 && size.height >= 720
        #else
            size.width >= 760 && size.height >= 620
        #endif
    }

    private var compactOnboardingContentWithBottomAction: some View {
        ZStack {
            ScrollView {
                onboardingFormContent
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 116)
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

    private var onboardingFormContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            languageForm
            privacyNote
        }
    }

    private func onboardingWideTopPadding(in size: CGSize) -> CGFloat {
        if size.height >= 1180 {
            78
        } else if size.height >= 900 {
            64
        } else {
            44
        }
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
        VStack(alignment: .leading, spacing: 14) {
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

            Divider()

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

            Divider()

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
                    }
                }
                Picker(selection: $draft.level) {
                    ForEach(LanguageLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                } label: {
                    localizedText("onboarding.level.title")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(localizedText("onboarding.level.title"))
                .accessibilityHint(
                    localizedString("onboarding.level.accessibilityHint", draft.resolvedTargetLanguage.nativeName)
                )
            }
        }
        .langoPanel(padding: 18)
        .langoSoftShadow()
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                localizedText("onboarding.privacy.localStorage")
            } icon: {
                Image(systemName: "lock")
            }
            .font(.headline)
            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            localizedText("onboarding.privacy.noExternalAI")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .langoPanel(padding: 16)
    }

    private var createButtonContent: some View {
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
        }
        .frame(maxWidth: onboardingBottomActionMaxWidth)
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
        createButtonContent
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var createSummary: String {
        "\(draft.resolvedNativeLanguage.displayTitle(for: .selectedValue)) -> " +
            "\(draft.resolvedTargetLanguage.displayTitle(for: .selectedValue)) · \(draft.level.rawValue)"
    }
}

private struct LanguageMenu: View {
    let titleKey: String
    let selectedLanguage: LearningLanguage
    let languages: [LearningLanguage]
    let onSelect: (LearningLanguage) -> Void

    var body: some View {
        Menu {
            ForEach(languages) { language in
                Button {
                    onSelect(language)
                } label: {
                    Text(language.displayTitle(for: .onboardingPicker))
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedLanguage.displayTitle(for: .selectedValue))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.headline)
            .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(LangoTraceDesign.ColorToken.hairline.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.button)
        .accessibilityLabel(localizedText(titleKey))
        .accessibilityValue(selectedLanguage.displayTitle(for: .onboardingPicker))
        .accessibilityHint(localizedText(titleKey))
    }
}

private struct PickerRow<PickerContent: View>: View {
    let titleKey: String
    let systemImage: String
    @ViewBuilder let picker: PickerContent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.teal)
                .frame(width: 30, height: 30)
                .background(LangoTraceDesign.ColorToken.paleTeal)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                localizedText(titleKey)
                    .font(.headline)
            }
            Spacer(minLength: 12)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
        }
        .frame(minHeight: 52)
    }
}
