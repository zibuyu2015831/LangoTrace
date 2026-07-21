# 任务方案：Gemini generateContent 文本适配（多轮 + 流式，图片后置）

状态：Verified
自审核状态：Reviewed
类型：feature
创建日期：2026-07-22
最后更新日期：2026-07-22

## 用户确认记录

- 本任务在 `FABLE-MISSION.md` 授权的自主运行中执行（§2 第 3 条 + §4 自批授权）。`geminiGenerateContent` 自 Core 枚举建立起即为 reserved 扩展点（ADR-005 用户自带 Provider 的兑现），spec/005 §224 明确「后续走 `docs/workflows/add-ai-provider.md` 接入」；本任务是该既定扩展点的兑现，不引入新决策，无需新增 ADR（沿 LM03-S4b Anthropic 先例）。

## 需求描述

`docs/README.md`「尚未完成」明确列有「Gemini 文本学习内容适配（`geminiGenerateContent` 目前仅 TTS / 枚举层存在）」。UI 侧 `.gemini` provider preset 已备齐（base URL / 默认模型 `gemini-2.5-flash` / `authHeaderKind = "x-goog-api-key"` / provider 级 policy 声明 text+JSON supported），但文本工厂对 `.geminiGenerateContent` 抛 `unsupportedProvider`，用户配置 Gemini 后所有文本能力（探针、学习材料、阅读解释、回译、语伴）全部不可用。本任务按 Anthropic Messages（LM03-S4b）五件套先例落地 Gemini 文本适配：纯文本、尽力而为 JSON、多轮 + 流式；图片与严格 responseSchema 后置。

## 现状描述（HEAD `9473a7e`，经接缝勘查子代理 + 主会话读协议核实）

- **先例全图（S4b）**：`AnthropicMessagesTextAdapter.swift`（adapter + `AnthropicResponseTextParser` + `AnthropicStreamDeltaExtractor` 单文件）；协议 `AIProviderTextRequestAdapter`（`AIProviderTextRequestAdapter.swift:48-128`）已含动态派发要求 `providerRequestHeaders(secret:)`（S4b 升格，修复 mimo 死 override）与 `streamingChatBody` / `streamContentDelta` / `structuredImagePromptBody`（默认 nil = 结构化不支持）；工厂 `:24-41` 对 `.geminiGenerateContent` throw（`:37-38`）；UI `AIProviderSettingsModels.swift:640-647` adapterKind 级 capabilityPolicy 五项全 false；图片单一事实源 `AIProviderImageSupport.swift:16` false。
- **关键接缝事实（主会话读码核实）**：`makeRequest(baseURL:secret:timeoutSeconds:body:)` 是 **extension-only**（`:185-213`），经 `any` 存在体调用为静态派发——struct 内「覆盖」是死代码（mimo 教训）；它用单一 `pathSuffix` 建 URL、body 内携带 `model` 键。
- **Gemini wire 契约与现有模型的两处不契合**：① model 在路径不在 body（`models/{model}:generateContent`）；② 流式用**不同方法名** `models/{model}:streamGenerateContent` 且需 `?alt=sse` query——固定 `pathSuffix` + 单 URL 构建无法表达。
- **鉴权唯一既定意图**：UI preset `authHeaderKind = "x-goog-api-key"`（`AIProviderSettingsModels.swift:435-436`）→ header 方式，非 `?key=` query。TTS 侧 Gemini 同为枚举占位无实现，不可作参考。
- **响应/流式形状**：非流式 `candidates[].content.parts[].text`；SSE `data:` 每块为完整 GenerateContentResponse JSON，delta = 同路径 text；无 `[DONE]`（`AIChatStreamingService` 已支持 EOF finish，Anthropic 先例）。
- **架构备忘录约束**：`2026-06-24-multimodal-structured-request-adapter-notes.md` L46 明确「不为 Anthropic / Gemini 提前实现图片或多模态请求体」。
- **保留 kind 耗尽问题**：全仓 7 处测试以 `.geminiGenerateContent` 作 unsupported/reserved fixture（`AIProviderTextRequestAdapterTests.swift:25`、`AIChatStreamingServiceTests.swift:81`、`LearningMaterialGenerationServiceTests.swift:347`、`PracticeBacktranslationReviewServiceTests.swift:160`、`ReadingSelectionExplanationServiceTests.swift:324`、`AIProviderConfigurationProbeServiceTests.swift:441`、`PhotoWritingAssistServiceTests.swift:184`）。Gemini 放行后闭集内不再有文本侧 reserved kind。
- spec/005 三处现状口径：L187（Gemini 探针明确暂不支持）、L206（图片仅 OpenAI 兼容）、L224（Gemini 保留扩展点）。architecture/002 §4.9 Provider 矩阵含「Gemini 仍 unsupportedProvider」行。

