# 任务方案：参考 VMark dev-docs 优化 LangoTrace docs 体系

状态：Verified
类型：docs
创建日期：2026-05-25
最后更新日期：2026-05-25

## 用户确认记录

- 2026-05-25：用户要求参考 `/Users/zibuyu/code/openSource/vmark/dev-docs` 的目录搭建和开发原则，对比 LangoTrace `docs/` 的异同、优劣和可借鉴设计。
- 2026-05-25：已完成只读审核，结论是 LangoTrace 的权威分层、产品 / 隐私 / 架构控制面更适合本项目；VMark 在系统地图、spike / probe / fixture 证据、周期性债务治理和轻量工程入口上更值得吸收。
- 2026-05-25：用户要求立即创建 active plan，记录本次审核结果，并给出优化、完善本项目 `docs/` 目录的方案。本记录确认创建本方案；涉及长期文档规则变更的实施仍需用户确认后开始。
- 2026-05-25：用户要求完整阅读本方案并立即实施，对本项目 `docs/` 目录进行优化；本次确认范围限定为文档体系优化和低争议脚本检查，不改 Swift 源码、XcodeGen、Package 结构或产品功能。

## 1. 需求或 bug 描述

用户希望把本次 VMark `dev-docs` 对比审核结果沉淀为可执行的 LangoTrace 文档体系优化方案，而不是只保留在聊天记录中。

本任务不是简单复制 VMark 目录，而是判断哪些机制适合 LangoTrace 当前 Apple 三端、本地优先、隐私敏感、AI / TTS / 同步 / StoreKit 逐步落地的工程控制面，并形成后续可实施的文档优化路径。

## 2. 现状描述

LangoTrace 当前 `docs/` 已经具备：

- `docs/README.md` 作为唯一真实入口，同时承担 AI 会话入口、任务类型路由、当前状态摘要和核心决策索引。
- `product-main-reference.md`、`technical-framework-roadmap.md`、`docs/decisions/`、`docs/spec/`、`docs/architecture/` 形成产品、架构、规范和 ADR 分层。
- `docs/plans/active` / `docs/plans/done` 统一承载功能、bug、重构、调研、文档治理和工程杂项任务。
- `docs/review/` 已有专项审查、复杂审查、状态机、索引、历史依据降权和周期性文档健康检查规则。
- `docs/workflows/` 已在 2026-05-25 的完成方案中新增，吸收过 VMark 的系统地图、故障恢复矩阵、审计严重度和周期性健康检查原则。

本次只读审核重新对比后发现，LangoTrace 仍有五个可优化点：

1. 系统地图可读性不足：当前 `docs/architecture/README.md` 已说明后续架构文档应覆盖系统形态、入口点、关键数据流和故障恢复路径，但还缺少一份像 VMark `dev-docs/architecture.md` 那样可被新会话快速读取的当前系统地图。
2. 故障恢复矩阵缺少统一架构落点：VMark `dev-docs/error-recovery.md` 把 failure mode、recovery path、test coverage 和 test file 放在同一张矩阵中；LangoTrace 当前相关要求散落在 spec、workflow、review 和 plan 中，不利于高风险能力收口。
3. spike / probe / fixture 证据缺少统一落点和处置规则：当前任务方案中已有局部 fixture 要求，但没有形成统一规则来区分 throwaway probe、长期 fixture、审查 evidence 和测试资源，也没有写清 probe 通过后保留、迁移或删除的条件。
4. 周期性健康治理已经有原则，但缺少低成本趋势指标：`docs/review/README.md` 已吸收 T1/T2/T3，但还没有 ledger 或同等轻量记录，用来追踪 active plan 数量、过期 review、占位符、链接问题、超大文档等趋势。
5. 本次 VMark 对比结论没有进入当前 active 计划控制面：已有 `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md` 记录过 VMark 参考，但它已完成；本次需要新 active plan 承接剩余优化项。

## 3. 目标

本任务完成后必须达到：

