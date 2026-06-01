# 阅读基础设施与 AI/TTS 纵向切片方案

状态：Draft
自审核状态：Reviewed
类型：feature
创建日期：2026-06-01
最后更新日期：2026-06-01

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以“阅读是语言学习一级场景”为前提，落地一个基础设施优先且重视精美阅读体验的阅读纵向切片：把产品 / 导航 / 阅读资料库 / 导入扩展 / Markdown 渲染 / 阅读样式 / 数据 / AI / TTS 的长期规则先沉淀到开发文档，再实现阅读资料导入、资料库管理、Markdown / 纯文本阅读呈现、手动选词、真实 AI selection explanation、真实 reading sentence TTS 播放、source anchor stale 表达，以及后续阅读 MVP 可继续扩展的正式 Reading domain 边界。

**Architecture:** 本任务是 feature 级纵向切片，但按早期开发阶段原则，不把既有三 Tab 或临时页面骨架当成长期包袱。若用户批准实施，本方案应同步更新产品主参考、导航规范、页面清单和 Reading 领域规范，并把阅读作为正式一级学习入口接入三端；同时将阅读资料库基础设施前置为本轮核心范围，提供资料列表、导入批次、分组 / 标签、搜索索引、软删除 / 恢复和生命周期事件的最小闭环，为后续 EPUB / PDF / HTML / Web clip、词典导入、词状态、导出和同步保留扩展位。阅读文本、结构、position、library metadata、source anchor、operation summary 采用正式 GRDB 主数据与 repository；Markdown 通过 LangoTrace 自有 `ReadingMarkdownParser` / `ReadingMarkdownBlockRenderer` / `ReadingAppearanceProfile` 转换为结构化 block 和原生阅读 presentation，而不是把原始 Markdown 直接塞进单个 SwiftUI `Text` 或 WebView；AI 解释复用现有用户自带 Provider / Keychain / HTTP client 边界并新增 reading prompt；TTS 播放复用现有 `SentenceAudioPlaybackCoordinator` / media artifact 基础设施并扩展 reading sentence source；UI 通过共享 `ReadingLibraryStore` / `ReadingDocumentStore` / action seam 装配到三端正式 route。

**Tech Stack:** Swift 6、Swift Testing、SwiftUI Multiplatform、GRDB、LangoTraceCore、LangoTraceData、LangoTraceAI、LangoTraceSpeech、LangoTraceUI、Prompt Registry、现有 `scripts/verify.sh` 和文档检查脚本。

---

## 1. 用户确认记录

- 2026-06-01：用户要求根据 `docs/reference/research/2026-06-01-reading-integration-assessment.md` 立即创建详细 active plan 文档。
- 2026-06-01：本方案仅获得“创建 active plan 文档”的授权；尚未获得生产代码实现授权。
- 2026-06-01：方案初版曾将阅读确认为长期一级学习场景的设计输入，但为控制范围暂不修改 `PhoneRootTab`，不立即把 iPhone 主导航改为 `记录 / 阅读 / 练习 / 记忆`。
- 2026-06-01：用户明确要求鉴于当前项目已经实现真实 AI / TTS 请求，本次开发需要接真实 AI / TTS；同时要求重新检查并细化实施步骤。本方案因此从 research spike 调整为 feature 级阅读 AI/TTS 纵向切片。
- 2026-06-01：用户要求按早期开发阶段原则重新审查本方案：发现错误或落后的应用级设计可以主动提出推倒重来；基础设施应优先采用清晰、可扩展且符合现有架构边界的方案；开发文档是 AI 辅助编程的全局控制面，发现规范过期或更优设计时应同步更新规范并持续沉淀。
- 2026-06-01：本次复审后，前一条“不修改 `PhoneRootTab` / 不更新导航规范”的保守限制被降级为“尚未获得实施授权前不改代码”。若用户批准本 feature 实施，方案建议把阅读作为正式一级入口接入，并同步修订相关规范；这仍不等于一次性实现完整阅读 MVP。
- 2026-06-01：用户进一步明确当前开发应优先做完整阅读资料库设计，方便导入和管理阅读素材；原“不做完整阅读资料库、分组、搜索、删除恢复和批量管理”的限制需要修订。虽然本轮仍不实现 EPUB / PDF 等格式的真实导入和阅读，也不实现完整词典导入 UI，但基础设施必须预留足够扩展，避免后续大量返工。
- 2026-06-01：用户要求重新评估 VMark 项目的 Markdown 阅读 / 编辑能力是否可借鉴，并要求在方案中补充具体参考代码文件位置，便于后续开发准确阅读和吸收。
- 2026-06-01：用户进一步明确阅读功能必须追求精美阅读体验，Markdown 渲染很重要；方案需要充分借鉴 VMark 的 Markdown 实现，尤其是其对多语言展示、CJK 排版、locale、主题 token 和多语言资源的努力。本轮因此不能把 Markdown 降级为普通文本展示，应建立可扩展的 Markdown block renderer 和阅读样式边界。
- 2026-06-01：用户确认不接受把 TextKit / SwiftUI chunk 选择前置成 Phase 0 阻塞门禁；AI explanation 不需要采用“预览确认后发送”的两步动作；async cancellation / stale response 必须作为进入实现前补齐的 P1 边界。

## 2. 需求描述

根据阅读整合调研，LangoTrace 长期应把阅读作为与记录、练习、记忆并列的一级学习场景，同时保留主 slogan：

```text
用生活记录学习语言。
Learn languages from your life.
```

但调研也指出：SwiftUI 阅读交互、长文本性能、导入 preflight、资料库管理、搜索、删除恢复、词典查询、CJK / RTL 手动选词、source anchor stale、AI 请求边界和 reading sentence TTS source 都存在高风险。当前项目已经具备真实 AI 文本请求、真实 TTS 生成 / 播放和本地媒体派生资产基础设施，因此本次不应只做纯 UI / Core spike，也不应只做一个无法承载资料管理的阅读页 shell，而应完成一个基础设施优先的真实纵向切片：用户导入或粘贴短文本后，阅读资料进入正式资料库，可以被搜索、分组 / 标签标记、软删除 / 恢复和打开阅读；用户在阅读中可以手动选词或句子，显式触发 AI 解释，显式触发该句 TTS 播放，并把所有请求限制在当前选择和有限上下文内。

