# 语迹 / LangoTrace 项目初始化规划

本文档记录语迹 LangoTrace 从产品文档与静态原型进入原生工程开发时的初始化边界。目标是为后续付费 App 开发建立可维护、可测试、可扩展的 Apple 三端工程基础。

状态说明：本文档最初用于工程创建前的规划。当前 SwiftUI Multiplatform 工程、XcodeGen 配置、本地 Swift Package 边界、产品体验骨架和首批测试已经落地；本文档仍保留为初始化边界和验证标准的历史依据。当前事实以本节和 `docs/README.md` 的项目当前状态为准。

## 1. 初始化目标

第一阶段项目初始化只解决一件事：

> 创建一个可以在 iPhone、iPad 和 macOS 上启动的 SwiftUI Multiplatform 工程骨架，并建立清晰的模块边界。

本阶段不追求功能完整，不接入复杂基础设施。

## 2. 当前仓库基线

当前仓库已有：

- `docs/product-main-reference.md`：产品主参考。
- `docs/technical-framework-roadmap.md`：技术路线参考。
- `docs/development/environment.md`：本机开发环境记录。
- `docs/reference/README.md`：参考项目使用指南。
- `prototypes/`：多端静态 HTML 原型，入口见 `prototypes/README.md`。
- `project.yml`：XcodeGen 工程定义。
- `LangoTrace.xcodeproj`：由 XcodeGen 生成的 Xcode 工程。
- `LangoTraceApp/`：App 入口、环境装配、启动状态和资源。
- `Packages/LangoTraceCore/`：产品身份、平台、语言、隐私、启动路由和 onboarding draft 等核心模型。
- `Packages/LangoTraceUI/`：Welcome、Onboarding、iPhone、iPad、macOS 主界面和共享 UI 组件。
- `Packages/LangoTraceData/`：`LanguageSpaceRepository` 协议和 `EmptyLanguageSpaceRepository`。
- `Packages/LangoTraceAI/`：`AIProvider` 协议和 `DisabledAIProvider`。
- `Packages/LangoTraceSpeech/`：`SpeechService` 协议和 `DisabledSpeechService`。
- `Packages/LangoTraceSync/`：`SyncService` 协议和 `DisabledSyncService`。
- `scripts/verify.sh`：当前统一验证入口。

当前仓库尚未创建或尚未实现：

- 数据库 schema。
- SQLite / GRDB Repository 和迁移。
- 真实 AI Provider 代码。
- TTS、录音、Speech、OCR、照片和权限接入。
- 同步引擎。
- StoreKit 配置。

## 3. 初始化原则

### 3.1 原生 Apple 优先

工程初始化采用 SwiftUI Multiplatform 路线，目标平台为：

- iOS。
- iPadOS。
- macOS。

iPadOS 作为 iOS target 的自适应体验处理，但在 UI 架构中保留 iPad 专属布局。

三端开发顺序遵循 [三端开发顺序方案](001-platform-development-sequence.md)：工程层面同时初始化 iPhone、iPad 和 macOS；MVP 功能优先 iPhone + iPad；Mac 第一阶段保持基础可运行，后续增强为语言资料库与创作工作台。

### 3.2 模块边界先于功能堆叠

第一阶段应先建立边界，而不是快速把所有功能写进一个 App 文件。

推荐边界：

- App shell：应用入口、平台窗口、根导航。
- Core：领域模型、用例协议、纯业务逻辑。
- UI：共享组件、平台适配视图、设计 token。
- Data：本地存储接口，第一阶段可以只有协议和内存实现。
- AI：Provider 协议和 Prompt Preset 类型，第一阶段不发真实请求。
- Speech：TTS、录音、语音识别接口，第一阶段可以只有空实现。
- Sync：同步接口和状态类型，第一阶段不实现真实同步。

### 3.3 MVP 不等于架构随意

语迹是长期付费 App。即使第一阶段功能很少，也必须从一开始明确：

- 哪些是主数据。
- 哪些是可重建派生数据。
- 哪些能力会触发权限。
- 哪些内容可能发送给 AI Provider。
- 哪些模块未来会影响 StoreKit、同步、导出和迁移。

## 4. 工程结构

已采用可扩展但不过度复杂的结构：

```text
LangoTrace/
  LangoTrace.xcodeproj
  project.yml
  scripts/
  LangoTraceApp/
    LangoTraceApp.swift
    AppEnvironment.swift
    Resources/
    Supporting/
  Packages/
    LangoTraceCore/
    LangoTraceUI/
    LangoTraceData/
    LangoTraceAI/
    LangoTraceSpeech/
    LangoTraceSync/
```

其中 iPhone 和 iPad 共享 `LangoTrace-iOS` target，iPad 通过设备形态和 UI 分支获得专属布局；macOS 使用 `LangoTrace-macOS` target。当前测试位于 `Packages/LangoTraceCore/Tests` 和 `Packages/LangoTraceUI/Tests`。

## 5. 第一阶段范围

### 5.1 应该完成

