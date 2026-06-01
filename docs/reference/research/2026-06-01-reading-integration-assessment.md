# 完整阅读能力整合调研评估

日期：2026-06-01

状态：Research Result，已被 active plan 承接

复审状态：Reviewed and Revised

复审日期：2026-06-01

定位再审日期：2026-06-01

复审范围：

- 当前 LangoTrace 权威文档：`docs/README.md`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md`、`docs/plans/README.md`、`docs/plans/plan-review-protocol.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/011-tts-provider-configuration-and-playback.md`、`docs/spec/learning-content/impl.md`、`docs/spec/media-artifacts/impl.md`。
- 当前 LangoTrace 代码：`PhoneRootTab`、`LearningContentStore`、`AppDatabase`、`LearningContentModels`、`SentenceAudioPlaybackCoordinator`、`GRDBLearningContentRepository`、media artifact 基础设施。
- VMark 本地源码：`/Users/zibuyu/code/openSource/vmark`，重点阅读 `README.md`、`LICENSE`、`dev-docs/architecture.md`、`dev-docs/large-file-open-pipeline.md`、`dev-docs/decisions/ADR-008/009/010/012/013`、`src/lib/formats/`、`src/services/navigation/largeFileRouting.ts`、`src/utils/fileSizeThresholds.ts`、`src/stores/documentStore/`、`src/services/commands/CommandBus.ts`、`src/components/ContentSearch/`、`src/services/editor/extractContext.ts`、`src/hooks/useGenieInvocation.ts`。

## 1. 结论摘要

可以在 LangoTrace 上继续开发完整阅读能力，并且这条路线比从 VMark 改造更合理。

定位再审后补充一个更清晰的边界：阅读应进入 LangoTrace 的一级学习场景，因为阅读是语言学习的基础输入环节；但品牌标语仍建议保留“用生活记录学习语言”。标语负责表达差异化，不负责枚举全部功能。产品定位可以扩展为“把生活记录和阅读材料变成外语学习闭环”，而不把 slogan 改复杂。

阅读能力不能把产品从“用生活记录学习语言”改造成通用电子书阅读器或外部资料库产品。第一阶段应把阅读定义为“用户主动导入的个人学习材料”，并让阅读材料能回流到当前语言空间、Memory、Practice 和 TTS，而不是替代 Entry 生活记录闭环。

这里的“阅读能力”不是生活记录详情里的辅助视图，而是一组完整产品能力：

- 阅读资料库。
- 文本 / 文件导入。
- 阅读进度。
- 点词 / 选词查询。
- 本地词典与词典导入。
- 词状态标注。
- 句子挖掘。
- TTS 阅读。
- 生词、短语、句子进入记忆和复习。
- iPhone / iPad / macOS 各自适配的阅读体验。

LangoTrace 已有 SwiftUI Multiplatform、Language Space、GRDB、Keychain、用户自带 Provider、TTS、练习录音、媒体派生资产和三端 UI 骨架。它天然适合承载完整阅读模块。主要风险不在技术路线，而在产品边界和复杂度控制：如果阅读模块一开始就追求 Readest / LingQ / LinguaCafe 级完整度，会显著扩大数据模型、UI、导入、同步、版权和性能范围。

推荐结论：

> LangoTrace 应把阅读能力作为长期产品中的一级学习场景纳入路线，并把长期 iPhone 主导航目标调整为 `记录 / 阅读 / 练习 / 记忆`。同时第一阶段仍只能从“纯文本 / Markdown 阅读资料库 + 手动选词查词 + 词句沉淀 + 单句 TTS”开始；不能直接承诺 EPUB / PDF / 网页抓取，不能自动把整篇材料发送给 AI。

产品表达建议：

- 主 slogan 保留：`用生活记录学习语言` / `Learn languages from your life`。
- 一句话定位扩展为：`语迹是一款把你的生活记录和阅读材料变成外语学习闭环的本地优先 App。`
- 一级学习对象从单一生活记录扩展为双来源：`生活记录` 和 `阅读材料`。
- 一级学习动作长期收敛为四类：`记录 / 阅读 / 练习 / 记忆`。

## 1.1 严格复审结论

状态：Needs Changes before feature implementation

这份 research 可以作为后续 active plan 的输入，但尚不能直接作为实现方案。后续已创建 `docs/plans/active/2026-06-01-feature-reading-ai-tts-vertical-slice.md` 承接本研究，并按 `docs/plans/plan-review-protocol.md` 完成自审核；该 active plan 仍为 `Draft`，尚未获得生产代码实现授权。

### 关键问题

- P1：产品边界需要分层表达。阅读应升级为一级学习场景，但不能稀释“用生活记录学习语言”的品牌差异化。建议保留主 slogan，同时扩展一句话定位和功能架构。
- P1：导航方案 B 从长期看有必要，但不能作为无方案的即时改动。`docs/spec/002-navigation-and-routing.md` 和 `PhoneRootTab` 当前都固定 iPhone 三 Tab：`记录 / 练习 / 记忆`。新增“阅读”一级 Tab 属于导航规范变更，至少需要 active plan、spec 更新、页面清单更新，若改变核心信息架构还要评估 ADR。
- P1：VMark 证据链不足。VMark 没有语言学习阅读器、词典或 lexeme state；它值得借鉴的是文档状态、格式适配、打开管线、大文件性能、命令意图和服务分层。不能把 VMark 的 Markdown 编辑器优势直接等价为 LangoTrace 的阅读学习实现。
- P1：数据模型缺少版本、导入、删除、导出和大文本策略。`reading_documents.body` 单字段可以作为早期小文本 MVP，但 active plan 必须明确大小上限、body hash、structure version、source anchor revision、import artifact、软删除、导出 / 备份 / 同步默认策略和 migration 测试。
- P1：词典和词状态容易膨胀为独立词库产品。第一阶段应先实现用户导入 CSV/TSV/JSON 的本地查词和词状态，不内置版权词典，不做 MDX / StarDict，不做自动 SRS。
- P2：AI 查询边界需要更细。点词时本地词典优先；AI 解释必须显式触发；不得自动发送全文；上下文半径、请求预览、成本提示和日志脱敏要写进 active plan。
- P2：SwiftUI 阅读交互需要 spike 先行。Text 选择、AttributedString 高亮、TextKit / UIKit / AppKit bridge、LazyVStack 长文本渲染、VoiceOver 和 Dynamic Type 都不应在 MVP 方案里凭空假设可行。
- P2：测试落点不够具体。需要先失败测试覆盖 Core segmentation contract、Data repository / migration、dictionary lookup normalization、source anchor stability、UI presentation model、TTS reading source key 和 import failure recovery。

### 四维切片

- 并发 / 性能边界：导入、分段 / 分句、词典索引、长文本渲染和 TTS 生成都必须异步、可取消、幂等；大文件先做 pre-read size gate，不能读入后再决定拒绝。
- 异常边界：文件不存在、无权限、编码失败、空内容、超长内容、重复导入、词典字段缺失、AI Provider 未配置、TTS requires retest、媒体 artifact 写入失败都要有稳定错误分类和用户可恢复路径。
- 状态同步：ReadingDocument 是主数据；reading structure、tokenization、lookup result、当前选择、inspector 展开状态是派生或 UI 状态；阅读位置是否 device-scoped 必须先定，不得混入 language space 主模型。
- 数据一致性：source anchor 不能只靠 sentence index；至少要保存 document id、content revision / structure version、sentence id、character range、source text hash。删除 ReadingDocument 时必须定义 anchors、memory、practice、TTS artifact 和导出行为。

## 2. 与前次调研的关系

前次 VMark 调研得出的核心学习闭环是：

1. 导入或粘贴文本。
2. 阅读并查询未知词。
3. 保存词、短语、句子和来源上下文。
4. 朗读词句。
5. 进入复习。
6. 写作并使用用户自配 API Key 批改。

这条闭环与 LangoTrace 当前路线高度一致。差异在于：

- VMark 需要先解决是否重写为 SwiftUI 的问题。
- LangoTrace 已经是 SwiftUI Multiplatform，不需要重选技术路线。
- VMark 的优势是复杂 Markdown 编辑器。
- LangoTrace 的优势是语言空间、AI/TTS/练习/本地数据已经围绕语言学习建立。

因此，阅读模块更适合成为 LangoTrace 的长期功能，而不是继续在 VMark 上转型。

## 2.1 VMark 深度调研结论

VMark 不是可直接迁移的阅读学习模块。它是 Tauri + React + Rust 的 plain-text workspace，当前核心是 Markdown / YAML / JSON / TOML / Mermaid / SVG / HTML / code 文件的打开、编辑、预览、导出、AI Genie 和 MCP 协作。其许可证是 ISC，许可证本身相对友好；但 LangoTrace 是 SwiftUI / GRDB 原生 App，复用价值主要是架构思想和行为边界，不是复制实现。

### 2.1.1 可借鉴实现

| VMark 实现 | 证据路径 | 对 LangoTrace 阅读功能的启发 |
|---|---|---|
| 格式注册表 | `src/lib/formats/types.ts`、`src/lib/formats/registry.ts` | 阅读导入不要写成单个 `if ext == md` 分支；应设计 `ReadingImportAdapter` / `ReadingFormatRegistry`，第一阶段只注册 pasted text、txt、md，后续 EPUB / PDF / HTML 作为独立 adapter。 |
| 大文件打开管线 | `dev-docs/large-file-open-pipeline.md`、`src/services/navigation/largeFileRouting.ts`、`src/utils/fileSizeThresholds.ts` | 导入前先用 metadata 判断大小和类型；按 small / large / huge / refused 分流；长文本进入纯阅读 / source-like 模式，不强行构建昂贵富文本树。 |
| 文档作为状态单元 | `dev-docs/decisions/ADR-009-document-as-unit-of-state.md`、`src/stores/documentStore/document.ts` | LangoTrace 应把 `ReadingDocument` 当作阅读状态单元，拥有 content revision、dirty/import status、structure version、progress，而不是把所有阅读状态塞进 UI view model。 |
| workspace facade | `dev-docs/decisions/ADR-008-workspace-as-single-facade.md` | 阅读资料库需要一个稳定 facade / store，UI 不应直接访问多个 Repository；iPhone、iPad、macOS 共享 action seam。 |
| CommandBus 单意图路径 | `dev-docs/decisions/ADR-012-command-bus-as-single-intent-path.md`、`src/services/commands/CommandBus.ts` | Mac 菜单、toolbar、快捷键、context menu、inspector 操作应汇聚到 reading actions；不要每个平台各写一套导入、查词、保存、朗读逻辑。 |
| service tier 分层 | `dev-docs/decisions/ADR-013-service-tier-as-cross-cutting-seam.md` | LangoTrace 已有 Core / Data / AI / Speech / UI package 边界；阅读应继续用 Core contract、Data repository、UI presentation store、AI explicit service、Speech playback coordinator 分层。 |
| Content Search | `src/components/ContentSearch/` | 阅读资料库搜索可参考“结果分组、命中高亮、键盘导航、打开并定位”的交互，但底层应使用 SQLite FTS5，而不是扫描文件系统。 |
| AI Genie 上下文抽取 | `src/services/editor/extractContext.ts`、`src/hooks/useGenieInvocation.ts` | AI 解释不应默认发送全文；应支持 selection + limited surrounding context，并把上下文半径、内容类型和 Provider 显式披露。 |
| CJK formatting / IME 防护 | `src/lib/cjkFormatter/`、`src/hooks/useViewShortcuts.ts` | 阅读选词和快捷键必须考虑 CJK、IME composition 和多语言文本，不要只按英文空格分词。 |

### 2.1.2 不应照搬

- 不照搬 Tauri / React / Zustand / CodeMirror / ProseMirror 技术栈。LangoTrace 的长期路线是 SwiftUI Multiplatform + GRDB。
- 不照搬 VMark 的“文件系统就是资料库”心智。LangoTrace 的阅读资料必须归属 `LanguageSpace`，并进入 SQLite 主数据、导出和删除边界。
- 不照搬 CLI-based AI provider routing。LangoTrace 已决定 Provider credentials 进入 Keychain，AI 请求经过 Provider / Prompt / privacy 边界。
- 不把 Markdown WYSIWYG 编辑器当作阅读器目标。LangoTrace 第一阶段需要稳定可选词、可高亮、可朗读、可沉淀的阅读视图，不需要完整 Markdown 编辑体验。
- 不复制 VMark 代码。即使 ISC 允许较宽松复用，LangoTrace 当前闭源商业计划仍应以重新实现为主，避免引入跨栈依赖和维护负担。

### 2.1.3 VMark 映射为 LangoTrace 设计原则

1. 导入前先分类：文件大小、格式、编码、目标语言空间和版权提示在写入前完成。
2. 文档是主状态单元：ReadingDocument 不是 Entry，也不是 LearningMaterial 的字段。
3. 格式适配可扩展：txt/md/pasted text 是 MVP；EPUB/PDF/HTML 后续作为 adapter 扩展。
4. 大文本不走富文本编辑器：阅读视图按 section / paragraph / sentence 懒加载，必要时降级为 plain reader。
5. 用户意图单路径：导入、查词、保存到记忆、朗读、进入练习必须通过 shared action seam。
6. AI 只处理用户选择的范围：selection / sentence / paragraph + limited context，不默认全文。
7. 长期数据归 GRDB：阅读内容、进度、词状态、source anchor 进入 repository；高亮、当前选择、面板状态是 UI 派生状态。

## 3. 当前 LangoTrace 基础盘点

### 3.1 已具备的基础

| 能力 | 当前状态 | 对完整阅读模块的意义 |
|---|---|---|
| SwiftUI Multiplatform | 已采用 iPhone / iPad / macOS 三端路线 | 可原生设计阅读、查词、资料库和 Mac 导入体验 |
| Language Space | 已作为核心模型 | 阅读资料、词典、词状态、复习队列可按目标语言隔离 |
| SQLite / GRDB | 已作为长期主存储 | 适合承载阅读文档、词典、词状态、阅读进度和复习数据 |
| 本地优先 | ADR-005 已接受 | 阅读材料、词典和学习数据默认本地保存 |
| 用户自带 Provider | 已有 AI Provider 和 TTS Provider 基础 | AI 解释、翻译、TTS 可沿用已有 Provider 边界 |
| Keychain | 已保存 API Key | 阅读相关 Provider 不需要另建密钥体系 |
| LearningMaterial | 已有分句学习材料 | AI 生成文本可作为阅读资料来源之一 |
| 逐句 TTS | 已有 TTS 生成、cache、播放 coordinator | 阅读句子和段落朗读可复用或扩展 |
| Practice session | 已有单句跟读录音闭环 | 阅读中保存的句子可进入跟读练习 |
| MemoryItem | 已有记忆雏形 | 阅读词句可沉淀到记忆模块 |

### 3.2 仍缺失的核心能力

完整阅读模块至少还缺：

- `ReadingDocument` 主数据。
- 阅读资料库列表、分组、搜索和删除。
- 阅读进度和位置恢复。
- 文本导入、粘贴导入、文件导入。
- 长文本分段、分句、分页或虚拟化。
- 点词 / 选词 UI。
- 本地词典模型。
- 词典导入和字段映射。
- 词形归一、大小写、重音、假名 / 汉字、CJK / RTL 处理。
- 词状态和高亮。
- 句子挖掘。
- 阅读统计。
- 阅读材料导出、备份和删除策略。
- 阅读数据与未来同步的冲突边界。

## 4. 完整阅读能力的产品范围

### 4.1 应包含的完整体验

完整阅读功能应覆盖以下体验：

1. 资料管理  
   用户可以创建、导入、删除、搜索阅读资料。每份资料归属一个语言空间。

2. 阅读视图  
   支持段落 / 句子级阅读、阅读位置恢复、字体和行距、目标语言文本优先展示。

3. 点词 / 选词  
   用户可以点击或选择词、短语、句子，查看本地词典结果、AI 解释、翻译和例句。

4. 词状态  
   词或短语可以标记为 new / seen / learning / known / ignored，并影响阅读高亮。

5. 句子挖掘  
   用户可以把词、短语、整句和上下文保存到记忆，后续进入复习或跟读。

6. TTS 阅读  
   支持单词、句子、段落朗读。系统 TTS 或用户配置的 TTS Provider 都可以作为能力来源。

7. 阅读统计  
   记录阅读进度、已读字数 / 词数、生词数量、已保存词句和材料完成度。

8. 三端适配  
   iPhone 用于碎片阅读和快速查词；iPad 用于精读和侧栏词典；macOS 用于批量导入、整理和长文本阅读。

### 4.2 不等于完整阅读器

“完整阅读能力”不意味着第一版要成为 Readest 级电子书阅读器。

第一阶段不建议直接做：

- EPUB 复杂排版。
- PDF 版面还原。
- 网页抓取和正文抽取。
- 书库封面墙。
- 第三方云书架。
- 视频 / 字幕播放器。
- 官方内容商店。

这些可以进入后续阶段，但不应阻塞核心阅读学习闭环。

## 5. 推荐产品信息架构

当前 iPhone 顶级 Tab 是：

```text
记录 / 练习 / 记忆
```

如果要扩展完整阅读体验，有三种方案。

### 方案 A：阅读作为“记忆”或“记录”的二级入口

优点：

- 对当前导航冲击最小。
- 不改变产品北极星。
- 适合先做原型。

缺点：

- 阅读资料库不够显性。
- 如果阅读成为高频主线，入口会偏深。

适合：阅读模块早期验证。

### 方案 B：把 iPhone Tab 改为“记录 / 阅读 / 练习 / 记忆”

优点：

- 阅读能力被明确提升为主线。
- 用户能理解 LangoTrace 不只处理生活记录，也能学习外部文本。

缺点：

- 改变现有导航决策。
- 需要更新 `docs/spec/002-navigation-and-routing.md`。
- 需要重新平衡首页主动作。

适合：阅读模块被确认为 P0/P1 后。

### 方案 C：保留三 Tab，新增全局资料库入口

优点：

- iPhone 保持简洁。
- iPad / macOS 可以用 Sidebar / Library 承载阅读资料。
- 更适合三端差异化。

缺点：

- iPhone 上阅读仍不如 Tab 显性。
- 需要设计稳定、可发现的资料库入口。

推荐：产品定位上接受方案 B 作为长期 IA 目标；实施上先用方案 C 或 A 完成 spike 和 MVP，待阅读资料库、点词、词典、TTS、Memory / Practice 回流形成最小闭环后，再通过独立导航任务把 iPhone Tab 调整为 `记录 / 阅读 / 练习 / 记忆`。

复审补充：

- 长期一级 Tab 目标建议调整为 `记录 / 阅读 / 练习 / 记忆`。这比把阅读藏在“记录”或“记忆”里更符合“一切语言学习”的目标，也更容易让用户理解语迹既支持自我表达输入，也支持外部文本输入。
- MVP 不应在同一个任务里同时做阅读基础设施和 `PhoneRootTab` 变更。当前代码和规范都把 iPhone 一级入口固定为 `记录 / 练习 / 记忆`；新增 Tab 会牵动 `PhoneRootTab`、本地化、页面清单、导航规范和 iOS 验证，建议拆成独立导航任务。
- iPhone spike / MVP 临时入口可以放在 `记录`页或顶部轻量入口中的“导入阅读材料”，以及 `记忆`页中的“阅读材料中的词句”聚合入口。临时入口用于降低首轮风险，不代表长期 IA。
- iPad / macOS 首版可以更显性：iPad 左侧工作台 route 增加资料库入口，macOS Sidebar / toolbar 增加导入和资料库。平台显性程度可以不同，但写入路径必须共享。
- 阅读 MVP 闭环验证后，应创建导航变更 active plan，更新 `docs/product-main-reference.md`、`docs/spec/002-navigation-and-routing.md`、`docs/platform-page-inventory.md`、相关 UI tests，并评估是否需要 ADR。

### 5.1 Slogan 与定位边界

主 slogan 建议保留：

```text
用生活记录学习语言。
Learn languages from your life.
```

原因：

- 它足够短、清晰、有差异化，能把语迹和传统阅读器、背单词 App、AI 聊天工具区分开。
- slogan 不等于功能清单；不需要把阅读、跟读、听写、回译、词典和复习都写进去。
- “生活记录”仍然是语迹最独特的入口和品牌锚点，不能为了功能完整性而被稀释。

但一句话定位和产品信息架构应扩展：

```text
语迹是一款把你的生活记录和阅读材料变成外语学习闭环的本地优先 App。
```

这形成两个层次：

- 品牌表达：用生活记录学习语言。
- 产品能力：生活记录和阅读材料都能进入学习、练习和记忆闭环。

### 5.2 为什么阅读有必要成为一级学习场景

阅读不只是一个资料来源，而是语言学习中最高频、最稳定的输入场景之一。对于“适合一切语言学习”的目标，完整阅读能力有必要进入一级产品架构。

必要性：

- 语言学习需要输入和输出并行。`记录`偏输出和自我表达，`阅读`偏输入和理解，两者共同构成材料来源。
- 用户不一定每天有生活记录灵感，但可以每天读一点目标语言材料；阅读能提高产品日常打开频率。
- 阅读天然连接点词、词典、TTS、句子收藏、跟读和复习，是 Memory 和 Practice 的高质量来源。
- 如果阅读只藏在二级入口，用户会误以为语迹只能处理自己写的内容，而不是一个完整语言学习材料系统。

可行性：

- 现有 Language Space 可以隔离阅读资料、词典、词状态和复习队列。
- 现有 GRDB 路线适合承载 ReadingDocument、Dictionary、LexemeState 和 SourceAnchor。
- 现有 TTS、Practice、Memory candidate 基础可以接阅读句子回流。
- 风险主要在 SwiftUI 阅读交互、长文本性能、数据模型和导入复杂度；这些可以通过 spike 和分阶段实现控制。

边界：

- 阅读是语言学习阅读，不是通用电子书 App。
- 阅读资料必须归属语言空间。
- 首版不做书城、社交阅读、完整 EPUB/PDF 排版还原、网页抓取和第三方云书架。
- AI 解释显式触发，不自动上传全文。

## 6. 数据模型建议

以下模型是 research 级建议，不是已批准 schema。正式写入 SQLite / GRDB 前必须创建 active plan，列出 migration id、唯一约束、外键、删除语义、导出 / 备份 / 同步边界和迁移测试。

### 6.1 ReadingDocument

```text
reading_documents
  id
  space_id
  title
  source_kind          -- pastedText / importedText / fileImport / generatedMaterial / writingDraft
  source_entry_id      -- nullable
  source_material_id   -- nullable
  original_filename    -- nullable
  body
  body_hash
  target_language
  created_at
  updated_at
  soft_deleted_at
