# 03 规范文档与代码契合审查

状态：Verified

## 1. 审查目标

检查当前事实源、决策源、执行规则源和过程记录是否与代码、脚本、测试和 review 索引匹配，并区分“代码应修正”和“文档应更新”。

## 2. 已执行证据

- `docs/README.md:78-80` 仍概括为“真实数据、真实 AI、真实语音之前”，但同一文件 `docs/README.md:106-109` 又列出 AI Provider 合成测试、TTS Provider 配置、本地媒体和 TTS 音频缓存基础设施。
- `docs/README.md:115-119` 仍把真实生活记录闭环、Entry / Rendering / Practice / Memory schema、逐句播放 coordinator 和正式音频播放 UI 写入“尚未完成”。
- `docs/spec/007-data-storage-migration-export-and-attachments.md:10-37` 已明确 Entry、LearningMaterial、句子分析、candidate、operation 摘要和媒体派生资产已进入真实 GRDB / 本地媒体路径。
- `docs/platform-page-inventory.md:48-50`、`docs/platform-page-inventory.md:74-79`、`docs/platform-page-inventory.md:99-103` 已把三端记录详情、真实学习材料生成、取消、learning text 编辑、重新分析和逐句 TTS 播放记录为已接入。
- `docs/technical-framework-roadmap.md:856-861` 仍写“Core / UI 首批单元测试”“尚未完成 SQLite / GRDB 数据模型验证、真实 OpenAI-compatible Provider、系统 TTS 播放和记录生成目标语言并播放的闭环”。
- `docs/testing/README.md:179-182` 的三端页面闭环验证清单仍写 Entry / Rendering / Practice / Memory 是内存 repository，记录详情 `听` 只切换本地播放状态且不触发 TTS。
- `docs/platform-page-inventory.md:44-49` 和 `docs/platform-page-inventory.md:224` 已记录文本记录写入 GRDB learning content repository，逐句 `听` 进入真实 TTS generation / cache / playback path。

## 3. 问题清单

### AUDIT-DOC-001

问题 ID：AUDIT-DOC-001
严重度：P1
标题：入口 README 的项目状态同时包含新旧事实，误导“真实数据 / 真实 AI / 真实语音”边界
问题现状：`docs/README.md` 在总述中仍说项目处于真实数据、真实 AI、真实语音之前，并把真实生活记录闭环、Entry / Rendering / Practice / Memory schema、逐句播放 coordinator 和正式音频播放 UI列为未完成；但同一入口文档和长期 spec / 页面清单已经记录了 GRDB learning content、AI Provider 学习材料生成、TTS Provider 配置、媒体派生资产和逐句 TTS 播放。
证据：`docs/README.md:78-80`、`docs/README.md:106-119`；`docs/spec/007-data-storage-migration-export-and-attachments.md:10-37`；`docs/platform-page-inventory.md:48-50`、`docs/platform-page-inventory.md:74-79`、`docs/platform-page-inventory.md:99-103`。
影响范围：新会话入口、任务优先级判断、后续 active plan 创建、用户对当前能力的理解。最危险的是后续 AI 可能按 README 的旧总述重复规划已经落地的 GRDB learning content / TTS playback，或错误地把当前真实 AI/TTS 边界当作仍不存在。
涉及的代码文件路径：`LangoTraceApp/AppEnvironment.swift`、`Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`、`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`、`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`、`Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
涉及的文档路径：`docs/README.md`、`docs/platform-page-inventory.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/011-tts-provider-configuration-and-playback.md`
复查方法：对照 `docs/README.md` 当前状态段与 `docs/platform-page-inventory.md`、`docs/spec/007`、`docs/spec/011`；搜索 `逐句播放 coordinator`、`真实数据、真实 AI、真实语音`、`Entry、Rendering、Practice、Memory 的真实数据库 schema`。
优化方案：用户确认后更新 README 当前状态：区分“真实学习材料生成和逐句 TTS 播放已在显式用户触发路径落地”与“真实生活记录完整时间线、真实练习录音 / 评分、FTS、附件、同步、StoreKit 仍未完成”。不要把所有能力笼统写成“真实数据 / AI / 语音之前”。
影响：修正后，新会话能从入口准确判断哪些能力已是当前事实、哪些仍是后续路线。
所属维度：文档契合 / 基础设施
四维切片：状态同步 / 数据一致性
建议处理：用户确认后更新当前事实源；本轮只记录问题。
后续落点：`docs/README.md`，必要时创建 `docs` active plan 承接入口状态修正。
是否阻塞继续开发：阻塞以 README 为唯一入口的新任务准确分流；不阻塞代码运行。
需要用户确认：是，涉及入口当前事实源更新。

### AUDIT-DOC-002

问题 ID：AUDIT-DOC-002
严重度：P1
标题：技术路线 Phase 0 进度明显滞后于当前代码和 spec，仍把已落地基础设施写成未完成
问题现状：`docs/technical-framework-roadmap.md` 的 Phase 0 当前进度仍停留在“Core / UI 首批单元测试”和“数据层、AI、TTS、核心学习闭环仍待设计与实现”。这与当前 `scripts/verify.sh`、package 测试、GRDB learning content、真实 AI 学习材料请求、TTS 配置和逐句播放基础设施不一致。
证据：`docs/technical-framework-roadmap.md:856-861`；`scripts/verify.sh:8-16` 已覆盖 Core / Data / AI / Speech / UI 和 AppTests；本轮实跑 Core 76、Data 77、AI 74、Speech 13、UI 216、AppTests 2 全部通过；`docs/spec/007-data-storage-migration-export-and-attachments.md:10-37` 和 `docs/spec/011-tts-provider-configuration-and-playback.md:2-39` 描述当前已落地基础设施。
影响范围：路线规划、Phase 0 / Phase 1 切分、下一阶段优先级。旧路线会低估当前已落地基础设施，也会掩盖真正剩余风险：完整生活记录时间线、练习录音 / 评分、FTS、附件、同步、StoreKit 和发布验证。
涉及的代码文件路径：`scripts/verify.sh`、`Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`、`Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift`、`Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
涉及的文档路径：`docs/technical-framework-roadmap.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/011-tts-provider-configuration-and-playback.md`、`docs/testing/README.md`
复查方法：对照 `docs/technical-framework-roadmap.md:856-861` 与当前 `scripts/verify.sh`、spec 007、spec 011、页面清单和 package 测试输出。
优化方案：用户确认后更新 Phase 0 当前进度，把已落地项改为精确描述，并把未完成项收窄到仍未落地的生活记录完整时间线、Prompt Preset 执行、真实练习语音、FTS / 附件 / 导出、同步和 StoreKit。
影响：避免后续路线评审围绕过期状态展开。
所属维度：文档契合 / 基础设施
四维切片：状态同步
建议处理：用户确认后更新技术路线；本轮只记录问题。
后续落点：`docs/technical-framework-roadmap.md` 或独立 `docs` active plan。
是否阻塞继续开发：不阻塞短期代码；阻塞项目级路线判断和里程碑收口。
需要用户确认：是，涉及长期路线文档更新。

