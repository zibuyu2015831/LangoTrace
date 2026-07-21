# 任务方案：LM03-S4a —— Style 受控片段注入 + 认知风格 i+1 下投影

状态：Done（2026-06-27 用户授权 → TDD 落地 → 全量 CI 绿 run 28256888515 → §17 回写）
自审核状态：Reviewed（见 §11）
类型：feature
创建日期：2026-06-27
最后更新日期：2026-06-27
所属系列：语伴（LM03）→ S4（v2）拆 S4a（本片：Style 注入）/ S4b（Anthropic，已 Done）
上游决策：[`active/2026-06-25-docs-lm03-companion-decomposition.md`](2026-06-25-docs-lm03-companion-decomposition.md) §LM03-S4a；ADR-006 §6（Style 外发闸）/ §12；ADR-008（语伴定位）；idea-01 §13.5/§13.9（i+1 下投影）；idea-03 §3.11
Workflow：[`workflows/add-prompt.md`](../../workflows/add-prompt.md)（新增受控 prompt 片段）

## 1. 背景与定位

语伴系列最后一片。把 **LM02-S2 的 surface Style 印记**（学习者母语写作的句长 / 词汇丰富度 / 正式度三项聚合指标）经 **Ability band 的 i+1 下投影**注入语伴 system prompt，让语伴回复匹配学习者**语域**（register），同时**不把母语复杂度强加给初学者**。

**2026-06-27 用户决策（本片两 fork）**：
1. **Consent**：**复用 `companion_threads.uses_learner_profile`**（Memory + Style 一闸，无新 migration），语义澄清为「使用我的学习者画像（Memory + Style）」。
2. **i+1**：**正式度镜像 + 复杂度按 band 封顶（完整 i+1）**——注入正式度语域让语伴匹配；句长/词汇丰富度作倾向描述但**经 band 只读封顶**，不超学习者当前目标语水平。

**§9 时机**：已收口 = A（现在注入 v1 surface Style）。

## 2. 前置（全部 BUILT，调查 2026-06-27）

| 前置 | 状态 | 事实源 |
| --- | --- | --- |
| LM02-S2 Style | ✅ seam-only Done | `LearnerStyleProvider.styleImprint() -> StyleImprint`（surface metrics 三项、系统级按母语码分组、compute-on-read、**无 migration**）；`GRDBLearnerStyleProvider` |
| Ability band（i+1 ceiling） | ✅ Done | `LearnerBandProvider.band(languageCode:seedLevel:) -> LearnerBand`（`.estimatedLevel: LanguageLevel`）；**只读，仅 SELECT `dictionary_lookup_events`，绝不触 `derive()` 写路径** |
| 注入接缝 | ✅ Ready | `CompanionPromptRegistry.systemPrompt(...)` 已有 `memoryContext`/`broughtInRecords`/`conversationMemory` 参数 + `<<<MEMORY>>>` 块模式可平行 |
| 两层 consent | ✅ Done（S2b-1） | `CompanionMemoryConsent`（全局）+ `companion_threads.uses_learner_profile`（per-conversation，v32）+ `CompanionInjectionGate.shouldInject(consent:threadUsesProfile:)` |
| 预览披露 | ✅ Ready | `AIRequestContentDescriptor`（Core）+ `AIRequestProjections.companionConversation(hasMemoryInjection:hasBroughtInRecords:)`（AI）|

## 3. 设计

### 3.1 投影管线（i+1 下投影核心）
**纯函数投影**把 surface 指标 + band 量化为受控描述符，跨包契约清晰、可单测：

