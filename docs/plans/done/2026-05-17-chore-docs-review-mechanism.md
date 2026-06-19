# 工作记录：文档体系审查机制草案

类型：chore

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/_meta/documentation-system.md`
- `docs/archive/worklogs/README.md`
- `case_skillatlas_review/核心原则说明.md`
- `case_skillatlas_review/审核计划.md`

关联 ADR：

- `docs/decisions/001-use-strict-engineering-documentation.md`

关联提交：

- 未提交

## 1. 背景

LangoTrace 已经把 `docs/README.md` 作为 AI 会话、产品讨论、技术评审和原型迭代的统一入口。随着 SwiftUI App Shell、产品体验骨架、Core/UI/Data/AI/Speech/Sync 包边界、测试与验证脚本陆续落地，文档与代码之间已经出现过状态滞后：入口文档、项目初始化文档、模块边界文档和开发环境文档都需要在代码变化后重新对齐。

如果后续继续只依赖临时人工检查，文档会逐步失去“可信入口”的作用。AI 新会话会基于旧状态做判断，尤其容易在数据、AI Provider、同步、权限、StoreKit、测试和发布等高风险模块上引入错误假设。

`case_skillatlas_review/` 中的审查机制可作为参考，但 LangoTrace 当前仍处于早期 Apple App 开发阶段，不适合照搬大型、多轮、强子代理化的审计流程。本次草案目标是设计一套轻量但可升级的文档审查机制。

## 2. 目标

本次机制设计要达到以下结果：

- 明确文档审查的目的：准确性、完整性、可执行性和决策一致性。
- 明确不同类型文档的审查口径，避免把历史记录、研究材料和当前实现事实混为一谈。
- 明确事实断言、产品决策、架构决策、计划和用户澄清分别以什么为依据。
- 明确什么情况下必须触发文档审查。
- 明确文档问题、代码 bug、架构债、测试缺口、跨文档冲突和 ADR 冲突分别如何处理。
- 建立一个后续可落地的 `docs/review/` 目录方案。
- 保留从轻量专项审查升级到复杂多阶段审查的路径，包括中间产物、用户澄清、方案批准和断点续审。
- 将审查机制纳入现有 `docs/README.md`、`docs/_meta/documentation-system.md` 和 `docs/archive/worklogs/README.md` 的规则体系。
- 保持流程轻量，避免每次小改动都触发完整审计。

## 3. 范围

本次拟处理：

- 新增 `docs/review/README.md`，定义 LangoTrace 文档审查机制。
- 在 `docs/_meta/documentation-system.md` 中补充文档审查机制的目录职责、触发条件和提交前检查要求。
- 在 `docs/README.md` 中补充任务阅读路径或完成前检查说明，让后续 AI 会话知道何时读取 `docs/review/README.md`。
- 视需要在 `docs/archive/worklogs/README.md` 中补充“文档影响检查”要求，要求重要开发任务完成时记录文档是否需要更新。

## 4. 不做什么

本次不处理：

- 不修改 Swift 代码。
- 不改变现有产品、架构、数据、隐私、同步或付费决策。
- 不创建大型全量审查轮次。
- 不把 `case_skillatlas_review/` 纳入 LangoTrace 文档体系。
- 不要求每次轻量文档修正都走完整审查流程。
- 不立刻为所有文档增加 `verified_at` front matter。
- 不自动提交，除非用户单独要求。

## 5. 分析

### 5.1 必要性

LangoTrace 的文档不是普通说明文件，而是后续 AI 辅助开发的控制面。审查机制要维护的不是“文档好看”，而是三类一致性：

- 代码实现状态一致性：已实现、未实现、Mock、Disabled、候选方案必须与代码一致。
- 决策一致性：`docs/README.md`、产品主参考、技术路线、ADR、guidelines 之间不能互相冲突。
- 执行入口一致性：后续 AI 或人类开发者按文档走，能知道该读什么、改什么、验证什么。

文档过期会直接造成错误实现路径，例如：

- 已实现的 Swift 类型、协议或 View 未写入文档，后续重复设计。
- 未实现的数据、AI、同步或 StoreKit 能力被文档写成已完成，后续基于错误前提开发。
- `scripts/verify.sh` 变化后文档未同步，导致验证口径分裂。
- ADR 和实际实现发生冲突，但没有触发复审。

因此需要固定机制，让“代码变化后检查文档影响”成为开发流程的一部分。

### 5.2 文档分级

不同文档承担不同责任，不能用同一把尺子审查。

| 类型 | 代表文档 | 审查重点 |
| --- | --- | --- |
| 当前事实源 | `docs/README.md`、`docs/development/environment.md`、`docs/development/project-initialization.md`、`docs/architecture/` | 必须与当前代码、脚本和工程结构匹配 |
| 决策源 | `docs/decisions/`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md` | 必须与核心产品、架构、隐私、付费和同步决策一致 |
| 执行规则源 | `docs/spec/`、`docs/testing/`、`docs/release/` | 必须能指导后续实现和验证，允许包含尚未完全实现的规则 |
| 过程记录 | `docs/plans/done/`、`docs/research/`、`docs/superpowers/` | 保留历史过程，不要求持续改写为最新事实 |
| 审查记录 | `docs/review/rounds/` | 记录某次审查的代码快照、范围、结论和剩余风险 |

