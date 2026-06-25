# 任务方案：开发系列进度仪表盘（跨会话恢复指针）

状态：In Progress
自审核状态：N/A（导航/指针文档，不含生产代码变更）
类型：docs
创建日期：2026-06-15
最后更新日期：2026-06-25（系列收尾后转为学习者模型系列 LM02/LM03 的实施指针；已删除 01–15 + 原型/infra 的历史 Phase 明细，仅保留前向可执行内容）

## 这份文档是什么

`docs/plans/active/` 的**进度仪表盘 + 跨会话恢复指针**，只做导航：一行登记每份方案状态、标出**实施顺序与门控**、记录**待用户决策**。新会话从这里读「下一步实施什么、按什么顺序、还缺哪些前置」。

它**不是**事实源：每份方案的权威范围 / TDD 落点 / 自审核见各方案文件；历史决策与 ~110 条审查处置见 `docs/plans/done/2026-06-11-chore-code-review-and-dev-plan-series.md` 附录 A。冲突以权威文档为准。

## 实施环境约束（实施前必读）

- **Linux 环境**：无 Swift 工具链，所有 `swift test` / `xcodebuild` / `swiftformat` / `swiftlint` 走 GitHub Actions；触发 CI 前仓库临时设 public、commit message 带 `[ci]`，跑完设回 private。
- **MacBook 环境**：本机只跑轻量单包测试（`swift test --package-path Packages/<target>`）+ 格式检查；重测试（`scripts/verify.sh` 全量、三端构建、跨多包）一律放 GitHub Actions（被动散热设备防过热降频）。
- **合并 `main`**：禁止本地直接 merge/push；经 PR + `Build & Test` 绿勾合并（CLAUDE.md 决策 #18）。日常开发在 `dev` 分支。

## 已完成基线（不再展开）

- **01–15 实施系列 + LM01 + 原型/infra 修复：全部 Implemented/Verified + CI 绿，已移入 `done/`**（记录详情见各 done 方案 + 上述主控文档附录 A）。其中 LM01 落地了独立包 `LangoTraceLearnerModel`（Ability 知识覆盖 compute-on-read，无 migration），是 LM02/LM03 的地基。
- **E10（导入导出）/ E11（同步引擎）：Slice 1 / 引擎切片已落地 + CI 绿，因依赖不存在的基础设施（加密 KDF/安全存储；iCloud container/付费 capability/真实账号/多设备）诚实 defer，已于 2026-06-25 整体移入 `docs/archive/plans/`**（active/ 收敛为学习者模型系列），恢复入口见 `docs/archive/plans/README.md` 与各方案自审核记录。**硬接缝（不随归档失效）**：E10 实现可恢复备份时**必须**纳入 LM02-S1 的 `learner_memory_facts`（否则删库=永久失忆），事实源为 `docs/architecture/notes/2026-06-25-learner-memory-persistence-and-security-notes.md`。

## 当前实施重点：学习者模型系列（LM02 + LM03）

> 来源 idea：`docs/idea/01-learner-model.md`（总纲，已固化为 ADR-006）/ `02-dynamic-proficiency-assessment.md` / `03-conversation-partner.md`（已固化定位 ADR-008）。三份 idea 内容已全部拆解为下列方案（AI 校准 v2 刻意不预拆，留外发增量后置）。
>
> **用户已定（2026-06-25）**：① 实施节奏 = **拆完→门控分批实现**；② 语伴 = **直接拆完整聊天引擎**；③ LM02-S2 = **do-now / seam-only**；④ 本轮**仅拆 plan、暂未授权任何实现**。

### 实施顺序与门控

**每份方案进入实现前的通用门控**：(a) 双轮自审完成 → `Reviewed`；(b) **用户实现授权**（当前全部未授权）；(c) 含 migration / 三端 UI 的收口走 GitHub Actions CI。

