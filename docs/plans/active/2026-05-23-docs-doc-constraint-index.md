# 文档约束索引与任务方案模板优化方案

状态：Draft
类型：docs
创建日期：2026-05-23
最后更新日期：2026-05-25

## 用户确认记录

- 2026-05-22：用户提供外部参考文件 `docs/reference/_constraints_doc.html`，要求先阅读并判断其架构设计是否可借鉴。
- 2026-05-22：经评估确认该文件虽然不属于 LangoTrace 当前事实源，但其“约束结构化、反向溯源、执行路径、适用范围和倒排索引”设计可以借鉴，用于优化 LangoTrace 文档治理。
- 2026-05-23：用户在创建正式方案前追问现有需求开发和 bug 修复方案模板是否已有固定章节、是否合理全面，以及外部 HTML 是否能反向优化模板。
- 2026-05-23：评估结论为：现有 `docs/plans/README.md` 和 `docs/plans/examples/task-plan-template.md` 已经可用，但偏人工写作模板，缺少 constraint-style 的结构化约束映射；同时发现 `docs/plans/README.md` 已允许 `docs` 类型，而 `docs/_meta/documentation-system.md` 的任务类型清单仍缺少 `docs`。
- 2026-05-23：用户确认采纳上述优化方向，并要求立即完成本方案文档。本方案仍处于 Draft；实施前需要用户确认具体修改范围。
- 2026-05-23：系统架构复查确认本任务不涉及 Swift 源码实现，代码现状描述为“无代码文件路径”准确；但要求收紧首批约束索引范围，避免把隐私、存储、AI 等领域规范复制成 `_meta` 下的第二事实源，并要求使用文档体系变更的更严格验证命令。
- 2026-05-25：用户要求站在系统架构师角度，基于项目定位和愿景，对方案问题深入思考并推荐最优方案；确认采纳“轻量文档约束路由索引 + 任务方案内具体约束执行”的设计，并要求立即更新本方案。

## 1. 需求或 bug 描述

当前 LangoTrace 的任务方案模板已经能覆盖需求、现状、目标、范围、证据、实施、验证和收口，但它更适合人工阅读，不够适合后续 AI 会话稳定地提取“哪些约束必须遵守、约束从哪里来、作用到哪里、如何验证、违反后是否阻塞”。

外部参考文件 `docs/reference/_constraints_doc.html` 提供了一套将约束结构化的设计：每条 constraint 有 `kind`、`source`、`applies_to`、`enforced_by`、`severity` 和 `verification_hint`，并按消费位置分流。LangoTrace 不应照搬该外部系统，但可以吸收它的轻量结构化思想，优化任务方案模板和文档治理入口。

本任务要完成三件事：

1. 修正计划类型规则中的当前文档漂移。
2. 增强任务方案模板，使后续 feature / bug / refactor / docs 方案显式记录约束映射和验证路径。
3. 建立一份轻量文档约束路由索引，用于指向 LangoTrace 已经存在、需要高频遵守的文档治理约束来源，而不是创造新的产品、架构或领域事实源。

## 2. 现状描述

当前固定模板和规则：

- `docs/plans/README.md` 规定所有任务方案必须包含标题、状态、类型、创建日期、最后更新日期、用户确认、需求或 bug 描述、现状、目标、范围、不做什么、证据与决策依据、涉及代码路径、参考代码路径、涉及文档路径、实施方案、复查方法、验证命令、文档影响检查、实施记录、完成标准和剩余风险。
- `docs/plans/examples/task-plan-template.md` 提供 17 个章节的模板。
- bug 方案必须补充复现方式、预期行为、实际行为、根因分析、置信度、置信度依据、备选原因和回归测试方案。
- `docs/review/README.md` 已经定义日常文档影响检查、事件触发专项审查、里程碑轻量全审和保守文档自进化。

已发现的问题：

- `docs/plans/README.md` 的允许类型包括 `docs`，但 `docs/_meta/documentation-system.md` 的任务方案类型清单缺少 `docs`。
- 模板要求“证据与决策依据”和“验证命令”，但没有要求把核心约束写成可复查、可溯源、可执行的约束块。
- 模板没有明确要求写出 TDD 落点、先失败用例、聚焦测试命令、完整验证命令，以及不新增单元测试时的原因和剩余风险。
- 模板没有区分约束的 `source`、`scope`、`severity` 和 `enforced_by`，导致复杂方案中约束容易散落在正文段落里。
- 现有 `docs/reference/` 规则已明确外部参考不是产品决策源、架构事实源或实现事实源；因此 `docs/reference/_constraints_doc.html` 只能作为参考输入，不能直接升级为 LangoTrace 规范。

