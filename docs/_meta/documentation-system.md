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

### 2.1 根目录主参考文档

根目录只保留需要被新会话高频读取、且不明显属于某个子目录职责的长期主参考文档。

- `product-main-reference.md`：产品北极星，记录产品名称、定位、核心闭环、功能边界和商业设计。
- `technical-framework-roadmap.md`：技术路线总纲，记录 Apple 原生路线、存储、同步、Provider 和长期架构判断。
- `README.md`：文档总入口，也是 AI 会话入口；根目录 `AI_ENTRY_POINT.md`、`CLAUDE.md` 和 `AGENTS.md` 通过软链接指向它。

主参考文档应保持相对稳定。若发生关键变化，需要同步更新相关决策记录。

以下长期文档虽然重要，但已经归入职责更明确的子目录：

- `docs/_meta/documentation-system.md`：文档体系规范。
- `docs/development/environment.md`：本机开发环境基线。
- `docs/development/project-initialization.md`：项目初始化规划和当前初始化基线。
- `docs/reference/README.md`：外部参考项目、本地源码软链接、功能参考映射和许可证边界。

### 2.2 架构文档

位置：`docs/architecture/`

用途：

- 记录模块边界、依赖方向和核心数据流。
- 记录当前系统地图、关键入口点、运行时对象、关键数据流、模块依赖方向和故障恢复矩阵索引。
- 记录数据模型、SQLite schema、迁移策略、Repository 设计和索引策略。
- 记录 AI Provider、Prompt Preset、TTS、OCR、Speech、Sync Engine 和 StoreKit 的技术边界。
- `docs/architecture/notes/` 保存架构级开发备忘录，用于记录尚未进入正式架构文档、spec、ADR 或任务方案的跨任务扩展提醒。

推荐命名：

```text
docs/architecture/001-app-shell-and-module-boundaries.md
docs/architecture/002-local-data-model.md
docs/architecture/003-ai-provider-architecture.md
docs/architecture/004-sync-engine.md
docs/architecture/notes/YYYY-MM-DD-<topic>-notes.md
```

架构开发备忘录不是最终事实源。它只能作为未来任务方案的设计输入和检查清单；后续采纳其中结论时，必须提升到对应任务方案、正式架构文档、`docs/spec/` 或 `docs/decisions/`。

### 2.3 决策记录

位置：`docs/decisions/`

用途：

- 记录不可轻易更改的重要决策。
- 说明背景、备选方案、最终结论、影响范围和复审条件。
- 不维护 implementation 文档、实现地图或阶段执行细节；这些内容分别写入 `docs/spec/<module>/impl.md`、`docs/architecture/`、`docs/development/` 或 `docs/plans/`。

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

如果某份阶段 runbook 中形成了不可轻易反转的平台、架构、隐私、同步或商业取舍，应把“决策本身”抽取为 ADR；原 runbook 可以继续保留执行顺序、验证矩阵和操作步骤。不要在 `docs/decisions/` 下新增 `implementation.md` 来替代 `docs/development/` 或 `docs/spec/<module>/impl.md`。

### 2.4 开发文档

位置：`docs/development/`

用途：

- 记录阶段级开发 runbook、工程初始化步骤、开发环境基线、跨任务工程路线和里程碑状态。
- 给后续开发会话提供阶段上下文，不替代 `docs/plans/active/` 中的一项需求或一个 bug 的唯一实施方案。

推荐命名：

```text
docs/development/001-initial-swiftui-project-runbook.md
docs/development/002-platform-development-sequence.md
docs/development/003-release-readiness-runbook.md
docs/development/environment.md
```

### 2.5 规范文档

位置：`docs/spec/`

用途：

- 记录后续开发必须遵守的导航、UI、SwiftUI 架构、AI Provider、隐私和测试等一致性规范。
- 帮助后续 AI 会话保持实现风格一致，避免每个功能重新定义局部架构。
- 标注哪些规则是强制的，哪些是默认推荐，哪些可以在开发过程中演进。
- 后续模块可以在本目录下形成 `spec.md` 和 `impl.md`，让模块规范与当前实现地图保持同目录。
- 高风险模块可以补充故障与恢复路径矩阵，明确已知失败模式、恢复行为、测试覆盖和剩余风险。
- `docs/architecture/002-system-map.md` 是当前工程结构的快速入口；它不替代 ADR、spec 或任务方案，更新时必须刷新代码快照和最后核对日期。

当前核心规范入口以 `docs/spec/README.md` 为准。现有高优先级规范包括：

