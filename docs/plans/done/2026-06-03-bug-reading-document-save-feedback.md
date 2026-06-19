# Reading document save feedback bugfix

状态：Verified
自审核状态：Reviewed
类型：bug
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户在最新阅读编辑测试后反馈“编辑之后点击保存没有反应，检查最新日志进行排查”，随后明确要求“立即进行”。本方案将该授权收敛为一次保存失败链路 bugfix，范围限定为阅读文档编辑保存的错误反馈、空正文校验 UX 和对应测试，不扩展到新的编辑能力或日志基础设施重构。

## 1. 需求或 bug 描述

用户在 iPhone 阅读详情编辑文档后点击“保存”，界面没有明显反应。需要排查运行期日志与当前保存链路，修复真正的根因，并确保后续同类失败不再表现为静默无反馈。

## 2. 现状描述

- 阅读编辑 sheet 通过 `saveEdits` / `saveDetailEdits` 构造 `ReadingDocumentUpdateInput`，再调用 `ReadingLibraryStore.saveDocumentEdits(...)`。
- 当前 `catch` 路径只调用 `ReadingDocumentStore.failSavingEdit()`，`saveState` 仅变为 `.failed`，没有错误原因。
- 编辑 sheet 失败态当前显示的红字是 `settings.languageSpace.management.edit`，实际文案只是“编辑”，不是错误提示。
- Core 已经对空正文做了硬校验：`ReadingDocumentUpdateInput` 会在 `body` 去空白后为空时抛 `ReadingDocumentUpdateError.emptyBody`。
- 最新 `logs/latest.log` 没有应用级保存异常日志，只有键盘附件 Auto Layout warning 和触摸事件；这意味着保存失败更像是被 UI 静默吞掉，而不是点击手势未触发或数据库崩溃。

## 3. 目标

1. 保存失败时，编辑 sheet 必须向用户显示明确、可理解的错误文案。
2. 空正文必须在 UI 上得到前置约束，避免继续表现为“点击保存没有反应”。
3. 成功保存、取消编辑、重新打开编辑器时，失败态必须正确清理，不遗留过期错误。
4. 补齐可自动化测试，覆盖空正文失败和通用失败文案映射。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`
- 如有必要，补充读取层或展示层的轻量测试

## 5. 不做什么

- 不新增正文原位编辑模式或新的编辑入口。
- 不重构阅读诊断体系，也不引入跨模块统一错误总线。
- 不修改 repository update contract、数据库 schema 或文档 CRUD 范围。
- 不处理与本次症状无关的键盘 accessory Auto Layout warning。

## 6. 证据与决策依据

- 代码证据：
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift` 中 `saveEdits` / `saveDetailEdits` 的 `catch` 静默吞错。
  - `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift` 中失败态只有 `.failed`，没有错误原因。
  - `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift` 中 `ReadingDocumentUpdateInput` 会抛 `ReadingDocumentUpdateError.emptyBody`。
- 运行期证据：
  - `scripts/capture-runtime-log --last 30m` 生成的 `logs/latest.log` 未出现保存崩溃或 repository update 错误；仅见键盘 accessory warning 与触摸事件。
- 采纳的修复策略：
  - 将保存失败从“布尔失败态”升级为“可映射的失败原因”。
  - 在 UI 层前置禁用空正文保存，并在失败时显示本地化文案。

来源：runtime trigger
发现 ID 或 trigger ID：runtime-2026-06-03-reading-save-no-feedback
严重度：high
对应 work item：保存失败原因建模、空正文前置校验、失败文案展示、测试补齐
验证证据：聚焦 UI 测试、相关 package 测试、`scripts/verify.sh`

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingDocumentStoreAIAndTTSTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Reading/ReadingLibraryStoreTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

## 9. 涉及的文档路径

- `docs/plans/active/2026-06-03-bug-reading-document-save-feedback.md`
- 视实现结果决定是否需要同步 `docs/plans/done/2026-06-03-feature-reading-document-crud-foundation.md`

## 10. bug 分析