过程记录和审查记录不能被当作“当前实现事实”去反复修正。若其中内容与当前代码不同，应在新的事实源或审查记录中说明演进结果，而不是改写历史过程。

### 5.3 断言依据

“代码是唯一真相源”只适用于当前实现事实，不适用于所有产品和架构判断。LangoTrace 审查时按以下依据判断：

| 断言类型 | 最高依据 | 处理规则 |
| --- | --- | --- |
| 当前实现事实 | 当前代码、`project.yml`、脚本、测试 | 文档必须向实际实现对齐 |
| 产品核心决策 | 产品主参考文档、ADR、用户明确确认 | 代码若冲突，不能直接改文档迁就代码，应触发复审 |
| 架构和隐私决策 | ADR、技术路线、guidelines | 代码若偏离，需要记录为架构债、bug 或 ADR 复审 |
| 未来计划 | roadmap、worklog、规格或计划文档 | 必须明确写成计划、候选、后续，不得伪装成已实现 |
| 历史过程 | worklog、research、review round | 保留当时上下文，不强制改写为最新事实 |
| 无法从代码判断的设计意图 | 用户澄清或新增决策记录 | 先记录问题，不凭空补入长期文档 |

这个边界非常重要：审查不是为了让所有文档都服从当前代码，而是为了让不同来源的权威关系清晰。

### 5.4 可借鉴内容

`case_skillatlas_review/` 的以下原则适合 LangoTrace：

- 对当前实现事实，代码是最高依据。
- 审查同时关注准确性和完整性。
- 审查产物应落盘，避免只存在聊天记录中。
- 发现代码问题时应记录，不应在文档审查中顺手改代码。
- 用户澄清和批准应作为审查流程的一部分。
- 任何需要用户确认的内容都应先成为可审阅文件，再成为聊天消息。
- 长审查需要断点续审能力，不能依赖单次会话上下文。
- 跨文档一致性应作为单独检查阶段，而不是分散在单文档修改中。
- 最终验收应看“新会话是否可用”，不是只看 checklist 是否勾完。

### 5.5 不宜照搬内容

以下内容对 LangoTrace 当前阶段过重：

- 每份目标文档都强制使用子代理。
- 每轮都执行 Pass 1、问题汇总、用户逐条答复、proposal、Pass 2 的完整流程。
- 每份文档强制维护 `verified_at`。
- 固定季度或月度周期审查。

LangoTrace 更适合以里程碑和事件触发为主，等文档和代码规模增长后再升级为更完整的轮次机制。

