# 任务方案：iPad / Mac 练习入口与单句页对齐 iOS 重录流程

状态：Verified
类型：refactor
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户要求“根据 iOS 端‘练习’的实现，立即优化 iPad 端和 Mac 端，保持功能和交互逻辑一致性”。本任务按已落地的 iOS 单句练习行为作为事实源执行：单句页不再显式 `标记完成`，录音成功后由 ready recording 派生“已练过”，主按钮显示 `再录一次` 并允许继续重录。

## 2. 现状描述

- iPad / Mac 单句页已经复用 `PracticeSessionView`、`PracticeControlBar`、`PracticeSessionViewModel` 和 `PracticeActions`，因此核心录音、回放和 `再录一次` 逻辑是共享的。
- iPad 学习面板中的练习入口仍在有 practice items 时使用 `.mockOnly` 状态，容易把真实练习路径表现为本地 mock。
- Mac 练习区入口同样使用 `.mockOnly` 状态。
- Mac 主区对 `.practiceSentenceList` 和 `.practiceSentence` 仍走外层 `ScrollView`，而 `PracticeSentenceListView` / `PracticeSessionView` 自身已经包含滚动容器，形成嵌套滚动风险。

## 3. 目标

- iPad 和 Mac 的练习入口在有可练习句子时显示 `.ready`，与真实可执行练习能力一致。
- Mac 的练习句子列表和单句页使用 dedicated main scrolling 路由，不再套外层 ScrollView。
- 保持 iPad / Mac 单句练习页继续复用 iOS 的共享 `PracticeSessionView`，不新增平台分叉状态机。
- 用 UI package 回归测试锁定平台壳层一致性。

## 4. 不做什么

- 不修改 GRDB schema、practice recording metadata、media artifact、录音权限或播放 resolver。
- 不新增 Mac 专属录音按钮、键盘快捷键、录音历史列表或评分。
- 不改变 iPhone 已落地的 `再录一次` 主流程。
- 不重做 iPad / Mac 整体布局。

## 5. 涉及文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadLearningPanelView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainModels.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `docs/platform-page-inventory.md`
- `docs/testing/README.md`

## 6. 实施方案

1. TDD：新增平台一致性测试，先确认当前 Mac practice routes 没有 dedicated scrolling、iPad / Mac 练习入口仍有 `.mockOnly`，测试应失败。
2. 修改 `PadLearningPanelView.entryLearningContent`，有 practice items 时把练习入口状态从 `.mockOnly` 改为 `.ready`。
3. 修改 `MacWorkspaceContentView.practiceItems`，有 practice items 时把入口状态从 `.mockOnly` 改为 `.ready`。
4. 修改 `MacWorkspaceRoute.usesDedicatedMainScrolling`，让 `.practiceSentenceList` 和 `.practiceSentence` 与 `.languageSpaceManagement` 一样绕过外层主区 ScrollView，由练习页自身滚动。
5. 更新平台页面清单和测试 README，记录 iPad / Mac 练习入口已指向真实练习闭环，Mac 避免嵌套滚动。

## 7. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PhoneIOSConvergenceTests|PracticeSessionViewModelTests'
```

收口验证：

```bash
scripts/check-docs.sh
git diff --check
scripts/verify.sh
```

## 8. 文档影响检查

本轮是三端练习页平台一致性修正，需要同步 `docs/platform-page-inventory.md` 和 `docs/testing/README.md`。不需要 ADR：没有改变核心产品决策、数据边界或隐私边界。

## 9. 实施记录

- 2026-05-26：创建 active plan。现场代码检查确认单句页核心逻辑已经共享，差异集中在 iPad / Mac 入口状态和 Mac 主区滚动容器。
- 2026-05-26：先新增 `PhoneIOSConvergenceTests/iPadAndMacPracticeShellsMatchIOSRepeatableRecordingFlow`，确认 iPad / Mac 练习入口仍显示 mock、Mac 练习 route 未使用 dedicated scrolling 时测试失败。
- 2026-05-26：将 iPad 学习面板和 macOS Practice section 的真实练习入口改为 ready；macOS `.practiceSentenceList` / `.practiceSentence` 改为 dedicated main scrolling；补充页面清单和测试 README。
- 2026-05-26：聚焦 UI 测试、文档检查、占位词扫描、`git diff --check` 和完整 `scripts/verify.sh` 均通过。SwiftLint 仍有既有 warning，当前完整验证显示 `0 serious`，SwiftFormat 显示 `0/235 files require formatting`。

## 10. 完成标准

- iPad / Mac 有练习材料时入口显示 ready，而不是 mockOnly。
- Mac 练习句子列表和单句页不再被主区外层 ScrollView 包裹。
- 聚焦 UI 测试通过。
- 文档记录与当前平台行为一致。
- 完整 `scripts/verify.sh` 通过。

## 11. 剩余风险

真实 iPad Stage Manager 和 macOS 窗口 resize 下的滚动手感仍需要人工验收；自动化测试只能锁定代码 seam 和平台壳层策略。
