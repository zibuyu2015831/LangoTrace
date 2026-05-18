# LangoTrace 文档体系重整计划

> 本计划用于指导一次文档目录重整。目标不是增加文档数量，而是减少歧义、减少重复维护、让后续开发能更快找到“该读什么、该写什么、该验证什么”。

**核心结论：**

1. 将 `docs/guidelines/` 重命名为 `docs/spec/`。现有 guidelines 实质上已经承担 OpenWriter 中 `spec` 的职责，继续使用 guidelines 名称会弱化其规范权威。
2. 将 `worklog 草案` 与 `plan` 合并为一份“任务方案文档”。后续需求开发、bug 修复、重构、文档治理任务只维护一份详细方案，按 `active/` 与 `done/` 管理生命周期。
3. 创建 `docs/prompts/`，现在就固定 Prompt 文档规则，避免后续开发 AI / Prompt 功能时遗漏。
4. 创建 `docs/_meta/`，但第一份文档放在重整完成之后，用于记录每个目录的职责、权威类型、写入规则和迁移状态。
5. 不创建独立 `docs/implementation/`。OpenWriter 的实现地图是各模块 `spec/<module>/impl.md`，LangoTrace 后续也应把实现地图放在对应 `docs/spec/<module>/impl.md` 下。
6. `docs/superpowers/` 完成内容归档后由用户手动删除。迁移时必须逐份判断：保留、归档、迁入 spec/ADR/任务方案，或谨慎删除过期内容。
7. 可以删除已过期内容，但过期判断必须有证据，不能因为文件旧就删除。

---

## 1. 架构判断

### 1.1 `guidelines` 是否就是另一个项目中的 `spec`

是。对照 OpenWriter 的 `dev_docs/spec/**/spec.md`，LangoTrace 当前 `docs/guidelines/` 已经承担规范层职责：

- 记录强制规则。
- 记录默认推荐。
- 记录反例。
- 记录 AI 开发提示。
- 约束 SwiftUI、导航、UI、AI Provider、Prompt、隐私等后续实现。
- 权威等级低于 ADR 和产品主参考，高于普通计划和临时实现。

因此不应再新增平行 `docs/spec/`。正确做法是：

```text
docs/guidelines/  ->  docs/spec/
```

迁移后：

- `docs/spec/` 是规范层。
- 原 `docs/guidelines/*.md` 文件重命名或原样迁入 `docs/spec/`。
- 所有入口、文档体系、审查机制、计划文档中的 `guidelines` 引用必须同步改为 `spec`。

### 1.2 是否还需要 `docs/implementation/`

不需要创建独立目录。

重新核对 OpenWriter 后可以确认：它没有独立的 implementation 目录。实现地图 `impl.md` 与模块规范 `spec.md` 放在同一个模块目录下：

```text
dev_docs/spec/<module>/spec.md
dev_docs/spec/<module>/impl.md
```

这个结构更合理，因为实现地图必须紧贴它对应的规范，避免“规范在一个目录、实现地图在另一个目录”造成跨目录漂移。

LangoTrace 现在缺的是：

- 当前实现对应哪些文件。
- 核心类型和函数在哪里。
- 关键流程如何串起来。
- 哪些测试覆盖了该模块。
- 当前实现与规范是否有偏差。

因此后续采用：

```text
docs/spec/
  README.md
  examples/
  <module>/
    spec.md
    impl.md
```

第一阶段先把 `docs/guidelines/` 重命名为 `docs/spec/`，保留现有平铺规范文件。第二阶段再选择真实模块试点，逐步形成 `docs/spec/<module>/spec.md` + `impl.md` 的模块化结构。

实现地图规则：

- `impl.md` 只描述当前实现，不定义新规范。
- `impl.md` 必须引用对应 `spec.md` 或相关平铺 spec 文件。
- `impl.md` 不做产品决策，不替代 ADR。
- 如果实现地图暴露规范缺口，应更新对应 spec 或新增 ADR，而不是只在 impl 中记录。

### 1.3 worklog 和 plan 是否可以合二为一

可以，且建议合并。

当前 `worklog` 与 `plan` 分离的代价：

- 同一任务容易出现两份文档。
- 用户确认、实施步骤、验证结果、文档影响检查分散。
- 后续会话需要读多个文件才能判断任务状态。
- `docs/superpowers/plans/` 与 `docs/worklogs/` 已经出现职责重叠。

