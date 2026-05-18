# 文档审查机制

本文档定义 LangoTrace 的文档一致性治理机制。它用于防止代码、产品决策、架构边界和文档入口在持续开发中逐步脱节。

文档审查不是为了让流程变重，而是为了保证后续 AI 会话和人类开发者能基于仓库内文档形成正确判断。

## 1. 审查目标

文档审查维护四类一致性：

- 准确性：当前实现事实必须与代码、工程配置、脚本和测试一致。
- 完整性：关键用户路径、数据路径、权限路径、错误路径和验证方式不能缺席。
- 可执行性：新会话读取入口和相关文档后，应能知道读什么、改什么、验证什么。
- 决策一致性：产品主参考、技术路线、ADR、spec 和实际实现不能互相冲突。

## 2. 文档分级

不同文档承担不同责任，审查时不能用同一口径处理。

| 类型 | 代表文档 | 审查重点 |
| --- | --- | --- |
| 当前事实源 | `docs/README.md`、`docs/development-environment.md`、`docs/project-initialization.md`、`docs/architecture/` | 必须与当前代码、脚本和工程结构匹配 |
| 决策源 | `docs/decisions/`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md` | 必须与核心产品、架构、隐私、付费和同步决策一致 |
| 执行规则源 | `docs/spec/`、`docs/testing/`、`docs/release/` | 必须能指导后续实现和验证，允许包含尚未完全实现的规则 |
| 过程记录 | `docs/worklogs/`、`docs/research/`、`docs/superpowers/` | 保留历史过程，不要求持续改写为最新事实 |
| 审查记录 | `docs/review/rounds/` | 记录某次审查的代码快照、范围、结论和剩余风险 |

过程记录和审查记录不能被当作当前实现事实反复改写。若历史记录与当前代码不同，应在新的事实源文档或新的审查记录中说明演进结果。

## 3. 断言依据

“代码是唯一真相源”只适用于当前实现事实，不适用于所有产品和架构判断。

| 断言类型 | 最高依据 | 处理规则 |
| --- | --- | --- |
| 当前实现事实 | 当前代码、`project.yml`、脚本、测试 | 文档必须向实际实现对齐 |
| 产品核心决策 | 产品主参考文档、ADR、用户明确确认 | 代码若冲突，不能直接改文档迁就代码，应触发复审 |
| 架构和隐私决策 | ADR、技术路线、spec | 代码若偏离，需要记录为架构债、bug 或 ADR 复审 |
| 未来计划 | roadmap、worklog、规格或计划文档 | 必须明确写成计划、候选、后续，不得伪装成已实现 |
| 历史过程 | worklog、research、review round | 保留当时上下文，不强制改写为最新事实 |
| 无法从代码判断的设计意图 | 用户澄清或新增决策记录 | 先记录问题，不凭空补入长期文档 |

审查不是为了让所有文档都服从当前代码，而是为了让不同来源的权威关系清晰。

## 4. 三层流程

### 4.1 日常文档影响检查

适用场景：

- 一般功能、bug 修复、重构、UI 体验调整和测试补充。
- 未命中专项审查触发条件的普通开发任务。

要求：

- 写在对应 worklog 的“文档影响检查”章节中。
- 明确本次变更是否影响 `docs/README.md`、主参考文档、架构文档、spec、testing 或 release 文档。
- 若不更新文档，应写清理由。
- 不创建 `docs/review/rounds/`，除非命中专项审查触发条件。

### 4.2 事件触发专项审查

以下情况强制触发专项审查：

- 数据库 schema、Repository、迁移。
- AI Provider、Keychain、请求预览、请求日志或隐私边界。
- 权限、Speech、OCR、Photos、TTS、录音。
- 同步引擎、Sync Adapter、冲突处理。
- StoreKit、发布验证、App Store 隐私标签。
- ADR 冲突或核心产品决策冲突。

以下情况默认触发专项审查；若跳过，必须在 worklog 中说明原因：

- 首次启动闭环。
- 语言空间闭环。
- 本地记录闭环。
- 多端导航结构。
- `scripts/verify.sh`、XcodeGen、包边界或 App 启动结构变化。
- AI 会话发现文档与代码不一致。

专项审查记录放在：

```text
docs/review/rounds/YYYY-MM-DD-<topic>/README.md
```

### 4.3 里程碑轻量全审

适用场景：

- MVP 阶段结束。
- 数据层、AI 层、同步层、付费发布层等关键阶段结束。
- 准备 TestFlight 或公开发布前。

要求：

- 检查入口文档、主参考文档、架构文档、spec、testing、release 是否仍然匹配实际实现。
- 抽样追踪关键能力从代码到文档的闭环。
- 记录剩余风险，不追求一次性覆盖所有细节。

## 5. 审查产物

### 5.1 普通 Round

普通专项审查只需要一个 `README.md`：

```text
docs/review/rounds/YYYY-MM-DD-<topic>/
  README.md
