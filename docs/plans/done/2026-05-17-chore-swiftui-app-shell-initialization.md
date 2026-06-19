# 工作记录：SwiftUI App Shell 工程初始化

类型：chore

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/development/project-initialization.md`
- `docs/development/001-platform-development-sequence.md`
- `docs/development/environment.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/004-swiftui-architecture.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/003-use-xcodegen-for-project-generation.md`

关联提交：

- `Initialize SwiftUI app shell`

## 1. 背景

语迹 LangoTrace 已完成产品定位、技术路线、文档体系、开发规范、三端开发顺序和静态 HTML 原型。当前仓库尚未创建 SwiftUI 原生工程，需要进入代码初始化阶段。

本次工作对应三端开发顺序中的 `Stage 0：三端 App Shell`，目标是建立可回放、可构建、可继续演进的 Apple 三端工程骨架，而不是实现 MVP 功能。

## 2. 目标

本次初始化完成后，应达到以下可验证结果：

- 仓库存在可维护的 XcodeGen `project.yml`。
- 可以生成 `LangoTrace.xcodeproj`。
- iPhone Simulator 构建通过。
- iPad Simulator 构建通过。
- macOS 构建通过。
- App 根界面展示产品名称和固定 slogan。
- 初始源码体现 App / Core / UI / Data / AI / Speech / Sync 的模块边界。
- 后续接入首次启动、语言空间、记录、练习、AI Provider、TTS 和同步时有清晰放置位置。

## 3. 范围

本次会处理：

- 安装或确认 `xcodegen` 可用。
- 创建 `project.yml`。
- 创建 SwiftUI Multiplatform App Shell。
- 创建最小源码目录：
  - `LangoTraceApp/`
  - `Packages/LangoTraceCore/`
  - `Packages/LangoTraceUI/`
  - `Packages/LangoTraceData/`
  - `Packages/LangoTraceAI/`
  - `Packages/LangoTraceSpeech/`
  - `Packages/LangoTraceSync/`
  - `Tests/`
- 创建轻量 App Environment 或占位依赖装配入口。
- 创建 iPhone、iPad、macOS 可区分的根布局占位。
- 创建最小单元测试，验证核心产品文案或基础模型。
- 运行初始化验证命令。
- 更新本工作记录的实施记录、验证结果和关联提交。

## 4. 不做什么

本次不处理：

- SQLite / GRDB。
- SwiftData。
- 数据库 schema、迁移、FTS 或向量索引。
- 真实 AI 请求。
- API Key、Keychain、Provider 配置 UI。
- TTS、录音、Speech Recognition、OCR。
- 相机、照片、麦克风权限。
- 对象存储、WebDAV、S3、R2、iCloud 同步。
- StoreKit、购买恢复、App Store 配置。
- 完整 onboarding。
- 完整设计系统。
- App icon。
- 复杂 macOS 菜单栏、多窗口、Command Palette。

## 5. 分析

### 5.1 工程边界

本次应优先建立可长期维护的工程边界。Core 必须保持平台无关，不依赖 SwiftUI、数据库、网络或具体 Provider。UI 可以依赖 Core，但不能直接访问 Keychain、SQLite、对象存储或 AI Provider。

### 5.2 平台边界

iPhone、iPad 和 macOS 从第一天进入构建验证，但完成度只要求 `Buildable + Runnable`。iPad 不单独创建 target，作为 iOS target 的设备形态处理。macOS 第一阶段只做基础可运行，不承担完整工作台功能。

### 5.3 数据与隐私边界

本次不创建真实数据存储，也不触发任何权限或外部请求。根界面可以展示占位状态，但不能模拟成已经具备 AI、同步或长期记忆能力。

### 5.4 初学 Xcode 友好性

工程采用 XcodeGen 生成 `.xcodeproj`，但文档和工作记录需要保留可复现命令，便于后续使用 Xcode 打开、运行和调试。

## 6. 方案

采用 XcodeGen 初始化工程：

1. 使用 Homebrew 安装或确认 `xcodegen`。
2. 创建 `project.yml` 作为 Xcode 工程真实来源。
3. 使用一个 iOS App target 覆盖 iPhone + iPad，另设一个 macOS App target。
4. 使用本地 Swift Package 承载 Core / UI / Data / AI / Speech / Sync 模块，App target 通过 package product 依赖这些模块。
5. UI 层提供 `LangoTraceRootView`，根据平台和设备形态展示轻量差异化占位。
6. Core 层提供 `ProductIdentity` 等最小类型，用测试固定产品名称和 slogan。
7. 通过 `xcodegen generate` 生成工程。
8. 使用 `xcodebuild` 验证 iPhone、iPad 和 macOS 构建。

替代方案：

- Xcode GUI 创建项目：更适合学习 Xcode 操作，但可回放性弱，不采用。
- Swift Package 先行、暂不建 App target：模块边界清晰，但不能验证三端 App 启动，不采用。

## 7. 风险与边界

- 用户已通过 Homebrew 安装 `xcodegen`，当前验证版本为 2.45.4。
- 当前环境记录中的 iPad 模拟器是 `iPad Pro 13-inch (M5)`。如果实际设备名变化，需要先用 `xcrun simctl list devices available` 查找可用设备，再调整验证命令。
- 如果 macOS 签名配置导致构建失败，优先调整本地开发签名设置，不引入 App Store 发布配置。
- 如果 Xcode 版本生成的工程字段与 XcodeGen 默认设置不兼容，应把修正写回本工作记录和 `docs/development/environment.md`。
- 如果本地 Swift Package 依赖配置在 XcodeGen 中产生不必要复杂度，可以退回到同仓库源码目录分层，但必须更新本文档说明原因。
- 本次不创建真实数据，不存在数据迁移和用户数据损坏风险。
- 本次不触发网络、相机、麦克风、照片、Keychain 或 AI Provider，不产生隐私发送风险。

## 8. 测试与验证

计划运行：

```bash
command -v xcodegen
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
git status --short
```

如果实际 scheme、模拟器名称或 target 名称不同，以生成后的工程为准，并在验证结果中记录实际命令。

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认后记录：

```text
2026-05-17：用户已执行 `brew install xcodegen`，并要求继续推进项目代码初始化，可以开始实现。
```

## 10. 实施记录

已完成：

- 创建 `.swift-version`，固定 SwiftFormat 使用 Swift 6.0 规则。
- 创建 `.swiftlint.yml`，排除 SwiftPM / Xcode 生成目录，避免 lint 扫描 `.build` 和 `.xcodeproj`。
- 创建 `project.yml`，使用 XcodeGen 管理 `LangoTrace.xcodeproj`。
- 创建 iOS App target：`LangoTrace-iOS`，覆盖 iPhone 和 iPad。
- 创建 macOS App target：`LangoTrace-macOS`。
- 创建 `LangoTraceApp/`，包含 SwiftUI App 入口、App Environment 占位装配和平台 Info.plist。
- 创建本地 Swift Package：
  - `Packages/LangoTraceCore`
  - `Packages/LangoTraceUI`
  - `Packages/LangoTraceData`
  - `Packages/LangoTraceAI`
  - `Packages/LangoTraceSpeech`
  - `Packages/LangoTraceSync`
- 在 Core 中创建 `ProductIdentity`，固定产品名称和主 slogan。
- 在 Core 中创建 `PlatformRole`，表达 iPhone、iPad、macOS 三种平台角色。
- 在 UI 中创建 `LangoTraceRootView`，根据 iPhone、iPad、macOS 展示差异化 App Shell 占位。
- 在 Data / AI / Speech / Sync 中创建最小协议和禁用实现，作为后续真实实现的替换边界。
- 创建 Core 单元测试 `ProductIdentityTests`。
- 更新 `docs/README.md`、`docs/development/environment.md` 和 `docs/development/project-initialization.md`，记录初始化后的实际状态和命令。

实现过程中的偏离：

- 原计划中的 macOS 验证命令从 `platform=macOS` 调整为 `platform=macOS,arch=arm64`，避免本机同时匹配 arm64 和 x86_64 destination。
- iPad 和 macOS 构建必须串行执行。曾并发执行导致 Xcode `build.db` 锁冲突，串行重跑后通过。
- SwiftLint 首次扫描到了 SwiftPM 生成的 `.build` 文件，因此新增 `.swiftlint.yml` 排除生成目录。

## 11. 验证结果

已验证：

```bash
xcodegen --version
```

结果：通过，版本为 `2.45.4`。

```bash
swift test --package-path Packages/LangoTraceCore
```

结果：通过，`Product identity exposes the fixed app name and slogans` 测试通过。实现前曾先运行该测试并确认因缺少 `ProductIdentity` 失败。

```bash
xcodegen generate
```

结果：通过，生成 `LangoTrace.xcodeproj`。

```bash
xcodebuild -list -project LangoTrace.xcodeproj
```

结果：通过，列出 `LangoTrace-iOS`、`LangoTrace-macOS` 以及各本地 Swift Package scheme。

```bash
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

结果：通过。

```bash
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```

结果：通过。

```bash
xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

结果：通过。

```bash
swiftlint --no-cache
```

结果：通过，`Found 0 violations, 0 serious in 17 files`。

```bash
swiftformat --lint . --cache ignore
```

结果：通过，`0/17 files require formatting`。

```bash
git diff --check
```

结果：通过。

剩余边界：

- 本次只完成 Stage 0 App Shell，不包含真实数据库、AI、TTS、同步、权限、StoreKit 和完整 onboarding。
- 生成目录 `Packages/*/.build` 与 `Packages/*/.swiftpm` 由 `.gitignore` 忽略，不纳入提交。
