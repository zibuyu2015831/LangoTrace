# 013：练习学习域规范

状态：Accepted

适用阶段：单句跟读录音闭环、练习列表与句间导航迭代、后续听写 / 回译 / 评分扩展。

## 1. 领域定位

练习是语迹从生活记录进入的核心学习闭环之一，与记录、阅读、记忆并列。当前已实现切片是：练习入口（记录卡片列表）→ 句子列表 → 单句跟读（听示范、录音、回放、重录、句间导航）。iPhone、iPad、macOS 共享同一业务 seam，平台外壳分别承载。

当前实现入口：`PracticeView`、`PhonePracticeRows`、`PracticeSentenceListView`、`PracticeSentenceListPresentation`、`PracticeSessionView`、`PracticeSessionViewModel`、`PracticeActions`、`PracticePromptCard`、`PracticeControlBar`、`GRDBPracticeRepository`。

本文档与其他文档的分工：

- 页面与实现状态事实以 [三端页面清单](../platform-page-inventory.md) 为准。
- 练习页视觉与交互规则以 [003：UI 设计系统规范](003-ui-design-system.md) 4.3.1-4.3.2 节为准。
- TTS 播放基础设施以 [011：TTS Provider 配置、测试与播放前置规范](011-tts-provider-configuration-and-playback.md) 为准。
- 本文档记录练习域的模型契约、生命周期、隐私边界和扩展边界。

## 2. 练习会话与录音模型

- `practice_sessions` 保存单句练习内容快照（`PracticeSentenceSnapshot`）、exercise type、status 和 completed recording reference。
- `practice_sessions.exercise_type` 的稳定值为 `shadowing / dictation / backtranslation`；v18 migration 已扩展 CHECK 约束。当前 shadowing（录音）与 dictation（文本 attempt）会话真实启用；backtranslation 值用于后续独立方案接入。
- `practice_recordings` 保存录音 attempt metadata；完成态只允许引用 ready recording。
- `practice_text_attempts`（v23 migration）保存文本作答 attempt（听写、后续回译），schema 一次性覆盖两种方式：`exercise_type` CHECK 为 `('dictation','backtranslation')`，`diff_difference_count` / `diff_summary_json` 仅听写写入、回译恒 NULL（回译参考不判对错），`listen_count` 为低权重信息。attempt 文本是用户练习证据、本地主数据，不参与同步 / 默认导出 / 备份 / 诊断 / 任何外发路径，也不参与 TTS cache 清理 / LRU。
- 录音文件写入 App 管理的媒体资产目录；`media_artifacts` 是通用主表，`practice_recording_artifacts` 是练习录音 typed extension metadata。
- “已练过”状态由最近一次 ready recording（shadowing）或未软删文本 attempt（dictation）派生，不设手动 `标记完成`；重复练习后录音回放使用最近一次 ready recording，听写恢复使用最近一次文本 attempt。
- completed practice recording 是用户练习证据，不是可重建缓存；TTS cache 清理或容量 LRU 不得静默删除它。
- 录音文件缺失或 hash mismatch 时，session 仍保持 completed，录音 source 进入 unavailable / missing 状态，不得静默指向其他音频。

## 3. Route Seed 契约

- 进入单句练习必须携带 `PracticeSessionRouteSeed`：entry、material、sentence identity、sentence index、target text hash、target language code、exercise type、句子快照和同一篇记录内的轻量 sibling context。
- 练习 route 不得退回 Entry 级 `.practice(entryID)`；单句 session 必须携带稳定 sentence identity（页面清单第 8 节红线）。
- prompt card disclosure state 只是 route-local UI state，不进入 `PracticeSession`、recording metadata、TTS cache 或 media artifact。
- 句间导航在当前 route 内替换相邻 seed；录音中和录音回放中禁用切换，示范播放中切换必须先停止旧播放。

## 4. TTS 示范与播放边界

- 单句页听示范复用逐句 TTS playback coordinator；`听` 只负责示范播放，`练` 负责进入会话，两者职责不得合并。
- 页面展示、滚动和进入会话不得自动触发 TTS；示范播放只能由用户显式点击触发。
- 用户开始录音前，必须先停止当前示范播放。

## 5. 录音隐私与权限边界