## 6. 方案

建议采用“分级文档 + 分层流程 + 问题分流”的文档一致性治理机制。

### 6.1 文档审查目录

新增目录：

```text
docs/review/
  README.md
  INDEX.md
  rounds/
```

`docs/review/README.md` 负责定义机制本身，包括：

- 审查目标。
- 文档分级。
- 断言依据。
- 触发矩阵。
- 三层流程。
- 问题分流。
- 审查产物模板。
- 验证边界。

`docs/review/INDEX.md` 作为审查轮次总索引，只记录长期状态，不存放单轮细节。单轮细节放在 `docs/review/rounds/` 下。

`docs/review/rounds/` 只保存专项审查和里程碑全审记录，不保存日常任务的轻量文档影响检查。

### 6.2 日常文档影响检查

适用场景：

- 新功能。
- bug 修复。
- 架构调整。
- 数据、AI、隐私、同步、权限、StoreKit 相关任务。
- 影响用户路径或多端体验的任务。

要求：

- 在对应 worklog 的验证或实施记录中增加“文档影响检查”。
- 明确列出本次代码变化是否影响 `docs/README.md`、主参考文档、架构文档、guidelines、testing 或 release 文档。
- 若不更新文档，应写清理由。
- 不创建 `docs/review/rounds/`，除非本次变更命中专项审查触发条件。

### 6.3 事件触发专项审查

适用场景：

- 完成首次启动与语言空间闭环。
- 引入 SQLite/GRDB schema、Repository 或迁移。
- 接入真实 AI Provider、Keychain、请求预览或请求日志。
- 接入 TTS、录音、Speech、OCR、Photos 权限。
- 接入 Sync Engine、Adapter 或冲突解决。
- 接入 StoreKit、恢复购买或 App Store 隐私标签。
- 修改 `scripts/verify.sh`、XcodeGen、包边界或 App 启动结构。
- AI 会话发现文档与代码不一致。

落点：

```text
docs/review/rounds/YYYY-MM-DD-<topic>/
  README.md
```

每轮专项审查至少记录：

- 审查类型：专项审查。
- 审查触发原因。
- 审查代码快照，至少包含 `git rev-parse HEAD`。
- 审查文档范围。
- 相关源码、脚本或配置路径。
- 发现的问题。
- 已更新文档。
- 延后问题和原因。
- 用户澄清。
- 验证命令与结果。
- 剩余风险。

### 6.4 里程碑轻量全审

适用场景：

- MVP 阶段结束。
- 数据层、AI 层、同步层、付费发布层等关键阶段结束。
- 准备 TestFlight 或公开发布前。

要求：

- 逐项检查入口文档、主参考文档、架构文档、guidelines、testing、release 是否仍然匹配实际实现。
- 抽样追踪几个关键能力从代码到文档的闭环，例如语言空间、记录创建、AI 请求、同步或 StoreKit。
- 记录剩余风险，而不是追求一次性覆盖所有细节。

落点同专项审查，但审查类型记为：里程碑全审。

### 6.5 触发矩阵

| 触发级别 | 条件 | 要求 |
| --- | --- | --- |
| 强制触发专项审查 | 数据库 schema、Repository、迁移、AI Provider、Keychain、隐私请求预览、权限、同步、StoreKit、发布验证、ADR 冲突 | 建立 `docs/review/rounds/` 记录，并更新相关文档 |
| 默认触发专项审查 | 首次启动闭环、语言空间闭环、本地记录闭环、多端导航结构、验证脚本、XcodeGen、包边界、App 启动结构变化 | 默认建立审查记录；若跳过，必须在 worklog 说明原因 |
| 日常影响检查 | 一般功能、bug、重构、UI 体验调整、测试补充 | 在 worklog 中记录文档影响 |
| 可跳过 | 错别字、非行为性轻量文案、纯研究材料整理、用户明确要求跳过 | 最终答复说明跳过原因 |

### 6.6 问题处理矩阵

