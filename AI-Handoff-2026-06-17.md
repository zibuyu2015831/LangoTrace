# LangoTrace 当前工作交接说明

生成日期：2026-06-17
适用仓库：`/Users/zibuyu/code/zibuyu/LangoTrace`
当前分支：`dev`

这是一份给后续 AI 接手当前工作的上下文文档。目标不是复述全部历史，而是把已经完成的工作、已验证事实、当前阻塞和下一步动作压缩成可直接执行的交接材料。

## 1. 当前主线状态

当前仓库处于一个连续推进中的开发阶段，最近一轮工作的核心分成两条线：

1. 继续推进 `docs/plans/active/2026-06-11-00-docs-series-progress.md` 指向的系列任务，当前仪表盘显示当前指针已经回到 `E4` 听写练习方向。
2. 处理中途插入的照片记录详情页问题，即“照片记录详情页没有展示具体图片”。

最近已经完成的两个重要交付：

1. 照片写作记录详情页补齐了图片展示链路的代码。
2. 练习模式路由基础已经完成并归档，当前只开放 `shadowing`，`dictation` 和 `backtranslation` 作为可扩展路由基础存在。

## 2. 已完成工作概览

### 2.1 照片写作详情页修复

这部分已经做过实现、测试和 Xcode build 验证。相关改动包括：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailPhotoPresentation.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingSaveCoordinator.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingActions.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/EntryDetailPhotoPresentationTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/PhotoWritingSaveFlowTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/EntryCreationFailureSurfaceTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`

修复目标是：

- 保存阶段不再“创建 Entry 后静默吞掉图片导入失败”。
- 详情页对照片写作条目展示一个明确的照片区域，而不是直接消失。
- 如果图片数据缺失、无法读取或无法解码，页面显示状态文案，而不是空白。

### 2.2 练习模式路由基础

这部分也已经做完并归档到 done 目录。涉及：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PracticeSession.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeRouting.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSentenceListPresentation.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViewModel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PracticeSessionViews.swift`
- `LangoTraceApp/PracticeActionsAssembly.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBPracticeRepository.swift`

当前现状是：

- `shadowing` 仍是实际启用模式。
- `dictation` 和 `backtranslation` 已作为路由/状态基础存在。
- UI 可以按练习模式切换句子列表和继续入口。

## 3. 最近的关键事实

### 3.1 Xcode build 已验证通过

我用 Xcode 对 iOS scheme 做过一次 build，构建成功。最初 build 失败的原因是：

- `LangoTraceApp/PracticeActionsAssembly.swift` 里 `createOrRestoreSession` 绑定闭包漏写了 `return`。

修复后 build 成功，日志已经落在 `logs/` 下，之前的 build 日志文件分别是：

- `logs/xcodebuild-ios-debug.log`
- `logs/xcodebuild-ios-debug-after-fix.log`

现在 build 层面没有源码级错误。

### 3.2 详情页“仍然没看到图片”的真实原因

这是当前最重要的根因。

我在正在运行的 iPhone 17 模拟器里查到了这些事实：

- 模拟器容器里确实有图片文件，路径在 `Library/Application Support/LangoTrace/MediaArtifacts/entryPhotoOriginal/...` 和 `entryPhotoThumbnail/...`。
- SQLite 数据库文件存在于：
  `.../Library/Application Support/LangoTrace/LangoTrace.sqlite`
- 但数据库里没有 `entry_photo_attachments` 表。
- `grdb_migrations` 已经记录了 `v17_add_photo_artifact_types`。

这说明当前模拟器数据属于“旧 v17 已经跑过，但当时还没有照片附件表”的状态。也就是说：

1. 图片文件导入过。
2. 关联照片附件的元数据表缺失。
3. 详情页通过 `GRDBEntryPhotoAttachmentRepository.photoRelativePath(forEntryID:)` 查不到路径，所以 UI 没法显示真实图片。

这不是单纯的 SwiftUI 渲染问题，而是数据库迁移状态问题。

### 3.3 还有一个运行态问题

我还确认到：

- 模拟器当前安装的 `LangoTrace.app` 可执行文件时间戳比最新 `DerivedData` build 产物旧。

这意味着即便 build 成功，模拟器里也可能还在跑旧安装包或旧状态。接手后需要重新安装/运行最新构建，再做验证。

## 4. 当前 workspace 状态

`git status --short --branch` 目前显示很多未提交改动，其中包括：

- 本轮 photo-writing / practice 路由相关改动
- 数据库迁移和测试改动
- 文档更新
- 之前就存在的脏文件

注意：

- `Packages/LangoTraceData/Sources/LangoTraceData/PhotoImportPipeline.swift`
- `docs/plans/active/2026-06-11-05-feature-reading-experience-completion.md`

这两个文件在我开始这轮交接前就是脏的，不应被随意回滚。

## 5. 证据位置

### 5.1 模拟器 App 容器

- App container:
  `/Users/zibuyu/Library/Developer/CoreSimulator/Devices/CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C/data/Containers/Data/Application/4948309C-ACAB-4A8B-B34D-D1B129A4E015`

- App bundle:
  `/Users/zibuyu/Library/Developer/CoreSimulator/Devices/CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C/data/Containers/Bundle/Application/62517389-D726-4A30-9A37-1391882BDBAA/LangoTrace.app`

- SQLite:
  `/Users/zibuyu/Library/Developer/CoreSimulator/Devices/CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C/data/Containers/Data/Application/4948309C-ACAB-4A8B-B34D-D1B129A4E015/Library/Application Support/LangoTrace/LangoTrace.sqlite`

### 5.2 相关日志

- 运行日志：
  `logs/runtime-20260617-161002.log`

- Xcode build 日志：
  `logs/xcodebuild-ios-debug.log`
  `logs/xcodebuild-ios-debug-after-fix.log`

### 5.3 可直接对照的关键表

- `entries`
- `grdb_migrations`
- `media_artifacts`
- `entry_photo_attachments`

在当前数据库里，`entry_photo_attachments` 不存在。

## 6. 当前最合理的下一步

如果后续 AI 要继续把“照片记录详情页看不到图片”这个问题彻底解决，建议按这个顺序做：

1. 新增一个新的 migration identifier，补齐 `entry_photo_attachments` 的创建逻辑，避免复用已经执行过的 `v17_add_photo_artifact_types`。
2. 用测试覆盖“旧数据库已执行过旧 v17，但附件表缺失”的修复路径。
3. 重新 build 并把最新 App 安装到模拟器，再检查详情页是否能读出图片。
4. 如果旧模拟器数据已经不可恢复，接受旧数据看不到图，但要保证新建的 photoWriting 记录能稳定显示。

## 7. 这次工作里已经完成的验证

已经做过的验证包括：

- `swift test --package-path Packages/LangoTraceUI` 相关聚焦测试
- `swift test --package-path Packages/LangoTraceData` 相关聚焦测试
- `xcodebuild -project LangoTrace.xcodeproj -scheme LangoTrace-iOS -configuration Debug -destination 'platform=iOS Simulator,id=CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C' build`
- 模拟器重启

其中 build 已通过，但模拟器运行态没有完成最终的“图片显示确认”。

## 8. 接手建议

1. 先不要改 `AI-Coding-Context`，这份文件之外不要动它。
2. 先解决数据库迁移缺表问题，再回到 UI 验证。
3. 不要假设“build 成功 = 运行中的模拟器一定是最新代码”。
4. 目前不建议回滚任何看起来像“多余”的数据库/练习路由改动，除非它们和新根因直接冲突。

