# 工作记录：修复代码、测试与文档审查发现

类型：bug

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/worklogs/2026-05-17-chore-code-test-docs-review.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `docs/worklogs/README.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/003-use-xcodegen-for-project-generation.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

代码、测试体系与文档契合度审查已经记录在 `docs/worklogs/2026-05-17-chore-code-test-docs-review.md`。复审确认其中的问题都有当前仓库证据支撑，且修复应遵守当前阶段边界：项目仍处于 SwiftUI App Shell 和 Mock 产品骨架阶段，不提前实现完整数据库、AI Provider、同步引擎或 StoreKit。

本次进入修复阶段，目标是先处理确定、低风险、能通过测试和文档检查闭环的问题，为后续首次启动与语言空间最小闭环打好基础。

## 2. 目标

本次修复要达到以下可验证结果：

1. 项目有一个真实可运行的统一验证入口，覆盖 Core/UI package tests、三端 build、SwiftLint、SwiftFormat 和文档占位词扫描。
2. 入口文档的 Swift 工程检查与当前实际测试资产一致，不再漏跑 UI package 测试。
3. `LangoTraceRootView` 不再在 `.main` 且缺少语言空间时静默生成默认空间。
4. `PadMainView.AudioPanel` 不再使用重复值作为 SwiftUI `ForEach` identity。
5. 已实施并验证过的历史 worklog 状态与实际记录一致。
6. 审查文档与本修复记录同步补充实施和验证结果。

## 3. 范围

本次处理：

- 新增统一验证脚本。
- 更新 `docs/README.md` 完成前检查。
- 为 RootView 缺少语言空间的非法状态补充可测试的行为边界。
- 修复 `AudioPanel` 中重复 `ForEach` ID。
- 更新相关 Swift package tests。
- 更新状态不准确的 worklog。
- 运行修复后的验证命令并记录结果。

涉及文件预计包括：

- `scripts/verify.sh`
- `docs/README.md`
- `docs/worklogs/2026-05-17-chore-code-test-docs-review.md`
- `docs/worklogs/2026-05-17-bug-code-test-docs-review-fixes.md`
- `docs/worklogs/2026-05-17-feature-product-shell-navigation.md`
- `docs/worklogs/2026-05-17-bug-ios-letterboxed-launch-screen.md`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/LaunchFlowTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`

## 4. 不做什么

本次不处理：

- 不实现 SQLite / GRDB schema。
- 不实现真实 `LanguageSpaceRepository` 持久化。
- 不接入真实 AI Provider、TTS、OCR、Speech、Sync 或 StoreKit。
- 不创建空的 Data / AI / Speech / Sync 测试 target。
- 不引入完整 App-level UI test target。
- 不调整产品定位、语言空间模型、买断制或本地优先 ADR。
- 不重做当前 Mock 视觉系统和三端页面结构。

## 5. 分析

### 5.1 统一验证入口

根因：

- `project.yml` 声明了 App scheme 的 test action，但没有可运行 test target。
- 当前可运行测试分散在 `Packages/LangoTraceCore` 和 `Packages/LangoTraceUI`。
- 入口文档只列出 Core 测试，低于实际测试资产。

期望行为：

- 开发者和 AI 会话可以运行一个顶层命令完成当前阶段的质量门禁。
- 该命令不声称运行尚不存在的 Data / AI / Speech / Sync 行为测试。

实际行为：

- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' test` 报错。
- 手动命令列表容易漏跑 UI package tests。

修复方向：

- 新增 `scripts/verify.sh` 作为当前阶段真实验证入口。
- `project.yml` 的 App scheme test action 本次不强行修，因为 Swift Package test target 挂载方式需要独立实测，且统一脚本更符合当前 package-first 测试状态。

### 5.2 RootView 缺少语言空间的非法状态

根因：

- `.main` 分支使用 `languageSpace ?? onboardingDraft.makeLanguageSpacePreview()`。
- UI 层 fallback 会把“没有语言空间上下文”的状态伪装成有效空间。

期望行为：

- 主流程必须有语言空间上下文。
- 如果状态进入 `.main` 但没有语言空间，用户态应回到 onboarding 或显示明确恢复路径；开发者应能通过测试看见该边界。

实际行为：

- UI 静默基于 onboarding draft 创建 preview。

修复方向：

- 将路由决策前移到 Core：新增或扩展 `LaunchRoute.route(appPhase:hasLanguageSpace:)` 之类的纯逻辑，让 `.main + false` 回到 `.onboarding`。
- `LangoTraceRootView` 根据该路由渲染，不在 UI main 分支做隐式 fallback。
- 先写 failing Core test，再修改实现。

### 5.3 AudioPanel 重复 ID

根因：

- Mock 波形使用数组值作为 `ForEach` ID，但数组里有重复高度。

期望行为：

- SwiftUI repeatable UI 使用稳定唯一 identity。

实际行为：

- 重复值 `38` 和 `46` 作为 identity。

修复方向：

- 使用索引作为 `ForEach` identity。
- 由于这是 SwiftUI 渲染 identity 问题，单元测试可通过抽出 `mockWaveformHeights` 或 `waveformSamples` 的唯一 identity helper 来覆盖；如果代码保持纯 View 内部常量，则至少通过 SwiftLint、SwiftFormat 和 build 验证。

### 5.4 Worklog 状态

根因：

- 部分历史 worklog 在实施和验证后未同步状态。

期望行为：

- 已验证记录状态为 `Verified`。

实际行为：