- 录音必须由用户显式点击触发；触发时才请求麦克风权限，页面出现不得自动请求权限。
- 练习录音默认本机保存：不同步、不默认导出、不自动发送 AI Provider、excluded from system backup。改变任一默认值都必须新开方案并按 [008：权限、本地隐私与诊断日志规范](008-permissions-local-privacy-and-diagnostics.md) 审查。
- iOS 录音会话（`.playAndRecord` category）**不得使用 `.allowBluetoothHFP` 选项**：该选项令 BT 耳机切入 HFP 双向通话模式（8–16kHz），会污染录音结束后的 TTS 播放路由。BT 麦克风输入使用 `.allowBluetooth`（iOS 17 deprecated，migration 见 `spec/011 §13.2`），输出使用 `.defaultToSpeaker`。TTS 播放会话须显式指定 `.allowBluetoothA2DP`（见 `spec/011 §13.1`）。
- 单句页只读取已有 LearningMaterial 翻译 / note 作为理解辅助，不新增 AI 语法分析请求。
- 当前阶段不做发音评分、ASR、后台录音或录音上传。

## 6. 练习方式扩展边界

- 练习 Tab 首层保持可练习记录卡片列表，不混排听写 / 回译等未实现任务类型。
- 听写与回译的目标设计位于「记录 → 句子列表」层级的练习方式切换（原型 `prototypes/iphone/practice-dictation.html`、`practice-backtranslation.html`，标注目标设计）。E3 已完成 mode 路由基础：`PracticeSessionRouteSeed`、`PracticeSentenceSnapshot`、`PracticeActions` seam 和 `practice_sessions.exercise_type` 可承载 `shadowing / dictation / backtranslation`；句子列表由 `PracticeModeAvailability` 控制可见方式，只有一个可用方式时不展示分段控制，避免未实现假入口。**E4 已落地听写**：`availableExerciseTypes` 注册 `shadowing / dictation` 两段，`PracticeSessionView` 按 exercise type 分发到听写或跟读会话。回译仍仅有 schema 预留。
- 听写对照契约（E4-D1，声学/词汇层口径）：听写检验听觉解码，对照只计入声学/词汇层差异——拼写、词形（stay/stays）、同音异形词（its/it's）、多写 / 漏写 / 错写的词各计 1 处；正字法层差异不计入——纯大小写差异等价匹配、独立标点在归一化阶段抹除（count 与显示均不涉及标点）。对照是 `PracticeDictationDiff` Core 纯函数（NFC 归一化、Character 粒度分词、词级 LCS 大小写折叠对齐、2000 Character 上限），完全本机、不调用 AI；差异用下划线（形状）+ warn 色 + “n 处差异”计数文字共同表达，不只靠颜色。不提供严格模式开关。
- `GRDBPracticeRepository.completedSentenceIDs(materialID:exerciseType:)` 是句子列表“已练”状态和“从第 n 句继续”CTA 的只读查询；完成状态按当前 exercise type 独立计算，不跨练习方式复用。听写“已练”由未软删文本 attempt 派生（并入同一查询），shadowing 仍由 ready recording 派生。
- E5 接入回译时，只能在对应会话、attempt 持久化和隐私边界完成后注册 mode 可用性；不得仅点亮 segment 或返回 `disabled` 页面。回译复用 `practice_text_attempts`，但 diff 列恒 NULL（参考不判对错）。
- 架构提醒见 [多端原型目标设计扩展备忘录](../architecture/notes/2026-06-11-prototype-target-design-extension-notes.md)。
- 录音同步、导出与可恢复备份的边界见 [练习录音同步、导出与可恢复备份备忘录](../architecture/notes/2026-05-26-practice-recording-sync-export-notes.md)。
- 回译参考表达如需新 AI 请求，必须遵守 [005：AI Provider、Prompt 与隐私规范](005-ai-provider-prompt-and-privacy.md) 的显式触发与请求边界。
- 发音评分和 ASR 涉及音频外发或本机模型选择，必须独立方案并完成隐私审查后才能进入实现。

## 7. 状态归属与投影边界