合并后的目标：

```text
一项需求 / 一个 bug / 一次重构 / 一次文档治理
只维护一份任务方案文档
```

这份文档同时承担原 worklog 和 plan 的职责：

- 任务描述。
- 用户确认。
- 现状证据。
- 决策依据。
- 实施方案。
- 涉及代码文件。
- 参考代码文件。
- 验证和复查方法。
- 文档影响检查。
- 实施记录。
- 完成状态。

生命周期由目录表达：

```text
docs/plans/active/  ->  docs/plans/done/
```

结论：

- 后续不再新增 `docs/worklogs/` 文档。
- `docs/worklogs/` 现有内容进入迁移清单。
- 历史有效任务记录迁入 `docs/plans/done/` 或归档。
- 明显过期且无追溯价值的内容，可以在慎重判断后删除。

## 2. 目标目录结构

第一阶段重整完成后的目标结构：

```text
docs/
  README.md
  _meta/
    directory-responsibilities.md
  architecture/
  decisions/
  plans/
    README.md
    active/
    done/
    examples/
  product-main-reference.md
  prompts/
    README.md
  release/
  research/
  review/
  spec/
    README.md
    examples/
  technical-framework-roadmap.md
  testing/
```

待退出目录：

```text
docs/worklogs/
docs/superpowers/
```

退出方式：

- `docs/worklogs/`：迁移到 `docs/plans/done/`、`docs/plans/active/` 或归档/删除。
- `docs/superpowers/`：迁移到 `docs/plans/`、`docs/spec/`、`docs/decisions/` 或归档/删除。
- 目录清空后，由用户手动删除。

## 3. 目录职责

| 目录 | 职责 | 权威类型 | 写入规则 |
| --- | --- | --- | --- |
| `docs/README.md` | 总入口和任务路由 | 入口权威 | 目录、状态、阅读路径变化时更新 |
| `docs/_meta/` | 文档体系自身规则 | 受保护规则 | 重整完成后创建第一份目录职责文档；后续修改需显式确认 |
| `docs/architecture/` | 系统架构、模块边界、数据流 | 架构说明 | 不记录逐步实施计划 |
| `docs/decisions/` | 全局 ADR | 决策权威 | 只记录不可轻易反转的核心取舍 |
| `docs/spec/` | 开发规范、模块规范和同目录实现地图 | 规范权威 + 实现描述 | 由原 `guidelines` 迁入；后续模块可使用 `spec.md` + `impl.md` |
| `docs/plans/active/` | 进行中任务方案 | 执行中任务记录 | 一项任务一份文档 |
| `docs/plans/done/` | 已完成任务方案 | 历史任务记录 | 完成验证后从 active 移入 |
| `docs/prompts/` | Prompt Registry | Prompt 规则和索引 | 先创建 README，具体 prompt 落地时补文档 |
| `docs/review/` | 文档一致性审查 | 审查记录 | 专项审查和里程碑审查 |
| `docs/testing/` | 测试策略和手动验证 | 验证规则 | 测试流程变化时更新 |
| `docs/release/` | TestFlight、App Store、StoreKit、隐私标签 | 发布规则 | 发布相关变化时更新 |
| `docs/research/` | 调研材料 | 非决策资料 | 形成结论后迁入 spec/ADR/产品文档 |

## 4. 任务方案文档要求

一项需求、一个 bug、一次重构或一次文档治理，只维护一份任务方案文档。

建议路径：

```text
docs/plans/active/YYYY-MM-DD-<type>-<topic>.md
docs/plans/done/YYYY-MM-DD-<type>-<topic>.md
```

允许类型：

- `feature`
- `bug`
- `refactor`
- `research`
- `chore`
- `docs`

### 4.1 必填内容

每份任务方案至少包含：

```text
标题
状态
类型
创建日期
最后更新日期
用户确认记录

1. 需求或 bug 描述
2. 现状描述
3. 目标
4. 范围
5. 不做什么
6. 证据与决策依据
7. 涉及的代码文件路径
8. 参考的代码文件路径
9. 涉及的文档路径
10. 实施方案
11. 复查方法
12. 验证命令
13. 文档影响检查
14. 实施记录
15. 完成标准
16. 剩余风险
```

