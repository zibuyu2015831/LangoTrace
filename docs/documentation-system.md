# 语迹 / LangoTrace 文档体系规范

本文档定义语迹 LangoTrace 的文档组织方式。项目目标是开发一款可长期维护、面向付费用户的 Apple 三端 App，因此从第一天开始采用严格工程化的文档体系。

## 1. 文档体系目标

文档体系需要解决以下问题：

- 后续新会话能快速理解当前项目状态。
- 产品、交互、技术、数据、隐私、同步和商业模式的关键判断可回溯。
- SwiftUI 工程初始化、架构拆分、数据库设计、AI Provider、同步引擎、StoreKit 和发布流程都有固定文档落点。
- 避免“聊天里讨论过，但仓库里找不到”的知识丢失。
- 避免早期开发为了速度牺牲付费 App 所需的稳定性、可测试性和数据安全边界。

## 2. 文档分层

### 2.1 主参考文档

主参考文档放在 `docs/` 根目录，用于长期稳定引用。

- `product-main-reference.md`：产品北极星，记录产品名称、定位、核心闭环、功能边界和商业设计。
- `technical-framework-roadmap.md`：技术路线总纲，记录 Apple 原生路线、存储、同步、Provider 和长期架构判断。
- `development-environment.md`：本机开发环境基线。
- `development-open-source-references.md`：开源参考项目和许可证风险。
- `AI_ENTRY_POINT.md`：AI 会话入口，规定后续新会话如何按任务类型读取相关文档。
- `project-initialization.md`：当前项目初始化规划。
- `documentation-system.md`：本文档，规定文档体系。

主参考文档应保持相对稳定。若发生关键变化，需要同步更新相关决策记录。

### 2.2 架构文档

位置：`docs/architecture/`

用途：

- 记录模块边界、依赖方向和核心数据流。
- 记录数据模型、SQLite schema、迁移策略、Repository 设计和索引策略。
- 记录 AI Provider、Prompt Preset、TTS、OCR、Speech、Sync Engine 和 StoreKit 的技术边界。

推荐命名：

```text
docs/architecture/001-app-shell-and-module-boundaries.md
docs/architecture/002-local-data-model.md
docs/architecture/003-ai-provider-architecture.md
docs/architecture/004-sync-engine.md
```

### 2.3 决策记录

位置：`docs/decisions/`

用途：

- 记录不可轻易更改的重要决策。
- 说明背景、备选方案、最终结论、影响范围和复审条件。

推荐采用 ADR 风格：

```text
docs/decisions/001-use-swiftui-multiplatform.md
docs/decisions/002-use-sqlite-grdb-for-long-term-storage.md
docs/decisions/003-language-space-as-primary-information-model.md
```

每份决策记录建议包含：

```text
# ADR-001: 决策标题

日期：
状态：Accepted / Superseded / Rejected

## 背景
## 决策
## 备选方案
## 影响
## 风险
## 复审条件
```

### 2.4 开发文档

位置：`docs/development/`

用途：

- 记录阶段计划、开发 runbook、工程初始化步骤和里程碑。
- 给后续开发会话提供明确执行入口。

推荐命名：

```text
docs/development/001-initial-swiftui-project-runbook.md
docs/development/002-first-launch-onboarding-plan.md
docs/development/003-language-space-mvp-plan.md
```

### 2.5 测试文档

位置：`docs/testing/`

用途：

- 记录自动化测试策略。
- 记录手动测试流程。
- 记录模拟器、真机和跨端验证标准。

必须覆盖的风险区：

- 首次启动和语言空间创建。
- 本地数据读写和迁移。
- AI 请求预览和隐私边界。
- 照片、麦克风、语音、OCR 权限。
- TTS、录音、听写和回译练习流程。
- 同步冲突和数据导出。
- StoreKit 买断制购买与恢复购买。

### 2.6 发布文档

位置：`docs/release/`

用途：

- 记录 App Store、TestFlight、StoreKit、版本号、隐私标签、权限描述和发布检查清单。

推荐命名：

```text
docs/release/001-storekit-and-pricing.md
docs/release/002-app-store-review-checklist.md
docs/release/003-privacy-labels-and-permissions.md
```

### 2.7 研究文档

位置：`docs/research/`

用途：