| 问题类型 | 示例 | 处理方式 |
| --- | --- | --- |
| 文档准确性问题 | 文档说功能已实现，但代码仍是 disabled provider | 修改文档，使其匹配代码 |
| 文档完整性问题 | 代码已有关键状态流转，但文档没有说明 | 补全文档 |
| 跨文档一致性问题 | README 与架构文档对同一模块状态描述不同 | 统一主入口和相关文档 |
| ADR 冲突 | 代码实现改变核心决策 | 新增或更新 ADR，不能只改普通文档 |
| 明显代码 bug | 审查时发现状态流转错误、数据丢失风险或崩溃路径 | 新建 `bug` worklog，不在审查中顺手修代码 |
| 架构债 | 代码能运行但边界与长期架构不匹配 | 新建 `refactor` 或 `chore` worklog，必要时关联 ADR |
| 测试缺口 | 文档要求某能力有验证，但测试或手动流程缺失 | 更新 `docs/testing/` 或创建测试补充任务 |
| 未确认设计意图 | 代码看不出为什么这样设计 | 记录为用户澄清项，不凭空写入长期文档 |

### 6.7 早期重写原则衔接

LangoTrace 仍处于早期开发阶段，审查机制不能把早期临时代码固化成长期负担。

- 审查不是为了保护已有实现。
- 如果发现早期实现与产品正确性、长期架构清晰度、三端体验质量或测试可维护性冲突，可以提出推翻重做。
- 审查过程中只记录问题和建议，不直接重写代码。
- 推翻代码路径应进入新的 `refactor`、`chore` 或架构 worklog；若影响核心决策，应新增或更新 ADR。

### 6.8 审查产物模板

普通专项审查只需要一个 `README.md`。复杂审查需要增加 `_meta.md`、问题、澄清、方案和一致性产物。

`docs/review/rounds/YYYY-MM-DD-<topic>/README.md` 至少包含：

```text
# 文档审查：标题

审查类型：专项审查 / 里程碑全审
日期：YYYY-MM-DD
代码快照：<git commit hash>
状态：Draft / In Progress / Verified

## 1. 触发原因
## 2. 审查范围
## 3. 相关源码、脚本和配置
## 4. 结论摘要
## 5. 问题清单
## 6. 文档修改记录
## 7. 用户澄清
## 8. 延后项和原因
## 9. 验证命令与结果
## 10. 剩余风险
```

日常影响检查通常写在 worklog 中，不单独创建该模板。

### 6.9 复杂审查升级路径

当审查范围较大、涉及多份核心文档、需要用户多轮澄清，或预计单次会话无法完成时，将普通 round 升级为复杂 round。

复杂 round 目录建议：

```text
docs/review/rounds/YYYY-MM-DD-<topic>/
  README.md
  _meta.md
  reports/
  questions/
  clarifications/
  proposals/
  consistency_check.md
```

各目录职责：

| 路径 | 用途 |
| --- | --- |
| `_meta.md` | 记录代码快照、审查状态表、方案批准记录、异常区和副产物索引 |
| `reports/` | 保存只读深审报告，记录准确性问题、完整性缺口、代码问题观察和证据 |
| `questions/` | 保存需要用户澄清的问题；必要时生成 `_merged.questions.md` 做跨文档去重 |
| `clarifications/` | 保存用户答复，避免重要澄清只留在聊天里 |
| `proposals/` | 保存推荐修改方案；用户批准后才能进入文档重写 |
| `consistency_check.md` | 保存跨文档术语、路径、状态、决策和验证口径的一致性检查 |

升级原则：

- 能在一个 worklog 内说清楚的日常影响检查，不升级。
- 单一主题、少量文档的专项审查，使用普通 round。
- 多文档、多阶段、需要用户逐条确认的审查，使用复杂 round。
- 复杂 round 不强制使用子代理；如果未来使用子代理，必须限制每个子代理的读写范围。

### 6.10 用户确认先落盘

