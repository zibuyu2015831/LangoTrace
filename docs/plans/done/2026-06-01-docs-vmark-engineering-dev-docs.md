# 任务方案：吸收 VMark 工程素养完善 Dev Docs 文档体系

状态：Verified
自审核状态：Reviewed
类型：docs
创建日期：2026-06-01
最后更新日期：2026-06-01

## 用户确认记录

- 2026-06-01：用户要求创建 active plan，吸收 `docs/reference/projects/vmark/dev-docs` 中优秀的开发工程素养设计，完善当前项目的 dev docs 文档体系。
- 本方案为实施前方案，不代表已获准修改长期文档规则。进入实施前需要用户确认范围，并按 `docs/plans/plan-review-protocol.md` 完成严格方案自审核。
- 2026-06-01：用户要求根据 `docs/plans/README.md` 对本方案进行自审。本轮执行主会话自审核，修订发现 ID 命名、测试边界、脚本验证边界和自审核记录；方案仍为 Draft，实施前仍需用户确认。
- 2026-06-01：用户切换 VMark 到 `zibuyu` 分支，要求阅读其中项目考古评估报告，继续思考如何借鉴、吸收、完善当前项目 dev docs 文档体系。本轮追加 `zibuyu-analysis/` 报告结论：evidence-backed claim、guardrail 生命周期、plan-vs-shipped 对账、cross-model audit 主线程复核和 release-tail closeout。
- 2026-06-01：用户确认“立即实施该方案”。本轮授权范围限于本方案列出的 docs-only 文档治理修改和 `scripts/check-docs.sh` 低争议结构检查增强，不包含 Swift 代码、XcodeGen、schema、Provider、同步、StoreKit 或历史记录删除。

## 1. 需求或 bug 描述

用户希望 LangoTrace 在现有严格文档控制面的基础上，继续吸收 VMark `dev-docs` 中更成熟的工程计划和治理方法，让后续高风险开发任务具备更强的可追踪性、可验证性和收口质量。

本任务不是再次复制 VMark 的目录结构，而是把 VMark 近期终端审计与整改方案中体现出的工程素养，转化为适合 LangoTrace 的文档规则和模板提示：

- 审计发现 ID 能从 review round 贯穿到 active plan 的 work item。
- 高风险任务可以明确使用 Phase 0 spike / baseline gate。
- 多阶段任务可以定义机器可检查 DoD。
- deferred / aborted 项有明确决策日志、复审条件和后续事实源。
- 任务方案和 review round 的关系更清晰，避免审计报告、计划和完成记录互相脱节。
- 重大文档治理结论区分“证据能证明什么 / 证据不能证明什么 / 迁移前提 / 照搬风险”，避免把参考项目、AI 输出或 commit message 叙事直接升级为当前事实。
- guardrail 具备生命周期记录，能说明一条检查规则是 advisory、manual、script、CI、hook-blocking 还是 release-blocking，也能记录 strengthened、weakened、manualized、removed 或 replacement。
- 阶段性功能完成后有 release-tail closeout 入口，用 focused review / focused tests / CI repair / stale-test alignment 收口，而不是把尾部修复吞进主功能叙事。

## 2. 现状描述

LangoTrace 已经具备较完整的文档体系：

- `docs/README.md` 是 AI 会话总入口，定义文档读取路径、核心决策、TDD、active plan 和文档影响检查规则。
- `docs/plans/README.md` 和 `docs/plans/examples/task-plan-template.md` 已定义任务方案生命周期、必填字段和状态。
- `docs/plans/plan-review-protocol.md` 已作为 active plan 进入实现前的严格方案自审核协议。
- `docs/review/README.md` 已定义日常文档影响检查、专项审查、里程碑轻量全审和保守文档自进化。
- `docs/review/health-ledger.md` 已吸收 VMark house-cleaning 的轻量趋势记录思想。
- `docs/architecture/002-system-map.md` 已吸收 VMark architecture map 的快速系统地图形式。
- `docs/reference/research/spikes/README.md` 已吸收 spike / probe / fixture / evidence 的研究落点规则。
- `docs/reference/research/2026-06-01-vmark-dev-docs-assessment.md` 已记录本轮 VMark dev-docs 再评估结论。

