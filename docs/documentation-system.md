# 语迹 / LangoTrace 文档体系规范

本文档定义语迹 LangoTrace 的文档组织方式。项目目标是开发一款可长期维护、面向付费用户的 Apple 三端 App，因此从第一天开始采用严格工程化的文档体系。

## 1. 文档体系目标

文档体系需要解决以下问题：

- 后续新会话能快速理解当前项目状态。
- 产品、交互、技术、数据、隐私、同步和商业模式的关键判断可回溯。
- SwiftUI 工程初始化、架构拆分、数据库设计、AI Provider、同步引擎、StoreKit 和发布流程都有固定文档落点。
- 避免“聊天里讨论过，但仓库里找不到”的知识丢失。
- 避免早期开发为了速度牺牲付费 App 所需的稳定性、可测试性和数据安全边界。
- 避免代码持续演进后，入口文档、架构文档、开发规范、测试文档和发布文档滞后于实际实现。

## 2. 文档分层

### 2.1 主参考文档

主参考文档放在 `docs/` 根目录，用于长期稳定引用。

- `product-main-reference.md`：产品北极星，记录产品名称、定位、核心闭环、功能边界和商业设计。
- `technical-framework-roadmap.md`：技术路线总纲，记录 Apple 原生路线、存储、同步、Provider 和长期架构判断。
- `development-environment.md`：本机开发环境基线。
- `development-open-source-references.md`：开源参考项目和许可证风险。
- `README.md`：文档总入口，也是 AI 会话入口；根目录 `AI_ENTRY_POINT.md`、`CLAUDE.md` 和 `AGENTS.md` 通过软链接指向它。
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

### 2.5 开发规范

位置：`docs/guidelines/`

用途：

- 记录后续开发必须遵守的导航、UI、SwiftUI 架构、AI Provider、隐私和测试等一致性规范。
- 帮助后续 AI 会话保持实现风格一致，避免每个功能重新定义局部架构。
- 标注哪些规则是强制的，哪些是默认推荐，哪些可以在开发过程中演进。

第一批规范：

```text
docs/guidelines/001-guideline-governance.md
docs/guidelines/002-navigation-and-routing.md
docs/guidelines/003-ui-design-system.md
docs/guidelines/004-swiftui-architecture.md
docs/guidelines/005-ai-provider-prompt-and-privacy.md
```

规范不是一成不变的教条。若开发中发现更优设计，可以更新对应 guideline；若影响产品核心模型、技术路线、数据边界、隐私边界或商业模式，应新增或更新 ADR。

### 2.6 开发工作记录

位置：`docs/worklogs/`

用途：

- 记录每一次重要功能开发、bug 修复、重构、调研和工程杂项任务。
- 作为具体工作的过程记录入口，记录背景、目标、范围、分析、方案、风险、用户确认、实施和验证结果。
- 避免拆分过多目录导致开发时不知道文档放在哪里。

命名规范：

```text
YYYY-MM-DD-<type>-<short-topic>.md
```

允许的 `type`：

- `feature`
- `bug`
- `refactor`
- `research`
- `chore`

必须先创建 worklog 并经用户确认后再实现的任务：

- 新功能。
- bug 修复。
- 架构调整。
- 数据、AI、隐私、同步、权限、StoreKit 相关任务。
- 影响用户路径或多端体验的任务。
- 改变开发规范、模块边界或长期维护方式的任务。

低风险错别字、轻量文档修正或用户明确要求跳过记录的小任务，可以不创建 worklog，但最终答复应说明原因。

### 2.7 测试文档

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

### 2.8 发布文档

位置：`docs/release/`

用途：

- 记录 App Store、TestFlight、StoreKit、版本号、隐私标签、权限描述和发布检查清单。

推荐命名：

```text
docs/release/001-storekit-and-pricing.md
docs/release/002-app-store-review-checklist.md
docs/release/003-privacy-labels-and-permissions.md
```

### 2.9 研究文档

位置：`docs/research/`

用途：

- 记录竞品分析、开源项目阅读、设计研究、技术调研和许可证分析。
- 不作为最终产品决策，除非后续同步到主参考文档或 ADR。

### 2.10 规格与计划

位置：

- `docs/superpowers/specs/`
- `docs/superpowers/plans/`

用途：

- `specs/` 保存较大功能或架构变更的设计规格。
- `plans/` 保存具体实施计划，供当前会话或后续会话按步骤执行。

### 2.11 文档审查

位置：`docs/review/`

用途：

- 定义文档一致性治理机制。
- 保存审查轮次总索引。
- 保存事件触发专项审查和里程碑轻量全审记录。
- 区分当前事实源、决策源、执行规则源、过程记录和审查记录，避免把历史记录误当成当前实现事实。

目录结构：

```text
docs/review/
  README.md
  INDEX.md
  rounds/
```

`docs/review/README.md` 规定审查目标、文档分级、断言依据、触发矩阵、问题分流、写入权限、审查产物和验收方式。

`docs/review/INDEX.md` 是所有审查轮次的长期索引，只保存长期状态，不存放单轮细节。

`docs/review/rounds/` 保存专项审查和里程碑轻量全审。日常文档影响检查写在对应 worklog 中，不在这里创建目录。

