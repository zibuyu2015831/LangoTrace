# 照片写作 AI 看图辅助写作

状态：User Approved
自审核状态：Reviewed
类型：feature
创建日期：2026-06-24
最后更新日期：2026-06-24

## 用户确认记录

- 2026-06-24：用户在 iPhone 模拟器查看「照片写作」页后提出两点：(1)「照片仅保存在本设备，不会发送给 AI Provider。」这条隐私 tip 需要删除/修订；(2) 后续要开发「发送图片给 AI，AI 基于图片为用户生成写作建议和提示，或直接生成源语言（母语）写作内容，供用户翻译成学习语言」的能力，并要求据此创建 active plan。
- 2026-06-24：用户就三项关键决策确认：
  1. **交付范围**：先只交付本方案（设计），保持 Draft，不进入生产代码实现；待后续显式确认实现授权（推进到 `User Approved`）后再实施。
  2. **隐私文案**：采纳「修订为分动作准确文案」（照片默认本地，仅看图动作发送且有预览确认），不静默 blank-delete。
  3. **v1 产出模式**：两种都做（写作提示 + 母语草稿），共用一个 prompt + `mode` 切换。
- 本方案当前为 Draft，未获 `User Approved` 前不进入生产代码实现。

## 需求描述

在「照片写作」流程中新增一个**用户显式触发**的 AI 看图辅助写作能力：

1. 用户在照片写作页选好照片后，可点击一个明确的「让 AI 看图帮我写」动作。
2. AI 基于这张照片（+ 可选的用户文字备注 + 当前语言空间上下文）产出两类辅助内容之一或两者：
   - **写作提示模式**：围绕照片给出写作角度、可用词句、引导问题，帮助用户自己动笔。
   - **母语草稿模式**：直接生成一段源语言（用户母语）短文，供用户翻译成学习语言（构成「看图 → 母语表达 → 翻译成目标语」的练习闭环）。
3. AI 产出为**非破坏性脚手架**：不覆盖用户已写文本；用户可选择「采用 / 插入」到写作框，或忽略。
4. 这是当前实现中第一个会把**照片内容**发送给 AI Provider 的能力，必须在隐私边界、请求预览、能力门控、Prompt 登记、日志脱敏上严格落地。

并同步修订照片写作页的隐私 tip，使其不再做「照片永不发送 AI」的无条件承诺。

## 现状描述

权威代码快照：`git rev-parse HEAD = a484b64afa452ee6bf98dbb39d325fbd82fb0215`。

### 照片写作页与照片管线

