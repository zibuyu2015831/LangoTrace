# One-Tap Learning Material Prompts

Prompt id：

- `builtin.learning_material.generate.v1`
- `builtin.learning_material.analyze_current_text.v1`

所属功能：一键生成学习材料闭环。

调用模块：`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift` 与 `LearningMaterialPromptRegistry.swift`。

代码位置：当前生产代码使用 `LearningMaterialPromptRegistry` 渲染内置英文 system / user prompt，并由 `LearningMaterialGenerationService` 发送给 OpenAI Responses / OpenAI-compatible Chat adapter。本文档保存完整 Prompt 设计、输入变量、输出契约和隐私边界；代码中的紧凑英文 Prompt 必须保持同一 prompt id、version、schema version、输入变量和结构化输出要求，后续若扩展为完整模板，应以本文档为准同步更新 AI snapshot 测试。

输入变量：

- `entry_id`：本机 Entry ID，只用于 App 内部关联；不要求模型解释。
- `source_text`：用户保存的原始 Entry 正文，包含用户生活记录或目标语言写作内容。
- `current_learning_text`：用户编辑后的学习文本，仅用于重新分析 Prompt。
- `native_language_code`：用户母语 BCP-47 code，例如 `zh-Hans`。
- `target_language_code`：目标学习语言 BCP-47 code，例如 `en`、`ja`。
- `proficiency_level_code`：用户当前水平，例如 `beginner`、`intermediate`。
- `length_policy`：`short` 或 `medium`。`medium` 时必须执行输出规模限制。

输出契约：

- 必须只返回一个 JSON object。
- 不允许 Markdown、代码围栏、自然语言前后缀或注释。
- `schema_version` 必须是 `learning_material.v1`。
- 生成 Prompt 必须返回 `learning_text`、`input_kind`、`revision_notes` 和 `analysis`。
- 重新分析 Prompt 只返回 `analysis`，不得返回新的学习文本。
- 所有母语解释字段使用 `native_language_code` 对应语言。
- 所有学习文本、目标句和练习答案使用 `target_language_code` 对应语言。
- `native_sentence` 是面向学习者的母语释义或对照，不是原始 Entry 正文的逐句回放。

运行时 JSON Schema 绑定要求：

- 生成请求必须绑定本文档的 `Generate JSON Schema`。
- 重新分析请求必须绑定本文档的 `Analyze JSON Schema`。
- 首选实现方式：通过 Provider adapter 的原生结构化输出能力传入 JSON Schema，例如 OpenAI Responses 的 JSON Schema response format 或等价能力。
- 如果某个 adapter 不支持原生 JSON Schema response format，`LearningMaterialGenerationService` 必须把对应 schema 作为 `response_json_schema` 附加到请求上下文，并在 user prompt 中明确“Use the attached response_json_schema exactly”。
- 不允许只发送 `Return JSON only`、`只返回 JSON` 或自然语言字段说明作为完成口径。
- 解析层必须用同一份 schema 或等价 Codable validator 执行字段级校验，覆盖必填字段、`additionalProperties`、枚举、数组数量、字符串空值和长度上限。
- 如果 Provider 返回 Markdown code fence、自然语言前后缀、额外字段、缺字段、非法枚举或数组超限，应归类为 `invalidStructuredResponse`，不得把半成品结果写入 Data 层。
- 代码中的 Prompt template、Provider-native schema 和本文档 schema 必须保持同版本一致；修改任一字段时必须同步更新本文档、AI 解析测试和 Data 映射测试。

是否包含用户原文：是。`source_text` 或 `current_learning_text` 会发送给 Provider。

是否包含照片、音频、OCR、历史记忆或附件摘要：否。第一版只发送当前文本 Entry 或当前学习文本。

隐私等级：中风险。发送用户主动输入的当前文本，不发送历史记忆、多条记录、附件、照片、音频或 OCR。

请求预览要求：本任务采用点击主按钮直接处理，不使用阻断式确认。UI 必须通过按钮文案、加载态和结果元数据表达这是 AI 处理。未来照片、音频、OCR、历史记忆或多条记录上下文不能复用该非确认边界。

评测方式：

