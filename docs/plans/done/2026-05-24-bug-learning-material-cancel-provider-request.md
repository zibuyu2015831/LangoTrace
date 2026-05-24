# 学习材料生成取消应终止实际 Provider 请求 Bug 修复方案

状态：Verified
类型：bug
创建日期：2026-05-24
最后更新日期：2026-05-24
关联审查：`docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/reports/01-architecture-and-serious-bugs.md` `AUDIT-ARCH-004`

## 1. 用户确认记录

- 2026-05-24：项目级代码、文档与测试审查发现 `LearningContentStore.cancelLearningMaterialGeneration(for:)` 没有取消实际 Provider 请求任务，本方案作为 P1 bug 后续分流记录创建。
- 2026-05-24：深度复查确认问题真实存在；同时收紧方案表述：`LearningMaterialGenerationService` 已有 `AIProviderProbeHTTPClientError.cancelled -> .cancelled` 映射，修复重点是 UI / App action 任务取消传播、取消回归测试和 App action 中普通 `CancellationError` 的分类一致性。
- 2026-05-24：用户要求立即修复审查发现项；本方案进入实施并完成验证。

## 2. Bug 描述

`LearningContentStore.cancelLearningMaterialGeneration(for:)` 当前只更新 UI 状态并记录取消 operation，不取消已经启动的学习材料生成 / 分析 async 调用。真实 App action 会解析 Keychain secret 并调用 `LearningMaterialGenerationService` 发送 Provider 请求，因此用户点击取消后，请求可能仍继续处理生活记录或学习文本，最后只是因为 operation ID 不匹配而丢弃晚到结果。

这违反 AI 请求边界中的用户控制预期，也会带来额度消耗和诊断语义问题。

## 3. 复现方式

推荐先写自动化回归：

1. 构造一个 `LearningMaterialGenerationActions.generateMaterial` fake，在闭包内部挂起并记录当前 Swift task 是否收到 cancellation。
2. 通过 `LearningContentStore.generateLearningMaterial(for:languageSpace:)` 启动生成。
3. 等 fake action 确认开始执行后，调用 `cancelLearningMaterialGeneration(for:)`。
4. 断言 fake action 观察到 `Task` cancellation，而不是只收到 `cancelOperation` 记录。
5. 对 `analyzeCurrentLearningText(for:languageSpace:)` 重复同样验证。

人工验证：

1. 配置可观察请求的 OpenAI-compatible Provider。
2. 在记录详情触发学习材料生成或重新分析。
3. 请求进行中点击取消。
4. 验证 UI 保持取消状态，operation 摘要为 cancelled；Provider 侧不应继续完成同一请求或继续保存 material。

## 4. 预期行为

- 用户取消生成或分析后，正在运行的 provider request 必须被实际取消。
- 取消后不得继续保存 material、替换 analysis 或刷新 UI 为生成成功。
- 取消路径应记录 `.cancelled` operation，且不把 Swift task cancellation 误记为 `.unknown`。
- 取消行为必须覆盖 generate 和 analyze 两条路径。

## 5. 实际行为

当前 `LearningContentStore` 只保存 `RunningLearningMaterialOperation` metadata，不保存可取消的 `Task` handle。取消时只清空 metadata、更新 UI 状态并调用 `generationActions.cancelOperation` 记录 operation；已经在执行的 `generateMaterial` / `analyzeCurrentText` async 调用不会因此收到 `Task.cancel()`。

## 6. 根因分析

生成 / 分析 operation 被建模为一次直接 `await generationActions...` 调用，operation identity 只用于晚到结果保护。取消 API 没有可触达的运行任务，也没有把取消信号传入 App action 或 HTTP client。现有测试覆盖的是“取消后晚到结果被丢弃”，不是“底层请求被取消”。

## 7. 置信度

置信度：90%

## 8. 置信度依据

