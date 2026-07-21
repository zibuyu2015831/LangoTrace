# 任务方案：LM03-S3a 语伴文本流式 UX + 温和复述纠正

状态：Done（2026-06-26 实现完成，全量 CI 绿 run 28226376483，移 done/）
自审核状态：Reviewed
类型：feature
创建日期：2026-06-26
最后更新日期：2026-06-26

## 用户确认记录

- 2026-06-26：用户确认 **LM03-S3 按风险拆 S3a / S3b**。本片 = **S3a**：文本流式 UX + 温和复述纠正（低风险）。**对话记忆/滚动摘要 + 对话小结 = S3b**（高风险，独立后续门控）。
- 2026-06-26：用户确认 **S3a v1 范围 = 流式 + 温和复述**（建议 chip defer）。
- **实现授权**：2026-06-26 用户经 `/goal`「方案审核通过，立即开始实施，直至功能完整落地并完成测试。注意测试需要通过 GitHub action 进行」授权实现；CI 经用户确认「现在跑（我代切 public→CI→private）」走 public 临时切换。

## 实施记录（2026-06-26，Done）

按 Reviewed 设计逐落点 TDD 落地，本机轻量逐包全绿 + 全量 CI `Build & Test` 绿（run 28226376483），无开放项。

- **engine（AI）**：`CompanionConversationEngine.reply(..., onPartial:)` 在既有 delta 循环内逐 token 回调累积缓冲全文；stub 改为「yield deltas 后再抛 error」以表达「流了一截再失败」。新增 3 例：onPartial 累积（"He"→"Hello"）/ 空流不回调 + `.empty` / 部分后失败仍 `.failure`。`CompanionPromptRegistryTests` 补 warmRecast fragment 文本断言（既有仅断言 directive）。
- **seam（UI）**：`CompanionChatActions.send` +`onPartial` 第三参——破坏 7 处闭包字面量 fixture + `.disabled` 机械补 `_`（默认参数救不了闭包字面量 arity，已如自审 P1 列全）；`CompanionLoadedThread` +`correction`（struct 默认值，不破坏构造）；新增 `setGentleRecast(spaceID,Bool)`。
- **store（UI）**：`@Published inFlightReply`/`gentleRecastEnabled`；`send()` 用 `AsyncStream` + 单 MainActor consumer 顺序消费（`onPartial` 仅 `yield`、`finish()` 后 `await consumer.value` 排空），任何完成路径清空 `inFlightReply`；`setGentleRecast` 派生更新。新增 `CompanionStreamingStoreTests`（partials 累积经 Combine sink 取证 + 持久完整文本守卫 + 失败清空保 draft + recast 派生与 spaceID 路由）。
- **view（UI）**：in-flight assistant 气泡（`isSending && inFlightReply` trim 非空才渲染）+ 温和复述 toolbar toggle；新增本地化 key `companion.recast.toggle`（en「Gentle recast」/ zh-Hans「温和复述」），`CompanionChatPresentationTests` 锁 key。
- **App**：`companionSend` 透传 onPartial → engine；`loadThread` 新增 `loadPersona(spaceID).correction` 带出；`setGentleRecast` = loadPersona→仅改 correction→savePersona（read-modify-write 保 tone/formality）。
- **Data**：`GRDBCompanionRepositoryTests` 新增 read-modify-write 守卫（先设 humorous/formal → 仅改 correction → 读回 tone/formality 不变且 correction==warmRecast）。

**边界复核**：无新 migration（head 仍 v32）、无新 AI capability、无新外发类目；流式只改显示，请求体 / 内容类目 / 隐私闸 / PII scrub 与 S1·S2b 完全一致；`inFlightReply` 纯 UI 派生态从不进持久路径；band 红线未碰（变更文件源级无 `derive(`/`learning_text`/`difficulty` 新增）。

**轻量验证**：`swift test` AI（Companion 35）+ Data（CompanionRepository 12）+ UI（全包 621）全绿；swiftformat lint 0 待格式化；swiftlint 变更文件零告警（既有 `AppEnvironment.swift` 等 pre-existing 告警与本片无关）。**全量验证**：CI run 28226376483 `Build & Test` 绿（三端构建 + macOS app test + 全包测试 + lint + check-docs）。

## 这份文档是什么

