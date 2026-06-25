# 任务方案：语伴（LM03）切片拆解与决策收口（完整聊天引擎）

状态：In Progress（拆解 / 排序 / 决策导航文档，非实现方案；不含生产代码变更）
自审核状态：N/A（决策 / 排序导航文档；各子片进入实现前各自按 plan-review-protocol 双轮自审核）
类型：docs
创建日期：2026-06-25
最后更新日期：2026-06-25

## 这份文档是什么

[ADR-006](../../decisions/006-system-level-three-layer-learner-model.md) 把学习者模型分 LM01/LM02/LM03，语伴（LM03）是依赖链最长、排最后的消费者。[ADR-008](../../decisions/008-language-companion-as-grounded-practice-modality.md) 已固化语伴**定位**（扎根记录的语言对话练习模态 + 六条硬边界 + 入口 = 练习 Tab 二级 + 记录详情），[Provider 多轮 + 流式方案](2026-06-25-feature-ai-provider-multi-turn-and-streaming.md) 已拆为前置。本文件把语伴**功能本体**（`docs/idea/03-conversation-partner.md` §3 各节）拆成有界子片，并**收口 idea-03 §9 / §10.6 的全部待决点**。

**2026-06-25 用户决策**：语伴策略采 **直接拆完整聊天引擎**（非 idea-03 §10.2 的「会话式 affordance 中间形态」）。故本文件按完整单线程多轮对话引擎拆解。

它**只做拆解 / 排序 / 决策导航**，不是实现方案：
- 不替代各子片未来的 active plan；每子片**进入实现前**各自创建 active plan、双轮自审、走用户确认链路。
- 不替代 ADR-006 / ADR-008（权威决策）、idea-03（设计来源）、Provider 前置方案、2026-05-25 语伴备忘录。
- 冲突时以 ADR-008 / ADR-006 与各权威文档为准。

## 硬前置（全部子片）

1. **ADR-008 定位**（已 Accepted）：六条硬边界 + 入口 = 练习 Tab 二级 / 记录详情（**不做第四 Tab / 顶层导航**）。
2. **Provider 多轮 + 文本流式**（Draft/Reviewed）：当前 AI 请求是 OpenAI 兼容单发、无多轮、无文本流式（流式仅 TTS）。语伴依赖多轮 + 流式；Anthropic Messages 适配后置。
3. **数据依赖已就绪**：plan 09（请求预览 / 日志，E6）已落地；plan 10/11（记忆 deposit / 复习，E7/E8）已落地；plan 12（FTS，E9）已落地——方案 B 找话题 + 聊天反哺记忆 + Memory 注入的数据底子具备。
4. **2026-05-25 语伴备忘录对齐**：复用命名 `ConversationCompanion / CompanionThread / CompanionMessage / CompanionMemorySummary / CompanionAnalysis`；对话情景 per-space、生活事实系统级（ADR-006 §7.1 / idea-03 §10.1）。
5. **LM02 Memory（S1）就绪**：Memory 注入依赖 S1 系统级生活事实 + `LearnerContextProvider`；Style 注入依赖 S2（v2）。
6. **语音输入架构备忘录（idea-03 §3.7）**：拆子片时必须把「语伴语音输入 / 语音对话」写入 `docs/architecture/notes/`，说明文本设计须为后续语音预留 message schema / 输入栏 / Speech 权限边界。

## 子片拆解（完整引擎，按依赖排序）

### LM03-S1：MVP 单线程文本对话引擎
- **范围**：设置开关（默认关闭，ADR-008）+ 练习 Tab 二级入口 + 记录详情「围绕这条记录对话」入口；单一会话（不支持多会话）纯文本多轮；始终目标语言回复；会话 GRDB schema（`CompanionThread/Message`，per-space、local-only、不同步、可按条及后续 / 整段删除）；多轮编排 + 上下文窗口管理；人设 = Prompt Registry 固定模板 + 枚举选项（语气 / 正式度 / 纠错倾向，防注入）；模糊输入拟真确认；语种识别本地 `NaturalLanguage` + AI 路由回退；难度三层自适应基线 v1 = 静态 `LanguageLevel`（§3.9）；语伴朗读复用既有逐句 TTS（ADR-008 / §3.7 初版必需）；话题来源仅方案 A（用户显式带入单条记录）；失败态（Provider 不可用 / 离线，不丢输入，不伪装）。
- **硬前置**：ADR-008 + Provider 多轮（流式可后置到 S3）+ 2026-05-25 命名。
- **触碰**：新 Speech/AI 编排 seam、新会话 GRDB schema（migration）、三端聊天 UI（工作量大头）、新 Prompt Registry 人设条目、设置开关、语种识别。
- **风险**：高（三端聊天 UI + 多轮编排 + 上下文预算 + 失败态）；但不依赖 LM02 后续切片（难度退静态 level）。