参考机制中“任何需要用户确认的内容都必须先成为文件，再成为消息”适合 LangoTrace 的长期维护。

LangoTrace 采用以下弱化版本：

- 日常任务：用户确认记录写入 worklog。
- 专项审查：用户澄清和批准写入 round 的 `README.md`。
- 复杂审查：用户问题写入 `questions/`，答复写入 `clarifications/`，方案批准写入 `_meta.md`。

这样做的目的不是增加仪式，而是避免关键产品、架构或隐私判断只存在于聊天上下文中。

### 6.11 断点续审

复杂审查必须支持从新会话恢复。恢复依据不应是主会话记忆，而应是磁盘产物：

- `_meta.md` 中的状态表。
- `reports/`、`questions/`、`clarifications/`、`proposals/` 的文件存在性。
- `consistency_check.md` 的完成状态。
- `README.md` 中的剩余风险和延后项。

每个复杂 round 至少使用以下状态：

```text
Draft -> In Progress -> Waiting for Clarification -> Waiting for Approval -> Updating Docs -> Consistency Check -> Verified / Deferred
```

### 6.12 审查检查维度

不同审查可按风险选择检查深度，但维度应稳定：

| 维度 | 检查点 | 默认优先级 |
| --- | --- | --- |
| 准确性 | 文件路径、类型名、函数名、脚本命令、配置项是否真实存在 | P0 |
| 准确性 | 已实现、未实现、Mock、Disabled、候选方案是否写清 | P0 |
| 完整性 | 关键用户路径、数据路径、权限路径、错误路径是否覆盖 | P0 |
| 决策一致性 | 是否与 ADR、产品主参考、技术路线冲突 | P0 |
| 跨文档一致性 | 术语、模块名、状态描述、验证命令是否统一 | P1 |
| 可执行性 | 新会话能否按文档找到入口、实施边界和验证方式 | P1 |
| 时效性 | 审查记录是否有代码快照、日期和剩余风险 | P2 |

### 6.13 写入权限边界

为避免审查范围失控，写入权限应提前声明：

| 文件或目录 | 谁可以写 | 何时写 |
| --- | --- | --- |
| `docs/plans/done/` | 当前任务执行者 | 日常文档影响检查或新问题分流 |
| `docs/review/INDEX.md` | 主会话或人工维护者 | 创建或完成审查轮次时 |
| `docs/review/rounds/<round>/README.md` | 主会话或人工维护者 | 专项审查和里程碑全审 |
| `docs/review/rounds/<round>/_meta.md` | 主会话或人工维护者 | 复杂审查状态维护 |
| `docs/review/rounds/<round>/reports/` | 审查执行者 | 只读深审阶段 |
| `docs/review/rounds/<round>/questions/` | 审查执行者 | 需要用户澄清时 |
| `docs/review/rounds/<round>/clarifications/` | 用户或主会话按用户答复整理 | 用户确认后 |
| `docs/review/rounds/<round>/proposals/` | 审查执行者 | 重写前方案评估 |
| 目标长期文档 | 主会话或被明确授权的执行者 | 用户确认方案后 |
| Swift 代码和工程文件 | 不在文档审查中修改 | 另开 feature、bug 或 refactor 任务 |

### 6.14 终极验收

文档审查的最终验收不是文件都写完，而是“新会话可用”。

建议的验收方式：

- 对日常影响检查：后续执行者能从 worklog 看出本次是否影响文档，影响了哪些文档。
- 对专项审查：新会话读取入口文档和相关目标文档后，能说清当前实现状态、下一步边界和验证方式。
- 对里程碑全审：随机抽取一个核心能力，例如语言空间、记录创建、AI 请求、同步或 StoreKit，新会话能仅凭文档找到代码入口和验证路径。

该验收不要求每次都实际另开会话执行，但在发布前、里程碑结束和高风险模块落地后应抽样执行。

## 7. 风险与边界

主要风险：