- UI：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingView.swift`。隐私 tip 由 `privacyNotice`（L159-168）渲染，文案来自本地化 key `photoWriting.privacy.notice`（`Resources/Localizable.xcstrings`，zh-Hans = 「照片仅保存在本设备，不会发送给 AI Provider。」，en = "Your photo stays on this device and is never sent to AI providers."）。
- 保存：`PhotoWritingView.onSave(body, imageData)` → `PhoneMainView.swift`（L130-146）→ `PhotoWritingSaveCoordinator` 先 `contentStore.createEntry(source:.photoWriting)`，再 `PhotoWritingActions.importPhoto(...)`，失败回滚 Entry。
- 照片落地：`Packages/LangoTraceData/.../PhotoImportPipeline.swift` 剥离 EXIF/GPS、生成缩略图、写入 `media_artifacts`（`entryPhotoOriginal` / `entryPhotoThumbnail`，`sync_policy=localOnly`、`backup_policy=excludedFromSystemBackup`）与 `entry_photo_attachments`。照片是用户主资产，**当前不发送 AI、不上传、不同步**。
- **经自审核更正**：`stripGPS`（约 L266）按**原始像素尺寸**重编码 JPEG（仅保留 orientation，**不降采样**）；唯一降采样物是 `generateThumbnail`（约 L298，max edge **256px**，为 EntryCard 列表渲染设计，不适合 vision）。因此「发送给 AI 的脱敏降采样产物」在当前代码中**并不存在**，需新增面向 AI 的中等尺寸脱敏降采样（见范围/Phase 1）。
- 路由：`PhoneSheet.photoWriting`（`PhoneRoute.swift`），从记录 Hero「用照片开始」进入。
- 页面清单事实源：`docs/platform-page-inventory.md` L46「照片写作」行明确「照片字节不发送 AI Provider」「不做 OCR、不做 AI 图片分析」。

### AI Provider 图片输入与请求隐私基础设施（关键）

- 能力开关：`AIProviderEndpointConfiguration.supportsImageInput` / `imageInputEnabled`（`AIProviderConfiguration.swift`）。`imageInputEnabled` **默认关闭**，且只对 `purpose == .textGeneration` 的 endpoint 生效（normalization 强制其他 purpose 为 false，约 L358-361）。
- 图片请求体（**经自审核更正**）：`AIProviderTextRequestAdapter.swift` 的 `imagePromptBody`（Chat `image_url` data URL，约 L161-180；Responses `input_image` / `detail:"low"`，约 L226-245）目前**只产出纯文本 prompt body，没有 `response_format` / `json_schema`，且 `max_tokens` 写死为调用方传入的极小值**（probe 传 8）。结构化输出只存在于 `structuredCompletionBody`（`strict: true`），而后者**纯文本、无图片**。代码中**不存在「图片 + 结构化 JSON schema」的请求体**。`MimoCompatibleChatTextAdapter` 也实现了 `imagePromptBody`，但 `supportsImageProbe` allowlist 只放行 `openAIResponses` / `openAICompatibleChat`，**不含 mimo**；Anthropic / Gemini adapter 抛 `unsupportedProvider`。
- 合成 probe：`AIProviderConfigurationProbeService.swift` 的 `imageProbeResult(...)` 已确立门控顺序：`supportsImageInput` → `imageInputEnabled`（用户显式启用）→ adapter 支持 → 才发送内置蓝色方块 PNG。这是「用户显式启用后才走图片链路」的既有先例。
- **请求隐私的结构化不变量（必须正视）**：`Packages/LangoTraceCore/.../AIRequestPreviewProjection.swift` 定义封闭枚举 `AIRequestCapability` 与 `AIRequestContentDescriptor`。**经自审核更正**：当前已有**三个 capability、四条活跃投影**——`learningMaterialGeneration`（generation + analysis 两路）、`readingSelectionExplanation`、`practiceBacktranslationReview`（`AIRequestProjections.swift` L135-178 已实现完整投影，**并非保留/无投影**；Core 源码 L8 注释「has no projection function yet」是过期注释，需在实现期顺手更正）。`AIRequestProjections.swift` 中 `private let alwaysExcludedContent` **把 `.photoAttachments` 列为上述所有现存能力一律排除的类别**，并在 `AIRequestLogEntry`（列级 allowlist）侧防止内容入日志。换言之，「照片永不发送」在当前代码里不仅是 UI 文案，而是**结构性不变量**。本能力将首次、且仅针对新增能力突破该不变量。
- Prompt 登记：`LearningMaterialPromptRegistry.swift` + `docs/prompts/learning-material/one-tap-learning-material.md`；`docs/prompts/` 已有 reading / practice / ai-provider 子目录的登记范式。
- 请求日志：App-Shell `LangoTraceApp/AIRequestLogRecorder.swift` 包裹真实调用写 `ai_request_logs`（成功/失败/取消三态，非敏感字段，按 capability 修剪）。
- 操作摘要范式：阅读选区解释用 `reading_ai_explanation_operations` 记录非敏感 operation 摘要；可作为本能力 operation 摘要的对照范式。

### 与核心决策的关系

- 核心决策 #10：「照片、日记、音频等敏感内容**只有在用户明确触发对应 AI 能力时**才发送给 Provider」——本能力（用户显式点击看图动作）**符合**该决策，不构成 ADR-005 反转。
- spec/005 §4.2 推荐任务类型已含「照片写作引导」；§4.3 把「发送照片内容」列为**高风险**请求，要求更明确的预览/确认，但允许在用户已主动选择「用 AI 分析照片」场景时使用简洁确认。
- 因此：**不需要新 ADR**，但需要在 spec/005、platform-page-inventory 写回当前实现事实，并明确「`photoAttachments` 不再是全局 always-excluded，而是仅本能力 included、其余能力仍 excluded」这一边界收敛。

## 目标、范围与不做什么

### 目标

1. 在照片写作页提供显式、可理解、可控的「AI 看图辅助写作」能力，覆盖写作提示 / 母语草稿两类产出。
2. 把照片首次进入 AI 请求边界这件事，落实在既有 Provider 抽象、能力门控、请求预览、Prompt 登记和脱敏日志上，不绕过任何边界。
3. 修订隐私文案，使页面对「照片何时本地保存、何时会被发送、发送时包含什么」表达准确、分动作。

### 范围（建议 v1）

- 新增 AI 能力：`AIRequestCapability.photoWritingAssist`（封闭枚举扩展）+ 其请求预览投影（`photoAttachments` included，其余敏感类别 excluded）。
- 新增 Prompt：单个 `builtin.photo_writing.assist.v1` + `mode` 输入变量（`suggestions` / `source_draft`）+ `docs/prompts/photo-writing/photo-writing-assist.md` 登记（见自审核 P1-1 已定型）。
- **新增结构化图片请求体（非复用）**：现有 `imagePromptBody` 无 schema、token 上限极小，无法承载结构化输出。需新增 `structuredImagePromptBody(...)`（或为 `imagePromptBody` 增可选 schema/token 上限参数），覆盖 OpenAI Chat 与 Responses 两个 adapter，并加 adapter 级单测验证 body 同时含 image part 与 `response_format` / `text.format=json_schema`。
- 图片支持矩阵（显式表态）：v1 仅 OpenAI-compatible Chat / Responses；**mimo 暂不纳入**（与现有 `supportsImageProbe` allowlist 对齐）；Anthropic / Gemini 返回明确「暂不支持」；`imageInputEnabled` 未启用 / adapter 不支持时返回明确门控错误。
- 门控复用：抽出共享的「图片能力是否可用」判定（`supportsImageInput` / `imageInputEnabled` / adapter allowlist），供 probe 与 assist 两条链路复用，避免放行集合漂移。
- 发送的图片字节：**新增面向 AI 的脱敏降采样产物**（来源是已 EXIF/GPS 剥离的 original 字节，经独立降采样到受控上限边长，如 max edge 768–1024 + 受控 JPEG 质量 + 字节上限，再 base64）。**不复用 256px 缩略图，也不直接发原图，不发送原始相册字节。** 脱敏降采样作为 Data/AI 层可被 import 与 assist 共享的纯函数，避免两套脱敏实现。
- UI：照片写作页新增「让 AI 看图帮我写」动作 + 简洁请求确认（展示请求预览投影：将发送「照片 + 你的备注」给 AI Provider）+ 结果面板（非破坏性，支持「采用到写作框」）+ 不可用/未启用图片输入时的引导态。
- 隐私文案：修订 `photoWriting.privacy.notice`（或拆分为「默认本地」+「看图动作会发送」两条/一条分动作文案）。
- 非敏感操作摘要：`photo_writing_assist_operations`（仿 `reading_ai_explanation_operations`）+ `ai_request_logs` 新增 `photoWritingAssist` capability 映射。
- 文档：spec/005、platform-page-inventory、prompts 登记、（如需）architecture/notes、ADR-005 复审标注。

### 不做什么（v1 非目标）

- 不做 OCR、不做通用「图片理解/问答」聊天；只服务照片写作脚手架这一闭环。
- 不持久化 AI 看图产出为正式派生对象（第一版按短生命周期 UI 状态处理，仅落非敏感 operation 摘要）；持久化另开 slice。
- 不支持 Anthropic / Gemini 图片请求（受 adapter 现状限制）。
- 不做多张照片、照片编辑、照片删除（沿用既有方案边界）。
- 不改变照片本地存储、同步、备份策略（照片主资产仍 localOnly / excludedFromBackup）。
- 不把照片字节复用给学习材料生成、阅读、回译等其它能力——这些能力的 `photoAttachments` **仍保持 always-excluded**。

## 证据与决策依据

- 高风险动作（新增 AI 能力 + 首次发送照片）：参照 `docs/workflows/add-ai-provider.md` 与 `docs/workflows/add-prompt.md` 的检查清单（Keychain 解析、请求预览、Prompt Registry、脱敏日志、专项审查）。采纳其顺序；偏离点：本能力不新增 Provider/endpoint，复用现有文本 endpoint 的图片输入开关。
- spec/005 §3 强制规则、§4.2 任务类型、§4.3 同意级别、§4.4 日志边界、§4.5 输出保存边界为本能力的权威约束来源。
- 核心决策 #10、ADR-005（本地优先 + 用户自带 Provider）为隐私边界依据；本能力符合，不反转。
- `AIRequestPreviewProjection.swift` / `AIRequestProjections.swift` 为「照片 always-excluded」结构性不变量的代码证据，决定了本方案必须以「新增 capability 专属投影」而非「放宽全局排除」的方式实现。

### 是否需要 spike / probe / fixture

- 需要一个**不含真实用户照片**的测试 fixture：复用 `Packages/LangoTraceAI/.../Resources/AIProviderProbe/blue-square.png` 或同类合成图，用于 AI service 图片请求体构造与结构化解析的单元测试。不引入真实敏感照片。
- 不需要新建跨会话 spike 目录；如需记录真实 Provider 联调证据，按 `docs/reference/research/spikes/` 规则落地并标注保留期限。

## 约束映射与验证路径

| 约束来源 | 规则 | 本方案落点 | 验证 |
|---|---|---|---|
| spec/005 §3 | 照片仅在用户明确触发时发送；UI 不直接调 AI；经 Provider 层 | 显式动作 + `PhotoWritingAssistActions` → AI service；无自动触发 | UI 状态机测试 + service 测试 |
| spec/005 §3 | API Key 只在 Keychain；服务层解析 | 复用现有 endpoint/Keychain 解析路径 | 沿用既有 Keychain 解析测试 |
| spec/005 §4.3 | 发送照片=高风险，需明确预览/确认 | 看图动作前展示请求预览（照片 included），简洁确认 | UI 测试断言预览含 photoAttachments |
| spec/005 §4.4 | 日志不得含照片、原文、请求体 | `ai_request_logs` 仅记 capability/prompt id/version/model/分桶/状态；operation 摘要非敏感 | 日志/摘要字段 allowlist 测试 |
| spec/005 §4.5 | AI 输出不覆盖用户原文，存为新对象/版本 | 产出为短生命周期 UI 状态，显式「采用」才插入 | UI 非破坏性测试 |
| spec/005 §4.7 / 169 | 图片理解默认关闭，由 preset+adapter+purpose+授权共同解析 | 复用 `imageInputEnabled` 门控；未启用→引导态 | service 门控测试 + UI 引导态测试 |
| 核心决策 #10 | 显式触发边界 | 仅本能力 included photoAttachments，其余能力仍 excluded | Core 投影回归测试 |
| spec/006 | 界面语言/母语/目标语边界 | 新增文案走本地化 key；母语草稿用 native code，目标语用 target code | 本地化 key 存在性测试 |

## 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIRequestPreviewProjection.swift`（新增 `photoWritingAssist` capability + `photoForWritingAssist` 视情况新增 content descriptor，或直接复用 `photoAttachments`）。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIRequestProjections.swift`（新增能力投影工厂；**不改** `alwaysExcludedContent`）。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/`：新增 `PhotoWritingAssistService.swift`（图片+文本请求、结构化解析）、`PhotoWritingAssistPromptRegistry.swift`（或扩展现有 registry）、共享图片能力门控判定。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextRequestAdapter.swift`（**新增 `structuredImagePromptBody`**——非复用 `imagePromptBody`；覆盖 Chat 与 Responses，带 image part + `response_format`/`json_schema` + 可配置 token 上限）。
- `Packages/LangoTraceData/Sources/LangoTraceData/`（**新增面向 AI 的脱敏降采样纯函数**，与 `PhotoImportPipeline` 共享 EXIF 剥离来源）+ `AppDatabase.swift` 新增 `photo_writing_assist_operations` migration + 对应 repository。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingView.swift`（看图动作、结果面板、引导态、隐私文案）+ 新增 `PhotoWritingAssistActions.swift`（action seam）+ draft state 扩展。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`（新增/修订文案 key）。
- `LangoTraceApp/`（装配 `PhotoWritingAssistActions`、`AIRequestLogRecorder` 映射 `photoWritingAssist`、operation recorder）。

## 参考的代码文件路径

- `AIProviderConfigurationProbeService.swift`（图片门控顺序范式）。
- `LearningMaterialGenerationService.swift` / `LearningMaterialPromptRegistry.swift`（结构化请求、Prompt 登记范式）。
- `ReadingSelectionExplanationService` + `reading_ai_explanation_operations` + `ReadingExplanationOperationRecorder`（短生命周期结果 + 非敏感 operation 摘要范式）。
- `PhotoImportPipeline.swift`（EXIF/GPS 剥离、降采样产物来源）。

## 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`（新增 §：photo writing assist 边界 + photoAttachments 从全局 always-excluded 收敛为「仅本能力 included」+ 变更记录）。
- `docs/platform-page-inventory.md`（「照片写作」行：新增 AI 看图动作、修订「照片字节不发送 AI」表述为分动作；隐私文案变更记录）。
- `docs/prompts/photo-writing/photo-writing-assist.md`（新建 Prompt 登记）+ `docs/prompts/README.md` 索引。
- `docs/decisions/005-local-first-and-user-owned-providers.md`（复审标注：照片在显式触发下进入 AI 边界，符合决策 #10，不反转）。
- 视需要：`docs/architecture/notes/`（若识别出跨任务的图片请求/多 Provider 扩展提醒）。

