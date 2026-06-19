# Reading AI/TTS Vertical Slice Evidence

日期：2026-06-01

## 1. 代码落地范围

- Core：Reading import preflight / registry、library model、Markdown parser contract、appearance profile、segmentation、dictionary exact lookup、source anchor stale 判定、reading AI explanation model、`TTSSentenceSource.readingDocumentSentence(documentID:sentenceID:)` 和 media artifact owner。
- Data：`v12_create_reading_domain_infrastructure` migration、`GRDBReadingLibraryRepository`、reading document / collection / tag / search index / import batch / lifecycle / position / source anchor / AI operation summary schema、reading TTS source columns round-trip。
- AI：`ReadingSelectionExplanationService`，使用 `URLSessionAIProviderHTTPClient` / `AIProviderHTTPClient` 边界，支持 OpenAI-compatible Chat 与 OpenAI Responses，拒绝 Anthropic / Gemini reading explanation 直到单独适配。
- UI / App：`ReadingLibraryStore`、`ReadingDocumentStore`、`ReadingLibraryView`、iPhone `记录 / 阅读 / 练习 / 记忆` Tab、iPad reading route、macOS Reading section、AppEnvironment 中真实 GRDB reading actions、reading selection explanation action 和 reading TTS action。

## 2. VMark 参考快照

- 本地路径：`/Users/zibuyu/code/openSource/vmark`
- commit：`ea24eb8f39cc6b8a3aed3ff6427b10060a3eec61`
- 工作区状态：执行 `git -C /Users/zibuyu/code/openSource/vmark status --short` 无输出。

本轮吸收的设计点：

- Markdown pipeline 与格式注册思想：LangoTrace 使用 `ReadingImportFormatRegistry` 和 `ReadingMarkdownParser`，不把 Markdown 原文直接塞进单个不可测 renderer。
- 大文件 pre-read gate：LangoTrace 在 `ReadingImportPreflight` 中先检查文件扩展和 byte size，再允许读取正文。
- source-mode fallback：LangoTrace 首轮保留 unsupported block fallback，不承诺 Markdown 编辑器或 WYSIWYG round-trip。
- CJK / 多语言风险清单：手动 selection 不依赖英文空格分词，测试覆盖 CJK、日语、重音拉丁和 RTL 短文本。
- theme token 与阅读样式：LangoTrace 以 `ReadingAppearanceProfile` / `ReadingPresentationStyle` 控制阅读宽度、行距、段距、代码块和色彩角色。

未复制的内容：

- 未引入 Tauri、React、Tiptap、ProseMirror、CodeMirror 或 VMark 的源码。
- 未复制 VMark 的编辑器、WYSIWYG、媒体解析或前端命令总线实现。
- 未保留真实用户文档、真实词典或大体积 fixture。

## 3. 验证记录

阶段提交：

- `c8d6760 Add reading vertical slice foundation`
- `60df1a0 Wire reading AI and TTS actions`

已执行并通过的聚焦验证：

```bash
swift test --package-path Packages/LangoTraceData --filter GRDBReadingLibraryRepositoryTests
swift test --package-path Packages/LangoTraceData --filter 'GRDBReadingLibraryRepositoryTests|AppDatabaseReadingMigrationTests'
swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests
swift test --package-path Packages/LangoTraceUI --filter 'ReadingDocumentStoreAIAndTTSTests|ReadingLibraryStoreTests|ReadingPresentationTests'
swift test --package-path Packages/LangoTraceCore --filter PhoneTabNavigationTests
xcodebuild -scheme LangoTrace-macOS -project LangoTrace.xcodeproj -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

此前基础切片还分别通过了 Core reading import / registry / markdown / appearance / segmentation / dictionary / source anchor / TTS key、Data reading migration / media artifact reading source、AI reading explanation service、UI reading layout / markdown renderer / stale AI/TTS store 的聚焦测试。

## 4. 当前限制与后续拆分

- 当前阅读正文选择是 SwiftUI block 点击级 selection，不是完整 TextKit selection engine；TextKit / UIKit / AppKit bridge 不是本轮 Phase 0 阻塞门禁，但后续精细选词、跨行选择、CJK / RTL 光标体验和 VoiceOver 必须单独验收。
- 文件导入 UI 已接入 SwiftUI file importer / open panel 路径，当前只启用 `.txt` / `.md`，并在读取正文前执行 extension 与 byte-size metadata preflight；后续仍需补真实 permission denied / cancel 人工验收、长期外部文件引用和 sandbox bookmark 管理。
- Markdown renderer 是原生 block presentation 第一版，不支持表格、Mermaid、HTML preview 或编辑器。
- Reading AI explanation 不做二次预览确认；点击 `解释` 即为显式触发。后续如引入全文总结、全文翻译或历史记忆上下文，必须另开 AI plan。
- Reading TTS 只做用户点击句子 / 正文块播放，不做全文朗读、批量预生成、后台播放或锁屏控制。
- Reading dictionary 仅保留 exact lookup contract 和合成 100k fixture 阈值测试，不做真实词典导入 UI。
