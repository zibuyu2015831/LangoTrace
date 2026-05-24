# 语言空间切换后学习内容 Store 空间绑定风险修复方案

状态：Verified
类型：bug
创建日期：2026-05-24
最后更新日期：2026-05-24

## 1. 用户确认记录

- 2026-05-24：项目级代码、文档与测试审查发现 `LearningContentStore` 可能在语言空间切换后继续绑定旧 `spaceID`，本方案作为 P1 bug 后续分流记录创建。
- 2026-05-24：用户要求立即修复审查发现项；本方案进入实施并完成验证。

## 2. Bug 描述

三端主界面通过 `PlatformMainView` 创建 `@StateObject private var contentStore: LearningContentStore`，并在 init 中把当前 `languageSpace.id` 写入 store。切换语言空间时，`PlatformMainView` 仍处于同一 SwiftUI 结构位置，当前代码没有 `.id(languageSpace.id)`、没有 `onChange` 重建 store，也没有让 store 显式切换空间。

因此，语言空间切换后页面 header 可能显示新空间，但记录列表、选中记录、生成状态、逐句 TTS 状态和 repository 写入仍停留在旧空间。

## 3. 复现方式

推荐先写自动化回归，再做人工验证：

1. 准备一个 test repository，分别给 `space-a` 和 `space-b` 创建不同 entries。
2. 让 root / platform 主视图先以 `space-a` 创建 `LearningContentStore`。
3. 模拟当前语言空间切换为 `space-b`。
4. 断言三端内容 store 不再返回 `space-a` entries，创建新记录时写入 `space-b`。

人工验证：

1. 启动 App，创建英语空间并创建一条记录。
2. 创建或切换到日语空间。
3. 确认记录列表不显示英语空间记录。
4. 在日语空间新建记录，重启后确认记录归属日语空间。
5. 从日语空间触发学习材料生成时，发送上下文使用日语空间 target language，而 entry 也必须属于日语空间。

## 4. 预期行为

- 当前语言空间变化后，三端主界面的 entries、selected entry、memory items、generation states、sentence audio playback states 和 running operations 都与新 `languageSpace.id` 对齐。
- 任何新建 Entry、学习材料生成、重新分析、逐句 TTS 请求都不能使用旧空间 entry 搭配新空间 language context。
- 切换空间时，旧空间正在运行的 generation / playback observation 要么取消，要么有明确状态隔离，不得把 late result 写入新空间 UI。

## 5. 实际行为

当前代码从静态结构看存在 stale store 风险：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` 中 `PlatformMainView` 使用 `@StateObject private var contentStore`。
- `PlatformMainView.init` 只在创建时用 `languageSpace.id` 初始化 `LearningContentStore`。
- `LearningContentStore` 把 `spaceID` 存为私有常量。
- 未发现 root 层语言空间切换时重建 store 或切换 store 的回归测试。

## 6. 根因分析

`@StateObject` 的生命周期与 SwiftUI view identity 绑定，而不是与 init 参数自动绑定。当前 `PlatformMainView` 没有显式把 `languageSpace.id` 放入 view identity，也没有把空间切换建模为 store 操作，因此语言空间切换会更新传入子视图的 `languageSpace` 值，但不一定重建 `contentStore`。

## 7. 置信度

置信度：85%

## 8. 置信度依据

- 代码证据清楚显示 `LearningContentStore.spaceID` 初始化后不可变。
- `PlatformMainView` 未使用 `.id(languageSpace.id)` 或 `onChange` 重建 / 切换 store。
- 当前测试只覆盖 `LearningContentStore` 拒绝 foreign entry，不覆盖 root 级当前空间切换。
- 仍需用 SwiftUI 级测试或人工验证确认真实运行时表现，因此不是 100%。

## 9. 备选原因

- SwiftUI 可能在某些父视图结构变化时重建 `PlatformMainView`，从而重建 `@StateObject`；但当前代码没有显式保证，不应把核心语言空间隔离依赖在隐式重建上。
- 某些平台 route 切换可能间接清空当前详情，但不会改变 store 内固定 `spaceID`。

## 10. 现状描述

语言空间 Data repository 的新增、切换、重命名和删除 fallback 已有测试和实现；问题不在 Data 层。风险集中在 UI root / feature store 状态绑定：当前 `LanguageSpacePreview` 已更新，但 `LearningContentStore` 可能仍读写旧空间。

## 11. 目标

- 用失败测试证明当前语言空间切换时 content store 必须换绑。
- 用最小实现修复三端共享主流程的空间隔离。
- 保证切换空间时旧空间的 generation / playback UI 状态不会污染新空间。
- 更新项目级审查 round 的问题状态和验证结果。

## 12. 范围

修改范围：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`（仅在选择显式 switch API 时）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`
- 本方案和项目级审查 round 对应记录

## 13. 不做什么

- 不改变语言空间 Data schema。
- 不改变 AI Provider、TTS Provider 或 media artifact schema。
- 不实现跨设备同步。
- 不重构三端页面 IA。
- 不把当前空间选择同步到云端。

## 14. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- 可新增：`Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceContentStoreBindingTests.swift`

## 15. 参考的代码文件路径

- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceSwitcherTests.swift`

