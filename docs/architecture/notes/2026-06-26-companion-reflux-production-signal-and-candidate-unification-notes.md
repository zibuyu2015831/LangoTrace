# 语伴聊天反哺：产出正向信号前向接缝 + 候选统一面备忘录

状态：Active（架构开发备忘录，非已接受实现事实）
创建日期：2026-06-26
来源：LM03-S2a（`docs/plans/done/2026-06-25-feature-lm03-s2a-companion-reflux.md`）

本备忘录记录 S2a 刻意**暂不实现、但会影响后续架构**的两条扩展线，供后续相关任务方案创建时检查（CLAUDE.md §1.2.4）。其中内容**不能直接当作已接受实现事实**。

## 1. Ability 产出（正向 / 流利度）信号消费——后续 band 演进片

### 现状（S2a 已落地的前向接缝）

- `GRDBCompanionRepository.productionUtterances(spaceID:after:)`：返回 `role='user'` 且 `detected_language == target_language_code`（行内自洽，不 join `language_spaces`）的 `companion_messages`，oldest-first，`after` cursor 窗口化，**无 limit**。
- **只读既有 v30 列，无新表、无迁移、无 ledger 常量、不改 band**。

### 为什么 S2a 不消费

- `GRDBLearnerBandProvider.band()` 当前**只建模 struggling（负向）信号**（`dictionary_lookup_events`：查词 + dictation 错误 → 越阈降一档）。产出 = **正向 / 流利度**信号；把「多说话」喂进 struggling 聚合在语义上错误（多说 ≠ 更挣扎）。
- 在语伴片内重开 band 数学 = 在消费片重开最高风险地基，违反原则；且 S4b 刚落地需回归保护。
- 避免「无消费者的死常量 / 死枚举」：S2a 不预登记 `LearnerSourceType.companionProduction`、不写 `analysis_ledger` 常量（plan §D3 round-1 收窄）。

### band 消费前必须满足的三层论证（后续片的门槛）

1. **信号独立**：产出信号与现有 struggling 信号正交，不重复计数、不互相污染。
2. **逻辑正确**：流利度 ≠ 努力度；产出多≠水平高（可能是话痨 / 简单句堆叠）。需明确产出如何映射到能力维度，避免被刷量。
3. **数学形态**：与 band 滞回（hysteresis）、置信度、降档阈值如何合成；是否引入独立的「产出维度」而非并入 struggling 标量。
4. **红线复用**：仍守 ADR-006 §4——不读 AI 难度 / learning_text，不覆盖用户可见 level。S2a 已留负向守卫测试 `CompanionRefluxBandGuardTests`（源无 `companion` 引用 + 插入聊天数据后 band 不变）。

引入消费片时，须登记 `LearnerSourceType.companionProduction` + `analysis_ledger` 高水位 cursor（仿 S4a 捕获 → S4b 消费），并把本接缝接入。

## 2. 两候选表统一评审面——deposit 期决策

### 现状

- 学习材料候选：`memory_candidates`（`entry_id` / `material_id` NOT NULL FK CASCADE）。
- 聊天反哺候选：`companion_memory_candidates`（v31，独立表，`thread_id` / `message_id` 弱引用，无 entry / material）。
- 两表**同 `kind` 枚举、同 `status='candidate'` 生命周期、同派生数据分类**，但物理分离（plan §D1：`memory_candidates` 的 NOT NULL FK 物理排斥聊天行；改可空需 12 步整表重建，触碰学习内容主路径，S2a 不做）。

### 后续（plan 10/11 deposit 管线落地时）

- 候选 deposit（升级为记忆条目 `learner_memory_facts` 主数据）落地时，需要**统一评审面**：要么读两表 union，要么届时再评估是否物理合并。
- 合并决策点应一并解决：difficulty 列（`memory_candidates` 有、`companion_memory_candidates` 无）、来源标注（entry / material vs thread / message）、source-deleted 候选的展示与可 deposit 性。
- 在评审面统一前，两表分离是可接受的早期状态；本备忘录记为未来切片，不在 S2a。

## 3. 相关链接

- [[2026-06-25-companion-voice-input-and-engine-boundary-notes]]
- [[2026-06-25-learner-memory-persistence-and-security-notes]]
- ADR-008 §3.8 / ADR-006 §4·§9 / spec/007 §3。
