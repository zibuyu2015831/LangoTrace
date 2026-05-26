# 任务方案：单句练习页改为可重复录音的派生完成态

状态：Verified
类型：refactor
创建日期：2026-05-26
最后更新日期：2026-05-26

## 1. 用户确认记录

2026-05-26：用户基于 iPhone 17 模拟器截图指出当前单句练习页存在交互问题：录音完成后主按钮切换为 `标记完成`，点击后变成保持完成状态，用户无法继续录音；但跟读练习中用户很可能需要反复录音。

2026-05-26：讨论后用户倾向方案 A：完成只是“这句已练过”的标记，之后仍可继续录音，新的录音可替换 / 更新练习状态。同时用户追问“标记完成”状态在整个流程中是否真的有必要。结论：当前阶段不保留显性的手动 `标记完成` CTA，改为录音成功后由 ready recording 派生“已练过”状态；用户确认同意该方向。

## 2. 需求描述

单句跟读练习应支持用户反复录音。录音完成后，页面不应把主操作锁定为不可再次触发的完成态，也不应要求用户额外点击 `标记完成` 才算完成一次练习。

## 3. 现状描述

- `PracticeControlBar` 当前主按钮根据 `PracticeSession.status` 和 `latestReadyRecordingID` 映射为 `开始录音`、`停止录音`、`标记完成`、`保持完成状态`。
- `PracticeControlBar.primaryDisabled` 在 `session.status == .completed` 时禁用主按钮。
- `PracticeSessionViewModel.completeLatestRecording()` 会调用 `PracticeActions.complete`，把 session 标为 `.completed` 并记录 `completedRecordingID`。
- Data 层已经支持同一个 session 有多个 `readyRecordings`，并且 repository 测试确认 `completedRecordingID` 可以稳定保留，同时 `latestReadyRecordingID` 可以指向更新录音。
- 当前 UI 问题来自页面把显性完成态当作主流程终点，而不是来自录音数据结构无法重复录音。

## 4. 目标

- 删除单句练习页的显性 `标记完成` 主按钮流程。
- 录音成功后主按钮仍保持可用，文案改为 `再录一次`。
- `回放录音` 始终播放最近一次 ready recording。
- 句子是否“已练过”由 `latestReadyRecordingID != nil` 派生，不要求用户手动完成。
- 保留现有 `PracticeActions.complete` 和 `completedRecordingID` 数据能力，暂不做删除或迁移，避免扩大本次改动。

## 5. 不做什么

- 不改 GRDB schema，不删除 `status`、`completedRecordingID` 或 repository complete API。
- 不做发音评分、ASR、最佳录音选择、录音历史列表或手动选择满意版本。
- 不改变录音文件写入、media artifact、播放 resolver 或权限逻辑。
- 不改变句间导航布局、释义 / 讲解展开逻辑或练习列表 IA。

## 6. 证据与决策依据

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift` 中 `session.status == .completed` 会禁用主按钮，这是用户截图中“完成后无法再录音”的直接交互原因。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift` 中 `completeLatestRecording()` 是显性完成 CTA 的唯一 UI view-model 路径。
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift` 已覆盖完成录音引用和最新 ready recording 可以同时存在，说明本轮无需先动数据层。
- `docs/spec/003-ui-design-system.md` 已规定 `PracticeControlBar` 只承载 `听`、`回放录音` 和录音 / 完成主按钮；本轮需要同步改成录音 / 重录主按钮，避免规范继续鼓励手动完成 CTA。

## 7. 涉及代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeControlBar.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PracticeSessionViewModelTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/ThreePlatformPresentationCopyTests.swift`

## 8. 参考代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `LangoTraceApp/PracticeActionsAssembly.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBPracticeRepositoryTests.swift`

## 9. 涉及文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`
- `docs/testing/README.md`
- `docs/plans/active/2026-05-26-refactor-practice-repeatable-recording-completion.md`

## 10. 实施方案

1. TDD：先更新 `PracticeSessionViewModelTests` 中控制条 presentation 测试，要求已有 ready recording 时主按钮 key 为 `practice.recording.recordAgain`，completed session 也不再映射为 `common.keepCompleted`。
2. TDD：新增 view-model 测试，覆盖用户录音、再次录音后，session 保持可继续录音且最新录音用于回放。
3. 最小实现：移除 `PracticeControlBar` 对 `session.status == .completed` 的禁用和 `common.keepCompleted` 映射；主按钮逻辑变为：
   - 正在录音：`停止录音`。
   - 未录音且已有 latest ready recording：`再录一次`。
   - 未录音且没有 ready recording：`开始录音`。