## 3. 当前现状

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift` 当前定义 iPhone 一级 Tab 为 `记录 / 练习 / 记忆`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift` 当前通过 `TabView` 承载三 Tab。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`、`PadMainSections.swift`、`MacMainView.swift`、`MacWorkspaceContentView.swift` 已有三端骨架，但没有阅读资料库或阅读详情入口。
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift` 当前 migration 到 `v11_add_ai_provider_endpoint_validation_summary`，没有 reading schema。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift` 当前 `TTSSentenceSource` 覆盖已有句子来源，尚无 reading document source。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift` 已能通过 OpenAI-compatible chat / responses endpoint 发起真实结构化文本请求，但该 service 面向 Entry / LearningMaterial，不应直接复用为阅读解释语义。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift` 已提供 production-safe `AIProviderHTTPClient`；阅读 AI 能力应优先使用该通用 client，而不是在 SwiftUI View 里创建 `URLSession`。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift` 已通过 `SentenceAudioPlaybackCoordinator` 串联 TTS availability、Keychain secret resolver、media artifact cache、generation service 和 playback source resolver。
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md` 已记录词典能力边界，要求不要把词典做成独立词库产品。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md` 和 `2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md` 已记录 TTS / media artifact 的长期边界。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md` 原建议先做 research spike，再进入阅读 MVP；本方案根据用户补充要求，将 spike 升级为包含真实 AI/TTS 的窄范围纵向切片。
- `docs/spec/002-navigation-and-routing.md` 当前仍固定三 Tab。结合阅读调研和早期重构原则，该规范已落后于新的产品判断；如果实施本方案，不能只在代码里偷加入口，应先把规范更新为 `记录 / 阅读 / 练习 / 记忆` 的正式路线，并明确本轮只交付阅读最小闭环而不是完整书库。
- VMark 本地源码位于 `/Users/zibuyu/code/openSource/vmark`，其 Markdown 格式注册、large-file gate、Markdown 清理、source / WYSIWYG 路由、content search 和 selection context 设计可作为架构参考；但 VMark 是 Tauri + React + Tiptap / ProseMirror / CodeMirror 项目，LangoTrace 只能吸收思想和测试策略，不复制跨栈实现，不引入 React / Tiptap / ProseMirror 依赖。

## 4. 目标

1. 将阅读从隐藏或二级原型入口提升为正式一级学习场景的工程入口：
   - 产品主参考更新一句话定位和双来源学习对象。
   - 导航规范更新 iPhone 长期主 Tab 为 `记录 / 阅读 / 练习 / 记忆`。
   - 页面清单记录三端阅读 route、当前能力边界和未实现能力。
2. 验证三端阅读交互路线：
   - iPhone：正文单栏，点词或选句后出现 bottom sheet。
   - iPad：正文和 inspector 可并列。
   - macOS：资料库 / 正文 / inspector 有可扩展布局模型，支持键盘或工具栏意图。
3. 建立阅读资料库基础设施：
   - 支持按语言空间隔离的资料列表、最近阅读、导入批次、分组 / 标签、搜索索引、软删除 / 恢复和生命周期事件。
   - 本轮 UI 至少提供资料列表、搜索、导入 / 粘贴、打开、删除和恢复入口；批量导入可以先用单批次多 item 的 repository / operation summary 验证，完整多选管理可后续增强。
4. 建立可扩展导入架构：
   - 定义 `ReadingImportFormatRegistry` / `ReadingImportAdapter` contract。
   - 本轮只注册 pasted text、`.txt`、`.md` adapter。
   - 为后续 EPUB / PDF / HTML / Web clip 保留 adapter id、adapter version、source format、MIME / UTI、body storage kind、managed file body、import batch 和 failure category 扩展位。
   - iOS / iPadOS / macOS 文件导入必须经过 document picker / open panel 的安全访问边界，metadata preflight 在读取 body 前执行，导入成功后只保存 App 管理的副本或 inline body，不持久化外部 security-scoped URL。
5. 借鉴 VMark 的 Markdown 处理能力并落地精美 Markdown 阅读体验：
   - 吸收 Markdown allowlist、格式注册表、Markdown pipeline、block / inline conversion、大文件 pre-read gate、source-mode fallback、code-aware cleanup、content search、selection context、主题 token、CJK formatter 和多语言展示测试的设计。
   - 首轮 Markdown 阅读至少覆盖标题层级、段落节奏、引用块、列表缩进、代码块、分隔线、链接、强调文本、inline code、Dark Mode、Dynamic Type、阅读宽度、行距和段距的原生 presentation model。
   - `ReadingAppearanceProfile` / `ReadingRenderStyle` 必须作为 renderer 输入预留，第一版可只提供默认样式，但不能把字体、字号、行距、代码块样式、主题色和阅读宽度硬编码成不可替换实现。
   - 不复制 VMark 的 Tauri / React / Tiptap / ProseMirror / CodeMirror 实现，不把 Markdown 编辑器作为本轮目标。
6. 验证 10k 字级文本能按 chunk 形成稳定 presentation model，不在单个 SwiftUI body 中构建完整 token tree。
7. 验证 pasted text、`.txt`、`.md` 的导入 preflight 规则，包括空内容、编码失败、超限文件和 size gate。
8. 验证 100k 词条本地 exact lookup 的纯 Swift 索引可行性，为后续 GRDB normalized index 和词典导入设计提供阈值输入；本次不做真实词典导入 UI，但必须在 Reading spec 中预留 `DictionaryImportAdapter`、dictionary import batch、normalized lookup index 和 lexeme state 的长期边界。
9. 验证手动选择对英文、带重音拉丁文、CJK、日语和 RTL 文本不会依赖英文空格分词。
10. 验证 `source anchor` 能在 document revision / structure version 变化时表达 stale，而不是静默指向错误文本。
11. 为阅读 selection explanation 接入真实 AI Provider 请求链路：用户显式点击后，只发送 selection、句子和有限上下文，不自动发送全文。
12. 为 reading sentence TTS 接入真实 TTS 生成 / cache / playback 链路：用户显式点击句子播放时使用 `readingDocumentSentence` source，不复用 learning material source。
13. 产出 feature evidence 文档，记录测试结果、阈值建议、资料库设计、导入扩展设计、VMark Markdown 借鉴结论、AI/TTS 隐私边界和后续 MVP 拆分建议。

## 5. 范围

本任务做：

- 新增 Core 层阅读模型、导入 preflight、Markdown block / inline parse contract、分段分句 contract、词典 lookup index、source anchor stale 判定、AI selection explanation request / result、reading TTS source contract。
- 新增 Core 层资料库和导入扩展模型，包括 `ReadingLibraryDocumentSummary`、`ReadingCollection`、`ReadingTag`、`ReadingImportBatch`、`ReadingImportAdapter`、`ReadingImportFormatRegistry`、`ReadingDocumentLifecycleEvent` 和 search query contract。
- 新增 Data 层 Reading domain 基础 schema、migration、repository 和非敏感 operation summary，只支持短文本 / Markdown inline body 的真实导入，但表结构必须覆盖 library document、collection / tag、document membership、structure block / sentence、position、source anchor、search index、import batch / item、document lifecycle event、AI explanation operation 的长期扩展点。
- 新增 AI 层 reading selection explanation service、Prompt Registry 文档、结构化输出解析、错误分类和日志脱敏测试。
- 扩展 TTS source / media artifact 映射，使 reading sentence TTS 使用独立 source key、owner 和 cache key。
- 新增 UI 层 `ReadingLibraryStore`、`ReadingDocumentStore`、reading presentation model、Markdown block renderer、默认阅读 appearance profile、三端正式 reading route、资料库列表 / 搜索 / 分组 / 导入 / 删除 / 恢复入口、AI explanation action 和 sentence TTS action；iPhone 顶层导航在用户批准实施后改为 `记录 / 阅读 / 练习 / 记忆`。
- 更新产品主参考、导航规范、页面清单、AI / Data / TTS spec 和新增 Reading 领域规范，使开发文档与新的应用级设计一致。
- 新增聚焦单元测试，覆盖资料库隔离、导入批次、格式识别、编码失败、Markdown block parse / renderer contract、多语言 Markdown fixtures、阅读 appearance profile、搜索索引、软删除 / 恢复、分组 / 标签、分段、lookup、selection、anchor stale、AI request contract、TTS source key、三端 presentation state。
- 新增 `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md` 记录证据和结论。

本任务不做：

- 不做 EPUB / PDF / HTML / Web clip 的真实解析、导入和阅读；本轮只预留 adapter、schema 和 failure category。
- 不做完整词典导入 UI，不落生产级 `GRDBDictionaryRepository`；但必须在 spec 和 schema 设计中预留 dictionary import / normalized lookup / lexeme state 的后续边界，避免阅读资料库和词典主数据未来冲突。
- 不做资料库的所有高级管理能力：不做多选批量编辑 UI、不做复杂书库封面墙、不做智能分类、不做云书架、不做跨设备阅读位置同步；本轮做资料库基础设施和最小管理闭环。
- 不自动触发 AI explanation；只允许用户显式点击 selection explanation。
- 不自动触发 TTS；只允许用户显式点击句子播放。
- 不实现 EPUB、PDF、HTML、网页抓取、MDX、StarDict、Lingvo DSL。
- 不实现用户自定义阅读样式 UI 或持久化设置；但 renderer / presentation model 必须接受 `ReadingAppearanceProfile`，并把后续字体、字号、主题、行距、段距、代码块样式和阅读宽度自定义作为正式扩展点。
- 不内置版权词典。
- 不做同步、可恢复备份、StoreKit、全文 AI 总结、全文翻译、批量 TTS、后台播放或锁屏控制。

## 6. 证据与决策依据

- `docs/reference/research/2026-06-01-reading-integration-assessment.md`：
  - 阅读应作为长期一级学习场景。
  - 主 slogan 保留，不在 slogan 中枚举阅读。
  - 实施上先验证窄范围纵向切片，再进入完整 MVP，再单独导航变更。
  - VMark 可借鉴格式注册表、大文件打开管线、文档状态单元、command bus、service tier 和 selection context，不复制跨栈实现。
- `/Users/zibuyu/code/openSource/vmark`：
  - `dev-docs/architecture.md`：用于理解 VMark 的 utils / services / hooks / stores 分层和 document-as-state-unit 思路。
  - `dev-docs/large-file-open-pipeline.md`：用于借鉴 pre-read size gate、large / huge / refused 分流、source-mode fallback 和 load id 防乱序。
  - `dev-docs/cjk-gotchas.md`、`src/lib/cjkFormatter/`：用于借鉴 CJK / Latin 混排、全角标点、引号、破折号、韩文排除、surrogate pairs、技术 subspan 保护、Markdown protected region 和 integrity verification 的设计；LangoTrace 本轮不自动改写用户 Markdown，但 Markdown renderer、fixtures 和后续 language pack 边界必须吸收这些风险。
  - `src/utils/markdownPipeline/`：用于借鉴 Markdown block / inline parse、AST 转换、URL validation、media converters、custom inline、wiki link、details / toc plugin 和 round-trip 测试思路；LangoTrace 应以 Swift 原生 block model 重写，不迁移 ProseMirror schema。
  - `src/lib/formats/registry.ts`、`src/lib/formats/types.ts`、`src/lib/formats/index.ts`、`src/lib/formats/adapters/markdown.tsx`、`src/lib/formats/markdownLargeFile.ts`：用于借鉴格式注册、Markdown allowlist、非 Markdown fallback 和 large Markdown source-mode 规则。
  - `src/utils/fileSizeThresholds.ts`、`src/services/navigation/largeFileRouting.ts`、`src/utils/largeFilePrompts.ts`：用于借鉴导入前 metadata gate 和用户确认边界。
  - `src/utils/markdownCodeMask.ts`、`src/utils/cleanPastedMarkdown.ts`、`src/utils/markdownPasteDetection.ts`、`src/utils/htmlToMarkdown.ts`：用于借鉴 code-aware Markdown 清理和 AI 粘贴 Markdown 处理；LangoTrace 需用 Swift 重写。
  - `src/components/Editor/TiptapEditor.tsx`、`src/components/Editor/SourceEditor.tsx`、`src/components/Editor/Editor.tsx`：用于理解 Markdown WYSIWYG / source fallback 的交互取舍；不迁移 React / Tiptap / ProseMirror。
  - `src/theme/`、`src/styles/`、`dev-docs/decisions/ADR-014-theme-tokens-as-typed-data.md`：用于借鉴主题 token、代码块 / media / popup CSS 边界和 snapshot regression 思路；LangoTrace 应映射为 SwiftUI design token / `ReadingAppearanceProfile`，不复制 CSS。
  - `src/i18n.ts`、`src/i18n.test.ts`、`src/locales/`、`src/stores/__tests__/settingsStore.i18n.test.ts`：用于借鉴 locale fallback、`lang` 标记、跨窗口 language change sync 和多语言资源组织；LangoTrace 阅读正文语言仍以 `LanguageSpace` / document target language 为主，不与 App UI language 混淆。
  - `src/services/media/resolveMediaSrc.ts`、`src/services/media/resolveMediaSrc.test.ts`、`src/utils/markdownUrl.ts`、`src/utils/markdownUrl.test.ts`：用于借鉴 Markdown URL、CJK 文件名、空格、相对路径和安全校验测试；LangoTrace 本轮不解析外部图片附件，但 future media / managed file body 边界应吸收这些用例。
  - `src/components/ContentSearch/`：用于借鉴资料内搜索的结果分组、命中定位和键盘导航；LangoTrace 底层应使用 SQLite FTS5 或可重建搜索索引，不扫描文件系统。
  - `src/services/editor/extractContext.ts`、`src/hooks/useGenieInvocation.ts`：用于借鉴 selection + limited surrounding context 的 AI 请求边界。
  - `src/services/commands/CommandBus.ts`：用于借鉴 Mac menu / toolbar / shortcut / context menu 汇聚到单一 command seam 的思路。
- `docs/spec/002-navigation-and-routing.md`：当前 iPhone 顶层 Tab 仍是三 Tab；结合阅读调研和早期重构原则，本方案认为该规范应在本 feature 实施前同步修订，而不是让代码继续迁就旧临时信息架构。
- `docs/spec/004-swiftui-architecture.md`：三端共享业务逻辑，但 UI 按设备分别设计；View 不直接创建 repository。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：阅读纵向切片不应引入默认外部请求或官方托管内容；真实 AI/TTS 必须由用户显式触发并使用用户自带 Provider。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：主数据、派生数据、附件、导出和 migration 需要明确边界。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：阅读 AI 解释属于真实 AI 能力，必须显式触发、展示发送范围、日志脱敏、Keychain 分层；本轮不采用“预览确认后发送”的两步动作。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：TTS source 和 artifact policy 不能混淆来源。
- `docs/workflows/add-ai-provider.md`：新增 AI 能力必须写清发送内容、Provider 配置、请求日志、失败恢复和 Prompt Registry。
- `docs/workflows/add-tts-provider.md`：新增逐句播放能力必须写清固定 / 用户文本边界、TTS endpoint、voice profile、cache invalidation、取消和 media artifact policy。
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`：词典是学习闭环工具，不是独立词典产品；查询日志不能记录完整隐私文本。
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`：媒体派生资产必须有 owner、policy 和清理边界；本任务复用既有 TTS 音频 artifact，不新增导出、同步或备份承诺。

## 7. 约束映射与验证路径

### 7.1 阅读是一级学习场景，本轮应同步修订应用级导航

- 来源：`docs/reference/research/2026-06-01-reading-integration-assessment.md` 第 1、5、13 节。
- 约束：阅读已经被确认是长期一级学习场景。早期开发阶段不应为了迁就三 Tab 临时骨架，把阅读藏到“记录”或“记忆”二级入口中形成新的技术债。
- 约束：本方案仍不做完整阅读 MVP，但应把正式信息架构更新为 `记录 / 阅读 / 练习 / 记忆`，并让三端都有明确 reading route。iPhone 修改 `PhoneRootTab`，iPad / macOS 修改 sidebar / workspace selection；平台外壳不同，业务 action seam 共享。
- 验证方式：实施前更新 `docs/product-main-reference.md`、`docs/spec/002-navigation-and-routing.md` 和 `docs/platform-page-inventory.md`；实施后测试 `PhoneRootTab.allCases` 包含 `.reading` 且顺序为 `entries / reading / practice / memory`。
- 阻塞判断：若用户不同意本轮改导航，则本方案不能按当前形态进入实现，应拆回“reading infrastructure without top-level route”并明确这是临时过渡，不得伪装成长期设计。

### 7.2 本地优先与隐私边界

- 来源：ADR-005、`docs/spec/005-ai-provider-prompt-and-privacy.md`、调研文档第 7.5 节。
- 约束：本任务会发送用户选中的阅读文本到用户自带 AI Provider，但只能在用户显式点击“AI 解释”后发送 selection、所在句子、有限上下文、目标语言、母语和 Prompt id/version；不得在导入、打开阅读页、滚动、选中、保存或播放 TTS 时自动发送。
- 约束：UI 必须展示或说明将发送的 selection 和上下文范围，但用户点击 AI 解释即为显式触发，不再增加“预览确认后发送”的二次确认动作；诊断日志、operation summary 和测试输出不得记录完整 selection、完整句子、完整上下文、响应体、API Key、Authorization header 或完整 Provider URL。
- 验证方式：AI service 测试检查 request body 包含 selection-only payload、Prompt id/version 和有限上下文；UI store 测试检查只有显式 action 才调用 AI；源码检索 `URLSession` 不出现在 SwiftUI View。
- 阻塞判断：若需要全文总结、全文翻译、历史记忆摘要或附件摘要，必须拆成独立 AI plan。
- 证据保留：`docs/reference/research/spikes/` 只能保存合成文本摘要、测试命令、阈值和结论；不得保存真实用户阅读材料、真实词典内容、AI 请求体或响应体。

### 7.3 数据边界

- 来源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、调研文档第 6 节。
- 约束：本任务允许新增 Reading domain 基础 schema。虽然真实导入只开放短文本 / Markdown inline body，schema 不应被设计成一次性 demo；必须覆盖 library document、collection / tag、document membership、structure block、sentence、position、source anchor、search index、import batch / item、document lifecycle event、AI explanation operation summary 和后续 managed file body 的扩展位。
- 约束：阅读文档是主数据，必须归属 `LanguageSpace`，有 stable id、body hash、content revision、structure version、soft delete、restore state、import status、source kind、source format、adapter id/version、body storage kind、target language code、UTC 时间戳和 active 查询边界。position 默认 device scoped；source anchor 不得只靠 sentence index。
- 约束：资料库主数据与阅读正文主数据必须分层。`reading_documents` 保存文档事实；`reading_collections`、`reading_document_collections`、`reading_tags`、`reading_document_tags` 保存资料库组织；`reading_document_search_index` 或 FTS5 virtual table 是可重建派生索引；`reading_import_batches` / `reading_import_items` 保存批次级状态；`reading_document_lifecycle_events` 保存删除、恢复、导入和打开等非敏感事件摘要。
- 约束：软删除不是物理删除。删除后 active 查询不返回，恢复后重新可见；source anchor、AI operation summary、TTS artifact owner 和后续 Memory / Practice 引用不能被静默误删。本轮不做同步，但 tombstone / lifecycle 字段必须让后续同步设计可判断删除与恢复。
- 验证方式：`AppDatabaseTests` 必须覆盖新 migration 空库、旧库迁移、重复 migrator、外键、CHECK、唯一索引、soft delete active 查询、restore 查询、position device scope、source anchor stale 输入字段、search index rebuild 标记和 operation summary 不含原文。
- 阻塞判断：若需要真实 managed file body 写入、EPUB/PDF/HTML 解析、export manifest 或 sync state，必须拆成后续 feature plan；但本轮不得省略这些后续能力所需的 schema 扩展位。

### 7.3.1 阅读资料库边界

- 来源：用户 2026-06-01 追加要求、调研文档第 5、6、10、11 节。
- 约束：阅读是一级学习场景，因此资料库不是装饰性列表。本轮必须形成最小可用资料库：按语言空间列出 active reading documents，支持 title 搜索、基础全文搜索或可重建搜索索引、最近阅读排序、collection / tag 归类、软删除、恢复和导入批次状态展示。
- 约束：阅读资料库必须以 `space_id` 为第一数据边界。`reading_documents`、`reading_collections`、`reading_tags`、membership、search index、import batches、import items、lifecycle events、position 和 AI operation 查询都必须 scoped by current `LanguageSpace`；collection / tag 不做跨空间全局池。导入资料时默认进入当前 active language space；外部入口或恢复场景无法确定 space 时，必须先选择语言空间，不能写入全局资料库。
- 约束：资料库 UI 不承诺完整批量管理，但 repository 必须支持 import batch 多 item、批次部分成功、失败 item 可重试、重复导入去重或提示、document lifecycle event 和 collection/tag membership 的幂等写入。
- 约束：资料库搜索不得触发 AI，不得记录完整正文到诊断日志。首版 repository API 按 FTS5 能力设计，优先使用 SQLite FTS5 external-content 或等价可重建索引；如果 GRDB FTS5 接入在实现期被证明成本过高，可先使用 `reading_document_search_index` 普通表作为 fallback，但 public repository API、测试语义和 spec 命名不得改变，后续切换到 FTS5 不应影响 UI store。
- 验证方式：Data tests 覆盖 `space_id` 隔离、collection/tag membership 幂等、active / deleted / restored 查询、search index rebuild、import batch partial failure；UI tests 覆盖打开阅读 Tab 只加载本地资料库，不触发 AI/TTS。
- 阻塞判断：如果实施者不能在本轮完成最小资料库闭环，应停止实现并把本方案拆成 `feature-reading-library-foundation` 和 `feature-reading-ai-tts-vertical-slice`，不能回退到隐藏入口或纯正文 demo。

### 7.4 三端 UI 边界

- 来源：`docs/spec/004-swiftui-architecture.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`。
- 约束：UI 使用 presentation model 和 SwiftUI view；平台差异在 UI 层，选择、lookup、anchor 判定在 Core / store 层。
- 约束：本轮阅读正文可以用 SwiftUI chunk view 落最小闭环，但不能把 SwiftUI `Text` 视为长期复杂文本交互引擎。TextKit / UIKit / AppKit bridge 选择不作为 Phase 0 阻塞门禁；实施者可先按 SwiftUI chunk 纵向切片推进，但 evidence 必须记录当次是否继续 SwiftUI chunk、是否引入 bridge、或是否降级为 plain reader 的理由和风险。
- 约束：TextKit / UIKit / AppKit bridge 只能作为阅读呈现和 selection engine，不得越过 `ReadingDocumentStore` 直接访问 repository、AI Provider、TTS coordinator 或 Keychain。
- 验证方式：UI tests 检查 iPhone / iPad / macOS layout model，不靠截图作为唯一证据。
- 验证方式：evidence 必须记录 iPhone 手动选词、iPad inspector 并列、macOS 键盘选择、10k 字滚动、Dynamic Type 和 VoiceOver 的人工或 simulator 验证结果；若未完成真实设备验证，完成标准中必须标为剩余风险。
- 阻塞判断：若 View 直接持有 SQLite / Provider concrete，必须重写。

### 7.4.1 Markdown 渲染和阅读样式边界

- 来源：用户 2026-06-01 对精美阅读体验的要求、VMark Markdown pipeline / CJK formatter / theme token 参考、`docs/spec/003-ui-design-system.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`。
- 约束：Markdown 渲染是本轮 Reading domain 的正式能力，不是后期美化。`.md` 导入后必须生成 LangoTrace 自有 `ReadingMarkdownBlock` / `ReadingInlineRun` / `ReadingBlockPresentation`，至少覆盖 heading、paragraph、blockquote、unordered / ordered list、code block、inline code、link、emphasis、strong、horizontal rule 和 unsupported block fallback。UI 不得把完整 Markdown 原文直接塞进单个 `Text`、`WKWebView` 或不可测试的第三方 renderer。
- 约束：阅读视觉质量必须通过 `ReadingAppearanceProfile` / `ReadingRenderStyle` 输入控制。第一版可只提供 default profile，但 profile 必须显式包含字体角色、标题层级比例、正文 line spacing、paragraph spacing、blockquote treatment、list indentation、code block typography、link style、reading width、color role、Dark Mode 和 Dynamic Type strategy；后续用户自定义样式不得要求重写 parser、repository 或 AI/TTS selection contract。
- 约束：样式是 presentation preference，不是 document fact。本轮不做用户自定义样式 UI 或持久化，但 `ReadingAppearanceProfile` 不得写入 `reading_documents` 正文字段，不得改变 body hash、content revision、structure version、source anchor、sentence id 或 AI/TTS source key。
- 约束：多语言展示必须前置验证。Markdown renderer 和 fixtures 至少覆盖英文、带重音拉丁文、中文 / 日文混排、韩文、RTL 短段、CJK + Latin 混排、CJK 文件名 / link text、inline code、URL、ordered list marker、code fence 和 quote / dash 组合。借鉴 VMark 的 CJK formatter 风险清单，但本轮默认不自动重写用户原文标点；任何自动格式化必须以后续 language pack / formatter plan 单独批准。
- 约束：source anchor、manual selection、AI explanation 和 TTS sentence source 必须基于结构化 text range / sentence / source anchor，而不是基于视觉布局坐标、line number 或 style-dependent attributed string offset。
- 验证方式：Core tests 覆盖 Markdown block parse、unsupported fallback、CJK / RTL / code protected region、source range 保留；UI tests 覆盖 default appearance profile 映射、Dynamic Type 不改变 anchor 输入、Dark Mode color role、Markdown block renderer 不触发 AI/TTS；evidence 记录 VMark commit、阅读文件、吸收设计、未复制实现和多语言渲染结论。
- 阻塞判断：如果实施者只能交付 plain text reader，不能声称 Markdown 阅读体验已完成；应把本方案拆成 `feature-reading-library-foundation` 和 `feature-reading-markdown-rendering-foundation` 后再继续 AI/TTS。

### 7.5 词典边界

- 来源：`docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`。
- 约束：本任务只验证本地 exact lookup index，不做真实词典导入 UI、不内置词库、不做外部词典 App 跳转。
- 约束：虽然不实现完整词典导入，本轮必须在 `docs/spec/012-reading-learning-domain.md` 中定义后续 `DictionaryImportAdapter`、`dictionary_import_batches`、`dictionary_entries`、normalized lookup、language-specific normalization strategy、lexeme state 和阅读资料库 / source anchor 的关系，避免后续词典主数据与 ReadingDocument、Memory 和 Practice 返工。
- 约束：Reading schema 本轮不必创建完整 `dictionary_entries` 表，但不能把词典 lookup 设计成只有内存 demo；Core contract 应保留 `ReadingDictionaryLookupIndex` 与未来 repository 结果的边界。
- 约束：CJK / RTL / 日语假名汉字等语言处理本轮以手动 selection 为主，不做自动全文 token 状态。后续自动 tokenization 必须通过 `TextSegmentationService` / language pack 扩展，优先参考 Unicode UAX #29、Apple `NLTokenizer` 和语言特定 normalization strategy；不得把 lowercased English word boundary 作为全局默认。
- 验证方式：fixtures 为合成 100k 词条；无版权词典文件进入仓库。
- 阻塞判断：如需真实词典格式，先新建 dictionary import plan。

### 7.5.1 文件导入权限和外部文件生命周期

- 来源：Apple 平台沙盒边界、`docs/spec/007-data-storage-migration-export-and-attachments.md`、VMark large-file pre-read gate。
- 约束：`.txt` / `.md` 文件导入不得假设永久可读外部路径。iOS / iPadOS 通过 document picker，macOS 通过 open panel / security-scoped resource 或 sandbox bookmark 的后续方案；本轮只在用户选择文件后的短生命周期访问内做 metadata preflight、读取允许内容并写入 App 管理的 inline body 或未来 managed file copy。
- 约束：preflight 顺序必须是：确认文件类型和安全访问 -> 读取 metadata / byte size -> 判断 hard limit / warning -> 用户确认 -> 读取 bytes -> decode -> 写入 import batch / document。不得先读完整文件再判断超限。
- 约束：数据库和 operation summary 只能保存 original filename、extension、MIME / UTI、byte size bucket、adapter id/version 和 failure category；不得保存外部绝对路径、security-scoped bookmark、完整文件内容或用户目录结构。本轮不实现长期 bookmark 管理。
- 验证方式：Core preflight tests 覆盖 metadata-before-read；Data import item tests 覆盖不保存完整路径；UI / App assembly tests 覆盖 unsupported / permission denied / cancelled / encoding failed 的稳定错误状态。
- 阻塞判断：若需要长期引用外部文件而非导入副本，必须新增 attachment / external file access plan，不得混入本纵向切片。

### 7.6 真实 TTS 边界

- 来源：`docs/spec/011-tts-provider-configuration-and-playback.md`、`docs/workflows/add-tts-provider.md`、`docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`。
- 约束：reading sentence TTS 只能由用户点击句子播放触发；必须复用 `SentenceAudioPlaybackCoordinator`、TTS availability、Keychain secret resolver、media artifact cache 和 playback source resolver。
- 约束：reading source 必须独立于 `.entry`、`.learningMaterialSentence` 和 `.temporary`，建议新增 `TTSSentenceSource.readingDocumentSentence(documentID:sentenceID:)`，并同步 Data source columns 与 artifact key canonical representation。
- 验证方式：Core 测试验证 reading source canonical key 不与 learning material key 冲突；Data media artifact 测试验证 source columns round-trip；UI store 测试验证打开阅读页不触发 TTS，只有句子播放 action 调用 coordinator。
- 阻塞判断：批量预生成、全文朗读、后台播放、锁屏控制和音频同步不在本任务内。

### 7.7 Evidence 和 fixture 边界

- 来源：`docs/plans/README.md` 对 spike / probe / fixture / evidence 的要求。
- 约束：本任务的 fixture 必须在测试代码中动态生成或使用短合成字符串；不得提交大体积 fixture 文件。
- 验证方式：`git status --short` 和 `find docs/reference/research/spikes -type f -maxdepth 1 -print` 检查新增内容；如新增 fixture 文件，必须在本方案实施记录说明大小、内容来源、保留原因和清理条件。
- 阻塞判断：如果需要保留真实样本文档或真实词典，必须先取得用户确认并新增隐私 / 版权边界说明。

### 7.8 开发文档沉淀边界

- 来源：`docs/README.md` 第 1.2、1.3、6 节，以及用户 2026-06-01 追加原则。
- 约束：本任务如果实施，不能只修改代码和 evidence。凡是形成长期规则的内容，必须写回当前事实源：产品定位写回产品主参考，导航写回导航 spec，Reading domain 数据 / 交互 / AI / TTS 边界写回新增 Reading spec 或既有 AI / Data / TTS spec。
- 约束：研究文档和 active plan 不能成为后续实现长期依赖的唯一事实源。实现完成后，后续 AI 会话应能只通过入口文档、spec、architecture、workflow 和实现地图理解 Reading domain。
- 验证方式：最终文档影响检查必须确认新旧事实源没有混用；`docs/reference/research/*` 只能作为证据来源，不作为正式实现规范。
- 阻塞判断：如果实施者发现现有 spec 与更优 Reading 设计冲突，应先更新 spec 并在 active plan 实施记录中说明，不应为了减少 diff 继续遵守过期规范。

### 7.9 VMark Markdown 借鉴边界

- 来源：用户 2026-06-01 追加要求、`docs/reference/README.md`、VMark 本地源码。
- 约束：VMark 的价值是 Markdown 资料处理和大文件体验的设计证据，不是 LangoTrace 的实现依赖。允许参考：格式注册表、Markdown allowlist、非 Markdown fallback、large-file pre-read gate、source-mode fallback、code-aware Markdown cleanup、content search、selection context、command bus 和 service tier 分层。
- 约束：VMark 的多语言努力必须被具体吸收而不是泛称参考。实施 evidence 必须记录当次 VMark commit、工作区状态和至少以下多语言相关参考：`dev-docs/cjk-gotchas.md`、`src/lib/cjkFormatter/`、`src/i18n.ts`、`src/locales/`、`src/services/media/resolveMediaSrc.test.ts`、`src/utils/markdownPipeline/`、`src/theme/`。如果 VMark 后续代码更新，后续评估必须基于新的 commit 追加记录，不能覆盖本次快照。
- 约束：禁止直接复制 VMark 的 React / Tiptap / ProseMirror / CodeMirror / Tauri 代码进入 LangoTrace；如后续需要复用小型算法或测试策略，必须先重新检查 VMark 当前 `LICENSE` 和依赖许可证，并在 evidence 中记录复用方式。当前建议全部用 Swift 原生重写。
- 约束：LangoTrace 的 Markdown 阅读不是 Markdown 编辑器。第一阶段导入 Markdown 后形成阅读资料正文、blocks、sentences 和 source anchors；不承诺 WYSIWYG 编辑、Markdown round-trip 保存、表格编辑、Mermaid 渲染或 HTML preview。
- 验证方式：active plan 实施记录和 evidence 必须写明 VMark 参考了哪些文件、吸收了哪些设计、明确没有复制哪些实现；`docs/spec/012-reading-learning-domain.md` 应把 Markdown adapter、code-aware cleanup 和 long-text fallback 写成 LangoTrace 自己的规范。

### 7.10 异步取消、重入和 stale response 边界

- 来源：用户 2026-06-01 追加确认、真实 AI/TTS action seam、语言空间切换和阅读资料库状态同步风险。
- 约束：`ReadingLibraryStore` 和 `ReadingDocumentStore` 必须为 import、load document、AI explanation、sentence TTS 等异步动作建立 operation id / request token / generation counter 或等价机制。任何旧 operation 完成时，若当前 `space_id`、`document_id`、`selection range`、`sentence_id` 或 request token 已变化，不得写入当前 UI state、selection、AI result、audio state 或 operation projection。
- 约束：语言空间切换、文档切换、selection 变化、关闭阅读详情、软删除当前文档或重复触发同一 action 时，必须取消或失效相关 in-flight import / load / AI / TTS task。取消应映射为稳定状态；用户主动取消或 state invalidation 不应写入 failed operation summary，也不应清除新的有效 selection。
- 约束：AI explanation 和 TTS 均保持用户显式单次动作触发，不引入“预览确认后发送”的二次确认流程。UI 可以展示将发送的 selection / context scope、Provider profile 和 model 作为操作说明或进行中状态，但不得把二次确认作为实现门槛。
- 验证方式：UI store tests 必须覆盖 stale AI response ignored、stale TTS response ignored、selection changed cancels or invalidates AI result、document switch cancels or invalidates AI/TTS、language space switch clears state and ignores old completions、double tap explain / play does not create duplicate active operations。
- 阻塞判断：如果实施者无法证明 stale completion 不会污染新 selection / document / space，本方案不能进入实现完成态。

## 8. 涉及代码文件路径

预计新增：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDocument.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImport.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImportRegistry.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSearch.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLifecycle.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingMarkdown.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAppearance.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDictionaryLookup.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTTS.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportRegistryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSearchQueryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingMarkdownRenderingTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingAppearanceProfileTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingImportBatchRepositoryTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingSearchIndexTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingDocumentLifecycleTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingMarkdownBlockRendererTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- `docs/prompts/reading/selection-explanation.md`
- `docs/spec/012-reading-learning-domain.md`

预计修改：

- `docs/product-main-reference.md`：更新一句话定位、一级学习对象和阅读作为一级学习场景的边界。
- `docs/platform-page-inventory.md`：登记三端阅读入口、当前实现状态和未实现能力。
- `docs/spec/002-navigation-and-routing.md`：将 iPhone 一级入口更新为 `记录 / 阅读 / 练习 / 记忆`，并补充三端 Reading route 承载规则。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：登记 reading selection-only AI request 边界。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：登记 ReadingDocument 主数据、source anchor、position、operation summary 和默认导出 / 同步待设计边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：登记 `readingDocumentSentence` source、owner 和 artifact policy。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`：新增 reading sentence source 和 canonical representation。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`：确认 `SentenceAudioRequest` 可承载 reading source；如需要则补充 non-sensitive summary。
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`：新增 Reading domain 基础 migration。
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`：扩展 TTS source columns round-trip 支持 reading document sentence。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`：注入 reading repository、AI explanation action、sentence audio playback action。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`：新增 `.reading`，顺序为 `记录 / 阅读 / 练习 / 记忆`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`PadMainView.swift`、`MacMainView.swift`：增加正式 reading route，不复用记录详情作为伪入口。

预计新增文档：

- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`
- `docs/prompts/reading/selection-explanation.md`
- `docs/spec/012-reading-learning-domain.md`

不应修改：

- 不应引入 EPUB / PDF / HTML / web import 的生产代码。
- 不应引入完整词典导入 repository、同步、导出或 StoreKit 代码。
- 不应把阅读 AI/TTS 直接写在 SwiftUI View 中。

## 8.1 VMark 参考代码文件路径

实施前必须阅读以下 VMark 文件，作为 Markdown / 资料库导入 / 大文件体验的参考。阅读目标是吸收设计边界和测试思路，不复制跨栈实现。

当前修订基线：`/Users/zibuyu/code/openSource/vmark` 在 2026-06-01 核对的 commit 为 `ea24eb8f39cc6b8a3aed3ff6427b10060a3eec61`，当时 `git status --short` 无输出。实施 evidence 必须重新记录当次 commit 和工作区状态；后续持续评估 VMark 新代码时，只能追加新的 commit 上下文，不能覆盖本次基线。

- `/Users/zibuyu/code/openSource/vmark/README.md`
- `/Users/zibuyu/code/openSource/vmark/LICENSE`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/architecture.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/large-file-open-pipeline.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-001-markdown-as-source-of-truth.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-008-workspace-as-single-facade.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-009-document-as-unit-of-state.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-010-editor-host-as-mode-agnostic-interface.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-012-command-bus-as-single-intent-path.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-013-service-tier-as-cross-cutting-seam.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/decisions/ADR-014-theme-tokens-as-typed-data.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/cjk-gotchas.md`
- `/Users/zibuyu/code/openSource/vmark/src/lib/formats/types.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/formats/registry.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/formats/index.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/formats/adapters/markdown.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/lib/formats/markdownLargeFile.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/index.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/parser.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/types.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/mdastBlockConverters.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/mdastInlineConverters.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/urlValidation.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/__tests__/performance.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPipeline/__tests__/mediaConverters.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/formatter.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/markdownParser.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/integrity.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/latinSpanScanner.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/formatter.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/markdownParser.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/lib/cjkFormatter/integrity.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/fileSizeThresholds.ts`
- `/Users/zibuyu/code/openSource/vmark/src/services/navigation/largeFileRouting.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/largeFilePrompts.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownCodeMask.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/cleanPastedMarkdown.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownPasteDetection.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownUrl.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/markdownUrl.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/utils/htmlToMarkdown.ts`
- `/Users/zibuyu/code/openSource/vmark/src/components/Editor/Editor.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/components/Editor/TiptapEditor.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/components/Editor/SourceEditor.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/components/ContentSearch/ContentSearch.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/components/ContentSearch/contentSearchUtils.tsx`
- `/Users/zibuyu/code/openSource/vmark/src/services/editor/extractContext.ts`
- `/Users/zibuyu/code/openSource/vmark/src/hooks/useGenieInvocation.ts`
- `/Users/zibuyu/code/openSource/vmark/src/services/commands/CommandBus.ts`
- `/Users/zibuyu/code/openSource/vmark/src/services/media/resolveMediaSrc.ts`
- `/Users/zibuyu/code/openSource/vmark/src/services/media/resolveMediaSrc.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/i18n.ts`
- `/Users/zibuyu/code/openSource/vmark/src/i18n.test.ts`
- `/Users/zibuyu/code/openSource/vmark/src/locales/zh-CN/editor.json`
- `/Users/zibuyu/code/openSource/vmark/src/locales/zh-TW/editor.json`
- `/Users/zibuyu/code/openSource/vmark/src/locales/ja/editor.json`
- `/Users/zibuyu/code/openSource/vmark/src/locales/ko/editor.json`
- `/Users/zibuyu/code/openSource/vmark/src/theme/tokens.ts`
- `/Users/zibuyu/code/openSource/vmark/src/theme/themes/index.ts`
- `/Users/zibuyu/code/openSource/vmark/src/theme/cssVars.ts`
- `/Users/zibuyu/code/openSource/vmark/src/styles/index.css`

吸收要求：

- Markdown adapter 采用 LangoTrace 自有 Swift contract：`ReadingImportAdapter` / `ReadingImportFormatRegistry`。
- Markdown 处理只做阅读导入、结构化和精美原生阅读渲染，不实现 Markdown 编辑器。
- Markdown renderer 采用 LangoTrace 自有 Swift contract：`ReadingMarkdownBlock` / `ReadingInlineRun` / `ReadingBlockPresentation` / `ReadingAppearanceProfile`，不得引入 React / Tiptap / ProseMirror / CodeMirror。
- 多语言 Markdown fixtures 必须吸收 VMark CJK / locale / media URL 测试思路，覆盖 CJK-Latin、日文、韩文、RTL、带重音拉丁文、URL、inline code、ordered list 和 CJK 文件名 / link text。
- large-file gate 必须在读取文件 body 前执行 metadata preflight。
- AI context 只允许 selection + limited surrounding context，不允许全文默认上传。
- Content search 思路写入 Reading library search，但底层使用 SQLite / GRDB / FTS5 或可重建索引。

## 9. 参考代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SentenceAudioPlaybackActions.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderHTTPClient.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlayback.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackTests.swift`

## 10. 涉及文档路径

- `docs/reference/research/2026-06-01-reading-integration-assessment.md`
- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`
- `docs/product-main-reference.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/workflows/add-ai-provider.md`
- `docs/workflows/add-tts-provider.md`
- `docs/prompts/README.md`
- `docs/architecture/notes/2026-05-25-dictionary-feature-extension-notes.md`
- `docs/architecture/notes/2026-05-23-local-media-artifact-extension-notes.md`
- `docs/architecture/notes/2026-05-24-sentence-tts-playback-infrastructure-extension-notes.md`

## 11. 实施方案

### 11.1 阶段 0：确认空白边界

- [ ] **Step 0.1：确认没有既有 reading active plan**

运行：

```bash
rg -n "reading|阅读" docs/plans/active docs/plans/done --glob '*.md'
```

预期：

- 只能命中本方案、既有调研引用或无关“阅读”普通词。
- 若存在同一 reading AI/TTS vertical slice active plan，停止并合并方案。

- [ ] **Step 0.2：确认本轮导航升级授权和规范更新范围**

运行：

```bash
git diff -- docs/product-main-reference.md docs/platform-page-inventory.md docs/spec/002-navigation-and-routing.md Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift
```

预期：

- 实施前可为空；如已有用户变更，必须阅读并合并，不得回退。
- 用户批准本方案实施后，上述文件应出现受控 diff：产品定位、导航规范、页面清单和 `PhoneRootTab` 同步进入四入口形态。
- 若用户只批准继续完善方案而未批准实现，不能修改生产代码。

- [ ] **Step 0.3：确认 Reading domain spec 写入路径**

创建或更新：`docs/spec/012-reading-learning-domain.md`

预期：

- spec 在代码实现前先定义 ReadingDocument、ReadingStructure、ReadingSourceAnchor、ReadingPosition、Reading AI explanation 和 Reading TTS source 的长期一致性边界。
- 若实施中发现 spec 与代码更优设计冲突，先更新 spec，再继续代码。

### 11.2 阶段 1：Core 导入 preflight

- [ ] **Step 1.1：写失败测试 `ReadingImportPreflightTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`

测试应覆盖：

```swift
import Foundation
import Testing
@testable import LangoTraceCore

@Suite("Reading import preflight")
struct ReadingImportPreflightTests {
    @Test("empty pasted text is rejected before document creation")
    func emptyPastedTextIsRejected() {
        let result = ReadingImportPreflight.evaluatePastedText(
            "   ",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.emptyContent))
    }

    @Test("long pasted text is accepted with long text warning below hard limit")
    func longPastedTextProducesWarning() {
        let text = String(repeating: "Language learning sentence. ", count: 700)

        let result = ReadingImportPreflight.evaluatePastedText(
            text,
            limits: .init(longTextCharacterThreshold: 10_000, hardCharacterLimit: 50_000, hardByteLimit: 200_000)
        )

        #expect(result.decision == .accept)
        #expect(result.warnings.contains(.longText))
        #expect(result.characterCount == text.count)
    }

    @Test("file metadata above hard byte limit is rejected before reading bytes")
    func hardByteLimitRejectsBeforeRead() {
        let result = ReadingImportPreflight.evaluateFileMetadata(
            filename: "book.txt",
            byteSize: 2_000_001,
            limits: .init(longTextCharacterThreshold: 10_000, hardCharacterLimit: 50_000, hardByteLimit: 2_000_000)
        )

        #expect(result.decision == .reject(.fileTooLarge))
        #expect(result.shouldReadFileBody == false)
    }

    @Test("txt and markdown files are supported while other extensions are rejected")
    func supportedExtensionsAreExplicit() {
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "note.txt", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "article.md", byteSize: 32, limits: .verticalSliceDefaults).decision == .accept)
        #expect(ReadingImportPreflight.evaluateFileMetadata(filename: "book.epub", byteSize: 32, limits: .verticalSliceDefaults).decision == .reject(.unsupportedFormat))
    }

    @Test("invalid text bytes fail as encoding failure")
    func invalidTextBytesFailAsEncodingFailure() {
        let invalid = Data([0xFF, 0xFE, 0x00, 0xD8])

        let result = ReadingImportPreflight.decodeTextData(
            invalid,
            filename: "broken.txt",
            limits: .verticalSliceDefaults
        )

        #expect(result.decision == .reject(.encodingFailed))
        #expect(result.text == nil)
    }
}
```

- [ ] **Step 1.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingImportPreflightTests
```

预期：

- 失败原因包含 `cannot find 'ReadingImportPreflight' in scope` 或等价未定义类型错误。

- [ ] **Step 1.3：实现最小 Core preflight 模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImport.swift`

实现要点：

- `ReadingImportPreflightLimits`
- `ReadingImportPreflightResult`
- `ReadingImportPreflightDecision`
- `ReadingImportPreflightWarning`
- `ReadingImportPreflightFailure`
- `ReadingImportPreflightLimits.verticalSliceDefaults`
- `ReadingImportPreflight.evaluatePastedText`
- `ReadingImportPreflight.evaluateFileMetadata`
- `ReadingImportPreflight.decodeTextData`

边界：

- pasted text 可以读取字符串，但必须先 trim 判断空。
- file metadata 检查不得读取文件内容。
- `.txt` 和 `.md` 是本任务唯一允许文件扩展名。
- decode 只支持 UTF-8 和 UTF-16 的 best-effort；失败返回 `.encodingFailed`。
- 不解析 EPUB / PDF / HTML。

- [ ] **Step 1.4：运行 Core preflight 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingImportPreflightTests
```

预期：通过。

### 11.2A 阶段 1A：Core 导入 registry、资料库模型和搜索 contract

- [ ] **Step 1A.1：写失败测试 `ReadingImportRegistryTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportRegistryTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading import registry")
struct ReadingImportRegistryTests {
    @Test("vertical slice registry only registers pasted text txt and markdown")
    func verticalSliceRegistryHasExplicitAdapters() {
        let registry = ReadingImportFormatRegistry.verticalSliceDefaults()

        #expect(registry.adapter(for: .pastedText)?.id == "pasted-text.v1")
        #expect(registry.adapter(forFileExtension: "txt")?.id == "plain-text-file.v1")
        #expect(registry.adapter(forFileExtension: "md")?.id == "markdown-file.v1")
        #expect(registry.adapter(forFileExtension: "epub") == nil)
        #expect(registry.adapter(forFileExtension: "pdf") == nil)
    }

    @Test("future adapters are represented without enabling them")
    func futureAdaptersAreDocumentedButDisabled() {
        let disabled = ReadingImportFormatRegistry.futureAdapterDescriptors()

        #expect(disabled.contains { $0.id == "epub-text-extraction.v1" && $0.status == .future })
        #expect(disabled.contains { $0.id == "pdf-text-extraction.v1" && $0.status == .future })
        #expect(disabled.contains { $0.id == "html-clip.v1" && $0.status == .future })
    }
}
```

- [ ] **Step 1A.2：写失败测试 `ReadingLibraryModelTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading library models")
struct ReadingLibraryModelTests {
    @Test("library summary separates document facts from library state")
    func summarySeparatesDocumentAndLibraryState() {
        let summary = ReadingLibraryDocumentSummary(
            id: "doc-1",
            spaceID: "space-1",
            title: "Article",
            sourceFormat: .markdown,
            importStatus: .ready,
            libraryStatus: .active,
            tagNames: ["travel"],
            collectionTitles: ["Essays"],
            lastOpenedAt: nil
        )

        #expect(summary.id == "doc-1")
        #expect(summary.libraryStatus == .active)
        #expect(summary.sourceFormat == .markdown)
    }

    @Test("deleted document is not active but remains restorable")
    func deletedDocumentRemainsRestorable() {
        #expect(ReadingLibraryStatus.active.isVisibleInActiveLibrary)
        #expect(!ReadingLibraryStatus.softDeleted.isVisibleInActiveLibrary)
        #expect(ReadingLibraryStatus.softDeleted.isRestorable)
    }
}
```

- [ ] **Step 1A.3：写失败测试 `ReadingSearchQueryTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSearchQueryTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading search query")
struct ReadingSearchQueryTests {
    @Test("empty search query normalizes to nil")
    func emptyQueryNormalizesToNil() {
        #expect(ReadingLibrarySearchQuery(rawValue: "   ") == nil)
    }

    @Test("search query trims and limits length")
    func queryTrimsAndLimitsLength() {
        let raw = String(repeating: "a", count: 300)
        let query = ReadingLibrarySearchQuery(rawValue: "  \(raw)  ")

        #expect(query?.normalized.count == ReadingLibrarySearchQuery.maxLength)
    }
}
```

- [ ] **Step 1A.4：实现 Core library / registry / search 模型**

创建：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingImportRegistry.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSearch.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLifecycle.swift`

实现要点：

- `ReadingSourceFormat` 至少包含 `.pastedText`、`.plainText`、`.markdown`、`.epub`、`.pdf`、`.htmlClip`、`.webArticle`，其中后四项本轮只能作为 future descriptor，不允许进入 ready document。
- `ReadingImportAdapterDescriptor` 保存 id、version、supported extensions、status。
- `ReadingImportFormatRegistry.verticalSliceDefaults()` 只启用 pasted text、txt、md。
- `ReadingLibraryDocumentSummary` 只保存资料库展示和筛选所需字段，不保存完整正文。
- `ReadingLibraryStatus` 区分 active / softDeleted。
- `ReadingDocumentLifecycleEventType` 至少包含 imported、opened、softDeleted、restored、assignedCollection、removedCollection、tagged、untagged。
- `ReadingLibrarySearchQuery` 负责 trim、空值归一和长度限制。

- [ ] **Step 1A.5：运行 Core library 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingImportRegistryTests
swift test --package-path Packages/LangoTraceCore --filter ReadingLibraryModelTests
swift test --package-path Packages/LangoTraceCore --filter ReadingSearchQueryTests
```

预期：通过。

### 11.2B 阶段 1B：Core Markdown block model 和阅读样式 contract

- [ ] **Step 1B.1：写失败测试 `ReadingMarkdownRenderingTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingMarkdownRenderingTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading Markdown rendering contract")
struct ReadingMarkdownRenderingTests {
    @Test("markdown parser emits structured reading blocks")
    func markdownParserEmitsStructuredBlocks() {
        let markdown = """
        # Title

        A paragraph with **strong**, *emphasis*, `code`, and [link](https://example.com).

        > Quote

        1. First
        2. Second

        ```swift
        let value = 1
        ```
        """

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.blocks.contains { $0.kind == .heading(level: 1) })
        #expect(document.blocks.contains { $0.kind == .paragraph })
        #expect(document.blocks.contains { $0.kind == .blockquote })
        #expect(document.blocks.contains { $0.kind == .orderedList })
        #expect(document.blocks.contains { $0.kind == .codeBlock(language: "swift") })
        #expect(document.inlineRuns.contains { $0.kind == .strong })
        #expect(document.inlineRuns.contains { $0.kind == .inlineCode })
        #expect(document.inlineRuns.contains { $0.kind == .link })
    }

    @Test("multilingual markdown keeps source ranges and protected code")
    func multilingualMarkdownKeepsSourceRanges() {
        let markdown = """
        # 多语言 Title

        中文与 Latin text、한국어、日本語、café 和 שלום mixed.

        1. 中文列表 item

        `Python3.11` should stay literal.
        """

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.plainText.contains("中文与 Latin"))
        #expect(document.plainText.contains("한국어"))
        #expect(document.plainText.contains("שלום"))
        #expect(document.inlineRuns.contains { $0.text == "Python3.11" && $0.kind == .inlineCode })
        #expect(document.blocks.allSatisfy { $0.sourceRange != nil })
    }

    @Test("unsupported markdown falls back without losing readable text")
    func unsupportedMarkdownFallsBack() {
        let markdown = "<custom-block data-x=\"1\">Hidden</custom-block>\n\nVisible text."

        let document = ReadingMarkdownParser.parse(markdown, sourceFormat: .markdown)

        #expect(document.plainText.contains("Visible text."))
        #expect(document.blocks.contains { $0.kind == .unsupported || $0.kind == .paragraph })
    }
}
```

- [ ] **Step 1B.2：写失败测试 `ReadingAppearanceProfileTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingAppearanceProfileTests.swift`

测试应覆盖：

- default profile 包含正文、标题、引用、列表、代码块、链接、inline code、reading width、line spacing、paragraph spacing、Dark Mode color role 和 Dynamic Type strategy。
- profile 不参与 body hash、content revision、structure version、source anchor 或 TTS source key。
- future user custom style 可以通过 profile value 表达，不需要改 `ReadingMarkdownBlock` schema。

- [ ] **Step 1B.3：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingMarkdownRenderingTests
swift test --package-path Packages/LangoTraceCore --filter ReadingAppearanceProfileTests
```

预期：失败原因包含 `ReadingMarkdownParser` / `ReadingAppearanceProfile` 未定义。

- [ ] **Step 1B.4：实现 Markdown block model 和 appearance contract**

创建：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingMarkdown.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAppearance.swift`

实现要点：

- `ReadingMarkdownDocument`
- `ReadingMarkdownBlock`
- `ReadingMarkdownBlockKind`
- `ReadingInlineRun`
- `ReadingInlineRunKind`
- `ReadingMarkdownParser.parse`
- `ReadingAppearanceProfile`
- `ReadingRenderStyle`
- `ReadingTypographyRole`
- `ReadingColorRole`
- parser / renderer contract 保留 source range，用于 source anchor 和 selection。
- Markdown parser 首版可以采用保守 parser / line scanner，但必须通过测试覆盖的 block / inline contract；若实现期引入 Swift Markdown 或其他 parser，必须先检查依赖、平台支持和许可证，并写入 implementation record。
- 不自动重写用户原文的 CJK 标点或 spacing；只在 presentation layer 做可逆展示处理，自动格式化必须进入后续独立 plan。

- [ ] **Step 1B.5：运行 Core Markdown 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingMarkdownRenderingTests
swift test --package-path Packages/LangoTraceCore --filter ReadingAppearanceProfileTests
```

预期：通过。

### 11.3 阶段 2：Core 分段、分句和选择模型

- [ ] **Step 2.1：写失败测试 `ReadingTextSegmentationTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading text segmentation")
struct ReadingTextSegmentationTests {
    @Test("paragraph chunks preserve character ranges")
    func paragraphChunksPreserveRanges() {
        let text = "First sentence.\n\nSecond paragraph has two sentences. Another one."

        let chunks = ReadingTextSegmenter.segmentParagraphs(
            text,
            documentID: "doc-1",
            contentRevision: 3
        )

        #expect(chunks.count == 2)
        #expect(chunks[0].range.lowerBound == text.startIndex)
        #expect(String(text[chunks[0].range]).contains("First sentence."))
        #expect(chunks[1].contentRevision == 3)
    }

    @Test("manual selection does not require whitespace tokenization")
    func selectionSupportsCJKAndRTL() {
        let text = "今日は図書館で読みます。 שלום עולם"
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: "図書館",
            contextText: text,
            characterOffset: 3
        )

        #expect(selection.selectedText == "図書館")
        #expect(selection.contextText.contains("שלום"))
    }

    @Test("manual selection records character range for later anchoring")
    func selectionRecordsCharacterRange() {
        let text = "Read this sentence carefully."
        let start = text.firstIndex(of: "s")!
        let end = text.index(start, offsetBy: 8)
        let selection = ReadingSelection(
            documentID: "doc-1",
            contentRevision: 1,
            selectedText: String(text[start..<end]),
            contextText: text,
            characterOffset: text.distance(from: text.startIndex, to: start),
            characterLength: text.distance(from: start, to: end)
        )

        #expect(selection.selectedText == "sentence")
        #expect(selection.characterOffset > 0)
        #expect(selection.characterLength == 8)
    }
}
```

- [ ] **Step 2.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：失败原因包含 `ReadingTextSegmenter` 或 `ReadingSelection` 未定义。

- [ ] **Step 2.3：实现分段和选择模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift`

实现要点：

- `ReadingTextChunk`
- `ReadingSelection`
- `ReadingTextSegmenter.segmentParagraphs`
- 用 paragraph chunk 作为首版粒度，不承诺自动 tokenization。
- `ReadingSelection` 由 UI 手动选择产生，不依赖英文空格。
- `ReadingSelection` 必须保存 `characterOffset` 和 `characterLength`，为后续 source anchor 提供最小可验证输入。

- [ ] **Step 2.4：运行测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：通过。

### 11.4 阶段 3：100k 词典 exact lookup 验证

- [ ] **Step 3.1：写失败测试 `ReadingDictionaryLookupTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading dictionary lookup")
struct ReadingDictionaryLookupTests {
    @Test("exact lookup uses normalized form and language code")
    func exactLookupUsesNormalization() {
        let entries = [
            ReadingDictionaryEntry(headword: "Résumé", normalizedHeadword: "resume", languageCode: "fr", definition: "summary"),
            ReadingDictionaryEntry(headword: "resume", normalizedHeadword: "resume", languageCode: "en", definition: "continue")
        ]
        let index = ReadingDictionaryLookupIndex(entries: entries)

        #expect(index.exactLookup("résumé", languageCode: "fr").first?.definition == "summary")
        #expect(index.exactLookup("resume", languageCode: "en").first?.definition == "continue")
    }

    @Test("synthetic 100k lookup returns deterministic result")
    func syntheticLargeLookup() {
        let entries = (0..<100_000).map { index in
            ReadingDictionaryEntry(
                headword: "word\(index)",
                normalizedHeadword: "word\(index)",
                languageCode: "en",
                definition: "definition \(index)"
            )
        }

        let lookup = ReadingDictionaryLookupIndex(entries: entries)

        #expect(lookup.exactLookup("word99999", languageCode: "en").first?.definition == "definition 99999")
        #expect(lookup.exactLookup("missing", languageCode: "en").isEmpty)
    }
}
```

- [ ] **Step 3.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingDictionaryLookupTests
```

预期：失败原因包含 `ReadingDictionaryLookupIndex` 未定义。

- [ ] **Step 3.3：实现纯内存 lookup index**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingDictionaryLookup.swift`

实现要点：

- `ReadingDictionaryEntry`
- `ReadingDictionaryLookupKey`
- `ReadingDictionaryLookupIndex`
- key 由 `languageCode + normalizedHeadword` 组成。
- 仅用于本任务的本地 lookup 验证，不作为正式词典 repository。

- [ ] **Step 3.4：运行 lookup 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingDictionaryLookupTests
```

预期：通过。

### 11.5 阶段 4：Source anchor stale 判定

- [ ] **Step 4.1：写失败测试 `ReadingSourceAnchorTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading source anchors")
struct ReadingSourceAnchorTests {
    @Test("anchor is current when revision and selected text hash match")
    func anchorCurrentWhenRevisionAndHashMatch() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )
        let state = anchor.resolve(
            currentRevision: 4,
            currentSelectedTextHash: "hash-a"
        )

        #expect(state == .current)
    }

    @Test("anchor is stale when revision changes")
    func anchorStaleWhenRevisionChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )

        #expect(anchor.resolve(currentRevision: 5, currentSelectedTextHash: "hash-a") == .stale(.revisionChanged))
    }

    @Test("anchor is stale when selected text hash changes")
    func anchorStaleWhenHashChanges() {
        let anchor = ReadingSourceAnchor(
            documentID: "doc-1",
            sourceRevision: 4,
            sentenceID: "sentence-1",
            selectedTextHash: "hash-a"
        )

        #expect(anchor.resolve(currentRevision: 4, currentSelectedTextHash: "hash-b") == .stale(.selectedTextChanged))
    }
}
```

- [ ] **Step 4.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingSourceAnchorTests
```

预期：失败原因包含 `ReadingSourceAnchor` 未定义。

- [ ] **Step 4.3：实现 anchor 判定模型**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingSourceAnchor.swift`

实现要点：

- `ReadingSourceAnchor`
- `ReadingSourceAnchorResolution`
- `ReadingSourceAnchorStaleReason`
- revision 不匹配优先返回 stale。
- revision 匹配但 hash 不匹配也返回 stale。

- [ ] **Step 4.4：运行 anchor 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingSourceAnchorTests
```

预期：通过。

### 11.6 阶段 5：UI presentation model 和三端 layout

- [ ] **Step 5.1：写失败测试 `ReadingPresentationTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceUI

@Suite("Reading presentation")
struct ReadingPresentationTests {
    @Test("phone uses single column and bottom sheet inspector")
    func phoneLayoutUsesBottomSheetInspector() {
        let model = ReadingLayoutModel.platform(.phone)

        #expect(model.primaryColumnCount == 1)
        #expect(model.inspectorPresentation == .bottomSheet)
    }

    @Test("pad uses reading body plus side inspector")
    func padLayoutUsesSideInspector() {
        let model = ReadingLayoutModel.platform(.pad)

        #expect(model.primaryColumnCount == 2)
        #expect(model.inspectorPresentation == .sidePanel)
    }

    @Test("mac supports library body and inspector columns")
    func macLayoutSupportsThreeColumns() {
        let model = ReadingLayoutModel.platform(.mac)

        #expect(model.primaryColumnCount == 3)
        #expect(model.inspectorPresentation == .sidePanel)
    }

    @Test("selection opens inspector without mutating document chunks")
    func selectionOpensInspector() {
        var state = ReadingPresentationState(
            layout: .platform(.phone),
            chunks: [
                .init(id: "chunk-1", text: "A short sentence for lookup.")
            ]
        )

        state.selectText("sentence", inChunkID: "chunk-1")

        #expect(state.selectedText == "sentence")
        #expect(state.isInspectorPresented)
        #expect(state.chunks.map(\.text) == ["A short sentence for lookup."])
    }
}
```

- [ ] **Step 5.1A：写失败测试 `ReadingMarkdownBlockRendererTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingMarkdownBlockRendererTests.swift`

测试应覆盖：

- heading / paragraph / blockquote / list / code block / link / emphasis / inline code 都映射到 `ReadingBlockPresentation`，不退化为单个 plain text chunk。
- default `ReadingAppearanceProfile` 生成稳定的 typography role、spacing、color role 和 reading width，不直接硬编码颜色或字号到具体 View。
- Dynamic Type size 改变只影响 presentation style，不改变 block id、source range、sentence id、source anchor 输入或 selected text。
- Dark Mode 使用 color role 映射，不在 renderer 中写死单一浅色或深色。
- CJK / Latin 混排、日文、韩文、RTL 短段、带重音拉丁文、inline code、ordered list marker 和 CJK link text 都能形成可读 block presentation。
- renderer 不触发 AI、TTS、repository、Keychain 或文件访问。

- [ ] **Step 5.2：运行测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
swift test --package-path Packages/LangoTraceUI --filter ReadingMarkdownBlockRendererTests
```

预期：失败原因包含 `ReadingLayoutModel` / `ReadingMarkdownBlockRenderer` 未定义。

- [ ] **Step 5.3：实现 UI presentation model**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift`

实现要点：

- `ReadingPlatformRole`
- `ReadingInspectorPresentation`
- `ReadingLayoutModel`
- `ReadingDocumentPresentation`
- `ReadingChunkPresentation`
- `ReadingBlockPresentation`
- `ReadingInlinePresentation`
- `ReadingPresentationState`
- 不依赖 Data repository。
- 不依赖旧记录详情 route。

- [ ] **Step 5.4：添加 SwiftUI reading route view**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`

同时创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingMarkdownBlockRenderer.swift`

实现要点：

- `ReadingPreviewView`
- `ReadingBodyView`
- `ReadingInspectorView`
- `ReadingMarkdownBlockRenderer`
- View 只接收 presentation model 和 sample chunks。
- Markdown block renderer 只接收 `ReadingMarkdownDocument` / `ReadingAppearanceProfile` / platform role，并输出 SwiftUI 可渲染的 presentation model；不得直接访问 repository、AI、TTS 或 Keychain。
- 首轮视觉目标是精美但克制的阅读体验：清晰标题层级、舒适段距和行距、可辨识引用块、稳定列表缩进、代码块等宽字体和背景、链接 / inline code / emphasis 可辨识、Dark Mode 和 Dynamic Type 可用。
- 本阶段可以先使用 sample chunks 验证 view contract；最终必须在阶段 10 接入正式 reading route 和 store。

- [ ] **Step 5.5：运行 UI 测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingPresentationTests
swift test --package-path Packages/LangoTraceUI --filter ReadingMarkdownBlockRendererTests
```

预期：通过。

### 11.7 阶段 6：10k 字长文本和 chunk 数量验证

- [ ] **Step 6.1：补充分段性能形态测试**

修改：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`

新增测试：

```swift
@Test("10k character text is chunked instead of represented as one view unit")
func tenThousandCharacterTextIsChunked() {
    let paragraph = String(repeating: "This is a language learning sentence. ", count: 25)
    let text = Array(repeating: paragraph, count: 16).joined(separator: "\n\n")

    let chunks = ReadingTextSegmenter.segmentParagraphs(
        text,
        documentID: "doc-long",
        contentRevision: 1
    )

    #expect(text.count > 10_000)
    #expect(chunks.count == 16)
    #expect(chunks.allSatisfy { !$0.text.isEmpty })
}
```

- [ ] **Step 6.2：运行分段测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentationTests
```

预期：通过。

### 11.8 阶段 7：Data Reading library domain 基础 schema 与 repository

- [ ] **Step 7.1：写失败测试 `AppDatabaseReadingMigrationTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`

测试应覆盖：

```swift
import GRDB
import Testing
@testable import LangoTraceData

@Suite("Reading database migration")
struct AppDatabaseReadingMigrationTests {
    @Test("empty database migrates reading tables")
    func emptyDatabaseMigratesReadingTables() throws {
        let database = try AppDatabase.inMemory()

        let tableNames = try database.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }

        #expect(tableNames.contains("reading_documents"))
        #expect(tableNames.contains("reading_collections"))
        #expect(tableNames.contains("reading_document_collections"))
        #expect(tableNames.contains("reading_tags"))
        #expect(tableNames.contains("reading_document_tags"))
        #expect(tableNames.contains("reading_structure_blocks"))
        #expect(tableNames.contains("reading_sentences"))
        #expect(tableNames.contains("reading_positions"))
        #expect(tableNames.contains("reading_source_anchors"))
        #expect(tableNames.contains("reading_import_batches"))
        #expect(tableNames.contains("reading_import_items"))
        #expect(tableNames.contains("reading_import_operations"))
        #expect(tableNames.contains("reading_document_lifecycle_events"))
        #expect(tableNames.contains("reading_ai_explanation_operations"))
    }

    @Test("reading operation summary does not require raw text columns")
    func operationSummaryHasNoRawTextColumns() throws {
        let database = try AppDatabase.inMemory()

        let columns = try database.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(reading_ai_explanation_operations)")
                .map { row in row["name"] as String }
        }

        #expect(!columns.contains("selected_text"))
        #expect(!columns.contains("context_text"))
        #expect(!columns.contains("response_body"))
        #expect(!columns.contains("request_body"))
    }
}
```

追加测试应覆盖：

- `reading_documents` 包含 `source_format`、`adapter_id`、`adapter_version`、`original_filename`、`original_mime_type`、`original_uti`、`original_byte_size`、`restored_at`、`last_opened_at`。
- `reading_import_batches` 和 `reading_import_items` 不保存原文，只保存 source metadata、状态、失败分类、大小分桶和 document id。
- `reading_document_lifecycle_events` 不保存原文，能够记录 imported / opened / softDeleted / restored / assignedCollection / removedCollection / tagged / untagged。
- search index table 或 FTS table 是本地可重建派生索引，不是同步主数据。

- [ ] **Step 7.2：运行迁移测试确认失败**

运行：

```bash
swift test --package-path Packages/LangoTraceData --filter AppDatabaseReadingMigrationTests
```

预期：失败原因包含缺少 `reading_documents`、`reading_collections`、`reading_import_batches` 或 `reading_ai_explanation_operations`。

- [ ] **Step 7.3：新增 Reading domain 基础 migration**

修改：`Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`

新增 migration 建议命名：

```swift
v12_create_reading_domain_infrastructure
```

基础表范围：

- `reading_documents`
  - `id`
  - `space_id`
  - `title`
  - `source_kind`
  - `source_format`
  - `adapter_id`
  - `adapter_version`
  - `body_storage_kind`
  - `body`
  - `managed_body_artifact_id`
  - `source_metadata_json`
  - `original_filename`
  - `original_file_extension`
  - `original_mime_type`
  - `original_uti`
  - `original_byte_size`
  - `body_hash`
  - `content_revision`
  - `structure_version`
  - `target_language_code`
  - `import_status`
  - `library_status`
  - `last_opened_at`
  - `created_at`
  - `updated_at`
  - `soft_deleted_at`
  - `restored_at`
- `reading_collections`
  - `id`
  - `space_id`
  - `title`
  - `title_normalized`
  - `sort_order`
  - `created_at`
  - `updated_at`
  - `soft_deleted_at`
- `reading_document_collections`
  - `document_id`
  - `collection_id`
  - `assigned_at`
- `reading_tags`
  - `id`
  - `space_id`
  - `name`
  - `name_normalized`
  - `created_at`
  - `updated_at`
  - `soft_deleted_at`
- `reading_document_tags`
  - `document_id`
  - `tag_id`
  - `assigned_at`
- `reading_structure_blocks`
  - `id`
  - `document_id`
  - `block_index`
  - `kind`
  - `text_hash`
  - `character_start`
  - `character_end`
  - `structure_version`
- `reading_sentences`
  - `id`
  - `document_id`
  - `block_id`
  - `sentence_index`
  - `text`
  - `text_hash`
  - `character_start`
  - `character_end`
  - `structure_version`
- `reading_positions`
  - `document_id`
  - `device_scope`
  - `block_id`
  - `sentence_id`
  - `character_offset`
  - `updated_at`
- `reading_document_search_index`
  - `document_id`
  - `index_revision`
  - `title_index_text`
  - `body_index_text`
  - `indexed_at`
  - `stale_at`
- `reading_source_anchors`
  - `id`
  - `document_id`
  - `source_revision`
  - `structure_version`
  - `block_id`
  - `sentence_id`
  - `character_start`
  - `character_end`
  - `selected_text_hash`
  - `created_at`
- `reading_import_batches`
  - `id`
  - `operation_id`
  - `space_id`
  - `adapter_id`
  - `adapter_version`
  - `source_kind`
  - `source_format`
  - `status`
  - `item_count`
  - `succeeded_count`
  - `failed_count`
  - `created_at`
  - `completed_at`
- `reading_import_items`
  - `id`
  - `batch_id`
  - `document_id`
  - `original_filename`
  - `original_file_extension`
  - `original_mime_type`
  - `original_uti`
  - `byte_count_bucket`
  - `character_count_bucket`
  - `status`
  - `failure_category`
  - `created_at`
  - `completed_at`
- `reading_import_operations`
  - `id`
  - `operation_id`
  - `space_id`
  - `document_id`
  - `source_kind`
  - `source_format`
  - `status`
  - `failure_category`
  - `character_count_bucket`
  - `byte_count_bucket`
  - `created_at`
  - `completed_at`
- `reading_document_lifecycle_events`
  - `id`
  - `space_id`
  - `document_id`
  - `event_type`
  - `operation_id`
  - `collection_id`
  - `tag_id`
  - `metadata_json`
  - `created_at`
- `reading_ai_explanation_operations`
  - `id`
  - `operation_id`
  - `space_id`
  - `document_id`
  - `anchor_id`
  - `source_kind`
  - `status`
  - `failure_category`
  - `selection_length_bucket`
  - `context_length_bucket`
  - `provider_preset_id`
  - `adapter_kind`
  - `model_name`
  - `duration_ms`
  - `created_at`
  - `completed_at`

约束：

- `reading_documents.space_id` 外键到 `language_spaces.id`。
- `reading_collections.space_id` 外键到 `language_spaces.id`。
- `reading_tags.space_id` 外键到 `language_spaces.id`。
- `reading_document_collections.document_id` 外键到 `reading_documents.id`。
- `reading_document_collections.collection_id` 外键到 `reading_collections.id`。
- `reading_document_tags.document_id` 外键到 `reading_documents.id`。
- `reading_document_tags.tag_id` 外键到 `reading_tags.id`。
- `reading_structure_blocks.document_id` 外键到 `reading_documents.id`。
- `reading_sentences.document_id` 外键到 `reading_documents.id`。
- `reading_sentences.block_id` 外键到 `reading_structure_blocks.id`。
- `reading_positions.document_id` 外键到 `reading_documents.id`。
- `reading_document_search_index.document_id` 外键到 `reading_documents.id`。
- `reading_source_anchors.document_id` 外键到 `reading_documents.id`。
- `reading_import_batches.space_id` 外键到 `language_spaces.id`。
- `reading_import_items.batch_id` 外键到 `reading_import_batches.id`。
- `reading_import_items.document_id` 外键到 `reading_documents.id`，允许为空以表达导入失败前未形成 document。
- `reading_document_lifecycle_events.document_id` 外键到 `reading_documents.id`。
- `reading_ai_explanation_operations.anchor_id` 外键到 `reading_source_anchors.id`，允许为空以表达 preflight 或失败前未形成 anchor 的情况。
- `reading_import_batches`、`reading_import_items`、`reading_import_operations`、`reading_document_lifecycle_events` 和 `reading_ai_explanation_operations` 不含原文、请求体、响应体和密钥。
- CHECK 必须限制 `source_kind`、`source_format`、`body_storage_kind`、`import_status`、`library_status`、operation `status`、`device_scope`、lifecycle `event_type` 和 failure category 的已知取值；未来新增取值必须伴随 migration / spec 更新。
- 唯一索引至少覆盖 active document 查询、`space_id + title_normalized + soft_deleted_at`、`document_id + block_index + structure_version`、`document_id + sentence_index + structure_version`、`operation_id`、`document_id + collection_id`、`document_id + tag_id`、`space_id + tag name_normalized`、`space_id + collection title_normalized`。
- FTS5 可作为 `reading_document_search_fts` virtual table 实现；如果本轮不使用 FTS5，则 `reading_document_search_index` 必须有 stale / rebuild contract，且后续切换 FTS5 不改变 repository API。

- [ ] **Step 7.4：写失败测试 `GRDBReadingRepositoryTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`

测试应覆盖：

- 保存 pasted text document 后可按 `space_id` 查询 active documents。
- 软删除后 active 查询不返回。
- 恢复后 active 查询重新返回，并写入 lifecycle event。
- 保存 structure blocks 和 sentences 后可按 document 读取且保留 `structure_version`。
- 保存 source anchor 后可通过 document revision / structure version / hash 判定 current 或 stale。
- 写入 import operation summary 和 AI explanation operation summary 不保存原文。
- 切换 language space 后不会读到其他空间文档。
- 同一个 `operation_id` 重复写入不能产生多条 summary。

- [ ] **Step 7.4A：写失败测试 `GRDBReadingLibraryRepositoryTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`

测试应覆盖：

- 创建 collection 后只能在同一 `space_id` 查询。
- collection title normalized 唯一约束只限制同一 language space 的 active collection。
- 给 document 分配 collection 是幂等的。
- 创建 tag 后只能在同一 `space_id` 查询。
- tag name normalized 唯一约束只限制同一 language space 的 active tag。
- 给 document 分配 tag 是幂等的。
- 删除 collection 或 tag 后，active library filter 不再使用它，但 document 不被删除。
- 最近阅读排序使用 `last_opened_at`，打开文档会写入 lifecycle event。

- [ ] **Step 7.4B：写失败测试 `ReadingImportBatchRepositoryTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingImportBatchRepositoryTests.swift`

测试应覆盖：

- 单批次可以包含多个 import item。
- 批次部分成功时，成功 item 关联 document，失败 item 不创建 document。
- retry 同一个 failed item 不产生重复 ready document。
- batch / item summary 不保存原文、完整文件路径、API Key 或完整 Provider URL。
- batch / item summary 不保存外部 absolute path、security-scoped bookmark 或用户目录结构。
- permission denied / cancelled / encoding failed / file too large / unsupported format 都映射为 stable failure category。
- unsupported EPUB / PDF / HTML 在本轮返回 stable failure category，而不是落库为 ready document。

- [ ] **Step 7.4C：写失败测试 `ReadingSearchIndexTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingSearchIndexTests.swift`

测试应覆盖：

- title search 返回同一 `space_id` 的 active document。
- body search 或 search index query 不返回 soft-deleted document。
- document body revision 变化后 search index 标记 stale。
- rebuild search index 后 stale marker 清除。
- search index 不写入 operation summary 或诊断日志。
- repository API 使用 FTS-capable 查询语义；若实现先采用普通 `reading_document_search_index`，测试仍必须证明后续切换 FTS5 不需要修改 UI store API。

- [ ] **Step 7.4D：写失败测试 `ReadingDocumentLifecycleTests`**

创建：`Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingDocumentLifecycleTests.swift`

测试应覆盖：

- imported / opened / softDeleted / restored / assignedCollection / removedCollection / tagged / untagged 均可写入 lifecycle event。
- lifecycle event 不保存原文。
- soft delete 不物理删除 source anchor、position、import history 或 AI operation summary。
- restore 不改变 `content_revision`，只改变 library visibility。

- [ ] **Step 7.5：实现 `GRDBReadingRepository` 和 `GRDBReadingLibraryRepository`**

创建：

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingRepository.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`

实现要点：

- 不把 repository 暴露给 SwiftUI View 直接使用。
- 事务内保存 document + structure blocks + sentences。
- 资料库列表查询只返回 active documents，默认按 `last_opened_at DESC, updated_at DESC`。
- collection/tag membership 写入必须幂等。
- import batch 写入必须支持部分成功和失败 item。
- search index 是本地可重建派生数据；repository API 不暴露 SQLite / FTS 细节。首选 SQLite FTS5 external-content；若实现期降级普通 search index，必须在 implementation record 写明原因和后续切换入口。
- `body_hash` 和 sentence `text_hash` 用 Core hash helper 或 Data 内部 helper 统一生成。
- operation summary 只写 length bucket、provider metadata 和 failure category。
- soft delete document 时，active document、position 和可见 sentence 查询都必须排除 deleted document；source anchor 不物理删除，以便后续 memory / practice 引用能表达 stale / unavailable。
- restore document 时不重写正文、不重写 source anchor、不重写 TTS artifact，只恢复 library visibility 并写 lifecycle event。

- [ ] **Step 7.6：运行 Data 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceData --filter AppDatabaseTests
```

预期：通过。

### 11.9 阶段 8：真实 AI selection explanation

- [ ] **Step 8.1：创建 Prompt Registry 文档**

创建：`docs/prompts/reading/selection-explanation.md`

必填内容：

- Prompt id：`reading.selection_explanation.v1`
- Prompt version：`2026-06-01`
- 所属功能：阅读选词 / 选句 AI 解释
- 调用模块：`LangoTraceAI.ReadingSelectionExplanationService`
- 输入变量：selection、sentence、limitedContextBefore、limitedContextAfter、targetLanguageCode、nativeLanguageCode、languageLevel
- 输出契约：JSON object，字段至少包含 `schema_version`、`summary`、`meaning`、`usage_notes`、`examples`、`confidence`
- 隐私边界：包含用户选择的阅读文本和有限上下文；不包含全文、照片、音频、OCR、历史记忆、附件摘要或 API Key
- 用户触发条件：用户点击 AI 解释按钮
- 发送范围展示要求：单次显式点击即可发送；不采用“预览确认后发送”的两步流程。UI 应在按钮附近、inspector 或进行中状态中展示 selection、上下文范围、Provider profile 和模型，帮助用户理解本次发送边界。
- 日志允许字段：operation id、长度分桶、provider preset id、adapter kind、model name、failure category、duration bucket

- [ ] **Step 8.2：写失败测试 `ReadingSelectionExplanationServiceTests`**

创建：`Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`

测试应覆盖：

- OpenAI-compatible chat request 只包含 selection、sentence、limited context，不包含 document full body。
- Responses API request 使用同一 schema。
- 返回 JSON 缺字段、非法 confidence、额外字段时拒绝。
- HTTP 401 映射 authentication failure。
- 429 映射 rate limited 或 quota failure。
- 取消映射 cancelled，且不写 failed operation summary。
- 取消或 stale completion 不写入当前 selection 的 AI result，不覆盖后续 operation state。

- [ ] **Step 8.3：创建 Core AI explanation contract**

创建：`Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingAIExplanation.swift`

模型建议：

- `ReadingSelectionExplanationRequest`
- `ReadingSelectionExplanationInput`
- `ReadingSelectionExplanationResult`
- `ReadingSelectionExplanationFailure`
- `ReadingAIExplanationOperationSummary`
- `ReadingAIExplanationLengthBucket`

约束：

- request 中可以包含 selection 和 limited context。
- summary 中只能含分桶和 provider metadata。
- request contract 不要求二次确认；是否展示发送范围属于 UI presentation state，不改变 service 输入契约。

- [ ] **Step 8.4：实现 `ReadingSelectionExplanationService`**

创建：`Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`

实现要点：

- 使用 `AIProviderHTTPClient`，不要用 probe-only 命名的 client。
- 支持 `.openAICompatibleChat` 和 `.openAIResponses`。
- 不支持 Anthropic / Gemini 时返回 `.unsupportedProvider`，不伪装成网络错误。
- 请求体遵守 Prompt Registry。
- parser 拒绝自然语言前后缀、缺字段、非法枚举、额外字段和过长数组。
- service 支持 Task cancellation；调用方取消后不得继续解析结果并写入 UI state。

- [ ] **Step 8.5：运行 AI 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceAI --filter ReadingSelectionExplanationServiceTests
```

预期：通过。

### 11.10 阶段 9：真实 reading sentence TTS source

- [ ] **Step 9.1：写失败测试 `ReadingTTSArtifactKeyTests`**

创建：`Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`

测试应覆盖：

```swift
import Testing
@testable import LangoTraceCore

@Suite("Reading TTS artifact key")
struct ReadingTTSArtifactKeyTests {
    @Test("reading sentence source has distinct canonical key")
    func readingSentenceSourceHasDistinctKey() {
        let reading = TTSSentenceSource.readingDocumentSentence(documentID: "doc-1", sentenceID: "sent-1")
        let material = TTSSentenceSource.learningMaterialSentence(materialID: "doc-1", sentenceIndex: 1)

        #expect(reading != material)
    }
}
```

- [ ] **Step 9.2：扩展 Core TTS source**

修改：`Packages/LangoTraceCore/Sources/LangoTraceCore/TTSAudioArtifact.swift`

新增：

```swift
case readingDocumentSentence(documentID: String, sentenceID: String)
```

并更新 canonical representation：

```text
readingDocumentSentence|<documentID>|<sentenceID>
```

- [ ] **Step 9.3：扩展 Data media artifact source mapping**

修改：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBMediaArtifactRepository.swift`

要求：

- `sourceColumns(_:)` 支持 reading source。
- `ownerColumns(_:)` 如需要新增 `.readingDocument(id:)`，必须同步 Core `MediaArtifactOwner`。
- round-trip 测试覆盖 ready artifact 读取后 source 不丢失。

- [ ] **Step 9.4：扩展 Core / Data 测试**

修改：

- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactRepositoryTests.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/SentenceAudioPlaybackTests.swift`

新增断言：

- reading source artifact key hash 与 learning material source 不同。
- reading source metadata 写入 / 读取 round-trip。
- reading source 不记录 sentence text 明文到 artifact path、derivation key 或 diagnostic description。

- [ ] **Step 9.5：运行 TTS source 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTTSArtifactKeyTests
swift test --package-path Packages/LangoTraceData --filter MediaArtifactRepositoryTests
```

预期：通过。

### 11.11 阶段 10：ReadingLibraryStore / ReadingDocumentStore 与三端 UI action seam

- [ ] **Step 10.0：写失败测试 `ReadingLibraryStoreTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`

测试应覆盖：

- 初始化 library store 只加载当前 language space 的 active documents。
- 搜索资料库不触发 AI / TTS。
- 导入 pasted text 创建 import batch、document summary 和 lifecycle event。
- unsupported EPUB / PDF / HTML 在 UI 中显示不可导入状态，不创建 ready document。
- 删除 document 后 active list 不再显示，但 trash / restore projection 可见。
- 恢复 document 后 active list 重新显示。
- collection / tag filter 只影响资料库列表，不改变 document 正文。
- language space 切换后清空旧列表、selection、搜索和恢复状态。
- language space 切换后，旧 import / load 操作完成不得写回新空间列表或 import state。

- [ ] **Step 10.1：写失败测试 `ReadingDocumentStoreAIAndTTSTests`**

创建：`Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`

测试应覆盖：

- 初始化 store 不触发 AI。
- 导入 / 打开 document 不触发 AI。
- 打开 Markdown document 后使用结构化 blocks / appearance profile 生成 reading presentation，不把 Markdown 原文作为单个 plain chunk 展示。
- 选择文本不触发 AI。
- 点击 explain action 才触发 AI action，且传入 selection 和 limited context。
- 点击 explain action 是单次显式触发，不要求先进入“预览确认后发送”的二次确认流程；store 可以展示发送范围，但不以二次确认作为状态机必经节点。
- 点击 sentence audio action 才触发 `SentenceAudioPlaybackActions`。
- 当前 language space 切换后 document store 清空旧 document state。
- AI explanation failure 进入可恢复状态，不删除 selection。
- TTS requires configuration 展示配置需求，不自动重试。
- iPhone 顶层 tab 包含 reading，且进入 reading tab 只加载本地文档，不触发 AI / TTS。
- selection 变化、document 切换或 language space 切换后，旧 AI response / TTS response 完成必须被忽略，不得覆盖当前 selection、inspector、audio state 或错误状态。
- 重复点击 explain / sentence audio 不得产生重复 active operation；必须取消、合并、忽略或以 request token 失效旧操作，并在测试中锁定所选策略。

- [ ] **Step 10.2：实现 UI actions**

创建：`Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingActions.swift`

建议：

- `ReadingAIExplanationActions`
- `ReadingSentenceAudioActions`
- `ReadingImportActions`
- `ReadingLibraryActions`

约束：

- action closure 由 App Shell 注入。
- View 不直接 import LangoTraceAI / LangoTraceData concrete。

- [ ] **Step 10.3：实现 `ReadingLibraryStore` 和 `ReadingDocumentStore`**

创建：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`

职责：

- 二者均为 `@MainActor` presentation store。
- `ReadingLibraryStore` 维护 document summaries、search query、collection / tag filters、import batch state、trash / restore projection、selected document id。
- `ReadingDocumentStore` 维护当前 document、Markdown / plain text blocks、chunks、active `ReadingAppearanceProfile`、selectedText、selectedSentence、inspector state、AI explanation state、sentence audio state projection。
- `ReadingLibraryStore` 调用 library action 保存 / 读取 document summary、导入批次、collection/tag、删除和恢复。
- `ReadingDocumentStore` 调用 document action 读取正文和结构，调用 AI action 解释 selection，调用 sentence audio action 播放 reading sentence。
- store 必须维护 request token / generation counter 或等价机制，用于取消或忽略 stale import、load、AI explanation 和 TTS completion。
- selection、document、language space 或 active tab 变化时，store 必须取消或失效相关 in-flight task；取消不得清除新的有效 selection，也不得把旧错误显示到新 document。
- `ReadingDocumentStore` 不持久化用户样式；本轮只使用 default appearance profile，但状态结构必须允许后续从设备级或空间级偏好注入 profile。
- store 不持有 SQLite handle、URLSession、API Key 或真实文件路径。
- store 分层必须让后续资料库管理扩展不污染阅读正文 selection / AI / TTS 状态。

- [ ] **Step 10.4：实现三端阅读视图**

创建或修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryViews.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`

边界：

- iPhone：新增正式 `阅读` Tab，顺序为 `记录 / 阅读 / 练习 / 记忆`；阅读 Tab 首屏承载资料库列表、搜索、collection/tag filter、导入 / 粘贴入口、最近文档、删除 / 恢复入口。
- iPad：在现有 workspace / sidebar route 增加 reading route；大屏使用资料库列表 + 正文 + inspector 的可扩展布局。
- macOS：在 sidebar / toolbar 增加 reading route；菜单 / toolbar / keyboard shortcut 后续应走 `ReadingLibraryActions` / `ReadingDocumentActions`，本轮至少保证入口和 action seam 不分叉。
- 三端阅读正文使用同一 Markdown block presentation model；平台 View 只决定列布局、inspector 承载和交互 affordance，不各自重新解析 Markdown 或定义不一致样式。
- 入口命名和可见性必须在 UI 测试中锁定，避免后续回退成隐藏入口或二级 mock。

- [ ] **Step 10.5：运行 UI 聚焦测试通过**

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
```

预期：通过。

### 11.12 阶段 11：App assembly 与真实依赖注入

- [ ] **Step 11.1：装配 reading repository**

修改：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` 或当前 App assembly 所在文件。

要求：

- 使用 `GRDBReadingRepository` 和 `GRDBReadingLibraryRepository`。
- 按当前 language space 初始化 `ReadingLibraryStore` 和 `ReadingDocumentStore`。
- 语言空间切换时更新 reading library / document store space id，并清理旧 search、selection、document、trash projection 和 in-flight import 状态。
- 语言空间切换、文档切换和关闭阅读详情时必须取消或失效 in-flight AI/TTS/import/load task；旧 completion 不得写回新 store state。

- [ ] **Step 11.2：装配真实 AI explanation action**

要求：

- 从已保存 AI Provider 配置和 Keychain resolver 获取 text generation endpoint 与 secret。
- 调用 `ReadingSelectionExplanationService`。
- 写入 `reading_ai_explanation_operations` 非敏感 summary。
- Provider 未配置、credential missing、unsupported provider、network、auth、rate limit、invalid response 都映射为稳定 UI 状态。
- 用户点击 AI 解释即为显式触发；不增加二次确认门槛。UI 可展示本次发送范围和 Provider 信息，但 action seam 只接收一次明确 explain intent。
- 若调用被取消、selection 已变化、document 已切换或 language space 已切换，结果必须被丢弃，且不写入失败 summary。

- [ ] **Step 11.3：装配真实 TTS action**

要求：

- 构造 `SentenceAudioRequest`，source 使用 `.readingDocumentSentence(documentID:sentenceID:)`。
- owner 使用 reading document owner；如 Core 暂无 owner，新增 `.readingDocument(id:)` 并同步 Data media artifact owner columns。
- 复用 `SentenceAudioPlaybackActions.coordinator(_:)`。
- 不在页面出现、滚动或 selection 时调用 TTS。
- 若 sentence、document 或 language space 已变化，旧 TTS completion 不得覆盖当前 audio state；重复点击必须有明确策略并通过测试锁定。

- [ ] **Step 11.4：补 assembly 级源码测试**

若当前没有 App target 测试，至少在 UI package 增加源码级 convergence 测试，检查：

- SwiftUI View 不包含 `URLSession`。
- Reading views 不直接创建 `GRDBReadingRepository`。
- Reading views 不直接读取 Keychain。
- `PhoneRootTab` 包含 `.reading`，且 `allCases` 顺序为 `entries / reading / practice / memory`。
- Reading file import path 不持久化外部 absolute path 或 security-scoped bookmark。
- Reading views 如引入 UIKit / AppKit / TextKit bridge，bridge 不直接持有 repository、AI action、TTS action 或 Keychain resolver。
- Reading stores 包含 stale response guard 或 request token 机制；源码级测试或 store 单元测试必须证明旧 completion 不写入新 state。

### 11.13 阶段 12：证据文档

- [ ] **Step 12.1：创建 feature evidence 文档**

创建：`docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`

至少记录：

- 纵向切片日期、状态、执行命令。
- 三端 layout model 结论。
- TextKit / UIKit / AppKit bridge gate 结论：是否继续 SwiftUI chunk、是否采用 bridge、手动选词和 10k 字滚动的验证结果。
- 异步取消和 stale response 结论：import / load / AI explanation / TTS 的 request token 或 cancellation 策略、重复点击策略、space / document / selection 切换后的旧 completion 处理结果。
- Markdown 渲染结论：本轮采用的 parser、block / inline contract、default appearance profile、unsupported fallback、多语言 fixture、Dynamic Type / Dark Mode 结果，以及未实现的 Markdown 编辑 / round-trip 能力。
- VMark 快照结论：记录当次 `/Users/zibuyu/code/openSource/vmark` commit、`git status --short`、阅读文件、吸收设计、未复制实现、许可证复核结果；后续 VMark 评估必须追加新的 commit 上下文。
- 导入 preflight 阈值建议。
- 文件导入权限边界：metadata-before-read、permission denied、cancelled、unsupported format、外部路径不落库的验证结果。
- 10k 字 chunk 测试结果。
- 100k lookup 测试结果。
- CJK / 日语 / RTL 手动选择结论。
- CJK / Latin / 日文 / 韩文 / RTL Markdown 展示结论，特别是 inline code、ordered list marker、URL、link text、quote / dash、CJK 文件名和 code fence 的渲染边界。
- CJK / RTL 后续语言处理路线：Unicode UAX #29、Apple `NLTokenizer`、language pack、normalization strategy 的采纳 / 后置判断。
- 搜索实现结论：FTS5 external-content 是否采用；若未采用，普通 search index fallback 的原因和后续切换条件。
- source anchor stale 结论。
- reading AI explanation 请求边界、Prompt id/version、发送范围展示、单次显式触发策略、取消 / stale response 处理和日志允许字段。
- reading sentence TTS source、artifact key、cache / playback 结果。
- 本轮是否新增 fixture 文件；若新增，记录大小、内容来源、保留理由和清理条件。
- 推荐进入 MVP 的技术路线。
- 不进入 MVP 的内容。
- `docs/spec/012-reading-learning-domain.md` 是否已经吸收本轮稳定结论。
- 是否需要后续 `feature-reading-library-and-document-management` 或 `feature-reading-dictionary-and-lexeme` active plan。

- [ ] **Step 12.2：回写本 active plan 实施记录**

修改本方案的“实施记录”章节，记录：

- 已新增 / 修改文件。
- 已运行验证命令和结果。
- 若未运行完整 `scripts/verify.sh`，说明原因。

### 11.14 阶段 13：最终验证

- [ ] **Step 13.1：运行聚焦测试**

运行：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
```

预期：通过。

- [ ] **Step 13.2：运行 package 回归**

运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

预期：通过。

- [ ] **Step 13.3：运行文档检查**

运行：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

预期：

- `scripts/check-docs.sh` 通过。
- 占位词检索无命中。
- `git diff --check` 无输出。

- [ ] **Step 13.4：运行完整验证**

本任务涉及 Data migration、AI、TTS source、App assembly 和 UI action seam，必须运行：

```bash
scripts/verify.sh
```

预期：通过；若失败，必须记录失败命令、错误摘要、是否与本任务相关、补救或阻塞状态。

## 12. TDD / 测试落点

先失败测试：

- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportPreflightTests.swift`
  - 首个失败原因：`ReadingImportPreflight` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingImportRegistryTests.swift`
  - 首个失败原因：`ReadingImportFormatRegistry` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingLibraryModelTests.swift`
  - 首个失败原因：`ReadingLibraryDocumentSummary` / `ReadingLibraryStatus` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSearchQueryTests.swift`
  - 首个失败原因：`ReadingLibrarySearchQuery` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingMarkdownRenderingTests.swift`
  - 首个失败原因：`ReadingMarkdownParser` / `ReadingMarkdownBlock` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingAppearanceProfileTests.swift`
  - 首个失败原因：`ReadingAppearanceProfile` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTextSegmentationTests.swift`
  - 首个失败原因：`ReadingTextSegmenter` / `ReadingSelection` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingDictionaryLookupTests.swift`
  - 首个失败原因：`ReadingDictionaryLookupIndex` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingSourceAnchorTests.swift`
  - 首个失败原因：`ReadingSourceAnchor` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingPresentationTests.swift`
  - 首个失败原因：`ReadingLayoutModel` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingMarkdownBlockRendererTests.swift`
  - 首个失败原因：`ReadingMarkdownBlockRenderer` / `ReadingBlockPresentation` 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/AppDatabaseReadingMigrationTests.swift`
  - 首个失败原因：缺少 `reading_documents` / `reading_collections` / `reading_document_collections` / `reading_tags` / `reading_document_tags` / `reading_import_batches` / `reading_import_items` / `reading_document_lifecycle_events` / `reading_ai_explanation_operations` 表。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingRepositoryTests.swift`
  - 首个失败原因：`GRDBReadingRepository` 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/GRDBReadingLibraryRepositoryTests.swift`
  - 首个失败原因：`GRDBReadingLibraryRepository` 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingImportBatchRepositoryTests.swift`
  - 首个失败原因：`ReadingImportBatch` repository API 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingSearchIndexTests.swift`
  - 首个失败原因：reading search index table / repository API 未定义。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/Reading/ReadingDocumentLifecycleTests.swift`
  - 首个失败原因：reading lifecycle event table / repository API 未定义。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`
  - 首个失败原因：`ReadingSelectionExplanationService` 未定义。
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/Reading/ReadingTTSArtifactKeyTests.swift`
  - 首个失败原因：`TTSSentenceSource.readingDocumentSentence` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`
  - 首个失败原因：`ReadingLibraryStore` / `ReadingLibraryActions` 未定义。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
  - 首个失败原因：`ReadingDocumentStore` / `ReadingAIExplanationActions` 未定义。
  - 必须覆盖 stale AI / TTS completion 被忽略、selection / document / language space 切换取消或失效 in-flight task、重复点击策略不产生重复 active operation。

聚焦验证命令：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
```

完整相关 package 验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

## 13. 复查方法

实施者完成后应逐项确认：

1. 产品主参考、导航规范和页面清单已把阅读作为一级学习场景和三端 route 记录清楚。
2. `PhoneRootTab.swift` 已按方案新增 `.reading`，顺序为 `记录 / 阅读 / 练习 / 记忆`。
3. `AppDatabase.swift` 只新增本方案允许的 Reading library domain 基础 migration，不夹带同步、导出、真实 EPUB/PDF/HTML 解析或完整词典导入 schema。
4. Reading models 使用正式 `Reading` 命名，资料库基础设施、导入扩展、正文阅读、AI/TTS 边界清晰，不伪装成完整电子书阅读器或完整词典产品。
5. 所有 fixture 为合成文本，不包含真实用户文本或版权词典。
6. 词典 lookup 测试使用合成 100k entries，不提交大文件 fixture。
7. Reading library repository 覆盖 language space 隔离、collection/tag membership、import batch partial failure、search index stale / rebuild、soft delete / restore 和 lifecycle event。
8. Source anchor stale 判定覆盖 revision changed 和 selected text hash changed。
9. UI presentation tests 覆盖 phone / pad / mac 三端布局差异，并覆盖资料库列表、搜索、删除恢复、selection 后 inspector presentation state。
10. AI explanation 测试证明只有显式 action 发请求，请求不包含全文、历史记忆、附件、密钥或日志敏感字段。
11. TTS 测试证明只有显式 sentence audio action 触发，reading source artifact key 不与 entry / learning material 混淆。
12. Evidence 文档记录测试命令、结果、资料库基础设施、导入扩展、VMark 借鉴结论、阈值建议、AI/TTS 边界、fixture 边界和后续任务拆分。

## 14. 验证命令

创建本方案后的文档验证：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

实施后的聚焦验证：

```bash
swift test --package-path Packages/LangoTraceCore --filter Reading
swift test --package-path Packages/LangoTraceData --filter Reading
swift test --package-path Packages/LangoTraceAI --filter Reading
swift test --package-path Packages/LangoTraceUI --filter Reading
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceUI
```

实施后完整验证：

```bash
scripts/verify.sh
```

## 15. 文档影响检查

本 feature 纵向切片完成后必须检查：

- `docs/reference/research/spikes/2026-06-01-reading-ai-tts-vertical-slice.md`：新增 evidence，记录实际验证结果。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md`：如纵向切片推翻原推荐路线，应回写修正；如只是补证据，可引用 evidence。
- `docs/prompts/README.md` 和 `docs/prompts/reading/selection-explanation.md`：登记真实 reading AI explanation Prompt。
- `docs/product-main-reference.md`：必须更新一句话定位、一级学习对象和主 slogan 保留边界。
- `docs/platform-page-inventory.md`：必须登记 iPhone / iPad / macOS 阅读 route、当前能力、未实现能力和代码路径。
- `docs/spec/002-navigation-and-routing.md`：必须更新 iPhone 一级入口为 `记录 / 阅读 / 练习 / 记忆`，并补充三端 reading route 承载规则。
- `docs/spec/012-reading-learning-domain.md`：必须新增或更新 Reading domain 规范，覆盖导入、document、structure、position、source anchor、selection AI、reading TTS、词典边界和非目标。
- `docs/spec/012-reading-learning-domain.md`：还必须覆盖资料库 collection/tag、import batch、search index、soft delete / restore、lifecycle event、future EPUB/PDF/HTML adapter、future dictionary import adapter 和 VMark Markdown 借鉴边界。
- `docs/spec/012-reading-learning-domain.md`：还必须覆盖精美 Markdown 阅读体验、block / inline renderer contract、`ReadingAppearanceProfile`、多语言 Markdown 展示 fixtures、VMark commit 快照记录要求、CJK / locale / media URL 借鉴边界，以及阅读资料库按 `LanguageSpace` 分层的 repository 规则。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：必须更新阅读 selection-only AI 边界、单次显式触发、发送范围展示、取消 / stale response 处理和日志允许字段；不得把本轮实现写成“预览确认后发送”的两步门槛。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：必须补充 ReadingDocument 主数据、library metadata、collection/tag、import batch、search index、structure、source anchor、position、operation summary 和删除 / 导出 / 同步默认边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：必须更新 readingDocumentSentence source、reading document owner 和 artifact policy。
- `docs/spec/009-testing-and-verification.md`：若纵向切片形成稳定手动验证流程，可在 MVP 计划中更新。
- `docs/architecture/notes/`：若纵向切片发现 EPUB/PDF、source anchor、dictionary import 或 sync 边界的新风险，应新增或更新架构备忘录。
- `docs/review/README.md` 和 `docs/review/INDEX.md`：本任务涉及 Data schema、AI、TTS 和三端入口，应触发专项文档影响检查，并记录是否需要 review round。

## 16. 严格方案自审核记录

审核日期：2026-06-01

审核方式：主会话自审核。

审核轮次：双轮合并执行；2026-06-01 按用户要求根据 `docs/plans/README.md` 追加补充自审；2026-06-01 按用户要求追加真实 AI / TTS 开发范围复审。

2026-06-01 追加：按用户提出的早期开发阶段重构原则、基础设施完整建设原则和 dev docs 控制面原则再次复审。

未使用隔离审查的原因：当前用户要求立即创建 active plan 文档，且本轮不进入生产代码实现；主会话按 `docs/plans/plan-review-protocol.md` 的两轮维度完成写回。

### 第一轮：系统架构师审查

发现摘要：

- P1：如果把本任务写成完整阅读 MVP，会过早触碰完整电子书阅读器、完整词典导入、同步、导出和全文 AI / 批量 TTS，范围过大。
  - 写回修改：本方案定位为基础设施优先的 feature 纵向切片；阅读资料库基础设施和最小管理闭环纳入本轮，完整电子书阅读器、完整词典导入、同步、导出、全文 AI 和批量 TTS 不纳入本轮。
  - 是否阻塞实现：已修正；进入完整 MVP 前仍需新方案。
- P1：阅读作为一级学习场景和现有三 Tab 存在导航张力。
  - 写回修改：初版曾不修改 `PhoneRootTab`；本次追加复审后改为用户批准实施时同步更新产品 / 导航规范 / `PhoneRootTab`，避免隐藏入口成为长期债务。
  - 是否阻塞实现：阻塞任何未获用户批准的生产代码改动；不阻塞继续完善方案。
- P1：词典和 source anchor 容易与未来正式主数据混淆。
  - 写回修改：reading document / source anchor 进入最小正式模型；词典 lookup 仍保留验证性质，不创建正式词典 repository。
  - 是否阻塞实现：不阻塞纵向切片。
- P2：VMark 参考不能变成跨栈复制。
  - 写回修改：方案只吸收 format registry、pre-read gate、document state unit、command intent 等思想，不复制代码。
  - 是否阻塞实现：不阻塞。

### 第二轮：测试、安全和落地性审查

发现摘要：

- P1：原研究文档的 TDD 落点是方向性清单，缺少先失败测试名和失败原因。
  - 写回修改：第 11、12 节列出具体测试文件、测试名、命令和预期失败原因。
  - 是否阻塞实现：已修正。
- P1：阅读文本和词典内容容易进入日志或 fixture。
  - 写回修改：约束中明确只使用合成文本，日志不记录完整正文、selection 或词典解释。
  - 是否阻塞实现：实施时必须复查。
- P2：真实 AI/TTS 和 Data migration 范围下，完整验证必须成为硬门禁。
  - 写回修改：第 11.14 和 14 节要求 Core / Data / AI / Speech / UI package 验证和 `scripts/verify.sh`。
  - 是否阻塞实现：已修正。
- P2：文档影响可能被误解为只更新 Prompt Registry 和 evidence。
  - 写回修改：第 15 节明确实施本方案时必须更新产品主参考、导航规范、页面清单、Reading spec、AI / Data / TTS spec，并评估 review round。
  - 是否阻塞实现：已修正。

### 追加自审：按 `docs/plans/README.md` 必填项和 evidence 要求复核

发现摘要：

- P1：导入 preflight 用例未覆盖 `.txt` / `.md` 显式格式边界和编码失败，和本方案目标“编码失败、size gate”不完全一致。
  - 证据：第 4 节目标包含 `.txt` / `.md` 和编码失败；原第 11.2 只覆盖 pasted text、long text、byte limit。
  - 影响：实施者可能只做 metadata gate，无法为阅读 MVP 判断真实导入失败路径。
  - 写回修改：第 11.2 增加 supported extension 和 invalid bytes 测试，实施要点增加 `decodeTextData`、UTF-8 / UTF-16 best-effort 和 `.encodingFailed`。
  - 是否阻塞实现：已修正；实施时必须先写这些失败测试。
- P1：早期 UI 计划只验证三端 layout，不验证 selection 触发 inspector 的状态流。
  - 证据：原第 11.6 只检查 `primaryColumnCount` 和 `inspectorPresentation`。
  - 影响：无法证明 iPhone bottom sheet / iPad inspector 的核心交互能通过 presentation state 表达。
  - 写回修改：第 11.6 增加 `ReadingPresentationState` 和 selection opens inspector 测试。
  - 是否阻塞实现：已修正。
- P1：Source anchor stale 判定只测试 revision changed，没有测试 selected text hash changed。
  - 证据：原第 11.5 只有 current 和 revision changed 用例。
  - 影响：文本同 revision 下重新分段或 selection hash 变化时可能静默误指。
  - 写回修改：第 11.5 增加 selected text hash changed 测试。
  - 是否阻塞实现：已修正。
- P2：`docs/plans/README.md` 要求 spike / probe / fixture / evidence 写清敏感内容、验证方式、保留期限和清理条件；原方案只说明合成 fixture，不够可审计。
  - 证据：`docs/plans/README.md` 第 5 节要求高风险任务说明 spike / probe / fixture / evidence。
  - 影响：后续可能把真实文本或词典样本留在 evidence 目录。
  - 写回修改：新增第 7.6 节，补充 evidence 文档必须记录 fixture 文件边界和清理条件。
  - 是否阻塞实现：已修正。
- P2：文档影响检查未显式判断 review round。
  - 证据：`docs/plans/plan-review-protocol.md` 第二轮要求文档影响检查判断 review round。
  - 影响：若实施中越界改 Data / navigation / AI / TTS，可能漏掉专项审查。
  - 写回修改：第 15 节新增 `docs/review/README.md` 和 `docs/review/INDEX.md` 检查项。
  - 是否阻塞实现：已修正。

### 追加自审：真实 AI / TTS 范围复核

发现摘要：

- P0：原方案明确“不接真实 AI / TTS”，与用户新要求冲突。
  - 证据：原 Architecture 和“本任务不做”包含“不接真实 AI explanation / TTS playback”。
  - 影响：按原方案实施会产出无法验证真实 Provider 链路的伪 spike，不能满足当前开发要求。
  - 写回修改：将类型从 `research` 改为 `feature`，目标改为阅读 AI/TTS 纵向切片，加入 Data、AI、TTS、UI 和 App assembly 阶段。
  - 是否阻塞实现：已修正；后续实施必须按 feature 级门禁执行。
- P1：接真实 AI 后必须补 Prompt Registry、发送范围展示 / 日志边界。
  - 证据：`docs/workflows/add-ai-provider.md` 和 `docs/prompts/README.md` 要求新增 AI 能力登记 Prompt、说明发送内容、日志允许字段和失败路径。
  - 影响：如果只写 service，不登记 Prompt，后续隐私审查和输出契约不可追踪。
  - 写回修改：新增 `docs/prompts/reading/selection-explanation.md`、`ReadingSelectionExplanationServiceTests` 和 AI operation summary 要求。
  - 是否阻塞实现：已修正。
- P1：接真实 TTS 后不能复用 learning material source。
  - 证据：`TTSSentenceSource` 当前只有 entry、learningMaterialSentence、temporary；调研文档要求 reading source 不与 Entry / LearningMaterial 混淆。
  - 影响：若复用现有 source，media artifact cache、删除、导出和诊断会错误归属。
  - 写回修改：新增 `readingDocumentSentence(documentID:sentenceID:)` source、Core key 测试和 Data source columns round-trip。
  - 是否阻塞实现：已修正。
- P1：真实 AI/TTS 纵向切片需要正式 Reading domain 主数据，否则 source anchor 和 TTS artifact owner 缺少稳定 source id。
  - 证据：source anchor、TTS source 和 AI operation summary 都需要 document id / sentence id。
  - 影响：如果继续纯内存，TTS artifact key、operation summary 和后续 stale 判断无法稳定复现。
  - 写回修改：允许新增 Reading library domain 基础 GRDB migration、`GRDBReadingRepository` 和 `GRDBReadingLibraryRepository`；阅读资料库基础设施纳入本轮，但完整词典导入、同步和导出不纳入本轮。
  - 是否阻塞实现：已修正。
- P2：真实 Data / AI / TTS / assembly 变更后，完整验证不能再是条件性。
  - 证据：`docs/workflows/add-ai-provider.md`、`docs/workflows/add-tts-provider.md` 和 `docs/plans/README.md` 对高风险动作要求聚焦测试和完整验证。
  - 影响：只跑 Core / UI 测试会漏 Data migration、AI service、Speech / media artifact 和 App assembly 问题。
  - 写回修改：验证命令扩展到 Core / Data / AI / Speech / UI，并要求运行 `scripts/verify.sh`。
  - 是否阻塞实现：已修正。

### 追加自审：早期重构、基础设施和 dev docs 控制面复核

发现摘要：

- P0：原方案把“不修改 `PhoneRootTab` / 不更新导航规范”作为硬边界，实质上让一个已被研究确认的一级学习场景继续服从旧三 Tab 临时设计。
  - 证据：`docs/spec/002-navigation-and-routing.md` 当前固定 `记录 / 练习 / 记忆`；调研文档已建议长期 `记录 / 阅读 / 练习 / 记忆`；用户明确要求早期阶段发现落后应用级设计可主动推倒重来。
  - 影响：如果继续只做隐藏入口，会形成新的信息架构债务，后续仍要重写 Tab、页面清单和路由测试。
  - 写回修改：第 4、5、7.1、8、11.1、11.11、13、15、18 节改为“用户批准实施后同步更新产品 / 导航 / 页面清单并新增正式 reading route”，不再把旧导航作为不可触碰边界。
  - 是否阻塞实现：已修正；但仍需用户批准本 feature 实施和导航升级范围。
- P1：原 “最小 reading schema” 偏纵向 demo，不足以作为基础设施首版。
  - 证据：`docs/spec/007-data-storage-migration-export-and-attachments.md` 明确真实数据基础设施不得只实现单对象临时版本；阅读 AI/TTS source anchor 需要稳定 document / structure / anchor / operation 主数据。
  - 影响：后续做阅读资料库、记忆回链、练习回链、删除、导出或同步时会补 schema，造成迁移和 repository 返工。
  - 写回修改：第 7.3 和 11.8 将 migration 提升为 Reading domain 基础 schema，新增 `reading_structure_blocks`、`reading_source_anchors`、`reading_import_operations`，并要求 CHECK、唯一索引、device scoped position 和 operation id 幂等。
  - 是否阻塞实现：已修正。
- P1：原文档影响检查把产品主参考、导航规范、Data / AI / TTS spec 放到“后续或可选”，与 dev docs 作为开发控制面的原则冲突。
  - 证据：入口文档要求形成新结论时写回对应事实源，research / active plan 不能替代长期 spec。
  - 影响：后续 AI 会话会从旧 spec 读取错误事实，继续生成三 Tab 或无 Reading domain 的实现。
  - 写回修改：第 7.8、8、10、11.1、15 节新增 `docs/spec/012-reading-learning-domain.md`，并把产品、导航、页面清单、AI、Data、TTS spec 更新列为实施步骤和完成标准。
  - 是否阻塞实现：已修正。
- P2：Reading route 上升为一级入口后，测试不能只检查 presentation model。
  - 证据：原 UI 测试只覆盖 layout model 和 selection inspector。
  - 影响：可能出现阅读功能存在但入口隐藏、Tab 顺序回退或进入阅读页即触发外部请求。
  - 写回修改：第 11.11 和 13 节新增 `PhoneRootTab` 顺序、reading tab 进入不触发 AI/TTS、源码 convergence 测试要求。
  - 是否阻塞实现：已修正。

### 追加自审：阅读资料库优先、导入扩展和 VMark Markdown 参考复核

发现摘要：

- P0：原方案把“不做完整阅读资料库、分组、搜索、删除恢复和批量管理”列为硬排除，已经与用户 2026-06-01 的最新开发要求冲突。
  - 证据：用户明确要求优先做完整阅读资料库设计，方便导入和管理阅读素材。
  - 影响：如果继续按旧方案实施，会落成一个只能打开正文的阅读页 shell，后续资料库、搜索、删除恢复、导入批次和管理入口需要重做 schema、repository 和 UI store。
  - 写回修改：第 2、4、5、7.3、7.3.1、8、11.8、11.11、12、13、15、18、19 节将阅读资料库基础设施纳入本轮核心范围，新增 collection/tag、search index、import batch、lifecycle event、soft delete / restore、ReadingLibraryStore 和 ReadingLibraryRepository。
  - 是否阻塞实现：已修正；实施时必须先完成资料库基础设施，不得回退到纯阅读页 shell。
- P1：未来 EPUB / PDF / HTML / Web clip 和词典导入虽然本轮不实现，但原方案没有足够扩展位。
  - 证据：原方案只允许 `.txt` / `.md`，词典只做纯内存 100k lookup。
  - 影响：后续引入多格式导入和词典导入时，会重新设计 source format、adapter version、body storage kind、import batch、normalization strategy 和 lexeme state。
  - 写回修改：新增 `ReadingImportFormatRegistry`、future adapter descriptors、source_format、adapter_id/version、MIME / UTI、managed_body_artifact_id、dictionary import / normalized lookup / lexeme state spec 预留要求。
  - 是否阻塞实现：已修正；真实 EPUB / PDF / HTML 和词典 UI 仍需后续 active plan。
- P1：VMark Markdown 借鉴路径过泛，实施者无法准确阅读参考代码。
  - 证据：原方案只写 VMark 可借鉴格式注册表、大文件打开管线等概念。
  - 影响：开发时可能漏读 VMark 的 large-file gate、Markdown allowlist、code-aware cleanup、content search 和 selection context，也可能误以为可直接复制跨栈实现。
  - 写回修改：新增第 8.1 节列出 VMark 具体参考文件；第 7.9 节明确只吸收设计和测试思路，不复制 React / Tiptap / ProseMirror / CodeMirror / Tauri 实现。
  - 是否阻塞实现：已修正。

### 追加自审：TextKit gate、AI explanation 触发和 async stale response 复核

发现摘要：

- P1：TextKit / UIKit / AppKit bridge 选择不应作为 Phase 0 阻塞门禁。
  - 证据：用户明确不接受把 TextKit / SwiftUI chunk 选择前置成真正的 Phase 0 阻塞门禁。
  - 影响：如果继续阻塞，纵向切片会被文本引擎选型拖住，无法先验证资料库、Markdown、AI/TTS 和 source anchor 主链路。
  - 写回修改：第 7.4 改为 SwiftUI chunk 可先推进，bridge 选择作为 evidence 和剩余风险记录；第 18、19 节保留真实设备文本选择和辅助功能风险。
  - 是否阻塞实现：已修正；TextKit 选择不阻塞本方案进入实现，但不能声称已完成复杂文本引擎验证。
- P1：AI explanation 不采用“预览确认后发送”的两步动作。
  - 证据：用户明确 AI explanation 不需要采用“预览确认后发送”的两步动作。
  - 影响：如果强制二次确认，会增加阅读中解释动作摩擦，并改变当前显式点击即触发的 action seam。
  - 写回修改：第 7.10、11.9、11.11、11.12、12、15 节改为单次显式 explain action 触发；UI 可展示发送范围和 Provider 信息，但不把二次确认作为状态机门槛。
  - 是否阻塞实现：已修正；仍必须保证默认不自动触发、只发送 selection 和有限上下文。
- P1：async cancellation / stale response 必须作为进入实现前补齐边界。
  - 证据：真实 AI/TTS 和资料库 import/load 都会跨越 selection、document 和 language space 生命周期。
  - 影响：若旧请求完成后写回新 state，会出现错误解释、错误音频状态、跨空间状态污染或误写 operation summary。
  - 写回修改：新增第 7.10，补充 `ReadingLibraryStoreTests` / `ReadingDocumentStoreAIAndTTSTests`、store 职责、App assembly、evidence、完成标准和剩余风险中的 cancellation / stale response 要求。
  - 是否阻塞实现：是。进入实现前必须保留这些测试落点；实现完成前必须通过相关测试。

仍需用户确认的问题：

- 是否批准按本方案进入 feature 纵向切片实施。
- 是否批准本轮同时升级 iPhone 顶层导航为 `记录 / 阅读 / 练习 / 记忆`，并同步修订产品主参考、导航规范和页面清单。
- 本轮资料库 UI 的管理深度：是否只做列表 / 搜索 / collection-tag filter / 删除恢复入口，还是同时做多选批量管理 UI。当前方案建议本轮不做多选批量编辑 UI，但 repository 支持 import batch 和 membership 幂等。
- 纵向切片完成后，是优先进入词典导入与词状态，还是优先进入 EPUB / PDF / HTML / Web clip adapter。

是否允许进入实现：否。当前状态为 `Draft`，需要用户明确确认后才能开始实现。

## 17. 实施记录

- 2026-06-01：创建本 active plan，最初依据阅读整合调研收敛为 research spike；完成主会话自审核并写回范围、TDD、验证命令和文档影响检查。
- 2026-06-01：按用户要求根据 `docs/plans/README.md` 追加自审并修订方案：补齐格式识别、编码失败、selection range、selection -> inspector、hash mismatch stale、fixture / evidence 边界和 review round 判断。
- 2026-06-01：按用户要求将方案从纯 research spike 调整为 feature 级阅读 AI/TTS 纵向切片：接入真实 AI selection explanation、真实 reading sentence TTS、GRDB reading 主数据 schema、Prompt Registry、TTS source key、App assembly 和完整验证门禁。
- 2026-06-01：按用户追加的早期重构、基础设施完整建设和 dev docs 控制面原则复审并修订：取消“不改导航 / 不改规范”的硬限制，将阅读正式一级入口、产品 / 导航 / 页面清单 / Reading spec 更新、Reading domain 基础 schema 和四 Tab 测试纳入本方案；方案仍为 Draft，尚未进入生产代码实现。
- 2026-06-01：按用户要求立即修订方案：取消“不做完整阅读资料库”的旧限制，将阅读资料库基础设施、collection/tag、search index、import batch、soft delete / restore、lifecycle event、导入 adapter 扩展、未来词典导入边界和 VMark Markdown 具体参考路径纳入本方案；方案仍为 Draft，尚未进入生产代码实现。
- 2026-06-01：按用户要求继续修订方案：补充 TextKit / UIKit / AppKit bridge spike gate、FTS5 优先且普通 search index fallback 不改变 repository API、文件导入 security-scoped / 外部路径不落库边界、CJK / RTL 后续基于 Unicode UAX #29 / Apple `NLTokenizer` / language pack 的处理路线；方案仍为 Draft，尚未进入生产代码实现。
- 2026-06-01：按用户要求继续修订方案：将 Markdown 渲染从普通结构化导入升级为本轮精美阅读体验的核心边界，新增 `ReadingMarkdownParser` / `ReadingMarkdownBlock` / `ReadingMarkdownBlockRenderer` / `ReadingAppearanceProfile`、多语言 Markdown fixtures、VMark CJK / locale / theme / markdown pipeline 参考路径、VMark commit 快照记录要求，以及资料库按 `LanguageSpace` 分层的更严格 repository 规则；方案仍为 Draft，尚未进入生产代码实现。
- 2026-06-01：按用户确认继续修订方案：TextKit / SwiftUI chunk 选择不作为 Phase 0 阻塞门禁；AI explanation 改为单次显式点击触发、不采用“预览确认后发送”的两步动作；新增 async cancellation / stale response 作为 P1 必补边界，覆盖 import / load / AI / TTS 的 request token、取消、失效和旧 completion 忽略测试。

## 18. 完成标准

本任务完成时必须满足：

- 本方案状态更新为 `Implemented` 或移动到 `done/` 后更新为 `Verified` / `Done`。
- Core reading 测试全部通过。
- Data reading migration / repository / library / import batch / search index / lifecycle 测试全部通过。
- AI reading selection explanation 测试全部通过。
- TTS reading source / media artifact 测试全部通过。
- UI reading library、reading presentation 和 AI/TTS action seam 测试全部通过。
- Evidence 文档存在且记录实际命令和结果。
- `PhoneRootTab.swift`、`docs/spec/002-navigation-and-routing.md`、`docs/product-main-reference.md` 和 `docs/platform-page-inventory.md` 已一致表达阅读一级入口。
- `docs/spec/012-reading-learning-domain.md` 已存在并记录 Reading domain、资料库、导入扩展、Markdown adapter、未来词典导入边界和 AI/TTS 长期规则。
- `docs/spec/012-reading-learning-domain.md` 已记录 Markdown block renderer、`ReadingAppearanceProfile`、多语言 Markdown 展示边界、VMark commit 快照记录要求和语言空间级资料库隔离规则。
- `AppDatabase.swift` 只包含本方案允许的 Reading library domain 基础 migration，不包含真实 EPUB/PDF/HTML parser、完整词典导入、同步或导出实现。
- 资料库最小管理闭环可用：列表、搜索、导入 / 粘贴、打开、collection/tag filter、软删除和恢复。
- `ReadingImportFormatRegistry` 只启用 pasted text、txt、md，且明确记录 EPUB / PDF / HTML / Web clip 为 future adapter。
- Markdown 阅读不是 plain text fallback：`.md` 导入后至少形成 heading / paragraph / blockquote / list / code block / link / emphasis / inline code / horizontal rule 的结构化 presentation，并通过 default `ReadingAppearanceProfile` 呈现精美、可访问、可扩展的阅读体验。
- `ReadingAppearanceProfile` 作为 renderer 输入存在，第一版可无用户自定义 UI，但后续字体、字号、行距、段距、主题、代码块样式和阅读宽度自定义不需要重写 parser、repository、AI/TTS selection contract。
- 文件导入遵守 metadata-before-read 和短生命周期安全访问边界，不持久化外部 absolute path、security-scoped bookmark 或用户目录结构。
- 搜索实现优先使用 FTS5 external-content 或等价可重建索引；如本轮降级普通 search index，repository API 和测试语义仍保持 FTS-capable。
- TextKit / UIKit / AppKit bridge 选择 evidence 已记录，说明本轮采用 SwiftUI chunk、bridge 或 plain reader 的理由和风险；该选择不作为 Phase 0 阻塞门禁。
- Async cancellation / stale response 测试通过：import / load / AI explanation / TTS 的旧 completion 不会写入新的 space、document、selection、inspector 或 audio state，重复点击策略已锁定。
- CJK / RTL 后续语言处理路线已写入 `docs/spec/012-reading-learning-domain.md`，不把英文 lowercased word boundary 当作全局默认。
- VMark 参考 evidence 已记录 commit、工作区状态、实际阅读文件、吸收设计、未复制实现、许可证复核和多语言展示借鉴结论。
- 未提交真实用户文本、版权词典或大体积 fixture。
- Prompt Registry 已登记 reading selection explanation Prompt。
- `scripts/verify.sh` 通过，或失败项有明确环境原因和替代验证记录。
- 文档验证通过。
- 剩余风险和下一步 feature plan 建议已写回。

## 19. 剩余风险

- SwiftUI presentation model 测试不能完全替代真实设备上的文本选择、VoiceOver、Dynamic Type 和滚动体验；后续 MVP 前仍需要模拟器或真机人工验证。
- TextKit / UIKit / AppKit bridge 选择不阻塞本纵向切片；本轮如继续使用 SwiftUI chunk，仍不能替代后续真实设备上的长文本选择、辅助功能和平台差异验证。
- Async cancellation / stale response 测试只能覆盖 store/action seam 的确定性行为；真实 Provider、音频播放和文件导入的底层取消时序仍需在后续模拟器或真机验证中观察。
- 本轮 Markdown renderer 只验证短文本 / 10k 字级 Markdown 阅读体验，不验证复杂表格、Mermaid、HTML preview、数学公式、图片附件、脚注、双向 Markdown 编辑或 round-trip 保存。
- 本轮只提供 default `ReadingAppearanceProfile`，不做用户自定义样式 UI、样式同步或 per-document style 持久化；这些必须后续独立设计设备级 / 空间级 / 文档级偏好边界。
- VMark 是持续迭代项目，本轮记录的 commit 快照只能代表当次评估；后续继续借鉴 VMark 必须重新记录 commit、diff、许可证和吸收上下文。
- 本轮资料库提供最小管理闭环，但不验证多选批量编辑 UI、复杂书库封面墙、智能分类和跨设备阅读位置同步。
- 本轮 search index / FTS 只验证本地资料库搜索基础，不验证大型书库、多字段 ranking、搜索结果高亮和跨格式全文搜索；若实现期使用普通 search index fallback，FTS5 切换仍需后续任务验证。
- 纯内存 100k lookup 只能证明索引思路，不等于 GRDB normalized index 性能结论；正式词典导入仍需 Data package migration 和 benchmark。
- EPUB / PDF / HTML / Web clip 只保留 adapter 和 schema 扩展位，不验证真实解析质量、版权提示、章节目录和正文抽取。
- 文件导入权限边界只覆盖短生命周期读取和导入副本；长期外部文件引用、sandbox bookmark 管理和外部文件变更监听需要独立 attachment / external file plan。
- CJK / RTL 本轮只保证手动 selection 不依赖英文空格；自动 tokenization、furigana、词形还原和 RTL 高级排版仍需后续 language pack 任务。
- 本纵向切片会验证真实 AI explanation，但不验证全文总结、全文翻译、历史记忆摘要、附件摘要或多 Provider 高级兼容。
- 本纵向切片会验证真实 reading sentence TTS source，但不验证全文朗读、批量预生成、后台播放、锁屏控制或音频同步。
- 本纵向切片不验证导出、备份、同步和删除传播；这些必须在 reading export / backup / sync 任务中重新建模。
- 本纵向切片会更新产品主参考和导航规范，并交付资料库基础设施和最小阅读闭环；词典导入、词状态、导出、同步、阅读统计和高级格式 adapter 仍需后续 active plan 收口。
