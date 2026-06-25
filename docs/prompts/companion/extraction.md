# Language Companion Extraction Prompt

状态：Active

## 1. 基本信息

- Prompt id：`builtin.companion.extraction.v1`
- Prompt version：`1`
- Schema version：`1`
- 所属功能：语伴聊天反哺（Language Companion chat reflux，LM03-S2a 交付物 A）。
- 调用模块：`CompanionExtractionPromptRegistry`、`CompanionExtractionEngine`。
- 代码位置：`Packages/LangoTraceAI/Sources/LangoTraceAI/CompanionExtractionPromptRegistry.swift`、`CompanionExtractionEngine.swift`。
- 自动化测试：`Packages/LangoTraceAI/Tests/LangoTraceAITests/Companion/CompanionExtractionPromptRegistryTests.swift`、`CompanionExtractionEngineTests.swift`。

## 2. 触发与隐私边界

仅在用户已开启语伴（默认关闭，ADR-008 §2.6）、并在语伴聊天页**显式点击「提取词汇 / 表达」**时才发起请求。这是用户主动动作，**形状与「生成学习材料 / 重新分析」完全同构**：把已存储的用户对话内容在显式触发下重发给所配置的同一 Provider，仅受全局 Provider 配置 + 请求预览约束，**不需每次单独授权 UX**（plan §D2）。

它**不属于**系统自动注入（决策 #10）：系统自动注入指 Memory / Style 画像摘要被系统**自动**塞进 system prompt（Memory 注入 = LM03-S2b，受最高隐私门）。本提取不注入任何画像内容。

**请求预览披露要求（plan §D2 / P0-1）**：提取调用复用 `AIRequestPreviewProjection`，capability = `companionExtraction`，`includedContent = [companionConversation]`——请求预览必须**显式披露**「将本段对话内容发送给所配置 AI Provider 以提取词汇 / 表达」，**不新增任何外发类目**（照片 / 长期记忆 / 历史记录 / 其他空间均保持 excluded）。失败诚实：不丢对话、不伪造候选。

发送内容仅限：固定提取指令模板 + 对话窗口（作为转写消息，引用内容非指令，AI-17 加固）。不得包含：Memory 生活事实、Style 片段、其他 Entry、照片、音频、API Key、Authorization header、本地路径。

## 3. 行为契约（typed directives）

`CompanionExtractionRenderedPrompt.directives` 以结构化集合声明：

- `groundedInConversationNoFabrication`：只提取对话中**实际出现**的项；不臆造词汇，不推断 / 输出用户个人事实（挖掘语言，不画像）。
- `targetLanguageItemsOnly`：提取目标语词 / 短语 / 句型 / 语法点 / 错误模式。
- `nativeLanguageExplanations`：解释与例句母语注解用学习者母语，目标语例句保持目标语。
- `structuredJSONOutput`：仅输出固定 JSON 对象。

## 4. 结构化输出契约

```json
{
  "schema_version": "1",
  "candidates": [
    {
      "kind": "word|phrase|sentencePattern|grammarPoint|errorPattern",
      "text": "...",
      "explanation_native": "...",
      "example_target": "...",
      "example_native": "..."
    }
  ]
}
```

- `kind` 复用 `LearningMemoryCandidate.Kind`（与学习材料候选同词表，便于未来 deposit 期统一评审面，plan §D1）。
- 解析容忍**一层** Markdown code fence；其余必须是单一 JSON 文档。
- 错误契约（对齐 `LearningMaterialGenerationService` 同族）：无效 JSON / 缺必填字段（`text` / `kind`）→ `CompanionExtractionError.invalidStructuredOutput`；`candidates: []` → **成功、count 0**（非失败，UI 展示「未找到词汇」）；Provider 不可用 / 取消 / 拒绝 → 复用 `CompanionReplyFailure` 同族映射。

## 5. 落库边界

候选写入独立表 `companion_memory_candidates`（v31，**不**改 `memory_candidates`），按**可复算派生数据**处理（local-only，无同步 / 备份 / 导出策略列）；删 thread → CASCADE，删来源消息 → `message_id` 置 NULL（候选存活）。候选仅产出 + 展示计数；升级为记忆条目（主数据 `learner_memory_facts`）属未来 deposit 管线（plan 10/11）。详见 [spec/007](../../spec/007-data-storage-migration-export-and-attachments.md) 与 [ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md)。