## 实施方案

建议分阶段（pipeline，先打通隐私/契约骨架，再接 UI）：

**Phase 0（Core 契约 gate，先失败测试）**：在 Core 扩展 `AIRequestCapability.photoWritingAssist` 与其投影工厂；写回归测试断言 (a) `photoWritingAssist` 投影 included 含照片类别、excluded 含历史/音频/记忆/凭证/其它空间；(b) **全部四条现存投影**（`learningMaterialGeneration` 的 generation 与 analysis、`readingSelectionExplanation`、`practiceBacktranslationReview`）**仍排除照片**。PASS 后方可进入下游。

**Phase 1（adapter 结构化图片契约 + AI service + Prompt；含兼容性 gate）**：
- 先失败测试：`structuredImagePromptBody` 在 Chat / Responses 下同时携带 image part 与 json_schema（P0-1 揭示这是新契约，不是复用）。
- 兼容性 gate（spike/probe）：用项目内合成 `blue-square.png`（`Resources/AIProviderProbe/`，**不发真实照片**）验证「图片 + 结构化 JSON」能被 OpenAI-compatible 接受并返回可解析 JSON；FAIL 则记录并退回方案重定。
- 新增 `PhotoWritingAssistService` + 单 prompt（`mode` 切换）+ `docs/prompts/...`。`mode → strict schema` 映射策略需敲定（同一 prompt id、按 mode 选用两份 strict schema 表达 `suggestions` xor `source_draft`，见 P2-3），解析层按 mode 校验对应字段非空、拒绝缺字段/越界/非法枚举。
- 门控：复用共享图片能力判定；`imageInputEnabled=false` / adapter 不支持 → 明确门控错误；Anthropic/Gemini/mimo → 明确 unsupported。
- 图片字节来源为「新增面向 AI 的脱敏降采样产物」（见范围），不复用缩略图/原图。

