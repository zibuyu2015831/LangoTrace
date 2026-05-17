# 工作记录：代码实现、测试体系与文档契合度审查

类型：chore

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `docs/technical-framework-roadmap.md`

关联代码：

- `project.yml`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/`

## 1. 背景

本次审查目标是对当前项目代码实现进行一次深入、基于代码的全面检查，重点关注：

1. 当前实现是否存在 bug。
2. 当前框架设计是否存在不准确、不完善或容易积累债务的地方。
3. 测试体系是否完整，`docs/` 文档体系与代码实现是否完全契合。

本次只记录审查发现，不修复代码。

## 2. 当前实现概况

当前仓库处于 SwiftUI App Shell 和 Mock 产品骨架阶段，不是完整 MVP。代码已具备：

- iOS / iPadOS / macOS App target。
- XcodeGen `project.yml` 和生成的 `LangoTrace.xcodeproj`。
- `LangoTraceCore`、`LangoTraceUI`、`LangoTraceData`、`LangoTraceAI`、`LangoTraceSpeech`、`LangoTraceSync` 六个本地 Swift Package。
- Welcome / Onboarding / Main 三段启动状态。
- iPhone 五个 Tab：`今日 / 记录 / 练习 / 记忆 / 设置`。
- iPad 三栏 Mock 工作区。
- macOS Mock 资料库工作台。
- Core 层 16 个 Swift Testing 测试。
- UI 层 3 个 Swift Testing 测试。

当前尚未具备：

- 真实数据库 schema。
- 真实 Repository 读写。
- 真实 AI Provider。
- 真实 Speech / TTS / OCR 流程。
- 真实 Sync Engine。
- StoreKit 配置。
- App-level UI test target 或完整 CI 测试入口。

这与 `docs/README.md` 中“App Shell 后、首次启动和语言空间功能前”的阶段描述基本一致。

## 3. 验证命令与结果

已验证通过：

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

验证结果：

- `xcodegen generate` 成功生成工程。
- `xcodebuild -list` 成功列出 `LangoTrace-iOS`、`LangoTrace-macOS` 和各本地 package scheme。
- `swift test --package-path Packages/LangoTraceCore` 通过，16 个 Swift Testing 测试通过。
- `swift test --package-path Packages/LangoTraceUI` 通过，3 个 Swift Testing 测试通过。
- iPhone 17 Simulator build 通过。
- iPad Pro 13-inch (M5) Simulator build 通过。
- macOS arm64 build 通过。
- `swiftlint --no-cache` 通过，0 violations。
- `swiftformat --lint . --cache ignore` 通过，0/40 files require formatting。
- 文档占位词扫描无命中。
- 审查前后 Git 工作区保持干净，新增本文档后只有本文档变更。

已确认失败：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' test
```

结果：

```text
xcodebuild: error: Scheme LangoTrace-iOS is not currently configured for the test action.
```

另一个确认失败：

```bash
swift test --package-path Packages/LangoTraceData
```

结果：

```text
error: no tests found; create a target in the 'Tests' directory
```

## 4. 发现的问题

### 4.1 Important：Xcode App scheme 的 test action 不可用

证据：

- `project.yml` 的 `schemes.LangoTrace-iOS.test` 和 `schemes.LangoTrace-macOS.test` 只配置了 `config` 与 `gatherCoverageData`，没有挂载任何 test target。
- 实测 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' test` 失败。

影响：

- 未来若使用 Xcode scheme 作为 CI 入口，测试不会被执行。
- `project.yml` 看起来声明了 test action，但实际不可运行，容易造成质量门禁误判。
- App target 与 package test target 之间缺少统一验证入口。

建议：

- 首选新增统一验证脚本，例如 `scripts/verify.sh`，明确执行 package tests、App build、lint 和 format lint，并把它作为当前阶段的真实质量入口。
- 如果希望 `xcodebuild ... test` 成为 App scheme 的质量入口，应在 `project.yml` 中显式配置可运行的 test targets；由于当前测试位于 Swift Package 内，具体 XcodeGen 写法必须通过 `xcodegen generate` 和 `xcodebuild -scheme ... test` 实测确认，不能只改 YAML 就认为完成。
- 另一条可行路径是新增 App-level XCTest / UI test target，用于覆盖启动路径、onboarding 和关键三端入口；package-level 单元测试继续由 `swift test --package-path ...` 执行。
- 在 `docs/README.md` 的完成前检查中同步更新测试入口，避免文档继续只跑 Core 测试。

### 4.2 Important：RootView 在缺少语言空间时会静默生成默认空间