- 审查机制过重，拖慢早期开发节奏。
- 审查机制过轻，只变成形式化 checklist。
- 文档审查中发现代码问题后顺手修改代码，导致范围失控。
- 把历史记录、研究材料和当前实现真相混为一谈。
- 过度相信当前代码，把尚未实现但仍然有效的产品或架构决策删掉。
- 只更新 `docs/README.md`，不更新真正承载细节的架构、guideline、testing 或 release 文档。
- 机械检查通过后误以为语义一致性已经得到证明。
- 长轮次审查只依赖聊天上下文，导致中断后无法恢复。
- 用户澄清没有落盘，后续无法追溯为什么这样写。

边界控制：

- 默认采用日常影响检查，专项审查只在触发条件出现时启动。
- 审查代码时只读代码；若需要修代码，另开 bug、refactor 或 chore worklog。
- 审查结论必须落盘到 `docs/review/` 或对应 worklog。
- 高风险核心决策变化必须走 ADR。
- 过程记录不追求改写为最新事实，当前事实应沉淀到事实源文档或新的审查记录。
- 机械检查只能作为底线，不能替代代码与文档的语义对照。
- 大范围审查必须有 round 目录和代码快照；复杂审查必须有 `_meta.md` 或等价状态记录。

## 8. 测试与验证

机制文档落地后至少做机械检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

还应做语义检查：

- 抽样检查 `docs/README.md` 的项目当前状态是否与代码、包目录、`project.yml` 和 `scripts/verify.sh` 一致。
- 抽样检查 `docs/architecture/` 中的模块边界是否与实际 package 和 public types 一致。
- 检查新增 `docs/review/README.md` 是否明确区分文档分级、断言依据、触发矩阵和问题分流。
- 检查新增 `docs/review/README.md` 是否说明普通 round 与复杂 round 的升级条件。
- 检查新增 `docs/review/INDEX.md` 是否只做长期索引，不承载单轮细节。
- 检查 `docs/archive/worklogs/README.md` 是否能指导后续任务记录文档影响。

本次仅涉及文档机制，不运行完整 Swift 工程验证；若同时修改代码或验证脚本，应运行：

```bash
scripts/verify.sh
```

## 9. 用户确认记录

状态为 `Draft` 时不能开始实现。

用户确认记录：

```text
2026-05-17：用户确认“立即根据草案，完成审查机制的搭建”，可以开始实现。
```

已确认范围：

- 是否同意新增 `docs/review/README.md`。
- 是否同意采用“三层机制”：日常文档影响检查、事件触发专项审查、里程碑轻量全审。
- 是否同意采用文档分级：当前事实源、决策源、执行规则源、过程记录、审查记录。
- 是否同意采用“断言依据”边界：当前实现事实看代码，核心决策看 ADR 和主参考文档，未来计划看 roadmap 和 worklog。
- 是否同意新增 `docs/review/INDEX.md` 作为审查轮次总索引。
- 是否同意复杂审查采用 `_meta.md`、`questions/`、`clarifications/`、`proposals/` 和 `consistency_check.md` 作为可升级产物。
- 是否同意暂不为所有文档增加 `verified_at` front matter。
- 是否同意将代码疑似问题分流为 bug、refactor、chore、testing 或 ADR 复审，而不是在审查中直接修改代码。

## 10. 实施记录

2026-05-17：根据系统架构视角复审，补充分级、断言依据、触发矩阵、问题分流、早期重写原则、审查产物模板和验证边界。

2026-05-17：再次对照 `case_skillatlas_review/`，吸收可升级审查设计，包括 `INDEX.md` 总索引、复杂 round 目录、用户确认先落盘、断点续审、检查维度、写入权限边界和新会话可用验收。

2026-05-17：新增 `docs/review/README.md`，定义文档审查目标、文档分级、断言依据、三层流程、审查产物、问题分流、写入权限、检查维度、断点续审和验收方式。

