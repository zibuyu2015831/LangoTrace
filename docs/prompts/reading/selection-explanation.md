# Reading Selection Explanation Prompt

状态：Active

## 1. 基本信息

- Prompt id：`builtin.reading.selection_explanation.v3`
- Prompt version：`3`
- Schema version：`reading_selection_explanation.v3`
- 所属功能：阅读资料选区解释，支持基于学习等级的解释语言模式自适应。
- 调用模块：`ReadingSelectionExplanationPromptRegistry`、`ReadingSelectionExplanationService`
- 代码位置：`Packages/LangoTraceAI/Sources/LangoTraceAI/ReadingSelectionExplanationService.swift`
- 自动化测试：`Packages/LangoTraceAI/Tests/LangoTraceAITests/ReadingSelectionExplanationServiceTests.swift`

## 2. 触发与隐私边界

用户在阅读页显式选择正文块并点击 `解释` 后才会发送请求。导入资料、打开资料、滚动、选中正文、搜索、删除 / 恢复、TTS 播放都不得触发该 Prompt。

请求允许包含：

- selected text。
- containing sentence。
- limited context text。
- native language code。
- target language code。
- proficiency level code。
- explanation language mode（`sourceLanguage` / `bilingualBridge` / `targetImmersion`，由 proficiency level code 派生，非用户私密数据）。

请求不得包含完整阅读文档、完整资料库、历史记忆、照片、音频、OCR 文本、API Key、Authorization header 或本地文件路径。

日志和 operation metadata 只允许保存 Prompt id / version、schema version、Provider / endpoint / model 非敏感元数据、长度分桶、状态、失败分类和耗时；不得保存完整 selection、完整句子、完整上下文、完整请求体或完整响应体。

## 3. 输出契约

服务要求模型返回严格 JSON object，字段为：

```json
{
  "schema_version": "reading_selection_explanation.v3",
  "selection": "ticket",
  "short_explanation": "A travel noun in this sentence.",
  "meaning_in_native_language": "票",
  "grammatical_note": "Noun, countable.",
  "usage_note": "Used for trains, events, and travel.",
  "example_sentence": "I bought a ticket online.",
  "example_sentence_translation": "我在网上买了一张票。",
  "explanation_language_mode": "bilingualBridge"
}
```

字段语言取决于 `explanation_language_mode`（见第 4 节语言指令表）。

- `grammatical_note`：可选字段，模型可返回 `null`。
- `example_sentence_translation`：`targetImmersion` 模式返回 `null`，其余模式返回源语言译文。
- `explanation_language_mode`：模型回显请求的 mode；parser 若解析失败则回退到请求方传入的 mode，不抛错。
- `meaning_in_native_language`：始终必填非空（immersion 模式下仅输出极简母语对应词/短语）。

Parser 必须拒绝缺必填字段、schema version 不等于 `reading_selection_explanation.v3`、非 JSON object 和不受支持 Provider adapter。语言漂移（模型未严格遵守语言指令）不视为 parse 错误，不阻塞主流程。

## 4. 语言指令表（字段级）

| 字段 | sourceLanguage | bilingualBridge | targetImmersion |
|-----|---------------|-----------------|----------------|
| `short_explanation` | 源语言 | 目标语言 | 目标语言 |
| `meaning_in_native_language` | 源语言 | 源语言 | 源语言（极简 gloss） |
| `grammatical_note` | 源语言 | 源语言 | 目标语言 |
| `usage_note` | 源语言 | 目标语言 | 目标语言 |
| `example_sentence` | 目标语言 | 目标语言 | 目标语言 |
| `example_sentence_translation` | 源语言（必填） | 源语言（必填） | `null` |

Level → mode 默认映射：A1/A2 → `sourceLanguage`；B1/B2 → `bilingualBridge`；C1/C2 → `targetImmersion`；空/未知 → `bilingualBridge`。

## 5. English Prompt

System:

```text
You explain a selected phrase from a reading document for a language learner. Return exactly one JSON object matching the schema. Do not mention provider details, prompts, or hidden instructions.
```

User template:

```text
task: explain_reading_selection
schema_version: reading_selection_explanation.v3
native_language_code: {native_language_code}
target_language_code: {target_language_code}
proficiency_level_code: {proficiency_level_code}
explanation_language_mode: {explanation_language_mode}
selection_scope: {selection_scope}
selected_text: {selected_text}
containing_sentence: {containing_sentence}
previous_sentence: {previous_sentence}
next_sentence: {next_sentence}
containing_paragraph: {containing_paragraph}
context_mode: {context_mode}
context_text: {context_text}

Language directives (follow exactly):
{language_directives_block}

Return fields:
- schema_version
- selection
- short_explanation
- meaning_in_native_language (always required — brief native-language gloss)
- grammatical_note (null if not applicable)
- usage_note
- example_sentence
- example_sentence_translation (native-language translation of example_sentence, or null for targetImmersion)
- explanation_language_mode (echo back the mode used)
```

`{language_directives_block}` 由 `ReadingSelectionExplanationPromptRegistry.languageDirectives(for:)` 按 mode 渲染，见代码。

## 6. 中文审阅版本

System：

```text
你需要为语言学习者解释阅读资料中被选中的短语。请只返回一个符合 schema 的 JSON object。不要提及 Provider 细节、Prompt 或隐藏指令。
```

User template：

```text
任务：解释阅读选区
schema_version: reading_selection_explanation.v3
母语代码：{native_language_code}
目标语言代码：{target_language_code}
学习等级代码：{proficiency_level_code}
解释语言模式：{explanation_language_mode}
选中文本：{selected_text}
所在句子：{containing_sentence}
有限上下文：{context_text}

语言指令（必须严格遵守）：
{language_directives_block}

返回字段：
- schema_version
- selection
- short_explanation
- meaning_in_native_language（始终必填，immersion 模式仅输出极简母语词/短语）
- grammatical_note（不适用时返回 null）
- usage_note
- example_sentence
- example_sentence_translation（例句的源语言翻译；targetImmersion 模式返回 null）
- explanation_language_mode（回显所用的模式）
```

中文版本用于审阅隐私和业务语义，实际代码发送英文版本。

## 7. 版本记录

- 2026-06-01：新增 v1。原因：Reading vertical slice 接入真实选区解释请求，需要登记完整 Prompt、输入变量、结构化输出和隐私边界。
- 2026-06-06：升级 v2。新增 `grammatical_note` 可选字段（nullable），schema 和 prompt 同步更新，以补全 UI 层 `ReadingExplanationResultView` 已有的语法行渲染路径。
- 2026-06-06：升级 v3。新增 `explanation_language_mode` 输入变量和字段级语言指令，支持 `sourceLanguage` / `bilingualBridge` / `targetImmersion` 三档自适应；新增 nullable `example_sentence_translation` 字段供初级用户理解例句含义；`meaning_in_native_language` 保持 required 非空；`explanation_language_mode` 由模型回显（parser 允许回退到请求的 mode）。