- **Core**：新值类型 `CompanionStyleDescriptor`（`formality: CompanionStyleFormality`〔formal/neutral/casual〕、`nativeElaboration: CompanionStyleElaboration`〔concise/moderate/elaborate，由句长+词汇丰富度量化〕、`complexityCeiling: LanguageLevel`〔= band.estimatedLevel，i+1 封顶〕）。纯值类型。
- **LearnerModel**：`CompanionStyleProjection.project(imprint:band:minimumSampleCount:) -> CompanionStyleDescriptor?`——按当前空间母语码 filter `imprint.groups`，**evidence 不足（sampleCount < 阈值，默认 3）或无 qualifying group → 返回 nil（不注入）**；`formalityTendency` double 量化为 formality 枚举；句长+词汇丰富度量化为 elaboration；`complexityCeiling = band.estimatedLevel`（band 信号稀疏时其自身回退 seed=space.level）。LearnerModel 可见 Core 类型 + StyleImprint，依赖方向正确。
- **AI**：`CompanionPromptRegistry.systemPrompt(..., styleDescriptor: CompanionStyleDescriptor? = nil)` 渲染 `<<<STYLE>>>` 受控块 + 新 directive `.styleGroundedPersona`。块文本（英文、injection-safe、reference-only）：「The learner's native-language writing tends toward [formal/casual] register and [concise/elaborate] phrasing. Mirror that register where natural, but keep your replies at [ceiling] level — never impose native-language complexity beyond their current target-language ability.」
- **App**（`AppEnvironment+Companion.swift`）：send 时复用 `CompanionInjectionGate.shouldInject` 同一门（gate 开 → Memory + Style 同时装配）；gate 开时读 `GRDBLearnerStyleProvider.styleImprint()` + `GRDBLearnerBandProvider(reader:blindSpotProvider:GRDBLearnerBlindSpotProvider(reader:)).band(...)` → `CompanionStyleProjection.project` → 传 `styleDescriptor` 给 `engine.reply`。

### 3.2 engine 透传
`CompanionConversationEngine.reply(..., styleDescriptor:)` + `assembleRequest` 透传到 `systemPrompt`（平行 `memoryContext`）。

### 3.3 band 仅用于 Style ceiling（防 scope 蔓延）
**S4a 引入 band 仅为 Style 复杂度封顶**；语伴整体 `proficiencyLevel` 仍读 `space.level`（「难度基线 v2 = band」是 decomposition 另记的独立未来项，不在本片）。band 信号稀疏时 `estimatedLevel` 回退 seed，故 ceiling 自然不低于无信号态。

### 3.4 预览披露
- Core `AIRequestContentDescriptor` 加 `.curatedLearnerStyle`（included 类）。
- AI `AIRequestProjections.companionConversation(..., hasStyleInjection: Bool = false)` → 命中加 `.curatedLearnerStyle`。
- App 一次性 consent 预览 `memoryPreviewProjection` 现披露**学习者画像 = Memory + Style**（`hasMemoryInjection: true, hasStyleInjection: true`）。

## 4. 隐私边界（ADR-006 §6 Style 外发闸 / 决策 #10）

- **系统自动注入外发**，受 ADR-006 §6 + 决策 #10：满足 = 复用 S2b-1 两层 consent（全局首次预览 + per-conversation 开关）+ 最小发送 + 一次性预览披露。**不新增 consent 门**（用户定：Memory+Style 一闸）。
- **Style 块零原始用户内容**：注入的是**枚举派生的英文类别**（formal/casual、concise/elaborate、band 等级），**非母语原文、非原始指标数值** → PII 风险远低于 S2b-1 Memory（注入真实生活事实）。**故 Style 块无需 PII scrub**（无可脱敏内容）；最小发送 = 仅语域类别 + ceiling。
- **预览诚实**：一次性预览披露 Memory + Style；`.curatedLearnerStyle` included 披露。**当前 pre-release 无生产用户**（CLAUDE.md §1.1），consent 语义从「Memory」扩为「Memory+Style」不需强制重置已有 consent；预览文案据实更新即为完整性机制（自审 §11 已审议）。
- **band 红线**：只读 `band(...)`（仅 SELECT），**绝不触 `derive()` / hysteresis 写路径**；新增 band 红线守卫测试。

## 5. TDD 落点（先写失败测试，再最小实现）