- `LearningContentStore` 代码中没有生成 / 分析任务句柄，`cancelLearningMaterialGeneration(for:)` 无法调用 `Task.cancel()`。
- 现有测试只通过 gate 释放晚到结果，断言 UI 丢弃结果和 `cancelOperation` 被调用，没有检查 fake action 是否收到 cancellation。
- `AppEnvironment` 真实 action 会解析 Keychain secret 并调用 `LearningMaterialGenerationService.generate/analyze`。
- `LearningMaterialGenerationService` 已有 HTTP client cancelled 分类映射，说明底层可表达取消；当前缺口集中在任务取消传播和 App action 分类一致性。

## 9. 备选原因

- 如果调用方外部持有并取消了包裹 `generateLearningMaterial` 的 Swift task，底层 await 可能收到 cancellation；但当前 UI 取消按钮没有连接这个 task handle，不能作为用户取消语义的实现。
- 如果网络请求已经到达 Provider，取消可能无法保证 Provider 不计费或不处理；但 App 仍应尽早取消本地任务、URLSession request、后续持久化和 UI 状态。

## 10. 现状描述

学习材料生成和分析已经通过 App action 接入真实 AI Provider 路径；本地 preflight、operation 摘要、late result 丢弃和 `.cancelled` UI 状态已有基础。风险集中在“用户点击取消”没有终止实际运行任务。

## 11. 目标

1. 用户取消生成或分析后，正在运行的 provider request 必须被实际取消。
2. 取消后不得继续保存 material、替换 analysis 或刷新 UI 为生成成功。
3. 取消路径应记录 `.cancelled` operation，且不把 Swift task cancellation 误记为 `.unknown`。
4. 取消行为必须覆盖 generate 和 analyze 两条路径。

## 12. 范围

修改范围：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/LearningMaterialGenerationServiceTests.swift`（仅补取消分类回归测试时）
- 本方案和项目级审查 round 对应记录

## 13. 不做什么

- 不改变 Prompt 内容、Provider schema 或 AI Provider 设置页。
- 不实现请求日志 UI。
- 不引入后台任务队列或多 entry 并发调度器；本修复只闭合当前 per-entry 取消语义。
- 不保证已经被 Provider 接收的远端请求一定免计费；本地可控范围是取消 URLSession task、停止后续保存和准确记录状态。

## 14. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:167-186`：生成路径创建 operation 后直接 `await generationActions.generateMaterial(...)`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:251-266`：分析路径同样直接 `await generationActions.analyzeCurrentText(...)`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift:288-302`：取消路径只清空 running metadata、设置 cancelled state 并调用 `cancelOperation`。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift:178-206`：现有测试验证 late result 被丢弃，不验证底层任务取消。
- `LangoTraceApp/AppEnvironment.swift:196-215`、`317-336`：真实 action 会 resolve secret 并调用 Provider service。
- `Packages/LangoTraceAI/Sources/LangoTraceAI/LearningMaterialGenerationService.swift:116-119`、`567-574`：HTTP client cancellation 已可映射为 `.cancelled`，但仍需要回归测试和 App action 层任务传播。

## 15. 参考的代码文件路径

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderProbeHTTPClient.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/SentenceTTSGenerationService.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/SentenceTTSGenerationServiceTests.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LearningMaterialGenerationModels.swift`

## 16. 涉及的文档路径

- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/reports/01-architecture-and-serious-bugs.md`
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/reports/06-deep-recheck-of-findings.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/009-testing-and-verification.md`

## 17. 实施方案

### 17.1 测试优先

先写失败测试：

- 生成请求取消后，fake generation action 能观察到 task cancellation。
- 分析请求取消后，fake analysis action 能观察到 task cancellation。
- 取消后的 late result 不保存 rendering，且 operation 状态保持 cancelled。
- App action 或 AI service 遇到 `CancellationError` / `AIProviderProbeHTTPClientError.cancelled` 时记录或返回 `.cancelled`，不落入 `.unknown`。

### 17.2 最小修复候选

候选 A：让 `LearningContentStore` 为每个 entry 的生成 / 分析 operation 持有 `Task`，取消时调用 `Task.cancel()`。