### AUDIT-DOC-003

问题 ID：AUDIT-DOC-003
严重度：P2
标题：测试手动验证清单仍按早期 mock 口径描述记录和逐句听读，落后于当前真实 GRDB / TTS 播放路径
问题现状：`docs/testing/README.md` 的“三端页面闭环验证清单”仍要求 iPhone 验证“当前 Entry / Rendering / Practice / Memory 仍是内存学习内容 repository”和“记录详情的 `听` 只切换本地播放状态，不触发 TTS”。这与页面清单、spec 和当前代码不一致：文本记录已保存到 GRDB learning content repository；逐句 `听` 已通过 AppEnvironment 装配的 TTS generation、local media artifact cache、Speech playback service 和 coordinator 执行真实播放路径。
证据：`docs/testing/README.md:179-182`；`docs/platform-page-inventory.md:44-49`；`docs/platform-page-inventory.md:224`；`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`；`LangoTraceApp/SentenceAudioPlaybackAssembly.swift`。
影响范围：人工验收、截图验证和阶段收口。后续如果按旧 checklist 验收，会把真实 TTS 播放误判为不应触发的副作用，也会漏测 GRDB learning content / media artifact / Provider 可用性边界。
涉及的代码文件路径：`Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`、`LangoTraceApp/SentenceAudioPlaybackAssembly.swift`、`Packages/LangoTraceCore/Sources/LangoTraceCore/SentenceAudioPlaybackCoordinator.swift`
涉及的文档路径：`docs/testing/README.md`、`docs/platform-page-inventory.md`、`docs/spec/011-tts-provider-configuration-and-playback.md`
复查方法：对照 `docs/testing/README.md` 三端页面闭环 checklist 与页面清单变更记录；搜索 `本地听读预览`、`不触发 TTS`、`内存学习内容 repository`。
优化方案：用户确认后更新测试手动验证清单：把记录创建改为 GRDB learning content repository 验证；把逐句 `听` 改为“无自动触发，用户点击后按已配置 TTS Provider / local artifact cache / playback seam 执行，并验证取消、失败、未配置和命中缓存状态”。同时保留照片写作、练习录音、导入导出和同步仍未接入的边界。
影响：测试文档能正确指导当前真实能力的人工验证，不把已落地能力当成 mock。
所属维度：测试文档 / 文档契合 / 三端验证
四维切片：状态同步
建议处理：纳入后续 docs status alignment 任务；本轮只记录问题。
后续落点：`docs/testing/README.md` 或独立 `docs` active plan。
是否阻塞继续开发：不阻塞代码；阻塞三端手动验收的准确性。
需要用户确认：是，涉及测试入口文档更新。

## 4. 修复后覆盖记录

- `AUDIT-DOC-001`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 修复。`docs/README.md` 已区分“显式用户触发的真实 GRDB learning content / AI 学习材料 / TTS 播放路径已落地”和“完整生活记录时间线、录音、同步、StoreKit 等仍未完成”。
- `AUDIT-DOC-002`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 修复。`docs/technical-framework-roadmap.md` 的 Phase 0 进度已对齐当前 Data / AI / TTS / testing 基础设施事实。
- `AUDIT-DOC-003`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 修复。`docs/testing/README.md` 已把记录创建和逐句 `听` 的人工验证口径更新为 GRDB learning content、TTS provider / local media artifact cache / playback seam。
- 验证：`scripts/verify.sh` 通过，文档占位扫描在完整脚本中通过。
