# Practice Prompt Card Translation Disclosure Refinement Plan

> **For agentic workers:** Use TDD for code behavior changes. Keep this plan as the task control surface until verification is complete, then move it to `docs/plans/done/`.

状态：Verified
类型：feature
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图确认，当前单句练习页顶部 prompt card 在 `查看讲解` 下方预留了过大空白；同时希望新增 `查看释义` 按钮，中文释义点击后才出现。

本次设计已由用户明确确认：

- 目标语言句子默认常驻，保持最高视觉权重。
- 中文释义默认不显示正文，只显示 `查看释义` 入口。
- 点击 `查看释义` 后完整展示中文释义，再次点击收起。
- `查看讲解` 默认不展示讲解正文，且未展开时不得预留隐藏内容高度。
- 卡片默认高度应由真实可见内容自然决定，不再用大块固定 min-height 保持旧基准高度。

## 2. 需求描述

当前 `PracticePromptCard` 已将中文释义、目标句和讲解拆分为 prompt card，但它仍保留了两个与最新设计冲突的行为：

1. 短中文释义默认直接展示，用户无法先专注目标句。
2. 卡片使用 `PracticePromptCardLayout.collapsedMinHeight = 220`，当释义或讲解隐藏时仍保留较大空白。

## 3. 现状描述

当前代码位置：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

当前测试位置：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

当前文档位置：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`
- `docs/plans/done/2026-05-26-feature-practice-session-prompt-card-disclosure.md`

## 4. 目标

- `PracticePromptCardPresentation` 将“释义是否存在”和“释义是否可见”拆清楚。
- 只要存在非空中文释义，就显示 `查看释义` / `收起释义` 控件。
- 未展开时不渲染中文释义正文。
- 展开时完整渲染中文释义，不使用省略号作为唯一访问方式。
- 移除 prompt card 的大块 collapsed min-height，让默认态高度贴合可见内容。
- 保留 route identity 变化时重置释义和讲解展开状态。
- 保持 TTS、录音、回放、完成态和句间导航行为不变。

## 5. 范围

涉及代码文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

涉及测试文件：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

涉及文档文件：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`
- 本方案文档

## 6. 不做什么

- 不改 `PracticeSessionViewModel` 录音状态机。
- 不改 `PracticeActions`、GRDB schema、media artifact、TTS cache 或播放 coordinator。
- 不新增持久化偏好，不记住用户是否默认展开释义。
- 不把释义放到新页面或 sheet；第一版仍在当前卡片内完整展开。
- 不引入复杂展开动画。

## 7. 证据与决策依据

- 用户截图显示 `查看讲解` 下方大块空白来自 card 默认高度而非实际内容。
- 代码中 `PracticePromptCard` 使用 `.frame(minHeight: PracticePromptCardLayout.collapsedMinHeight)`，该固定高度与最新“保持页面简洁”的目标冲突。
- `PracticePromptCardPresentation` 当前只在长译文时显示 translation toggle，短译文默认显示正文；这与“点击查看释义后才出现释义”的要求冲突。
- Apple iPhone 交互要求按钮保持 44pt 触控目标；本次保留 toggle button 的 44pt 高度，但不为隐藏正文保留额外空间。

## 8. 实施方案

### Task 1: 写失败测试

- 修改 `PracticeRouteSeedTests`：
  - 覆盖有释义时默认只显示 `查看释义`，不输出可见释义正文。
  - 覆盖展开后完整输出释义正文，且 title key 切换为 `收起释义`。
  - 覆盖短释义也需要 `查看释义`，空白释义不显示 toggle。
- 修改 `PhoneIOSConvergenceTests`：
  - 明确禁止 `PracticePromptCardLayout.collapsedMinHeight` 和 `.frame(minHeight: PracticePromptCardLayout.collapsedMinHeight`。
  - 确认 prompt card 仍使用 translation / explanation accessibility hint。

### Task 2: 实施最小代码变更

- 在 `PracticePromptCardPresentation` 中新增 `displayedTranslationText` 或等价字段。
- 将 `shouldShowTranslationToggle` 改为基于非空释义存在，而不是长短阈值。
- 删除长短译文阈值、collapsed line limit 和固定 min-height 相关逻辑。
- 默认只渲染 translation toggle；展开后渲染 `中文释义` 标题和完整释义正文。
- 更新简体中文本地化文案为 `查看释义` / `收起释义`，hint 调整为“查看或收起中文释义。”

### Task 3: 更新规范文档

- 更新 UI 规范：单句练习页释义默认隐藏，只通过 `查看释义` 按需展示；默认态不得用固定高度预留隐藏内容。
- 更新 Apple 交互与可访问性规范：释义和讲解 toggle 均需 44pt 触控目标、可访问状态和 hint。
- 更新页面清单：三端共享 prompt card 的最新显示规则。

### Task 4: 验证与收口

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

文档与格式验证：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

完整验证：

```bash
scripts/verify.sh
```

## 9. 复查方法

- 代码复查：确认 `PracticePromptCardPresentation` 是释义显示规则唯一入口。
- UI 复查：默认态 prompt card 不出现大块空白；点击 `查看释义` 后可完整阅读中文释义。
- 测试复查：确认短释义、长释义和空白释义都有自动化覆盖。
- 文档复查：确认 spec 与页面清单不再保留“短译文默认展示、长译文摘要展示”的旧规则。

## 10. 文档影响检查

本任务改变练习页 UI 规范和三端页面事实，应同步更新：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`

不需要新增 ADR；该调整不改变核心产品决策、数据模型、Provider、隐私或同步边界。

## 11. 实施记录

- 2026-05-26：创建 active plan，按 TDD 写入失败测试。
- 2026-05-26：聚焦测试首次失败，原因是 `PracticePromptCardPresentation` 尚无 `displayedTranslationText`，无法表达“释义存在但默认隐藏”。
- 2026-05-26：更新 `PracticePromptCardPresentation`，将非空释义与可见释义拆分；有释义时始终显示 `查看释义` / `收起释义`，默认不渲染释义正文，展开后完整渲染。
- 2026-05-26：移除 `PracticePromptCardLayout.collapsedMinHeight` 和隐藏内容的固定高度预留；更新简体中文文案为 `查看释义` / `收起释义`。
- 2026-05-26：同步更新 UI 规范、Apple 交互可访问性规范和页面清单。
- 2026-05-26：聚焦验证通过：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

结果：24 个 Swift Testing 测试通过，0 failures。

- 2026-05-26：文档与格式验证通过：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

结果：`scripts/check-docs.sh` 输出 `check-docs: ok`；占位词扫描无匹配；`git diff --check` 无输出。

- 2026-05-26：完整验证通过：

```bash
scripts/verify.sh
```

结果：退出码 0；覆盖 XcodeGen 工程生成、各 Swift Package 测试、Python probe 单元测试、iPhone / iPad / macOS build、macOS App tests、SwiftLint 和 SwiftFormat lint。SwiftLint 仍报告 163 个 warning、0 serious，均为既有 lint debt，未阻断验证。

## 12. 完成标准

- 默认态只显示目标句、`查看释义` 和 `查看讲解` 入口，不显示释义正文和讲解正文。
- 未展开时 card 不再为隐藏内容预留大块空白。
- 点击 `查看释义` 后完整展示中文释义，点击 `收起释义` 后隐藏。
- 切换句子后释义和讲解都回到收起。
- 聚焦 UI package 测试、文档检查和完整验证通过。

## 13. 剩余风险

- 真实设备 Dynamic Type 超大字号下，展开后的长释义仍可能显著增加卡片高度；这是用户主动查看完整内容时的预期行为，需要后续人工验收。
