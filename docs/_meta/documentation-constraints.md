---
title: LangoTrace 文档约束路由索引
summary: 轻量治理路由器，将开发约束按类型索引到原始权威文档；不是新的事实源、产品决策源或裁决源。
keywords: constraint routing | governance | 约束索引 | 治理路由
scope: docs/_meta/
related_files: docs/README.md | docs/_meta/directory-responsibilities.md | docs/plans/plan-review-protocol.md
verified_at: 2026-06-06
---

# LangoTrace 文档约束路由索引

状态：Accepted
创建日期：2026-06-06
最后更新日期：2026-06-06

## 1. 用途

本文档是 LangoTrace 开发约束的轻量路由索引（governance router）。它帮助 AI 和人类开发者快速定位"哪些规则必须遵守、规则从哪里来、如何验证"，并指向已有权威文档，而不是创造新的产品决策源、架构事实源或裁决源。

具体任务命中的约束、阻塞判断和例外说明，必须写回对应 `docs/plans/active/*.md` 的"约束映射与验证路径"章节；本文件只提供路由，不替代任务方案的决策记录。

## 2. 权威边界

**本文件是约束路由索引，不是产品决策源、架构事实源、执行裁决源或领域规范源。**

- 如果本文件与原始权威文档（README / spec / ADR / review 机制）冲突，以原始权威文档为准，并把冲突作为文档治理问题处理。
- `blocker` 只来自当前权威文档中的明确强制规则；来自 reference、done plan、历史 review、外部 HTML 或 AI 推断的内容不得设为 `blocker`。
- `domain_trigger` 类约束只写触发条件和权威文档路径，不复制领域规则正文（AI Provider 规范、Keychain 规则、SQLite schema、日志脱敏细节等）。
- 源文档变更后若无法立即确认索引仍有效，应将对应条目降级为 `needs-review`；不得继续以 `blocker` 使用。

## 3. 字段说明

| 字段 | 含义 |
|---|---|
| `id` | 约束唯一编号，格式 `DOC-CONST-NNN` |
| `kind` | 约束类型（见下方分类说明）|
| `status` | `active` / `superseded` / `invalidated` / `needs-review` |
| `source` | 原始权威文档路径；优先写到章节或标题 |
| `severity` | `blocker` / `warn` / `info`（见下方语义隔离声明）|
| `enforced_by` | 验证入口或执行者 |
| `verification_hint` | 可机械检查的验证方式 |
| `conflict_handling` | 本约束与其他约束冲突时的优先规则 |
| `superseded_by` | 若 `status: superseded`，指向替代约束 ID |

**severity 语义隔离声明**：本索引的 `severity` 字段（`blocker` / `warn` / `info`）描述违反该约束对实现流程的影响程度，与 `docs/review/README.md` 中 review round 发现的 P0–P3 严重度、以及 `docs/plans/plan-review-protocol.md` 中方案自审核发现的 P0–P3 严重度彼此独立，不可混用。三套语义的使用场景：

- 本索引 `severity`：实现前判断是否触发阻塞。
- review round P0–P3：实现后文档一致性审查的问题严重度。
- 方案自审核 P0–P3：实现前 active plan 审核发现的问题严重度。

**kind 分类说明**：

- `plan_gate`：哪些任务必须先创建 active plan 再实现。
- `approval_gate`：哪些变更必须用户确认或 ADR 复审。
- `test_gate`：TDD、聚焦测试和完整验证规则。
- `doc_impact`：哪些变更触发文档影响检查或专项审查。
- `authority_boundary`：reference、done plan、review round、ADR、spec 等文档权威关系。
- `domain_trigger`：AI、隐私、存储、同步、权限、StoreKit 等领域任务应回到哪些权威文档检查；每条 `domain_trigger` 的规则摘要不超过一句话，必须以"应回到 `<path>` 检查"结尾，不复制领域规则正文。

## 4. 约束摘要表

