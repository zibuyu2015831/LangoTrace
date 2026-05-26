# 任务方案：微调单句练习页句间导航与录音反馈

状态：Done
类型：refactor / bugfix
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图确认上一轮方向基本成立，但要求继续收敛单句练习页：

- `第 1 / 2 句` 居中展示。
- 删除 `这是第一句` / `这是最后一句` 边界文案，因为序号已经表达位置。
- `上一句` / `下一句` 放到页面最底部。
- 删除 `听完示范后开始录音。` 常驻提示。
- 删除缺少录音时出现的 `练习需要处理` 提示卡。
- 录音后 `回放录音` 应可用。
- 用户重复录音时替换之前版本的使用语义，始终回放最近一次录音。

用户已明确要求立即处理，本方案作为实施控制面同步记录。

## 2. 目标

- 将 `PracticeSentenceNavigationBar` 收敛为底部单行句间导航：左侧 `上一句`、中间 `第 n / m 句`、右侧 `下一句`。
- 句序只显示 `第 n / m 句`，不拼接第一句 / 最后一句文案，不再单独占据内容卡和操作卡之间的视觉层级。
- `上一句` / `下一句` 移到操作卡之后，保持低权重、44pt 触控、disabled 状态清晰。
- `PracticeControlBar` 删除常驻状态文案，只保留真实操作按钮。
- `PracticeSessionView` 不再为 `.missingReadyRecording` 展示大块错误卡，避免用户在录音前或未刷新状态时看到“练习需要处理”。
- 自动化覆盖：操作区 presentation 不再输出常驻状态 key；多次 ready recording 后 `playLatestRecording()` 使用最新 recording id。

## 3. 不做什么

- 不改变录音文件写入、media artifact、GRDB schema 或播放 resolver。
- 不新增 toast、弹窗或底部固定操作条。
- 不改变完成态引用策略：已完成的 recording id 仍保持稳定；回放入口始终使用最新 ready recording。

## 4. 涉及文件

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`
- `docs/testing/README.md`

## 5. 验证

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|PracticeRouteSeedTests|ThreePlatformPresentationCopyTests|LearningContentStoreSentenceAudioCoordinatorTests|PhoneIOSConvergenceTests'
```

完整验证：

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
scripts/verify.sh
```

## 6. 实施记录

2026-05-26 已实施：

- `PracticeSentenceNavigationProjection.boundaryKey` 对第一句 / 最后一句返回 `nil`，UI 只显示 `第 n / m 句`。
- `PracticeSessionView` 将底部句间导航放在操作卡之后，`PracticeSentenceNavigationBarPresentation` 固定为左侧上一句、中间句序、右侧下一句。
- `PracticeControlBar` 删除常驻状态文案，只保留 `听`、`回放录音` 和主按钮。
- `PracticeSessionViewModel.visibleFailure` 隐藏 `.missingReadyRecording`，避免出现缺少录音提示卡；真实 playback / session / disabled 错误仍可展示。
- `PracticeSessionViewModelTests` 覆盖重复录音后 `playLatestRecording()` 使用最新 ready recording。
- 更新 `docs/spec/003-ui-design-system.md`、`docs/platform-page-inventory.md` 和 `docs/testing/README.md`。
