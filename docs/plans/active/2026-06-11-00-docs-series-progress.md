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
独立基础设施（可与第 1/2 批并行先行，退 spike 险，不压在语伴关键路径）
  ✅ AI Provider 多轮 + 文本流式（OpenAI 兼容族；Anthropic 后置）  ← 2026-06-25 已 Done（Phase 0 spike gate 过 + CI 全绿，已移 done/）；LM03 仅消费

第 1 批（本地优先，零外发，可门控为一批）
  ✅ LM02-S1（Memory 层 + 学习画像总览页）   ← 2026-06-25 已 Done（v27 migration + writer seam + 三端总览页 + CI 绿，已移 done/）；S2/S3/S4a 硬前置已满足
     ↓
  ✅ LM02-S3（盲点：dictation diff 派生）       ← 2026-06-25 已 Done（填 S1 盲点分区 + CI 绿，已移 done/）；compute-on-read 无 migration
  ✅ LM02-S2（Style：seam-only 不展示）         ← 2026-06-25 已 Done（compute-on-read seam-only + CI 绿，已移 done/）；无 migration
        （S2/S3 均 read-only，不依赖 S1 的 writer，但 S3 展示依赖 S1 总览页先落地）

第 2 批（band，最高风险，须第 1 批 S3 信号成熟 + 回归充分）— 2026-06-25 已拆 S4a/S4b 各自 active plan + 双轮 + 隔离再审
  ✅ S4a（查词捕获 + 分析账本/cursor，v28/v29 migration）  ← 2026-06-25 已 Done（不动 derive()；查词 local-only 新类别 + ADR-006 §9 账本+cursor + AI 解释 seam 埋点 + CI 绿，已移 done/）
     ↓
  S4b（band 服务 + derive() 迟滞 + 总览呈现，最高风险）       ← 唯一碰 derive()；双轮+再审过；门控：S4a+S3 信号回归 + ADR-006 §10 修订存在；迟滞=连续 3 次 document-open 越阈 + ≥5 次停留；band 经 :96 影响外发档位(诚实论证=不增新外发字段)

第 3 批（语伴 = 完整聊天引擎；消费上方已退险的 Provider 多轮/流式 infra）
  LM03-S1（MVP 单线程文本对话引擎）          ← 各子片需先按 LM03 拆解文档各自拆出 active plan + 双轮自审
     ↓
  LM03-S2（方案B 找话题 + Memory 注入 + 反哺记忆）
     ↓
  LM03-S3（文本流式 + 对话记忆 + 小结 + 复述）
     ↓
  LM03-S4（v2：Style 注入 + Anthropic 适配 + i+1 下投影）

未来切片登记（2026-06-25 补登孤儿，仅占位、未拆 active plan，见 LM02 拆解文档）
  改写/写作修改（Style→Ability i+1 下投影第二消费者，兑现 S2）；onboarding 自评措辞软化微切片

跨切 v2（外发增量，逐项 opt-in，隐私闸后）
  AI 校准（Style 认知风格 / band AI 估计）    ← 叠加在 S2/S4b 上，未拆 active plan
