---
title: LangoTrace 方案自审核协议
summary: 定义 LangoTrace active plan 在进入功能开发、Bug 修复、重构或文档治理实现前的严格自审核门禁。
keywords: plan review | active plan | 自审核 | 方案门禁 | TDD | documentation governance
scope: docs/plans/active/
related_files: docs/README.md | docs/plans/README.md | docs/review/README.md | docs/architecture/notes/README.md
verified_at: 2026-06-01
---

# LangoTrace 方案自审核协议

状态：Accepted
创建日期：2026-06-01
最后更新日期：2026-06-01

本文档定义 LangoTrace 的 active plan 在进入实现前必须执行的严格自审核协议。它适用于 Codex、Claude Code 或其他 AI 编程工具维护本仓库时的方案质量门禁。

本协议只管理“实现前的方案审核”。代码或文档变更完成后的文档一致性检查，仍以 [文档审查机制](../review/README.md) 为准。

## 0. 权威边界

- 本协议是 `docs/plans/` 下的执行规则源，服务于 `docs/plans/active/*.md`。
- 本协议不替代产品主参考、ADR、architecture、spec、workflow、review round 或测试文档。
- 如果本协议与产品主参考、ADR、spec 或 review 机制冲突，以更高权威文档为准，并按 `docs/review/README.md` 的保守文档自进化机制汇报和修正。
- 审核结论必须写回目标 active plan；聊天记录不能作为唯一依据。
- 用户明确要求跳过完整自审核时，必须在 active plan 或最终回复中记录跳过原因、剩余风险和补救路径。

## 1. 适用范围

以下任务进入实现前必须执行本协议：

- 新功能。
- Bug 修复。
- 重构。
- 数据库、Repository、迁移、附件、导出、长期记忆或同步相关任务。
- AI Provider、TTS Provider、Prompt、OCR、Speech、权限、隐私、安全、StoreKit 或发布相关任务。
- 平台页面、导航结构、App 启动结构、包边界、XcodeGen、验证脚本或测试基础设施调整。
- 文档体系、规范、架构、workflow、review 机制和验证门禁调整。

以下任务可以例外：

- 低风险错别字。
- 单个失效链接修正。
- 用户明确要求跳过方案的小任务。

例外不代表没有责任。执行者仍应在最终答复中说明为什么跳过 active plan 或自审核，以及剩余风险。

## 2. 前置门禁

进行任何受本协议约束的实现前，必须先完成：

1. 在 `docs/plans/active/` 创建或更新目标方案。
2. 核对方案中的当前事实是否来自当前代码、脚本、测试、权威文档或用户确认。
3. 按本文档完成至少一轮严格自审核。
4. 将确认的问题、修订、TDD 落点、验证命令和剩余风险写回 active plan。
5. 将 active plan 的 `自审核状态` 从 `Not Reviewed` 更新为 `Reviewed`。
6. 等待用户确认，或在 active plan 的用户确认记录中已有明确授权。

状态为 `Draft` 的方案默认不能进入生产代码实现。若用户只授权“完善方案”或“修订文档”，实现范围仅限被授权的文档变更。

`自审核状态：Reviewed` 只表示方案审核门禁已完成，不表示用户已经批准实现。

## 3. 审核执行方式

优先使用隔离审查能力，例如子代理、独立会话或独立上下文，对方案进行只读审查。主会话负责：

- 提供入口文档、目标 active plan 和相关上下文文档。
- 汇总审查结果并核验证据。
- 将确认问题写回 active plan。
- 执行必要的文档验证。

如果当前工具环境没有可用的隔离审查能力，主会话必须按本文的审查维度执行自审核，并在 active plan 的“严格方案自审核记录”中说明未使用隔离审查的原因。

隔离审查不是授权绕过用户确认、修改核心决策或直接改生产代码。任何核心产品、隐私、数据、同步、AI Provider、权限、StoreKit、发布或 ADR 级变更，仍必须遵守入口文档和对应权威文档的确认链路。

## 4. 默认双轮审查

默认执行双轮审查。用户只要求“一次自审核”时，至少必须完成第一轮，并覆盖第二轮中与任务直接相关的测试、安全和落地性问题。高风险任务仍应执行完整双轮。

### 4.1 第一轮：系统架构师审查

重点检查：

- 方案是否符合 LangoTrace 的产品北极星和本地优先边界。
- 是否违反 ADR、spec、architecture、workflow 或现有任务方案的权威关系。
- 模块职责、依赖方向、平台边界、Provider / Repository / Service / View Model 分层是否清晰。
- 实施链路是否完整，是否存在缺少上游契约、下游消费、状态入口或验证入口的断点。
- 并发、性能、取消、重入、重复触发、缓存、IO、内存和 UI 响应边界是否考虑清楚。
- 异常、重试、回滚、超时、权限拒绝、依赖不可用、输入非法和用户可见错误是否有处理路径。
- 状态同步、source of truth、派生状态、跨页面传播、生命周期和 stale read 是否清楚。
- 数据一致性、schema、事务、幂等、唯一性、删除 / 恢复、敏感数据边界和 fixture 是否可实现。
- 是否存在更简单、更长期正确或更符合早期重构原则的设计。

