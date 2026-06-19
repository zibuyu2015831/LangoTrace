# 任务方案：参考 OpenWriter dev_docs 完善 LangoTrace 文档执行层

状态：Verified
类型：docs
创建日期：2026-05-25
最后更新日期：2026-05-25

## 用户确认记录

- 2026-05-25：用户要求参考另一个项目的 `dev_docs` 目录，重点比较其设计与 LangoTrace `docs/` 的异同、完整性和可借鉴之处。
- 2026-05-25：已完成只读对照分析，推荐保留 LangoTrace 当前产品 / 架构 / 文档治理控制面，吸收 OpenWriter `dev_docs` 的工程执行层能力。
- 2026-05-25：用户确认“立即创建 active plan 文档”。本记录仅确认创建本方案；后续实施仍需在用户确认本方案范围后开始。
- 2026-05-25：用户继续要求参考 `/Users/zibuyu/code/openSource/vmark/dev-docs` 的 docs 目录搭建和开发原则，继续完善 LangoTrace docs。本次确认将 VMark 作为第二参考样本，吸收系统地图、故障恢复矩阵、审计协议和周期性清理原则，但不复制其分块审计目录或 house-cleaning 目录。

## 1. 需求或 bug 描述

LangoTrace 当前 `docs/` 已经具备产品北极星、技术路线、ADR、spec、plan、review、testing、release 和 reference 等长期控制面，但与 OpenWriter `dev_docs/` 对比后，工程执行层仍有明显可增强空间：

- 缺少独立的 `docs/workflows/`，典型开发动作只能通过入口文档的任务类型路由和各 spec 间接拼接。
- 高风险模块尚未统一形成 `spec.md` / `impl.md` / `decisions/` 结构，部分实现地图散落在顶层 spec 或子目录中。
- Prompt Registry 已有目录和规则，但真实 Prompt 落地后的完整记录字段、代码锚点、隐私分级和评测要求仍需要提前固化。
- 文档健康检查目前主要依赖 `find`、`rg`、`git diff --check` 和人工语义审查，缺少低成本、可持续的结构性脚本入口。
- 参考 VMark 后，LangoTrace 还缺少对高风险能力故障恢复矩阵、系统级入口 / 数据流地图和周期性文档健康检查的明确落点说明。
- `docs/_meta/documentation-constraints.md` 的约束路由索引方案正在另一个 active plan 中推进，本任务需要与其分工清楚，避免出现第二事实源或重复治理体系。

本任务目标是把 OpenWriter `dev_docs` 中适合 LangoTrace 的工程执行经验吸收到 LangoTrace 文档体系中，但不照搬其目录结构、bug 目录、ideas 目录或 `_meta` 只读策略。

## 2. 现状描述

LangoTrace 当前文档结构：

```text
docs/
  README.md
  _meta/
  architecture/
  decisions/
  development/
  plans/
  prompts/
  reference/
  release/
  review/
  spec/
  testing/
```

当前优势：

- `docs/README.md` 同时作为 AI 入口、产品状态入口和任务路由入口。
- `product-main-reference.md`、`technical-framework-roadmap.md`、`decisions/` 和 `spec/` 已经形成产品 / 架构 / 规则分层。
- `docs/review/README.md` 已明确当前事实源、决策源、执行规则源、过程记录和审查记录的权威关系。
- `docs/plans/README.md` 已要求一项需求、一个 bug 或一次文档治理只维护一份方案，避免 worklog 和 plan 分散。
- 当前正在通过 `docs/plans/active/2026-05-23-docs-doc-constraint-index.md` 规划轻量文档约束路由索引。

与 OpenWriter `dev_docs/` 对比后的缺口：

- OpenWriter 有 `dev_docs/workflows/`，覆盖新增 Agent、Provider、Screen、Storage、Tool、Privacy、Structured AI Result 等典型动作。
- OpenWriter 多数模块采用 `spec/<module>/spec.md` + `impl.md` + `decisions/`，对 AI 新会话更可执行。
- OpenWriter 的 Prompt Registry 记录代码锚点、完整 Prompt、输入输出契约和隐私边界，更利于后续审查。
- OpenWriter 有文档校验测试，检查路径、frontmatter、入口同步和实现地图漂移。