## 3. 目标

本任务完成后必须达到：

- `docs/plans/README.md` 与 `docs/_meta/documentation-system.md` 对任务类型的口径一致，均明确 `docs` 是允许类型。
- `docs/plans/README.md` 的必填内容新增或细化以下能力：
  - 约束映射与验证路径。
  - TDD / 测试落点。
  - 专项审查触发判断。
  - 如果不新增单元测试，必须说明原因和剩余风险。
- `docs/plans/examples/task-plan-template.md` 增加一套可直接填写的“约束映射与验证路径”章节或子章节。
- 新增轻量文档约束路由索引，推荐落点为 `docs/_meta/documentation-constraints.md`，只收录已经存在于 `docs/README.md`、`docs/plans/README.md`、`docs/review/README.md`、`docs/_meta/documentation-system.md`、`docs/reference/README.md`、核心 spec 和 ADR 中的高价值治理规则与领域检查入口。
- 新索引采用 Markdown，不引入 JSON / YAML / 代码生成 pipeline；索引主格式采用“短摘要表 + 每条约束段落块”，避免长字段破坏 Markdown 表格。
- 每条约束至少包含：`id`、`kind`、`status`、`source`、`statement`、`scope`、`severity`、`enforced_by`、`verification_hint`、`conflict_handling`，必要时包含 `superseded_by`。
- 首批索引优先收录文档治理、任务方案、review、reference 权威边界和验证入口等跨任务治理约束；隐私、存储、AI Provider 等领域规则只收录“应回到哪个权威文档检查”的触发型路由约束，不复制具体领域规则正文。
- 新索引明确它不是新的产品决策源、架构事实源、执行裁决源或领域规范源；如果索引内容与原始 spec / ADR / product reference / review 机制冲突，以原始权威文档为准，并把冲突作为文档治理问题处理。
- 完成文档门禁验证，并记录验证结果。

## 4. 范围

本任务覆盖：

- 任务方案规则和模板优化。
- 文档体系规范中任务类型清单的口径修正。
- 新增轻量文档约束路由索引。
- 必要时更新 `docs/_meta/directory-responsibilities.md`，登记新增 `_meta` 文档职责。
- 必要时更新 `docs/README.md` 或 `docs/review/README.md` 的读取路径，但只在新增约束索引需要入口发现时进行。
- 文档-only 验证。

## 5. 不做什么

本任务不做：

- 不修改 Swift 源码、XcodeGen 配置、Package 文件或测试代码。
- 不新增自动扫描脚本。
- 不引入 `constraints.json`、`by_module` 生成器、audit_v2 或多变体 codegen。
- 不把 `docs/reference/_constraints_doc.html` 升级为 LangoTrace 当前事实源。
- 不创建新的产品决策、AI Provider 决策、数据同步决策、隐私决策或 StoreKit 决策。
- 不把 `_meta` 约束索引升级为全局规则库、事实源或自动裁决系统。
- 不在索引中复制 AI Provider、Keychain、SQLite schema、同步冲突、StoreKit 等领域规则正文；这些规则仍由对应 spec / ADR / review 机制承载。
- 不改写历史 `docs/plans/done/`、`docs/review/rounds/` 或 `docs/archive/` 正文。
- 不删除任何历史记录或外部参考文件。
- 不把 LLM 推断出的规则直接设为 blocker；只有已经被 LangoTrace 权威文档或用户明确确认的规则才能进入强约束。

## 6. 证据与决策依据

文档依据：

- `docs/plans/README.md`：当前任务方案规则和必填内容来源。
- `docs/plans/examples/task-plan-template.md`：当前模板来源。
- `docs/_meta/documentation-system.md`：文档体系分层、任务方案职责和允许类型来源。
- `docs/review/README.md`：文档审查机制、保守文档自进化、问题分流和专项审查触发来源。
- `docs/reference/README.md`：外部参考不是产品决策源、架构事实源或实现事实源。
- `docs/reference/_constraints_doc.html`：外部 constraint 结构化设计参考。
- `docs/README.md`：当前 AGENTS / AI_ENTRY_POINT / CLAUDE 入口事实源，包含 active plan、TDD、专项文档影响检查和高风险变更规则。