### LM03-S2：找话题（方案 B）+ Memory 注入 + 聊天反哺记忆
- **范围**：方案 B（一次性范围授权 + 本地 FTS 预筛 + 最小发送找话题，§3.6）；Memory 注入（系统级生活事实 salience top-5 + per-space 对话情景，经 `LearnerContextProvider`，§3.11）+ 两层隐私控制（首次开启预览 + per-conversation toggle + PII scrubbing，§6.9）；聊天内容自动提取词汇 / 表达到 `memory_candidates`（复用既有自动产出管线，§3.8）；用户目标语发言回流 Ability 产出证据（接 S4 账本，§3.8）。
- **硬前置**：LM03-S1 + plan 12 FTS（已就绪）+ LM02-S1 Memory + 隐私两层控制。
- **触碰**：FTS 检索、Memory 注入受控片段、隐私预览（复用 plan 09）、`memory_candidates` 自动入库、（Ability 回流接 S4 账本）。
- **风险**：中高（隐私外发边界 = 系统自动注入，受决策 #10；须两层控制 + PII scrubbing）。

### LM03-S3：文本流式 + 对话记忆 + 小结 + 温和复述
- **范围**：文本流式输出（真人感，依赖 Provider 流式前置，§5.2）；对话记忆 / 长期关系记忆（滚动窗口 + 摘要，含「删除某条及其后续」时摘要失效重建，§3.2/§3.11）；对话小结（手动 + 可选会话结束，§3.12）；温和复述纠正（opt-in 默认关，§3.4）；常驻建议 chip（可选，默认走长按提示）。
- **硬前置**：LM03-S1/S2 + Provider 流式 + plan 10/11 记忆。
- **风险**：中（流式体验 + 摘要失效重建一致性）。

### LM03-S4（v2）：Style 注入 + Anthropic 适配 + 认知风格下投影
- **范围**：Style 受控片段注入（依赖 LM02-S2 Style，经 Ability i+1 下投影，§3.11 / idea-01 §13.5）；Anthropic Messages 多轮 + 流式适配（idea-03 §10.3）；Style v2 触发时机（§9 待决）。
- **硬前置**：LM02-S2（Style）+ Provider Anthropic 适配 + ADR-006 §6 隐私闸（Style 外发）。
- **风险**：中（外发增量 + 多 Provider）。

### 远期（不在本次拆解的 active plan 范围）
- 语音输入 / 语音对话（依赖 Speech Recognition，先写架构备忘录，§3.7）；场景 / 主题对话模式（决策 #5：Prompt 模式非新空间，§9 远期）；向量检索增强话题相关性。

## idea-03 待决点收口（§9 + §10.5/§10.6）

下列多数 §10.6 已给架构师推荐默认，本文件**采纳为各子片进入实现时的默认取舍**（用户最终授权时可逐项推翻）：

