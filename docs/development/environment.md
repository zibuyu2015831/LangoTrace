# LangoTrace 开发环境记录

本文档记录语迹 LangoTrace 当前本机开发环境基线，便于后续新会话快速理解项目状态，不需要重新排查 Apple 开发工具链。

最后验证日期：2026-05-17

## 1. 开发设备

- 设备：MacBook Air M4
- 系统：macOS 26.4.1
- 系统构建号：25E253
- 架构：Apple Silicon，arm64
- 仓库路径：`/Users/zibuyu/code/zibuyu/LangoTrace`
- 设备为 MacBook Air（被动散热），长时间编译易发烫/超时：**重测试（全量验证、三端构建、跨多包测试）放 GitHub Actions，本机只做轻量单包测试与 `swiftformat`/`swiftlint` 自查**。详见 [CI 与分支协作 Runbook §1.1](002-ci-and-branch-workflow.md) 与 [009 测试与验证入口规范](../spec/009-testing-and-verification.md)。

## 2. Apple 开发工具链

- Xcode：26.5
- Xcode build：17F42
- 当前 developer directory：`/Applications/Xcode.app/Contents/Developer`
- Swift：6.3.2
- Swift target：`arm64-apple-macosx26.0`
- Xcode license：已接受

通过 `xcodebuild -showsdks` 验证到的 SDK：

- iOS SDK：`iphoneos26.5`
- iOS Simulator SDK：`iphonesimulator26.5`
- macOS SDK：`macosx26.5`
- watchOS SDK：`watchos26.5`
- tvOS SDK：`appletvos26.5`
- visionOS SDK：`xros26.5`

## 3. Simulator 基线

Xcode Components 中已确认：

- macOS 26.5：内置
- iOS 26.5：已安装

`Simulator.app` 已通过以下路径成功打开：

```bash
open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
```

图形界面已验证：

- Simulator 应用可以启动。
- `iPhone 17` 模拟器可以启动到 iOS 26.5 主屏幕。

通过提升权限执行 `xcrun simctl list` 验证到的 runtime：