### Core
1. `CompanionStyleDescriptor` + `CompanionStyleFormality` + `CompanionStyleElaboration`（新文件）。
2. `AIRequestContentDescriptor` 加 `.curatedLearnerStyle`。
- **测试**：descriptor 值语义；**`AIRequestContentDescriptor` 闭集新 case 须同步全部 exhaustive 消费点**（见 UI §P1）。

### LearnerModel
3. `CompanionStyleProjection.project(imprint:band:minimumSampleCount:)`（新）。
- **测试**：① formality double→枚举量化边界；② elaboration 量化；③ `complexityCeiling == band.estimatedLevel`；④ 无 qualifying group / sampleCount < 阈值 → nil；⑤ 多母语组按当前母语码选对组；⑥ **band 红线守卫**：投影 + band 读取不写库、不触 derive（复用既有 band-guard grep/行为测试模式）。

### AI
4. `CompanionPromptRegistry.systemPrompt(..., styleDescriptor:)` + `.styleGroundedPersona` directive + `<<<STYLE>>>` 渲染。
5. `CompanionConversationEngine.reply(..., styleDescriptor:)` + assembleRequest 透传。
6. `AIRequestProjections.companionConversation(hasStyleInjection:)`。
- **测试**：styleDescriptor 非 nil → 块present + 含 formality/ceiling 措辞 + reference-only 框架；nil → 无块、无 directive；descriptor 经 reply 流到 systemPrompt；`hasStyleInjection: true` → 投影含 `.curatedLearnerStyle`。

### UI（**P1：S3b-1 式闭集破坏，已上修**）
7. `AIRequestPreviewPresentation.label(for:)`（exhaustive switch，行 72）加 `case .curatedLearnerStyle: localizedString("requestPreview.content.curatedLearnerStyle")`——**不加则 enum 非穷尽编译失败**。`excludedDisclosureLabel`（行 99，有 `default`）无需改。
8. 一次性 consent 预览文案：Memory → 「Memory + 写作风格」；新本地化 key `requestPreview.content.curatedLearnerStyle`（en/zh）+ consent 预览 copy（en/zh）。
- **测试**：preview presentation 含 style 披露；**本机跑全量 UI（no-hardcoded-Han + exhaustive switch + band 守卫）**；新增 UI 源注释**英文**。

### App
9. `AppEnvironment+Companion.swift`：gate 开装配 styleImprint+band→project→styleDescriptor；预览披露 style。
- 预期 macOS app test 覆盖编译；App 不单测。

### Prompt Registry
10. 登记 `<<<STYLE>>>` 受控片段到 `docs/prompts/companion/`（新 `style.md`：英文/中文版、输入变量、输出契约、隐私边界=零原始内容）。

## 6. 故障与恢复矩阵

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| 无 Style 信号（新用户/母语写作不足） | `project` 返回 nil → 不注入，语伴正常 | LearnerModel 测试 |
| band 信号稀疏 | `estimatedLevel` 回退 seed=space.level，ceiling 不异常 | LearnerModel 测试 |
| gate 关 / consent 未启 | Style + Memory 均不注入 | App / gate 测试 |
| Style 数据异常 | `try?` 取不到 → nil → 不注入，不伪装 | App 装配（防御性） |

**无新网络路径**（复用既有流式/单发传输 + S1/S2b 隐私闸），故无新 Provider 故障类目。

## 7. 边界小结
- **无新 migration**（复用 `uses_learner_profile`）。
- **无新 `AIRequestCapability`**（复用 `.companionConversation`）。
- **新 `AIRequestContentDescriptor.curatedLearnerStyle`**（闭集 case → 同步 `AIRequestPreviewPresentation.label` exhaustive switch + 本地化）。
- **无新外发类目语义升级**：Style 是受 ADR-006 §6 约束的系统注入，但块内零原始内容、复用既有 consent 门。
- band 红线不碰（只读）。