- 记录本次 VMark 对比审核的结论、证据、优劣判断和吸收边界。
- 明确 LangoTrace `docs/` 不直接复制 VMark `dev-docs/audit/`、`house-cleaning/`、`grills/` 目录，而是在现有权威分层内吸收其机制。
- 形成一份可执行优化方案，覆盖系统地图、spike / probe / fixture 证据规则、轻量健康趋势记录和文档验证入口。
- 将 VMark 的故障恢复矩阵吸收到 LangoTrace 高风险模块文档中，要求 failure mode、recovery path、test coverage 和 test file 可追踪。
- 明确 spike / probe 通过后的处置策略，避免临时探针长期混入当前事实源或测试资源。
- 明确需要修改的长期文档路径、验证命令、完成标准和剩余风险。
- 与已有完成方案 `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md` 分工清楚，不重复已经落地的 workflow 目录和首批 workflow。

## 4. 范围

预计后续实施可涉及：

- `docs/architecture/README.md`
- `docs/architecture/001-initial-module-boundaries.md`
- 可选新增 `docs/architecture/002-system-map.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- `docs/testing/README.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/reference/README.md`
- 可选新增 `docs/reference/research/spikes/README.md`
- 可选新增 `docs/testing/fixtures/README.md` 或在 package-level Tests fixture 规则中补充说明
- `scripts/check-docs.sh`
- 可选新增轻量健康记录文件，例如 `docs/review/health-ledger.md`
- 可选在高风险 spec 或 architecture 文档中新增故障恢复矩阵入口，优先覆盖数据、AI Provider、TTS、同步、权限、StoreKit 和媒体派生资产。

## 5. 不做什么

- 不把 LangoTrace `docs/` 改名为 `dev-docs`。
- 不新增 VMark 同名的 `docs/audit/`、`docs/house-cleaning/` 或 `docs/grills/` 目录。
- 不复制 VMark 面向 Tauri / React / MCP / Markdown 编辑器的技术栈规则。
- 不把 VMark 的工程决策当作 LangoTrace 的产品、隐私、数据、同步或商业决策。
- 不删除历史 review、done plan、archive 或 reference 文档。
- 不一次性重写所有 spec、architecture 和 testing 文档。
- 不改 Swift 源码、XcodeGen、Package 结构或产品功能。
- 不把机器脚本检查包装成语义审查结论；脚本只能做低争议结构检查。

## 6. 证据与决策依据

### 6.1 LangoTrace 当前文档证据

- `docs/README.md`：定义唯一真实入口、任务类型阅读路径、核心产品和架构决策、完成前检查。
- `docs/_meta/documentation-system.md`：定义文档分层、目录职责、Prompt Registry、workflow、review 和 testing 的落点。
- `docs/plans/README.md`：定义 active / done 生命周期、必填字段、文档治理任务规则。
- `docs/review/README.md`：定义文档审查机制、当前事实源 / 决策源 / 执行规则源 / 过程记录 / 审查记录分层，已经吸收 VMark T1/T2/T3 周期检查思路。
- `docs/workflows/README.md`：已经明确吸收 VMark 的系统地图、故障恢复、审计输出和周期检查原则，但不新增分块审计或 house-cleaning 目录。
- `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md`：已完成一轮参考 OpenWriter 与 VMark 的 workflow 治理落地；本任务承接其未完全展开的系统地图、证据库和趋势治理。

### 6.2 VMark dev-docs 参考证据

- `/Users/zibuyu/code/openSource/vmark/dev-docs/README.md`：用 Active Docs、Agent Configuration、Website Docs、Documentation Conventions 和 Important History 组织入口，强调单一事实源、日期 / 状态和行为变更同步文档。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/architecture.md`：用系统形态、进程 / runtime、入口点、关键数据流、模块地图和依赖方向快速建立工程全局图。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/audit/protocol.md`：审计协议要求分严重度输出，并记录文件、问题和修复建议。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/README.md`：提出 T1 / T2 / T3 / T4 周期治理、趋势指标、verdict 和自改进 gate。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/ledger.md`：把周期健康指标设计成 append-only 趋势记录，强调指标必须可机械采集、方向明确且能指导行动。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/findings-template.md`：要求每条发现都有 verdict，避免审查报告沉淀成无主噪声。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/error-recovery.md`：用矩阵追踪故障模式、恢复路径、测试状态和测试文件。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/grills/gha-workflow/README.md`：Phase 0 spikes 用 fixture 和 probe 先验证 parser、export、ProseMirror 集成和 round-trip，再进入正式实现。
- `/Users/zibuyu/code/openSource/vmark/dev-docs/fixtures/gha-workflows/`：把真实样本语料作为长期回归和研究证据保存。