**Phase 2（Data 摘要 + 日志）**：`photo_writing_assist_operations` migration + repository（仿 `reading_ai_explanation_operations`，记 mode/失败分类等非敏感字段）；App-Shell 新增 `photoWritingAssist` 入口（复用 `AIRequestLogRecorder` prebuilt `record(_:)` 或新增入口）记 capability/prompt/model/分桶/三态；与 operation 摘要职责不重叠。

**Phase 3（UI）**：照片写作页新增看图动作（经 `PhotoWritingAssistActions` 持可取消 Task，重复触发先取消旧任务）、请求预览简洁确认、结果面板（非破坏性「采用」才插入草稿）、未启用图片输入/不支持 adapter 的引导态（指向 AI Provider 设置开启图片输入）。
- **脱敏单一执行入口（P1-2）**：看图发送的图片必须经 `PhotoWritingAssistActions`/Data 脱敏降采样函数产出 base64；**View 不得把 `selectedImageData`（原始 PhotosPicker 字节）直接交给 AI service**，并加 seam 测试断言发送输入不是原始 picker 字节。
- **看图动作时序（P1-3，采纳方案 A）**：看图动作在 Entry 保存前即可用，但图片现场经与落库共享的同一脱敏降采样纯函数处理后再发送；不要求用户先建 Entry。
- 修订隐私文案为分动作准确文案。