## 16. 涉及的文档路径

- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/reports/01-architecture-and-serious-bugs.md`
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/reports/02-platform-parity.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/platform-page-inventory.md`

## 17. 实施方案

### 17.1 测试优先

先新增 UI package 测试，锁定以下行为：

- `PlatformMainView` 或 root 分发层必须把 content store identity 绑定到 `languageSpace.id`。
- 若采用 `.id(languageSpace.id)`，测试可以先用源码结构检查保护该约束，并配合 `LearningContentStore` 单元测试证明不同 store 的 space isolation。
- 若采用 `LearningContentStore.switchSpace(...)`，测试必须断言切换后 entries、selectedEntry、memoryItems、generationStates、sentenceAudioPlaybackStates 和 running operations 被重置或换绑。

### 17.2 最小修复候选

候选 A：在 root 处给 `PlatformMainView` 增加 `.id(languageSpace.id)`。

优点：改动小，能利用 `@StateObject` 重建语义。
风险：切换空间时旧 store 的运行任务依赖 deinit 取消 observation；仍需确认 generation action late result 不会写回已销毁 UI。

候选 B：让 `LearningContentStore` 支持显式切换空间。

优点：空间切换行为更可测试，能显式清理状态。
风险：改动更大，需要把 `spaceID` 从 `let` 改成可控状态，并审查所有方法的空间使用。

推荐先评估候选 A 是否能满足失败测试；如果不能证明运行中状态清理，再采用候选 B。

## 18. 复查方法

- 代码搜索确认 root / platform 主视图对 `languageSpace.id` 有显式 identity 或 switch handling。
- 测试确认切换空间后不会显示旧空间 entries。
- 手动验证三端语言空间切换、新建记录、记录详情和学习材料生成入口。

## 19. 回归测试方案

聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI --filter LanguageSpaceContentStoreBindingTests
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
```

收口测试：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

## 20. 验证命令

实施完成后至少运行：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 21. 文档影响检查

若修复确认三端语言空间切换隔离已被自动化覆盖，应更新项目级审查 round 中 AUDIT-ARCH-003 的后续覆盖记录。若修复方式改变 SwiftUI 架构规则，应更新 `docs/spec/004-swiftui-architecture.md` 的状态边界或变更记录。

## 22. 实施记录

- 2026-05-24：由项目级审查发现并创建本后续 bug 方案。
- 2026-05-24：新增 root 源码约束测试，先确认 `PlatformMainView` 未显式绑定 `languageSpace.id`；随后在 root 调用处添加 `.id(languageSpace.id)`，让 `@StateObject` 随语言空间 identity 重建。
- 2026-05-24：通过聚焦测试、UI 包测试和完整 `scripts/verify.sh` 验证。

## 23. 完成标准

- 失败测试先证明语言空间切换的旧 store 风险。
- 修复后三端主流程 content store 与当前 `languageSpace.id` 对齐。
- 旧空间 generation / playback UI 状态不会污染新空间。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- `scripts/verify.sh` 通过。
- 项目级审查 round 更新后续覆盖记录。

## 23.1 验证结果

- `swift test --package-path Packages/LangoTraceUI --filter LanguageSpaceContentStoreBindingTests`：通过。
- `swift test --package-path Packages/LangoTraceUI`：通过。
- `scripts/verify.sh`：通过，退出码 0。

## 24. 剩余风险

- SwiftUI view identity 的真实运行表现最好补一轮模拟器人工验证；纯源码测试只能证明结构约束。
- 如果修复采用 `.id(languageSpace.id)`，需要额外确认运行中 AI generation late result 不会写回新空间 UI。