已存在相关任务：

- `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`：处理文档约束索引、任务方案模板增强和方案自审核协议接入。
- `docs/plans/done/2026-05-25-docs-vmark-docs-system-optimization.md`：已吸收系统地图、故障恢复矩阵、spike / probe / health ledger 等第一批 VMark 机制。
- `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md`：已吸收 workflow、系统地图、故障恢复矩阵、审计严重度和周期性健康检查原则。

本方案的新增价值在于：聚焦 VMark 后续终端审计和大型整改 plan 的工程闭环，不重复既有约束索引、workflow 和 health ledger 落地。

## 3. 目标

本任务完成后必须达到：

- `docs/review/README.md` 补充专项审查发现 ID 的推荐格式、使用边界和从 review round 到 active plan 的引用规则。
- `docs/plans/README.md` 补充高风险多阶段任务的工程计划要求，包括 Phase 0 gate、work item 对照、机器可检查 DoD、deferred / aborted 决策日志和完成收口规则。
- `docs/plans/examples/task-plan-template.md` 增加可选但结构化的“审计发现对照”“Phase 0 spike gate”“阶段 DoD”“延后 / 中止决策日志”填写块。
- `docs/reference/research/spikes/README.md` 补充 Phase 0 gate 与普通 spike / probe / fixture 的关系，明确研究证据如何进入 active plan，何时清理或保留。
- `docs/review/health-ledger.md` 或 `docs/review/README.md` 明确：趋势记录中的重复问题连续出现时，如果进入 remediation plan，应带上稳定发现 ID 和 verdict，不只追加趋势描述。
- `docs/reference/README.md`、`docs/reference/research/spikes/README.md` 或任务模板补充轻量 evidence-backed claim 写法：参考研究被采纳前必须写清证据能证明什么、不能证明什么、迁移前提和照搬风险。
- `docs/plans/README.md` 或任务模板补充 plan-vs-shipped 对账：高风险 done plan 收口时，检查 work item、scope-down、deferred / aborted 项和实际文档 / 代码 / 测试 / review evidence 是否一致。
- `docs/review/README.md` 补充 release-tail closeout 的适用场景：数据层、AI 层、同步层、StoreKit、权限层、跨 package 大功能或 TestFlight / 发布前。
- `docs/review/README.md` 或 `docs/plans/README.md` 补充 guardrail 生命周期记录：新增或调整脚本、CI、TDD、coverage、AI audit 或文档检查规则时，应记录 enforcement level、引入原因、回调路径和替代机制。
- `scripts/check-docs.sh` 只在低争议范围内增强结构检查，例如确认 plan template 包含新增章节、review README 包含发现 ID 规则；不做语义审查，不自动修改文档。
- 本任务为 docs-only 治理任务，不新增 Swift 单元测试；测试落点是 `scripts/check-docs.sh` 的结构检查、占位符扫描和 `git diff --check`。若修改脚本，必须至少运行一次通过路径，并在必要时用临时副本或可还原方式验证失败输出清晰。
- 所有新增规则都保持 LangoTrace 权威分层：reference 不是事实源，review 是审查记录，plan 是实施入口，ADR / spec / architecture 才承载长期决策和实现边界。

## 4. 范围

本任务覆盖：

- 文档规则和模板修改。
- review 与 plan 的衔接规则。
- spike / probe 研究证据进入 active plan 的规则。
- 文档结构检查脚本的低争议增强。
- 文档-only 验证和收口。

预计修改文档：

- `docs/review/README.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/reference/research/spikes/README.md`
- `docs/review/health-ledger.md`
- `scripts/check-docs.sh`

可能修改文档：

- `docs/README.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`

## 5. 不做什么

本任务不做：