bug 方案还必须包含：

```text
复现方式
预期行为
实际行为
根因分析
置信度
置信度依据
备选原因
回归测试方案
```

### 4.2 置信度规则

置信度主要用于 bug 分析，必须使用百分比，不使用 `Low`、`Medium`、`High` 这类模糊分级。

```text
置信度：0% - 100%
```

规则：

- `0% - 39%`：只是猜测或线索，不允许进入修复实施，只能继续调查。
- `40% - 69%`：有一定代码证据，但缺少完整复现或验证，只能做小范围验证性改动。
- `70% - 89%`：根因较明确，可以制定修复方案，但必须保留备选原因和回归测试。
- `90% - 100%`：已有复现、代码证据或测试证明根因，但仍不能省略验证。

写法要求：

```text
置信度：85%
置信度依据：列出代码证据、复现证据、日志证据或测试证据。
不确定性：列出还没有证明的部分。
```

### 4.3 状态流转

建议状态：

```text
Draft -> User Approved -> In Progress -> Implemented -> Verified -> Done
```

目录与状态关系：

- `Draft` / `User Approved` / `In Progress` / `Implemented`：放在 `docs/plans/active/`。
- `Verified` / `Done`：移动到 `docs/plans/done/`。

### 4.4 是否还需要 worklog

不建议继续维护独立 worklog。

原因：

- 合并后的一份任务方案已经覆盖 worklog 的背景、确认、实施、验证和文档影响。
- 单文档更符合用户提出的“具体、内容不分散”目标。
- active/done 目录能表达任务生命周期，不需要再靠 worklog 状态追踪。

保留规则：

- 旧 `docs/worklogs/` 在迁移完成前仍是历史资料。
- 文档入口需要明确：新任务写入 `docs/plans/active/`，不再写入 `docs/worklogs/`。
- 迁移完成后，`docs/worklogs/` 可由用户手动删除。

## 5. `spec` 目录迁移规则

### 5.1 重命名

执行：

```text
docs/guidelines/ -> docs/spec/
```

迁移后需要同步更新：

- `docs/README.md`
- `docs/documentation-system.md`
- `docs/review/README.md`
- `docs/review/INDEX.md` 中如有引用
- `docs/plans/**` 中如有引用
- `docs/architecture/**` 中如有引用
- 根入口内容中的阅读路径

### 5.2 文件命名

现有文件可以第一阶段保留原编号：

```text
001-guideline-governance.md
002-navigation-and-routing.md
...
```

第二阶段再考虑是否重命名为：

```text
001-spec-governance.md
002-navigation-and-routing.md
...
```

不建议第一阶段同时改目录名和文件名，避免 diff 过大。

### 5.3 spec 内容要求

后续 `docs/spec/*.md` 应包含：

- 状态。
- 适用阶段。
- 适用范围。
- 当前结论。
- 强制规则。
- 默认推荐。
- 可演进部分。
- 反例。
- AI 开发提示。
- 关联 `impl.md` 实现地图。
- 变更记录。

### 5.4 spec 的演进规则

当前项目仍处于起步阶段，spec 是开发过程中持续总结、收敛和完善的规范，不是一成不变的冻结文档。

允许更新 spec 的情况：

- 功能开发发现现有规则不完整。
- bug 修复暴露了新的边界条件。
- 原规范与更优设计冲突，且经过代码和产品判断后确认需要调整。
- 新模块落地，需要补充模块级不变量、状态流或验证规则。
- 现有实现已经稳定，需要把反复出现的局部约定提升为规范。

更新约束：

- 如果只是补充实现细节或更清晰的开发约束，可以直接更新 spec 并记录原因。
- 如果改变产品核心模型、数据所有权、隐私边界、同步策略、付费策略或重大技术路线，必须新增或更新 ADR。
- 如果代码已经偏离 spec，不能只改 spec 迁就代码；必须说明是“代码错”还是“spec 需要演进”。
- spec 更新后，相关任务方案、实现地图、测试或 README 路由也要同步检查。

### 5.5 模块化 spec 和实现地图

第一阶段只完成目录重命名和规则更新，不强制把所有平铺 spec 改成模块目录。

第二阶段开始，可以选择高风险模块逐步改为：

```text
docs/spec/<module>/
  spec.md
  impl.md
```

