# 06 审查结果深度复查

状态：Verified

## 1. 复查目标

本文件复查本轮项目级审查已经记录的问题是否真实存在、证据是否准确、严重度是否合理，以及后续优化方案是否符合 LangoTrace 的文档控制面、TDD、隐私和早期基础设施原则。

本轮仍不修改生产代码，只修正审查记录和后续方案中发现的不精确表述。

## 2. 复查命令与证据

- `git status --short`：当前变更集中在本轮审查 round、已完成审查 plan 和两个 P1 bug active plan。
- `swift test --package-path Packages/LangoTraceSync`：源码编译完成后失败，`error: no tests found; create a target in the 'Tests' directory`。
- `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`：通过，6 tests。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift:146-195`：`PlatformMainView` 用 `@StateObject` 初始化 `LearningContentStore(spaceID: languageSpace.id)`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:7-33`：`spaceID` 是私有常量。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:167-186`、`251-266`、`288-302`：生成 / 分析直接 await action，取消只记录 operation，不持有或取消 task。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift:116-119`、`567-574`：HTTP client cancelled 已能映射为 `.cancelled`。
- `Packages/LangoTraceSync/Package.swift:20-27`、`Packages/LangoTraceSync/Sources/LangoTraceSync/SyncBoundary.swift:1-5`：Sync package 只有 source target 和 disabled boundary。
- `scripts/verify.sh:8-18`：未运行 Sync package 测试或 Python tooling tests。
- `docs/README.md:78-119`、`docs/spec/007-data-storage-migration-export-and-attachments.md:11-36`、`docs/platform-page-inventory.md:48-49`、`docs/platform-page-inventory.md:224`：入口状态与当前 spec / 页面清单存在新旧事实混杂。

## 3. 逐项复查结论

| 问题 ID | 复查结论 | 描述准确性 | 方案可行性 | 调整 |
| --- | --- | --- | --- | --- |
| AUDIT-ARCH-004 | 成立 | 主问题准确：取消不终止实际生成 / 分析任务。需要补充 nuance：AI service 已有 HTTP client cancelled 分类映射，缺口主要是 UI / App action task cancellation 传播和回归测试。 | 可行。应先写 fake action cancellation 失败测试，再改 store/action contract；不能只保留 late result 丢弃。 | 已由 `docs/plans/done/2026-05-24-bug-learning-material-cancel-provider-request.md` 完成修复和验证。 |
| AUDIT-ARCH-003 | 成立 | 准确。`@StateObject` 生命周期没有显式绑定 `languageSpace.id`，`LearningContentStore.spaceID` 不可变，缺 root 级切换测试。 | 可行。`.id(languageSpace.id)` 是低风险候选，但必须验证运行中 generation / playback observation 清理；显式 `switchSpace` 是更完整但更大改动。 | 无需调整。现有方案已写明 85% 置信度和候选路径风险。 |
| AUDIT-ARCH-001 | 成立 | 准确。Sync package 在工程图中，但 SwiftPM package 没有 test target，统一验证脚本也不跑 Sync。 | 可行。先补最小 test target，再把 Sync test 加入 `scripts/verify.sh`；符合测试靠近模块原则。 | 无需调整。 |
| AUDIT-ARCH-002 | 成立 | 准确。App target tests 只有 `SentenceAudioPlaybackAssemblyTests` 两个测试，不能证明 `AppEnvironment.bootstrap()` 装配图。 | 可行。补 App 层 integration tests 合理，但应避免真实 Keychain、真实外部 Provider 和用户容器副作用。 | 无需调整。 |
| AUDIT-DOC-001 | 成立 | 准确。README 仍笼统写“真实数据 / AI / 语音之前”，同页又记录 AI Provider、TTS 和媒体缓存基础设施。 | 可行。应通过 docs active plan 更新入口事实源，区分已落地显式用户触发路径与仍未完成闭环。 | 无需调整。 |
| AUDIT-DOC-002 | 成立 | 准确。技术路线 Phase 0 仍写数据层、AI、TTS 和核心学习闭环待设计，与当前 spec、页面清单和测试事实不一致。 | 可行。应与 README 状态对齐，不把未完成同步 / StoreKit / 录音等能力误写成已完成。 | 无需调整。 |
| AUDIT-DOC-003 | 成立 | 准确。测试手动清单仍写 learning content 是内存 repository、`听` 不触发 TTS，已落后于 GRDB learning content 与逐句 TTS 播放路径。 | 可行。更新 checklist 即可，保留无自动触发、照片 / 录音 / 同步未接入等边界。 | 无需调整。 |
| AUDIT-INFRA-001 | 成立 | 准确。Sync UI mock 已较具体，但 Sync package 只有 disabled boundary。 | 可行。真实同步前先冻结 domain model 和 test boundary，符合早期基础设施长期正确原则。 | 无需调整。 |
| AUDIT-TEST-001 | 成立 | 准确。`scripts/verify.sh` 可通过，但没有覆盖 Sync 和 Python tooling；SwiftLint warning 策略也未形成清晰门禁口径。 | 可行。Sync test target 补齐后再加入脚本；Python tooling 可加入脚本或在 testing 文档中明确为专项验证。 | 无需调整。 |

## 4. 四维切片

- 并发 / 性能边界：`AUDIT-ARCH-004` 是真实并发取消缺口；`AUDIT-ARCH-003` 在语言空间切换时还牵涉运行中 generation 和 playback observation 清理。两个 P1 都应先写失败测试再改实现。
- 异常边界：取消请求方案需要区分 UI cancelled、Swift `CancellationError`、HTTP client cancelled 和 Provider 已接收请求后的不可控远端副作用；App 层集成测试应覆盖 unavailable repository / disabled service 边界。
- 状态同步：`LearningContentStore` 与 `LanguageSpacePreview` 的身份同步是核心模型隔离问题；README、技术路线和 testing checklist 是文档状态同步问题。
- 数据一致性：Sync test boundary、AppEnvironment 装配、LearningMaterial operation summary 和 language space isolation 都影响后续真实数据可信度；当前整改拆分符合“先冻结边界，再扩展真实能力”的项目原则。

## 5. 复查后的整改顺序

1. 先处理 `AUDIT-ARCH-004`：AI 隐私和用户取消语义风险最高，且已有 active bug plan。
2. 再处理 `AUDIT-ARCH-003`：语言空间隔离是核心模型边界，影响记录、AI 和 TTS 上下文。
3. 同步启动文档状态对齐 plan：修 `docs/README.md`、`docs/technical-framework-roadmap.md`、`docs/testing/README.md`，避免新会话继续基于旧事实规划。
4. 在真实 Sync 前处理 `AUDIT-ARCH-001` / `AUDIT-INFRA-001`；在下一轮 App Shell 高风险装配变化前处理 `AUDIT-ARCH-002`。

## 6. 剩余风险

- 本轮只做代码和文档证据复查，未运行完整 `scripts/verify.sh`，也未做截图、真机、VoiceOver、Dynamic Type、Stage Manager 或真实 Provider 验证。
- `AUDIT-ARCH-003` 的实际 SwiftUI 运行表现仍需要修复任务中的回归测试或人工验证确认；当前结论是“没有显式保证，核心隔离不能依赖隐式重建”。
- `AUDIT-ARCH-004` 即使修复本地 task cancellation，也不能绝对保证 Provider 已接收请求后不计费或不处理；方案已将可控范围收窄到本地任务、HTTP client、持久化和 UI 状态。
