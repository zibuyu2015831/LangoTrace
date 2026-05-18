# 任务方案：保守文档自进化机制

状态：Verified
类型：docs
创建日期：2026-05-18
最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户提出希望文档体系具备“自进化”能力：当发现模板内容不完整、规范文档需要更新、无用历史数据需要清理、文档谬误等问题时，AI 应主动向用户汇报，深入思考必要性和可行性，并提出优化方案和实现方案。
- 2026-05-18：用户询问 review 类文档在代码或文档完善后是否失去作用、是否需要删除。
- 2026-05-18：已在会话中形成“保守自进化”方案：主动发现和提出方案强制执行；实际修改长期规则、删除历史记录或改变文档权威关系仍需用户确认。用户确认“同意‘保守自进化’的方案，立即创建方案文档”。
- 2026-05-18：用户补充要求：本方案创建后仍需用户审核，审核通过后才能实施。因此当前状态保持 `Draft`，不得开始修改长期规则文档。
- 2026-05-18：用户要求“根据本方案，制定具体实施计划，将该方案的内容完整落地”，视为批准将本方案从 Draft 进入实施并完成收口。

## 1. 需求或 bug 描述

当前 LangoTrace 文档体系已经具备入口文档、任务方案、规范文档、测试文档和 review round。但现有机制更多强调“被动一致性检查”：当任务触发审查时，AI 会核对文档与代码是否一致。

用户希望进一步增强文档体系的主动治理能力：AI 在开发、审查或阅读文档时，如果发现文档体系自身存在结构性问题，应主动报告用户，并给出证据、影响、必要性、可行性、风险和实施方案，而不是只在当前任务范围内绕过问题。

典型问题包括：

- 模板内容不完整，导致后续任务反复漏写关键字段。
- 规范文档需要更新，已有代码、决策或验证方式已经超出旧规范。
- 无用历史数据需要清理，例如重复草稿、临时扫描产物、已迁移但未标记的旧目录。
- 文档谬误，例如把计划写成事实、把 mock 写成真实能力、把局部实现写成完整实现。
- review 记录、计划记录、审查报告在问题修复后如何保留、降权、归档或删除。

## 2. 现状描述

现有文档治理基础：

- `docs/README.md` 要求形成重要判断时写回对应文档，并在完成前运行文档检查。
- `docs/review/README.md` 已定义文档审查目标、文档分级、断言依据、日常影响检查、专项审查和里程碑轻量全审。
- `docs/plans/README.md` 已定义任务方案生命周期，要求重要文档体系变化先进入 `docs/plans/active/`。
- `docs/spec/009-testing-and-verification.md` 已定义验证入口和完成声明前的验证要求。
- `docs/review/rounds/2026-05-18-development-doc-system-audit/` 已完成一次文档体系与 spec 深审，确认 review round 保留审计价值。

当前缺口：

- 入口文档尚未明确要求 AI 对“文档体系自身问题”主动汇报。
- review 机制尚未明确“文档自进化触发器”和对应处理流程。
- review round 的生命周期还缺少 `Superseded`、保留、降权、归档、删除的规则。
- 历史文档清理尚未明确优先归档、索引降权还是删除。
- 模板缺陷和文档谬误尚未被明确列为可主动提出的文档治理问题。
- 文档自进化问题尚未区分严重度，后续 AI 容易把轻微措辞问题升级成治理任务，或漏掉隐私、数据、同步、付费等高风险偏差。
- review round 的“过时”语义还不够精细：问题已修复、结论被后续推翻、仅作为历史证据保留，三者需要不同状态和索引说明。
- 治理任务缺少去重规则，多个 AI 会话可能围绕同一模板缺陷、规范过期或历史索引问题重复创建 active plan。
- 当前事实源位置缺少统一标注方式，后续 AI 检索到旧 review 后可能不知道应转读哪份 spec、architecture、plan 或代码入口。

## 3. 目标

本任务完成后，应达到以下结果：