## 8. 验证
- 聚焦：`swift test --package-path Packages/LangoTraceCore`、`Packages/LangoTraceLearnerModel`、`Packages/LangoTraceAI`。
- 全量 UI：`swift test --package-path Packages/LangoTraceUI`（Han/band/exhaustive 守卫；S3b-1 教训）。
- 完整：GitHub Actions `Build & Test`（三端 + macOS app test + 全包 + lint）。public→CI→private（默认先取得用户许可）。
- 本机一次只跑一个包 `swift test`（本会话教训：并发撞坏共享 module cache）。

## 9. 文档影响（§17 收口落点，实现后回写）
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：Style 注入受控片段 + 零原始内容 + 复用 consent 门 + i+1 ceiling。
- `docs/architecture/002-system-map.md` §4.x：companion Style 注入投影管线（Core descriptor / LearnerModel projection / AI 渲染 / App 装配）+ band 只读 ceiling。
- `docs/prompts/companion/style.md`（新）。
- `docs/platform-page-inventory.md`：语伴一次性预览披露 Memory+Style。
- `docs/idea/03-conversation-partner.md` §3.11 / idea-01 §13.5（i+1 v1 mapping 落地、§13.9 档位映射 v1 定义）/ 拆解 doc §S4a / 仪表盘。
- 审查：AI Provider 外发 + 请求预览边界 + 学习者画像 consent 语义扩展 → 按 `docs/review/README.md` 判断专项审查；无新 ADR（ADR-006 §6 已含 Style 外发约束，本片是其兑现）。

## 10. 剩余风险（授权时知情）
1. surface Style（3 聚合数）注入对语伴体验的实际增益有限——i+1 ceiling 主要价值是**防止**母语复杂度外溢；formality 镜像是主要正向信号。价值验证待模拟器人工体验。
2. i+1 档位映射（idea-01 §13.9 原 v2 待决）本片定义 v1 = formality 镜像 + ceiling=band.estimatedLevel；认知风格 v2（AI 校准）仍后置。
3. consent 语义扩为 Memory+Style：pre-release 无生产用户，不重置已有 consent；若未来有用户须在发布前评估是否需重新征得 Style consent（自审 §11 审议、记 review）。

## 11. 双轮隔离自审核记录（plan-review-protocol）

**轮次一（架构 / 正确性）**：
- **P0（band 红线）**：S4a 必须**只读** band，绝不触 `derive()` / hysteresis 写。已据调查确认 `GRDBLearnerBandProvider.band()` 仅 SELECT、零写；新增 band 红线守卫测试钉死。规避。
- **P1（跨包闭集破坏，S3b-1 式，已上修）**：`AIRequestContentDescriptor` 加 `.curatedLearnerStyle` **必然破坏** `AIRequestPreviewPresentation.label(for:)`（行 72 exhaustive switch）→ 计划内同步加 case + 本地化 key。**已上修，非 CI 才发现**（吸取 S3b-1/S4b 教训：闭集语义变更先扫全部 exhaustive 消费点；已确认 `excludedDisclosureLabel` 行 99 有 default 不破）。
- **P1（依赖方向）**：投影跨 Core(descriptor)/LearnerModel(StyleImprint+band)/AI(渲染)。projection 放 **LearnerModel**（可见 Core + StyleImprint），descriptor 放 **Core**（AI+LearnerModel 共见），AI 仅渲染——依赖方向正确，AI 不反依赖 LearnerModel。
- **P1（band 装配）**：`GRDBLearnerBandProvider` 需 `blindSpotProvider`；App 已有 `GRDBLearnerBlindSpotProvider(reader:)` 装配先例（`AppEnvironment+LearnerProfile`/`+ReadingLookupCapture`），直接复用。