```text
docs/spec/001-guideline-governance.md
docs/spec/002-navigation-and-routing.md
docs/spec/003-ui-design-system.md
docs/spec/004-swiftui-architecture.md
docs/spec/005-ai-provider-prompt-and-privacy.md
docs/spec/006-interface-localization-and-language-boundaries.md
docs/spec/007-data-storage-migration-export-and-attachments.md
docs/spec/008-permissions-local-privacy-and-diagnostics.md
docs/spec/009-testing-and-verification.md
docs/spec/010-apple-platform-interaction-and-accessibility.md
```

规范不是一成不变的教条。当前项目处于起步阶段，若开发中发现更优设计，可以更新对应 spec；若影响产品核心模型、技术路线、数据边界、隐私边界或商业模式，应新增或更新 ADR。

### 2.6 任务方案

位置：`docs/plans/`

用途：

- 记录每一次重要功能开发、bug 修复、重构、调研、文档治理和工程杂项任务。
- 作为具体工作的唯一方案入口，记录背景、目标、范围、分析、方案、风险、用户确认、实施和验证结果。
- 用 `active/` 与 `done/` 表达任务生命周期，避免 worklog 草案和 plan 分散维护。

命名规范：

```text
docs/plans/active/YYYY-MM-DD-<type>-<short-topic>.md
docs/plans/done/YYYY-MM-DD-<type>-<short-topic>.md
```

允许的 `type`：

- `feature`
- `bug`
- `refactor`
- `research`
- `chore`

必须先创建任务方案并经用户确认后再实现的任务：

- 新功能。
- bug 修复。
- 架构调整。
- 数据、AI、隐私、同步、权限、StoreKit 相关任务。
- 影响用户路径或多端体验的任务。
- 改变开发规范、模块边界或长期维护方式的任务。

低风险错别字、轻量文档修正或用户明确要求跳过记录的小任务，可以不创建任务方案，但最终答复应说明原因。

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

### 2.7.1 Prompt 文档

位置：`docs/prompts/`

用途：

- 记录代码中真实使用或计划使用的 Prompt。
- 记录 Prompt 输入变量、输出契约、请求预览、隐私等级和评测方式。
- 同时保存英文版本和中文版本；代码内置 Prompt 以英文为准，中文用于客户阅读、校对和隐私审查。

具体 Prompt 文档在功能落地时创建。当前阶段只维护 `docs/prompts/README.md` 规则，不预先创建具体 Prompt 文档。

### 2.7.2 开发 Workflow

位置：`docs/workflows/`

用途：

- 保存高频、高风险开发动作的执行手册。
- 帮助后续 AI 会话快速确认某类任务应读取哪些权威文档、修改哪些代码和文档落点、运行哪些验证。
- 承接参考项目中可复用的工程执行经验，例如新增 Provider、TTS、数据迁移、平台页面和 Prompt 的动作清单。

边界：

- Workflow 不是产品决策源、架构事实源或实现事实源。
- Workflow 不能复制长期规则正文；应链接到 `docs/spec/`、`docs/architecture/`、`docs/decisions/`、`docs/review/` 或 `docs/prompts/`。
- 具体任务仍必须写入 `docs/plans/active/` 并经用户确认。
- 如果 workflow 与权威文档冲突，应优先更新权威文档或当前任务方案，而不是让 workflow 成为第二事实源。

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

### 2.9 参考和研究文档

位置：

- `docs/reference/`
- `docs/reference/projects/`
- `docs/reference/research/`

用途：

- `docs/reference/README.md` 作为外部参考项目总入口，记录本地源码软链接、功能参考映射、项目阅读顺序和许可证边界。
- `docs/reference/projects/` 只放当前已登记参考项目的本地源码软链接，不作为 LangoTrace 当前代码事实源。
- `docs/reference/research/` 记录参考项目研究、竞品分析、设计研究、技术调研和许可证分析。
- `docs/reference/research/spikes/` 记录 spike / probe / fixture / evidence 的研究落点规则，以及需要保留的短期验证上下文。
- 参考和研究资料不作为最终产品决策、架构事实或实现事实；被采纳的结论必须同步到主参考文档、`docs/spec/`、`docs/architecture/` 或 `docs/decisions/`。

spike / probe / fixture / evidence 的边界：

- spike 是实现前的短期可行性验证，默认写入当前任务方案；需要保留研究上下文时放入 `docs/reference/research/spikes/`。
- probe 是可重复运行的小型验证脚本或样例；长期保留时应进入 `scripts/`、`Tests/Tooling/`、package tests 或 reference research，并写明运行方式、跳过条件和剩余风险。
- fixture 是自动化测试或研究依赖的稳定样本，优先靠近对应 test target；外部格式研究样本可放入 reference research，但不得包含真实用户敏感内容。
- evidence 是审查 round 的命令输出、截图、日志和手动验证记录，归入 `docs/review/rounds/<round>/`。