- 不修改 Swift 源码、XcodeGen、Package、SQLite schema、Prompt、Provider、StoreKit 或同步实现。
- 不新增 `docs/audit/`、`docs/house-cleaning/`、`docs/grills/` 或 `dev-docs/` 目录。
- 不复制 VMark 面向 Tauri / React / Rust / MCP / Markdown editor 的技术栈规则。
- 不把 VMark 的 ADR、架构决策、AI routing、terminal architecture 或 Markdown source-of-truth 决策转写成 LangoTrace 决策。
- 不复制 VMark `zibuyu-analysis/` 的完整考古目录、episode ledger、claim ledger 或 evidence admission pipeline；只吸收轻量证据边界和结论写法。
- 不把 second-model / cross-model audit 当成自动真理；外部模型或工具审查必须经主线程复核，并回写到 plan、测试、代码或 review 记录。
- 不复制 VMark 的 near-100% coverage threshold、TDD Guardian 强阻断或 GitHub Actions 成本 / auth 体系；只吸收 guardrail 生命周期记录和回调机制。
- 不删除历史 review、done plan、archive 或 reference 记录。
- 不把机器可检查 DoD 扩展为语义裁决器；脚本只检查结构性事实。
- 不强制每个小任务都写 Phase 0、work item ID 或阶段检查脚本。
- 不与 `docs/plans/active/2026-05-23-docs-doc-constraint-index.md` 重复实现文档约束索引或通用方案自审核协议。

## 6. 证据与决策依据

LangoTrace 文档依据：

- `docs/README.md`：文档总入口、active plan、TDD、文档影响检查和参考项目边界。
- `docs/plans/README.md`：任务方案生命周期、必填字段、状态和文档治理任务规则。
- `docs/plans/examples/task-plan-template.md`：当前任务方案模板。
- `docs/plans/plan-review-protocol.md`：active plan 进入实现前的严格方案自审核协议。
- `docs/review/README.md`：文档审查机制、专项 review、健康趋势和保守文档自进化规则。
- `docs/reference/README.md`：参考项目不能直接成为产品决策源、架构事实源或实现事实源。
- `docs/reference/research/spikes/README.md`：spike / probe / fixture / evidence 的研究落点。
- `docs/reference/research/2026-06-01-vmark-dev-docs-assessment.md`：本轮 VMark dev-docs 再评估结论。
- `docs/reference/projects/vmark/zibuyu-analysis/reports/project-methods/dev-docs-system.md`：项目考古报告对 VMark dev docs、ADR、plans、audit notes 与 runtime truth 对账的总结。
- `docs/reference/projects/vmark/zibuyu-analysis/reports/reusable/ai-assisted-programming-playbook.md`：可复用 AI 辅助编程方法，强调 working agreement、phase / WI / checkpoint、cross-model audit、guardrail 生命周期和 release-tail closeout。
- `docs/reference/projects/vmark/zibuyu-analysis/reports/author-thinking/development-philosophy.md`：作者开发思路报告，强调先分解再证明、失败进入制度、AI 是审查放大器而非证据替代品。
- `docs/reference/projects/vmark/zibuyu-analysis/reports/author-thinking/growth-path.md`：作者成长路径报告，记录从 phased execution 到 public control-plane、guardrail 回调、architecture contract 校准和 release-tail closeout 的阶段演化。

VMark 参考依据：

- `docs/reference/projects/vmark/dev-docs/README.md`：active docs 入口、日期 / 状态、单一事实源和行为变更同步文档规则。
- `docs/reference/projects/vmark/dev-docs/audit/protocol.md`：审计输出格式和严重度。
- `docs/reference/projects/vmark/dev-docs/audit/20260531-terminal-integration.md`：终端审计使用稳定发现 ID、文件证据和优先级。
- `docs/reference/projects/vmark/dev-docs/plans/20260531-terminal-industrial-best.md`：大型整改 plan 使用 Phase、WI、ADR、RED test、DoD、Phase 0 spike 和 deferred / aborted 决策记录。
- `docs/reference/projects/vmark/dev-docs/house-cleaning/findings-template.md`：每条发现必须有 verdict。
- `docs/reference/projects/vmark/dev-docs/baselines/README.md`：视觉 baseline 只作为 dev verification，不污染生产 surface。
- `docs/reference/projects/vmark/zibuyu-analysis/STATUS.md`、`progress/checkpoint.md`、`reports/README.md`：说明考古报告的证据门控、accepted claims、episode ledger 和禁止 speculative 结论提升的边界。

关键判断：