```

`README.md` 至少包含：

```text
# 文档审查：标题

审查类型：专项审查 / 里程碑全审
日期：YYYY-MM-DD
代码快照：<git commit hash>
状态：Draft / In Progress / Verified / Deferred

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

### 5.2 复杂 Round

当审查范围较大、涉及多份核心文档、需要用户多轮澄清，或预计单次会话无法完成时，升级为复杂 round。

复杂 round 目录：

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

| 路径 | 用途 |
| --- | --- |
| `_meta.md` | 记录代码快照、审查状态表、方案批准记录、异常区和副产物索引 |
| `reports/` | 保存只读深审报告，记录准确性问题、完整性缺口、代码问题观察和证据 |
| `questions/` | 保存需要用户澄清的问题；必要时生成 `_merged.questions.md` 做跨文档去重 |
| `clarifications/` | 保存用户答复，避免重要澄清只留在聊天里 |
| `proposals/` | 保存推荐修改方案；用户批准后才能进入文档重写 |
| `consistency_check.md` | 保存跨文档术语、路径、状态、决策和验证口径的一致性检查 |

复杂 round 不强制使用子代理；如果未来使用子代理，必须限制每个子代理的读写范围。

## 6. 问题处理

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

## 7. 写入权限

| 文件或目录 | 谁可以写 | 何时写 |
| --- | --- | --- |
| `docs/worklogs/` | 当前任务执行者 | 日常文档影响检查或新问题分流 |
| `docs/review/INDEX.md` | 主会话或人工维护者 | 创建或完成审查轮次时 |
| `docs/review/rounds/<round>/README.md` | 主会话或人工维护者 | 专项审查和里程碑全审 |
| `docs/review/rounds/<round>/_meta.md` | 主会话或人工维护者 | 复杂审查状态维护 |
| `docs/review/rounds/<round>/reports/` | 审查执行者 | 只读深审阶段 |
| `docs/review/rounds/<round>/questions/` | 审查执行者 | 需要用户澄清时 |
| `docs/review/rounds/<round>/clarifications/` | 用户或主会话按用户答复整理 | 用户确认后 |
| `docs/review/rounds/<round>/proposals/` | 审查执行者 | 重写前方案评估 |
| 目标长期文档 | 主会话或被明确授权的执行者 | 用户确认方案后 |
| Swift 代码和工程文件 | 不在文档审查中修改 | 另开 feature、bug 或 refactor 任务 |

## 8. 检查维度

| 维度 | 检查点 | 默认优先级 |
| --- | --- | --- |
| 准确性 | 文件路径、类型名、函数名、脚本命令、配置项是否真实存在 | P0 |
| 准确性 | 已实现、未实现、Mock、Disabled、候选方案是否写清 | P0 |
| 完整性 | 关键用户路径、数据路径、权限路径、错误路径是否覆盖 | P0 |
| 决策一致性 | 是否与 ADR、产品主参考、技术路线冲突 | P0 |
| 跨文档一致性 | 术语、模块名、状态描述、验证命令是否统一 | P1 |
| 可执行性 | 新会话能否按文档找到入口、实施边界和验证方式 | P1 |
| 时效性 | 审查记录是否有代码快照、日期和剩余风险 | P2 |

## 9. 断点续审

复杂审查必须支持从新会话恢复。恢复依据是磁盘产物，而不是主会话记忆：

- `_meta.md` 中的状态表。
- `reports/`、`questions/`、`clarifications/`、`proposals/` 的文件存在性。
- `consistency_check.md` 的完成状态。
- `README.md` 中的剩余风险和延后项。

复杂 round 至少使用以下状态：

```text
Draft -> In Progress -> Waiting for Clarification -> Waiting for Approval -> Updating Docs -> Consistency Check -> Verified / Deferred
```

## 10. 验收方式

文档审查的最终验收不是文件都写完，而是新会话可用。

- 对日常影响检查：后续执行者能从 worklog 看出本次是否影响文档，影响了哪些文档。
- 对专项审查：新会话读取入口文档和相关目标文档后，能说清当前实现状态、下一步边界和验证方式。
- 对里程碑全审：随机抽取一个核心能力，新会话能仅凭文档找到代码入口和验证路径。

该验收不要求每次都另开会话执行，但在发布前、里程碑结束和高风险模块落地后应抽样执行。

## 11. 常用检查

文档审查至少运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

如果同时修改代码或验证脚本，应运行：

```bash
scripts/verify.sh
```