| ID | 名称 | Kind | Status | Severity | Source |
|---|---|---|---|---|---|
| DOC-CONST-001 | 实现前必须创建 active plan | plan_gate | active | blocker | docs/README.md §4.16 |
| DOC-CONST-002 | 实现前必须完成方案自审核 | plan_gate | active | blocker | docs/plans/plan-review-protocol.md §2 |
| DOC-CONST-003 | 实现前必须获得用户确认 | approval_gate | active | blocker | docs/plans/README.md §4 |
| DOC-CONST-004 | 核心决策变化必须新增或更新 ADR | approval_gate | active | blocker | docs/README.md §4 |
| DOC-CONST-005 | 行为可自动化验证时先写单元测试 | test_gate | active | blocker | docs/README.md §1.4 |
| DOC-CONST-006 | 高风险实现完成后必须做文档影响检查 | doc_impact | active | warn | docs/review/README.md |
| DOC-CONST-007 | _meta 目录新长期文件必须登记职责 | doc_impact | active | blocker | docs/_meta/directory-responsibilities.md §3 |
| DOC-CONST-008 | 架构级跨任务提醒写入 architecture/notes/ | doc_impact | active | info | docs/README.md §1.2 |
| DOC-CONST-009 | reference 项目不是产品决策源或事实源 | authority_boundary | active | warn | docs/reference/README.md |
| DOC-CONST-010 | done plan 历史方案不作为当前事实直接引用 | authority_boundary | active | warn | docs/plans/README.md §5 |
| DOC-CONST-011 | 敏感凭证任务应回到 AI Provider / 隐私 spec 检查 | domain_trigger | active | blocker | docs/README.md §4.9 |
| DOC-CONST-012 | 存储 / 迁移 / 导出任务应回到存储 spec 检查 | domain_trigger | active | warn | docs/README.md §4.11 |
| DOC-CONST-013 | AI / TTS / Prompt 等高风险动作应回到 workflows 检查 | domain_trigger | active | warn | docs/workflows/README.md |
| DOC-CONST-014 | 用户敏感内容发送 AI 任务应回到隐私 spec 检查 | domain_trigger | active | blocker | docs/README.md §4.10 |

## 5. 约束详情

### DOC-CONST-001：实现前必须创建 active plan

- 状态：active
- 来源：`docs/README.md` §4.16 / `docs/plans/README.md` §5
- 适用范围：全局，适用于新功能、bug 修复、架构调整、数据、AI、隐私、同步、权限、付费、发布或文档体系变化的任务
- 规则摘要：涉及上述类型的任务，实现前必须先在 `docs/plans/active/` 创建任务方案并经用户确认
- 执行或验证方式：人工确认 `docs/plans/active/` 中存在对应方案文件
- 验证提示：`find docs/plans/active -name "*.md" | sort`，确认存在目标方案
- 冲突处理：与其他约束冲突时，本约束优先；已有 active plan 且已获用户确认视为满足
- 替代关系：无

### DOC-CONST-002：实现前必须完成方案自审核

- 状态：active
- 来源：`docs/plans/plan-review-protocol.md` §2
- 适用范围：全局，适用于受 DOC-CONST-001 约束的所有任务
- 规则摘要：active plan 进入实现前，必须按 `docs/plans/plan-review-protocol.md` 完成严格自审核，并将发现写回方案，`自审核状态` 标记为 `Reviewed`
- 执行或验证方式：检查 active plan 头部 `自审核状态` 字段和"严格方案自审核记录"章节
- 验证提示：`rg -n '自审核状态：Reviewed' docs/plans/active/<target>.md`
- 冲突处理：自审核发现 P0 / P1 未修复时阻塞实现；`自审核状态：Not Reviewed` 时视同 P0
- 替代关系：无

### DOC-CONST-003：实现前必须获得用户确认

- 状态：active
- 来源：`docs/plans/README.md` §4
- 适用范围：全局，适用于 `状态：Draft` 的任务方案
- 规则摘要：状态为 `Draft` 的方案不能开始生产代码实现；用户确认后方案状态应推进到 `User Approved` 或在用户确认记录中写明授权范围
- 执行或验证方式：检查 active plan 头部 `状态` 字段和"用户确认记录"章节
- 验证提示：`rg -n '^状态：' docs/plans/active/<target>.md`，确认不是 `Draft`；或确认"用户确认记录"有明确授权
- 冲突处理：`自审核状态：Reviewed` 不代表用户已确认；两者独立检查
- 替代关系：无

### DOC-CONST-004：核心决策变化必须新增或更新 ADR

- 状态：active
- 来源：`docs/README.md` §4 / `docs/_meta/documentation-system.md`
- 适用范围：产品核心模型、技术路线、隐私边界、同步策略、StoreKit 策略、Apple 三端首发等核心决策
- 规则摘要：改变核心产品定位、技术选型、隐私边界、同步路线或付费策略，必须新增或更新 `docs/decisions/`
- 执行或验证方式：人工确认 `docs/decisions/` 中存在对应 ADR
- 验证提示：`ls docs/decisions/`，确认相关 ADR 已创建或更新
- 冲突处理：文档治理任务不改变核心决策，不触发本约束；如不确定是否需要 ADR，以保守判断为准
- 替代关系：无

### DOC-CONST-005：行为可自动化验证时先写单元测试