**Phase 4（文档影响检查 + 收口）**：写回 spec/005、platform-page-inventory（含 L46）、prompts、ADR-005 复审标注；更正 `AIRequestPreviewProjection.swift` L8 过期注释；更新 `architecture/002-system-map`（新增「照片 → AI」数据流与边界收敛说明）；新增 adapter 契约扩展的 architecture note（见下）；按 review 机制做专项审查判断。
- **隐私文案原子化约束（P1-4）**：隐私文案 + `platform-page-inventory` L46 的修订，必须与「首个可从 UI 触发看图发送的提交」在同一原子变更内落地；service 层即使先合并，也必须处于无 UI 入口、无法被用户触发发送的状态，避免出现「代码能发照片、文案仍承诺永不发送」的可发布窗口。

## 严格方案自审核记录

审核日期：2026-06-24
审核方式：隔离审查（Plan 子代理只读审查，对当前代码逐条核验事实主张）+ 主会话汇总写回
审核轮次：第一轮（系统架构师）+ 第二轮（测试/安全/落地性）
代码快照：HEAD = a484b64，子代理核验与方案自述快照一致。

### 发现摘要（隔离审查，已全部写回方案对应章节）

与当前代码不符、必须更正的事实主张（已更正）：

- **P0-1｜「复用 `imagePromptBody` 产出结构化输出」不成立。** 证据：`AIProviderTextRequestAdapter.swift` 的 `imagePromptBody` 纯文本、无 `response_format`/`json_schema`、`max_tokens` 极小（probe 传 8）；结构化只存在于无图片的 `structuredCompletionBody`。影响：v1「看图 + 结构化」是新 adapter 契约，非复用，工作量被低估。已写回：范围/Phase 1 改为新增 `structuredImagePromptBody` + adapter 单测 + 兼容性 gate。阻塞实现：是。
- **P0-2｜「现存仅三能力、backtranslation 保留无投影」不成立。** 证据：`AIRequestProjections.swift` L135-178 `practiceBacktranslationReview` 已是活跃投影；Core L8 注释过期。影响：Phase 0 回归会漏锁。已写回：更正为四条活跃投影，Phase 0 全覆盖，实现期更正过期注释。阻塞实现：否（但必须写回）。
- **P1-1｜「复用 `PhotoImportPipeline` 降采样产物」不成立。** 证据：`stripGPS` 不降采样（原尺寸重编码），唯一降采样物是 256px 缩略图（为列表渲染，不适合 vision）。已写回：新增面向 AI 的中等尺寸脱敏降采样函数，不复用缩略图/原图。阻塞实现：是。

执行边界/契约缺口（已写回）：

