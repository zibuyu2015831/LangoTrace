import LangoTraceCore
import SwiftUI

struct OnboardingView: View {
    @Binding var draft: OnboardingDraft
    let onCreateLanguageSpace: () -> Void

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    languageForm
                    privacyNote
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 116)
                .frame(maxWidth: 680, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            createButton
        }
        .langoPageBackground()
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
                .accessibilityHint("选择当前 \(draft.resolvedTargetLanguage.zhHansName) 水平")
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

    private var createButton: some View {
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
            .accessibilityHint("创建 \(draft.resolvedTargetLanguage.zhHansName) 学习空间并进入主体页面")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var createSummary: String {
        "\(draft.resolvedNativeLanguage.selectedTitleForChineseUI) -> " +
            "\(draft.resolvedTargetLanguage.selectedTitleForChineseUI) · \(draft.level.rawValue)"
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
                    Text(language.pickerMenuTitleForChineseUI)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedLanguage.selectedTitleForChineseUI)
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
        .accessibilityValue(selectedLanguage.pickerMenuTitleForChineseUI)
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