- 创建 SwiftUI Multiplatform App。已完成。
- App 名称使用 `LangoTrace`。已完成。
- Bundle / Display Name 后续可再调整为 `语迹` 或 `语迹 LangoTrace`。
- 支持 iOS、iPadOS、macOS 启动。已完成构建验证。
- 根视图展示初始占位界面。已推进为产品体验骨架。
- 占位界面体现产品主线。已完成：
  - `语迹 / LangoTrace`
  - `用生活记录学习语言。`
  - `Learn languages from your life.`
- 根导航为后续首次启动引导、语言空间、记录和练习留出位置。已完成。
- 加入最小测试或构建验证。已完成，并统一到 `scripts/verify.sh`。
- 更新文档记录初始化方式。已完成。

### 5.2 暂不完成

本阶段不实现：

- SQLite / GRDB 数据库。
- SwiftData。
- AI 请求。
- API Key 保存。
- TTS 播放。
- 录音。
- OCR。
- 同步。
- StoreKit。
- 最终品牌 App icon。
- 完整设计系统。
- 真实持久化 onboarding。

这些能力需要后续单独规格、计划、实现和验证。

## 6. 初始化方式选择

有两种可选方式。

### 6.1 方案 A：Xcode GUI 创建项目

优点：

- 最贴近 Apple 官方流程。
- 对第一次接触 Xcode 的用户更直观。
- 不引入额外项目生成工具。

缺点：

- 自动化和可重复性较弱。
- 后续如果需要重建工程，依赖手动步骤。
- 项目文件变更较难审查。

适合：

- 第一次创建项目。
- 需要用户熟悉 Xcode 基础操作。

### 6.2 方案 B：XcodeGen 生成项目

优点：

- 工程结构可由 `project.yml` 明确描述。
- 适合严格工程化和长期维护。
- 项目文件可重复生成，减少 `.xcodeproj` 手动漂移。

缺点：

- 需要额外安装 `xcodegen`。
- 初次配置成本略高。
- 用户需要理解生成式 Xcode 工程的工作方式。

适合：

- 从第一天要求工程可回放。
- 未来计划多人协作或长期维护。
- 希望代码审查时能清楚看到 target、scheme、依赖和 build setting 变化。

## 7. 推荐结论

推荐采用方案 B：

> 使用 XcodeGen 管理 `.xcodeproj`，用 `project.yml` 固化工程结构。

理由：

- 语迹目标是长期维护的付费 App，不是一次性 Demo。
- 工程结构、target、scheme、platform、package dependency 和 build setting 应能被文档化和版本化。
- 后续如果新增测试 target、Swift Package、macOS 专属 target、StoreKit 配置或构建脚本，XcodeGen 更容易保持一致。

如果后续发现 XcodeGen 对初学 Xcode 的理解成本过高，可以保留 `project.yml`，同时在 `docs/development/` 中写清楚如何用 Xcode 打开、运行和调试。

## 8. 初始化后的验证标准

项目初始化不能只以“文件创建完成”为完成标准，必须验证：

- `xcodegen generate` 可以生成 Xcode 工程。
- `xcodebuild` 可以列出 schemes。
- iOS Simulator 可以构建。
- iPad Simulator 可以构建。
- macOS target 可以构建。
- SwiftLint 可以运行，或明确记录暂未接入。
- SwiftFormat 可以检查，或明确记录暂未接入。
- `git status --short` 中没有意外临时文件。

当前统一验证入口：

```bash
scripts/verify.sh
```

当前脚本展开为：

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
if rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'; then
  echo "Documentation placeholder scan found entries." >&2
  exit 1
fi
git status --short
```

## 9. 后续里程碑建议

### Milestone 1：App Shell

- 原生工程可启动。
- 平台根布局可区分 iPhone、iPad、macOS。
- 占位导航清晰。

### Milestone 2：首次启动与语言空间

- 首次启动询问母语、目标语言、水平自评。
- 创建第一个语言空间。
- 暂用内存或轻量本地持久化。

### Milestone 3：本地记录闭环

- 创建生活记录。
- 展示记录时间线。
- 以“中文母语 -> 英语目标语言”作为首个示例转换占位。
- 示例语言不能写死到数据模型、Prompt Preset、TTS 设置或路由中。

### Milestone 4：AI Provider 抽象

- 接入 OpenAI-compatible Provider 配置。
- 支持请求预览。
- API Key 进入 Keychain。

### Milestone 5：听读练习闭环

- TTS 播放。
- 逐句跟读。
- 听写和回译基础流程。

### Milestone 6：本地存储与长期记忆

- SQLite / GRDB。
- FTS。
- 词句记忆。
- 可重建向量索引。

## 10. 进入实现前的检查清单

开始创建 SwiftUI 工程前，应确认：

- Xcode 和 iOS Simulator 已安装并可启动。
- `environment.md` 中环境记录仍然准确。
- 是否采用 XcodeGen 已明确。
- 初始工程目录名已明确。
- 第一个提交只包含工程骨架和必要文档，不混入功能实现。
- `.vscode/` 是否纳入版本控制已明确。