- AI 在发现文档体系问题时，有明确规则要求主动汇报，而不是静默绕过。
- 主动汇报必须包含证据、影响范围、必要性、可行性、风险和推荐实施方案。
- 明确哪些情况可以建议直接修，哪些必须等待用户确认。
- 明确 review round、审查报告和任务方案在问题修复后的保留价值，不把它们误删。
- 明确历史文档清理的优先级：当前事实修正优先于历史记录重写；归档和索引降权优先于删除。
- 形成可供后续 AI 会话执行的保守自进化流程。
- 建立文档治理问题严重度分级，避免低价值噪音压过真正的系统性风险。
- 建立问题分流矩阵，区分当前事实错误、规范过期、ADR 冲突、实现偏离决策、历史记录过时、模板缺陷和缺少新规则等不同处理路径。
- 建立 review 记录失效、覆盖和降权的索引字段，让后续会话能判断某份 review 是否仍可作为依据。
- 建立治理任务去重规则，优先复用现有 active plan，避免重复记录和重复执行。

## 4. 范围

预计修改：

- `docs/README.md`
- `docs/review/README.md`
- `docs/plans/README.md`
- `docs/review/INDEX.md`
- 可能新增 `docs/review/rounds/README.md` 的补充规则，若现有内容不足以承载 review round 生命周期。

只读参考：

- `docs/_meta/documentation-system.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/review/rounds/2026-05-18-development-doc-system-audit/README.md`
- `docs/plans/done/2026-05-18-docs-development-system-audit.md`

## 5. 不做什么

- 不删除任何历史 review、done plan、archive 或 reference 文档。
- 不把现有 review round 改写成当前事实源。
- 不让 AI 在没有用户确认时自动修改 ADR、产品主参考、核心 spec 或删除历史记录。
- 不引入复杂脚本或自动清理工具；本轮先完善治理规则。
- 不修改 Swift 代码、工程配置、测试脚本或资源文件。
- 不建立自动删除、自动归档或自动改写长期文档的后台机制。
- 不要求每个轻微文案、格式或措辞问题都升级为文档治理任务。
- 不用单一 `Superseded` 状态覆盖所有 review 过时场景；本轮应明确更细的语义，但不批量重写既有 review 正文。

## 6. 证据与决策依据

依据：

- 用户明确要求文档体系具备保守自进化能力。
- `docs/review/README.md` 已定义文档分级：过程记录和审查记录不能被当作当前实现事实反复改写；若历史记录与当前代码不同，应在新的事实源文档或新的审查记录中说明演进结果。
- `docs/plans/README.md` 已要求文档体系变化进入任务方案。
- `docs/spec/009-testing-and-verification.md` 已要求完成声明前有本轮新运行的验证证据。
- 本轮文档体系深审表明，review 文档在问题修复后仍有审计价值：它记录代码快照、证据、当时的问题、修复依据和剩余风险。

关键判断：

- review 类文档不应因为问题已修复而删除；它们不再是当前事实源，但仍是审计记录和决策回溯材料。
- 删除只适用于空目录、误生成文件、重复副本、临时扫描输出，且需要确认没有被索引、任务方案或审查记录引用。
- 文档谬误需要修正当前事实源；历史报告中曾经正确的旧事实可保留，但必须在新的 review README 或报告收口段说明已修复，避免后续检索误判。
- LangoTrace 文档体系是工程控制面，不是普通 wiki；它承载产品北极星、隐私边界、AI 请求边界、数据和同步路线、验证入口和后续 AI 会话恢复能力。
- 保守自进化的核心价值是让 AI 主动发现治理问题并提出证据化方案，而不是给 AI 默认权限去改写决策体系。
- 当前项目仍处于早期，文档规则需要允许演进；但所有影响产品、隐私、数据、同步、付费、发布或核心架构的演进都必须保留确认链路。

### 6.1 文档自进化的架构原则

- 当前事实源优先修正，历史证据优先保留。
- 文档权威关系高于单次任务便利性；不能为了让当前任务顺利而把代码偏差包装成新决策。
- AI 有发现问题、汇报问题和提出方案的义务，但没有默认改写核心规则、删除历史记录或改变权威关系的权限。
- 删除是最后手段；降权、归档、索引标注和补充当前事实源优先。
- 涉及产品北极星、隐私、数据、同步、AI Provider、权限、StoreKit、发布或核心架构边界的文档变化，必须按 ADR、spec、architecture、review 或 task plan 的职责分流。
- 治理任务必须可恢复、可去重、可追溯；后续会话不能只靠聊天上下文理解某个文档为什么存在或为什么降权。

### 6.2 主动汇报严重度