## 3. 文档更新规则

### 3.1 必须更新文档的情况

以下情况必须更新文档：

- 项目当前状态变化，例如 SwiftUI 工程已创建、XcodeGen 已接入、MVP 里程碑发生改变。
- 重要开发工作开始或完成，例如新增功能、bug 修复、架构调整和高风险文档变更。
- 产品核心模型变化，例如语言空间、单人使用、首次启动、导航结构。
- 技术路线变化，例如放弃 SwiftUI、改用 SwiftData、改用 CloudKit-only。
- 开发规范变化，例如新增导航模式、UI 组件体系、SwiftUI 状态管理方式或 AI 请求路径。
- 数据边界变化，例如哪些数据是主数据、哪些是可重建派生数据。
- 隐私边界变化，例如哪些内容会发送给 AI Provider。
- 同步方案变化，例如新增 WebDAV / S3 / R2 同步。
- 付费策略变化，例如买断制、内购、订阅、试用。
- 发布流程变化，例如 TestFlight、App Store 审核和隐私标签。

### 3.1.1 必须检查文档影响的情况

以下情况完成后必须检查是否触发 `docs/review/README.md` 定义的审查机制：

- 数据库 schema、Repository、迁移、导出、备份。
- AI Provider、Keychain、请求预览、请求日志、隐私边界。
- 权限、Speech、OCR、Photos、TTS、录音。
- 同步引擎、Sync Adapter、冲突处理。
- StoreKit、发布验证、App Store 隐私标签。
- ADR 冲突或核心产品决策冲突。
- 首次启动闭环、语言空间闭环、本地记录闭环。
- 多端导航结构、验证脚本、XcodeGen、包边界或 App 启动结构变化。
- AI 会话发现文档与代码不一致。

未命中专项审查条件的一般功能、bug、重构、UI 体验调整和测试补充，应在对应 worklog 的“文档影响检查”中记录是否需要更新文档。

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

### 3.4 文档审查规则

文档审查遵循以下权威关系：

- 当前实现事实以代码、`project.yml`、脚本和测试为最高依据。
- 产品核心决策以产品主参考文档、ADR 和用户明确确认为最高依据。
- 架构和隐私决策以 ADR、技术路线和 guidelines 为最高依据。
- 未来计划以 roadmap、worklog、规格或计划文档为依据，必须明确写成计划、候选或后续。
- worklog、research、review round 是过程记录，不强制改写为最新事实。

如果代码与 ADR 或核心产品决策冲突，不能默认改文档迁就代码，应触发复审、记录架构债、修正实现或新增 ADR。

## 4. 严格工程化要求

### 4.0 文档入口优先

后续 AI 辅助编程或产品讨论应优先阅读根目录 `AI_ENTRY_POINT.md`、`CLAUDE.md`、`AGENTS.md` 或 `docs/README.md`。这些入口指向同一份内容。

这个入口文件只承担路由和全局约束作用，不替代具体文档。AI 应根据任务类型继续阅读产品主参考、技术路线、ADR、架构文档、开发规范、测试文档或发布文档。

如果入口文件中的“项目当前状态”与仓库实际状态不一致，应优先更新 `docs/README.md`，避免后续会话建立错误上下文。

### 4.1 先边界，后实现

每个较大功能进入实现前，应至少明确：

- 目标用户路径。
- 数据模型影响。
- 平台差异。
- 权限影响。
- 隐私影响。
- 测试方式。

### 4.1.1 先规范，后代码

涉及具体实现风格的开发任务，应先读取对应 `docs/guidelines/` 文档。

例如：

- 做页面路由前读导航与路由规范。
- 做 SwiftUI 组件前读 UI 设计系统规范和 SwiftUI 架构规范。
- 做 AI 请求前读 AI Provider、Prompt 与隐私规范。

如果规范与实际实现冲突，应先明确是更新规范还是修正实现，不能让两套模式并存。

### 4.1.2 先记录，后实现

新功能、bug 修复、架构调整、数据/AI/隐私/同步/权限/付费相关任务，在实现前必须先创建 `docs/worklogs/YYYY-MM-DD-<type>-<short-topic>.md`。

worklog 应至少写清：

- 背景。
- 目标。
- 范围。
- 不做什么。
- 分析。
- 方案。
- 风险与边界。
- 测试与验证。
- 用户确认记录。

状态为 `Draft` 时不能开始实现。用户确认后将状态改为 `User Approved`，再进入实现。

### 4.1.3 先检查文档影响，后收尾

重要功能、bug 修复、架构调整和高风险文档任务完成前，应检查本次变更是否影响文档体系。

默认规则：

- 日常文档影响检查写入对应 worklog。
- 事件触发专项审查写入 `docs/review/rounds/YYYY-MM-DD-<topic>/README.md`。
- 里程碑轻量全审写入 `docs/review/rounds/YYYY-MM-DD-<topic>/README.md`，并更新 `docs/review/INDEX.md`。

审查过程中发现代码问题时，不应顺手修改代码；应分流为 bug、refactor、chore、testing 或 ADR 复审任务。

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
git diff --check
```

若涉及 Markdown 结构，可额外使用 ripgrep 检查未完成占位表达。

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
```