- 记录竞品分析、开源项目阅读、设计研究、技术调研和许可证分析。
- 不作为最终产品决策，除非后续同步到主参考文档或 ADR。

### 2.8 规格与计划

位置：

- `docs/superpowers/specs/`
- `docs/superpowers/plans/`

用途：

- `specs/` 保存较大功能或架构变更的设计规格。
- `plans/` 保存具体实施计划，供当前会话或后续会话按步骤执行。

## 3. 文档更新规则

### 3.1 必须更新文档的情况

以下情况必须更新文档：

- 项目当前状态变化，例如 SwiftUI 工程已创建、XcodeGen 已接入、MVP 里程碑发生改变。
- 产品核心模型变化，例如语言空间、单人使用、首次启动、导航结构。
- 技术路线变化，例如放弃 SwiftUI、改用 SwiftData、改用 CloudKit-only。
- 数据边界变化，例如哪些数据是主数据、哪些是可重建派生数据。
- 隐私边界变化，例如哪些内容会发送给 AI Provider。
- 同步方案变化，例如新增 WebDAV / S3 / R2 同步。
- 付费策略变化，例如买断制、内购、订阅、试用。
- 发布流程变化，例如 TestFlight、App Store 审核和隐私标签。

### 3.2 可以只写阶段记录的情况

以下情况可以写在 `docs/development/` 或 `docs/testing/`：

- 某次环境检查结果。
- 某个模拟器验证结果。
- 某个里程碑临时计划。
- 某个功能的手动测试流程。

### 3.3 不应写入长期文档的内容

以下内容不应进入主参考文档：

- 临时聊天摘要。
- 未确认的灵感碎片。
- 已废弃且无复审价值的原型细节。
- 没有结论的零散竞品截图描述。

若内容有参考价值，应先放入 `docs/research/`，待形成结论后再迁移到主参考文档或 ADR。

## 4. 严格工程化要求

### 4.0 AI 会话入口优先

后续 AI 辅助编程或产品讨论应优先阅读 `docs/AI_ENTRY_POINT.md`。

这个入口文件只承担路由和全局约束作用，不替代具体文档。AI 应根据任务类型继续阅读产品主参考、技术路线、ADR、架构文档、测试文档或发布文档。

如果入口文件中的“项目当前状态”与仓库实际状态不一致，应优先更新入口文件和 `docs/README.md`，避免后续会话建立错误上下文。

### 4.1 先边界，后实现

每个较大功能进入实现前，应至少明确：

- 目标用户路径。
- 数据模型影响。
- 平台差异。
- 权限影响。
- 隐私影响。
- 测试方式。

### 4.2 先主数据，后派生能力

语迹是长期记录产品，主数据边界必须优先于 AI 能力。

主数据示例：

- 用户记录原文。
- 目标语言生成文本。
- 逐句对齐关系。
- 用户收藏的词句。
- 练习记录。
- 照片和音频附件元数据。
- Prompt Preset。
- 用户配置。

派生数据示例：

- FTS 索引。
- 向量索引。
- AI 摘要。
- 相似记忆召回结果。
- 临时请求预览。

派生数据默认可重建，不应优先进入同步主协议。

### 4.3 付费 App 质量门槛

因为语迹目标是买断制付费 App，以下内容不能作为后期补丁：

- 数据迁移策略。
- 导出和备份路径。
- AI 请求隐私预览。
- Keychain 密钥保存。
- 权限说明。
- StoreKit 恢复购买。
- 崩溃和失败状态处理。
- 手动测试清单。

## 5. 新文档写作规范

所有长期文档默认使用中文书写。专有名词、API 名称、文件路径和代码符号保留英文。

建议风格：

- 先给结论，再给依据。
- 使用清晰的小标题。
- 避免空泛表达。
- 对未实现内容明确写“计划”“候选”“后续”，不要伪装成已完成。
- 每份文档都应能独立说明上下文。

## 6. 提交规则

建议按主题提交：

- 产品和交互文档一次提交。
- 技术架构文档一次提交。
- 工程初始化一次提交。
- 原型图修改一次提交。
- 环境记录一次提交。

提交前至少检查：

```bash
git status --short
find docs -maxdepth 3 -type f | sort
```

若涉及 Markdown 结构，可额外使用 ripgrep 检查未完成占位表达。