不适合直接复制的部分：

- OpenWriter 的 `bug/active` / `bug/fixed` 会与 LangoTrace 统一 `docs/plans/` 生命周期冲突。
- OpenWriter 的 `ideas/` 容易引入未接受灵感和当前事实源混用；LangoTrace 已有 `architecture/notes/` 和 `reference/research/`。
- OpenWriter 的 `_meta` 默认只读策略不适合 LangoTrace 当前早期文档体系演进阶段；LangoTrace 应继续采用“保守文档自进化 + 用户确认后修改”的模式。

## 3. 目标

本任务完成后必须达到：

- 新增 LangoTrace 专属 `docs/workflows/` 目录和入口说明，明确它是开发动作手册，不是产品决策源、架构事实源或实现事实源。
- 首批新增 3 到 5 个最高频、最高风险 workflow，优先覆盖 AI Provider、TTS Provider、存储 / migration、平台页面、Prompt。
- 明确模块级 `spec.md` / `impl.md` / `decisions/` 的采用规则，先作为后续高风险模块的推荐结构，不强制一次性重排全部现有 spec。
- 强化 `docs/prompts/README.md`，要求真实 Prompt 文档记录英文 canonical Prompt、中文审阅版本、输入变量、输出契约、隐私等级、调用代码路径和评测方式。
- 设计并可选落地轻量文档健康检查入口，优先检查低争议结构规则，不替代语义审查。
- 吸收 VMark `dev-docs` 的系统地图、故障恢复矩阵、审计严重度和周期性健康检查原则，并分流到 LangoTrace 现有 `architecture/`、`spec/`、`review/`、`plans/` 和 `scripts/check-docs.sh`。
- 与 `docs/_meta/documentation-constraints.md` 的约束路由索引保持边界清楚：workflow 负责“怎么做”，约束路由索引负责“去哪里确认强约束”。

## 4. 范围

本任务预计检查或修改：

- `docs/README.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/prompts/README.md`
- `docs/spec/README.md`
- 新增 `docs/workflows/README.md`
- 新增首批 `docs/workflows/*.md`
- 可选新增 `scripts/check-docs.sh`
- 可选更新 `scripts/verify.sh`，仅在 `check-docs.sh` 稳定且成本低时接入
- 可按需更新 `docs/architecture/README.md` 和 `docs/review/README.md`，用于吸收系统地图与周期性文档健康检查原则。

## 5. 不做什么

- 不把 LangoTrace `docs/` 改名为 `dev_docs/`。
- 不复制 OpenWriter 的 `dev_docs/bug/`，bug 仍归入 `docs/plans/active` / `docs/plans/done`。
- 不新增 `docs/ideas/`；未来灵感继续按性质进入 `docs/architecture/notes/`、`docs/reference/research/` 或正式 spec / ADR。
- 不把 workflow 写成新的规范事实源；workflow 必须引用原始权威文档。
- 不一次性重构全部现有 `docs/spec/*.md` 为模块目录。
- 不把 `docs/_meta/` 设为 AI 永久只读；仍按 LangoTrace 的保守文档自进化规则处理。
- 不删除历史 review、done plan、archive 或 reference 文档。
- 不改 Swift 代码，不改 XcodeGen，不改 package 结构。
- 不复制 VMark 的 `dev-docs/audit/` 分块审计目录、`dev-docs/house-cleaning/` 目录或面向 Tauri / React / MCP 的技术栈规则。

## 6. 证据与决策依据

### 6.1 LangoTrace 文档证据

- `AGENTS.md` / `docs/README.md`：定义 `docs/` 是唯一真实文档入口，要求任务按类型读取相关文档，重要判断写回文档。
- `docs/_meta/documentation-system.md`：定义文档分层、目录职责、spec / plan / review / prompt / release / testing 的落点。
- `docs/review/README.md`：定义当前事实源、决策源、执行规则源、过程记录和审查记录的权威关系。
- `docs/plans/README.md`：定义统一任务方案目录，要求文档治理任务优先追加已有 active plan 或新建 docs 类型 plan。
- `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`：规划轻量文档约束路由索引，应作为本任务的相邻治理任务，而不是被本任务覆盖。