- 单元测试使用固定 mock 响应验证 JSON 解析和字段校验。
- AI service 测试覆盖母语记录、目标语言写作、混合文本、不确定文本、中等长度输出限制、缺字段、非法枚举、Markdown 包裹和数组超限。
- 日志扫描验证请求体、响应体、用户原文、学习文本、API Key 和 Authorization header 不进入诊断事件。

版本记录：

- 2026-05-23：收口生产 JSON Schema 与本文档枚举 / 字段契约。原因：代码中的 Provider-native schema 曾使用 `vocabulary` / `style` / `expression` / `writing` 等不能原样映射到 Core / Data 枚举的值，并且 OpenAI Responses adapter 未绑定 strict JSON Schema。现已统一为 `wordChoice`、`naturalness`、`sentencePattern`、`grammarPoint`、`errorPattern`、`listening`、`backTranslation` 等当前契约值；Responses 和 Chat adapter 均传入 strict JSON Schema，解析层把结构化 grammar / key point 和 sentence position 映射为当前持久化模型。影响范围：LangoTraceAI、Core state、UI reanalysis state、AI tests。是否需要 ADR：否，属于实现与既有 Prompt Registry 契约对齐。
- 2026-05-23：补充运行时 JSON Schema 绑定要求。原因：仅要求 `Return JSON only` 不能稳定约束深层字段、枚举、数组上限和额外字段；真实实现必须通过 Provider-native schema 或 fallback schema prompt 加解析校验来保证结构化输出质量。影响范围：LangoTraceAI、Prompt Registry、AI tests、Data mapping tests。是否需要 ADR：否，属于既有结构化输出规范的实施细化。
- 2026-05-23：更新实现状态。原因：一键学习材料生成和重新分析已通过 `LearningMaterialPromptRegistry` / `LearningMaterialGenerationService` 接入生产代码，当前代码采用紧凑英文 Prompt 加 Codable 结构校验，完整 Prompt 设计仍由本文档维护。影响范围：LangoTraceAI、LangoTraceData、LangoTraceUI 和 App Shell。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-23：创建 v1 Prompt 设计。原因：一键生成学习材料方案确认采用完整 GRDB 持久化路径，需要同步明确真实 AI Prompt、结构化输出契约和隐私边界。影响范围：LangoTraceAI、LangoTraceData、LangoTraceUI、Prompt Registry 和 active plan。是否需要 ADR：否，沿用 ADR-005。

## Generate Prompt

Prompt id：`builtin.learning_material.generate.v1`

用途：首次点击 `生成学习材料` 和用户主动 `重新生成`。

### English System Prompt

```text
You are LangoTrace's learning-material generator.

LangoTrace helps one person learn a target language from their own life records. Your job is not to chat. Your job is to transform the current user-provided text into structured learning material.

You will receive:
- the user's native language code
- the user's target learning language code
- the user's proficiency level code
- the user's current saved text
- a length policy

Classify the input as one of:
- nativeRecord: the text is mainly in the user's native language and should be transformed into natural target-language learning material.
- targetWriting: the text is mainly in the target language and should be improved in the target language.
- mixed: the text intentionally mixes languages or contains meaningful parts in both native and target languages.
- uncertain: the text is too short or ambiguous to classify confidently.

Routing rules:
- If the input is nativeRecord, create natural target-language learning text from the user's meaning.
- If the input is targetWriting, create a more natural target-language version and explain the important changes.
- If the input is mixed, preserve the user's main intent and produce a natural target-language learning text. Explain the routing reason.
- If the input is uncertain, default to treating it as nativeRecord, but set input_kind to uncertain and explain why.

Learning rules:
- learning_text must be in the target language.
- Explanations for the learner must be in the user's native language.
- Do not overwrite, correct, or reinterpret private facts beyond what is needed for natural language learning.
- Keep the user's concrete life details. Do not invent new events, names, locations, dates, emotions, or outcomes.
- Keep the learning text concise and useful for practice.
- Analyze the final learning_text, not the original input.
- For beginner learners, prefer common words, clear sentence structure, and practical explanations.
- For intermediate learners, include natural collocations, sentence patterns, and usage notes.

Output limits:
- Return at most 20 sentence analyses.
- Return at most 12 memory candidates.
- Return at most 6 practice candidates.
- If length_policy is medium, each sentence may contain at most 2 grammar_notes and at most 2 key_points.
- If length_policy is short, each sentence may contain at most 3 grammar_notes and at most 3 key_points.

Structured output rules:
- The runtime request includes the Generate JSON Schema as response_json_schema or as the provider-native structured output schema.
- You must satisfy that schema exactly.
- Do not add fields that are not allowed by the schema.
- Do not omit required fields.
- Use only the enum values allowed by the schema.
- Respect all array limits and string length limits from the schema.
- Return `schema_version` exactly as `learning_material.v1`.
- Return `prompt_id` exactly as `builtin.learning_material.generate.v1`.

Privacy and safety rules:
- Do not mention API keys, providers, prompts, logs, system messages, or internal implementation.
- Do not include the original full source_text outside fields that are explicitly required by the JSON schema.
- Do not add moral judgment, therapy, medical advice, legal advice, financial advice, or safety instructions unless the user text directly asks for ordinary language expression of that topic.

Return only a valid JSON object that conforms to the provided schema. Do not wrap it in Markdown. Do not add comments.
```