- LangoTrace 当前文档体系整体方向正确，不应推翻。
- VMark 值得继续吸收的是工程闭环机制，不是目录形态或技术栈事实。
- 本轮最有价值的吸收点是高风险任务的“审计发现 -> 计划 work item -> 验证 DoD -> 延后 / 中止决策 -> 收口记录”链路。
- VMark `zibuyu-analysis/` 表明，真正有效的 dev docs 是 active control plane：计划、ADR、审查、测试、脚本、CI、运行时事实和收口记录能互相对账。
- LangoTrace 不需要复制完整 evidence ledger，但需要在参考研究和高风险文档治理中保留“证据能证明什么 / 不能证明什么 / 迁移前提 / 照搬风险”的写法。
- guardrail 不是越强越好；新增脚本、CI、TDD、coverage、AI audit 或文档检查规则时，应记录 enforcement level 和生命周期，允许根据误报、维护成本和信号质量诚实回调。
- 这些机制应作为高风险任务的可选强化规则，不应提高所有轻量任务的流程成本。

高风险或研究性任务补充：

```text
是否需要 spike / probe / fixture / evidence：需要。实施前需要把 VMark 终端审计和整改方案中的可迁移机制作为 evidence，已经落点到 docs/reference/research/2026-06-01-vmark-dev-docs-assessment.md。
需要时的落点：docs/reference/research/2026-06-01-vmark-dev-docs-assessment.md；实施中如发现新的 VMark 证据，可追加到本 active plan 的实施记录或新建 reference research 记录。
是否包含真实用户敏感内容：否。只涉及公开参考项目文档和本仓库开发文档。
如何验证和清理：完成后运行文档结构检查、占位符扫描、git diff 检查；不删除参考项目文档。
```

## 7. 涉及的代码文件路径

预计修改：

- `scripts/check-docs.sh`

不修改 Swift、XcodeGen、Package、App target 或测试 target。

## 8. 参考的代码文件路径

无生产代码参考。可能只读参考：

- `scripts/check-docs.sh`

## 9. 涉及的文档路径

预计修改：

- `docs/review/README.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/reference/research/spikes/README.md`
- `docs/review/health-ledger.md`

可能修改：

- `docs/README.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`

只读参考：