### 4.2 第二轮：测试、安全和落地性审查

第二轮必须基于第一轮修订后的 active plan，不得只重复第一轮结论。

重点检查：

- TDD 红绿路径是否明确。
- 首个失败测试的 package、文件、测试名、预期失败原因是否具体。
- 聚焦验证命令和完整验证命令是否覆盖风险。
- 如果不新增单元测试，原因和剩余风险是否成立。
- 隐私、安全、Keychain、日志脱敏、诊断、外部请求、导出、删除、备份和恢复边界是否可验证。
- Prompt、Provider、API contract、结构化输出、migration 和 repository contract 是否有结构化验证方式。
- 文档影响检查是否判断了入口、spec、ADR、architecture、testing、release、workflow 和 review round。
- 实施步骤是否能被后续会话从磁盘恢复，不依赖聊天记忆。

## 5. 发现分级

审查输出必须按 P0 / P1 / P2 / P3 分级：

```text
P0：阻塞实现，必须修复后才能继续。
P1：高风险缺口，默认必须修复后才能继续。
P2：重要改进，可在本阶段修复或记录明确后续路径。
P3：非阻塞优化或表达改进。
```

每条发现必须包含：

- 问题。
- 证据。
- 影响。
- 建议修改。
- 是否阻塞实现。

若发现只是未来想法，不应塞进当前实施步骤。处理方式：

- 会影响当前实现边界的，写入 active plan 的“非目标”“后续方向”或“剩余风险”。
- 架构级跨任务提醒，写入 `docs/architecture/notes/`，并在当前 active plan 中说明为何不纳入本轮。
- 进入实施阶段前，未来想法必须重新提炼为 `docs/plans/active/` 下的方案并重新执行本协议。

## 6. 写回要求

目标 active plan 应包含或补充“严格方案自审核记录”，至少记录：

```text
审核日期：
审核方式：隔离审查 / 主会话自审核
审核轮次：第一轮 / 第二轮 / 单轮
未使用隔离审查的原因：
发现摘要：
写回修改：
仍需用户确认的问题：
是否允许进入实现：
```

所有确认的问题、修订和剩余风险都必须写回 active plan。不得只保留在聊天记录中。

如果审查后修改了方案中的范围、架构边界、TDD 落点、验证命令或文档影响检查，应同步更新相关章节，而不是只在审核记录中描述。

只有在确认问题已经修订并写回、剩余风险已经记录后，才可以将 `自审核状态` 标记为 `Reviewed`。如果自审核发现的问题尚未处理，状态保持 `Not Reviewed`。

## 7. 与提交记录的关系

本协议不强制每次 active plan 创建、审查或修订都形成单独 commit。是否提交由当前任务、用户要求和仓库协作方式决定。

如果用户要求提交，或任务本身进入需要 commit 的开发流程，应在 active plan 的实施记录中写明提交哈希、验证命令和结果。

不要为了回填提交号而 amend 已共享提交，除非用户明确要求。

## 8. 与文档审查机制的关系

本协议发生在实现前，目标是提升方案质量。

`docs/review/README.md` 发生在文档影响检查、专项审查或里程碑审查阶段，目标是防止代码、产品决策、架构边界和文档入口在持续开发中脱节。

两者的默认顺序：

1. 创建或更新 active plan。
2. 按本文执行方案自审核。
3. 用户确认。
4. 按 TDD 实施。
5. 运行聚焦验证和必要的完整验证。
6. 按 `docs/review/README.md` 做日常文档影响检查或专项审查判断。
7. 验证收口后将 active plan 移入 `docs/plans/done/`。

## 9. 子代理审查 Prompt

对子代理或独立审查会话可使用以下 prompt，并将 `<PLAN_PATH>` 替换为目标 active plan 路径：

```text
站在严格系统架构师的角度，基于 LangoTrace 的产品定位、入口文档、相关 ADR、spec、architecture、workflow、review 机制和当前代码，对 <PLAN_PATH> 进行实现前方案自审核。

请先读取 AGENTS.md / docs/README.md、目标 active plan、docs/plans/README.md、docs/plans/plan-review-protocol.md，以及该 plan 引用的权威文档和相关代码路径。不要只接受方案自述，必须用代码或权威文档核验证据。

第一轮重点检查产品定位、架构边界、模块依赖、实施链路、并发 / 性能、异常边界、状态同步和数据一致性。

第二轮重点检查 TDD 红绿路径、先失败测试、聚焦验证、完整验证、隐私安全、日志脱敏、外部请求、schema / contract、删除 / 导出 / 恢复、Prompt / Provider 输出契约和文档影响检查。

审查输出按 P0 / P1 / P2 / P3 分级。每条发现必须包含：问题、证据、影响、建议修改、是否阻塞实现。

如果发现更优设计，直接提出。若发现只是未来能力，不要塞进当前实施步骤；请说明应写入 active plan 的非目标 / 剩余风险，还是应写入 docs/architecture/notes/。

不要实施生产代码。确认的问题必须建议写回 active plan。
```