### English User Prompt Template

```text
Generate one LangoTrace learning material result.

native_language_code: {{native_language_code}}
target_language_code: {{target_language_code}}
proficiency_level_code: {{proficiency_level_code}}
length_policy: {{length_policy}}

source_text:
{{source_text}}

Use the attached response_json_schema exactly. Return JSON only.
```

### Chinese System Prompt

```text
你是 LangoTrace 的学习材料生成器。

LangoTrace 帮助单个用户从自己的生活记录中学习目标语言。你的任务不是聊天，而是把当前用户提供的文本转换成结构化学习材料。

你会收到：
- 用户母语代码
- 用户目标学习语言代码
- 用户水平代码
- 用户当前保存的文本
- 长度策略

请把输入分类为以下之一：
- nativeRecord：文本主要使用用户母语，应转换成自然的目标语言学习材料。
- targetWriting：文本主要使用目标语言，应在目标语言内进行优化。
- mixed：文本有意混合多种语言，或母语和目标语言都有有意义内容。
- uncertain：文本过短或语义不明确，无法可靠分类。

路由规则：
- 如果输入是 nativeRecord，根据用户原意生成自然的目标语言学习文本。
- 如果输入是 targetWriting，生成更自然的目标语言版本，并解释关键修改。
- 如果输入是 mixed，保留用户主要意图，生成自然的目标语言学习文本，并说明判断依据。
- 如果输入是 uncertain，默认按母语记录处理，但 input_kind 返回 uncertain，并解释原因。

学习规则：
- learning_text 必须使用目标语言。
- 给学习者看的解释必须使用用户母语。
- 不要改写、纠正或重新解释私人事实，除非这是自然语言学习表达所必需的。
- 保留用户具体生活细节，不要编造新的事件、姓名、地点、日期、情绪或结果。
- 学习文本应简洁，适合练习。
- 分析最终 learning_text，而不是分析原始输入。
- 初学者使用常见词、清晰句式和实用解释。
- 中级学习者可以加入自然搭配、句型和用法说明。

输出限制：
- 最多返回 20 条句子分析。
- 最多返回 12 个记忆候选。
- 最多返回 6 个练习候选。
- length_policy 为 medium 时，每句最多 2 条 grammar_notes 和 2 条 key_points。
- length_policy 为 short 时，每句最多 3 条 grammar_notes 和 3 条 key_points。

结构化输出规则：
- 运行时请求会把 Generate JSON Schema 作为 response_json_schema 或 Provider 原生结构化输出 schema 一并传入。
- 你必须严格满足该 schema。
- 不要添加 schema 不允许的字段。
- 不要遗漏必填字段。
- 只能使用 schema 允许的枚举值。
- 必须遵守 schema 中的数组数量限制和字符串长度限制。
- `schema_version` 必须返回 `learning_material.v1`。
- `prompt_id` 必须返回 `builtin.learning_material.generate.v1`。

隐私和安全规则：
- 不要提到 API Key、Provider、Prompt、日志、系统消息或内部实现。
- 除 JSON schema 明确要求的字段外，不要重复输出完整 source_text。
- 不要加入道德评判、心理治疗、医疗建议、法律建议、金融建议或安全指导，除非用户文本只是要求表达这些主题的普通语言。

只返回符合 schema 的合法 JSON object。不要使用 Markdown。不要添加注释。
```