2026-05-17：新增 `docs/review/INDEX.md`，作为审查轮次长期索引；新增 `docs/review/rounds/README.md`，说明普通轮次和复杂轮次目录结构。

2026-05-17：更新 `docs/README.md`，加入文档审查任务阅读路径、文档更新落点、目录职责和完成前检查要求。

2026-05-17：更新 `docs/_meta/documentation-system.md`，加入 `docs/review/` 分层职责、必须检查文档影响的情况、断言依据规则和收尾前文档影响检查。

2026-05-17：更新 `docs/archive/worklogs/README.md` 和 `docs/archive/worklogs/TEMPLATE.md`，把“文档影响检查”纳入重要任务收尾流程。

2026-05-17：对照本方案进行严格文档复查，修正 `docs/README.md` 目录树遗漏 `docs/review/README.md` 的问题，并统一 round 模板类型，避免把“日常影响检查”误写成 `docs/review/rounds/` 审查类型。

## 11. 文档影响检查

- 已影响 `docs/README.md`：新增文档审查任务阅读路径、目录结构、目录职责、完成前检查说明。
- 已影响 `docs/_meta/documentation-system.md`：新增文档审查分层、触发条件、断言依据和收尾规则。
- 已影响 `docs/archive/worklogs/README.md`：新增文档影响检查要求。
- 已影响 `docs/archive/worklogs/TEMPLATE.md`：新增“文档影响检查”章节。
- 已新增 `docs/review/README.md`、`docs/review/INDEX.md`、`docs/review/rounds/README.md`。
- 本次任务本身是文档审查机制搭建，不额外创建审查 round；审查机制从本次落地后开始适用。
- 本次机制复查发现并修正入口目录树和方案模板中的文档口径问题；不涉及代码、产品决策或 ADR 调整。

## 12. 验证结果

2026-05-17 已执行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort` 已列出新增 `docs/review/README.md`、`docs/review/INDEX.md` 和 `docs/review/rounds/README.md`。
- 占位符扫描无命中。
- `git diff --check` 无输出。
- `git status --short` 显示本次文档机制相关修改，以及未跟踪的 `case_skillatlas_review/` 参考目录。

语义抽样已检查：

```bash
rg -n "文档审查|docs/review|review/README|review/INDEX|文档影响检查|专项审查|里程碑轻量全审" docs/README.md docs/_meta/documentation-system.md docs/archive/worklogs/README.md docs/archive/worklogs/TEMPLATE.md docs/review/README.md docs/review/INDEX.md docs/review/rounds/README.md docs/plans/done/2026-05-17-chore-docs-review-mechanism.md
rg -n "四类文档分级|verified_at|季度|月度|case_skillatlas_review" docs/README.md docs/_meta/documentation-system.md docs/archive/worklogs/README.md docs/archive/worklogs/TEMPLATE.md docs/review docs/plans/done/2026-05-17-chore-docs-review-mechanism.md
```

结果：

- 文档审查相关入口在 `docs/README.md`、`docs/_meta/documentation-system.md`、`docs/archive/worklogs/README.md`、`docs/archive/worklogs/TEMPLATE.md` 和 `docs/review/` 中均有对应落点。
- 未发现“文档分级”仍被错误写作“四类文档分级”。
- `case_skillatlas_review/` 只出现在本 worklog 的参考来源和排除说明中，没有被纳入 `docs/review/` 机制正文。

2026-05-17 复查补充执行：

```bash
rg -n "审查类型：|docs/review/README.md|review/" docs/README.md docs/_meta/documentation-system.md docs/archive/worklogs/README.md docs/archive/worklogs/TEMPLATE.md docs/review docs/plans/done/2026-05-17-chore-docs-review-mechanism.md
```

结果：

- `docs/README.md` 的目录树已显式列出 `docs/review/README.md`。
- `docs/review/rounds/` 的审查类型口径已统一为专项审查和里程碑全审；日常文档影响检查仍写入 worklog。