- **P1-2｜脱敏单一执行入口。** `PhotoWritingView` 经 `loadTransferable` 直接持原始相册字节并经 `onSave` 外传；必须由 Data/AI 脱敏函数产 base64，View 不得直发原始字节，并加 seam 测试。阻塞实现：是。
- **P1-3｜看图动作与 Entry 生命周期时序未定义。** 已写回：采纳方案 A（保存前可用，现场经共享脱敏降采样函数）。阻塞实现：是。
- **P1-4｜隐私文案上线时序窗口风险。** 已写回 Phase 4：文案 + page-inventory L46 与首个可触发发送的提交原子化。阻塞实现：否（实施纪律）。
- **P1-5｜TDD 缺「图片+结构化 body」先失败测试。** 已写回 TDD。阻塞实现：否。
- **P1-6｜probe 与 assist 图片门控可能漂移。** 已写回：抽共享门控判定 + 一致性测试。阻塞实现：否。
- **P1-7｜取消/重入未落到 PhotoWritingView 状态机。** 已写回 Phase 3 + 取消/重入测试。阻塞实现：否。
- **P2-3｜mode→strict schema 映射需敲定。** strict 模式难表达互斥可选字段；已写回：按 mode 选用两份 strict schema（同 prompt id），Phase 1 固化。阻塞实现：否（实现前定）。
- **P2-4｜002-system-map 应更新、prompts 子目录索引。** 已写回文档影响检查。阻塞实现：否。
- **P3-1｜图片支持矩阵遗漏 mimo。** 已写回：v1 暂不纳入 mimo，与 `supportsImageProbe` allowlist 对齐。阻塞实现：否。

核验为**真**、方案无误的关键主张：`alwaysExcludedContent` 被所有现存能力共享且含 `.photoAttachments`（P0 隐私设计依据成立，方向正确）；`imageInputEnabled` 默认关 + normalization；门控顺序；Anthropic/Gemini 抛 `unsupportedProvider`；`reading_ai_explanation_operations` 范式与 App-Shell 双 recorder 存在；blue-square fixture 存在。

### 写回修改

- 现状描述更正三处事实（imagePromptBody / 四能力 / 缩略图非降采样）。
- 范围与实施方案改为「新增结构化图片请求体」「新增面向 AI 脱敏降采样」「共享门控」「mimo 暂不纳入」「时序方案 A」「脱敏单一入口」「文案原子化」。
- TDD 增加结构化图片 body、脱敏入口、取消/重入、四能力回归、门控一致性用例。
- 文档影响检查升级 002-system-map 为必更；新增 architecture note。
- 剩余风险新增结构化图片兼容性。

### 跨任务提醒（写入 docs/architecture/notes/）

- 「结构化输出 + 图片输入」的 adapter 契约扩展是跨能力基础设施；已创建 `docs/architecture/notes/` 备忘录记录统一图片请求体形态与 Provider 兼容性待验证项。

### 用户已确认的关键决策

三项关键决策已于 2026-06-24 由用户确认（见「用户确认记录」）：

1. 交付范围 → 先只交付方案（Draft，不实现）。
2. 隐私文案 → 修订为分动作准确文案（不 blank-delete）；上线时序随 AI 能力一并落地（保持上线前文案仍真实）。
3. v1 产出模式 → 写作提示 + 母语草稿两种都做，共用一个 prompt + `mode` 切换（对应 P1-1 定型）。

进入实现前无其它阻塞性待确认项；仅需用户在准备实现时显式授权将状态推进到 `User Approved`。

### 是否允许进入实现

隔离审查确认的 P0/P1 已全部写回方案对应章节，方案已具备进入实现的事实地基。但按用户决策，当前仅交付方案，保持 `状态：Draft`、`自审核状态：Reviewed`。后续用户显式授权实现并推进到 `User Approved` 后方可进入生产代码实现。

实现期硬约束（必须遵循）：
- P0-1：新增结构化图片请求体（非复用 `imagePromptBody`），并先过兼容性 gate。
- P1-1：新增面向 AI 的脱敏降采样产物，不复用 256px 缩略图、不发原图。
- P1-2：脱敏单一执行入口，View 不得直发原始 PhotosPicker 字节。
- P1-3：看图动作时序按方案 A，共享同一脱敏降采样纯函数。
- 隐私底线：保留 `alwaysExcludedContent` 不变，仅 `photoWritingAssist` 投影含照片；Phase 0 回归锁定其余四投影仍排除照片。

## 复查方法

- Phase 0 完成后跑 Core 投影回归测试，确认其它能力仍排除照片。
- 实现期对照 spec/005 §3/§4.3/§4.4/§4.5/§4.7 逐条核验。
- 收口前做 plan-vs-shipped 对账（work item 是否有代码/测试/文档/Prompt 登记）。

## TDD / 测试落点

- **Core**：`Packages/LangoTraceCore/Tests/.../AIRequestPreviewProjectionTests`（或新增文件）——
  - 先失败用例：`test_photoWritingAssist_projection_includesPhotoAttachments_excludesOtherSensitive`；
  - 回归用例：`test_existingCapabilities_stillExcludePhotoAttachments`，**显式覆盖全部四条投影**（learningMaterial generation、learningMaterial analysis、reading、backtranslation）。