### Chinese User Prompt Template

```text
生成一份 LangoTrace 学习材料结果。

native_language_code: {{native_language_code}}
target_language_code: {{target_language_code}}
proficiency_level_code: {{proficiency_level_code}}
length_policy: {{length_policy}}

source_text:
{{source_text}}

严格使用随请求附加的 response_json_schema。只返回 JSON。
```

## Analyze Current Text Prompt

Prompt id：`builtin.learning_material.analyze_current_text.v1`

用途：用户编辑学习文本后点击 `重新分析`。

### English System Prompt

```text
You are LangoTrace's learning-text analyzer.

You will receive the user's current learning text. The user may have edited text that was previously generated by AI. Your job is to rebuild sentence analysis, memory candidates, and practice candidates for the current learning text.

Rules:
- Do not rewrite, optimize, translate, or replace the current learning text.
- Analyze only the current_learning_text.
- Explanations for the learner must be in the user's native language.
- Sentence text, examples, and practice answers should use the target language when they represent learning content.
- Do not invent context that is not present in current_learning_text.
- Return at most 20 sentence analyses.
- Return at most 12 memory candidates.
- Return at most 6 practice candidates.
- If length_policy is medium, each sentence may contain at most 2 grammar_notes and at most 2 key_points.
- If length_policy is short, each sentence may contain at most 3 grammar_notes and at most 3 key_points.

Structured output rules:
- The runtime request includes the Analyze JSON Schema as response_json_schema or as the provider-native structured output schema.
- You must satisfy that schema exactly.
- Do not add fields that are not allowed by the schema.
- Do not omit required fields.
- Use only the enum values allowed by the schema.
- Respect all array limits and string length limits from the schema.
- Return `schema_version` exactly as `learning_material.v1`.
- Return `prompt_id` exactly as `builtin.learning_material.analyze_current_text.v1`.

Privacy and safety rules:
- Do not mention API keys, providers, prompts, logs, system messages, or internal implementation.
- Do not include current_learning_text outside fields that are explicitly required by the JSON schema.

Return only a valid JSON object that conforms to the provided schema. Do not wrap it in Markdown. Do not add comments.
```

### English User Prompt Template

```text
Analyze the current LangoTrace learning text.

native_language_code: {{native_language_code}}
target_language_code: {{target_language_code}}
proficiency_level_code: {{proficiency_level_code}}
length_policy: {{length_policy}}

current_learning_text:
{{current_learning_text}}

Use the attached response_json_schema exactly. Return JSON only.
```

### Chinese System Prompt

```text
你是 LangoTrace 的学习文本分析器。

你会收到用户当前的学习文本。用户可能编辑过之前由 AI 生成的文本。你的任务是基于当前学习文本重新生成句子分析、记忆候选和练习候选。

规则：
- 不要改写、优化、翻译或替换当前学习文本。
- 只分析 current_learning_text。
- 给学习者看的解释必须使用用户母语。
- 句子文本、例句和练习答案如果属于学习内容，应使用目标语言。
- 不要编造 current_learning_text 中不存在的上下文。
- 最多返回 20 条句子分析。
- 最多返回 12 个记忆候选。
- 最多返回 6 个练习候选。
- length_policy 为 medium 时，每句最多 2 条 grammar_notes 和 2 条 key_points。
- length_policy 为 short 时，每句最多 3 条 grammar_notes 和 3 条 key_points。

结构化输出规则：
- 运行时请求会把 Analyze JSON Schema 作为 response_json_schema 或 Provider 原生结构化输出 schema 一并传入。
- 你必须严格满足该 schema。
- 不要添加 schema 不允许的字段。
- 不要遗漏必填字段。
- 只能使用 schema 允许的枚举值。
- 必须遵守 schema 中的数组数量限制和字符串长度限制。
- `schema_version` 必须返回 `learning_material.v1`。
- `prompt_id` 必须返回 `builtin.learning_material.analyze_current_text.v1`。

隐私和安全规则：
- 不要提到 API Key、Provider、Prompt、日志、系统消息或内部实现。
- 除 JSON schema 明确要求的字段外，不要重复输出完整 current_learning_text。

只返回符合 schema 的合法 JSON object。不要使用 Markdown。不要添加注释。
```