| 等级 | 触发条件 | 默认处理 |
| --- | --- | --- |
| P0 | 误导当前实现、隐私边界、数据持久化、同步、付费、发布、核心产品或 ADR 决策 | 必须主动汇报，并建议创建或更新治理任务；未经用户确认不得改核心规则 |
| P1 | 影响后续开发执行路径、验证命令、模块边界、任务模板、review 生命周期或新会话入口 | 应主动汇报，并给出修复方案和验证方式 |
| P2 | 重复文档、历史索引不清、术语轻微不一致、已修复 review 未降权 | 可汇总汇报，优先追加到已有治理任务 |
| P3 | 风格、排版、轻微措辞、非误导性表达 | 默认不触发治理任务，除非用户要求或它反复造成误判 |

### 6.3 问题分流矩阵

| 问题类型 | 示例 | 推荐落点 |
| --- | --- | --- |
| 当前事实错误 | 文档写真实 AI 已接入，但代码仍是 mock 或 disabled | 修正当前事实源，必要时补 review 记录 |
| 规范过期 | spec 未覆盖已落地的验证方式或模块边界 | 更新对应 `docs/spec/`，若影响核心取舍则触发 ADR 复审 |
| 实现偏离决策 | 代码绕过请求预览、权限说明或本地优先边界 | 新建 bug、refactor 或 review 任务，不直接改文档迁就代码 |
| ADR 或产品决策冲突 | 新方案改变语言空间、买断制、Provider 或同步路线 | 新增或更新 ADR，并记录用户确认 |
| 历史记录过时 | 旧 review 中的问题已被后续 plan 和 commit 修复 | 保留旧记录，在索引或收口段标注当前事实源和覆盖记录 |
| 历史判断失效 | 旧 review 结论基于错误前提，后续确认不成立 | 保留原始记录，但标注结论失效，不再作为依据 |
| 模板缺陷 | plan 或 review 模板缺关键字段，导致反复漏写 | 更新模板或规则文档，并在 active plan 中记录原因 |
| 缺少新规则 | 新实现引入现有体系无法表达的边界，例如 Provider 请求审计或同步冲突 | 新增或扩展 spec、architecture、testing 或 release 文档 |
| 临时或重复文件 | 误生成扫描输出、重复草稿、空目录 | 先确认无引用和无审计价值，再请求用户确认删除 |

## 7. 涉及的代码文件路径

无。本文档任务不修改 Swift 代码。

## 8. 参考的代码文件路径

无。

## 9. 涉及的文档路径

预计修改：

- `docs/README.md`
- `docs/review/README.md`
- `docs/plans/README.md`
- `docs/review/INDEX.md`
- `docs/review/rounds/README.md`

参考：

