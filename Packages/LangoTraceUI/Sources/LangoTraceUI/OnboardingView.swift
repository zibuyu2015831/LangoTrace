import LangoTraceCore
import SwiftUI

struct OnboardingView: View {
    @Binding var draft: OnboardingDraft
    let onCreateLanguageSpace: () -> Void

    private let nativeLanguages = ["中文", "英语", "日语", "韩语", "法语", "德语", "西班牙语"]
    private let targetLanguages = ["英语", "日语", "法语", "德语", "西班牙语", "韩语"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                VStack(alignment: .leading, spacing: 18) {
                    Picker("母语", selection: $draft.nativeLanguage) {
                        ForEach(nativeLanguages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    Picker("目标语言", selection: $draft.targetLanguage) {
                        ForEach(targetLanguages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    Picker("水平自评", selection: $draft.level) {
                        ForEach(LanguageLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .langoPanel()

                Button(action: onCreateLanguageSpace) {
                    Label("创建第一个语言空间", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("创建 \(draft.targetLanguage) 学习空间并进入主体页面")

                Text("\(draft.nativeLanguage) -> \(draft.targetLanguage) · \(draft.level.rawValue)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .langoPageBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("创建语言空间")
                .font(.largeTitle.weight(.semibold))
            Text("一个语言空间对应一个目标语言。先记录母语、目标语言和当前水平，之后所有记录、练习和长期记忆都会归档在这里。")
                .font(.body)
                .foregroundStyle(LangoTraceDesign.ColorToken.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