参考设计中可吸收的点：

| 外部设计点 | 可吸收方式 | 不吸收的部分 |
| --- | --- | --- |
| `source` 反向溯源 | 要求模板记录约束来源路径 | 不自动从文档生成约束 |
| `applies_to` 适用范围 | 在模板中记录约束影响的模块、平台或文档域 | 不建立复杂倒排索引脚本 |
| `enforced_by` 验证机制 | 明确验证是单元测试、脚本、人工审查还是专项 review | 不实现 audit_v2 |
| `severity` 阻塞等级 | 用 blocker / warn 或 P0-P3 标注违反后的处理方式 | 不把推断规则自动设为 blocker |
| `verification_hint` | 给后续 AI 写清如何验证 | 不要求每条规则都有机器可验证脚本 |

关键判断：

- 现有模板不是错误模板，而是需要增强。
- 本轮适合做 Markdown 级增强，不适合做可执行 constraint pipeline。
- 新索引应只承载“已有权威规则的路由索引”，不能成为凌驾于 ADR、spec、product reference 或 review 机制之上的新权威层。

### 6.1 系统架构复查结论

代码现状准确性：

- 本任务为文档治理任务，不涉及 Swift 源码、Package、XcodeGen、App runtime、数据库 schema 或测试 target 的生产代码修改。
- 因此“涉及的代码文件路径：无”和“不运行 `scripts/verify.sh` 的默认理由”在方向上成立。
- 但本任务会改变文档体系规则和模板，属于 `docs/_meta/` 和 `docs/plans/` 的受保护文档变更，验证命令应按文档体系变更而不是普通纯文档修正处理。

架构可行性：

- 新增 `docs/_meta/documentation-constraints.md` 可行，但它必须被定义为“约束路由索引 / governance router”，不是新的领域事实源或执行裁决源。
- `_meta` 目录本身是受保护规则目录；如果索引放在 `_meta`，必须在文件头和目录职责中明确：索引只引用原始权威文档，不能用来覆盖 ADR、spec、product reference、architecture 或 review 机制。
- 首批索引不应追求覆盖隐私、存储、AI Provider 等领域细节，否则会把领域规范复制成第二份规则源，增加未来漂移风险。

需要收紧的设计：

- 首批约束数量从“20 到 40 条”收紧为“10 到 16 条”，优先覆盖高频治理规则和跨任务触发器。
- `severity` 使用受控枚举 `blocker / warn / info`，表示违反该索引项时对执行流程的影响；`P0 / P1 / P2 / P3` 继续只用于 `docs/review/README.md` 的治理问题严重度，避免混用两套语义。
- `blocker` 只能来自明确写有“必须 / 不得 / 强制”等执行要求的权威文档，例如 `docs/README.md`、ADR、spec 或 review 机制；来自 reference、done plan、历史 review、外部 HTML 或 AI 推断的内容默认只能是 `warn` 或 `info`，除非已经被提升到当前权威文档。
- 每条约束的 `source` 必须是具体文档路径，推荐写到章节或标题；没有明确来源的内容不能进入首批索引。
- 文档约束索引可以记录“AI Provider 变更必须回到 `docs/spec/005...` 和 `docs/review/README.md` 检查”，但不应在索引中重写 AI 请求正文、Keychain 规则或日志脱敏细节。
- 每条约束必须有生命周期状态：`active`、`superseded`、`invalidated` 或 `needs-review`。源文档变更后若无法立即确认索引仍有效，应降级为 `needs-review`，不能继续作为 blocker 使用。

## 7. 涉及的代码文件路径

无，文档-only 任务。

## 8. 参考的代码文件路径

无。

## 9. 涉及的文档路径

预计修改：

- `docs/plans/README.md`
- `docs/plans/examples/task-plan-template.md`
- `docs/_meta/documentation-system.md`
- `docs/_meta/documentation-constraints.md`

可能修改，视实施时入口完整性决定：

- `docs/_meta/directory-responsibilities.md`
- `docs/README.md`
- `docs/review/README.md`

只读参考：