### 6.2.1 VMark dev-docs 目录结构上下文

以下结构来自 `/Users/zibuyu/code/openSource/vmark/dev-docs`，用于理解本次审核参考对象的职责分布。该结构只作为外部参考，不作为 LangoTrace 当前事实源。

```text
dev-docs/
  README.md
  architecture.md
  error-recovery.md
  design-system.md
  css-reference.md
  cjk-gotchas.md
  large-file-open-pipeline.md
  coverage-promotion-plan.md
  audit/
  decisions/
  fixtures/
    gha-workflows/
  grills/
    gha-workflow/
    multi-format/
  house-cleaning/
  important-history/
  plans/
```

目录和关键文件作用：

- `README.md`：VMark 开发文档入口，索引 active docs、agent configuration、website docs、documentation conventions 和 important history。
- `architecture.md`：系统级工程地图，描述系统形态、运行进程、入口点、关键数据流、模块地图和依赖方向。
- `error-recovery.md`：故障恢复矩阵，按 persistence、file operations、configuration、application lifecycle、MCP bridge、editor 等边界记录 failure mode、recovery path、test status 和 test file。
- `design-system.md`：设计 token、组件和视觉模式的开发参考。
- `css-reference.md`：CSS 变更的视觉 QA 参考。
- `cjk-gotchas.md`：CJK formatter 的已知坑和实现注意事项。
- `large-file-open-pipeline.md`：大文件打开体验的端到端 pipeline、性能策略和降级路径。
- `coverage-promotion-plan.md`：测试覆盖提升计划。
- `audit/`：分块审计报告和审计协议目录，`protocol.md` 定义 Critical / Warning / Info 严重度、文件定位、问题描述和修复建议格式。
- `decisions/`：ADR 和重要技术决策目录，记录 Markdown source of truth、MCP sidecar、Tiptap 选型、AI provider routing 等不可轻易反转的工程决策。
- `fixtures/`：长期样本语料目录；`fixtures/gha-workflows/` 保存 GitHub Actions workflow fixture，用于回归、parser 和 round-trip 研究。
- `grills/`：深度调研、spike 和专项验证记录目录；`grills/gha-workflow/` 保存 Phase 0 probes、fixtures、spike write-up 和通过后的处置说明；`grills/multi-format/` 保存多格式能力相关调研、性能和安全评审。
- `house-cleaning/`：周期性债务治理目录，包含 cadence、weekly、monthly、quarterly、ledger schema 和 findings template，强调趋势、预算、verdict 和自改进 gate。
- `important-history/`：重要历史和复盘目录，保存代码库级改造、事故教训和后续 checklist。
- `plans/`：阶段性实施方案目录，保存功能、质量治理、workflow、house-cleaning、multi-format 等具体计划。

对 LangoTrace 的吸收判断：

- 可直接吸收的是职责机制：系统地图、故障恢复矩阵、spike / probe / fixture 证据链、周期健康 ledger 和每条发现必须有 verdict。
- 不直接吸收的是目录形态：不新增 `docs/audit/`、`docs/house-cleaning/` 或 `docs/grills/`，而是把对应机制分流到 LangoTrace 现有 `architecture/`、`review/`、`reference/research/`、`testing/`、`plans/` 和 `scripts/`。
- 不吸收的是技术栈事实：VMark 的 Tauri / React / MCP / Markdown editor 规则不能转写成 LangoTrace 的 SwiftUI Multiplatform、GRDB、Keychain、Provider、StoreKit 或同步事实。