S3a 完整实施方案：把语伴 S1 的「缓冲整段再显示」非流式 UX 升级为**逐字流式显示**（真人感，idea-03 §5.2），并暴露既有 `CompanionCorrection.warmRecast` 为**温和复述纠正 opt-in**（默认关，idea-03 §3.4）。两者均**低风险**：传输层早已逐 delta yield（S1 只是缓冲）；温和复述是既有闭集枚举值 + prompt directive 早已就绪。权威边界以 ADR-008 / spec/005 / idea-03 为准。

## 北极星 / 边界对照（实现前自检）

- **不改外发边界**：流式只改**显示**（逐 delta 渲染 in-flight 气泡），外发请求体、内容类目、隐私闸与 S1/S2b 完全一致；**无新 AI capability、无新外发类目、无新 migration**。
- **持久化不变**：成功时仍持久 user + **完整缓冲** assistant 文本（engine `.reply(text: buffer)` 返回完整文本，App 持久之）；`inFlightReply` 是纯 UI 派生态，**从不进持久路径**；失败保输入不伪装（ADR-008 §7）。
- **温和复述受 ADR-008 约束**：`warmRecast` 是既有 `CompanionCorrection` 闭集值（人设枚举防注入），prompt 映射 directive + fragment 早已就绪；v1 仅暴露 opt-in（默认 `.ifNeeded` 关），不引入自由文本。
- **band 红线**：本片不碰任何 learner model / band；纯对话 UX + persona。

## 范围（本片两件，待实现）

### 1. 文本流式 UX（逐字显示，AsyncStream 顺序消费）

- **engine**：`CompanionConversationEngine.reply(..., onPartial: @Sendable (String) -> Void = { _ in })`——delta 循环内回调**累积缓冲全文**（cumulative）。最终 `CompanionReplyOutcome` 与 S1 一致；空流/失败走既有 honest failure（先 yield 部分后抛错的情形：onPartial 可能已被调用，但最终 `.failure`，store 据此清空——见取消/失败）。
- **App seam**：`CompanionChatActions.send` 由 `(threadID,userInput) async -> CompanionSendOutcome` 改为 **`(threadID,userInput, onPartial:@Sendable (String)->Void) async -> CompanionSendOutcome`**；App `companionSend` 透传 onPartial → engine。**破坏面（自审 P1）**：闭包字面量 arity 变更，**默认参数救不了闭包字面量构造点**——须同步改 `init` 形参 + `.disabled` + App 装配 + **全部 8 处 `send: { _, _ in }` 测试 fixture**（`.disabled`、`CompanionChatStoreTests`×3、`CompanionExtractionStoreTests`×2、`CompanionMemoryInjectionUITests`、`CompanionTopicSourcingUITests`）改为 `{ _, _, _ in }`。
- **store 顺序消费（自审 P0-1 改定，核心）**：`CompanionChatStore.send()` 内建 `AsyncStream<String>`——
  ```
  let (partials, cont) = AsyncStream<String>.makeStream()
  let consumer = Task { @MainActor in for await p in partials { inFlightReply = p } }
  let outcome = await actions.send(threadID, text, onPartial: { cont.yield($0) })
  cont.finish(); await consumer.value
  ```
  `onPartial` 仅 `cont.yield`（`@Sendable`、线程安全、**保序**）；MainActor consumer 单循环顺序消费——**天然有序、零 Task fan-out、无需单调守卫**（弃用原 cumulative+守卫设计）。`@Published inFlightReply: String` 随之更新。
- **完成 / 失败 / 取消一致清空（自审 P2-1）**：outcome 处理前先 `cont.finish()` 排空；`.appended` → 追加 user+assistant 到 `messages` 并 `inFlightReply = ""`；`.failed` → `inFlightReply = ""` + 保 draft + 不伪造 assistant；**取消 / 视图离开**：send 完成（任何路径）后无条件清空 `inFlightReply`（沿用 S1 任务取消语义，不持久部分回复）。
- **view**：`CompanionChatView` 在 `isSending && !inFlightReply.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty` 时渲染**进行中 assistant 气泡**（逐字增长；纯空白 partial 不渲染，与 engine `.empty` 判定对齐，自审 P2-3）；发送按钮 send 期间禁用（沿用 `canSend`）。

### 2. 温和复述纠正 opt-in（暴露既有 warmRecast，read-modify-write）

