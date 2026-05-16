# ADR-003: 使用 XcodeGen 管理 Xcode 工程生成

日期：2026-05-17

状态：Accepted

## 背景

语迹 LangoTrace 即将从文档和静态 HTML 原型进入 SwiftUI 工程初始化。项目目标是长期维护的付费 App，后续会涉及多个 target、Swift Package、测试 target、平台差异、构建设置、StoreKit 配置和可能的脚本化验证。

如果直接用 Xcode GUI 手动维护 `.xcodeproj`，早期上手直观，但工程结构和 build setting 的变化不容易审查，也不利于后续回放项目生成过程。

## 决策

使用 XcodeGen 管理 `.xcodeproj` 生成。

具体要求：

- 在仓库中维护 `project.yml`。
- 通过 `xcodegen generate` 生成 Xcode 工程。
- 将 target、scheme、platform、source path、资源路径、测试 target 和 build setting 尽量写入 `project.yml`。
- `.xcodeproj` 是否提交，后续可在工程初始化时根据实际协作方式决定；若提交，需要确保 `project.yml` 仍是工程结构的主要来源。

## 备选方案

### Xcode GUI 手动创建和维护项目

优点：

- 最符合 Xcode 初学者直觉。
- 不需要额外安装工具。
- 可以快速看到项目运行效果。

缺点：

- 工程文件变更难审查。
- 后续新增 target、scheme 和 build setting 时容易漂移。
- 不利于新会话快速理解工程结构来源。

### Tuist

优点：

- 工程管理能力强。
- 适合大型模块化项目。

缺点：

- 对当前单人早期项目偏重。
- 学习和维护成本高于 XcodeGen。

### XcodeGen

优点：

- 配置文件清晰。
- 工程可重复生成。
- 适合严格工程化但不过度复杂的早期项目。
- 后续新增 target 和 package 时更容易审查。

缺点：

- 需要额外安装 `xcodegen`。
- 初次配置需要理解 `project.yml`。

## 影响

- 项目初始化前需要安装或确认 XcodeGen。
- 后续修改 target、scheme、source path 和 build setting 时，应优先修改 `project.yml`。
- 开发文档需要写清楚如何生成、打开、构建和验证工程。

## 风险

- XcodeGen 配置错误会导致 Xcode 工程生成失败。
- 如果团队成员直接在 Xcode 中改工程文件而不更新 `project.yml`，会造成配置漂移。
- 某些 Xcode 新特性可能需要额外配置或手动补充。

缓解方式：

- 工程初始化时加入 `xcodegen generate` 验证。
- 在开发 runbook 中明确“修改工程结构先改 `project.yml`”。
- 提交前检查 `project.yml` 与生成后的工程状态。

## 复审条件

以下情况需要复审本决策：

- XcodeGen 对当前 Xcode 版本支持不足。
- Swift Package 化后 `.xcodeproj` 配置明显变少，手动维护更简单。
- 项目规模扩大到需要 Tuist 级别的模块管理能力。
- 用户学习成本显著高于收益。