```

复审修订建议：

```text
reading_documents
  id
  space_id
  title
  source_kind            -- pastedText / importedTextFile / importedMarkdown / generatedMaterial
  source_entry_id        -- nullable
  source_material_id     -- nullable
  import_artifact_id     -- nullable, future attachment/import artifact
  original_filename      -- nullable
  original_file_extension -- nullable
  original_byte_size     -- nullable
  body_storage_kind      -- inlineText / managedFile, MVP can only allow inlineText
  body
  body_hash
  content_revision
  structure_version
  target_language_code
  import_status          -- ready / failed / needsReview
  created_at
  updated_at
  soft_deleted_at
```

MVP 可以把小文本 `body` 直接放入 SQLite，但必须设置导入上限。超过上限时应拒绝或进入后续 managed file 方案，不要悄悄把超长文件读入 SwiftUI 状态。

### 6.2 ReadingStructure

```text
reading_sections
  id
  document_id
  section_index
  title
  text_hash

reading_sentences
  id
  document_id
  section_id
  sentence_index
  text
  text_hash
  character_start
  character_end
```

token 不建议第一阶段持久化为主数据。tokenization 应作为可重建派生结果。

复审修订建议：

- `reading_sentences` 应保存 `structure_version` 或从 document 当前 revision 派生；source anchor 必须能判断自身是否 stale。
- `sentence_index` 不能作为长期唯一定位。建议 `id` 为稳定 UUID，另存 `text_hash`、`character_start`、`character_end` 和 `structure_version`。
- 长文本分段 / 分句应由 `TextSegmentationService` 异步执行；导入成功不等于 structure 全部完成。UI 可先展示段落文本，再逐步补句子级能力。
- token / word boundary / highlight spans 第一阶段作为可重建派生缓存；如果持久化，必须标记为 derived index，并定义失效规则。

### 6.3 ReadingProgress

```text
reading_positions
  document_id
  device_scope
  sentence_index
  character_offset
  updated_at