- `docs/reference/README.md`
- `docs/reference/research/2026-06-01-vmark-dev-docs-assessment.md`
- `docs/plans/active/2026-05-23-docs-doc-constraint-index.md`
- `docs/plans/done/2026-05-25-docs-vmark-docs-system-optimization.md`
- `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md`
- `docs/reference/projects/vmark/dev-docs/README.md`
- `docs/reference/projects/vmark/dev-docs/audit/protocol.md`
- `docs/reference/projects/vmark/dev-docs/audit/20260531-terminal-integration.md`
- `docs/reference/projects/vmark/dev-docs/plans/20260531-terminal-industrial-best.md`
- `docs/reference/projects/vmark/dev-docs/house-cleaning/findings-template.md`
- `docs/reference/projects/vmark/dev-docs/baselines/README.md`
- `docs/reference/projects/vmark/zibuyu-analysis/reports/project-methods/dev-docs-system.md`
- `docs/reference/projects/vmark/zibuyu-analysis/reports/reusable/ai-assisted-programming-playbook.md`
- `docs/reference/projects/vmark/zibuyu-analysis/reports/author-thinking/development-philosophy.md`
- `docs/reference/projects/vmark/zibuyu-analysis/reports/author-thinking/growth-path.md`
- `docs/reference/projects/vmark/zibuyu-analysis/reports/README.md`
- `docs/reference/projects/vmark/zibuyu-analysis/STATUS.md`
- `docs/reference/projects/vmark/zibuyu-analysis/progress/checkpoint.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 查重和边界确认

1. 重新搜索 `docs/plans/active/`、`docs/plans/done/` 和 `docs/review/INDEX.md`，确认本任务不与现有 active plan 重复。
2. 确认 `docs/plans/active/2026-05-23-docs-doc-constraint-index.md` 的范围仍是约束索引、通用模板增强和方案自审核协议，本任务只补高风险工程闭环。
3. 确认 `docs/reference/README.md` 的参考项目边界仍然适用：VMark 只能作为工程治理参考，不是 LangoTrace 当前事实源。

### 11.2 增强 review 发现 ID 规则

修改 `docs/review/README.md`：

- 在专项审查章节增加“发现 ID”规则。
- 推荐格式：
  - 数据 / 存储：`DATA-1`、`DATA-2`
  - AI / Prompt / Provider：`AI-1`、`AI-2`
  - 权限 / 隐私 / 诊断：`PRIV-1`、`PRIV-2`
  - 同步：`SYNC-1`、`SYNC-2`
  - UI / 可访问性：`UI-1`、`UI-2`
  - 文档治理：`DOC-1`、`DOC-2`
- 说明 ID 只在单个 review round 内稳定；跨 round 引用时必须带 round id。
- 要求来源于 review round 的 remediation plan 在“证据与决策依据”中列出 `round id -> finding id -> work item` 对照。
- 说明发现 ID 不替代 P0 / P1 / P2 / P3 严重度；ID 用于追踪，严重度用于排序。

### 11.3 增强 plan 高风险工程闭环规则

修改 `docs/plans/README.md`：

- 在必填内容中补充“来源于 review round 时的发现 ID 对照”。
- 在使用规则中补充：高风险、多阶段、跨 package 或超过 3 个阶段的任务，应考虑增加 Phase 0 gate。
- 定义 Phase 0 gate 最低内容：
  - 假设名称。
  - probe / fixture / baseline 路径。
  - PASS / FAIL 条件。
  - FAIL 后的处理方式。
  - 是否允许进入生产实现。
- 定义机器可检查 DoD 的边界：
  - 适合大型多阶段任务。
  - 只检查文件、章节、命令、测试、migration、review round 状态等结构性事实。
  - 不替代语义审查。
- 定义 deferred / aborted 决策日志最低字段：
  - 项目。
  - 决策类型：deferred 或 aborted。
  - 原因。
  - 影响。
  - 后续事实源或复审入口。

### 11.4 增强任务方案模板

修改 `docs/plans/examples/task-plan-template.md`：

- 在“证据与决策依据”后增加可选块“审计发现与 work item 对照”。
- 在“实施方案”中增加可选块“Phase 0 spike / baseline gate”。
- 在“验证命令”中增加可选块“阶段 DoD 检查命令”。
- 在“剩余风险”或“实施记录”中增加“延后 / 中止决策日志”模板。
- 明确这些块仅在来源于 review round、高风险、多阶段或跨 package 任务中使用；轻量 docs 修正可以写“不适用，原因：本任务不来源于 review round，且不涉及高风险实现”。

### 11.5 补充 spike 研究入口

修改 `docs/reference/research/spikes/README.md`：

- 补充 Phase 0 gate 与普通 spike / probe / fixture 的关系。
- 明确 Phase 0 gate 的 evidence 可以放在 `docs/reference/research/`，但被采纳后必须写回 active plan、spec、architecture、testing 或 ADR。
- 明确研究失败也要记录 FAIL 原因和后续处理，不能只删除证据。
- 明确不保存真实用户敏感内容；需要敏感样本时必须使用脱敏 fixture 或人工验收记录。

### 11.6 补充 health ledger 到 remediation plan 的升级规则

修改 `docs/review/health-ledger.md` 或 `docs/review/README.md`：

- 明确同类问题连续出现后，如果创建 remediation plan，应在 plan 中使用稳定 finding id 或 health-ledger trigger id。
- 明确每条 health-ledger 发现仍需 verdict，例如已修、转为 active plan、明确接受、延后原因或由 review round 承接。
- 避免让 ledger 变成第二套 issue tracker；它只提供趋势和升级触发。

### 11.7 补充 evidence-backed claim 和 plan-vs-shipped 对账

修改 `docs/reference/README.md`、`docs/reference/research/spikes/README.md` 或 `docs/plans/examples/task-plan-template.md`，采用最小落点：

- 对参考项目研究和重大文档治理结论，要求写清：
  - 证据能证明什么。
  - 证据不能证明什么。
  - 迁移前提。
  - 照搬风险。
- 对高风险 done plan 收口，要求检查：
  - work item 是否有实际文档、代码、测试、脚本或 review evidence。
  - plan 中的 scope 是否被实施缩小；若缩小，是否写明 scope-down。
  - deferred / aborted 项是否从完成叙事中剥离，并有后续事实源或复审入口。
- 该机制不引入完整 episode ledger 或 claim ledger；只把考古报告中的证据边界写法轻量吸收进现有 reference / plan / review 体系。

### 11.8 补充 guardrail 生命周期规则

修改 `docs/review/README.md`、`docs/plans/README.md` 或 `docs/review/health-ledger.md`，采用最小落点：

- 新增或强化脚本、CI、TDD、coverage、AI audit、文档检查或 release gate 时，应记录 enforcement level：
  - advisory
  - manual
  - script
  - CI
  - hook-blocking
  - release-blocking
- 对后续 weakened、manualized、removed 或 replacement，应在对应 active plan、review round 或 health ledger 中记录原因。
- 不直接复制 VMark 的强 gate 数值；只复制机制生命周期记录。

### 11.9 补充 release-tail closeout 规则

修改 `docs/review/README.md` 或 `docs/plans/README.md`：

- 定义 release-tail closeout 适用场景：数据层、AI 层、同步层、StoreKit、权限层、跨 package 大功能、TestFlight / 发布前。
- 说明 release-tail closeout 可包含 focused review、focused tests、CI repair、stale-test alignment、文档影响检查和剩余风险降权。
- 明确它不是每个小任务的强制流程；没有清晰 feature batch 边界时不要启用。

### 11.10 增强结构检查脚本

修改 `scripts/check-docs.sh`，只增加低争议检查：

- 确认 `docs/plans/examples/task-plan-template.md` 包含“审计发现”或同等章节。
- 确认 `docs/review/README.md` 包含“发现 ID”或同等规则。
- 确认 `docs/reference/research/spikes/README.md` 包含“Phase 0”或同等规则。
- 如脚本中已有类似检查，复用现有风格，不引入新依赖。
- 如要验证失败路径，优先用临时复制文件或可还原的最小改动触发失败，验证后必须恢复；不得为了测试脚本而破坏长期文档或留下临时文件。

脚本不得检查某个具体业务 plan 是否语义正确，也不得自动修改文档。

### 11.11 文档影响检查和收口

1. 检查是否需要更新 `docs/README.md`。只有当新增规则需要入口发现时才更新，避免入口过载。
2. 检查是否需要更新 `_meta`。如果没有新增目录职责，不更新 `_meta`。
3. 运行文档验证命令。
4. 在本方案“实施记录”中记录实际修改、验证命令和结果。
5. 完成后将本方案移入 `docs/plans/done/`，状态更新为 `Verified` 或 `Done`。

## 12. 严格方案自审核记录

已按 `docs/plans/plan-review-protocol.md` 执行主会话自审核。本轮只修订方案，不进入长期文档实施。

```text
审核日期：2026-06-01
审核方式：主会话自审核
审核轮次：单轮
未使用隔离审查的原因：当前请求是对单份 active plan 按 docs/plans/README.md 做自审，范围为文档治理方案修订；本轮可由主会话基于 AGENTS.md、docs/plans/README.md、docs/plans/plan-review-protocol.md、docs/review/README.md、spikes 入口和目标 plan 完成。
发现摘要：
- P1：发现 ID 示例使用 `P1` / `P2` 表示权限 / 隐私 / 诊断，和现有 P0 / P1 / P2 / P3 严重度语义冲突。已改为 `PRIV-1` / `PRIV-2` 等领域前缀格式。
- P1：方案属于 docs-only 文档治理，但目标和验证中没有明确 TDD / 单元测试例外，容易被误解为需要新增 Swift 测试。已补充测试落点为文档结构检查、占位符扫描、diff check 和脚本路径验证。
- P2：脚本失败路径验证边界不够明确，可能诱导通过破坏长期文档来测试失败输出。已补充必须使用临时复制文件或可还原最小改动，且验证后恢复。
- P2：与 `2026-05-23-docs-doc-constraint-index.md` 的职责边界已写明，但实施阶段仍需复查，避免重复修改同一模板语义。
- P1：读取 VMark `zibuyu-analysis/` 后发现原方案只覆盖 dev-docs 目录和终端整改计划，缺少考古报告中更关键的 evidence-backed claim、guardrail 生命周期、plan-vs-shipped 对账和 release-tail closeout。已补充进目标、证据、实施方案和剩余风险。
写回修改：已更新头部自审核状态、用户确认记录、目标、证据与决策依据、参考文档路径、实施方案 11.2 / 11.7 / 11.8 / 11.9 / 11.10 和本自审核记录。
仍需用户确认的问题：是否批准按本方案修改 docs/review、docs/plans、reference research spikes、health ledger 和 scripts/check-docs.sh。
是否允许进入实现：否。本方案自审核已完成，但状态仍为 Draft；需要用户确认实施范围后才可进入实现。
```

## 13. 复查方法

复查时按以下问题检查：

- 新增规则是否仍然保持 LangoTrace 的文档权威分层，没有让 VMark reference 成为事实源。
- `docs/review/README.md` 中的发现 ID 规则是否能指导 review round 到 active plan 的衔接。
- `docs/plans/README.md` 和模板是否清楚表达 Phase 0 gate、机器可检查 DoD、deferred / aborted 决策日志的适用条件。
- `docs/reference/research/spikes/README.md` 是否说明研究证据如何被采纳、失败和清理。
- `scripts/check-docs.sh` 是否只做结构检查，没有做语义裁决。
- 参考研究和重大文档治理结论是否写清证据能证明什么、不能证明什么、迁移前提和照搬风险。
- 高风险 done plan 收口是否具备 plan-vs-shipped 对账，不把 scope-down、deferred 或 aborted 项包装成完成。
- 新增 guardrail 是否记录 enforcement level 和未来回调路径。
- release-tail closeout 是否只用于阶段性或跨 package 高风险任务，没有扩张到所有小任务。
- docs-only 测试例外是否仍成立；若实施中引入可自动化行为变化或脚本复杂逻辑，应补充对应脚本级验证。
- 与 `2026-05-23-docs-doc-constraint-index.md` 是否分工清楚，没有重复实现同一套约束索引。

## 14. 验证命令

完成前必须运行：

```bash
find docs -maxdepth 3 -type f | sort
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如修改 `scripts/check-docs.sh`，还应单独确认脚本在失败时有清晰错误输出，且不依赖外部网络或用户本地未安装工具。