### 6.2 OpenWriter dev_docs 参考证据

- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/ai-coding-context.md`：入口文档包含任务路由、spec 索引、实现地图索引、收尾自审清单和文档维护规则。
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/workflows/`：提供新增 Provider、Screen、Storage、Tool、Privacy 等动作手册。
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/spec/README.md`：模块级 `spec.md` / `impl.md` 覆盖面更完整。
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/prompts/README.md`：Prompt Registry 的完整度高于 LangoTrace 当前空壳规则。
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/_meta/docs-audit.md`：提供 quick / standard / strict 审核模式和权威冲突处理协议，可供 LangoTrace 审查机制吸收一部分模式选择字段。

### 6.3 对照结论

- OpenWriter `dev_docs/` 在工程执行层更全面。
- LangoTrace `docs/` 在产品愿景、Apple 三端、隐私 / 数据 / 同步 / StoreKit 和长期文档权威关系上更适合本项目。
- 最优路径是保留 LangoTrace 当前文档控制面，吸收 OpenWriter 的 workflow、模块级 spec / impl、Prompt Registry 和轻量机器校验经验。

### 6.4 VMark dev-docs 参考证据

- `/Users/zibuyu/code/openSource/vmark/dev-docs/README.md`：以 Active Docs、Agent Configuration、Website Docs、Documentation Conventions 和 Important History 组织入口，强调单一事实源、状态 / 日期和行为变更同步更新文档。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/architecture.md`：用系统形态、进程 / runtime、入口点、关键数据流、模块地图和依赖方向帮助新会话快速定位系统。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/audit/protocol.md`：审计输出区分 Critical / Warning / Info，并要求文件、问题和修复建议。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/error-recovery.md`：用矩阵列出故障模式、恢复路径和测试覆盖，适合被 LangoTrace 高风险模块 spec / impl 吸收。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/README.md` 与 `cadence.md`：把日常检查、周度、月度、季度治理分层，强调趋势、verdict、预算和自改进 gate；LangoTrace 只吸收分层原则，不新增同名目录。

### 6.5 VMark 对照结论

- VMark 的 `dev-docs` 更像“工程运行手册 + 系统地图 + 审计框架”，适合补强 LangoTrace 的架构入口、故障恢复矩阵和文档健康节奏。
- LangoTrace 已有更强的产品北极星、隐私边界、ADR / spec / plan / review 权威分层，不应引入 VMark 的独立 audit / house-cleaning 目录来分裂控制面。
- 最优吸收路径是：`architecture/` 增强系统地图要求，`spec/` 增强故障恢复矩阵要求，`review/` 增强周期性健康检查分层，`scripts/check-docs.sh` 承担低争议结构 gate，`workflows/` 承担动作手册。

## 7. 涉及的代码文件路径

文档-only 任务，默认无 Swift 代码修改。

可选脚本修改：

- `scripts/check-docs.sh`：若决定落地轻量文档健康检查，则新增。
- `scripts/verify.sh`：仅在 `check-docs.sh` 足够稳定且低成本时接入。

## 8. 参考的代码文件路径

无。若实施阶段决定新增 `scripts/check-docs.sh`，可参考：

- `scripts/verify.sh`
- OpenWriter 文档测试思路，但不复制其 TypeScript 测试实现。
- VMark `dev-docs/audit/protocol.md`、`dev-docs/error-recovery.md`、`dev-docs/house-cleaning/README.md` 和 `dev-docs/architecture.md`，但不复制其目录结构或技术栈规则。

## 9. 涉及的文档路径

预计修改：

- `docs/README.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/prompts/README.md`
- `docs/spec/README.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/architecture/README.md`
- `docs/review/README.md`
- `docs/workflows/README.md`
- `docs/workflows/add-ai-provider.md`
- `docs/workflows/add-tts-provider.md`
- `docs/workflows/add-storage-migration.md`
- `docs/workflows/add-platform-screen.md`
- `docs/workflows/add-prompt.md`

只读参考：

- `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`
- `docs/review/README.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/spec/011-tts-provider-configuration-and-playback.md`
- `docs/architecture/notes/README.md`
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/ai-coding-context.md`
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/workflows/*.md`
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/spec/README.md`
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/prompts/README.md`
- `/Users/zibuyu/code/zibuyu/open-writer/dev_docs/_meta/docs-audit.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/README.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/architecture.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/audit/protocol.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/error-recovery.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/README.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/cadence.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 固化目录职责和入口路由

新增 `docs/workflows/README.md`，定义：

- `docs/workflows/` 是开发动作手册目录。
- workflow 只能引用 authoritative docs，不复制长期规则正文。
- workflow 不能覆盖 spec、ADR、architecture、review、plan 或 prompt registry 的职责。
- 每个 workflow 必须包含：
  - 适用场景
  - 必读文档
  - 预计触发的 active plan 要求
  - 关键代码 / 文档落点
  - 必做测试
  - 完成前检查
  - 反例

同步更新：

- `docs/README.md` 第 5 节任务类型路由中加入 workflow 入口。
- `docs/_meta/documentation-system.md` 和 `docs/_meta/directory-responsibilities.md` 中加入 `workflows/` 职责。

### 11.2 新增首批 workflow

首批只覆盖高频、高风险、已在 LangoTrace 中反复出现的开发动作：

1. `docs/workflows/add-ai-provider.md`
   - 读取 `docs/spec/005-ai-provider-prompt-and-privacy.md`
   - 强制确认 Keychain / 非敏感配置分离、用户显式触发、请求预览 / 请求日志边界
   - 指向 AI package、Data repository、UI settings、probe tests 和 Prompt Registry

2. `docs/workflows/add-tts-provider.md`
   - 读取 `docs/spec/011-tts-provider-configuration-and-playback.md`
   - 强制确认 sample preview、persistent artifact、format validation、cancel / retry / cache invalidation
   - 指向 Speech package、Data artifact repository、UI settings 和 sentence playback seam

3. `docs/workflows/add-storage-migration.md`
   - 读取 `docs/spec/007-data-storage-migration-export-and-attachments.md`
   - 强制确认 migration id、transaction、repository contract、rollback / recovery、test fixture 和 export / backup 影响

4. `docs/workflows/add-platform-screen.md`
   - 读取 navigation、UI design system、SwiftUI architecture、Apple interaction / accessibility spec
   - 强制确认 iPhone / iPad / macOS 是否共享状态、是否需要平台差异设计、是否需更新 `platform-page-inventory.md`

5. `docs/workflows/add-prompt.md`
   - 读取 `docs/prompts/README.md` 和 AI privacy spec
   - 强制记录 canonical prompt、中文审阅版本、变量、输出契约、隐私等级、调用代码路径和评测方式

### 11.3 强化模块级 spec / impl 结构规则

更新 `docs/spec/README.md`，说明后续高风险模块优先采用：

```text
docs/spec/<module>/spec.md
docs/spec/<module>/impl.md
docs/spec/<module>/decisions/
```

采用范围：

- AI Provider
- TTS
- Storage / migration / attachments
- Sync
- Permissions / diagnostics
- Prompt execution
- StoreKit / release

当前顶层 spec 不要求一次性迁移；只有当某模块继续扩展、实现地图变长或需要记录模块级决策时，再按任务方案逐步拆分。

### 11.4 强化 Prompt Registry

更新 `docs/prompts/README.md`，要求真实 Prompt 文档至少记录：

- Prompt ID
- 所属能力
- 状态：draft / active / superseded / retired
- 英文 canonical Prompt
- 中文审阅版本
- 输入变量
- 输出契约
- 隐私等级
- 是否允许发送照片、音频、日记、语言空间上下文
- 调用代码路径
- 测试 / 评测方式
- 变更记录

同时说明：

- 代码内置 Prompt 以英文 canonical 为准。
- 中文版本用于审阅、隐私检查和产品校对。
- Prompt 文档不是单独产品决策源；若 Prompt 体现新的产品或隐私判断，必须回写 spec、architecture 或 ADR。

### 11.5 设计轻量文档健康检查

优先新增 `scripts/check-docs.sh`，只做低争议结构检查：

- 根入口软链接是否仍指向 `docs/README.md`。
- `docs/workflows/README.md` 是否存在。
- `docs/plans/active` / `docs/plans/done` 文件名是否符合基本命名。
- `docs/review/rounds/*/README.md` 是否包含代码快照、状态、当前事实源或可作为依据字段。
- 已退出目录 `docs/worklogs/`、`docs/superpowers/`、`docs/guidelines/` 不应重新出现。
- 文档占位符扫描沿用现有 `TO[D]O` / `TB[D]` / 中文待补规则。

暂不做：

- 自动判断语义一致性。
- 自动修改文档。
- 自动删除历史文件。
- 对所有 `impl.md` 做 commit-lag 检查。

若脚本稳定，再考虑接入 `scripts/verify.sh`。

### 11.5.1 吸收 VMark 系统地图和故障恢复矩阵

更新 `docs/architecture/README.md`，要求后续系统级架构文档覆盖系统形态、入口点、关键数据流、模块依赖方向和故障恢复路径。

更新 `docs/spec/README.md`，要求高风险模块在 `spec.md` 或 `impl.md` 中补充故障与恢复路径矩阵，至少记录：

- 故障模式。
- 恢复路径。
- 自动化覆盖。
- 测试文件或手动验证。
- 剩余风险。

该矩阵优先适用于数据迁移、Repository、AI Provider、Prompt、TTS、权限、诊断日志、同步冲突和 Keychain 缺失恢复。

### 11.5.2 吸收 VMark 审计和周期性清理原则

更新 `docs/review/README.md`，补充轻量周期性文档健康检查分层：

- T1：每次文档体系变更或收尾前运行结构脚本、占位符扫描和 `git diff --check`。
- T2：高风险功能完成、连续出现同类问题或用户要求时做专项抽查。
- T3：MVP、数据层、AI 层、同步层、付费发布层阶段结束时做里程碑轻量全审。

不新增 `docs/audit/`、`docs/house-cleaning/` 或自动删除机制。

### 11.6 与约束路由索引分工

本任务实施时必须读取 `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`，并保持以下边界：

- `docs/_meta/documentation-constraints.md`：帮助新会话找到强约束的原始权威文档。
- `docs/workflows/*.md`：帮助执行某类任务时按正确顺序读文档、改文件、跑验证。
- `docs/spec/*`：记录长期开发约束和模块规范。
- `docs/plans/active/*.md`：记录具体任务的执行方案和验证路径。

任何 workflow 中出现的强制规则，都必须链接原始 spec、ADR、review 或入口文档，不把规则正文复制成长篇第二来源。

## 12. 复查方法

从以下角度复查：

- 目录职责：`docs/workflows/` 是否只承载执行手册，没有变成新事实源。
- 权威关系：新增 workflow 是否都引用原始 authoritative docs。
- 范围克制：是否没有新增 `docs/bug/`、`docs/ideas/` 或重命名 `docs/`。
- 可执行性：每个 workflow 是否能让新会话知道读什么、改什么、测什么。
- Prompt 完整性：`docs/prompts/README.md` 是否足以指导真实 Prompt 文档落地。
- 验证稳定性：`scripts/check-docs.sh` 若新增，是否只检查低争议结构，不做语义误判。
- 与约束索引关系：两个 active plan 是否职责互补，没有重复或冲突。

## 13. 验证命令

创建本方案后先运行：

```bash
git diff --check -- docs/plans/active/2026-05-25-docs-dev-docs-workflow-governance.md
rg -n "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs/plans/active/2026-05-25-docs-dev-docs-workflow-governance.md
git status --short
```

实施完成后至少运行：

```bash
find docs -maxdepth 4 -type f | sort
scripts/check-docs.sh
test ! -d docs/worklogs
test ! -d docs/superpowers
test ! -d docs/guidelines
if rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'; then exit 1; fi
git diff --check
git status --short
```

若新增 `scripts/check-docs.sh`：

```bash
scripts/check-docs.sh
```

若修改 `scripts/verify.sh`：

```bash
scripts/verify.sh
```

本任务默认不改 Swift 代码；若实施阶段仍保持文档-only 且不改 `scripts/verify.sh`，可不运行完整 Swift 工程验证，并在实施记录中说明原因。

## 14. 文档影响检查

本任务会影响文档体系自身，因此必须检查：

- `docs/README.md`：是否增加 workflow 路由但不膨胀入口。
- `docs/_meta/documentation-system.md`：是否记录 `workflows/` 职责和权威边界。
- `docs/_meta/directory-responsibilities.md`：是否更新目录结构和退出目录说明。
- `docs/spec/README.md`：是否记录模块级 `spec.md` / `impl.md` 结构规则。
- `docs/prompts/README.md`：是否补足真实 Prompt 文档要求。
- `docs/plans/README.md` 和模板：是否需要要求任务方案引用相关 workflow。
- `docs/review/README.md`：一般不修改；只有发现审查模式字段明显缺口时再追加，并需保持与现有审查机制一致。
- `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`：只读检查职责边界；如发现冲突，优先更新本方案或另行请求用户确认，不擅自改写已确认的约束索引方案。
- `docs/architecture/README.md`：若吸收系统地图原则，只写架构文档写作要求，不伪装当前已存在完整系统地图。
- `docs/review/README.md`：若吸收周期性健康检查，只扩展现有 review 机制，不新增并行审计体系。

## 15. 实施记录

- 2026-05-25：创建本 active plan，记录 OpenWriter `dev_docs` 对照结论和 LangoTrace 吸收方案。
- 2026-05-25：参考 VMark `dev-docs` 后执行文档完善：新增 `docs/workflows/` 首批 5 个动作手册，新增 `scripts/check-docs.sh`，更新入口、文档体系规则、目录职责、spec、Prompt Registry、plan 规则、review 机制和 architecture 入口。保持 docs-only，不修改 Swift、XcodeGen 或 package 结构。
- 2026-05-25：验证完成。`find docs -maxdepth 4 -type f | sort` 已运行；`scripts/check-docs.sh` 输出 `check-docs: ok`；`test ! -d docs/worklogs && test ! -d docs/superpowers && test ! -d docs/guidelines && test ! -d research` 通过；占位符扫描无命中；`git diff --check` 通过；`git status --short` 已检查。未运行 `scripts/verify.sh`，原因：本任务为 docs-only 和脚本结构检查变更，未修改 Swift、XcodeGen 或 package 行为。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- `docs/workflows/README.md` 已创建，且职责边界清楚。
- 首批 3 到 5 个 workflow 已创建，并能覆盖 AI Provider、TTS Provider、storage migration、platform screen、Prompt 中至少 3 类高风险动作。
- `docs/README.md`、`docs/_meta/documentation-system.md`、`docs/_meta/directory-responsibilities.md` 已按需更新。
- `docs/spec/README.md` 已说明模块级 `spec.md` / `impl.md` / `decisions/` 的采用规则。
- `docs/prompts/README.md` 已补足真实 Prompt 文档字段。
- 若新增 `scripts/check-docs.sh`，脚本已通过本地运行；若接入 `scripts/verify.sh`，完整验证已通过。
- 完成前检查没有占位符、已退出目录复活或 Markdown trailing whitespace。
- 实施记录写明实际修改、验证命令和结果。

## 17. 剩余风险

- workflow 增加后可能成为新会话优先阅读对象，若写得过重，会稀释 `docs/README.md` 和 spec 的权威关系；因此 workflow 必须保持短、动作化、引用式。
- 模块级 `spec.md` / `impl.md` 结构若一次性推广过猛，会造成大规模文档搬迁和历史链接漂移；本任务只建立规则和首批入口，不做全量迁移。
- 文档健康脚本如果过早扩大到语义判断，会产生误报并诱导“为了通过脚本而改文档”；首版只做结构检查。
- OpenWriter 的经验来自 TUI / TypeScript 项目，不能直接套用到 Apple 三端、SwiftUI、Keychain、SQLite / GRDB、StoreKit 和本地优先隐私边界；所有吸收内容必须经过 LangoTrace 现有产品愿景和 ADR 过滤。
