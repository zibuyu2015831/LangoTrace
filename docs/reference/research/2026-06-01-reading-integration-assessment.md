# 完整阅读能力整合调研评估

日期：2026-06-01

状态：Research Result

## 1. 结论摘要

可以在 LangoTrace 上继续开发完整阅读能力，并且这条路线比从 VMark 改造更合理。

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

> LangoTrace 应把完整阅读能力作为一条独立学习主线纳入长期产品，而不是仅作为生活记录的附属功能。但第一阶段必须从“纯文本阅读资料库 + 点词查词 + 词句沉淀”开始，不应直接做完整电子书阅读器。

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

推荐：先采用方案 C，原型期可用方案 A；如果验证后阅读高频，再评估方案 B。

## 6. 数据模型建议

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

## 7. 主要难点

### 7.1 SwiftUI 阅读交互

完整阅读体验需要高亮、点词、长按选择、滚动定位、阅读进度、上下文菜单和可访问性。SwiftUI 原生 `Text` 并不直接提供完整交互阅读器。

可选路线：

- 短中篇文本：SwiftUI token / sentence view。
- 长文本：`LazyVStack` 分段 / 分句渲染。
- 高级选择：TextKit / UIKit / AppKit bridge。
- 后续电子书：单独阅读引擎，不要塞进 Entry detail。

风险：如果第一版就承诺电子书级体验，可能被迫自研复杂阅读器。

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
   按 `docs/plans/README.md` 创建 `docs/plans/active/YYYY-MM-DD-research-or-feature-reading.md` 并经确认。

2. 权威文档更新  
   如果决定把阅读作为完整产品主线，需要更新：
   - `docs/product-main-reference.md`
   - `docs/spec/002-navigation-and-routing.md`
   - `docs/spec/004-swiftui-architecture.md`
   - `docs/spec/007-data-storage-migration-export-and-attachments.md`
   - 可新增 `docs/spec/012-reading-dictionary-and-lexeme.md`

3. Spike  
   至少验证：
   - iPhone 点词和 bottom sheet。
   - iPad 三栏阅读 + 词典 Inspector。
   - macOS 资料库 + 阅读 + Inspector。
   - 10k 字文本渲染。
   - 100k 词典查询。
   - CJK / 日语 / RTL 手动选词。

4. 许可证审查  
   VocabSieve、LinguaCafe、Readest、Anki 等只能研究产品结构。GPL / AGPL 项目不得直接复制代码进闭源商业实现。

5. 数据边界审查  
   明确阅读文档、词典、词状态、记忆、复习、TTS 音频和导出的边界。

## 10. 推荐 MVP

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
- 保存词、短语、句子到 Memory。
- 单句 TTS。
- 从阅读句子进入跟读练习。

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

### 10.3 不做

- 官方课程库。
- 内置版权词典。
- 社交阅读。
- 排行榜。
- 教师课堂。
- 自动把整篇材料发送 AI。

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

不建议：

- UI 直接查 SQLite。
- UI 直接调用 AI Provider。
- token 全量作为主数据持久化。
- 第一版引入完整电子书引擎。
- 复制 GPL / AGPL 项目实现。

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

## 13. 最终建议

建议把完整阅读能力纳入 LangoTrace 的长期产品路线，并作为与“记录 / 练习 / 记忆”并列的重要学习场景评估。

短期不要把它降级为生活记录详情页的小功能，也不要一步到位做完整电子书阅读器。最稳妥路线是：

1. 建立阅读资料库和纯文本阅读。
2. 做点词、本地词典、词状态和句子收藏。
3. 接入 TTS、Memory、Practice。
4. 再扩展文件格式、SRS、语言包和高级导入。

如果后续用户验证显示阅读成为最高频入口，再重新评估 iPhone 主 Tab 是否从 `记录 / 练习 / 记忆` 调整为 `记录 / 阅读 / 练习 / 记忆`。