## 目标、范围和不做什么

目标：用户自带 Gemini API Key 后，文本探针（textReply / structuredJSON / languageSupport）、学习材料生成 / 重新分析、阅读解释、回译 critique、语伴多轮流式对话全部可用；隐私边界与请求预览行为与其他 Provider 完全一致。

范围内：

1. **URL 构建接缝（先决，隔离审核 P2-1 定案 = 显式参数）**：把 `makeRequest` 升格为**协议要求**并扩为显式签名 `makeRequest(baseURL:secret:timeoutSeconds:model:streaming:body:)`（默认实现忽略 model/streaming、行为与现状逐字一致，四个既有 adapter 零改动——沿 S4b 把 `providerRequestHeaders` 升格的先例）；AI 包内 6 个调用点机械补参（服务本就持有 model；仅流式服务传 `streaming: true`）。**不采用** body 内部标记方案（杜绝内部键漏上 wire 的整类风险）。Gemini 覆盖 `makeRequest`：复用 `AIProviderEndpointURLBuilder` 做 path join（免费继承尾斜杠 / 带路径 baseURL / 反代归一行为），path = `models/{model}:generateContent`（非流式）/ `models/{model}:streamGenerateContent`（流式），`alt=sse` 经 `URLComponents.queryItems` 追加并保留 baseURL 既有 query；`pathSuffix` 返回占位（仅满足协议）。model 输入做轻量归一（剥用户误输的 `models/` 前缀）。
2. **`GeminiGenerateContentTextAdapter`**（新文件，单文件三件套沿 Anthropic 形态）：
   - `providerRequestHeaders` → `["x-goog-api-key": secret]`（空/空白 secret 返回空字典）。
   - `plainPromptBody` / `structuredCompletionBody`：`contents[].parts[].text` + `systemInstruction`；结构化走 **尽力而为**——仅设 `generationConfig.responseMimeType = "application/json"`，**与 Anthropic 先例一致忽略 `structuredOutputName`/`schema` 参数**（格式指令依赖既有 Registry Prompt 自带内容，不由 adapter 合成任何未登记外发文本；严格 `responseSchema` 后置，见不做什么）。
   - `imagePromptBody`：返回占位体但**不放行**（`AIProviderImageSupport` 保持 false，路径不可达；与 Anthropic 现状一致）。
   - `streamingChatBody`：`contents` 多轮映射（user→user、assistant→**model**——Gemini 角色名差异必须映射）+ `systemInstruction`（流式与否由 makeRequest 的显式 `streaming:` 参数决定，body 不携带任何内部标记）；`streamContentDelta`：解析 SSE data JSON 的 `candidates[0].content.parts[].text`。
   - `outputText`：`candidates[].content.parts[].text` 拼接；`GeminiResponseTextParser` / `GeminiStreamDeltaExtractor` 独立枚举便于测试。