4. 最小实现：`PracticeControlBar.primaryAction()` 不再调用 `onComplete`，已有录音时也调用 `onStartRecording`。
5. 清理 UI seam：从 `PracticeControlBar` 和 `PracticeSessionView` 删除 `onComplete` 参数；`PracticeSessionViewModel.completeLatestRecording()` 若无其他调用则删除。
6. 本地化：新增 `practice.recording.recordAgain` 的中英文文案，保留旧 `practice.action.markComplete` / `common.keepCompleted` key 不立即删除，避免本轮扩大 xcstring 清理。
7. 文档影响：更新 UI 设计系统和平台页面清单中关于单句练习页操作区的描述，记录“已练过”为派生状态而非手动完成 CTA。

## 11. 复查方法

- 代码复查 `PracticeControlBar`，确认 `session.status == .completed` 不再导致主按钮 disabled。
- 代码复查 `PracticeSessionViewModel`，确认页面不再从显性 CTA 调用 `actions.complete`。
- 测试复查 repeated recording 路径，确认第二次录音后 `playLatestRecording()` 使用最新 recording id。
- 文档复查，确认用户可见流程不再描述 `标记完成`。

## 12. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|ThreePlatformPresentationCopyTests'
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

## 13. 文档影响检查

本轮改变 iPhone 单句练习页主操作语义，需同步更新：

- `docs/spec/003-ui-design-system.md` 的 `PracticeControlBar` 描述。
- `docs/platform-page-inventory.md` 中练习页当前能力和边界。
- `docs/testing/README.md` 中练习录音验证关注点，如已有对应段落。

不需要新增 ADR：本轮不改变核心产品定位、隐私边界、Provider 边界或长期存储选型。

## 14. 实施记录

- 2026-05-26：创建 active refactor plan，记录用户确认的方向：删除显性 `标记完成` CTA，录音成功后用 ready recording 派生已练过状态，主按钮支持 `再录一次`。
- 2026-05-26：按 TDD 先修改 `PracticeSessionViewModelTests`，确认旧实现会把已有 ready recording 映射为 `practice.action.markComplete`、completed session 映射为 `common.keepCompleted`，测试按预期失败。
- 2026-05-26：修改 `PracticeControlBar`，删除 `onComplete` 入口和 `session.status == .completed` 的主按钮禁用逻辑；已有 latest ready recording 时主按钮显示 `practice.recording.recordAgain` 并继续调用 start recording。
- 2026-05-26：删除 `PracticeSessionViewModel.completeLatestRecording()` 的页面调用 seam；保留底层 `PracticeActions.complete` 和数据层 `completedRecordingID`，等待后续单独清理任务判断。
- 2026-05-26：新增 `practice.recording.recordAgain` 本地化 key，并更新 `ThreePlatformPresentationCopyTests` 的 key 覆盖。
- 2026-05-26：同步更新 UI 设计系统、平台页面清单、权限隐私规范和测试 README，明确单句页由 ready recording 派生“已练过”，不再把 `标记完成` 作为主流程。
- 2026-05-26：聚焦验证通过：
  - `swift test --package-path Packages/LangoTraceUI --filter PracticeSessionViewModelTests`
  - `swift test --package-path Packages/LangoTraceUI --filter 'PracticeSessionViewModelTests|ThreePlatformPresentationCopyTests'`
- 2026-05-26：文档与格式验证通过：
  - `scripts/check-docs.sh`
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`
  - `git diff --check`
- 2026-05-26：完整验证 `scripts/verify.sh` 通过；SwiftLint 仍有既有 warning，但结果为 `0 serious`，SwiftFormat lint 为 `0/235 files require formatting`。

## 15. 完成标准

- 录音成功后主按钮显示 `再录一次`，并可继续开始新录音。
- 已有 ready recording 后 `回放录音` 可用并播放最新录音。
- 页面不再出现显性 `标记完成` / `保持完成状态` 主流程。
- 聚焦 UI 测试通过。
- 相关文档不再把手动完成 CTA 描述为当前练习页主流程。

## 16. 剩余风险

- 旧的 `PracticeActions.complete` 和 `completedRecordingID` 仍保留在数据 / App seam 中，后续若确认完全不需要“满意录音”语义，应单独创建数据与 API 清理任务。
- 练习列表的完成进度目前仍可能使用占位统计；若后续要展示“已练过几句”，需要从 practice session / ready recording 投影真实进度。