- `docs/reference/README.md`
- `docs/reference/_constraints_doc.html`
- `docs/spec/001-guideline-governance.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### 11.1 查重与权威边界确认

1. 重新搜索 `docs/plans/active/`、`docs/plans/done/` 和 `docs/review/INDEX.md`，确认没有正在处理同一模板优化或约束索引任务的 active plan。
2. 重新确认 `docs/reference/README.md` 中 reference 的权威边界，避免把外部 HTML 当作 LangoTrace 事实源。
3. 记录本任务只增强文档治理表达，不改变产品、架构、隐私、同步或付费决策。

### 11.2 修正任务类型口径漂移

1. 更新 `docs/_meta/documentation-system.md` 的任务方案允许类型清单，补充 `docs`。
2. 检查 `docs/plans/README.md`、`docs/plans/examples/task-plan-template.md` 和 `_meta` 之间的类型列表一致性。
3. 不改动已完成 plan 的历史正文。

### 11.3 增强任务方案规则

更新 `docs/plans/README.md`：

- 在“必填内容”中新增“约束映射与验证路径”。
- 在“必填内容”中新增“TDD / 测试落点”。
- 在“使用规则”中明确：如果任务涉及新功能、bug 修复、架构调整或行为变化，方案必须写明先失败测试、聚焦验证命令和完整验证命令；如果不新增单元测试，必须说明原因与剩余风险。
- 在“使用规则”中明确：约束映射只记录已经有来源的规则，不允许把参考项目或 AI 推断直接升级为 blocker。

### 11.4 增强任务方案模板

更新 `docs/plans/examples/task-plan-template.md`：

- 在“证据与决策依据”之后增加“约束映射与验证路径”章节。
- 使用可重复的段落块作为默认填写格式，避免 AI 或人工维护长文本时破坏 Markdown 表格列数：

```text
### 约束 1：<短标题>

- 来源：<文档路径，可写到章节或标题>
- 适用范围：<全局 / 模块 / 平台 / 文档域>
- 严重度：blocker / warn / info
- 执行或验证方式：<单元测试 / 脚本 / 人工审查 / 专项 review / 不适用>
- 验证提示：<后续实施者如何确认该约束被满足>
- 说明：<为什么这条约束属于本任务；没有补充说明时写“无”>
```

如果任务包含大量约束，可在段落块之前增加短摘要表，但摘要表不能替代上述段落块；长文本、路径和验证提示以段落块为准。

- 在“验证命令”前增加“TDD / 测试落点”章节，字段包括：
  - 测试落点。
  - 先失败用例。
  - 完整验证命令。
  - 不新增单元测试的原因。
  - 剩余风险。
- 保持模板仍是 Markdown 文档，不引入 frontmatter 或机器生成格式。

### 11.5 新增轻量文档约束路由索引

新增 `docs/_meta/documentation-constraints.md`，建议结构：

```text
# 文档约束路由索引

状态：Accepted
最后更新：YYYY-MM-DD

