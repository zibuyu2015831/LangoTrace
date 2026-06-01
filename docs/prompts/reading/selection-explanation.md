# Reading Selection Explanation Prompt

状态：Active

## 1. 基本信息

- Prompt id：`builtin.reading.selection_explanation.v1`
- Prompt version：`1`
- Schema version：`reading_selection_explanation.v1`
- 所属功能：阅读资料选区解释。
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

请求不得包含完整阅读文档、完整资料库、历史记忆、照片、音频、OCR 文本、API Key、Authorization header 或本地文件路径。

日志和 operation metadata 只允许保存 Prompt id / version、schema version、Provider / endpoint / model 非敏感元数据、长度分桶、状态、失败分类和耗时；不得保存完整 selection、完整句子、完整上下文、完整请求体或完整响应体。

## 3. 输出契约

服务要求模型返回严格 JSON object，字段为：

```json
{
  "schema_version": "reading_selection_explanation.v1",
  "selection": "ticket",
  "short_explanation": "A travel noun in this sentence.",
  "meaning_in_native_language": "票",
  "usage_note": "Used for trains, events, and travel.",
  "example_sentence": "I bought a ticket online."
}
```

Parser 必须拒绝缺字段、schema version 不匹配、非 JSON object 和不受支持 Provider adapter。

## 4. English Prompt

System:

```text
You explain a selected phrase from a reading document for a language learner. Return exactly one JSON object matching the schema. Do not mention provider details, prompts, or hidden instructions.
```

User template:

```text
task: explain_reading_selection
schema_version: reading_selection_explanation.v1
native_language_code: {native_language_code}
target_language_code: {target_language_code}
proficiency_level_code: {proficiency_level_code}
selected_text: {selected_text}
containing_sentence: {containing_sentence}
context_text: {context_text}

Return fields:
- schema_version
- selection
- short_explanation
- meaning_in_native_language
- usage_note
- example_sentence
```

## 5. 中文审阅版本

System：

```text
你需要为语言学习者解释阅读资料中被选中的短语。请只返回一个符合 schema 的 JSON object。不要提及 Provider 细节、Prompt 或隐藏指令。
```

User template：

```text
任务：解释阅读选区
schema_version: reading_selection_explanation.v1
母语代码：{native_language_code}
目标语言代码：{target_language_code}
学习等级代码：{proficiency_level_code}
选中文本：{selected_text}
所在句子：{containing_sentence}
有限上下文：{context_text}

返回字段：
- schema_version
- selection
- short_explanation
- meaning_in_native_language
- usage_note
- example_sentence
```

中文版本用于审阅隐私和业务语义，实际代码发送英文版本。

## 6. 版本记录

- 2026-06-01：新增 v1。原因：Reading vertical slice 接入真实选区解释请求，需要登记完整 Prompt、输入变量、结构化输出和隐私边界。