```text
第 1 批（本地优先，零外发，可门控为一批）
  LM02-S1（Memory 层 + 学习画像总览页）   ← 先做：建 writer seam + v27 migration + 总览页（S2/S3 的展示归宿）
     ↓
  LM02-S3（盲点：dictation diff 派生）       ← 填 S1 总览页盲点分区；compute-on-read 无 migration
  LM02-S2（Style：seam-only 不展示）         ← 与 S3 并行；compute-on-read 无 migration
        （S2/S3 均 read-only，不依赖 S1 的 writer，但 S3 展示依赖 S1 总览页先落地）

第 2 批（band，最高风险，须第 1 批 S3 信号成熟 + 回归充分）
  LM02-S4（band 重估 + derive() 迟滞）       ← 唯一碰 derive()；首次引入查词捕获 + 分析账本 + migration
        建议自拆 S4a（信号捕获+账本）→ S4b（band 服务+derive 迟滞）；可能须升 ADR

第 3 批（语伴 = 完整聊天引擎；前置 Provider 多轮/流式先实现）
  LM03 前置：AI Provider 多轮 + 文本流式（OpenAI 兼容族；Anthropic 后置）
     ↓
  LM03-S1（MVP 单线程文本对话引擎）          ← 各子片需先按 LM03 拆解文档各自拆出 active plan + 双轮自审
     ↓
  LM03-S2（方案B 找话题 + Memory 注入 + 反哺记忆）
     ↓
  LM03-S3（文本流式 + 对话记忆 + 小结 + 复述）
     ↓
  LM03-S4（v2：Style 注入 + Anthropic 适配 + i+1 下投影）

跨切 v2（外发增量，逐项 opt-in，隐私闸后）
  AI 校准（Style 认知风格 / band AI 估计）    ← 叠加在 S2/S4 上，未拆 active plan
```

### 待办方案状态总表

| 系列 | 方案文件（`docs/plans/active/`） | 主题 | 状态 / 门控 |
|---|---|---|---|
| LM02-S1 | `2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview` | Memory 层 + 学习画像总览页 | 🟡 **Draft / Reviewed**（双轮过；visibility=global + 二段式删除已收口；含 v27 migration + writer seam + 三端总览页）；**待实现授权** |
| LM02-S2 | `2026-06-25-feature-lm02-s2-style-surface-imprint` | Style 表层印记（seam-only 不展示） | 🟡 **Draft / Reviewed**（双轮过；compute-on-read 源语言写作印记，零外发/零迁移）；**用户定 do-now/seam-only**；待实现授权 |
| LM02-S3 | `2026-06-25-feature-lm02-s3-blind-spots` | 盲点（dictation diff 派生） | 🟡 **Draft / 第一轮 Reviewed**（2 P0/3 P1 已写回；deposit 砍出 v1）；**第二轮 + 实现授权待批次前** |
| LM02-S4 | `2026-06-25-feature-lm02-s4-band-reestimation` | band 动态重估 + derive 迟滞 | 🟠 **Draft / Not Reviewed**（最高风险；唯一碰 derive()；含查词捕获+账本 migration；建议拆 S4a/S4b；可能升 ADR）；**完整双轮自审 + 授权待第 2 批** |
| LM03 前置 | `2026-06-25-feature-ai-provider-multi-turn-and-streaming` | AI Provider 多轮 + 文本流式 | 🟡 **Draft / Reviewed**（双轮过；OpenAI 兼容族，Anthropic 后置）；**待实现授权（第 3 批先做）** |
| 导航 | `2026-06-25-docs-lm02-remaining-slices-decomposition` | LM02 后续切片拆解 + 排序 | 🔵 **In Progress**（S2/S3/S4 已拆 active plan；AI 校准留登记未拆） |
| 导航 | `2026-06-25-docs-lm03-companion-decomposition` | 语伴完整引擎切片 + 决策收口 | 🔵 **In Progress**（S1–S4 切片边界 + §9/§10.6 决策收口；**LM03-S1…S4 子片 active plan 待各批次开工前再拆**） |

> E10（导入导出）/ E11（同步引擎）已于 2026-06-25 移入 `docs/archive/plans/`（引擎切片落地 + 剩余诚实 defer），不再占用本表；恢复入口与 `learner_memory_facts` 硬接缝见上方「已完成基线」与 `docs/archive/plans/README.md`。

## 待用户决策（实施前收口）

1. **各 plan 推荐默认是否接受**：S1 的 visibility=global / 二段式删除、Provider 的 OpenAI 兼容族范围、S3 聚合策略等——各方案已带推荐默认 + 确认点，可批量过目或逐项推翻。
2. **4 项语伴决策**（其余 18 项已按 §10.6 推荐收口，见 LM03 拆解文档）：① Style v2 接入时机；② Memory 注入 salience 评分机制；③ 模糊输入/夹码体验阈值；④ 语伴入口英文名。
3. **逐批实现授权**：当前**无任何方案获实现授权**。新会话实施时按上面「实施顺序」逐批走「完成自审 → 取得授权 → TDD 实现 → CI 绿 → 移 done/」。

## 维护约定

- 每份方案状态推进时同步更新本表（与方案 `状态：` 字段一致）；某 LM03 子片拉为 active plan 时在此登记并在 LM03 拆解文档标注。
- 详细决策 / 验证结果 / TDD 落点不写这里，写回各权威文档并在此留指针。
- 本文件随学习者模型系列收尾一并移入 `done/`。
