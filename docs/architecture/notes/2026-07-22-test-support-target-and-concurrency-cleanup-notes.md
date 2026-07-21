# 开发备忘录：测试夹具出仓、@preconcurrency 收敛与 App 组装层测试盲区

状态：开发备忘录（非正式方案 / 非事实源）
创建日期：2026-07-22
来源：2026-07-22 代码健康度审查（`docs/plans/done/2026-07-22-chore-code-health-remediation.md` 的 defer 项 M3 / L1 / L4）

> 本备忘录只登记尚未进入正式方案的跨任务提醒；创建相关任务方案前应检查本文件，但不得把内容直接当作已接受实现事实。

## 1. M3：InMemoryLearningContentRepository 等 mock 夹具位于生产 Sources

- 现状：`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift` 的 `InMemoryLearningContentRepository` + `SeedLearningContent.swift` 是纯测试 / 预览夹具（含写死英文示例文本、`isMock: true`），但位于 Sources，会随发行版编译进包。生产装配点（`AppEnvironment.swift`）已确认不引用它。
- 方向：新建 test-support 产品（如 Data 包内 `LangoTraceDataTestSupport` library target），把 InMemory 夹具与 seed 数据迁出生产 target；LangoTraceUI Tests 等跨包消费方 imports 随迁。
- 注意：2026-07-22 起 capability 元数据已由 `SettingsCapabilityCatalog`（生产 Sources）单一持有，迁移时 InMemory 的 status 注入随夹具走、catalog 留在生产侧。
- 风险：多包 imports 改动量中等；`project.yml` 无需新 target（SwiftPM library product 即可）。

## 2. L1：`@preconcurrency import Foundation` 大面积整文件抑制

- 现状：LangoTraceAI 约 12 个文件用整文件级 `@preconcurrency import Foundation`，会连带屏蔽真实 Sendable 警告。
- 方向：随 Swift 6 严格并发迁移逐文件收敛为最小抑制面（或移除后修真实警告）；不建议单独立项，挂在下一次工具链 / Swift 版本升级任务中。

## 3. L4：App 组装层测试盲区

- 现状：`LangoTraceApp/ReadingExplanationOperationRecorder.swift`、`AIRequestLogRecorder.swift`、`PhotoWritingActionsAssembly.swift` 在所有测试 target 中零引用；`AppEnvironment.swift`（约 1300 行）仅 bootstrap 路径有测试，大量装配分支未覆盖。
- 方向：为三个 recorder / assembly 补最小化装配测试（`LangoTraceAppTests`）；`AppEnvironment` 大函数拆分应与测试补齐同批做，避免为旧结构写测试后立刻重构作废。
- 边界：App 层测试跑在 CI macOS test step，本地 Linux 环境不可运行；立项时验证命令按 CI 步骤写。
