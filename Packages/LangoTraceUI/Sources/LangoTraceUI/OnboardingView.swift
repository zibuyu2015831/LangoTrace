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
                Text("FIRST LANGUAGE SPACE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            Text("创建语言空间")
                .font(.system(.largeTitle, design: .default, weight: .semibold))
            Text("一个语言空间，就是一门目标语言的长期学习档案。先记录最少信息，之后再开始把生活变成学习材料。")
                .font(.body.weight(.regular))
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            PickerRow(
                title: "母语",
                systemImage: "person.text.rectangle"
            ) {
                LanguageMenu(
                    title: "母语",
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
                title: "目标语言",
                systemImage: "text.bubble"
            ) {
                LanguageMenu(
                    title: "目标语言",
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
                        Text("水平自评")
                            .font(.headline)
                        Text("用于调整生成难度，之后可以随时修改。")
                            .font(.footnote)
                            .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                    }
                }
                Picker("水平自评", selection: $draft.level) {
                    ForEach(LanguageLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("水平自评")
                .accessibilityHint("选择当前 \(draft.resolvedTargetLanguage.zhHansName) 水平")
            }
        }
        .langoPanel(padding: 18)
        .langoSoftShadow()
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("数据默认保存在本机", systemImage: "lock")
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.ink)
            Text("未配置 AI 时不会发送任何记录。AI、同步、词典和 Prompt 都可以稍后在设置中处理。")
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
                Label("创建 \(draft.resolvedTargetLanguage.zhHansName) 空间", systemImage: "plus.circle.fill")
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
    let title: String
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
        .accessibilityLabel(title)
        .accessibilityValue(selectedLanguage.pickerMenuTitleForChineseUI)
        .accessibilityHint("选择\(title)")
    }
}

private struct PickerRow<PickerContent: View>: View {
    let title: String
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
                Text(title)
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