reading_progress
  document_id
  completed_sentence_count
  total_sentence_count
  last_read_at
```

复审修订建议：

- `reading_positions.device_scope` 需要明确取值。第一阶段建议本机 scope，不进入未来同步主数据；如果后续要跨设备恢复阅读位置，应另做 sync-aware device state。
- progress 应区分用户明确到达的位置和系统推算完成度。不要只因渲染到某段就标记已读。
- 位置恢复应以 `document_id + content_revision + sentence_id / character_offset` 为依据；revision 不匹配时进入 best-effort restore，不直接跳到旧 index。

### 6.4 Dictionary

```text
dictionary_collections
  id
  space_id
  title
  source_kind          -- csv / tsv / json / mdx / stardict
  target_language
  created_at

dictionary_entries
  id
  collection_id
  headword
  normalized_headword
  reading
  part_of_speech
  definition
  example
  tags_json
```

复审修订建议：

```text
dictionary_imports
  id
  space_id
  source_kind            -- csv / tsv / json
  original_filename
  original_byte_size
  field_mapping_json
  import_status          -- importing / ready / failed
  imported_entry_count
  failed_row_count
  created_at
  completed_at
```

- `dictionary_entries` 需要 `space_id` 冗余索引或通过 collection join 查询；100k 词典条目查询不能依赖无索引 join。
- `normalized_headword`、`language_code`、`collection_id` 至少要有组合索引。
- CSV/TSV/JSON 导入必须有字段映射、预览、行级错误摘要和回滚策略；失败导入不得留下半成品 ready collection。
- 不内置版权词典。用户导入时要提示词典版权由用户负责；App 只提供本地解析和索引。

### 6.5 LexemeState

```text
lexeme_states
  id
  space_id
  normalized_form
  display_form
  language_code
  state               -- new / seen / learning / known / ignored
  source_count
  last_seen_at