证据：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift` 中 `.main` 分支使用：

```swift
PlatformMainView(languageSpace: languageSpace ?? onboardingDraft.makeLanguageSpacePreview())
```

问题：

- 如果 App 状态错误地进入 `.main`，但 `currentLanguageSpace == nil`，UI 会基于 onboarding draft 自动生成一个 preview。
- 这会掩盖非法状态，使“缺少语言空间上下文进入主流程”的问题不容易暴露。

与文档的冲突：

- `docs/guidelines/002-navigation-and-routing.md` 要求主流程必须携带或恢复语言空间上下文。
- 任何会创建主数据的路由，不能在缺少语言空间上下文时执行写入。

当前风险：

- 当前还没有真实写入，所以不会立刻造成数据污染。
- 一旦后续接入 Entry、Practice、Memory 或 Repository，这个 fallback 可能让无效上下文下的主流程继续运行。

建议：

- 将 `.main + nil languageSpace` 建模为显式状态，例如 `.missingLanguageSpace` 或回到 `.onboarding`。
- 开发期可以使用 assertion 或专门的错误视图暴露非法状态；面向用户的构建不应崩溃，而应回到首次引导或语言空间恢复路径。
- 补充 Core/UI 测试覆盖“main phase cannot render without language space”的行为边界。

### 4.3 Important：SwiftUI ForEach 使用重复 ID

证据：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift` 的 `AudioPanel` 中：

```swift
ForEach([24, 38, 28, 46, 40, 32, 26, 38, 46, 20], id: \.self) { height in
    ...
}
```

问题：

- 数组中 `38` 和 `46` 重复。
- `id: \.self` 会让 SwiftUI 看到重复 identity，可能产生运行时警告或 diffing 不稳定。

影响：

- 当前只是 Mock 波形，影响较小。
- 后续如果该模式复制到真实动态 UI，会造成状态复用、动画错乱或渲染异常。

建议：

- 使用 indices：

```swift
let waveformHeights = [24, 38, 28, 46, 40, 32, 26, 38, 46, 20]
ForEach(waveformHeights.indices, id: \.self) { index in
    let height = waveformHeights[index]
    ...
}
```

- 或定义 `Identifiable` 的波形样本模型。

### 4.4 Medium：语言空间创建仍是纯内存状态，Repository 边界没有参与启动路由

证据：

- `LangoTraceApp/AppEnvironment.swift` 已装配 `languageSpaceRepository`。
- `AppSessionState` 中 `phase`、`onboardingDraft`、`currentLanguageSpace` 都是内存状态。
- `createLanguageSpace()` 只执行：

```swift
currentLanguageSpace = onboardingDraft.makeLanguageSpacePreview()
phase = .main
```

问题：

- 启动路由没有从 Repository 恢复已有语言空间。
- 创建语言空间没有写入任何 Repository。
- App 重启后无法保持“已创建语言空间”的状态。

与当前阶段关系：

- 文档明确数据库 schema 尚未完成，所以这不是当前阶段的阻断 bug。
- 但项目当前优先级第一项是“首次启动引导与语言空间的最小闭环”，该闭环无法只靠内存状态完成。

建议：

- 在进入真实首次启动功能前，先定义最小 `LanguageSpaceRepository` 协议能力，例如 `loadCurrentSpace()`、`createInitialSpace(from:)`。
- InMemory 实现只适合预览、测试和临时 demo。面向真实首次启动闭环时，生产路径应使用 SQLite / GRDB，或用单独 worklog 明确记录临时持久化方案和替换条件。
- 启动路由应由 repository 结果驱动，而不是 UI draft fallback 驱动。

### 4.5 Medium：测试体系与长期文档目标差距较大

证据：

- `LangoTraceCore` 有 16 个测试。
- `LangoTraceUI` 有 3 个测试。
- `LangoTraceData`、`LangoTraceAI`、`LangoTraceSpeech`、`LangoTraceSync` 没有测试 target。
- `docs/testing/README.md` 只是目录说明，没有自动化策略、手动测试流程或回归清单。
- `docs/technical-framework-roadmap.md` 的测试与质量门禁要求覆盖 Repository/migration、Prompt Preset、Provider 请求隐私、同步冲突、附件恢复、三端关键路径 UI 和真机权限。

影响：

- 目前测试只覆盖少量 Core 纯逻辑和一个 iPad 手势 helper。
- 对 Data、AI、Speech、Sync 的风险尚未形成测试入口。
- 文档中的长期质量目标没有落到实际测试结构。

建议：

- 短期补齐测试体系文档：明确当前已覆盖、未覆盖、下一阶段门禁。
- 对 Data/AI/Speech/Sync 不需要为了空协议机械创建无意义测试；一旦出现可测试行为，例如 repository 协议语义、请求预览、TTS 状态机或同步状态机，就应同步建立 package test target。
- 在这些模块仍只有空边界时，测试文档应明确标注“当前无可测试行为”和下一次必须补测的触发条件。
- 首次启动与语言空间最小闭环落地时，优先补 Repository 和启动路由测试。
- AI Provider 引入前，先定义请求预览和外发字段白名单测试。

### 4.6 Medium：文档入口的 Swift 工程检查漏掉 UI 测试

证据：