- **AI**：`Packages/LangoTraceAI/Tests/...`——
  - **先失败（P0-1 关键契约）**：`test_structuredImagePromptBody_carriesImageAndJSONSchema_forChatAndResponses`，先失败原因＝方法不存在 / body 缺 image part 或缺 `response_format`；
  - `test_photoWritingAssist_rejectsWhenImageInputDisabled`；
  - `test_photoWritingAssist_unsupportedAdapter_returnsUnsupported`（anthropic/gemini/mimo）；
  - `test_imageCapabilityGate_probeAndAssist_shareSameAllowlist`（P1-6 防漂移）；
  - `test_photoWritingAssist_parsesAndValidatesStructuredOutput_perMode` / `rejectsMalformed`（P2-3 mode→schema）；
  - Prompt registry：`test_photoWritingAssistPrompt_idAndVersionRegistered`。
- **Data**：面向 AI 的脱敏降采样纯函数测试（输出尺寸/字节上限、EXIF 已剥离）；`photo_writing_assist_operations` migration + repository 测试（仅非敏感字段）；`ai_request_logs` capability 映射测试。
- **UI**：`Packages/LangoTraceUI/Tests/...`——
  - 看图动作在 provider 无图片能力/未启用时隐藏或禁用并显示引导；
  - 请求预览含「照片 + 备注」描述、不含其它敏感类别；
  - **脱敏入口（P1-2）**：`test_photoWritingAssist_sendsSanitizedImage_notRawPickerBytes`；
  - **取消/重入（P1-7）**：`test_photoWritingAssist_secondTriggerCancelsFirst`、`test_photoWritingAssist_cancelLeavesDraftUntouched`；
  - 结果「采用」非破坏性插入、不覆盖；
  - 新增/修订本地化 key 存在性 + 隐私文案防回归（断言不再是无条件「永不发送」）。
- 聚焦验证命令见下；不新增测试的部分（纯文案）说明原因与风险于实施记录。

## 验证命令

