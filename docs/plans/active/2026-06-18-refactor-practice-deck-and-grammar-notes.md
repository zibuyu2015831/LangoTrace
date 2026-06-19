# 跟读页两处优化：底部控制台去冗余边框 + 修复讲解笔记生成链路

状态：Implemented
自审核状态：Reviewed
类型：refactor（UI + AI/Prompt）
创建日期：2026-06-18
最后更新日期：2026-06-18
代码快照（创建时）：`0469c98373d1a0a673b2e027b7d6e809cccdd7d6`
关联分支：`refactor/practice-deck-and-grammar-notes`（PR 合并到 `dev`）

## 1. Context（为什么做）

iPhone 17 模拟器验收跟读单句页后，用户提出两点：

1. **底部控制台「内边框」显冗余**。`PracticeControlBar` body 以 `.langoPanel(padding: 14)` 收尾，`langoPanel`（`LangoTraceDesign.swift:356`）= elevatedPaper 填充 + 圆角 + 1px hairline 描边。该面板嵌在 `controlDeck(session:)`（`PracticeSessionViews.swift:370-410`）内，deck 自身已有 elevatedPaper 背景 + 顶部 hairline。面板填充与 deck 同色 → 唯一可见物是冗余描边，形成「卡片套卡片」，与 `platform-page-inventory.md` L54 记载的「避免卡片套卡片」设计意图相悖。

2. **「查看讲解」按钮疑似被删**。经核实未被删除：`PracticePromptCard` 的 explanation toggle 自 2026-05-26 起就由 `note != nil` 门控（note ← `sentence.grammarNotes`），6-18 舞台重构未动该逻辑；`main` 落后 dev 509 commit、练习页根本不在 main 上。当前句子只显示「查看释义」的真因是 **AI 生成返回了空的 `grammar_notes`**——`generationSystemPrompt` 从不要求逐句产出讲解、provider schema 的 `grammar_notes` 无 `minItems`、本地校验也接受空数组（`count <= 3` 对 0 成立）；Prompt 文档只写「at most N」、无下限。

目标：(A) 移除冗余内描边让 deck 更清爽（三端共用，自动覆盖 iPhone/iPad/macOS）；(B) 修复生成链路使每句稳定产出讲解笔记，用户重新生成材料后「查看讲解」自然出现。门控逻辑「有笔记才显示」保留不变（数据驱动、优雅降级）。

## 2. Change A — 移除控制台冗余面板描边（UI）

文件：`Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`

- 把 body 末尾 `.langoPanel(padding: 14)` 替换为无填充无描边的 `.padding(.vertical, 14)`（保留竖向呼吸感；横向由 deck 的 `.padding(.horizontal, 24)` 提供）。直接删除会同时丢掉 14pt 内距，使主按钮与句间导航过近，故仅去描边、保留竖向 inset。
- 保留 `.tint(LangoTraceDesign.ColorToken.primaryActionFill)`（`AppearanceSettingsTests.swift:134` 断言此文件含 `primaryActionFill`）。
- 次按钮 `.bordered` / 主按钮 `.borderedProminent` 不变。
- 作用域：`PracticeControlBar` 仅被 `controlDeck` 调用，经 `PracticeSessionView` → `PracticeShadowingSessionView` 三端共用。

## 3. Change B — 修复讲解笔记生成链路（AI/Prompt）

代码：
- `LearningMaterialPromptRegistry.swift`：在 `generationSystemPrompt` 和 `analysisSystemPrompt` 各加一条要求——analysis.sentences 每句至少一条有价值的 grammar_note（`point_native` + `explanation_native`，母语书写）；句子简单时给最相关的一点；不得返回空 grammar_notes 数组。
- `LearningMaterialGenerationService.swift`：`sentenceSchema()` 的 `grammar_notes` 数组加 `"minItems": 1`（generate + analyze 共用）。本地校验保持宽容（不在 `validatedSentenceAnalysis` 加 ≥1 硬要求），非合规 provider 返回 `[]` 时优雅降级。

文档：`docs/prompts/learning-material/one-tap-learning-material.md`
- 全部四个 prompt 块（Generate EN/ZH、Analyze EN/ZH）补「每句至少一条 grammar_note」指令。
- Generate + Analyze 两处 JSON Schema 的 grammar_notes 加 `minItems: 1`。
- 新增版本记录条目（2026-06-18），保持 prompt id / version / schema_version 不变（比照 2026-06-11 先例：收紧既有契约字段、非 schema 变更）。

