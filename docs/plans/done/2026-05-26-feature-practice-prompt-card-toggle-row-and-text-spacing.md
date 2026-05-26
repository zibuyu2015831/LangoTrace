# Practice Prompt Card Toggle Row and Text Spacing Plan

状态：Verified
类型：feature
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图确认继续优化单句练习页顶部 prompt card：

- 展开释义后去除重复标题 `中文释义`。
- 讲解内容中不同段落之间需要更清晰的间距。
- 默认态 `查看释义` 与 `查看讲解` 两个按钮放在同一行以节省空间。

2026-05-26：经 UI 设计评估，用户确认采用：默认态目标句下方同行显示两个低权重 plain text buttons；展开释义时直接显示译文正文；展开讲解时按段落分隔显示正文；窄屏或 Dynamic Type 下可回退换行，但不得压缩触控目标。

## 2. 需求描述

当前 `PracticePromptCard` 已实现释义默认隐藏，但展开态仍有冗余和密度问题：

- 用户点击 `查看释义` 后，按钮已经变为 `收起释义`，再显示 `中文释义` 标题属于重复提示。
- `noteSnapshot` 中的多条语法说明作为一个 `Text` 渲染，段落之间缺少视觉停顿。
- 默认态两个 toggle 纵向排列，增加了卡片高度。

## 3. 目标

- 默认态在目标句下方同行显示 `查看释义` 与 `查看讲解`，每个按钮仍保持不小于 44pt 的触控目标。
- 展开释义时只显示译文正文，不再渲染 `中文释义` 标题。
- 展开讲解时按非空换行拆成段落，段落之间保持 6-8pt 间距。
- 小屏或较大 Dynamic Type 下允许按钮自然回退为上下排列，不挤压文字、不缩小触控目标。
- 不改变录音、TTS、回放、完成态、句间导航或 route state reset。

## 4. 范围

涉及代码文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticePromptCard.swift`

涉及测试文件：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeRouteSeedTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

涉及文档文件：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/platform-page-inventory.md`
- 本方案文档

## 5. 不做什么

- 不新增图标、分段控件、卡片内卡片或动画。
- 不改变 String Catalog key；`practice.prompt.translation.title` 可保留给未来列表或其它界面使用，但本组件不再渲染它。
- 不持久化展开状态。
- 不改 `PracticeSessionViewModel`、`PracticeActions`、media artifact 或数据库。

## 6. 实施方案

### Task 1: 写失败测试

- `PracticeRouteSeedTests` 覆盖 `PracticePromptCardPresentation` 输出讲解段落数组，空白行被清理。
- `PhoneIOSConvergenceTests` 源码扫描：
  - prompt card 使用 `ViewThatFits` 和 `HStack` 承载 disclosure buttons。
  - prompt card 不再包含 `practice.prompt.translation.title`。
  - prompt card 使用 `explanationParagraphs` 和 paragraph spacing 渲染讲解。

### Task 2: 实施 SwiftUI 变更

- 新增 `disclosureControls` 视图，用 `ViewThatFits(in: .horizontal)` 优先尝试同行布局，回退到 VStack。
- 将 `translationSection` 简化为直接渲染译文正文。
- 将讲解正文拆为 `explanationSection`，逐段渲染 `presentation.explanationParagraphs`。

### Task 3: 更新文档

- UI 规范补充：练习 prompt card 的辅助信息入口优先同行，展开释义不重复标题，讲解多段需要段落间距。
- Apple 交互规范补充：同行按钮仍需保持 44pt 触控目标，Dynamic Type 下可换行。
- 页面清单补充默认态同行入口。

### Task 4: 验证

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

文档与格式验证：

```bash
scripts/check-docs.sh
git diff --check
```

完整验证：

```bash
scripts/verify.sh
```

## 7. 实施记录

- 2026-05-26：创建 active plan，按 TDD 写入失败测试。
- 2026-05-26：聚焦测试首次失败，原因是 `PracticePromptCardPresentation` 尚无 `explanationParagraphs`，且 prompt card 尚未使用同行 disclosure controls。
- 2026-05-26：更新 `PracticePromptCard`，新增 `disclosureControls`，通过 `ViewThatFits(in: .horizontal)` 优先同行显示 `查看释义` / `查看讲解`，回退到纵向排列。
- 2026-05-26：展开释义时不再渲染 `practice.prompt.translation.title`；展开讲解时按非空换行拆分为段落，并使用 8pt 段落间距。
- 2026-05-26：同步更新 UI 规范、Apple 交互与可访问性规范、三端页面清单。
- 2026-05-26：聚焦验证通过：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeRouteSeedTests|PhoneIOSConvergenceTests|ThreePlatformPresentationCopyTests'
```

结果：25 个 Swift Testing 测试通过，0 failures。

- 2026-05-26：文档和格式检查通过：

```bash
scripts/check-docs.sh
git diff --check
```

结果：`scripts/check-docs.sh` 输出 `check-docs: ok`；`git diff --check` 无输出。

- 2026-05-26：完整验证通过：

```bash
scripts/verify.sh
```

结果：退出码 0；覆盖 XcodeGen 工程生成、各 Swift Package 测试、Python probe 单元测试、iPhone / iPad / macOS build、macOS App tests、SwiftLint 和 SwiftFormat lint。SwiftLint 仍报告 163 个 warning、0 serious，均为既有 lint debt，未阻断验证。

## 8. 完成标准

- 默认态两个按钮优先同行显示。
- 展开释义不再出现 `中文释义` 标题。
- 展开讲解多段之间有清晰间距。
- 聚焦测试、文档检查和完整验证通过。

## 9. 剩余风险

- Dynamic Type 超大字号下按钮可能回退为上下排列，这是保持触控目标和文字完整的预期行为。