### 2.10 历史规格与计划目录

位置：

- `docs/archive/superpowers/`

用途：

- 这是旧 `docs/superpowers/` 的历史归档位置，不再作为新任务入口。
- 仍有价值的规格已经迁入 `docs/spec/`。
- 与历史任务重复的旧实施计划归档到 `docs/archive/superpowers/plans/`，避免在 `docs/plans/` 下为同一任务保留两份方案。

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

`docs/review/rounds/` 保存专项审查和里程碑轻量全审。日常文档影响检查写在对应任务方案中，不在这里创建目录。

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
- Workflow 规则变化，例如新增高风险开发动作手册、改变必读文档顺序或改变完成前检查口径。
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

未命中专项审查条件的一般功能、bug、重构、UI 体验调整和测试补充，应在对应任务方案的“文档影响检查”中记录是否需要更新文档。

### 3.2 可以只写阶段记录的情况

以下情况可以写在 `docs/development/` 或 `docs/testing/`，但不能替代单项任务方案：

- 某次环境检查结果。
- 某个模拟器验证结果。
- 跨多个任务的阶段路线或里程碑 runbook。
- 某个功能的手动测试流程。

### 3.3 不应写入长期文档的内容

以下内容不应进入主参考文档：

- 临时聊天摘要。
- 未确认的灵感碎片。
- 已废弃且无复审价值的原型细节。
- 没有结论的零散竞品截图描述。

若内容有参考价值，应先放入 `docs/reference/research/`，待形成结论后再同步到主参考文档、spec、architecture 或 ADR。

若内容不是外部研究，而是当前开发过程产生的跨任务架构提醒，应放入对应领域的开发备忘录。当前架构级备忘录统一写入 `docs/architecture/notes/`；测试、发布、Prompt、参考研究等备忘性质内容应优先落入各自已有目录，而不是新增泛化的 `docs/memos/` 目录。

### 3.3.1 主动创建开发备忘录的情况

以下情况应主动创建或更新开发备忘录：

- 当前任务明确不实现某个未来能力，但当前设计会影响该未来能力的边界。
- 一个风险或候选方案会被多个未来任务复用，不适合只留在单个任务方案中。
- 讨论形成了重要的跨模块扩展提醒，但尚未稳定到需要写入 spec、正式架构文档或 ADR。
- 若后续 AI 会话忽略该提醒，可能造成数据库迁移、同步协议、隐私边界、权限模型、导出恢复或模块边界返工。

不应创建开发备忘录的情况：

- 单个任务的实施步骤、用户确认、验证命令和完成记录，应留在 `docs/plans/`。
- 已经稳定为开发一致性规则的内容，应写入 `docs/spec/`。
- 已经成为不可轻易反转的产品、架构、隐私、同步、付费取舍，应写入 `docs/decisions/`。
- 外部参考项目、竞品分析和许可证研究，应写入 `docs/reference/research/`。
- 手动测试流程和验证记录，应写入 `docs/testing/` 或对应任务方案。
- 发布、StoreKit 和 App Store 相关提醒，应写入 `docs/release/` 或对应任务方案。

### 3.4 文档审查规则

文档审查遵循以下权威关系：

- 当前实现事实以代码、`project.yml`、脚本和测试为最高依据。
- 产品核心决策以产品主参考文档、ADR 和用户明确确认为最高依据。
- 架构和隐私决策以 ADR、技术路线和 spec 为最高依据。
- 未来计划以 roadmap、任务方案、规格或计划文档为依据，必须明确写成计划、候选或后续。
- 历史 worklog、reference research、review round 是过程记录，不强制改写为最新事实。

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

涉及具体实现风格的开发任务，应先读取对应 `docs/spec/` 文档。

例如：

- 做页面路由前读导航与路由规范。
- 做 SwiftUI 组件前读 UI 设计系统规范和 SwiftUI 架构规范。
- 做 AI 请求前读 AI Provider、Prompt 与隐私规范。
- 做 AI Provider、TTS Provider、数据迁移、平台页面或 Prompt 前读对应 `docs/workflows/` 手册。

如果规范与实际实现冲突，应先明确是更新规范还是修正实现，不能让两套模式并存。

### 4.1.2 先记录，后实现

新功能、bug 修复、架构调整、数据/AI/隐私/同步/权限/付费相关任务，在实现前必须先创建 `docs/plans/active/YYYY-MM-DD-<type>-<short-topic>.md`。

任务方案应至少写清：

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

- 日常文档影响检查写入对应任务方案。
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
- 高风险能力的故障与恢复路径矩阵。
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
scripts/check-docs.sh
git diff --check
```

若涉及 Markdown 结构，可额外使用 ripgrep 检查未完成占位表达。

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
```