3. **工厂放行**：`.geminiGenerateContent` 移出 throw 组；throw 组耗尽后**保留 `unsupportedProvider` 错误 case**——放行后该 case 在生产代码暂无 producer，保留理由是未来 kind 的错误词汇表与各服务 catch 映射的稳定性（隔离审核 P2-3 修正：TTS 与 photo-writing 消费的是各自错误枚举，非本 case）。
4. **UI 放行**：adapterKind 级 capabilityPolicy `.geminiGenerateContent` 放行 `canProbeText` / `canProbeStructuredJSON`（image/tts/embedding 仍 false）。
5. **测试策略（保留 kind 耗尽的处置，经隔离审核 P1-1/P1-2 逐处钉死）**：
   - 工厂测试：`factoryRejectsReservedKinds` 删除并在实施记录说明（闭集全支持后该场景不存在；安全网转移为穷举 switch 的编译期强制），`factoryDispatchesSupportedKinds` 增 gemini 断言。
   - `AIChatStreamingServiceTests` reserved 用例：fixture 直接改 **`.mimoCompatibleChat`**——mimo 未覆盖 `streamingChatBody`（继承默认 nil，流式 defer 是记录在案的既定事实），原守护语义「无流式支持的 adapter 映射 unsupportedProvider」完整保留、零生产改动。**不做注入式改造**（服务构造无 adapter 注入 seam，为测试加注入属不必要生产改动）。顺带修正协议 `:146-147` 错误宣称「mimo override streamingChatBody」的注释。
   - `LearningMaterialGenerationServiceTests:347` / `PracticeBacktranslationReviewServiceTests:160` / `ReadingSelectionExplanationServiceTests:324` 三处 unsupported 用例：**删除并记录理由**——factory-throw → 服务分类映射在闭集内成为不可达 latent 分支（映射代码保留作未来 kind 词汇表）；三服务构造均只收 `httpClient`，无注入 seam，不为测试改生产构造。
   - `AIProviderConfigurationProbeServiceTests:441`：**重写为 gemini 正向用例**（本任务最有价值的服务级行为红测试）：textReply / structuredJSON 探针真发 HTTP（fake httpClient 收到 `x-goog-api-key` 头与 `:generateContent` URL）、imageUnderstanding == unsupported、speechSynthesis / embedding == notEnabled。
   - `PhotoWritingAssistServiceTests:184`：继续用 gemini（`structuredImagePromptBody` 仍 nil），放行后仍绿，不动。
6. **文档同批**（隔离审核 P2-6 补全）：spec/005 两处口径回写（L187 探针放行、L224 落地记录；**L206 图片范围无需改动**——gemini 结构化图片仍 unsupported）+ spec/005 底部变更记录节新增条目；architecture/002 §4.9 矩阵行 + **§1 L28「未完成」清单行**；`docs/README.md`「尚未完成」移除 Gemini 行；multimodal 备忘录补 Gemini 文本落地事实（图片仍禁）+ responseSchema 升级路径；随代码同批修正 stale 注释：probe service `:137-138`「(anthropic / gemini)」、协议 `:10-13` 错误枚举注释、`:110-117` providerRequestHeaders 注释、`:146` streamingChatBody 注释。

不做什么（登记去向）：

- **图片 / 多模态请求体**：备忘录 L46 明确禁止无能力驱动抢跑；`AIProviderImageSupport` 与 `structuredImagePromptBody` 保持不支持。
- **严格 `responseSchema` 结构化**：Gemini 原生 schema 为 OpenAPI 子集，与现有 strict JSON Schema 的转换（`additionalProperties` 等键差异）需独立验证；v1 尽力而为 + 服务层既有非法 JSON 拒收兜底（与 Anthropic 同级），升级路径写入 multimodal 备忘录。
- **Gemini TTS**（`geminiGenerateContentTTS`）：不动。
- **真实凭证 E2E**：无凭证环境；wire 形状由单元测试钉死，真实探针由用户后续手测（spec/005 探针即为此设计）。
- 无新 Prompt、无 migration、无新外发类目、无 Keychain 变化（凭证走既有 credential store）。

## 证据与决策依据