```

复审修订建议：

- `normalized_form` 不能只是一套全局 lowercased 字符串。至少要保存 `normalization_strategy` 或 `language_code`，避免英语词形、德语大小写、日语假名 / 汉字、中文分词和 RTL 文本混用。
- MVP 可以先支持用户手动选词 / 短语后的状态记录，不承诺自动全文 token 状态覆盖。
- `source_count` 是派生统计，不应成为不可修复主事实；可从 anchors / occurrences 重建，或标记为 snapshot。
- `ignored` 与 `known` 的语义要区分：ignored 不参与高亮和复习，known 可以参与统计和阅读熟悉度。

### 6.6 Source Anchors

阅读中保存的词句必须能回到来源：

```text
memory_source_anchors
  id
  memory_item_id
  source_kind         -- entry / learningMaterial / readingDocument
  source_id
  sentence_id
  character_start
  character_end
  source_text_hash
```

这比把来源句子复制到 note 更稳：即使后续 UI 展示复制文本，也应保留稳定 source anchor。

复审修订建议：

```text
memory_source_anchors
  id
  memory_item_id
  source_kind             -- entry / learningMaterial / readingDocument
  source_id
  source_revision         -- entry body hash / material analysis hash / reading content revision
  sentence_id
  character_start
  character_end
  selected_text_hash
  context_text_hash
  created_at