```text
== Runtimes ==
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

可用模拟器设备包括：

- iPhone 17 Pro
- iPhone 17 Pro Max
- iPhone 17e
- iPhone Air
- iPhone 17
- iPad Pro 13-inch (M5)
- iPad Pro 11-inch (M5)
- iPad mini (A17 Pro)
- iPad Air 13-inch (M4)
- iPad Air 11-inch (M4)
- iPad (A16)

已知环境边界：

- 在 Codex 默认沙箱中，`xcrun simctl list runtimes` 和 `xcrun simctl list devices available` 可能会因为 `CoreSimulatorService connection became invalid` 与 `Operation not permitted` 失败。
- 相同命令在沙箱外或提升权限执行时可以通过。
- 这是 Codex 执行权限边界，不代表 Xcode 或 Simulator 未安装。

## 4. Homebrew 与开发辅助工具

- Homebrew：5.1.11
- Homebrew prefix：`/opt/homebrew`
- Git：系统 Apple Git 可用
- SQLite：3.51.0
- XcodeGen：2.45.4
- SwiftLint：0.63.2
- SwiftFormat：0.61.1
- GitHub CLI：2.92.0
- SF Symbols：7.2，安装路径为 `/Applications/SF Symbols.app`

GitHub CLI（`gh`）是本项目的**必备开发工具**，用于获取 CI 失败日志、触发 workflow 和管理 PR；首次使用需 `gh auth login` 完成认证。安装、认证和基于 `gh` 的 CI 失败日志获取流程见 [CI 与分支协作 Runbook](002-ci-and-branch-workflow.md)。

## 5. 代码签名

当前代码签名证书状态：

```text
0 valid identities found
```

这不影响早期本地项目搭建和模拟器开发。后续如果需要真机调试、TestFlight、CloudKit 生产环境测试或 App Store 发布，需要在 Xcode 中登录 Apple Developer Account，并配置有效的签名身份。

## 6. 仓库状态

当前项目状态：

- 产品文档位于 `docs/`。
- 静态 HTML 原型位于 `prototypes/`，入口为 `prototypes/index.html`。
- SwiftUI Multiplatform 工程已创建。
- XcodeGen 配置位于 `project.yml`。
- Xcode 工程位于 `LangoTrace.xcodeproj`。
- 初始模块位于 `Packages/LangoTraceCore`、`Packages/LangoTraceUI`、`Packages/LangoTraceData`、`Packages/LangoTraceAI`、`Packages/LangoTraceSpeech` 和 `Packages/LangoTraceSync`。
- App 入口位于 `LangoTraceApp/`，当前通过 `AppEnvironment` 装配 empty / disabled 边界实现。
- 当前已有 Welcome / Onboarding / Main 启动状态、内存语言空间 preview、三端 SwiftUI 产品骨架、隐私状态图标和 iPad 面板手势 helper。
- `Packages/LangoTraceCore` 和 `Packages/LangoTraceUI` 已有首批 Testing 测试。
- `scripts/verify.sh` 是当前统一验证入口；`.github/workflows/ci.yml` 是它的远程镜像，跑同一套 package 测试、三端构建、lint 和文档检查。触发策略：直接 push 到 `main`/`dev` 需 commit message 含 `[ci]`，PR 到 `main`/`dev` 与手动 `workflow_dispatch` 总是运行，详见 `docs/spec/009-testing-and-verification.md`。
- 仓库已有初始提交：`7ce34b7 Initial LangoTrace product docs and prototype`。
- 本地 `.vscode/` 设置目录存在，但仍是未跟踪文件，不属于已提交的项目基线。

## 7. 新会话快速检查命令

新开发会话开始时，可优先执行以下命令：

```bash
sw_vers
xcode-select -p
xcodebuild -version
swift --version
xcodebuild -showsdks
xcodegen --version
swiftlint --version
swiftformat --version
gh --version
sqlite3 --version
find /Applications -maxdepth 1 -iname '*Symbols*.app' -print
git status --short
```

Simulator 检查命令在 Codex 中可能需要提升权限执行：

```bash
xcrun simctl list runtimes
xcrun simctl list devices available
```

## 8. 下一步工程动作

当前环境已经满足继续开发语迹 LangoTrace SwiftUI Multiplatform 应用的要求。当前原生 Apple 项目骨架和产品体验骨架已覆盖：

- iOS
- iPadOS
- macOS

下一步实现里程碑应保持克制，优先完成：

- 最小本地记录模型与创建流程。
- 本地记录时间线和记录选择状态。
- 英语示例学习材料展示闭环。

已完成但仍需人工验收或后续平台扩展：

- 真实语言空间持久化和启动恢复。
- iPhone 设置页语言空间管理入口。

继续暂不加入：

- Entry/附件/导出等完整数据库迁移体系、真实 AI Provider、同步引擎或 StoreKit 逻辑。
- TTS、录音、Speech、OCR、照片权限等平台能力。

## 首次 clone 后的必要配置

以下步骤只需在每台新机器或重新 clone 后执行一次：

```bash
# 激活仓库内置 Git 钩子（pre-commit API Key 扫描 + pre-push main 分支保护）
# 仅写入本仓库 .git/config，不带 --global，不影响其他仓库
git config core.hooksPath scripts/git-hooks
chmod +x scripts/git-hooks/*

# 验证
git config --get core.hooksPath   # 应输出 scripts/git-hooks

# 复制 probe 脚本凭证模板，填入真实密钥（文件已 gitignore，不会提交）
cp scripts/probe/.env.example scripts/probe/.env
# 然后编辑 scripts/probe/.env，把占位符替换为真实 API Key
```

钩子说明见 [scripts/git-hooks/README.md](../../scripts/git-hooks/README.md)：
- `pre-commit`：每次 `git commit` 前扫描暂存文件中的 API Key 模式，阻止真实密钥进入历史。
- `pre-push`：阻止直接向 `main` 推送，强制走 PR 流程。
- 误报绕过：`git commit --no-verify`（需人工确认无密钥后使用）。

已完成的初始化验证包括：

- `xcodegen generate`
- `xcodebuild -list -project LangoTrace.xcodeproj`
- `swift test --package-path Packages/LangoTraceCore`
- `swift test --package-path Packages/LangoTraceUI`
- `xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`
- `xcodebuild -quiet -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`