轻量验证（按改动 package 选择）：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/check-docs.sh
```

完整验证（仅在跨模块收口/合并前，按 CLAUDE.md §1.4 在 GitHub Actions 跑，必要时临时设 public）：`scripts/verify.sh`。

## 文档影响检查

- spec/005：必更新（新增能力 + 照片排除边界收敛 + 变更记录 + 是否需要 ADR 结论：否，沿用 ADR-005）。
- platform-page-inventory：必更新（照片写作 L46 行 + 变更记录；与首个可触发发送的提交原子化）。
- prompts：必新增登记（新建 `docs/prompts/photo-writing/` 子目录 + README 索引）。
- ADR-005：复审标注（不反转，记录决策 #10 适用）。
- **architecture/002-system-map：必更新**（本能力是首个把照片纳入 AI 请求边界的能力，属系统地图「关键数据流 / 安全边界」，需新增「照片 → AI」数据流与边界收敛说明）。
- **architecture/notes：新增 adapter 契约扩展备忘录**（「结构化输出 + 图片输入」是跨能力基础设施，未来 OCR / 图片问答都会用；记录统一图片请求体应可携带 `response_format`/schema 与可配置 token 上限，及 Responses `input_image`+`json_schema` / Chat `image_url`+`response_format` 的 Provider 兼容性待验证项）。已随本方案创建：`docs/architecture/notes/2026-06-24-multimodal-structured-request-adapter-notes.md`。
- 代码注释治理：实现期更正 `AIRequestPreviewProjection.swift` L8 过期注释。
- review 机制：AI Provider / 隐私 / 首次发送照片属高风险，收口后按 `docs/review/README.md` 触发专项审查或在本方案说明跳过原因。
- testing、release：初判无需更新，收口时复核。

## 实施记录

实施分支：`feat/photo-writing-ai-assist`（从 `dev` 切出）。代码快照 HEAD = a484b64。

- **Phase 0（commit b5df95c）**：Core 新增 `AIRequestCapability.photoWritingAssist` + `AIRequestPreviewProjection.photoWritingAssist(endpoint:lengthBucket:)`（唯一 included 含 `.photoAttachments`，excluded 由 `alwaysExcludedContent` 去掉照片派生）；更正过期注释；回归测试锁定四条现存投影仍排除照片。验证：`swift test` Core 238、AI 165 全绿。
- **Phase 1（commit c04c5bb）**：adapter 新增 `structuredImagePromptBody`（Chat/Responses 图片 + json_schema；协议默认 nil 使 mimo/未来 kind 结构性不支持）；新增 `PhotoWritingAssistService`（单 prompt + mode 两份 strict schema、门控顺序、结构化解析）；`SanitizedAIImage` 为 AI 边界唯一图片形态；`AIProviderImageSupport` 单一 allowlist 供 probe/assist 共用；Core 失败桶映射。验证：Core 238、AI 180 全绿。
- **Phase 2（commit ec2e26f）**：Data 新增 `AIImageSanitizer.sanitizeForAI`（降采样 maxEdge 1024 + JPEG 质量回退至字节预算；ImageIO 缩略图重渲染天然剥离 EXIF/GPS），单一脱敏入口（P1-1）；`ai_request_logs` 经 rawValue 自动支持新 capability（新增 round-trip 测试，无需 schema 变更）。验证：Data 241 全绿。
- **Phase 3（commit 05ce771）**：照片写作页新增显式「让 AI 看图帮我写」动作（模式切换 + 发送前确认 + 非破坏性结果面板 + 未启用图片输入引导态）；`PhotoWritingAssistViewModel` 状态机带 generation 令牌防陈旧任务回写（P1-7），脱敏单一入口经 `actions.sanitizeImage`、View 不直发原始字节（P1-2，seam 测试断言）；隐私文案改为分动作准确表述；App Shell `PhotoWritingActionsAssembly` 接 `AIImageSanitizer` + `PhotoWritingAssistService` + 端点解析 + `ai_request_logs`。验证：Core 238、AI 180、Data 241、UI 566 全绿；改动文件 `swiftformat --lint` 0、`swiftlint` 仅 warning（与既有 adapter 同类，CI 无 `--strict`）、Han 守卫通过。
- **Phase 4（本提交）**：文档写回——spec/005（§3 强制规则 + §4.8 新边界 + 变更记录）、platform-page-inventory（L46 行 + 变更记录）、新建 `docs/prompts/photo-writing/photo-writing-assist.md` + README 索引、ADR-005 复审记录（不反转）、architecture/002-system-map §4.8「照片 → AI」数据流。`scripts/check-docs.sh` 通过。全量验证（三端构建 + LangoTraceAppTests + verify.sh）走 GitHub Actions（PR + Build & Test 绿勾）。

> 说明：App-Shell（`PhotoWritingActionsAssembly`、`AppEnvironment` 接线）按 CLAUDE.md §1.4 不在本机做重 xcodebuild，由 CI 的三端构建 + `LangoTraceAppTests` 验证；其代码严格镜像现有 `makeReviewBacktranslation` 的端点解析 / secret / 日志范式。

### Deferred（v1 不实现，已记录入口，非静默裁剪）

- **`photo_writing_assist_operations` 专用摘要表**：v1 暂不实现。理由：`ai_request_logs` 已提供按 capability 的非敏感逐请求透明度（capability/status/prompt/model/分桶/三态），隐私底线由「投影 + 日志列级 allowlist」保证（均已落地），CLAUDE.md §1.1/§1.2 允许 v1 限定功能范围而保留边界。专用表相对 `ai_request_logs` 仅多出 `mode` 维度与独立保留策略，非用户可见、非隐私必需。后续如需 `mode` 级摘要或独立保留策略，按 `docs/workflows/add-storage-migration.md` 新开 slice，仿 `reading_ai_explanation_operations`。本次 spec/005 写回会标注该边界与延后入口。

## 完成标准

- Phase 0 契约 gate 通过，且现存能力照片排除回归测试为绿。
- AI 看图辅助写作能力在 OpenAI-compatible + 用户已启用图片输入时可用，产出非破坏性；门控/不支持/失败态有明确 UI。
- 照片发送走脱敏产物；请求预览准确表达照片被发送；日志/摘要无敏感内容。
- 隐私文案修订完成且不再做无条件「永不发送」承诺。
- spec/005、platform-page-inventory、prompts 登记同步更新；ADR-005 复审标注完成。
- 轻量验证全绿；文档检查通过。

## 剩余风险

- **结构化图片 Provider 兼容性（P0-1 衍生）**：「图片 + `response_format`/json_schema」能否被各 OpenAI-compatible 聚合层接受、Responses `input_image`+`text.format=json_schema` 与 Chat `image_url`+`response_format` 能否共存，均未验证；由 Phase 1 兼容性 gate（合成图）先行验证，FAIL 退回方案。
- Provider 图片输入兼容性差异（不同 OpenAI-compatible 聚合层对 `image_url` data URL 支持不一）；通过明确失败分类与引导态缓解，真实联调可能需 spike。
- 母语草稿质量与「可翻译性」依赖 Prompt 调优；v1 接受质量不稳，后续迭代 Prompt 版本。
- 大图 base64 请求体体积/超时；设尺寸与字节上限。
- 隐私认知风险：用户需清楚「看图动作=照片外发」；靠显式动作 + 预览确认 + 准确文案三重表达缓解。
- 一旦放宽不变量，未来新增能力可能误复用照片边界；通过 Phase 0 回归测试 + spec 明文边界锁定。