```

- 现有 `MemoryItem` 仍是候选 / mock 形态，真实 Memory 主数据尚未完整落地。阅读 MVP 前要先明确是写入 `memory_candidates`，还是新增正式 `memory_items`。
- Anchor 应允许来源 stale。来源文本修改或重新分段后，不应删除用户记忆；UI 应显示“来源已变化，可查看保存时摘录”。
- 为了保证可恢复导出，Memory 可保存短摘录 snapshot，但 snapshot 不能替代 anchor。

### 6.7 Reading Import Adapter

参考 VMark format registry，建议在 Core / Data 之间先定义导入适配契约：

```text
ReadingImportAdapter
  id
  supported_extensions
  preflight(url or text) -> size / format / warnings
  parse(input) -> ReadingImportResult

ReadingImportResult
  title
  plain_text
  source_kind
  detected_language_hint
  original_metadata
  warnings
```

MVP 只需要：

- pasted plain text。
- `.txt` UTF-8 / UTF-16 best-effort。
- `.md` 去除明显 front matter 后按纯文本 / Markdown block 处理。

暂不做：

- HTML sanitizer。
- EPUB spine / chapter。
- PDF text extraction。
- 网页正文抽取。

### 6.8 Reading Operation Summary

阅读导入和结构化应有非敏感 operation 摘要，类似 `learning_material_operations`：

```text
reading_import_operations
  id
  operation_id
  space_id
  document_id
  source_kind
  status               -- started / succeeded / failed / cancelled
  failure_category
  byte_size_bucket
  character_count_bucket
  duration_ms
  created_at
  completed_at