优点：用户取消按钮能直接终止当前 store 启动的任务，行为清晰。
风险：需要避免把 `@MainActor` store、Task 生命周期和 Published 状态更新搅在一起；任务完成、取消、deinit 和语言空间切换都要清理 handle。

候选 B：把 `LearningMaterialGenerationActions` 改造成返回可取消 operation handle，store 只保存 handle。

优点：取消语义更显式，App action 可以统一处理 HTTP / persistence 取消。
风险：action contract 变动更大，影响 UI tests 和 AppEnvironment 装配。

推荐先评估候选 A；如果实现后无法可靠把取消传播到 App action / URLSession，再提升为候选 B。

## 18. 复查方法

- 代码搜索确认 `cancelLearningMaterialGeneration(for:)` 会触发真实 task cancellation。
- fake action 测试确认 generate 和 analyze 都能观察到 cancellation。
- App action / service 测试确认 cancellation 分类为 `.cancelled`。
- 手动验证取消后不会保存 material、替换 analysis 或把 UI 刷回成功。

## 19. 回归测试方案

聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
swift test --package-path Packages/LangoTraceAI --filter LearningMaterialGenerationServiceTests
```

## 20. 验证命令

实施完成后至少运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
swift test --package-path Packages/LangoTraceAI --filter LearningMaterialGenerationServiceTests
scripts/verify.sh
git diff --check
git status --short
```

## 21. 文档影响检查

修复后检查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 是否需要补充“取消必须终止外部请求”的实现约束。
- `docs/spec/009-testing-and-verification.md` 是否需要加入 AI request cancellation 回归项。
- 项目级审查 round 中 `AUDIT-ARCH-004` 的后续覆盖记录是否需要标记为已修复。

## 22. 实施记录

- 2026-05-24：由项目级审查发现并创建本后续 bug 方案。
- 2026-05-24：深度复查后补齐 bug 方案必填结构，并收紧 cancellation mapping 表述。
- 2026-05-24：新增 UI 回归测试，先确认取消不会传播到底层 generation / analysis task；随后让 `LearningContentStore` 保存运行中 task 并在取消时调用 `Task.cancel()`。
- 2026-05-24：新增 Data 回归测试，确认 operation 摘要中 `cancelled` 为终态，不会被晚到的 `.failed(.cancelled)` 覆盖；随后更新 GRDB upsert 规则保持 cancelled 终态。
- 2026-05-24：将新增取消传播测试拆入 `LearningContentStoreCancellationTests`，避免扩大既有测试类型体积。
- 2026-05-24：通过聚焦测试、UI / Data 包测试和完整 `scripts/verify.sh` 验证。

## 23. 完成标准

- 失败测试先证明当前取消不会终止底层生成 / 分析任务。
- 修复后取消按钮能取消正在运行的生成 / 分析任务。
- late result 不保存、不覆盖 UI 成功状态。
- cancellation 在 operation 摘要和失败分类中保持 `.cancelled`。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- `swift test --package-path Packages/LangoTraceAI --filter LearningMaterialGenerationServiceTests` 通过。
- `scripts/verify.sh` 通过。
- 项目级审查 round 更新后续覆盖记录。

## 24. 验证结果

- `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreCancellationTests`：通过，2 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过。
- `swift test --package-path Packages/LangoTraceData --filter operationSummariesKeepCancelledAsTerminalStatus`：通过。
- `swift test --package-path Packages/LangoTraceData`：通过。
- `scripts/verify.sh`：通过，退出码 0。

## 25. 剩余风险

- 如果 URLSession client 没有正确响应 Swift task cancellation，UI 层取消仍可能无法终止网络请求，需要在 HTTP client 层补测试。
- 如果只取消 UI task 但 action 已经完成 secret resolve 并开始请求，必须确保取消信号能传到 send 调用。
- 取消和成功同时到达时，需要以 operation identity 和 task cancellation 双重约束避免状态回滚。
- Provider 已收到的请求可能仍在远端处理；本修复只能保证本地任务、HTTP client 和持久化链路尽早取消。