## 15. 文档影响检查

本任务本身就是文档体系治理，预计影响：

- `docs/review/README.md`：专项审查与 remediation plan 衔接规则。
- `docs/plans/README.md`：高风险多阶段工程计划规则。
- `docs/plans/examples/task-plan-template.md`：任务方案模板。
- `docs/reference/research/spikes/README.md`：研究证据和 Phase 0 gate 规则。
- `docs/review/health-ledger.md`：趋势问题升级到 remediation plan 的规则。
- `docs/reference/README.md`：可能补充参考研究结论的证据边界写法。
- `scripts/check-docs.sh`：文档结构检查。

预计不影响：

- 产品北极星。
- ADR 决策。
- SwiftUI 架构、数据 schema、AI Provider、TTS、权限、同步、StoreKit 的实现事实。
- 发布文档。

如果实施中发现新增规则改变了 ADR、spec、architecture 或 review 的权威关系，必须停止实施并请求用户确认。

## 16. 实施记录

- 2026-06-01：创建本 active plan。当前状态为 Draft，尚未实施长期文档修改。
- 2026-06-01：用户确认立即实施后，按 docs-only 范围完成长期文档规则和结构检查脚本修改：
  - `docs/review/README.md`：新增专项审查发现 ID、release-tail closeout、guardrail 生命周期和 health ledger 升级到 remediation plan 的衔接规则。
  - `docs/plans/README.md`：新增 finding id / trigger id 对照、Phase 0 gate、机器可检查 DoD、deferred / aborted 决策日志、plan-vs-shipped 对账和 guardrail 记录要求。
  - `docs/plans/examples/task-plan-template.md`：新增 evidence-backed claim、审计发现与 work item 对照、Phase 0 gate、阶段 DoD、延后 / 中止决策日志和 plan-vs-shipped 收口块。
  - `docs/reference/research/spikes/README.md`：新增 evidence-backed claim、失败记录和 Phase 0 gate 规则。
  - `docs/review/health-ledger.md`：新增 trigger id、verdict 和“不作为第二套 issue tracker”的边界。
  - `scripts/check-docs.sh`：新增低争议结构检查，覆盖发现 ID、guardrail、release-tail、任务模板和 Phase 0 / evidence-backed claim 入口。