`impl.md` 必须包含：

- 关联 spec。
- 当前代码快照。
- 涉及源文件。
- 核心类型和函数。
- 关键流程。
- 测试覆盖。
- 已知偏差。
- 验证命令。
- 最近验证日期。

候选模块：

```text
launch-and-routing
language-space
data-storage
ai-provider
privacy-permissions
sync
storekit-release
```

## 6. Prompt 目录规则

现在创建：

```text
docs/prompts/README.md
```

第一阶段只写使用规则，不创建具体 Prompt 文档。

每个具体 Prompt 文档必须包含：

- Prompt id。
- 所属功能。
- 调用模块。
- 输入变量。
- 输出契约。
- 是否包含用户原文。
- 是否包含照片、音频、OCR、历史记忆或附件摘要。
- 隐私等级。
- 请求预览要求。
- 评测方式。
- 版本记录。
- 英文版本 Prompt。
- 中文版本 Prompt。

Prompt 语言规则：

- 代码中实际使用的内置 Prompt 应以英文版本为准，以获得更稳定的模型效果和跨模型兼容性。
- 文档中必须保存英文和中文两个版本。
- 中文版本用于客户阅读、业务校对、隐私审查和产品讨论。
- 如果代码中的 Prompt 由模板拼接生成，文档必须记录完整渲染后的英文样例，并说明变量位置。
- 英文版本和中文版本语义必须一致；如果为了模型效果存在非逐字翻译，应在文档中说明差异原因。

Prompt 文档不得只写摘要。关键 Prompt 文案应保存完整文本，或明确说明文案从哪个代码位置生成。

## 7. `_meta` 目录规则

创建：

```text
docs/_meta/
  directory-responsibilities.md
```

这应是 `_meta` 下的第一份文档，在重整完成之后创建。

内容必须记录：

- 每个目录的职责。
- 每个目录的权威类型。
- 每个目录允许写入的内容。
- 每个目录不允许写入的内容。
- 已退出目录。
- 待删除目录。
- 迁移完成日期。
- 最后审查日期。

后续如果需要更多 `_meta` 文档，可以再拆分：

```text
docs/_meta/doc-format.md
docs/_meta/sync-policy.md
docs/_meta/migration-policy.md
```

但第一阶段不预先创建这些文件，避免规则层过早膨胀。

## 8. `superpowers` 归档规则

`docs/superpowers/` 内容需要逐份分类。

当前已知文件包括：

```text
docs/superpowers/plans/*.md
docs/superpowers/specs/*.md
```

迁移目标：

| 内容类型 | 目标 |
| --- | --- |
| 仍未执行的任务方案 | `docs/plans/active/` |
| 已完成且仍有追溯价值的任务方案 | `docs/plans/done/` |
| 形成长期规范的设计 | `docs/spec/` |
| 描述当前实现的内容 | `docs/spec/<module>/impl.md` |
| 不可轻易反转的取舍 | `docs/decisions/` |
| 历史参考但非当前事实 | `docs/archive/superpowers/` |
| 明确过期且无追溯价值 | 删除 |

删除标准：

- 文档描述的计划已经被后续方案完整替代。
- 文档没有独立决策、实现证据或验证价值。
- 文档内容与当前代码/产品方向冲突，且不需要作为历史参考。
- 删除前已确认没有被 README、spec、ADR、review、plan 引用。

不能删除的情况：

- 记录了用户确认的关键决策。
- 记录了仍未迁入 ADR/spec 的重要取舍。
- 是某个已完成功能唯一的实施证据。
- 后续审查仍需用它解释为什么这样设计。

`docs/superpowers/` 清空后，用户手动删除目录。

## 9. `worklogs` 归档规则

`docs/worklogs/` 不再作为新任务入口。

迁移方式：

| 内容类型 | 目标 |
| --- | --- |
| 未完成任务 | `docs/plans/active/` |
| 已完成任务且有追溯价值 | `docs/plans/done/` |
| 历史参考但不应作为当前事实 | `docs/archive/worklogs/` |
| 明确过期且无追溯价值 | 删除 |

迁移时需要保留：

- 用户确认记录。
- 实施记录。
- 验证结果。
- 文档影响检查。
- 关联提交。

如果一份 worklog 已经被更完整的 plan 覆盖，可以删除或归档，但必须先确认没有独立信息丢失。

