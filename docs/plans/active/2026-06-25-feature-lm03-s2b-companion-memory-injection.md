# 任务方案：LM03-S2b 语伴外发注入（Memory 注入 + 方案B找话题 + 两层隐私控制）

状态：Draft（边界登记 / 门控未开；进入实现前须补全实施方案 + 双轮自审）
自审核状态：Not Reviewed
类型：feature
创建日期：2026-06-25
最后更新日期：2026-06-25

## 用户确认记录

- 2026-06-25：用户确认 S2 按风险拆 S2a/S2b。本片 = **S2b 外发注入半片**，承载整个语伴系列**最高隐私门**（系统自动注入外发，受决策 #10 / ADR-005）。
- 2026-06-25：用户确认 **Memory 注入 v1 排序 = 时近性 + 种类配额**（recency-primary，按 kind 配额保多样性；salience 列 v1 仍不参与，留 v2 FTS 相关性召回）。
- **实现授权**：尚未授权；且额外门控未满足（见下）。本片当前仅作边界登记。

## 这份文档是什么

S2 拆分后的**外发注入半片**边界登记。它**不是**可立即实现方案：进入实现前须补全 §实施方案 + TDD 落点，并完成双轮隔离自审 → `Reviewed`，再经用户授权。先登记是为了：① 把最高隐私门从 S2a 关键路径摘下独立门控；② 锁定已定决策（时近性 + 种类配额）；③ 明确额外门控条件，避免后续会话误判可直接实现。

## 范围（待实现，三项）

1. **Memory 注入**：系统级生活事实经 `LearnerContextProvider.memoryFacts(...)` 取 **top-5（时近性 + 种类配额）** + per-space 对话情景，渲染为受控片段注入 system prompt（idea-03 §3.11）。salience 列 v1 不参与（恒 0、无写入者）；v2 接 plan 12 FTS 改相关性召回。
2. **方案 B 主动找话题**：一次性范围授权（时间窗 / 排除标签 / 排除照片原图）+ 本地 `GRDBLocalSearchRepository.search(...)` FTS 预筛 + 最小发送（仅选中条目，§3.6）。
3. **两层隐私控制 + PII scrubbing**：① 全局首次开启预览（复用 `AIRequestPreviewProjection` / `RequestPreviewCardModel`）+ 全局「不使用学习画像」关闭；② per-conversation toggle；③ 注入内容 + 用户消息发送前对结构化 PII（手机号 / 身份证号）确定性 scrubbing（defense-in-depth，不替代授权，§6.9）。

## 额外门控（进入实现前必须满足）

- ✅ 硬前置：LM03-S1（Done）+ plan 12 FTS（就绪）+ LM02-S1 Memory / `LearnerContextProvider`（就绪）。
- ⛔ **隐私两层控制 + PII scrubbing 可验证**（决策 #10 系统自动注入门，spec/008 §2）——须有结构化验证（注入预览快照 + scrubbing 单元测试 + per-conversation toggle 行为测试）。
- ⛔ S2a（聊天反哺）建议先落地（统一候选 / 产出接缝就位），但非硬依赖。
- ⛔ 本片双轮隔离自审 → `Reviewed` + 用户实现授权。

## 关键设计锚点（实现时展开）

- **时近性 + 种类配额排序**：`memoryFacts(visibility: .global)` 现返回 oldest-first 全量；S2b 加 recency-DESC + 按 kind（lifeFact/goal/preference/relationship）配额选 top-5 的纯函数排序层（Core 可测，不改 v27 schema）。
- **注入 = 系统自动外发**：与 S1 的「用户打字发送」严格区分；首次预览 + per-conversation toggle + PII scrubbing 三道控制。
- **PII scrubbing**：确定性正则（手机号 / 身份证号），作用于注入片段 + 用户消息，发送前；Core 纯函数可测；不入日志。
- **方案 B 最小发送**：FTS 本机预筛候选 → 仅选中条目入 prompt，绝不灌全库。
- **删除语义**（§3.11）：「清空对话」仅清对话 + per-space 情景；系统级生活事实保留；UI 透明提示（与 S1/S2 一致）。

## 涉及文档（实现时回写）

ADR-008 / ADR-006 §6 隐私闸 / spec/005 / spec/008 §2 / architecture/002 / page-inventory / idea-03 §3.11/§6.9 收口 / prompts/companion / 拆解文档 / 仪表盘。

## 剩余待用户定（实现拆解时）

- 方案 B 范围限定默认值（默认排除哪些标签、默认时间窗）。
- per-conversation toggle 的偏好持久化粒度（会话级，不改全局）。
- PII scrubbing 覆盖范围 v1（手机号 / 身份证号确定；邮箱 / 地址是否纳入）。

## 严格方案自审核记录

N/A（边界登记，未补全实施方案）。进入实现前须补全实施方案 + 双轮隔离自审，状态转 `Reviewed` 后方可授权。
