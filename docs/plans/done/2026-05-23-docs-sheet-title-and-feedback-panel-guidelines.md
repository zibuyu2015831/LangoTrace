# Sheet 标题与反馈面板规范补强

状态：Done  
日期：2026-05-23  
类型：Docs / UI Governance  
范围：iPhone sheet 标题、状态反馈 sheet、AI Provider 测试结果面板规范

## 背景

用户人工测试 AI Provider TTS 测试结果面板后指出，结果面板此前很可能是在开发中误套了“sheet 需要标题”的模式，导致状态反馈面板变成左侧大标题加表格样式。现有规范对管理 / 编辑类 sheet 写得较清楚，但没有明确区分：

- 需要 Navigation 标题的任务型 sheet。
- 不需要页面标题、只需要状态 chrome 的反馈型 sheet。

## 检查结论

规范确实存在缺口：

- `docs/spec/002-navigation-and-routing.md` 只说明 sheet / modal / inspector 的大类边界，没有说明 sheet 标题规则。
- `docs/spec/003-ui-design-system.md` 已有“管理类 sheet 与轻量编辑面板”规则，但它只适用于创建、编辑、重命名、配置等任务型 sheet，容易被误套到测试结果这类反馈面板。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md` 已要求 sheet 轻量、清楚，但没有明确 running / testing 反馈不应使用禁用主按钮表达进度。

## 已更新

1. `docs/spec/002-navigation-and-routing.md`
   - 补充 sheet 标题分类：任务型 sheet 需要标题，状态反馈 sheet 使用状态 chrome。
   - 明确反馈型 sheet 不应同时出现系统导航标题、面板内大标题和状态图标。
2. `docs/spec/003-ui-design-system.md`
   - 新增 `iPhone 状态反馈 Sheet` 规则。
   - 明确 running / testing 用 `ProgressView`，分项结果用 grouped card，底部只保留真实可用操作。
   - 将 AI Provider 测试结果面板归入状态反馈 sheet。
3. `docs/spec/010-apple-platform-interaction-and-accessibility.md`
   - 补充任务型 sheet 与状态反馈 sheet 的顶部结构边界。
   - 明确禁用主按钮不应作为进度反馈。
4. `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
   - 在变更记录中补充“不是所有 sheet 都需要页面式标题”的规则归因。

## 验证

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
scripts/verify.sh
```

结果：通过；`scripts/verify.sh` 中 SwiftLint 仍有既有 warning，0 serious。