- `docs/_meta/documentation-system.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/review/rounds/2026-05-18-development-doc-system-audit/README.md`
- `docs/plans/done/2026-05-18-docs-development-system-audit.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

实施前置条件：

- 用户审核本方案并明确批准实施后，才可将状态改为 `User Approved` 或 `In Progress`。
- 在用户批准前，只允许继续修订本方案本身，不修改 `docs/README.md`、`docs/review/README.md`、`docs/plans/README.md`、`docs/review/INDEX.md` 或 `docs/review/rounds/README.md`。

1. 更新 `docs/review/README.md`：
   - 新增“文档自进化触发器”章节。
   - 覆盖模板不完整、规范过期、历史数据清理、文档谬误、review 生命周期问题。
   - 新增“主动汇报格式”：问题、证据、影响、必要性、可行性、风险、推荐方案、需要用户确认的点。
   - 新增“保守执行边界”：AI 可主动报告和提出方案；修改核心规则、删除历史记录、改变权威关系必须等用户确认。
   - 新增主动汇报严重度：P0 / P1 / P2 / P3，明确哪些问题必须立即汇报，哪些可以汇总处理，哪些不应制造治理噪音。
   - 新增问题分流矩阵：当前事实错误、规范过期、实现偏离决策、ADR 冲突、历史记录过时、历史判断失效、模板缺陷、缺少新规则、临时或重复文件。
   - 新增治理任务去重规则：创建新任务前必须搜索 `docs/plans/active/`、`docs/plans/done/` 和 `docs/review/INDEX.md`；已有 active plan 时优先追加，已完成任务复发时新建任务并引用旧记录。
   - 新增删除前置条件：仅允许建议删除误生成、重复、临时、无引用且无审计价值的文件；删除历史记录或影响权威关系必须等待用户确认。

2. 更新 `docs/README.md`：
   - 在使用原则或文档审查路径中补充：AI 发现文档体系问题时，应主动汇报并提出优化方案。
   - 明确该机制不授权 AI 自动删除历史记录或改写核心决策。
   - 明确文档体系是工程控制面，AI 不应为了单次任务便利改写产品、隐私、数据、同步、付费或发布边界。

3. 更新 `docs/plans/README.md`：
   - 明确模板缺陷、文档治理规则变化、历史资料清理、文档谬误修正都属于 `docs` 类型任务。
   - 明确此类任务通常需要先建 `docs/plans/active/` 方案并经用户确认。
   - 补充治理任务去重要求：新建前先查 active、done 和 review index；相同问题优先合并到现有 active plan。

4. 更新 `docs/review/INDEX.md`：
   - 补充 review round 状态含义：`Verified`、`Deferred`、`Superseded`、`Invalidated`。
   - 明确 `Verified` 的 review 仍保留，不作为当前事实源，但作为审计记录。
   - 增加或约定索引字段：`当前事实源`、`后续覆盖记录`、`可作为依据`。
   - 区分“问题已修复型过时”和“判断被推翻型过时”：前者可作为历史证据，后者只能作为历史过程记录。

5. 视现有内容情况更新或新增 `docs/review/rounds/README.md`：
   - 明确 review round 保留、归档、降权和删除规则。
   - 删除规则保持严格：仅限误生成、重复、临时、无引用和无审计价值文件。
   - 明确 review round 正文通常不因后续变化反复改写；当前事实源、覆盖关系和失效说明优先写入索引或新的收口记录。
   - 明确后续工具化只可作为报告器，不能自动删除或自动改写长期文档。

6. 验证并记录结果：
   - 运行文档树检查、占位词扫描、`git diff --check`、状态检查。
   - 如修改链接或新增文档，运行相对链接检查。
   - 将实施记录写回本方案。

### 11.1 实际落地计划

本轮按以下顺序落地：

1. `docs/README.md`：写入保守文档自进化的入口原则和执行边界，确保新会话从总入口即可知道 AI 有主动汇报义务，但没有默认改写核心规则或删除历史记录的权限。
2. `docs/review/README.md`：作为主规则承载文档，写入触发器、主动汇报格式、P0 / P1 / P2 / P3 严重度、问题分流矩阵、执行边界、去重要求和删除前置条件。
3. `docs/plans/README.md`：写入 `docs` 类型治理任务范围、创建前去重规则和用户确认要求，避免重复 active plan。
4. `docs/review/INDEX.md`：扩展索引字段，增加 `当前事实源`、`后续覆盖记录`、`可作为依据`，并说明 `Verified`、`Deferred`、`Superseded`、`Invalidated` 的长期语义。
5. `docs/review/rounds/README.md`：写入 review round 生命周期、保留优先级、删除规则和自动化工具边界。
6. 本方案：记录实施结果、验证命令和剩余风险，随后从 `active/` 移入 `done/`。

## 12. 复查方法

复查时从新 AI 会话视角抽样判断：

- 如果发现模板缺字段，是否能从文档知道需要主动汇报并提出模板修复方案。
- 如果发现 spec 与代码冲突，是否能判断是修文档、修代码、还是触发 ADR / 用户澄清。
- 如果发现旧 review 已被后续修复覆盖，是否知道应保留并在索引中降权，而不是删除。
- 如果发现重复临时文件，是否知道删除前要确认无引用和无审计价值。
- 如果发现文档谬误，是否知道应修当前事实源，并在 review 或任务方案记录修复证据。
- 如果发现旧 review 结论被后续证明错误，是否知道应标注为 `Invalidated` 或历史过程记录，而不是继续作为依据。
- 如果发现新能力超出现有 spec 表达范围，是否知道应提出新增或扩展 spec / architecture / testing / release 文档，而不是只写在任务方案里。
- 如果多个会话发现同一治理问题，是否知道应先查 active plan、done plan 和 review index，避免重复创建任务。
- 如果发现 P3 级风格或措辞问题，是否知道默认不升级为治理任务，避免文档自进化机制制造噪音。

## 13. 验证命令

文档产物完成前至少运行：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如新增或修改 Markdown 链接，运行相对链接检查：

```bash
python3 - <<'PY'
from pathlib import Path
import re, urllib.parse
root = Path('.').resolve()
files = [p for p in Path('docs').rglob('*.md') if p.is_file()]
missing = []
pattern = re.compile(r'\[[^\]]+\]\(([^)]+)\)')
for p in files:
    text = p.read_text(encoding='utf-8')
    for m in pattern.finditer(text):
        raw = m.group(1).strip()
        if not raw or raw.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        target = raw.split('#', 1)[0]
        if not target:
            continue
        target = urllib.parse.unquote(target)
        if target.startswith('<') and target.endswith('>'):
            target = target[1:-1]
        resolved = (p.parent / target).resolve()
        try:
            resolved.relative_to(root)
        except ValueError:
            continue
        if not resolved.exists():
            missing.append((str(p), raw))