- 2026-06-01：`scripts/check-docs.sh` 失败路径验证使用临时副本 `scripts/.check-docs-fail-test.sh`，替换新增 finding ID 检查关键词后运行，结果为 `status=1`，输出 `check-docs: docs/review/README.md must include finding ID rules`；临时副本已删除。
- 2026-06-01：plan-vs-shipped 对账：方案 11.2 至 11.10 均已落地；未新增 VMark 同名目录；未复制 VMark 技术栈规则；未修改 Swift、XcodeGen、Package、SQLite schema、Prompt、Provider、StoreKit 或同步实现；未删除历史 review、done plan、archive 或 reference 记录。
- 2026-06-01：验证命令第一轮结果：
  - `find docs -maxdepth 3 -type f | sort`：已运行，用于确认文档树。
  - `scripts/check-docs.sh`：通过，输出 `check-docs: ok`。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：无输出，退出码 1，表示未命中。
  - `git diff --check`：通过，无输出。
  - `git status --short`：显示本任务修改的 docs / script 文件，以及既有未提交用户改动和其他未跟踪计划 / research 文件。
- 2026-06-01：本方案已从 `docs/plans/active/` 移入 `docs/plans/done/`，状态为 `Verified`。移动后最终验证结果：
  - `find docs -maxdepth 3 -type f | sort`：已运行，输出包含 `docs/plans/done/2026-06-01-docs-vmark-engineering-dev-docs.md`，不再包含本方案 active 路径。
  - `scripts/check-docs.sh`：通过，输出 `check-docs: ok`。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：无输出，退出码 1，表示未命中。
  - `git diff --check`：通过，无输出。
  - `git status --short`：显示本任务修改文件、done plan 未跟踪文件，以及既有未提交用户改动；无临时失败路径验证文件残留。

