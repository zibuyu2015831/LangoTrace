# learning-content 实现地图

状态：Current Implementation Map

最后更新：2026-05-18

## 1. 对应规范

- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`

## 2. 当前实现

- 内存学习内容模型和 repository：`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- Data 边界协议：`Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift`
- iPhone 记录创建和详情：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- Entry editor、detail 和 mock practice supporting views：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`

当前已经实现：

- `InMemoryLearningContentRepository.createEntry` 可创建 mock Entry。
- 创建 Entry 时生成 mock Rendering、Practice item 和 Memory item。
- iPhone 可通过记录创建 sheet 保存到内存 repository，并进入详情。
- Entry detail 可展示本地 mock 学习内容并进入 mock practice session。

## 3. 已知偏差

- `LanguageSpaceRepository` 仍是空协议。
- Entry、Rendering、Practice 和 Memory 没有 SQLite / GRDB repository。
- 没有真实持久化、启动恢复、附件关联、导出、删除恢复或迁移。
- Mock Rendering 不触发真实 AI Provider，也不代表请求预览、失败重试或日志链路已经完成。
- TTS、录音、Speech、OCR、照片和同步尚未接入。

## 4. 复查方法

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
rg "InMemoryLearningContentRepository|EntryEditorView|EntryDetailView|PracticeSession" Packages/LangoTraceData Packages/LangoTraceUI
scripts/verify.sh
```

如果 Data package 在某个阶段没有测试目标或没有测试用例，应在任务方案中记录实际 package 状态，并至少运行相关 UI / Core 测试和文档检查。