- 接缝勘查子代理报告（2026-07-22）+ 主会话对协议文件 `AIProviderTextRequestAdapter.swift:48-226` 的亲自核读（makeRequest extension-only 与 pathSuffix 单一性）。
- S4b done plan（`docs/plans/done/2026-06-27-feature-lm03-s4b-anthropic-messages-adapter.md`）：五件套结构、providerRequestHeaders 升格先例、跨测试破坏教训（fixture 6 处当场捕获）。
- `docs/workflows/add-ai-provider.md` §3 L37：「新增 Anthropic/Gemini 只需实现 streamingChatBody + streamContentDelta 并放行，不必重写行解析/流式服务」。
- UI preset 既定意图：`x-goog-api-key` header 鉴权、base URL `v1beta`、默认模型 `gemini-2.5-flash`。
- Gemini REST 契约（generateContent / streamGenerateContent?alt=sse、contents/parts、systemInstruction、role=model）：训练知识 + 与 UI preset base URL 一致性；wire 形状全部以单元测试固化，真实验证留给用户探针。

## 约束映射与验证路径

- 决策 8/9（Provider 抽象、凭证 Keychain 分离）：复用既有 seam，零新增敏感面。
- 决策 10 / spec/005（显式触发、预览只暴露类别）：Gemini 走既有服务层，无新外发类目；capability 描述符不变。
- spec/005 §4.4/§4.7（日志不含明文、cancel 非 failure）：adapter 层无日志；沿用服务层既有行为。
- workflow add-ai-provider §4：凭证不落 SQLite/日志、结构化输出拒非法 JSON、取消不写失败事件——由既有服务测试覆盖，Gemini 分支纳入同套断言。
- §1.4 TDD：见测试落点；红相位逻辑成立 + CI 实证（批次②③先例），调用点勘查用多行感知扫描（批次③教训）。

## 涉及的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/GeminiGenerateContentTextAdapter.swift`（新建）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderTextRequestAdapter.swift`（makeRequest 升协议要求 + 工厂放行）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`（capabilityPolicy 放行）
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderTextRequestAdapterTests.swift`（Gemini 套件 + 工厂用例调整）
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIChatStreamingServiceTests.swift`（reserved 用例改造 + Gemini SSE fixture）
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/{LearningMaterialGenerationServiceTests,PracticeBacktranslationReviewServiceTests,ReadingSelectionExplanationServiceTests,AIProviderConfigurationProbeServiceTests,PhotoWritingAssistServiceTests}.swift`（fixture 处置）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`（policy 断言校准）

## 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AnthropicMessagesTextAdapter.swift`（结构模板）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/ServerSentEventParser.swift`、`AIChatStreamingService.swift`（流式 seam，不改）
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderImageSupport.swift`（保持不动的单一事实源）

## 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`（L187/L206/L224 口径）
- `docs/architecture/002-system-map.md` §4.9（Provider 矩阵）
- `docs/README.md`（尚未完成清单）
- `docs/architecture/notes/2026-06-24-multimodal-structured-request-adapter-notes.md`（Gemini 文本落地事实 + responseSchema 升级路径）
- `FABLE-WORKLOG.md`

## 实施方案

1. 协议：`makeRequest` 升格为协议要求（默认实现原样保留在 extension；断言其余四 adapter 行为零变化的既有测试全绿即证）。
2. 新建 Gemini adapter 三件套 + 单元测试（TDD：先写 body/头/解析/流式断言）。
3. 工厂与 UI policy 放行 + 用例调整；七处 fixture 逐文件处置。
4. 文档同批回写。
5. 多行感知扫描复核调用点 → 提交带 `[ci]` → 观察 CI → 收口。

## TDD / 测试落点

（区分行为红 / 编译红；本环境红相位逻辑成立、CI 实证。）