- 录音、回放、示范播放和完成状态以主区 `PracticeSessionView` / action seam 为唯一事实源。
- iPad 学习面板和 macOS Inspector 只展示 route 级练习上下文和状态投影，不持有 recorder、文件 URL 或 GRDB repository。
- 练习列表与单句页在 macOS 使用 dedicated main scrolling，不被工作台外层 `ScrollView` 再包裹。
- `learningPracticeReadiness(for spaceID:) -> [String: Bool]` 是时间线"待练习"筛选的只读投影查询（`EntryTimelineFilter.needsPractice`），通过 LEFT JOIN `learning_materials / practice_sessions / practice_recordings / media_artifacts` 链批量推导每个 Entry 的完成录音状态：字典缺失 entry key = 无学习材料；值 `false` = 有材料但无 completed recording（`completed_recording_id IS NULL`）；值 `true` = 有完成录音。该查询是只读派生投影，不写入任何练习状态；真实完成状态更新仍以 `PracticeActions` seam 为事实源。
- `completedSentenceIDs(materialID:exerciseType:)` 是句子列表级别的只读投影，只服务当前 material + 当前 exercise type，不替代 `learningPracticeReadiness` 的 Entry 级筛选语义。

## 8. 验证入口

- 单元测试落点：`Packages/LangoTraceUI/Tests`（route seed、presentation model、状态映射、本地化 key）、`Packages/LangoTraceData/Tests`（practice repository、completed recording 语义）、`Packages/LangoTraceSpeech/Tests`（录音与音频校验 seam）。日常采用对应 package 的轻量验证。
- 真实设备麦克风、回放音频路由和三端布局仍需人工验收，验收记录按 [009：测试与验证入口规范](009-testing-and-verification.md) 落入 testing 文档或任务方案。

## 9. 变更记录

- 2026-06-11：创建练习学习域规范。原因：练习域的模型契约、route seed、隐私边界和扩展边界分散在页面清单、spec 003 和架构备忘录中，听写 / 回译等扩展落地前需要一份汇集的领域规范；本文档为既有已确认事实与边界的汇编，不引入新的产品决策。影响范围：后续练习相关任务的设计输入和检查清单。是否需要 ADR：否，沿用本地优先、用户显式触发和三端共享业务逻辑决策。
- 2026-06-17：§7 新增 `learningPracticeReadiness` 只读投影查询说明。原因：E1 时间线与筛选方案在 Data 层新增了该查询作为"待练习"筛选的真实数据投影，其语义（`completed_recording_id IS NULL`）属于练习域范围；写入规范防止后续误将其用于写路径或与 `PracticeSessionView` 更新路径混淆。影响范围：时间线筛选、后续听写 / 回译等扩展的"是否有完成录音"查询。是否需要 ADR：否。
- 2026-06-16：§5 新增 iOS 录音会话选项约束。原因：bug 修复揭示 `.allowBluetoothHFP` 会激活 BT HFP 双向通道污染后续 TTS 播放；该约束应沉淀到练习域规范，防止后续扩展（听写 / 回译录音等）重犯同类问题。影响范围：练习录音基础设施、后续听写 / 回译录音扩展。是否需要 ADR：否，沿用现有约束并交叉引用 spec/011 §13。
- 2026-06-18：§2 / §6 同步 E4 听写落地事实。原因：E4 落地听写本机对照闭环，新增 `practice_text_attempts`（v23）文本 attempt 主数据、`PracticeDictationDiff` Core 纯函数对照、听写会话视图与 attempt 持久化，并把 `createOrRestoreShadowingSession` 泛化为 `createOrRestoreSession`；§2 补文本 attempt 模型与已练派生扩展，§6 写入 E4-D1 声学/词汇层对照契约并把听写从“未实现”转为已落地。影响范围：句子列表 mode 可用性、听写会话、attempt 隐私边界、后续 E5 回译复用同表。是否需要 ADR：否，沿用本地优先、用户显式触发、不做机械评分决策。
- 2026-06-17：§2 / §3 / §6 / §7 同步 E3 练习方式路由基础事实。原因：`PracticeExerciseType` 已扩展三种稳定 rawValue，v18 migration 扩展了 `practice_sessions.exercise_type` CHECK 约束，句子列表新增 mode availability、已练投影和续练 CTA；写入规范防止 E4 / E5 误读为可直接点亮未实现入口。影响范围：Practice route seed、PracticeActions seam、GRDBPracticeRepository、句子列表 UI 和后续听写 / 回译方案。是否需要 ADR：否，沿用三端共享业务逻辑与本地优先录音边界。