**轮次二（隔离再审，对抗式）**：
- **consent 语义扩展是否需重新征得？**——`uses_learner_profile` 命名前瞻、用户已定一闸；Style 零原始内容、低 PII；pre-release 无用户。结论：不重置 consent，但**一次性预览文案必须据实改为 Memory+Style**（完整性机制）。记 §10.3 + review。**非 P0**（无用户 + 命名本含 Style）。
- **PII scrub 是否遗漏？**——Memory 注入须 scrub（真实事实含手机号/身份证）；Style 块仅枚举类别派生英文，**无原始用户内容可泄**，故无需 scrub。确认非遗漏。
- **scope 蔓延（band → 整体难度）？**——明确仅用于 Style ceiling，`proficiencyLevel` 仍 `space.level`；难度基线 v2=band 是独立未来项。已 §3.3 钉死。
- **Style ceiling 用 band 而整体难度用 space.level 是否矛盾？**——不矛盾：§13.5 要求 Style 应用经「当前 Ability」（band）下投影，正是 ceiling 的语义；band 稀疏回退 seed。可接受。
- **空 Style / 单 entry 误注入？**——`minimumSampleCount`（默认 3）+ qualifying group 缺失 → nil。规避过拟合微样本。
- **directive injection 安全？**——`<<<STYLE>>>` 块 reference-only 框架（仿 Memory），且内容为固定枚举派生英文，无用户自由文本拼入 → 无 prompt 注入面。

**自审结论**：单片 S4a 连贯、无需下拆。最高风险 = P0 band 红线（守卫钉死）+ P1 闭集破坏（已上修计划内）。i+1 v1 mapping 定义清晰、认知风格 v2 后置。升 **Reviewed**，待用户实现授权。

## 12. 收口记录（2026-06-27）

实现 commit `cc5c417`；全量 CI `Build & Test` 绿 **run 28256888515**（6 包 + 三端构建 + macOS app test + lint + docs）。

逐落点 TDD 落地：Core `CompanionStyleDescriptor` + `.curatedLearnerStyle` / LearnerModel `CompanionStyleProjection`（formality 量化 + elaboration 量化 + ceiling=band.estimatedLevel + sampleCount 阈值 nil + 主子标签匹配）+ band 红线守卫 / AI `<<<STYLE>>>` 渲染 + `.styleGroundedPersona` + engine 透传 + `hasStyleInjection` 投影 / UI `RequestPreviewCardModel.label` exhaustive switch 上修 + `requestPreview.content.curatedLearnerStyle` 本地化 / App 同 `uses_learner_profile` 门装配 styleImprint+band→project→styleDescriptor + 预览披露 Memory+Style。

**自审验证回填 / 实施期教训**：
- **P0 band 红线**：守卫源级 grep 一度**误伤自身注释**——`CompanionStyleProjection.swift` 注释里写「never touches `BandHysteresis` / `derive()`」恰含 grep 禁词 → 改写注释避开字面量 `bandhysteresis`/`derive(`。教训：解释「不用某禁词」的注释也会触发字面量 grep 守卫，措辞须避开。
- **P1 闭集破坏（计划内已上修）**：`.curatedLearnerStyle` 破坏 `RequestPreviewCardModel.label` exhaustive switch（行 72）+ 需本地化 key——**方案已提前列出、非 CI 才发现**；UI 测试误用类型名 `AIRequestPreviewPresentation`（实际方法在 `RequestPreviewCardModel`，文件名误导）→ 改正。
- **本机 module-cache staleness 复发**：加 Core 闭集 case 后，AI / UI 各自 `.build` 缓存旧 Core 模块致「cannot find `.curatedLearnerStyle`」假错；`rm -rf <pkg>/.build` 重建即过。复用本会话教训（Speech/Sync 同因）。
- **type-check 超时**：`<<<STYLE>>>` 渲染原为单条巨型 `+`-插值链触发 Swift type-check 超时 → 抽出 rawValue 到局部变量后秒过。
- **switch-expression 推断**：`elaboration` switch-表达式隐式 return 不推断 case 上下文 → 改 `if/return`。

**偏差**：无。认知风格 v2（AI 校准）按方案后置，非偏差。

**至此 LM03 语伴系列（S1→S2a→S2b-1→S2b-2→S3a→S3b-1→S3b-2→S4b→S4a）全部 Done。** 轻量验证：Core 280 / LearnerModel 71 / AI 254 / UI 625 绿。本片**无新 migration / 无新 AIRequestCapability / 无新外发类目语义升级**（Style 块零原始内容、复用 consent 门、band 只读）。