### 6.3 对比结论

LangoTrace 优势：

- 权威分层更强，能区分产品核心决策、当前实现事实、执行规则、过程记录和审查记录。
- 对隐私、本地优先、Provider、Keychain、SQLite / GRDB、同步和 StoreKit 这类长期边界更谨慎。
- active / done 计划和 review round 生命周期更适合 AI 会话恢复和历史结论降权。

VMark 优势：

- 系统地图更短、更工程化，新会话能快速看到 runtime、entry point、data flow 和 module map。
- 故障恢复矩阵把失败模式、恢复行为和测试覆盖放在同一视图，减少“功能已写但异常路径无人验证”的盲区。
- spike / probe / fixture 证据链更实用，高风险依赖和复杂行为先用可运行样本证明。
- house-cleaning 把维护从“偶发清理”变成“有预算、有趋势、有 verdict 的周期治理”。
- audit protocol 的输出格式简洁，适合快速分块审计。

本项目推荐判断：

- LangoTrace 当前文档体系整体更适合本项目，不应推翻。
- 应吸收 VMark 的“工程地图 + 可运行研究证据 + 趋势化健康治理”，并嵌入现有 `architecture/`、`reference/research/`、`testing/`、`review/`、`plans/` 和 `scripts/`。

## 7. 涉及的代码文件路径

文档治理任务，默认无 Swift 代码修改。

可选脚本：

- `scripts/check-docs.sh`：如需要补充低争议结构检查或健康指标输出，可修改。
- `scripts/verify.sh`：仅当新增检查稳定、快速且无语义误判时，才考虑接入。

## 8. 参考的代码文件路径

无。

只读参考脚本：

- `scripts/check-docs.sh`
- `scripts/verify.sh`

## 9. 涉及的文档路径

预计修改或新增：

- `docs/architecture/README.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/architecture/002-system-map.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/directory-responsibilities.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- `docs/review/health-ledger.md`
- `docs/testing/README.md`
- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/reference/README.md`
- `docs/reference/research/spikes/README.md`
- 高风险模块的故障恢复矩阵落点，优先从 `docs/architecture/002-system-map.md` 建立索引，再按需分流到对应 spec 或 review round。

只读参考：

- `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md`
- `docs/workflows/README.md`
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/README.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/README.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/architecture.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/audit/protocol.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/error-recovery.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/README.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/ledger.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/house-cleaning/findings-template.md`
- `/Users/zibuyu/code/openSource/vmark/dev-docs/grills/gha-workflow/README.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 建立当前系统地图

新增或完善 `docs/architecture/002-system-map.md`，采用 VMark `architecture.md` 的可读性，但内容必须来自 LangoTrace 当前代码和现有权威文档。

建议结构：

```text
# LangoTrace 系统地图

状态：
最后核对：
代码快照：

## 1. 系统形态
## 2. App 和 Package 入口点
## 3. 关键运行时对象
## 4. 关键数据流
## 5. 模块依赖方向
## 6. 禁止反向依赖
## 7. 当前已知故障与恢复路径索引
## 8. 验证入口
```

系统地图必须写明：

- `代码快照` 来自实施时 `git rev-parse HEAD`，不能沿用旧 review 或 done plan 的快照。
- 每条入口点和数据流都要能追到当前代码、project 配置、脚本或权威文档。
- 对未完成能力使用 `未完成 / 未来能力 / 候选路径` 等明确标记，不能写成当前事实。

首批数据流至少覆盖：

- App 启动和语言空间恢复。
- 语言空间新增、切换、重命名、删除 fallback。
- Entry 写入和 LearningMaterial 生成 / 重新分析。
- AI Provider 配置、Keychain secret 和固定 probe。
- TTS 生成、local artifact cache 和播放 coordinator。
- 未来同步、导出、权限和 StoreKit 标记为未完成，不写成已实现。

### 11.2 建立故障恢复矩阵入口

吸收 VMark `error-recovery.md` 的矩阵做法，但不新增平行事实源。首版建议在 `docs/architecture/002-system-map.md` 中建立索引，并在对应 spec、testing 或 review round 中保存详细矩阵。