```text
复现方式：
1. 打开任一阅读文档详情。
2. 进入编辑 sheet。
3. 将正文清空或触发任一保存异常。
4. 点击“保存”。

预期行为：
保存成功时关闭编辑器并刷新正文；保存失败时明确提示原因，且用户知道下一步怎么修正。

实际行为：
点击保存后界面几乎无可见反馈，用户感知为“没有反应”。

根因分析：
保存链路在 UI 层把 `ReadingDocumentUpdateInput.emptyBody` 或 repository error 全部吞入同一个无文本 `.failed` 状态；编辑 sheet 又错误地用“编辑”文案充当失败提示，导致失败事实几乎不可见。

置信度：92%

置信度依据：
代码直接证明保存 catch 没有错误传播；Core 已有空正文硬校验；运行期日志没有按钮未触发或数据库崩溃证据。

备选原因：
1. 键盘 accessory warning 干扰 toolbar 交互。
2. 个别 repository 错误不是空正文，而是 soft-deleted 或其他 update failure。
这些备选原因不会改变“当前失败链路静默”的结论。

回归测试方案：
1. 新增 UI store 测试，验证空正文失败映射为明确错误 key。
2. 新增 UI store 测试，验证通用失败映射为通用错误 key。
3. 验证 begin/cancel/success 会清空旧失败态。
```

## 11. 实施方案

1. 先补 `ReadingDocumentStore` 失败态测试，覆盖空正文和通用失败映射，先看红测。
2. 在 `ReadingDocumentStore` 中引入阅读文档保存失败模型或错误 key，替换单纯 `.failed` 无上下文状态。
3. 更新 `ReadingViews.swift` 的编辑 sheet：
   - 展示明确失败文案；
   - `saveState == .loading` 时禁用保存；
   - 正文去空白后为空时直接禁用保存。
4. 补充本地化 key。
5. 运行聚焦测试与完整验证。

## 12. 严格方案自审核记录

```text
审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：单轮
未使用隔离审查的原因：问题边界单一，根因已由日志与代码路径直接收敛，优先快速进入 TDD 修复。
发现摘要：
1. 如果只在视图里补一行红字，不改变 store 错误模型，后续 iPad/macOS 仍会复用静默失败状态。
2. 如果只显示错误，不禁用空正文保存，用户仍会反复触发同一失败。
3. 如果不测试错误清理，旧失败态可能污染下一次编辑会话。
写回修改：
1. 将修复落点前移到 `ReadingDocumentStore`。
2. 明确加入空正文前置禁用。
3. 将“失败态清理”写进目标、实施方案和回归测试。
仍需用户确认的问题：无。用户已授权立即修复。
是否允许进入实现：允许
```

## 13. 复查方法

- 代码复查：确认保存失败不再只有裸 `.failed`，而是带明确错误映射。
- 交互复查：空正文时保存按钮不可用；失败时有可读文案；成功保存关闭编辑器；取消后旧错误不残留。
- 测试复查：新增测试先失败后通过，并且不破坏现有阅读 store 行为。

## 14. 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreAIAndTTSTests
swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
```

## 15. 文档影响检查

- 这是 bugfix，不改变长期产品或架构边界，预计不需要更新 spec / ADR。
- 若实现中改变了阅读编辑失败的事实表达，应在原 CRUD done plan 中补一条收口说明。

## 16. 实施记录

- 2026-06-03：根据用户测试反馈和 `logs/latest.log` 完成根因收敛，创建本 active plan，并将修复范围收敛为“保存失败反馈链路 bugfix”。
- 2026-06-03：先在 `ReadingDocumentStoreAIAndTTSTests` 中新增空正文失败和通用失败映射用例，确认红测后为 `ReadingDocumentStore` 增加 `ReadingDocumentSaveFailure`、失败态清理和 `canSaveDraft` 约束。
- 2026-06-03：更新 `ReadingViews.swift`，让编辑 sheet 直接展示失败文案，并在 loading 或空正文时禁用保存；同时将 `saveEdits` / `saveDetailEdits` 的 `catch` 改为透传错误。
- 2026-06-03：新增 `reading.editor.error.emptyBody` 与 `reading.editor.error.generic` 本地化文案。
- 2026-06-03：验证通过：
  - `swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStoreAIAndTTSTests`
  - `swift test --package-path Packages/LangoTraceUI --filter ReadingLibraryStoreTests`
  - `swift test --package-path Packages/LangoTraceUI`
  - `scripts/check-docs.sh`
  - `scripts/verify.sh`
  - `git diff --check`

## 17. 完成标准

- 阅读编辑保存失败时显示明确本地化错误文案。
- 空正文无法触发保存请求。
- 失败态在成功、取消和重新打开编辑器后正确清理。
- 聚焦测试和 `scripts/verify.sh` 通过。

## 18. 剩余风险

- 本次不会解决 UIKit 键盘 accessory warning；若后续仍出现“点击无响应”，需要单独针对 toolbar/keyboard 交互做运行期复现。
- 当前仍未引入专门的阅读编辑诊断事件；如果后续出现更深层 repository failure，仍需要第二轮日志能力补强。
