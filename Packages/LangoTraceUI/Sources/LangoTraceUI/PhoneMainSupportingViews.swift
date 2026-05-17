import LangoTraceCore
import LangoTraceData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let languageSpace: LanguageSpacePreview
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("生活记录") {
                    TextField("标题", text: $title)
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                }
                Section("隐私") {
                    Label("当前为本地保存和 Local Mock，不会发送到外部 AI。", systemImage: "lock")
                }
            }
            .navigationTitle("写一句")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(title, bodyText)
                        dismiss()
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EntryDetailView: View {
    let languageSpace: LanguageSpacePreview
    let entry: LearningEntry
    let rendering: LearningRendering?
    let practiceItems: [PracticeItem]
    let onPractice: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: entry.title,
                    subtitle: "\(entry.sourceTitle) · \(languageSpace.targetLanguage) · \(entry.scene)"
                )
                HStack(alignment: .top, spacing: 14) {
                    TextPanel(title: "母语记录", text: entry.body)
                    TextPanel(title: "目标语言", text: rendering?.targetText ?? "等待生成")
                }
                if let rendering {
                    RequestPreviewCard(entry: entry, rendering: rendering)
                    SectionHeader(title: "逐句练习", subtitle: "Local Mock 生成，可先验证页面闭环")
                    ForEach(Array(rendering.sentences.enumerated()), id: \.element.id) { index, sentence in
                        SentencePairView(index: index + 1, sentence: sentence, onPractice: onPractice)
                    }
                }
                SectionHeader(title: "练习入口", subtitle: "当前先保留本地 mock 会话")
                ForEach(practiceItems) { item in
                    CompactPanel(title: item.title, text: item.summary, systemImage: "waveform")
                }
            }
            .padding(20)
        }
        .navigationTitle("记录详情")
        .langoPageBackground()
    }
}

struct PracticeSessionView: View {
    let entry: LearningEntry
    let rendering: LearningRendering?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "跟读练习", subtitle: entry.title)
            Text(rendering?.targetText ?? "当前记录还没有可练习内容。")
                .font(.title3.weight(.semibold))
                .lineSpacing(5)
            RequestPreviewCard(entry: entry, rendering: rendering)
            Spacer()
        }
        .padding(20)
        .navigationTitle("练习")
        .langoPageBackground()
    }
}

struct PhoneContextHeader: View {
    let languageSpace: LanguageSpacePreview
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(languageSpace.displayContext, systemImage: "text.badge.star")
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Capsule())
            Label(statusText, systemImage: "lock")
                .font(.footnote.weight(.medium))
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                .accessibilityLabel(statusText)
        }
    }
}

struct HeroActionCard: View {
    let languageSpace: LanguageSpacePreview
    let onNewEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今天记录一点生活")
                    .font(.system(.title2, design: .default, weight: .semibold))
                Text("写一句、拍一张照片，或把今天想说的话留给之后的 \(languageSpace.targetLanguage) 练习。")
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                ActionChip(title: "写一句", systemImage: "pencil", action: onNewEntry)
                ActionChip(title: "拍照", systemImage: "camera") {}
                ActionChip(title: "听一句", systemImage: "play") {}
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 20)
        .langoSoftShadow()
    }
}

struct EntryCard: View {
    let entry: LearningEntry
    let targetLanguage: String
    let rendering: LearningRendering?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                        Text("\(entry.sourceTitle) · \(targetLanguage) · \(entry.scene)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        InlineStatusLabel(text: entry.practiceSummary, systemImage: "waveform")
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    }
                }

                Text(entry.body)
                    .font(.body)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let rendering {
                    Divider()
                    Text(rendering.targetText)
                        .font(.callout.weight(.medium))
                        .lineSpacing(3)
                        .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .langoPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title)，打开记录详情")
    }
}

struct EmptyEntryPanel: View {
    let onNewEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("还没有记录", systemImage: "square.and.pencil")
                .font(.headline)
            Text("先写下一条生活片段，再生成本地 mock 学习材料。")
                .font(.callout)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
            Button(action: onNewEntry) {
                Label("创建第一条记录", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .langoPanel()
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        }
        .padding(.top, 4)
    }
}

struct ActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
        }
        .buttonStyle(.plain)
        .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(title)
    }
}

struct CompactPanel: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(LangoTraceDesign.ColorToken.accent)
                .frame(width: 34, height: 34)
                .background(LangoTraceDesign.ColorToken.surfaceAccentMuted)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .langoPanel(padding: 16)
    }
}