矩阵字段至少包含：

```text
能力 / 边界：
Failure mode：
Recovery path：
User-visible result：
Diagnostics / log：
Test status：Yes / Partial / No / Manual
Test file or verification：
Current owner document：
```

首批覆盖范围：

- App 启动和语言空间恢复失败。
- GRDB migration / repository 写入失败。
- AI Provider 配置缺失、Keychain 读取失败、Provider probe 失败和用户取消。
- TTS 生成失败、artifact cache miss / corrupt、播放取消和重试。
- 媒体派生资产 staging / atomic move / cleanup 失败。
- 未来同步、权限、导出和 StoreKit 先列为未完成能力，不虚构恢复路径。

实施边界：

- 已有测试的异常路径必须指向具体 test file 或验证命令。
- 没有自动化测试的异常路径必须标记 `No` 或 `Manual`，并进入后续测试计划或剩余风险。
- 矩阵不得替代 bug plan；发现真实缺陷时仍按 `docs/plans/active/` 建 bug / refactor / docs 方案。

### 11.3 明确 spike / probe / fixture / evidence 的落点

在 `_meta`、`reference`、`testing` 或 `review` 中明确四类材料的职责：

- spike：实现前的短期可行性验证，默认放入当前任务方案或 `docs/reference/research/spikes/`；被采纳后结论必须提升到 spec、architecture、ADR 或 plan。
- probe：可重复运行的小型验证脚本或样例，若保留为长期开发工具，需要放入 `scripts/`、测试 target 或 reference research，并写明运行方式。
- fixture：自动化测试依赖的稳定样本，优先靠近测试 target；涉及外部格式或研究样本时可放入 reference，但不得包含真实用户敏感内容。
- evidence：审查 round 的命令输出、截图、日志和手动验证证据，归入 `docs/review/rounds/<round>/`。

同时吸收 VMark `grills/gha-workflow/README.md` 的处置规则：

- throwaway probe 必须在任务方案中写明保留期限和删除条件。
- spike 通过后，长期 fixture 迁入测试 target 或 reference research；临时 probes 默认删除或归档为 historical-only 证据。
- spike write-up 可以保留为过程记录，但不能作为当前实现事实源。
- 若 probe 依赖外部包、网络服务、真实 API Key 或本地机器状态，必须写明如何离线复现、如何跳过，以及剩余风险。

同时更新 task plan 模板，要求高风险任务回答：

```text
是否需要 spike / probe / fixture / evidence：
需要时的落点：
是否包含真实用户敏感内容：
如何验证和清理：
```

### 11.4 引入轻量健康趋势记录

不新增 `docs/house-cleaning/`，而是在 `docs/review/` 下引入轻量健康记录，例如 `docs/review/health-ledger.md`。

首批指标建议：

- 当前 active plan 数量。
- 超过 7 天未更新的 active plan 数量。
- `docs/review/INDEX.md` 中 `Deferred`、`Superseded`、`Invalidated` 数量。
- 占位符扫描结果数量。
- `scripts/check-docs.sh` 结果。
- `git diff --check` 结果。
- 可选：超过阈值的超长文档数量，仅报告不阻塞。

记录原则：

- 记录趋势，不把单次快照当作结论。
- 每条发现必须有 verdict：已修、转为 active plan、明确接受、延后原因。
- 指标优先选择可机械采集、方向明确、能指导行动的项目；不记录 raw LOC、总提交数等 vanity metrics。
- 如果采用机器可读记录，必须是 append-only，不就地改写历史条目；若采用 Markdown 表，也必须保留日期、commit、trigger、metrics、verdict 和 notes。
- 任何语义问题仍进入 `docs/plans/active/` 或 `docs/review/rounds/`，不靠 ledger 解决。
- 同一问题连续三次出现且无改善时，必须转为 active plan、review round 或显式接受风险，不能继续只写 ledger。

### 11.5 强化 `scripts/check-docs.sh`

若当前脚本只覆盖基础结构，可补充低争议检查：