- `docs/README.md` 的 Swift 工程检查只包含：

```bash
swift test --package-path Packages/LangoTraceCore
```

- 实际仓库已有：

```bash
swift test --package-path Packages/LangoTraceUI
```

影响：

- 后续会话按入口文档执行验证时，会漏跑 UI package 测试。
- 文档入口低于实际质量门禁。

建议：

- 将 `swift test --package-path Packages/LangoTraceUI` 加入 `docs/README.md` 完成前检查。
- 如果后续新增统一验证脚本，应让入口文档指向脚本，避免命令列表继续漂移。

### 4.7 Low：部分 worklog 状态与实际内容不一致

证据：

- `docs/worklogs/2026-05-17-feature-product-shell-navigation.md` 状态仍为 `User Approved`，但文档后部已有实施记录和验证结果。
- `docs/worklogs/2026-05-17-bug-ios-letterboxed-launch-screen.md` 状态为 `Implemented`，但已有验证结果。

影响：

- 文档体系总体可用，但状态流转不准会影响后续审计。
- 后续 AI 或开发者可能误判这些任务仍待实施或待验证。

建议：

- 将已实施并验证的 worklog 状态同步为 `Verified`。
- 若任务已经完成并不再活跃，可进一步归档或在文档中补充关联提交。

## 5. 未发现明显问题的部分

本次审查未发现以下方面的当前阻断问题：

- Core 不依赖 SwiftUI、SQLite、网络或具体 Provider。
- UI 未直接访问 SQLite、Keychain、网络或真实 AI Provider。
- App target 依赖方向大体符合 `App Shell -> UI -> Core` 和 `App Shell -> Data / AI / Speech / Sync`。
- iPhone 一级导航符合 `今日 / 记录 / 练习 / 记忆 / 设置`。
- Onboarding 已询问母语、目标语言和水平自评。
- 当前文案多处明确标注 `未配置 AI`、`本地优先`、`当前为 Mock 骨架`，没有明显误导为真实 AI/同步能力已经完成。
- 三端 build 当前均通过。
- SwiftLint 与 SwiftFormat 当前均通过。

## 6. 建议修复顺序

建议按以下顺序处理：

1. 修复 `project.yml` 的 Xcode test action，或新增统一验证脚本并更新文档入口。
2. 修复 `LangoTraceRootView` 的 `.main + nil languageSpace` fallback，避免非法状态被静默掩盖。
3. 修复 `PadMainView.AudioPanel` 的重复 `ForEach` ID。
4. 更新 `docs/README.md`，把 UI package 测试纳入完成前检查。
5. 更新状态不准的 worklog。
6. 在首次启动与语言空间最小闭环开始前，补齐 `LanguageSpaceRepository` 的最小协议、测试和启动恢复边界。
7. 在 AI/Data/Speech/Sync 真实实现前，补齐对应 package 的最小测试入口与测试策略文档。

## 7. 复审结论

2026-05-17 从系统架构和 iOS 产品设计角度复审后，确认上述问题均有当前仓库证据支撑，且没有把尚未完成的数据库、AI、同步或 StoreKit 能力误判为已实现缺陷。

需要特别收紧的结论：

- `xcodebuild ... test` 不可用是确定问题，但“把 package test target 直接挂入 App scheme”的具体 XcodeGen 写法需要实测验证；当前更稳妥的落地方式是先建立统一验证脚本，并将其写入入口文档。
- `.main + nil languageSpace` fallback 是架构边界问题，不是当前 Mock 阶段的数据损坏 bug；修复目标是让非法状态显式化，避免未来真实写入路径继承这个隐患。
- Data / AI / Speech / Sync 当前只有空边界协议时，不应为了覆盖率创建空测试；应在对应模块出现可测试行为时立即补测试入口，并在测试文档中写明触发条件。
- 从产品体验看，RootView 缺少语言空间时不应崩溃给真实用户，应回到 onboarding、语言空间恢复或明确的缺失状态页面。

## 8. 剩余风险

本次审查以代码阅读、文档对照和命令验证为主，没有执行完整图形界面人工回归，也没有启动 Simulator 截图检查当前视觉状态。

由于项目仍处在 Mock Shell 阶段，很多文档中要求的高风险测试项尚无真实实现对象，例如数据库迁移、AI 请求外发、同步冲突、StoreKit 恢复购买和权限流程。本次结论不代表这些能力已经满足质量门禁，只代表当前骨架阶段没有发现构建阻断问题。

## 9. 修复跟进

2026-05-17：已创建并完成修复记录 `docs/worklogs/2026-05-17-bug-code-test-docs-review-fixes.md`。当前阶段已落地统一验证脚本、RootView 缺少语言空间的显式路由边界、AudioPanel `ForEach` identity 修复、入口文档测试命令更新和历史 worklog 状态修正。修复范围不包含数据库、真实 Repository、AI Provider、同步引擎或 StoreKit。
