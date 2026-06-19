# 任务方案：记录详情页标题区视觉降噪

状态：Verified
类型：refactor
创建日期：2026-05-27
最后更新日期：2026-05-27

## 1. 用户确认记录

2026-05-27：用户基于 iPhone 17 模拟器截图指出记录详情页顶部的 `文本输入 · 英语 · 生活记录` metadata 行和右侧 `可用` 状态 badge 影响页面简洁感，询问是否可以删除。经判断这两处信息与页面正文、可执行按钮和记录内容重复，且 `可用` 更像开发态能力标记，用户要求立即创建 active plan 并执行优化。

## 2. 需求描述

记录详情页顶部标题区当前在记录标题右侧展示能力状态 badge，并在标题下方展示来源、目标语言和场景 metadata。该区域在练习详情路径中视觉权重大，但对用户下一步动作帮助有限。

本任务目标是删除标题区的低价值 metadata 和状态 badge，让记录详情页优先呈现记录标题、原文、目标语言表达和逐句练习。

## 3. 现状描述

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift` 中 `EntryDetailHeader` 使用 `HStack` 展示 `Text(entry.title)`、`Spacer` 和 `CapabilityStatusBadge(status: EntryRenderingStatus.status(for: rendering))`。
- 同一组件在标题下渲染 `Text("\(entry.displaySourceTitle) · \(targetLanguage) · \(entry.scene)")`。
- `PhoneMainSupportingViews.swift` 复用 `EntryDetailHeader`，因此该顶部结构会影响 iPhone、iPad 和 macOS 共享记录详情内容。
- `CapabilityStatusBadge` 仍在设置、能力状态和其他页面中使用；本任务只移除记录详情标题区调用。

## 4. 目标

- 记录详情标题区只显示记录标题，不显示 `文本输入 · 英语 · 生活记录` metadata 行。
- 记录详情标题区不显示 `可用` / `本地预览` / `未接入` 等能力状态 badge。
- 不影响正文编辑、学习材料生成、逐句 `听`、逐句 `练`、练习录音、TTS、AI Provider、GRDB 或 media artifact。
- 保持标题支持 Dynamic Type 和多行，不引入固定高度或截断。
- 自动化测试锁定记录详情 header 不再引用 `CapabilityStatusBadge`、`EntryRenderingStatus.status(for:)`、`entry.displaySourceTitle`、`targetLanguage` 或 `entry.scene`。

## 5. 范围

预计修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`
- 本方案文档

## 6. 不做什么

- 不删除 `CapabilityStatusBadge` 组件。
- 不改变记录详情正文卡片、编辑 sheet、生成学习材料、重新分析或逐句练习入口。
- 不改变 iPad / macOS 外壳导航结构。
- 不把来源、语言和场景迁移到新面板；后续如需记录元信息页再另建任务。
- 不新增截图自动化。

## 7. 证据与决策依据

- 用户截图中圈出的 metadata 行和 `可用` badge 均位于首屏高权重区域，但不提供直接动作。
- `docs/spec/003-ui-design-system.md` 已要求 iPhone 单句练习和学习主路径减少解释型状态，把视觉权重留给内容和真实可执行动作。
- 记录详情已有 `中文记录`、`英语表达` 和逐句练习列表，足以表达来源语言和练习可用性。
- `可用` badge 在记录详情标题区容易被理解为审核状态或后台状态，不符合用户面向的内容详情页语义。

## 8. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

## 9. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/CapabilityStatusBadge.swift`

## 10. 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`

## 11. 实施方案

### Task 1：测试先行锁定 header 降噪

- 修改 `PhoneIOSConvergenceTests.iPhoneDefaultLearningFlowDoesNotShowPersistentRequestPreviews` 或新增相邻测试，读取 `EntryDetailHeader.swift`，断言：
  - 包含 `struct EntryDetailHeader`。
  - 不包含 `CapabilityStatusBadge(`。
  - 不包含 `EntryRenderingStatus.status(for: rendering)`。
  - 不包含 `entry.displaySourceTitle`。
  - 不包含 `targetLanguage`。
  - 不包含 `entry.scene`。

预期首次运行失败，因为当前代码仍包含这些内容。

### Task 2：删除记录详情标题区 metadata 和 badge