## 17. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 用户确认实施范围。
- 严格方案自审核完成，头部 `自审核状态` 更新为 `Reviewed`。
- 目标文档完成修改，且没有新增 VMark 同名目录或跨栈技术规则。
- `scripts/check-docs.sh` 如被修改，能通过并保持低争议结构检查边界。
- 若 `scripts/check-docs.sh` 新增检查，已验证通过路径；如验证失败路径，使用临时复制文件或可还原改动并恢复现场。
- 验证命令全部运行并记录结果。
- 文档影响检查记录实际影响和不影响范围。
- 方案实施记录写明任何偏离方案的原因。

## 18. 剩余风险

- 流程规则过重：如果所有任务都强制使用 Phase 0、发现 ID 和阶段 DoD，会降低轻量文档修正效率。本方案通过“高风险、多阶段、跨 package、来源于 review round”限定适用范围。
- 证据体系过重：完整复制 VMark 考古的 episode / claim / evidence ledger 会超出 LangoTrace 当前需求。本方案只吸收轻量证据边界写法。
- 模板膨胀：任务方案模板可能变长。实施时应把新增块标为条件适用，而不是要求每个任务填写复杂表格。
- 脚本误用：机器 DoD 容易被误解为语义正确。实施时必须反复强调脚本只检查结构事实。
- release-tail 过度泛化：如果没有清晰 feature batch 边界，release-tail closeout 会变成无止境补丁链。本方案只建议用于阶段性或跨 package 高风险收口。
- guardrail 过度强化：VMark 负样本显示强 gate 可能被维护成本反噬。本方案要求记录 enforcement level 和回调路径，不直接复制高阈值。
- 与现有 active plan 重叠：`2026-05-23-docs-doc-constraint-index.md` 仍是约束索引和通用自审核协议的主线，本方案不得重复或覆盖其职责。
- VMark 参考过度迁移：VMark 是 Tauri / React / Rust / MCP / Markdown editor 项目，LangoTrace 只能吸收工程治理机制，不能复制技术栈决策。