- v1 暴露**二元 opt-in**：开=`.warmRecast`、关=`.ifNeeded`（`.none` 不暴露）。directive + fragment 早已映射，自然生效。
- **load 带出（自审 P1-1）**：`CompanionLoadedThread` 加 `correction: CompanionCorrection = .ifNeeded`（struct memberwise 默认值，**不破坏既有 8 处 `loadThread` 构造**）；**App `loadThread` 须新增 `repository.loadPersona(spaceID:).correction`**（当前 loadThread 不读 persona，persona 仅在 send 内加载——此为新增落点，否则 toggle 显示 stale）。
- **store**：`@Published gentleRecastEnabled: Bool`，派生 `= (correction == .warmRecast)`（`.none`/`.ifNeeded` → false）；`setGentleRecast(_ on: Bool)` → action。
- **持久 read-modify-write（自审 P1-2）**：`CompanionChatActions.setGentleRecast(spaceID, Bool)` → App `loadPersona(spaceID)`（缺则 `.default`）→ **仅改 `correction`、保持 tone/formality** → `savePersona`（全字段 upsert，故须带回现有 tone/formality，否则覆盖用户人设）。
- **view**：工具栏温和复述 toggle。

## 关键架构落点与触碰

| 层 | 落点 | 动作 |
|---|---|---|
| AI | `CompanionConversationEngine.swift` | `reply(..., onPartial:)` 新参（默认空闭包，对**函数形参**有效）；delta 循环回调 cumulative；assembleRequest 不变；失败/空流走既有路径。 |
| UI | `CompanionChatActions.swift` | `send` 闭包 +`onPartial` 第三参（破坏 8 fixture + .disabled + init，全部补 `_`）；加 `setGentleRecast: (spaceID,Bool) async -> Void`；`CompanionLoadedThread` 加 `correction`（默认值）。 |
| UI | `CompanionChatStore.swift` | `@Published inFlightReply`、`gentleRecastEnabled`；send 用 `AsyncStream` + MainActor consumer 顺序消费；任何路径清空 inFlightReply；`setGentleRecast`；load 带出 correction 派生。 |
| UI | `CompanionChatView.swift`（三端共享单文件） | in-flight 气泡（trim 非空才渲染）；温和复述 toolbar toggle。 |
| UI | `CompanionChatPresentation.swift` | 复述 toggle 文案 key（en+zh-Hans）。 |
| App | `AppEnvironment+Companion.swift` | `companionSend` 透传 onPartial → engine；**`loadThread` 加 `loadPersona(spaceID).correction`**；`setGentleRecast` = loadPersona→仅改 correction 保 tone/formality→savePersona。 |

## 非目标（本片不做）

- **对话记忆 / 滚动摘要 / 对话小结**：= S3b（高风险）。
- **常驻建议 chip / 长按翻译·解析·提示**：长按能力未建，defer。
- **persona tone / formality 编辑器、`.none` 纠错档**：v1 仅暴露 correction 二元（ifNeeded/warmRecast）。
- **流式持久化变化 / 新 migration / 新 AI capability / 新外发类目**；**Anthropic / 多 Provider 流式适配**（= S4）。

## TDD 落点（先失败 → 最小实现 → 聚焦验证）

1. **AI `CompanionConversationEngineTests`（扩）**：stub yield `["He","llo"]` → `onPartial` 依次收 `"He"`、`"Hello"`（cumulative）；最终 `.reply(text:"Hello")`。空流 → 不回调 + `.empty`。**先 yield "He" 再抛错** → onPartial 收过 "He" 但最终 `.failure`（自审 P1-3）。
2. **UI `CompanionStreamingStoreTests`**：经 stub `actions.send`（其 onPartial 顺序回调 "He"→"Hello"）驱动 → `inFlightReply` 终态 "Hello"；`.appended` 后 `messages` 末条 == **完整缓冲全文**（非中间 partial）且 `inFlightReply` 清空（自审 P2-2 持久不变量守卫）；`.failed` → `inFlightReply` 清空 + draft 保留 + 不追加 assistant（自审 P2-1/P1-4）；纯空白 partial 不进有效渲染态（trim 判定，自审 P2-3）。
3. **UI 复述 toggle**：`CompanionLoadedThread.correction == .warmRecast` 经 load → `store.gentleRecastEnabled == true`；`.ifNeeded`/`.none` → false（自审 P3-1）；`setGentleRecast(true)` → action 持久。
4. **AI `CompanionPromptRegistryTests`（补文本片段，自审 P2-1）**：`correction == .warmRecast` → rendered text **含 recast fragment 文本**（既有测试仅断言 directive，缺文本片段断言；本片唯一 AI 层真新增）。
5. **Data persona round-trip**：**已被 `GRDBCompanionRepositoryTests.savePersonaRoundTrips` 覆盖（warmRecast 存读一致）——本片仅确认不新增**；新增 **read-modify-write 守卫**：先设非默认 tone → `setGentleRecast(true)` → 读回 **tone 不变** 且 correction==warmRecast（自审 P1-2）。