| 待决点 | 收口（默认，§10.6 推荐） | 归属子片 |
| --- | --- | --- |
| 开关默认 | **关闭**（已定，§2） | S1 |
| 入口位置 | **练习 Tab 二级 + 记录详情**，不做第四 Tab（ADR-008） | S1 |
| 数据模型命名 | **复用 2026-05-25 备忘录** Companion* | S1 |
| 人设选项集 | 语气（友好/中性/幽默）正式度（随意/正式）纠错（仅按需/温和复述/不纠错），默认**友好/随意/仅按需**；无「陪练强度」 | S1 |
| 自由文本（昵称） | v1 **不开放**，纯枚举（防注入） | S1 |
| 难度自适应 | **三层隐式**（Ability 基线 v1 静态 level→v2 band / 响应层 persona / 对话控制），不宣布难度 | S1（v2 接 S4 band） |
| 词汇提取 | **自动产出 + 入库**对齐既有 memory_candidates；长按手动补充 | S2 |
| 清空对话语义 | 仅清对话消息 + per-space 情景；系统级生活事实保留；UI 透明提示 | S1（schema）/ S2（Memory） |
| Memory 注入隐私 | 全局首次预览 + 全局关闭 / per-conversation toggle / PII scrubbing；不为每类单独 opt-in | S2 |
| Memory v1 注入上限 | salience **top-5**；v2 接 FTS 召回 | S2 |
| 模糊输入拟真 | 确认 / 调侃，克制偏友好（阈值待细化） | S1 |
| 温和复述纠正 | **默认关闭**，opt-in | S3 |
| 对话小结触发 | **手动 + 可选会话结束**，不每轮 | S3 |
| 历史 export/sync | **默认不同步**；导出随统一口径 | S1（schema）/ E10 |
| 失败态 | 「语伴暂时联系不上」+ 重试 + 不丢输入 + 不伪装 | S1 |
| 秒回期待 | 产品定位「练习对象」非「助手」 | S1（文案） |
| 流式 | 依赖 Provider 前置；可后置到 S3 | S3 |
| Style 集成 | v1 不注入；v2 经 provider 注入 + i+1 下投影 | S4（v2） |
| Style v2 时机 | **仍待决**（与 idea-01 §13.4 认知风格后置节奏对齐） | S4（v2，待用户定） |
| Memory salience 评分机制 | **仍待决**（时近 / 频次 / 主题相关性权重） | S2（待用户定） |
| 混合语言 / 夹码 | 长按按主导 / 选中片段；主对话母语片段当求助填空 | S1（待细化） |
| 场景 / 主题模式 | **远期**，Prompt 模式非新空间 | 远期 |
| 关系记忆可见 / 编辑 / 删除粒度 | 归 Learner Model 统一治理（LM02-S1 总览页） | S2 |

**仍须用户定的少数项**（其余采纳上表默认）：① Style v2 接入时机（S4）；② Memory salience top-5 评分机制（S2）；③ 模糊输入拟真 / 夹码体验的具体阈值（S1 实现时细化）；④ 语伴入口英文名（§9）。

## 推荐排序与门控

```text
前置：ADR-008（已定）+ Provider 多轮/流式（Draft/Reviewed，待实现）+ 2026-05-25 命名对齐
   ↓
LM03-S1（MVP 文本对话引擎）   ← 完整引擎起点；不依赖 LM02 后续切片（难度退静态 level）
   ↓
LM03-S2（方案 B 找话题 + Memory 注入 + 反哺记忆）   ← 依赖 plan 12 FTS（已就绪）+ LM02-S1 Memory + 隐私两层
   ↓
LM03-S3（流式 + 对话记忆 + 小结 + 复述）   ← 依赖 Provider 流式
   ↓
LM03-S4（v2：Style 注入 + Anthropic + i+1 下投影）   ← 依赖 LM02-S2 Style + ADR-006 §6 隐私闸
   ↓
远期：语音对话 / 场景模式 / 向量检索
```

门控（每子片实现前）：① 硬前置就绪；② 该子片独立 active plan 已 Reviewed（双轮）；③ 用户实现授权；④ S2 额外门 = 隐私两层控制 + PII scrubbing 可验证；⑤ S4 额外门 = ADR-006 §6 Style 外发闸 + Anthropic 适配。

## 与既有文档的关系 / 维护约定

- 语伴本体改变产品定位，相关定位修订（连同 idea-01 隐私重定义、idea-02 自适应卖点）按 ADR-008 已部分固化；S1 落地时一并收口 `product-main-reference.md` 定位文案（§10.6「合并为一次修订」）。
- 某子片拉为 active plan 时，在 `2026-06-11-00-docs-series-progress.md` 登记，并在本文件对应子片标注「→ 已拆 active plan: <路径>」。
- 语音输入架构备忘录（硬前置 6）在 LM03-S1 active plan 创建时一并写入 `docs/architecture/notes/`。
- 全部子片落地后，本文件随 LM03 收口移入 `done/`。
- 设计细节 / TDD 落点 / 验证写回各子片 active plan 与权威文档，不在本文件。
```
