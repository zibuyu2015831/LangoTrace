# 待议构想孵化区（Idea Incubator）

状态：Accepted
创建日期：2026-06-13
最后审查日期：2026-06-13

本目录存放**处于讨论阶段、尚未拆成 active plan**的需求构想与跨任务架构设想。它是「想法」到「正式实施」之间的临时孵化区，给早期头脑风暴一个明确的家，避免这类文档散落在仓库根目录或被误当作事实源。

## 1. 这里放什么

- 产品功能方向的深入构想（例如某个新功能是否要做、形态如何）。
- 横跨产品 + 架构、尚未定型的能力设想（例如把多个派生数据统一为一个模块）。
- 已经过一到多轮讨论、但**还没有**进入用户确认链路、还没有拆成 `docs/plans/active/` 任务方案的内容。

## 2. 这里不放什么 / 权威边界

- **不是事实源**：本目录任何文件都不替代 `spec` / `decisions(ADR)` / `architecture` / `plans` / 代码；与权威文档冲突时，以权威文档为准。
- **不是新会话入口**：新会话仍从 `docs/README.md` 进入。
- **不放已确认的实施方案**：一旦经用户确认要做，必须按 [`../plans/README.md`](../plans/README.md) 拆成 `docs/plans/active/` 任务方案，并按 [`../plans/plan-review-protocol.md`](../plans/plan-review-protocol.md) 自审核。
- **不放纯架构备忘录**：只为某个未来架构能力留提醒、风险清单或候选模型，写 [`../architecture/notes/`](../architecture/notes/README.md)；本目录是更上游、更偏「要不要做、做成什么」的产品 + 架构整体构想。
- **不放外部研究**：竞品、开源参考、许可证、spike / probe 证据写 [`../reference/research/`](../reference/research/README.md)；本目录是 LangoTrace 自身的内部构想。

## 3. 命名规则

- 文件名形如 `NN-english-kebab.md`，数字前缀标记**建议实施顺序**（不是创建顺序）。
- 顺序会随讨论调整；调整顺序时直接重命名并更新本 README 的清单与互链。
- 每个文件头部应包含：状态（构想 / 搁置）、类型、创建日期、最后更新、来源、负责人决定、以及「本文件不替代 spec / ADR / plan」的说明块。

## 4. 生命周期与退出

构想成熟后，按其性质分流到权威文档，然后归档本文件：

1. 核心产品 / 架构 / 隐私 / 同步 / 付费取舍 → 新增或更新 `docs/decisions/`（ADR）。
2. 模块边界、数据流、Provider、同步架构 → `docs/architecture/`。
3. 开发一致性约束、模块规范、实现地图 → `docs/spec/`。
4. 具体实施步骤 → `docs/plans/active/`（完成后入 `docs/plans/done/`）。
5. 仅为未来能力留的架构提醒 → `docs/architecture/notes/`。
6. 已分流的构想文件不再当作当前事实；如已无追溯价值可删除，否则迁入 `docs/archive/`。

分流时务必走用户确认链路；本目录文件本身不能自动升格为决策或实现事实。

## 5. 当前构想清单（按建议实施顺序）

| 顺序 | 文件 | 主题 | 一句话 |
| --- | --- | --- | --- |
| 01 | [`01-learner-model.md`](01-learner-model.md) | 学习者模型 / 用户画像（Learner Model） | 统一承载「App 对用户的理解」的上位模块；下含「能力画像」「关系记忆」两个平级子域，建议先立模块边界再增量填充 |
| 02 | [`02-dynamic-proficiency-assessment.md`](02-dynamic-proficiency-assessment.md) | 动态水平评估（能力画像子域） | 把用户语言水平从一次性静态自评变为持续演进的能力画像，并配「水平总览」页面；建议先于语伴实现 |
| 03 | [`03-conversation-partner.md`](03-conversation-partner.md) | 语伴（AI 语言对话 + 关系记忆子域） | 默认关闭、扎根个人记录的目标语言对话练习；其「长期关系记忆」是学习者模型的另一个子域 |