- 状态：active
- 来源：`docs/README.md` §1.4 / `docs/README.md` §1 第 9 条
- 适用范围：新功能、bug 修复、架构调整和行为变化；文档-only、纯视觉文案或无法自动化的手动验证项可例外
- 规则摘要：行为可自动化验证时，先在所属 Swift Package 的 `Tests` 目录创建或更新能失败的单元测试，再实施最小代码变更；测试应靠近被测模块
- 执行或验证方式：确认 `Packages/*/Tests/` 中存在对应新增或修改的测试文件；聚焦测试命令运行通过
- 验证提示：`swift test --package-path Packages/<target> --filter <TestName>` 先红后绿
- 冲突处理：如不新增单元测试，必须在任务方案的"TDD / 测试落点"章节说明原因和剩余风险
- 替代关系：无

### DOC-CONST-006：高风险实现完成后必须做文档影响检查

- 状态：active
- 来源：`docs/review/README.md` / `docs/README.md` §4.17
- 适用范围：数据库、AI Provider、权限、同步、StoreKit、发布验证、ADR 冲突、首次启动闭环、语言空间闭环、本地记录闭环、验证脚本、XcodeGen、包边界或 App 启动结构变化
- 规则摘要：高风险实现完成后，应按 `docs/review/README.md` 做日常文档影响检查或触发专项审查
- 执行或验证方式：检查 active plan 的"文档影响检查"章节是否有触发专项审查的判断；或确认实施记录中有日常检查记录
- 验证提示：`rg -n '文档影响检查' docs/plans/active/<target>.md`
- 冲突处理：文档治理任务可在方案中说明为何不触发专项审查；高风险实现类任务不可省略
- 替代关系：无

### DOC-CONST-007：_meta 目录新长期文件必须登记职责

- 状态：active
- 来源：`docs/_meta/directory-responsibilities.md` §3
- 适用范围：在 `docs/_meta/` 新增长期文件时
- 规则摘要：在 `docs/_meta/` 新增长期文件必须在 `docs/_meta/directory-responsibilities.md` 的目录职责表中登记该文件的职责、权威类型、写入规则和禁止事项
- 执行或验证方式：检查 `docs/_meta/directory-responsibilities.md` 的目录职责表是否包含新文件条目
- 验证提示：`rg -n 'documentation-constraints' docs/_meta/directory-responsibilities.md`
- 冲突处理：与其他约束冲突时，本约束优先；不得以"入口文档可发现"为由跳过登记
- 替代关系：无

### DOC-CONST-008：架构级跨任务提醒写入 architecture/notes/

- 状态：active
- 来源：`docs/README.md` §1.2 / `docs/README.md` §1 第 8 条
- 适用范围：当前任务不实现但会影响未来数据、同步、AI、权限、附件、导出、StoreKit、三端架构或长期记忆边界的能力
- 规则摘要：架构级跨任务提醒写入 `docs/architecture/notes/`；创建相关任务方案前应主动检查这些备忘录
- 执行或验证方式：确认 `docs/architecture/notes/` 中有对应备忘录；新任务方案引用相关备忘录
- 验证提示：`ls docs/architecture/notes/`，确认相关备忘录已创建
- 冲突处理：非架构级提醒可写在 active plan 的"剩余风险"章节，不强制写入 `architecture/notes/`
- 替代关系：无

### DOC-CONST-009：reference 项目不是产品决策源或事实源

- 状态：active
- 来源：`docs/reference/README.md`
- 适用范围：使用 `docs/reference/` 中外部参考项目、研究材料、竞品分析或外部 HTML 时
- 规则摘要：reference 项目只能提供灵感、结构和研究证据，不能替代语迹的产品决策、架构事实或实现事实；采纳参考结论后必须回写到主参考、spec、architecture 或 ADR
- 执行或验证方式：确认任务方案的"约束映射与验证路径"中明确区分了参考输入和当前权威
- 验证提示：检查方案中引用 reference 的条目是否有"证据能证明什么 / 照搬风险"声明
- 冲突处理：reference 结论不能被直接设为 blocker；必须先提升到当前权威文档
- 替代关系：无

### DOC-CONST-010：done plan 历史方案不作为当前事实直接引用

- 状态：active
- 来源：`docs/plans/README.md` §5
- 适用范围：引用 `docs/plans/done/` 中已完成任务方案时
- 规则摘要：`docs/plans/done/` 是历史记录，不作为新任务入口；历史方案中已实施的决策若仍有效，以当前代码、spec、ADR 或 architecture 为准
- 执行或验证方式：确认新任务方案的决策依据优先指向当前权威文档，而非 done plan 正文
- 验证提示：检查方案引用 done plan 时是否同时引用对应的当前权威文档
- 冲突处理：done plan 可作历史背景引用，但不能替代 spec、ADR 或 architecture 的当前事实判断
- 替代关系：无

