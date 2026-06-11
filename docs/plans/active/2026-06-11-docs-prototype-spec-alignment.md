# 原型重建后的文档一致性对齐（docs prototype spec alignment）

- 状态：Active
- 自审核状态：Reviewed
- 类型：docs
- 创建日期：2026-06-11
- 最后更新日期：2026-06-11

## 用户确认记录

2026-06-11 用户在会话中明确授权本任务：

> 下面需要根据新版的原型图，检查一下 docs 目录下的文档是否需要更新，特别是【docs/spec】下的规范文档；这些文档和原型图，将用于指导后续的开发和实现。如果更新文档过程中遇到疑问，需要确认或取舍，请站在系统架构师的角度，基于项目的定位和愿景进行充分思考，然后采取最优方案。检查更新时可以忽略【docs/plans】目录，这些是进行中和已完成的方案文档。

授权范围包含：对照 2026-06-11 重建的多端原型检查 `docs/`（不含 `docs/plans/`）一致性，自行决策更新方案。

## 需求描述

`prototypes/` 已于 2026-06-11 重建为按平台分目录的完整原型集（见 `docs/plans/done/2026-06-11-chore-prototype-redesign.md`）。后续开发将以「spec 文档 + 原型」共同作为设计输入，需要确认 docs 体系与新原型一致，并补齐双向连接和目标设计的沉淀落点。

## 现状与检查结论

对 `docs/spec/` 全部规范、`docs/platform-page-inventory.md`、`docs/product-main-reference.md` 第 7-9 节、`docs/technical-framework-roadmap.md` 第 10 节、`docs/_meta/`、`docs/development/`、`docs/architecture/002-system-map.md` 和 `docs/README.md` 做了内容核查：

1. **无过时表述**：docs 中已无旧原型路径引用；spec 002 / 003 / 010 描述的 IA、红线和组件约束与新原型一致（原型即按这些 spec 绘制）。
2. **缺口 A — spec 侧缺少设计基准指针**：`prototypes/README.md` 单向声明 spec 003 / 010 为权威，但 spec 003 没有指回原型基准；后续 UI 开发会读 spec 却不知道存在可对照的目标设计。
3. **缺口 B — 页面清单缺少原型定位说明**：`docs/platform-page-inventory.md` 的「本文档不替代」列表未包含 `prototypes/`，原型与实现事实源的关系只写在原型侧。
4. **缺口 C — 目标设计未沉淀为架构备忘录**：原型中的目标设计（记录时间线筛选、记忆 Tab 体验、听写 / 回译练习方式层级、搜索、macOS 导入导出）及其代码改进方向目前只记录在 done plan（历史记录，不作为后续设计输入），按 CLAUDE.md 第 1 节第 8 条应沉淀到 `docs/architecture/notes/`。
5. **缺口 D — 预存 spec 索引缺漏**：`docs/spec/README.md` 第 2 节核心规范列表止于 011，遗漏已存在并被 review round `2026-06-03-reading-lifecycle-governance` 确认为事实源的 `012-reading-learning-domain.md`（实现地图列表也未列 `learning-content` 以外的新增项，经查 impl 地图四项均在列，仅 012 平铺规范缺失）。

## 目标、范围和不做什么

目标：

1. `docs/spec/003-ui-design-system.md` 新增「静态原型设计基准」小节：指向 `prototypes/index.html`，明确 spec 与原型的权威关系、目标设计标注语义和偏差处理规则；补充变更记录。
2. `docs/spec/README.md` 修复核心规范列表缺漏（补 012），并在 AI 开发使用方式中加入原型基准的使用提示。
3. `docs/platform-page-inventory.md` 在「本文档不替代」列表加入 `prototypes/` 定位说明；补充变更记录。
4. 新增 `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`，沉淀原型目标设计的架构提醒、扩展点和后续任务必须重新决策的问题，并链接既有相关备忘录。

不做什么：

- 不修改 `docs/plans/` 下任何历史方案。
- 不修改 spec 中既有约束的语义；只新增指针、索引和备忘录，不把原型目标设计写成当前 spec 强制规则。
- 不修改 ADR、product-main-reference、technical-framework-roadmap（核查无需更新）。
- 不修改任何代码或原型文件。

## 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/spec/README.md`
- `docs/platform-page-inventory.md`
- `docs/architecture/notes/2026-06-11-prototype-target-design-extension-notes.md`（新增）
- 本方案（完成后移入 `docs/plans/done/`）

## 实施方案

1. **阶段 1**：创建本方案并自审核，commit。
2. **阶段 2**：按目标 1-4 更新 / 新增文档，跑文档检查，commit。
3. **阶段 3**：本方案补实施记录并移入 done，commit。

## 严格方案自审核记录

按 `docs/plans/plan-review-protocol.md` 自审核，确认的问题与修订：

1. **问题**：把原型目标设计直接写进 spec 会把未实现能力包装成当前开发约束，违反 spec 职责（开发一致性规范记录当前约束）。**修订**：spec 003 只新增「设计基准指针 + 权威关系」，目标设计细节沉淀到 `docs/architecture/notes/`（非权威设计输入），符合备忘录目录创建条件第 1、5 条。
2. **问题**：新备忘录可能与既有备忘录（词典、练习录音同步导出、embedding 基础设施、settings status projection）重复。**修订**：新备忘录只覆盖原型目标设计特有的提醒，相关领域以链接引用既有备忘录，不复制内容。
3. **问题**：spec/README 缺 012 是预存问题，与原型无直接关系，混入本任务是否越界。**修订**：属于当前事实源的索引修正（012 已是 Accepted 规范且被 review round 引用），修复成本低、不修复会持续误导按索引读 spec 的会话；纳入本任务并在变更记录中说明，不另开治理任务。
4. **TDD 落点**：纯文档任务，无可自动化行为，按 CLAUDE.md 1.4 第 9 条豁免单元测试；验证以 `scripts/check-docs.sh`、占位扫描和链接有效性为主。
5. **剩余风险**：见文末。

## 验证命令

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 文档影响检查

- 不改变数据、AI、权限、同步、StoreKit、ADR、启动闭环、语言空间闭环、验证脚本、XcodeGen、包边界或 App 启动结构，不触发专项审查。
- spec 003 / spec README / 页面清单的变更均为新增指针和索引修正，不改变既有约束语义。

## 实施记录

- 2026-06-11：阶段 1 完成，方案创建并自审核。

## 完成标准

1. spec 003 含原型设计基准小节和变更记录；spec README 索引含 012 且含原型使用提示。
2. 页面清单「本文档不替代」列表含 `prototypes/` 定位，变更记录已补。
3. 架构备忘录覆盖原型全部目标设计决策，链接既有备忘录和原型页面。
4. `scripts/check-docs.sh`、占位扫描、`git diff --check` 通过。
5. 每阶段独立 commit，本方案移入 done。

## 剩余风险

1. 原型作为目标设计快照会随实现推进滞后；spec 003 的指针小节已写明权威关系和偏差处理，滞后不会反向污染 spec。
2. 备忘录中的目标设计仍未经过独立方案评审；后续任务采纳时必须按备忘录目录规则写回正式文档，本任务不构成实现授权。