```

不得记录完整原文、文件内容、词典内容、AI 请求体、响应体或密钥。诊断日志只记录大小分桶、格式、失败分类和耗时。

## 7. 主要难点

### 7.1 SwiftUI 阅读交互

完整阅读体验需要高亮、点词、长按选择、滚动定位、阅读进度、上下文菜单和可访问性。SwiftUI 原生 `Text` 并不直接提供完整交互阅读器。

可选路线：

- 短中篇文本：SwiftUI token / sentence view。
- 长文本：`LazyVStack` 分段 / 分句渲染。
- 高级选择：TextKit / UIKit / AppKit bridge。
- 后续电子书：单独阅读引擎，不要塞进 Entry detail。

风险：如果第一版就承诺电子书级体验，可能被迫自研复杂阅读器。

复审补充：这里必须先做 spike。至少比较三条路线：

1. SwiftUI `LazyVStack` + 自定义 sentence/token button：最可控，适合 MVP，但原生文本选择弱。
2. `TextEditor` / `UITextView` / `NSTextView` bridge：选择能力强，但高亮、SwiftUI 状态同步和三端差异复杂。
3. AttributedString + TextKit 2 bridge：长期潜力大，但实现成本高，不能未经验证直接进入 MVP。

Spike 验收不是“能显示文本”，而是 iPhone 可手动选词、iPad 可并列 inspector、macOS 可键盘选择并查词、10k 字滚动不卡、Dynamic Type 不重叠、VoiceOver 有可理解元素。

### 7.2 多语言分词

英语、法语、德语可以先用 Unicode word boundary + normalization。日语、中文、韩语和混合文本更复杂。

建议：

- v1 支持手动选择词 / 短语查询，降低自动分词失败影响。
- 建立 `TextSegmentationService` 协议。
- 日语分词、词形还原和 furigana 放入后续 language pack。

### 7.3 本地词典导入

CSV/TSV/JSON 字段映射可控，但 MDX、StarDict、Lingvo DSL 会增加：

- parser 复杂度。
- 索引性能要求。
- 许可证风险。
- 词典内容版权风险。
- 文件体积和导入失败恢复。

建议：

- 第一阶段只做 CSV/TSV/JSON。
- 不内置版权词典。
- 高级格式在独立 spike 后再决定。

### 7.4 与现有 Entry / LearningMaterial 的关系

完整阅读模块不能把所有文本都伪装成 Entry。

边界：

- Entry 是用户生活记录或写作记录。
- LearningMaterial 是 AI 对 Entry 的学习材料派生。
- ReadingDocument 是可阅读资料，包括外部文本和派生文本。
- MemoryItem 是长期记忆对象，可来源于三者。

如果混淆这四类对象，后续导出、同步、删除和统计会变得不可维护。

### 7.5 AI 请求成本和隐私

阅读容易诱发频繁 AI 查询。必须遵守本地优先和用户自带 Provider：

- 本地词典优先。
- AI 解释显式触发。
- 不自动发送整篇阅读材料。
- 不在诊断日志中保存原文、请求体、响应体、API Key 或 Authorization header。
- 长文本总结、全文翻译必须有请求预览和成本提示。

### 7.6 性能

高风险点：

- 100k+ 词典条目查询。
- 1 万字以上文本渲染。
- 词状态高亮导致正文频繁重绘。
- 阅读位置恢复。
- TTS 音频缓存增长。

要求：

- normalized index。
- 分段 / 分句懒加载。
- token 派生缓存可重建。
- TTS 音频沿用 media artifact policy，默认 local-only。

复审补充：性能策略应借鉴 VMark 的 pre-read gate。

建议第一阶段设置保守阈值，具体数值由 spike 校准：

- pasted text：超过阈值先提示会作为长文本导入，允许取消。
- 文件导入：先读取 metadata，不读内容；超过 hard limit 直接拒绝或提示后续版本支持。
- structure generation：按 document revision 异步生成，重复触发应合并或取消旧任务。
- UI 渲染：按 paragraph / sentence chunk 懒加载，不在单个 SwiftUI body 中构建完整 1 万字 token tree。
- 词典查询：normalized index + prefix / exact lookup；全文模糊搜索放到后续 FTS 任务。

### 7.7 版权、导出和同步

阅读资料和词典导入新增了版权和数据可迁移问题：

- 用户导入的书籍、文章、词典可能受版权保护。App 不应内置版权内容，也不应提供绕过版权的抓取或分享能力。
- 普通导出可以包含用户导入的阅读文本和词句记忆，但必须明确这只是用户本地数据导出，不代表 App 获得内容分发权。
- 可恢复备份可包含 reading_documents、structure、lexeme state、dictionary metadata 和用户导入词典，但 TTS 音频仍默认 excluded，除非后续备份方案单独允许。
- 同步第一阶段不做。后续同步应区分 reading document 主数据、dictionary import 主数据、tokenization 派生缓存、TTS 音频缓存和设备级 reading position。

## 8. 风险评估

| 风险 | 等级 | 说明 | 缓解 |
|---|---:|---|---|
| 范围膨胀 | 高 | 完整阅读可能扩展到电子书、网页、字幕、书库 | 分阶段：纯文本 -> 文件 -> EPUB/PDF |
| 导航冲突 | 中高 | 阅读若成为主线，现有三 Tab 需调整 | 先用资料库入口，验证频率后再改 Tab |
| SwiftUI 阅读器复杂 | 高 | 点词、高亮、长文本选择都需原型 | 先 spike，再决定 TextKit bridge |
| 多语言分词质量 | 高 | 日语 / 中文 / RTL 自动分词难 | v1 手动选择优先，分词服务可替换 |
| 词典版权 | 高 | 内置词典和用户导入都可能涉及版权 | 不内置版权词典，导入提示用户责任 |
| 数据模型缠绕 | 中高 | Entry、ReadingDocument、Memory、Practice 容易混淆 | source anchor 和 owner 类型必须先设计 |
| AI 成本失控 | 中高 | 高频点词 AI 解释可能产生高成本 | 本地词典优先，AI 显式触发 |
| 同步边界复杂 | 中 | 阅读进度、词状态、音频缓存冲突 | 主数据、派生数据、缓存分层 |

## 9. 前置要求

正式进入开发前，需要：

1. 任务方案  
   按 `docs/plans/README.md` 创建 `docs/plans/active/YYYY-MM-DD-research-reading-spike.md` 或 `docs/plans/active/YYYY-MM-DD-feature-reading-mvp.md` 并经确认。若尚未完成 SwiftUI 阅读交互和长文本性能 spike，推荐先建 research spike，不直接建 feature plan。

2. 权威文档更新  
   由于定位再审已经建议把阅读作为一级学习场景，后续进入 feature plan 或导航 plan 时需要更新：
   - `docs/product-main-reference.md`
   - `docs/spec/002-navigation-and-routing.md`
   - `docs/spec/004-swiftui-architecture.md`
   - `docs/spec/007-data-storage-migration-export-and-attachments.md`
   - 可新增 `docs/spec/012-reading-dictionary-and-lexeme.md`
   - `docs/platform-page-inventory.md`
   - `docs/spec/009-testing-and-verification.md` 中的阅读手动验证入口

   如果只是进入 research spike，可暂不立即修改 `PhoneRootTab` 和导航规范强制规则，但 active plan 必须写明“产品方向已倾向四 Tab，当前任务只验证阅读闭环和技术可行性”。

3. Spike  
   至少验证：
   - iPhone 点词和 bottom sheet。
   - iPad 三栏阅读 + 词典 Inspector。
   - macOS 资料库 + 阅读 + Inspector。
   - 10k 字文本渲染。
   - 100k 词典查询。
   - CJK / 日语 / RTL 手动选词。
   - `.txt` / `.md` 导入前 size preflight、编码失败、空文件和超限文件。
   - source anchor 在 content revision 变化后的 stale 展示。

4. 许可证审查  
   VocabSieve、LinguaCafe、Readest、Anki 等只能研究产品结构。GPL / AGPL 项目不得直接复制代码进闭源商业实现。VMark 当前 `LICENSE` 为 ISC，可研究并在必要时按许可证复用小型思想或测试策略，但不建议跨栈复制实现。

5. 数据边界审查  
   明确阅读文档、词典、词状态、记忆、复习、TTS 音频和导出的边界。

6. 开发备忘录
   阅读会影响长期数据、导出、同步、Memory 和练习来源模型。创建 active plan 前应检查 `docs/architecture/notes/`，并考虑新增阅读架构备忘录，记录 EPUB/PDF、词典高级格式、同步和 source anchor 的后续风险。

7. 自审核
   active plan 进入实现前必须按 `docs/plans/plan-review-protocol.md` 完成严格自审核，尤其覆盖并发 / 性能、异常边界、状态同步、数据一致性、TDD 和文档影响检查。

## 10. 推荐 MVP

复审后建议把路线拆成三个层级：`Spike`、`MVP`、`Post-MVP`。不要把所有阅读能力塞进第一份 feature plan。

### 10.0 先做 Spike

Spike 只验证，不承诺真实主数据完整上线：

- 三端阅读布局原型：iPhone 单栏 + bottom sheet，iPad 正文 + inspector，macOS 资料库 + inspector。
- SwiftUI / TextKit 点词选择技术路线。
- 10k 字文本渲染和滚动。
- 导入前 size preflight 和超限策略。
- `.txt` / `.md` 导入解析到纯文本 / paragraphs。
- 100k dictionary exact lookup benchmark。
- CJK / 日语 / RTL 手动选择可用性。
- Source anchor revision mismatch 的 UI 表达。

Spike 产物应放入 `docs/reference/research/spikes/` 或 active research plan 的 evidence 段，不直接写入产品事实源。

### 10.1 MVP 做

- 阅读资料库。
- 粘贴文本创建 ReadingDocument。
- `.txt` / `.md` 文件导入。
- 分段 / 分句阅读。
- 阅读位置恢复。
- 手动选词 / 短语查询。
- CSV/TSV/JSON 词典导入。
- 本地词典查询。
- 词状态：new / seen / learning / known / ignored。
- 保存词、短语、句子到 Memory candidate 或正式 Memory，取决于 Memory 主数据方案是否已落地。
- 单句 TTS。
- 从阅读句子进入跟读练习。
- Reading import operation 摘要和非敏感诊断。
- Source anchor：至少支持 readingDocument 来源，并能在 revision 变化时标记 stale。
- iPhone MVP 可先通过二级入口降低风险；长期目标仍是新增阅读一级 Tab。

### 10.2 MVP 暂缓

- EPUB。
- PDF。
- 网页抓取。
- MDX / StarDict / Lingvo DSL。
- 自动日语分词。
- 全文 AI 翻译。
- 全文 AI 总结。
- 复杂 SRS / FSRS。
- 阅读材料同步。
- 视频 / 字幕阅读。
- 自动全文 token 高亮。
- 自动把全文词汇加入 lexeme state。
- 阅读资料跨设备位置同步。
- 词典内容默认导出或同步。

### 10.3 不做

- 官方课程库。
- 内置版权词典。
- 社交阅读。
- 排行榜。
- 教师课堂。
- 自动把整篇材料发送 AI。
- 绕过版权的网页抓取、付费书籍解析或内容分享。

### 10.4 Post-MVP 路线候选

只有在 MVP 验证通过后再评估：

1. EPUB adapter：章节、目录、spine、文本抽取、阅读位置。
2. HTML / web clip adapter：sanitizer、正文抽取、来源 URL、版权提示。
3. PDF text extraction：只做文本抽取，不做版面还原。
4. 语言包：日语分词、词形还原、furigana、RTL 排版。
5. FTS：阅读资料库全文搜索、dictionary fuzzy lookup。
6. 复习调度：从 lexeme state / Memory 进入 SRS。
7. 同步：阅读主数据、词状态、词典 metadata、位置和冲突策略。

## 11. 推荐技术方案

新增能力应遵守现有依赖方向：

```text
App Shell -> UI -> Core
App Shell -> Data / AI / Speech / Sync
Data -> Core
AI -> Core
Speech -> Core
Sync -> Core
```

建议新增：

- Core：`ReadingDocument`、`ReadingSentence`、`ReadingProgress`、`DictionaryEntry`、`LexemeState`、`ReadingSourceAnchor`、`TextSegmentationService`。
- Data：`GRDBReadingRepository`、`GRDBDictionaryRepository`、migrations、normalized indexes。
- UI：`ReadingLibraryStore`、`ReadingDocumentStore`、`ReadingView`、`DictionaryLookupPanel`、`ReadingImportView`。
- AI：`ContextualExplanationService`、`ReadingAIRequestPreview`，只处理显式请求。
- Speech：复用或扩展 `SentenceAudioPlaybackCoordinator` 支持 `readingDocument` source。

复审修订建议：

- Core 还应新增：`ReadingImportAdapter` contract、`ReadingImportPreflightResult`、`ReadingImportFailureCategory`、`ReadingSelection`、`LexemeNormalizationStrategy`。
- Data 还应新增：`reading_import_operations` 或等价 operation summary、dictionary import transaction、migration fixture、FTS 后续扩展点。
- UI store 应是 `@MainActor` presentation store，类似 `LearningContentStore`，但不能直接持有 SQLite handle；所有写入经 repository/action seam。
- AI service 第一阶段只做 selection explanation，不做全文总结和全文翻译。请求输入必须包含 source kind、selection、limited context、target language、native language、Prompt id/version 和 consent boundary。
- Speech 不应直接复用 `learningMaterial` 的 TTS sentence source。需要在 Core 中扩展 `TTSSentenceSource` 或新增 reading source，保证 media artifact owner、derivation key、source id 和 sentence id 不与 Entry/LearningMaterial 混淆。
- App assembly 需要注入 reading repository、dictionary repository、reading actions、TTS action seam；iPhone/iPad/macOS 只做承载差异。

不建议：

- UI 直接查 SQLite。
- UI 直接调用 AI Provider。
- token 全量作为主数据持久化。
- 第一版引入完整电子书引擎。
- 复制 GPL / AGPL 项目实现。
- 复制 VMark 的 Tauri file workspace 模型。
- 把 reading body、dictionary entries 或 selected text 写入诊断日志。
- 把 tokenization / highlight spans 当作同步主数据。

### 11.1 推荐实施拆分

后续 active plan 不建议一份计划覆盖全部。推荐拆为：

1. `research-reading-interaction-spike`：三端阅读交互、TextKit / SwiftUI 技术路线、性能阈值。
2. `feature-reading-document-infrastructure`：Core model、GRDB schema、repository、import operation、txt/md/paste 导入。
3. `feature-reading-library-ui`：三端资料库入口、ReadingDocumentStore、阅读位置恢复。
4. `feature-reading-dictionary-lookup`：dictionary import、normalized lookup、lookup panel、lexeme state。
5. `feature-reading-memory-practice-tts`：source anchor、Memory / Practice 回流、reading sentence TTS。
6. 后续再评估 AI explanation、FTS、EPUB/PDF、同步。

### 11.2 TDD 落点

正式 feature plan 应先写失败测试：

- Core：`ReadingImportPreflightTests`、`TextSegmentationServiceContractTests`、`LexemeNormalizationTests`、`ReadingSourceAnchorTests`。
- Data：`AppDatabaseReadingMigrationTests`、`GRDBReadingRepositoryTests`、`GRDBDictionaryRepositoryTests`、`ReadingImportOperationTests`。
- UI：`ReadingLibraryStoreTests`、`ReadingDocumentPresentationTests`、`ReadingSelectionStateTests`、`ReadingActionSeamTests`。
- AI：`ReadingContextualExplanationServiceTests`，验证 selection-only、context radius、Prompt id/version、隐私字段不进入日志。
- Speech / Core：`SentenceAudioPlaybackReadingSourceTests`，验证 reading source artifact key 与 learning material source 不冲突。

聚焦验证命令应至少包括：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

涉及 AI / TTS 时追加：

```bash
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
```

涉及数据库、三端入口或 App assembly 时运行：

```bash
scripts/verify.sh
```

## 12. 验收标准

阅读模块进入正式路线前，应证明：

- iPhone 上阅读、点词、保存、朗读可以单手完成。
- iPad 上正文和词典 / 解释面板可以并列使用。
- macOS 上资料导入、搜索、查词、保存到记忆有清晰菜单或工具栏路径。
- 10k 字文本滚动稳定。
- 100k 词典条目本地查询可接受。
- 无 AI Provider 时本地阅读和词典仍可用。
- 无 TTS Provider 时 UI 明确提示，不自动请求。
- 用户导出不包含 API Key、完整请求体、响应体或音频缓存，除非进入明确可恢复备份模式。
- 导入超限文件不会让 UI 卡死或半写入主数据。
- malformed dictionary import 事务回滚，ready collection 不包含半成品。
- source anchor 在阅读文本 revision 变化后能显示 stale，而不是静默指向错误文本。
- 当前语言空间切换后，阅读资料库、词典、词状态和进度不会串空间。
- 删除 ReadingDocument 后，Memory / Practice / TTS artifact 的处理路径有明确策略并被测试覆盖。

## 12.1 文档影响检查

如果阅读 MVP 开始实现，至少需要同步检查：

- `docs/product-main-reference.md`：是否把阅读列为一级学习场景，保留主 slogan，并把一句话定位扩展到生活记录和阅读材料双来源。
- `docs/spec/002-navigation-and-routing.md`：新增入口是否仍符合三端导航边界；若新增 iPhone Tab 必须更新强制规则。
- `docs/platform-page-inventory.md`：新增 iPhone/iPad/macOS 阅读资料库、阅读详情、lookup panel。
- `docs/spec/007-data-storage-migration-export-and-attachments.md`：新增 ReadingDocument、Dictionary、LexemeState、SourceAnchor、导出 / 备份 / 同步边界。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：阅读 AI 解释、全文 AI 请求、请求预览和日志边界。
- `docs/spec/011-tts-provider-configuration-and-playback.md`：readingDocument TTS source 和 artifact policy。
- `docs/spec/012-reading-dictionary-and-lexeme.md`：建议新增，作为长期阅读 / 词典 / 词状态规范。
- `docs/review/README.md`：数据库 schema、AI、TTS、三端导航命中专项审查条件，active plan 必须说明是否创建 review round。

## 13. 最终建议

建议把完整阅读能力纳入 LangoTrace 的长期产品路线，并把阅读确认为与记录、练习、记忆并列的一级学习场景。

主 slogan 仍建议保留：

```text
用生活记录学习语言。
Learn languages from your life.
```

不需要为了阅读而改成更长的功能枚举式标语。更合适的做法是：保留 slogan 的差异化表达，在一句话定位、产品主参考和导航架构里补足阅读。

建议长期一句话定位：

```text
语迹是一款把你的生活记录和阅读材料变成外语学习闭环的本地优先 App。
```

建议长期 iPhone 主 Tab：

```text
记录 / 阅读 / 练习 / 记忆
```

短期不要把阅读降级为生活记录详情页的小功能，也不要一步到位做完整电子书阅读器。最稳妥路线是：

1. 先做 research spike，验证 SwiftUI 阅读交互、长文本性能、导入 preflight、词典查询和 source anchor。
2. 建立阅读资料库和纯文本 / Markdown 阅读主数据。
3. 做手动选词、本地词典、词状态和句子收藏。
4. 接入 TTS、Memory、Practice。
5. 阅读 MVP 闭环成立后，单独创建导航任务，把 iPhone Tab 从 `记录 / 练习 / 记忆` 调整为 `记录 / 阅读 / 练习 / 记忆`。
6. 再扩展 AI 解释、文件格式、SRS、语言包、FTS 和同步。

这一路线的核心判断是：阅读作为产品能力应升格，阅读作为工程实现必须分阶段。方向上承认它是一级学习场景；落地上先验证阅读闭环，不让电子书、词典格式、同步和 AI 全文能力拖垮 MVP。

本 research 的结论不能直接授权实现。当前后续入口是 `docs/plans/active/2026-06-01-feature-reading-ai-tts-vertical-slice.md`；该方案把原先建议的 spike 事项提升为含真实 AI / TTS 的窄范围纵向切片，但仍需用户明确确认后才能进入生产代码实现。