### DOC-CONST-011：敏感凭证任务应回到 AI Provider / 隐私 spec 检查

- 状态：active
- 来源：`docs/README.md` §4.9
- 适用范围：涉及 API Key、Keychain、Provider 凭证、加密密钥等敏感配置的任务
- 规则摘要：涉及敏感凭证的任务，应回到 `docs/spec/005-ai-provider-prompt-and-privacy.md` 和 `docs/decisions/005-local-first-and-user-owned-providers.md` 检查
- 执行或验证方式：确认任务方案引用了上述文档，且实施步骤中 Keychain 路径明确
- 验证提示：`rg -n 'Keychain|keychain' docs/plans/active/<target>.md`；实施后 `rg -rn 'Keychain' Packages/` 确认落点
- 冲突处理：以原始权威文档为准；本条目仅做路由
- 替代关系：无

### DOC-CONST-012：存储 / 迁移 / 导出任务应回到存储 spec 检查

- 状态：active
- 来源：`docs/README.md` §4.11 / `docs/README.md` §5.4
- 适用范围：涉及 SQLite / GRDB schema、Repository、migration、附件、导出或备份的任务
- 规则摘要：涉及存储 / 迁移 / 导出的任务，应回到 `docs/spec/007-data-storage-migration-export-and-attachments.md` 检查
- 执行或验证方式：确认任务方案引用了上述文档，且 migration 路径、schema 契约和 Repository 边界已说明
- 验证提示：检查方案的"证据与决策依据"中是否引用 spec/007
- 冲突处理：以原始权威文档为准；本条目仅做路由
- 替代关系：无

### DOC-CONST-013：AI / TTS / Prompt 等高风险动作应回到 workflows 检查

- 状态：active
- 来源：`docs/workflows/README.md` / `docs/README.md` §1 第 12 条
- 适用范围：新增 AI Provider、TTS Provider、数据迁移、平台页面或 Prompt 等高风险动作时
- 规则摘要：涉及上述高风险动作的任务，应回到 `docs/workflows/` 中对应手册检查
- 执行或验证方式：确认任务方案引用了对应 workflow 手册，并说明采纳或偏离原因
- 验证提示：检查方案的"证据与决策依据"中是否引用 workflows 对应条目
- 冲突处理：workflow 只提供执行顺序和检查清单，不替代 spec、ADR 或任务方案确认链路；以原始权威文档为准
- 替代关系：无

### DOC-CONST-014：用户敏感内容发送 AI 任务应回到隐私 spec 检查

- 状态：active
- 来源：`docs/README.md` §4.10
- 适用范围：涉及将照片、日记、音频等用户敏感内容发送给 AI Provider 的任务
- 规则摘要：涉及用户敏感内容发送 AI Provider 的任务，应回到 `docs/spec/005-ai-provider-prompt-and-privacy.md` 和 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 检查
- 执行或验证方式：确认任务方案引用了上述文档，且实施中有"用户显式触发"边界说明
- 验证提示：检查方案是否声明了"用户显式触发"条件
- 冲突处理：以原始权威文档为准；本条目仅做路由
- 替代关系：无

## 6. 使用方式

1. 开始任务前，根据任务类型在本索引中匹配相关约束。
2. 在 `docs/plans/active/<task>.md` 的"约束映射与验证路径"章节记录命中的约束 ID、来源和验证方式。
3. 实施前确认所有 `blocker` 约束已满足或已在任务方案中说明例外原因。
4. 实施后在 active plan 的"实施记录"中记录约束验证结果。
5. 如发现约束与源文档冲突，以原始权威文档为准，并把冲突按 `docs/review/README.md` 处理。

## 7. 维护规则

- 约束编号一旦分配不重用；`invalidated` 条目保留编号和记录，不删除。
- 源文档变更后若无法立即确认索引仍有效，将对应条目状态降级为 `needs-review`；不得继续作为 `blocker` 使用。
- 新增约束必须有明确的 LangoTrace 权威文档来源（路径可写到章节或标题）；只来自外部参考或 AI 推断的内容不得进入索引。
- `blocker` 只来自当前权威文档中的明确强制规则；参考项目、done plan、历史 review 或外部 HTML 的内容不得直接设为 `blocker`。
- `domain_trigger` 类约束的规则摘要不超过一句话，必须以"应回到 `<path>` 检查"结尾，不复制领域规则正文。
- 本文件每次实质性变更应更新"最后更新日期"字段。