聚焦验证（本机轻量逐包）：`swift test --package-path Packages/{LangoTraceAI,LangoTraceData,LangoTraceUI}` + swiftformat/swiftlint。完整验证（三端构建 + macOS app test，**无新 migration**）走 GitHub Actions CI。

## 文档影响（§17，实现收口回写）

- **spec/005 §5**：「上层消费仍可演进」收口——语伴会话**已接文本流式 UX**；流式不改外发边界；**`CompanionChatActions.send` seam 形态变更**（+onPartial）同步 architecture/002 语伴数据流条目。
- **architecture/002 §4.x**：语伴流式 UX 数据流（engine onPartial → AsyncStream → MainActor consumer → inFlightReply → in-flight 气泡）+ 温和复述 persona 暴露。
- **ADR-008 / idea-03 §5.2/§3.4**：流式真人感 + 温和复述 opt-in 收口（均在既有边界内）。
- **platform-page-inventory**：语伴页逐字流式 + 温和复述 toggle（三端共享单文件）。
- **prompts/companion/system.md**：confirm correction directive + 补 recast opt-in 暴露说明。
- **spec/006 / testing**：复述 toggle 文案 key 纳入既有 localized-key 验证（若有）；流式逐字 / 复述生效 / 失败清空 in-flight 写入手工验证项。
- **拆解 + 仪表盘**：S3a Done 登记；S3b 边界。
- **专项审查触发判断**：本片无 migration / 隐私门 / 数据外发新增——**不触发专项审查**（仅 UX + 既有 persona 暴露 + seam contract 变更）；release/testing 影响 = 流式手工验证项。

## 剩余风险 / 待用户定（实现时）

- **流式取消脏态**：已收口为范围内——send 任何路径完成后无条件清空 `inFlightReply` + TDD 锁定；AsyncStream consumer 随 send 结束 `cont.finish()` 自然排空。
- **温和复述作用域**：correction 是 per-space persona（`conversation_companions`），toggle 改全 space 语伴；非 per-conversation。v1 接受（与人设同层）。
- **send 签名变更波及面**：已列全（8 fixture + .disabled + init + App）；属机械改动，非设计风险。

## 严格方案自审核记录

```
审核日期：2026-06-26
审核方式：隔离子代理 ×2（架构 / 测试·落地），并行 distinct-lens 后主会话核验汇总
审核轮次：第一轮（架构）+ 第二轮（测试·落地）
```

两轮独立核验，**高度收敛**（两轮各自独立命中 send 签名破坏面 + 并发模型问题），合计 1 P0 + 多 P1/P2，全部确认并写回正文：

- **P0-1（并发模型：cumulative+Task hop+单调守卫不健全）已采纳**：架构轮证 `Task{@MainActor}` 不保序、守卫依赖长度弱代理。**已改采 `AsyncStream` + 单 MainActor consumer 顺序消费**（弃守卫），correct-by-construction。
- **P1（send 闭包加 onPartial 破坏 8 fixture + 默认参数救不了闭包字面量）已采纳**：两轮独立命中；纠正原 §「默认参数减破坏面」误判（对闭包字面量无效）；范围表列全 8 处 fixture + .disabled + init + App，机械补 `_`。
- **P1（loadThread 不读 persona 链路断点）已采纳**：App `loadThread` 新增 `loadPersona(spaceID).correction`；TDD 3 读回断言。
- **P1（setGentleRecast 须 read-modify-write 保 tone/formality）已采纳**：`savePersona` 全字段 upsert，故 loadPersona→仅改 correction→save；TDD 5 守卫。
- **P2 已采纳**：取消/失败清空 inFlightReply 升为 TDD；持久完整文本守卫；纯空白 partial 不渲染（trim 对齐 engine `.empty`）；warmRecast round-trip 既有覆盖**不重复**、directive 文本片段断言为唯一 AI 新增；`CompanionLoadedThread.correction` 默认值不破坏构造（struct，区别闭包）。

**仍需用户确认的问题**：无新增范围性问题（均实现细节，已按低风险收口）。

**是否允许进入实现**：1 P0 + 全部 P1/P2 已写回正文（AsyncStream 顺序消费 / send 签名破坏面列全 / loadThread 带 persona / read-modify-write / 取消清空 TDD）。**自审门禁完成 → `Reviewed`**。待用户实现授权（`Reviewed` ≠ 已批准实现）。