- **AI 包新增 Gemini 套件**（`AIProviderTextRequestAdapterTests.swift` 内联，沿 Anthropic 形态；全部行为红）：
  - 鉴权头 = `x-goog-api-key` 且非 `Authorization`；空/空白 secret 返回空字典（`arguments: [nil, "", "  "]`）。
  - `plainPromptBody` 形状（`contents[0].parts[0].text`，无 `model` 键泄漏到最终 body——由 makeRequest 覆盖移除，单测直接测 makeRequest 产物 URL 与 body）。
  - `makeRequest` URL：非流式 `.../models/gemini-2.5-flash:generateContent`；流式 `.../models/gemini-2.5-flash:streamGenerateContent?alt=sse`；body 不含内部标记键。
  - `structuredCompletionBody` 含 `generationConfig.responseMimeType == "application/json"` + `systemInstruction`。
  - `streamingChatBody` 角色映射 assistant→`model`、system 走 `systemInstruction` 不入 contents。
  - `outputText` 解析 `candidates[].content.parts[].text` 拼接；空 candidates → nil（extractText 抛 invalidResponseBody）。
  - `GeminiStreamDeltaExtractor`：SSE data JSON 抽 text；非文本块返回 nil。
  - `structuredImagePromptBody == nil` 回归（图片仍禁）。
  - URL 细节两例（隔离审核 P2-5）：带路径前缀 baseURL（反代）经 builder 归一后拼接正确；URL 字面量含未转义 `:generateContent`（load-bearing：无 `alt=sse` 时 Gemini 返回 JSON 数组不可流式解析）。
  - model 归一：输入 `models/gemini-2.5-flash` 不产生双前缀。
- **工厂用例**：`factoryDispatchesSupportedKinds` 增 gemini（行为红）；`factoryRejectsReservedKinds` 删除并在实施记录说明（闭集耗尽）。
- **流式服务**：Gemini SSE 端到端 fixture（`data:` JSON 块 + EOF 无 [DONE]，行为红）；unsupported 映射用例按范围第 5 条策略改造。
- **UI**：**新增** gemini canProbeText/StructuredJSON == true 断言（行为红）；`AIProviderSettingsTests.swift:535-537` 的既有断言是**图片输入 decision**（`canProbeImageInput` 保持 false），**必须原样保绿，不存在可反转的断言**（隔离审核 P2-4 修正措辞，防实施误伤图片不变量）。
- **既有全套回归**：其余四 adapter 的既有测试即 makeRequest 升格的零行为变化守护（旧代码即绿，守护性质）。

## 验证命令

聚焦（CI 内等价步骤）：`swift test --package-path Packages/LangoTraceAI`、`swift test --package-path Packages/LangoTraceUI`。
完整：GitHub Actions `Build & Test`（HEAD 带 `[ci]`），conclusion=success 为准。

## 文档影响检查

- spec/005 三处口径、architecture/002 §4.9 矩阵、README 清单、multimodal 备忘录——确定交付，随代码同批。
- 无 schema / 权限 / 同步 / StoreKit 变化；AI Provider 变化属高风险类目，本 plan 即其专项影响检查载体（沿 S4b 先例，不另开 review round；不豁免未来 AI 层里程碑全审）。

## 严格方案自审核记录

```text
审核日期：2026-07-22
审核方式：隔离审查（独立 general-purpose 子代理，新上下文、只读，HEAD 9473a7e 核验）
审核轮次：双轮合并
未使用隔离审查的原因：不适用（已使用）
发现摘要：P0=0；P1=2（① 流式 reserved 用例 fallback「全闭集 streamingChatBody 非 nil」为假命题——mimo 未覆盖流式属既定 defer，且服务无注入 seam，应直接改 mimo fixture；② 四服务测试 + probe 测试处置不得推迟到实施时——三服务无注入 seam 应删除并记录理由，probe 用例应重写为 gemini 正向红测试）；P2=6（makeRequest 显式参数优于 in-band 标记、结构化明确忽略 schema 参数防未登记外发 Prompt、unsupportedProvider 保留理由修正、UI 图片断言不可反转、URL builder 复用与 alt=sse queryItems 细节、文档补 002 §1 L28 + spec/005 变更记录 + 四处 stale 注释）；P3=4（model 前缀归一、SSE 单行 JSON 依赖显式化、完成标准归因校准、L206 明示不改）。
关键核验：makeRequest 确为 extension-only（静态派发）；五条文本路径全部经 factory + makeRequest 无绕行（embedding/TTS 独立面不受影响）；probe 服务无独立 gemini allowlist（工厂即唯一闸门）；x-goog-api-key 无任何日志/诊断泄漏路径（DiagnosticEventAttribute 闭集无 header case）；spec/005 三行号准确；工厂 switch 本就穷举无 default；「CompanionStreamingTransport」实为 AIChatStreamingService（方案笔误已随核验更正认知）。
写回修改：范围 1（显式参数定案 + URL builder 复用 + alt=sse queryItems + model 归一）、范围 2（忽略 schema 参数）、范围 3（保留 case 理由）、范围 5（五处 fixture 逐处钉死）、范围 6（文档与注释补全）；TDD 落点补 URL 两例 + model 归一 + UI 断言措辞修正 + probe 正向用例；剩余风险补 SSE 单行依赖与安全网转移。
仍需用户确认的问题：无（reserved 扩展点兑现，自批授权范围内）。
是否允许进入实现：是（P1 修订已全部写回本方案）。
```