## 10. 第一阶段执行任务

### 任务 1：重命名 `guidelines` 为 `spec`

- [ ] 执行目录重命名。
- [ ] 全仓搜索 `docs/guidelines`、`guidelines/`、`开发规范` 是否需要改为 `docs/spec` 或 `规范文档`。
- [ ] 更新 `docs/README.md` 任务阅读路径。
- [ ] 更新 `docs/documentation-system.md` 文档分层。
- [ ] 更新 `docs/review/README.md` 审查分级。
- [ ] 更新现有文档中的旧链接。

### 任务 2：建立统一任务方案目录

- [ ] 创建 `docs/plans/README.md`。
- [ ] 创建 `docs/plans/active/`。
- [ ] 创建 `docs/plans/done/`。
- [ ] 创建 `docs/plans/examples/task-plan-template.md`。
- [ ] 在模板中写入任务方案必填字段。
- [ ] 更新入口文档，说明新任务不再写入 `docs/worklogs/`。

### 任务 3：建立模块实现地图规则

- [ ] 在 `docs/spec/README.md` 中说明模块目录可以同时包含 `spec.md` 和 `impl.md`。
- [ ] 创建或迁入 `docs/spec/examples/impl-template.md`。
- [ ] 说明 `impl.md` 只描述当前实现，不定义规范和决策。
- [ ] 暂不创建真实模块实现地图。

### 任务 4：建立 `prompts` 目录

- [ ] 创建 `docs/prompts/README.md`。
- [ ] 写明 Prompt Registry 使用规则。
- [ ] 写明具体 Prompt 文档必填字段。
- [ ] 明确第一阶段不创建具体 Prompt 文档。

### 任务 5：归档 `superpowers`

- [ ] 枚举 `docs/superpowers/` 下全部文件。
- [ ] 为每个文件标注迁移目标：plans、spec、spec module impl、decisions、archive、delete。
- [ ] 迁移前先更新引用。
- [ ] 对需要删除的文件写明删除依据。
- [ ] 迁移完成后由用户手动删除空目录。

### 任务 6：归档 `worklogs`

- [ ] 枚举 `docs/worklogs/` 下全部文件。
- [ ] 区分 active、done、archive、delete。
- [ ] 将仍有价值的内容合并或迁移到 `docs/plans/`。
- [ ] 删除或归档过期内容前，检查引用和独立信息。
- [ ] 迁移完成后由用户手动删除空目录。

### 任务 7：创建 `_meta` 第一份文档

- [ ] 在所有目录重整完成后创建 `docs/_meta/directory-responsibilities.md`。
- [ ] 记录每个目录职责、权威类型、写入规则和禁止事项。
- [ ] 记录已退出目录和迁移完成日期。
- [ ] 将该文档加入 `docs/README.md`。

## 11. 验证计划

每个阶段至少运行：

```bash
find docs -maxdepth 4 -type f | sort
rg "docs/guidelines|guidelines/" docs
rg "docs/superpowers|superpowers/" docs
rg "docs/worklogs|worklogs/" docs
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*'
git diff --check
git status --short
```

如果修改脚本或 Swift 代码，追加运行：

```bash
scripts/verify.sh
```

## 12. 验收标准

重整完成必须满足：

- `docs/guidelines/` 已重命名为 `docs/spec/`。
- 新任务入口统一为 `docs/plans/active/`。
- 已完成任务统一进入 `docs/plans/done/`。
- `docs/prompts/README.md` 已创建并说明规则。
- `docs/spec/README.md` 已说明模块实现地图 `impl.md` 规则。
- `docs/_meta/directory-responsibilities.md` 已在重整完成后创建。
- `docs/superpowers/` 内容已完成分类迁移或删除判断。
- `docs/worklogs/` 内容已完成分类迁移或删除判断。
- 过期内容删除有依据。
- 旧路径引用已清理。
- `docs/README.md` 能准确指导后续开发。

## 13. 仍需用户确认的点

1. `docs/worklogs/` 完成迁移后是否也由用户手动删除，和 `docs/superpowers/` 保持一致？
2. 是否接受第一阶段保留原 spec 文件名中的 `guideline` 字样，第二阶段再改文件名？
3. 是否需要新增 `docs/archive/`，还是过期历史内容直接删除？