- 禁止 tracked `.DS_Store`。
- 检查 `docs/plans/active/*.md` 是否包含状态、类型、创建日期、最后更新日期。
- 检查 `docs/review/INDEX.md` 是否存在最新状态摘要。
- 检查 `docs/workflows/README.md` 和首批 workflow 是否存在。
- 检查占位符扫描继续排除 examples。
- 如新增 health ledger，检查其入口存在并且最新条目包含日期、commit、trigger、verdict 或同等字段；不检查语义对错。

脚本不得做：

- 自动删除文件。
- 自动改写 ADR、spec、review、done plan。
- 根据关键词判断产品或架构语义正确性。

### 11.6 更新文档权威关系和目录职责

需要同步说明：

- 系统地图是当前工程结构入口，不替代 ADR 或 spec。
- spike / probe / fixture 是证据材料，不自动成为产品决策或当前实现事实。
- 故障恢复矩阵是异常路径索引和测试覆盖视图，不替代 spec、bug plan 或 review round。
- health ledger 是趋势记录，不替代 review round 和 task plan。
- VMark 是参考项目，不是 LangoTrace 当前事实源。

### 11.7 验证与收口

实施完成前至少运行：

```bash
find docs -maxdepth 3 -type f | sort
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如修改 `scripts/verify.sh`，还必须运行：

```bash
scripts/verify.sh
```

## 12. 复查方法

复查时应按以下问题逐项确认：

- 新增系统地图是否只描述当前事实和明确标记的未来能力，没有把未完成能力写成已实现。
- 故障恢复矩阵是否覆盖高风险边界，并把未验证异常路径明确标记为 `No`、`Partial` 或 `Manual`。
- spike / probe / fixture / evidence 的落点是否不会与 `plans`、`review`、`testing`、`reference` 职责冲突。
- spike / probe 是否有处置规则，长期 fixture 是否有稳定落点，临时 probes 是否不会成为长期事实源。
- health ledger 是否只是趋势和 verdict 记录，没有成为平行审查体系。
- health ledger 指标是否可机械采集、方向明确、能指导行动，并避免 vanity metrics。
- `docs/plans/done/2026-05-25-docs-dev-docs-workflow-governance.md` 中已完成内容没有被重复实施。
- `docs/workflows/` 仍是动作手册，不成为产品决策源、架构事实源或实现事实源。
- 所有新增规则都能指回权威文档，而不是复制出第二份长期规则。

## 13. 验证命令

计划创建后先运行：

```bash
git diff --check
git status --short
```

后续实施完成前运行：

```bash
find docs -maxdepth 3 -type f | sort
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果接入完整验证：

```bash
scripts/verify.sh
```

## 14. 文档影响检查

本任务本身就是文档体系优化，会影响：

- `docs/architecture/`：新增当前系统地图或强化架构入口。
- `docs/architecture/` / `docs/spec/` / `docs/testing/`：补充故障恢复矩阵入口和异常路径测试覆盖说明。
- `docs/_meta/`：补充 spike / probe / fixture / evidence 和目录职责。
- `docs/review/`：补充健康趋势记录和周期治理落点。
- `docs/testing/`：补充 fixture 归属规则。
- `docs/plans/`：补充任务方案模板中的证据材料判断。
- `docs/reference/`：补充研究 spike 的候选落点。

不影响：

- ADR 中的核心产品 / 架构决策。
- Swift 代码实现。
- XcodeGen 或 package 结构。
- StoreKit、同步、权限和发布规则的具体产品决策。

## 15. 实施记录