```

### 待办方案状态总表

| 系列 | 方案文件（`docs/plans/active/`） | 主题 | 状态 / 门控 |
|---|---|---|---|
| LM02-S1 | ~~`2026-06-25-feature-lm02-memory-layer-and-learner-profile-overview`~~ → `done/` | Memory 层 + 学习画像总览页 | ✅ **Done（2026-06-25）**：三 Phase 落地（v27 `learner_memory_facts` + `AppDatabase.writer` + 三端总览页 + 治理）；CI Build & Test 全绿（run 28159562884）；§17 文档回写完成（ADR-006 / architecture 001+002 / spec/007 / page-inventory）；已移 `done/`。**S2/S3/S4a 硬前置已满足** |
| LM02-S2 | ~~`2026-06-25-feature-lm02-s2-style-surface-imprint`~~ → `done/` | Style 表层印记（seam-only 不展示） | ✅ **Done（2026-06-25）**：compute-on-read 源语言写作印记 seam-only（NL 注入 detector + 按母语分组 + 红线 entries-only）；CI Build & Test 全绿（run 28161953442）；§17 回写（含 ADR-006 §8 持久化分层细化 + 新 architecture note + idea-01 §13.9 收口）；已移 `done/` |
| LM02-S3 | ~~`2026-06-25-feature-lm02-s3-blind-spots`~~ → `done/` | 盲点（dictation diff 派生） | ✅ **Done（2026-06-25）**：compute-on-read dictation diff 盲点 + 填充 S1 总览页盲点分区（红线源级 grep + 行为断言双守；`LIMIT 200`）；CI Build & Test 全绿（run 28160963826）；§17 文档回写（含 idea-02 §7.1 源替换纠正）；已移 `done/` |
| LM02-S4 | `2026-06-25-feature-lm02-s4-band-reestimation` | band 动态重估（拆解边界） | ⚪ **拆解边界 / 自审 N/A**（2026-06-25 完整双轮后转拆解边界，已 spawn S4a/S4b；4 P0+4 P1 分配进子片为实现前必决项）；不再作单一可实现方案 |
| LM02-S4a | ~~`2026-06-25-feature-lm02-s4a-lookup-capture-and-ledger`~~ → `done/` | 查词捕获 + 分析账本（地基，低风险） | ✅ **Done（2026-06-25）**：v28 查词事件（显式 local-only）+ v29 ADR-006 §9 账本+高水位 cursor + 阅读 AI 解释 seam 埋点；CI Build & Test 全绿（run 28163829316）；§17 回写（ADR-006 §9 / spec/007 / architecture/002 / persistence note）；已移 `done/`。**S4b 信号地基已就绪** |
| LM02-S4b | `2026-06-25-feature-lm02-s4b-band-service-and-derive-hysteresis` | band 服务 + derive 迟滞 + 总览（最高风险） | 🟡 **Draft / Reviewed**（双轮 + 隔离再审三关过；再审收口 P0-1 band 经 :96 影响外发档位措辞 / P1-1 迟滞 dwell 改 document-open 次数 / P2-1 计数器状态）；门控 S4a+S3 信号回归 + ADR-006 §10 修订存在；**待实现授权** |
| 独立 infra | ~~`2026-06-25-feature-ai-provider-multi-turn-and-streaming`~~ → `done/` | AI Provider 多轮 + 文本流式（LM03 消费） | ✅ **Done（2026-06-25）**：Phase 0 spike gate 过 → 生产实现；CI Build & Test 全绿（run 28156767558）；§17 文档回写完成（spec/005 + system-map §4.9/§7 + 新 architecture note + ADR-008 + add-ai-provider workflow）；已移 `done/`。mimo 流式 / Anthropic / 对话级 log 写入按记录 defer 至 LM03 / 后续 run |
| 导航 | `2026-06-25-docs-lm02-remaining-slices-decomposition` | LM02 后续切片拆解 + 排序 | 🔵 **In Progress**（S2/S3 已拆 active plan；S4 已转拆解边界拆 S4a/S4b；改写 + onboarding 措辞两孤儿已补登；AI 校准留登记未拆） |
| 导航 | `2026-06-25-docs-lm03-companion-decomposition` | 语伴完整引擎切片 + 决策收口 | 🔵 **In Progress**（S1–S4 切片边界 + §9/§10.6 决策收口；**LM03-S1…S4 子片 active plan 待各批次开工前再拆**） |

> E10（导入导出）/ E11（同步引擎）已于 2026-06-25 移入 `docs/archive/plans/`（引擎切片落地 + 剩余诚实 defer），不再占用本表；恢复入口与 `learner_memory_facts` 硬接缝见上方「已完成基线」与 `docs/archive/plans/README.md`。

## 待用户决策（实施前收口）

1. **各 plan 推荐默认是否接受**：S1 的 visibility=global / 二段式删除、Provider 的 OpenAI 兼容族范围、S3 聚合策略等——各方案已带推荐默认 + 确认点，可批量过目或逐项推翻。
2. **4 项语伴决策**（其余 18 项已按 §10.6 推荐收口，见 LM03 拆解文档）：① Style v2 接入时机；② Memory 注入 salience 评分机制；③ 模糊输入/夹码体验阈值；④ 语伴入口英文名。
3. **逐批实现授权**：**✅ 2026-06-25 用户已授权实现 LM02 本地优先系列 + enabler**（enabler / S1 / S2 / S3 / S4a / S4b 六份 Reviewed feature plan），将由独立 goal 会话按下方「实施顺序与门控」逐片驱动（每片：TDD → 轻量本地测试 + 格式检查 → 重测试走 GitHub Actions CI → commit → 移 done/）。**LM03（语伴）不在本次授权内**——其子片 active plan 尚未拆出，须先各自双轮自审 + 隔离再审，属下一次授权。
   - **开放项默认已接受（用户 2026-06-25）**：① 查词事件 v1 = local-only / 排除导出（S4a §20）；② onboarding 自评措辞软化 = 登记孤儿、不在本次实现内。

### 架构完整性审查决议（2026-06-25 已决，4 项）

补完 S3 第二轮 + S4 双轮自审 + 三 idea 拆分完整性审查后，**四件架构级缺口已由用户拍板**（详见各方案 §13 + 拆解文档）：

4. **✅ 已决并已落地：S4 拆 S4a/S4b，S4 文件转拆解边界**（自审 N/A）。**2026-06-25「先收口再实施」已完成拆分**：S4a（`...s4a-lookup-capture-and-ledger`，信号捕获+账本，低风险）+ S4b（`...s4b-band-service-and-derive-hysteresis`，band 服务+derive 迟滞，最高风险）**各自 active plan 已建 + 各自双轮自审 + 拆分后隔离子代理再审三关过**。再审捕获并收口了拆分引入的实质错误：S4a 的 source_content_origin 不可捕获（降前向接缝）、practice 伪先例（改新类别显式声明）、埋点落点（改 AI 解释 seam）；S4b 的「band 不跨外发」被 `:96` 证伪（改诚实措辞）、迟滞 dwell 单位错配（改 document-open 次数）。两片现 Draft/Reviewed，**待实现授权**（S4b 另门控 S4a+S3 信号回归 + ADR-006 §10 修订 artifact 存在）。
5. **✅ 已决：两处孤儿能力均登记为未来切片**（LM02 拆解文档「未来切片登记」节）：① 改写/写作修改（Style→Ability i+1 下投影第二消费者，兑现 S2 立项前提）；② onboarding 自评措辞软化微切片（idea-02 §7.2 / ADR-006 §10，纯展示、不改 `LanguageLevel` 枚举）。仅占位、不立即拆 active plan。
6. **✅ 已决：AI Provider 多轮+流式 enabler 改标独立基础设施**（原「语伴前置」）：可与第 1/2 批并行先行退 spike 险（首个 `AsyncThrowingStream` / `bytes(for:)` OS 差异 / mimo SSE 未验），LM03 仅消费。方案范围不变、仅排序定位调整。
7. **✅ 已决：S4 ADR = ADR-006 §10 修订**（非新独立 ADR）：band 重估 + derive() 吃演进信号 + 迟滞契约作 §10 扩展修订，作为 **S4b 清线门控**（修订 artifact 须先存在）。

> 上述决议仅落 **plan/拆解文档** 层；S4a/S4b active plan 拆分、ADR-006 §10 实际修订、孤儿切片 active plan 均在各自实现批次开工前执行，仍需逐批用户实现授权（当前无任何方案获实现授权）。

> 备注（E10/E11 归档硬接缝复核）：`learner_memory_facts` 可恢复备份硬接缝仍由架构备忘录 `2026-06-25-learner-memory-persistence-and-security-notes.md` 托管、可追溯，未被静默孤立；但「无 active plan 会执行 E10 备份」属设计内的备忘录机制——Memory 备份安全性取决于未来会话恢复 E10 时先读该备忘录。

## 维护约定

- 每份方案状态推进时同步更新本表（与方案 `状态：` 字段一致）；某 LM03 子片拉为 active plan 时在此登记并在 LM03 拆解文档标注。
- 详细决策 / 验证结果 / TDD 落点不写这里，写回各权威文档并在此留指针。
- 本文件随学习者模型系列收尾一并移入 `done/`。