- 将 `EntryDetailHeader.body` 简化为只渲染 `Text(entry.title)`。
- 保留 `.font(.title2.weight(.semibold))`、`.foregroundStyle(...)`、`.fixedSize(horizontal: false, vertical: true)`、`.padding(.vertical, 4)` 和 `.accessibilityElement(children: .combine)`。
- 保留 `targetLanguage` 和 `rendering` 入参可暂不删除，以减少调用点扩散；若编译器或 lint 要求，再删除入参并同步调用点。

### Task 3：同步文档事实

- 更新 `docs/spec/003-ui-design-system.md`：记录详情标题区不展示能力状态 badge 或低价值 metadata，标题下方直接进入内容卡片。
- 更新 `docs/platform-page-inventory.md`：记录详情顶部不再展示 practice / rendering availability badge 或来源语言场景 metadata。

## 12. 复查方法

- 代码复查：确认 `EntryDetailHeader` 不再调用 `CapabilityStatusBadge`，也不渲染来源 / 语言 / 场景 metadata。
- 行为复查：确认记录详情正文卡片、逐句 `听` 和 `练` 的代码路径没有被修改。
- 文档复查：确认页面清单和 UI 规范不再描述旧标题区。

## 13. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
```

文档与格式验证：

```bash
scripts/check-docs.sh
git diff --check
```

必要时运行完整验证：

```bash
scripts/verify.sh
```

## 14. 文档影响检查

本任务改变记录详情页可见 UI 事实，应同步 `docs/spec/003-ui-design-system.md` 和 `docs/platform-page-inventory.md`。不改变核心产品决策、数据、AI、隐私、同步、权限或发布边界，不需要新增 ADR。

## 15. 实施记录

- 2026-05-27：创建 active plan，按 TDD 执行。
- 2026-05-27：新增 `PhoneIOSConvergenceTests.entryDetailHeaderKeepsTitleOnlyWithoutMetadataOrAvailabilityBadge`，首次运行聚焦测试按预期失败，失败点覆盖 `CapabilityStatusBadge`、`EntryRenderingStatus.status(for:)`、`entry.displaySourceTitle`、`targetLanguage` 和 `entry.scene`。
- 2026-05-27：简化 `EntryDetailHeader`，标题区仅保留 `entry.title`；同步删除 `PhoneMainSupportingViews` 的旧参数传入。
- 2026-05-27：更新 `docs/spec/003-ui-design-system.md` 和 `docs/platform-page-inventory.md`，记录记录详情标题区不再恢复 metadata 或能力状态 badge。
- 2026-05-27：验证完成，方案归档至 `docs/plans/done/`。

## 16. 完成标准

- 记录详情页顶部不再显示 metadata 行。
- 记录详情页顶部不再显示 `可用` badge。
- 聚焦 UI 测试通过。
- 文档检查和 `git diff --check` 通过。
- 方案文档移入 `docs/plans/done/` 并记录验证结果。

## 17. 验证结果

- `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/entryDetailHeaderKeepsTitleOnlyWithoutMetadataOrAvailabilityBadge`：先失败后通过。
- `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests`：通过，15 个测试。
- `swift test --package-path Packages/LangoTraceCore`：通过，87 个测试。
- `swift test --package-path Packages/LangoTraceData`：通过，90 个测试。
- `swift test --package-path Packages/LangoTraceAI`：通过，87 个测试。
- `swift test --package-path Packages/LangoTraceSpeech`：通过，16 个测试。
- `swift test --package-path Packages/LangoTraceSync`：通过，1 个测试。
- `swift test --package-path Packages/LangoTraceUI`：通过，261 个测试。
- `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`：通过，9 个测试。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`：通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`：通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`：通过。
- `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`：通过，11 个测试。
- `scripts/check-docs.sh`：通过。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：无匹配。
- `git diff --check`：通过。
- `swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore`：通过。
- `swiftlint --no-cache`：通过，保留既有 warning，0 serious。

说明：完整 `scripts/verify.sh` 曾在格式问题上失败一次，已修复；最终验证按脚本展开命令逐项执行并通过。

## 18. 剩余风险

- 删除 metadata 后，用户在详情页顶部不再直接看到来源 / 场景；当前判断这些信息对练习详情主路径价值低，未来如需可在低权重信息面板中重新设计。