不改动（确认保留）：`PracticePromptCard` 的 `shouldShowExplanationToggle = note != nil` 门控、`LearningContentStore` 的 grammarNotes 拼接、`PracticeBacktranslationSessionView` 的 grammarNotes 渲染。

## 4. TDD 落点

- Change A：`PhoneIOSConvergenceTests.swift` shadowing 测试加载 `PracticeControlBar.swift`，断言 `!contains(".langoPanel(")` 且 `contains(".padding(.vertical, 14)")`。
- Change B：`LearningMaterialGenerationServiceFixtures.swift` 加 `func jsonBodyInt(_:) -> Int?`；`LearningMaterialGenerationServiceTests.swift` 断言两个 `.system` 含新指令子串，并用真实序列化请求体断言 `grammar_notes.minItems == 1`。

## 5. 验证

- 本机轻量：`swiftformat`、`swiftlint --no-cache`、`scripts/check-docs.sh`、`git diff --check`。
- 聚焦单包：`swift test --package-path Packages/LangoTraceAI`、`swift test --package-path Packages/LangoTraceUI`。
- 重测试走 GitHub Actions：三端 build + 全量单包测试 + lint，`Build & Test` 绿勾后 PR 合并到 `dev`。
- 人工视觉验收（用户）：重建重装 iPhone 17 模拟器，确认 (A) 控制台无内描边、间距正常；(B) 对已重新生成含讲解的材料，跟读页出现「查看讲解」并可展开。

## 6. 自审核记录（plan-review-protocol，Plan 子代理对抗校验）

- A 隐患：裸删 `langoPanel` 丢竖向内距 → 改为 `.padding(.vertical, 14)`（P1，已修正）。
- A 连带测试：两处 `.langoPanel(padding: 14)` 断言指向 PhoneMainSupportingViews(L199)/LearningContentComponents(L381)，不受影响；`AppearanceSettingsTests` 要求保留 `primaryActionFill`（已标注，P1）。
- B 版本策略：保持 version=="1" 合规（spec 005 同步规则非强制递增；2026-06-11 先例）（P2）。
- B provider 风险：三个 adapter 透传 schema，`minItems` 对 OpenAI strict 有效；OpenRouter/自定义兼容端 model-dependent → 由本地校验宽容兜底（P1，保留 step 3）。
- B 质量风险：指令措辞「至少一条有价值的笔记／简单句给最相关一点」降低 filler（P2）。
- B 测试可达性：schema helper 为 private，须经真实序列化请求体断言；现有访问器只返回 String/[String]，须新增 `jsonBodyInt`（P1，已纳入）。
- 隐私（spec 005/008）：仅改输出形状，不改发送内容与日志 allowlist，无新边界、无需 ADR。
- 文档落点：doc 两处 schema + 四个 prompt 块都要改（P1）。

## 7. 剩余风险

- 旧材料（修复前生成）仍可能无讲解，需用户对该材料「重新分析」/重新生成后出现按钮——符合「修复生成链路」语义，不做历史数据迁移（早期阶段，CLAUDE.md §1.1）。
- 自定义 OpenAI 兼容端若忽略 `minItems`，退回 prompt 指令引导 + 优雅降级。

## 8. 实现记录

- 本机轻量自查：swiftformat（改动文件 0 需格式化）、swiftlint（413 warning / 0 serious，无新增于改动文件）、check-docs ok、git diff --check clean、`swift test --package-path Packages/LangoTraceAI` 163 测试全绿（含新增 prompt 指令子串断言与 `grammar_notes.minItems == 1` 断言）。
- CI：PR #2 `Build & Test` run `27771443586` 成功（三端 build + UI 单包 + 全量测试 + lint 全绿）。
- 合并：PR #2 经绿勾合并到 `dev`，merge commit `60e0454`，feature 分支已删。
- 视觉验收：iPhone 17 模拟器已重建 + 重装，交由用户人工验收（控制台无内描边、间距正常；对已重新生成含讲解的材料出现「查看讲解」）。验收通过后将本方案移入 `docs/plans/done/`。