- 2026-05-25：创建本 active plan，记录 VMark `dev-docs` 对比审核结果和 LangoTrace `docs/` 优化方案。尚未开始实施长期文档修改。
- 2026-05-25：严格复审本方案，对照 VMark `architecture.md`、`error-recovery.md`、`audit/protocol.md`、`house-cleaning/README.md`、`house-cleaning/ledger.md`、`house-cleaning/findings-template.md` 和 `grills/gha-workflow/README.md`，补充故障恢复矩阵、spike / probe 处置、health ledger 指标边界和 verdict 规则。仍未开始实施长期文档修改。
- 2026-05-25：按用户确认开始实施。新增 `docs/architecture/002-system-map.md`，记录当前系统形态、App / Package 入口点、关键运行时对象、关键数据流、依赖方向、禁止反向依赖、故障恢复矩阵和验证入口；矩阵首批覆盖启动恢复、语言空间 fallback、GRDB、AI Provider、Keychain、Provider probe、学习材料生成、TTS、media artifact、未来 Sync / 权限 / 导出 / StoreKit。
- 2026-05-25：新增 `docs/reference/research/spikes/README.md`，明确 spike / probe / fixture / evidence 的定义、落点、清理规则、敏感内容禁区和与 plans / review / testing / scripts 的关系。
- 2026-05-25：新增 `docs/review/health-ledger.md`，建立首条 baseline，记录 active plan 数量、过期 active plan、Deferred / Superseded / Invalidated review rows、占位符扫描和 tracked `.DS_Store` 指标。
- 2026-05-25：同步更新 `docs/README.md`、`docs/architecture/README.md`、`docs/_meta/documentation-system.md`、`docs/_meta/directory-responsibilities.md`、`docs/review/README.md`、`docs/plans/README.md`、`docs/plans/examples/task-plan-template.md`、`docs/reference/README.md` 和 `docs/testing/README.md`，把系统地图、故障恢复矩阵、spike / probe / fixture / evidence、health ledger 的权威边界写回长期入口。
- 2026-05-25：强化 `scripts/check-docs.sh`，新增 tracked `.DS_Store`、workflow 文件、系统地图、spike 研究入口、health ledger、review index 最新状态摘要和 active plan 基础字段检查；脚本仍只做结构性检查，不做产品或架构语义判断。
- 2026-05-25：完成文档验证：`find docs -maxdepth 4 -type f | sort` 可列出新增系统地图、spike 研究入口和 health ledger；`scripts/check-docs.sh` 输出 `check-docs: ok`；占位符扫描无输出；`git diff --check` 无输出；`git status --short` 显示本次 docs 和 `scripts/check-docs.sh` 修改，以及新增文件通过 intent-to-add 纳入 diff 检查但未暂存内容。
- 2026-05-25：复查确认完成标准已满足，将方案从 `docs/plans/active/` 移入 `docs/plans/done/`，作为本次文档体系优化的完成记录。

## 16. 完成标准

本任务可以从 `active/` 移入 `done/` 的条件：

- 本方案经用户确认实施范围。
- 系统地图、证据材料落点、健康趋势记录和任务模板补充至少完成其中用户批准的部分。
- 若用户批准吸收 VMark 故障恢复矩阵，至少完成系统地图中的矩阵索引，并为已实现的启动、数据、AI Provider、TTS 和媒体派生资产路径标注测试状态。
- 若用户批准吸收 VMark spike / probe 机制，至少完成任务模板中的证据材料判断和处置规则。
- 若用户批准吸收 VMark health ledger 机制，至少完成首条 baseline 记录或明确采用 Markdown / JSON 的原因。
- 所有修改后的文档权威关系清楚，没有新增平行事实源。
- 文档检查命令通过，或无法运行项已记录原因和剩余风险。
- 实施记录写明实际修改文件、验证命令和结果。
- 若新增或修改长期规则，入口文档或相关索引已经同步。

## 17. 剩余风险

- 如果系统地图维护成本过高，可能再次变成过期事实源；需要通过代码快照、最后核对时间和 review 触发规则降低风险。
- 如果 spike / fixture 规则过细，可能增加早期开发负担；应只对高风险任务强制，普通文案和轻量 UI 调整不强制。
- 如果 health ledger 指标过多，可能变成无效仪表盘；首版应只记录少量高信号指标。
- VMark 的机制来自 Markdown 编辑器和 Tauri / React / MCP 工程，不能直接套用到 SwiftUI Multiplatform、Keychain、GRDB、StoreKit 和本地优先隐私边界。