if missing:
    for p, raw in missing:
        print(f'{p}: missing link {raw}')
    raise SystemExit(1)
print(f'checked {len(files)} markdown files; missing relative links: 0')
PY
```

本任务不修改 Swift 代码，不运行 `scripts/verify.sh`，除非实施过程中意外触及代码、工程配置或验证脚本。

## 14. 文档影响检查

本任务会影响文档治理规则本身：

- `docs/README.md`：补充 AI 发现文档体系问题时的主动汇报要求。
- `docs/review/README.md`：补充保守自进化触发器、汇报格式、执行边界和 review 生命周期。
- `docs/plans/README.md`：补充文档治理类任务分类和去重规则。
- `docs/review/INDEX.md`：补充 review 状态含义、当前事实源、后续覆盖记录和可作为依据字段。
- `docs/review/rounds/README.md`：可能补充 round 保留、降权、失效标注和删除规则。

本任务不改变产品核心决策、架构 ADR 或 Swift 实现。

## 15. 实施记录

- 2026-05-18：创建 active 任务方案，记录用户确认的“保守自进化”方案、范围、落点和验证方式。
- 2026-05-18：根据用户补充要求，将方案状态保持为 `Draft`，并补充实施前置条件：用户审核通过后才能实施。
- 2026-05-18：根据系统架构视角复审，补充文档自进化架构原则、主动汇报严重度、问题分流矩阵、review 失效语义、当前事实源字段、治理任务去重和删除边界。
- 2026-05-18：收到用户实施要求后，将方案内容落地到 `docs/README.md`、`docs/review/README.md`、`docs/plans/README.md`、`docs/review/INDEX.md` 和 `docs/review/rounds/README.md`。
- 2026-05-18：实施后执行文档树检查，确认 `docs/plans/active/2026-05-18-docs-conservative-document-self-evolution.md` 已移入 `docs/plans/done/2026-05-18-docs-conservative-document-self-evolution.md`。
- 2026-05-18：执行占位词扫描 `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`，无匹配。
- 2026-05-18：执行 `git diff --check`，无 whitespace 报错。
- 2026-05-18：执行相对链接检查，结果为 `checked 92 markdown files; missing relative links: 0`。
- 2026-05-18：执行 `git status --short`，仅显示本轮文档落地改动和方案从 active 到 done 的移动。
- 2026-05-18：按用户要求做全面复查，补充 `docs/review/README.md` 中复杂 round 后续 `Superseded` / `Invalidated` 标注规则，并将常用占位词扫描命令与入口文档保持一致，排除 `plans/examples` 和 `spec/examples`。

## 16. 完成标准

- `docs/review/README.md` 明确保守文档自进化机制。
- `docs/README.md` 明确 AI 发现文档体系问题时的主动汇报要求。
- `docs/plans/README.md` 明确模板缺陷、历史数据清理和文档谬误修正属于 docs 任务。
- `docs/review/README.md` 明确 P0 / P1 / P2 / P3 严重度和问题分流矩阵。
- `docs/plans/README.md` 明确治理任务创建前的去重要求。
- `docs/review/INDEX.md` 或 `docs/review/rounds/README.md` 明确 review round 的保留、降权、归档、失效标注和删除规则。
- review 索引或 round 规则能表达 `当前事实源`、`后续覆盖记录` 和 `可作为依据`。
- 文档检查命令运行并记录结果。
- 本方案完成后从 `active/` 移入 `done/`，状态改为 `Verified`。

## 17. 剩余风险

- 该机制只能提升 AI 主动发现和汇报概率，不能保证每个会话都能自动识别所有文档问题。
- 历史数据清理仍需要人工或用户确认，避免误删有审计价值的记录。
- 后续若需要自动扫描无用文档或链接图谱，应另开工具化任务，不纳入本轮。
- 严重度分级仍依赖执行者判断，后续可能需要通过真实 review round 反向校准。
- `Invalidated`、`Superseded` 和 `Historical Only` 等语义如果写得过细，可能增加维护成本；实施时应优先保证新会话不误用历史结论。