- `2026-05-17-feature-product-shell-navigation.md` 状态为 `User Approved`。
- `2026-05-17-bug-ios-letterboxed-launch-screen.md` 状态为 `Implemented`。

修复方向：

- 只调整状态字段，不改写历史事实。

## 6. 方案

### 6.1 实施顺序

1. 创建统一验证脚本 `scripts/verify.sh`。
2. 更新 `docs/README.md`，将统一脚本作为首选检查入口，同时保留展开命令并加入 UI package 测试。
3. TDD 修复 RootView 缺少语言空间 fallback：
   - 先在 Core 测试中增加 `.main + no language space` 应回到 onboarding 的 failing test。
   - 修改 Core 路由模型。
   - 修改 `LangoTraceRootView` 使用显式路由结果。
4. 修复 `AudioPanel` 的重复 identity。
5. 更新历史 worklog 状态。
6. 更新审查文档和本修复 worklog 的实施记录。
7. 运行统一验证脚本和必要的定向验证命令。

### 6.2 替代方案与取舍

替代方案一：直接修 `project.yml` 让 App scheme test action 跑 package tests。

- 优点：`xcodebuild ... test` 变成单一入口。
- 缺点：当前测试位于 Swift Package，XcodeGen 对 package test target 的配置方式需要额外试验；容易把配置探索和本次确定修复绑在一起。
- 本次结论：不作为首选。保留为后续独立工程任务。

替代方案二：马上新增 App-level UI test target。

- 优点：更贴近真实用户路径。
- 缺点：当前 App 仍是 Mock 骨架，UI test 稳定性和维护收益不如先补 package tests 与验证入口。
- 本次结论：不做。等首次启动和语言空间闭环有真实状态后再设计。

替代方案三：马上实现 Repository 持久化。

- 优点：能真正解决语言空间重启后丢失。
- 缺点：会进入数据库 schema 和存储路线设计，超出本次低风险修复范围。
- 本次结论：不做。保留为下一阶段 feature/refactor worklog。

## 7. 风险与边界

- RootView 路由修复可能影响 welcome -> onboarding -> main 的 Mock 流程，必须通过 Core test 和三端 build 验证。
- 统一验证脚本运行时间会比单个 package test 长，但符合当前阶段质量门禁。
- worklog 状态修正只改元数据，不应改写历史命令或结果。
- 不实现持久化意味着 App 重启后仍会回到初始状态；这是当前阶段剩余风险，需要在首次启动与语言空间最小闭环中解决。

## 8. 测试与验证

计划运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git status --short
```

`scripts/verify.sh` 预期覆盖：

```bash
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git status --short
```

预期结果：

- Core tests 通过。
- UI tests 通过。
- 三端 build 通过。
- SwiftLint 0 violations。
- SwiftFormat 0 files require formatting。
- 文档占位词扫描无命中。
- Git 状态只包含本次预期文件变更。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

```text
2026-05-17：用户要求“立即修复”，确认本方案，可以开始实施。
```

## 10. 实施记录

2026-05-17：已完成以下改动。

- 新增 `scripts/verify.sh`，作为当前阶段统一验证入口。
- 更新 `docs/README.md`，将 `scripts/verify.sh` 设为 Swift 工程任务首选检查命令，并把 `swift test --package-path Packages/LangoTraceUI` 纳入展开命令。
- 在 `LaunchRoute` 中新增 `LaunchPhaseIntent` 和 `route(requestedPhase:hasLanguageSpace:)`，将 `.main + no language space` 统一路由回 onboarding。
- 在 `LaunchFlowTests` 中新增缺少语言空间时拒绝进入 main 的测试。该测试先因缺少 API 失败，随后实现后通过。
- 更新 `LangoTraceRootView`，使用 Core 路由结果计算 `effectivePhase`，移除 main 分支中的 `onboardingDraft.makeLanguageSpacePreview()` 隐式 fallback。
- 更新 `PadMainView.AudioPanel`，将波形高度数组抽为静态常量，并使用 indices 作为 `ForEach` identity。
- 将已实施并验证过的历史 worklog 状态更新为 `Verified`：
  - `docs/worklogs/2026-05-17-feature-product-shell-navigation.md`
  - `docs/worklogs/2026-05-17-bug-ios-letterboxed-launch-screen.md`

## 11. 验证结果

已完成验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git status --short
```

结果：

- `swift test --package-path Packages/LangoTraceCore` 通过，17 个 Swift Testing 测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，3 个 Swift Testing 测试通过。
- `scripts/verify.sh` 首次在沙盒内运行失败，原因是 Xcode / SwiftPM 访问 DerivedData、CoreSimulator 和 SwiftPM 缓存时被沙盒权限拦截。
- `scripts/verify.sh` 在沙盒外重跑通过，覆盖：
  - `xcodegen generate`
  - `xcodebuild -list -project LangoTrace.xcodeproj`
  - `swift test --package-path Packages/LangoTraceCore`
  - `swift test --package-path Packages/LangoTraceUI`
  - `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`
  - `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`
  - `swiftlint --no-cache`
  - `swiftformat --lint . --cache ignore`
  - 文档占位词扫描
  - `git status --short`
- SwiftLint 结果：0 violations。
- SwiftFormat 结果：0/40 files require formatting。
- 文档占位词扫描无命中。
- 剩余风险：App 重启后仍不会持久化语言空间，这是当前阶段尚未实现 Repository / SQLite 的既有边界，应在首次启动与语言空间最小闭环任务中处理。