## 1. 用途
## 2. 权威边界
## 3. 字段说明
## 4. 约束分类
## 5. 约束索引
## 6. 使用方式
## 7. 维护规则
```

文件定位必须写清：

- 本文件是约束路由索引，只帮助后续 AI / 人类开发者快速找到应检查的权威文档。
- 本文件不是产品决策源、架构事实源、执行裁决源或领域规范源。
- 具体任务命中的约束、验证方式、阻塞判断和例外说明，必须写回对应 `docs/plans/active/*.md` 的“约束映射与验证路径”章节。
- 如果本文件与原始权威文档冲突，以原始权威文档为准，并把冲突作为文档治理问题处理。

首批只收录高价值、已有明确来源的规则，建议控制在 10 到 16 条，不追求全量。第一版优先覆盖文档治理和跨任务触发器，不复制领域规范正文。初始分类建议：

- `plan_gate`：哪些任务必须先建 active plan。
- `approval_gate`：哪些变更必须用户确认或 ADR 复审。
- `test_gate`：TDD、聚焦测试和完整验证规则。
- `doc_impact`：哪些变更触发文档影响检查或专项审查。
- `authority_boundary`：reference、done plan、review round、ADR、spec 等文档权威关系。
- `domain_trigger`：AI、隐私、存储、同步、权限、StoreKit 等领域任务应回到哪些权威文档检查；只写触发和路由，不复制领域规则正文。

每条约束采用“短摘要表 + 段落块”记录。摘要表只放短字段：

```text
| ID | Kind | Status | Severity | Source |
| --- | --- | --- | --- | --- |
```

长字段必须写在约束段落块中：

```text
### DOC-CONST-001：<短标题>

- 状态：active / superseded / invalidated / needs-review
- 来源：<原始权威文档路径，可写到章节或标题>
- 适用范围：<全局 / 模块 / 平台 / 文档域>
- 规则摘要：<只摘要原始规则，不扩写领域规则正文>
- 执行或验证方式：<单元测试 / 脚本 / 人工审查 / 专项 review / 不适用>
- 验证提示：<后续实施者如何确认该约束被满足>
- 冲突处理：<与原始文档冲突时如何处理>
- 替代关系：<无 / superseded_by: DOC-CONST-xxx>
```

命名建议：

- `DOC-CONST-001` 起步。
- 只用稳定编号，不因排序调整重编号。
- `severity` 只使用 `blocker`、`warn`、`info`。
- `status` 只使用 `active`、`superseded`、`invalidated`、`needs-review`。
- `source` 必须是具体文档路径；实施时优先写到章节名或标题。
- 无明确来源、只来自外部参考或 AI 推断的内容不得进入首批索引。
- `blocker` 只能来自当前权威文档中的明确强制规则；来自 reference、done plan、历史 review、外部 HTML 或 AI 推断的内容不得直接设为 `blocker`。
- 如果用户未确认本方案，不创建该文件；一旦按本方案实施创建，文件状态应直接写为 `Accepted`，不要保留二选一状态占位。

### 11.6 更新入口发现路径

如果新增 `docs/_meta/documentation-constraints.md` 后没有入口能发现它，则执行：

- 在 `docs/_meta/directory-responsibilities.md` 登记该文件职责。
- 在 `docs/review/README.md` 或 `docs/README.md` 中加入轻量引用，说明它是约束索引，不是新事实源。

入口更新必须克制，避免把根入口变成长篇规则集合。

### 11.7 自检与收口

1. 检查新模板没有未完成占位标记。
2. 检查新增约束没有把外部参考或 AI 推断当成 LangoTrace 强约束。
3. 检查 `docs/plans/README.md` 与模板章节一致。
4. 检查 `_meta` 的类型清单包含 `docs`。
5. 检查每条 `DOC-CONST-*` 都有明确 source、status、severity、验证提示和冲突处理。
6. 检查新索引中没有复制 AI、隐私、存储、同步、StoreKit 等领域规则正文，只保留触发和路由。
7. 运行文档验证命令。
8. 在本方案“实施记录”中记录实际修改、验证命令和结果。
9. 验证通过后，将本方案移入 `docs/plans/done/` 并更新状态。

## 12. 复查方法

- 对照 `docs/plans/README.md` 和 `docs/plans/examples/task-plan-template.md`，确认新增章节在规则和模板中都有对应。
- 对照 `docs/_meta/documentation-system.md`，确认允许类型包含 `docs`。
- 对照 `docs/reference/README.md`，确认新增约束索引没有把 reference 变成事实源。
- 对照 `docs/review/README.md`，确认新增约束索引没有绕过保守文档自进化和用户确认边界。
- 抽样检查首批约束，每条都必须能回到明确 source，并且只作路由，不作裁决。
- 检查首批约束的 `blocker` 项是否均来自当前权威文档中的明确强制规则。
- 检查首批约束的生命周期状态是否完整；源文档状态不明的约束必须标记 `needs-review`。
- 搜索 `constraints.json`、`audit_v2`、`variant` 等词，确认本任务没有引入外部系统实现承诺。

## 13. 验证命令

```bash
# 结构列举，人工确认新增文件落点和历史目录没有异常恢复。
find docs -maxdepth 4 -type f | sort

# 应无命中：已退出或旧目录引用不应出现在当前文档中。
if rg "docs/guidelines|guidelines/" docs --glob '!plans/done/*' --glob '!archive/*'; then exit 1; fi
if rg "docs/superpowers|superpowers/" docs --glob '!plans/done/*' --glob '!archive/*'; then exit 1; fi
if rg "docs/worklogs|worklogs/" docs --glob '!plans/done/*' --glob '!archive/*'; then exit 1; fi
if rg "docs/resear[ch]|research/open-source-reference[s]" docs --glob '!plans/done/*'; then exit 1; fi

# 应无命中：新增长期规则文档不应引入外部 constraint pipeline 承诺。
if rg -n "constraints\\.json|audit_v2|variant-trigger|variant scatter|by_module" docs/_meta docs/README.md docs/review/README.md docs/plans/README.md docs/plans/examples/task-plan-template.md; then exit 1; fi

# 应无命中：占位词不应出现在当前 docs，模板和示例除外。
if rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'; then exit 1; fi

# 应有命中：任务类型口径应同时包含 docs。
rg -n "feature / bug / refactor / research / chore / docs|`docs`" docs/_meta/documentation-system.md docs/plans/README.md docs/plans/examples/task-plan-template.md

# 应有命中：新索引必须声明自身只作路由，不作事实源或裁决源。
rg -n "约束路由索引|不是产品决策源|不是.*事实源|不是.*裁决源|以原始权威文档为准" docs/_meta/documentation-constraints.md

# 应有命中：首批约束必须带 lifecycle 和冲突处理字段。
rg -n "状态：active|状态：superseded|状态：invalidated|状态：needs-review|冲突处理|替代关系" docs/_meta/documentation-constraints.md

git diff --check
git status --short
```

本任务默认不运行 `scripts/verify.sh`，原因是文档-only 任务，不修改 Swift 源码、工程配置、Package、资源或验证脚本。如果实施过程中修改了脚本或 Swift 工程相关文档导致验证入口变化，应重新评估是否运行完整 `scripts/verify.sh`。

## 14. 文档影响检查

本任务直接影响文档治理规则和模板，属于 `docs` 类型治理任务。

预期影响：

- `docs/plans/README.md`：任务方案必填字段和使用规则增强。
- `docs/plans/examples/task-plan-template.md`：模板章节增强。
- `docs/_meta/documentation-system.md`：任务类型清单修正。
- `docs/_meta/documentation-constraints.md`：新增约束路由索引。

可能影响：

- `docs/_meta/directory-responsibilities.md`：新增 `_meta` 文件职责登记。
- `docs/README.md` 或 `docs/review/README.md`：新增轻量入口引用。

不需要 ADR，原因是本任务不改变产品核心模型、技术路线、隐私边界、同步路线、StoreKit 策略或 Apple 三端首发决策。

不创建 `docs/review/rounds/` 专项审查，原因是本任务本身是文档治理 active plan；若实施中发现现有事实源与代码或核心决策冲突，再按 `docs/review/README.md` 触发专项审查。

## 15. 实施记录

- 2026-05-23：创建本 active plan，记录外部 constraint 设计可吸收点、现有模板缺口、实施范围和验证方式。尚未修改长期规则文档。
- 2026-05-23：完成系统架构复查并写回方案：确认无 Swift 代码修改边界准确；初步收紧首批约束索引范围；明确 `_meta` 索引不得复制领域规范正文；统一 `severity` 语义；补充文档体系变更验证命令。
- 2026-05-25：根据系统架构审核后的推荐方案更新本 active plan：将新增文件定位从“约束索引”收窄为“约束路由索引 / governance router”；首批范围收紧为 10 到 16 条；索引格式改为短摘要表加段落块；补充 `status` 生命周期、`blocker` 来源限制、冲突处理、替代关系和可判定验证命令。

## 16. 完成标准

- 用户确认本方案可实施。
- `docs/_meta/documentation-system.md` 与 `docs/plans/README.md` 的任务类型口径一致。
- `docs/plans/README.md` 已新增约束映射、TDD / 测试落点和不新增测试说明要求。
- `docs/plans/examples/task-plan-template.md` 已提供可直接填写的约束映射与验证路径模板。
- `docs/_meta/documentation-constraints.md` 已创建，且首批约束均有明确来源、生命周期状态、验证提示、冲突处理和替代关系字段。
- 新增索引明确只作路由，不替代 ADR、spec、product reference、review 和 plan 的权威关系。
- 新增索引没有复制 AI、隐私、存储、同步、StoreKit 等领域规则正文；领域项只保留触发条件和权威文档路径。
- 已运行文档验证命令并记录结果。
- 本方案已移入 `docs/plans/done/`，状态为 `Verified` 或 `Done`。

## 17. 剩余风险

- Markdown 约束路由索引仍依赖人工维护，短期内不能保证自动发现所有文档漂移。
- 如果首批约束收录过多，后续维护成本会上升；本轮应优先收录高频、高风险、来源清晰的治理规则和领域触发器。
- 如果首批约束写得过硬，可能误把参考输入或阶段性建议升级为 blocker；实施时必须逐条核对 source。
- 如果源文档后续更新但索引未同步，约束可能过期；因此每条约束必须带生命周期状态，源文档状态不明时降级为 `needs-review`。
- 任务方案模板增强后，后续方案会更完整，但也会更长；实施时需要保持字段有用，不把模板变成形式主义清单。