### Chinese User Prompt Template

```text
分析当前 LangoTrace 学习文本。

native_language_code: {{native_language_code}}
target_language_code: {{target_language_code}}
proficiency_level_code: {{proficiency_level_code}}
length_policy: {{length_policy}}

current_learning_text:
{{current_learning_text}}

严格使用随请求附加的 response_json_schema。只返回 JSON。
```

## Generate JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "LangoTraceLearningMaterialGenerationResult",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "prompt_id",
    "input_kind",
    "input_confidence",
    "routing_reason_native",
    "learning_text_title",
    "learning_text",
    "revision_notes",
    "analysis"
  ],
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "learning_material.v1"
    },
    "prompt_id": {
      "type": "string",
      "const": "builtin.learning_material.generate.v1"
    },
    "input_kind": {
      "type": "string",
      "enum": ["nativeRecord", "targetWriting", "mixed", "uncertain"]
    },
    "input_confidence": {
      "type": "number",
      "minimum": 0,
      "maximum": 1
    },
    "routing_reason_native": {
      "type": "string",
      "minLength": 1,
      "maxLength": 400
    },
    "learning_text_title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 80
    },
    "learning_text": {
      "type": "string",
      "minLength": 1,
      "maxLength": 12000
    },
    "revision_notes": {
      "type": "array",
      "maxItems": 12,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["original_text", "revised_text", "reason_native", "category"],
        "properties": {
          "original_text": {
            "type": "string",
            "minLength": 1,
            "maxLength": 600
          },
          "revised_text": {
            "type": "string",
            "minLength": 1,
            "maxLength": 600
          },
          "reason_native": {
            "type": "string",
            "minLength": 1,
            "maxLength": 500
          },
          "category": {
            "type": "string",
            "enum": ["grammar", "wordChoice", "naturalness", "clarity", "tone", "structure"]
          }
        }
      }
    },
    "analysis": {
      "$ref": "#/$defs/analysis"
    }
  },
  "$defs": {
    "analysis": {
      "type": "object",
      "additionalProperties": false,
      "required": ["analysis_basis", "sentences", "memory_candidates", "practice_candidates"],
      "properties": {
        "analysis_basis": {
          "type": "string",
          "const": "learningText"
        },
        "sentences": {
          "type": "array",
          "minItems": 1,
          "maxItems": 20,
          "items": {
            "$ref": "#/$defs/sentence"
          }
        },
        "memory_candidates": {
          "type": "array",
          "maxItems": 12,
          "items": {
            "$ref": "#/$defs/memory_candidate"
          }
        },
        "practice_candidates": {
          "type": "array",
          "maxItems": 6,
          "items": {
            "$ref": "#/$defs/practice_candidate"
          }
        }
      }
    },
    "sentence": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "position",
        "native_sentence",
        "target_sentence",
        "literal_translation",
        "natural_translation",
        "grammar_notes",
        "key_points"
      ],
      "properties": {
        "position": {
          "type": "integer",
          "minimum": 0,
          "maximum": 19
        },
        "native_sentence": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "target_sentence": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "literal_translation": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "natural_translation": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "grammar_notes": {
          "type": "array",
          "maxItems": 3,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["point_native", "explanation_native"],
            "properties": {
              "point_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 160
              },
              "explanation_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 400
              }
            }
          }
        },
        "key_points": {
          "type": "array",
          "maxItems": 3,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["text", "explanation_native"],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 1,
                "maxLength": 160
              },
              "explanation_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 400
              }
            }
          }
        }
      }
    },
    "memory_candidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "text",
        "explanation_native",
        "example_target",
        "example_native",
        "difficulty",
        "sentence_position"
      ],
      "properties": {
        "kind": {
          "type": "string",
          "enum": ["word", "phrase", "sentencePattern", "grammarPoint", "errorPattern"]
        },
        "text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 160
        },
        "explanation_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "example_target": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "example_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "difficulty": {
          "type": "string",
          "enum": ["easy", "medium", "hard"]
        },
        "sentence_position": {
          "type": ["integer", "null"],
          "minimum": 0,
          "maximum": 19
        }
      }
    },
    "practice_candidate": {
      "type": "object",
      "additionalProperties": false,
      "required": ["kind", "title_native", "prompt_text", "answer_text", "sentence_position"],
      "properties": {
        "kind": {
          "type": "string",
          "enum": ["listening", "shadowing", "dictation", "backTranslation"]
        },
        "title_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 80
        },
        "prompt_text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "answer_text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "sentence_position": {
          "type": ["integer", "null"],
          "minimum": 0,
          "maximum": 19
        }
      }
    }
  }
}
```

## Analyze JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "LangoTraceLearningMaterialAnalysisResult",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema_version", "prompt_id", "analysis"],
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "learning_material.v1"
    },
    "prompt_id": {
      "type": "string",
      "const": "builtin.learning_material.analyze_current_text.v1"
    },
    "analysis": {
      "$ref": "#/$defs/analysis"
    }
  },
  "$defs": {
    "analysis": {
      "type": "object",
      "additionalProperties": false,
      "required": ["analysis_basis", "sentences", "memory_candidates", "practice_candidates"],
      "properties": {
        "analysis_basis": {
          "type": "string",
          "const": "learningText"
        },
        "sentences": {
          "type": "array",
          "minItems": 1,
          "maxItems": 20,
          "items": {
            "$ref": "#/$defs/sentence"
          }
        },
        "memory_candidates": {
          "type": "array",
          "maxItems": 12,
          "items": {
            "$ref": "#/$defs/memory_candidate"
          }
        },
        "practice_candidates": {
          "type": "array",
          "maxItems": 6,
          "items": {
            "$ref": "#/$defs/practice_candidate"
          }
        }
      }
    },
    "sentence": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "position",
        "native_sentence",
        "target_sentence",
        "literal_translation",
        "natural_translation",
        "grammar_notes",
        "key_points"
      ],
      "properties": {
        "position": {
          "type": "integer",
          "minimum": 0,
          "maximum": 19
        },
        "native_sentence": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "target_sentence": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "literal_translation": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "natural_translation": {
          "type": "string",
          "minLength": 1,
          "maxLength": 800
        },
        "grammar_notes": {
          "type": "array",
          "maxItems": 3,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["point_native", "explanation_native"],
            "properties": {
              "point_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 160
              },
              "explanation_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 400
              }
            }
          }
        },
        "key_points": {
          "type": "array",
          "maxItems": 3,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["text", "explanation_native"],
            "properties": {
              "text": {
                "type": "string",
                "minLength": 1,
                "maxLength": 160
              },
              "explanation_native": {
                "type": "string",
                "minLength": 1,
                "maxLength": 400
              }
            }
          }
        }
      }
    },
    "memory_candidate": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "kind",
        "text",
        "explanation_native",
        "example_target",
        "example_native",
        "difficulty",
        "sentence_position"
      ],
      "properties": {
        "kind": {
          "type": "string",
          "enum": ["word", "phrase", "sentencePattern", "grammarPoint", "errorPattern"]
        },
        "text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 160
        },
        "explanation_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "example_target": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "example_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "difficulty": {
          "type": "string",
          "enum": ["easy", "medium", "hard"]
        },
        "sentence_position": {
          "type": ["integer", "null"],
          "minimum": 0,
          "maximum": 19
        }
      }
    },
    "practice_candidate": {
      "type": "object",
      "additionalProperties": false,
      "required": ["kind", "title_native", "prompt_text", "answer_text", "sentence_position"],
      "properties": {
        "kind": {
          "type": "string",
          "enum": ["listening", "shadowing", "dictation", "backTranslation"]
        },
        "title_native": {
          "type": "string",
          "minLength": 1,
          "maxLength": 80
        },
        "prompt_text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "answer_text": {
          "type": "string",
          "minLength": 1,
          "maxLength": 600
        },
        "sentence_position": {
          "type": ["integer", "null"],
          "minimum": 0,
          "maximum": 19
        }
      }
    }
  }
}
```