## 实施记录

2026-07-22 实施完成（自主运行，FABLE-MISSION 授权）：

- 提交序列：`36c22a2`（主批 21 文件 +719/-103：makeRequest 升协议要求 + 显式 model/streaming 参数、六调用点机械补参；`GeminiGenerateContentTextAdapter` 三件套；工厂放行〔穷举 switch，`unsupportedProvider` 留作未来 kind 词汇表〕；UI capabilityPolicy 放行 text/structuredJSON；七处 reserved fixture 逐处处置——流式用例改 mimo fixture、LearningMaterial/Backtranslation/Reading 三处 unsupported 用例删除留理由、probe 重写为 gemini 正向用例、photo-writing 保留 gemini〔structuredImagePromptBody 仍 nil〕、factoryRejectsReservedKinds 删除；Gemini 套件 13 例 + 流式端到端 SSE fixture + UI policy 断言；spec/005 / architecture/002 §1+§4.9 / README / multimodal 备忘录 / 四处 stale 注释同批回写）→ `835349c`（fix：正向探针图片状态断言 `.unsupported`→`.notEnabled`——服务判定顺序为未启用先于 adapter 不支持）。
- CI 证据：run 29862700137 仅一处红（上述断言）→ **run 29864585392 `Build & Test` conclusion=success（完整绿，与批次③合并验证）**。
- 红→绿：Gemini 全部行为红测试（鉴权头 / model-in-path URL / alt=sse / 反代 path join / model 归一 / body 形状 / 角色映射 / 解析 / 流式 delta / 图片仍禁 / probe 正向 / UI policy）与实现同批入库并经 run 29864585392 实证；其余四 adapter 既有测试零变化全绿（makeRequest 升格无行为回归的守护证据）。
- deferred 项按计划落备忘录：图片/多模态请求体（禁令继续有效）、responseSchema 严格模式升级路径（multimodal 备忘录 2026-07-22 更新节）。

## 完成标准

- Gemini 端点保存后文本/结构化探针可发起（UI policy 放行）；学习材料 / 阅读解释 / 回译 / 语伴走 Gemini 端点不再 `unsupportedProvider`。
- makeRequest 升格后其余四 adapter 既有测试零变化全绿。
- 七处 fixture 处置完毕且各自守护语义保留或有记录的理由。
- 文档四处同批回写；CI `Build & Test` success；plan 移 `done/`。

## 剩余风险

- Gemini wire 形状以训练知识 + 单元测试固化，无真实凭证 E2E；缓解：探针机制本就面向用户手测，形状错误会以明确探针失败呈现且不影响其他 Provider。
- `makeRequest` 升协议要求属闭集语义变更；缓解：默认实现不动、既有测试全绿守护，S4b 有同型先例。
- 保留 kind 耗尽后，「未来新增 kind 未实现即被工厂拒绝」的默认安全网消失；缓解：工厂 switch 本就穷举无 default，新增 case 编译期强制实现决策。
- `ServerSentEventParser` 不做 SSE 规范级多 `data:` 行拼接；`alt=sse` 实践为单行 JSON 块可解析，若 Gemini 改为分行则 delta 静默丢失；缓解：`?alt=sse` URL 断言 load-bearing + 流式端到端 fixture 钉形状。
- 完成标准措辞校准（隔离审核 P3-3）：探针可发起由**工厂放行**决定；capabilityPolicy 的 canProbeText/StructuredJSON 在 UI 无消费点，属声明性真值表 + 测试守护。
