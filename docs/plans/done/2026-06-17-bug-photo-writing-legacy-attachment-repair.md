# 任务方案：照片写作旧数据附件修复与运行验证

状态：Verified
自审核状态：Reviewed
类型：bug
创建日期：2026-06-17
最后更新日期：2026-06-17

## 用户确认记录

2026-06-17：用户在 iPhone 17 模拟器实测后反馈照片详情问题仍未彻底解决，要求调用专业 skill 深入分析，修复后进行实际测试和验证。该指令授权在本 bug 范围内继续实现、测试和模拟器验证。

## 1. 需求或 bug 描述

照片写作详情页修复后，运行态仍出现旧照片记录无法展示具体图片的情况。当前最新新建记录可以显示图片，但旧记录存在 `photoWriting` entry 无 `entry_photo_attachments` 关联的问题。

## 2. 现状与证据

- 当前模拟器数据库已包含 `v19_ensure_entry_photo_attachments` migration 和 `entry_photo_attachments` 表。
- 最新记录 `山海河流，壮丽景色` 有 attachment row 和 `entryPhotoOriginal` media artifact，详情页能渲染图片。
- 旧记录 `这一片是树叶`、`图片记录测试` 仍没有 attachment row。
- 当前媒体目录残留了不在 `media_artifacts` 表中的 `entryPhotoOriginal` / `entryPhotoThumbnail` 文件，说明旧导入流程可能在 metadata 事务失败后没有清理已移动到永久目录的文件。

## 3. 目标

1. 对 legacy 数据中“已有 `entryPhotoOriginal` media artifact metadata，但缺少 `entry_photo_attachments` row”的情况新增 repair migration。
2. 修正 `PhotoImportPipeline`，metadata 事务失败时清理已经移入永久目录的 original / thumbnail 文件，避免继续制造孤立照片文件。
3. 运行 Data / UI 聚焦测试，并将最新构建安装到 iPhone 17 模拟器后做真实数据库与页面验证。

## 4. 范围

- `Packages/LangoTraceData/Sources/LangoTraceData/AppDatabase.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/PhotoImportPipeline.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/MediaArtifactPhotoMigrationTests.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/PhotoImportPipelineTests.swift`

## 5. 不做什么

- 不用文件名或文件创建时间猜测旧孤立文件属于哪条 entry；没有数据库 metadata 的历史文件不能安全恢复为用户主数据。
- 不改变照片本地优先和不发送 AI Provider 的隐私边界。
- 不运行本机全量 `scripts/verify.sh`，除非后续用户明确要求。

## 6. 根因分析

根因分成两层：

1. 已修复的 v19 只补建缺失表，但没有补齐“已有 media artifact metadata、缺 attachment row”的旧库状态。
2. `PhotoImportPipeline` 在永久文件 move 成功后才进入 metadata 事务；如果事务失败，当前 defer 只清理 staging，不清理已经移入永久目录的文件，导致后续无法仅靠数据库恢复旧图。

置信度：90%

置信度依据：当前模拟器数据库和文件目录均支持上述判断；最新记录已正常显示，旧记录缺 attachment。剩余 10% 风险是用户反馈可能还包含 UI 视觉/布局问题，需要模拟器复测确认。

## 7. TDD / 测试落点

- `MediaArtifactPhotoMigrationTests.v20RepairMigrationBackfillsAttachmentsFromExistingPhotoArtifacts`
  - 先失败原因：当前没有 v20 repair migration，不会从既有 `media_artifacts` 生成 attachment row。
- `PhotoImportPipelineTests.metadataFailureRemovesMovedPermanentPhotoFiles`
  - 先失败原因：当前 metadata 失败后 original / thumbnail 永久文件会残留。

聚焦验证命令：

```bash
swift test --package-path Packages/LangoTraceData --filter MediaArtifactPhotoMigrationTests
swift test --package-path Packages/LangoTraceData --filter PhotoImportPipelineTests
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests
```

## 8. 实施方案

1. 新增 v20 migration：在 `entry_photo_attachments` 已存在时，从 ready、未 invalidated 的 `entryPhotoOriginal` media artifact 中，为仍缺 attachment 的 entry 创建 repair row；thumbnail 通过同 entry 的 ready thumbnail artifact 关联，宽高保持 `NULL`。
2. 在 `PhotoImportPipeline` 中跟踪已移动的永久路径；metadata 事务失败或后续失败时，同时清理 permanent original / thumbnail。
3. 运行聚焦测试。
4. build 并安装 iPhone 17 模拟器，打开最新 App 后查询 `grdb_migrations`、`entry_photo_attachments` 和最新 photoWriting 记录，再人工确认详情页图片。

## 9. 严格方案自审核记录

审核日期：2026-06-17
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：当前任务是复发 bug 的窄范围修复，主会话已基于模拟器数据库、代码和测试落点完成审查。

发现摘要：

- [P0] 不能把旧孤立文件按时间猜测绑定到 entry。处理：明确不做，避免错误关联用户主数据。
- [P1] 只补 attachment row 不够，导入失败仍会继续留下孤立永久文件。处理：加入 pipeline cleanup 测试与实现。
- [P1] 需要真实模拟器验证，不能只看 build pass。处理：完成后重装运行最新构建并查 live DB。
- [P2] 本机全量验证成本高。处理：按入口规则跑 Data / UI 聚焦测试和 iOS build/install，不主动跑 `scripts/verify.sh`。

写回修改：已写入目标、非目标、TDD 落点、验证命令和剩余风险。
仍需用户确认的问题：无，用户已明确要求继续修复并实际验证。
是否允许进入实现：是。

## 10. 文档影响检查

本次属于数据库 repair migration 和导入失败清理补强。若实现完成，应更新当前方案实施记录；如长期事实源需要补充“legacy repair”边界，再更新 `docs/spec/007-data-storage-migration-export-and-attachments.md` 或 `docs/spec/media-artifacts/impl.md`。

## 11. 完成标准

- 新增测试先失败后通过。
- Data / UI 聚焦测试通过。
- iPhone 17 模拟器安装最新构建后，最新照片写作记录有 attachment row 且详情页显示图片。
- 对无 metadata 的旧孤立文件给出明确说明：不能安全自动恢复，但后续不会继续产生。

## 12. 实施记录

2026-06-17：

- 新增 `v20_backfill_entry_photo_attachments_from_media_artifacts` migration：对已有 ready `entryPhotoOriginal` media artifact metadata 但缺少 `entry_photo_attachments` row 的旧库状态生成 repair attachment row，并关联同 entry 的 ready thumbnail。
- 修正 `PhotoImportPipeline`：跟踪已经 move 到永久目录的 original / thumbnail 路径；metadata 事务失败时删除这些永久文件，同时保留原 staging cleanup，避免继续产生“有文件但无 metadata / attachment”的孤立状态。
- 新增回归测试：
  - `MediaArtifactPhotoMigrationTests.v20RepairMigrationBackfillsAttachmentsFromExistingPhotoArtifacts`
  - `PhotoImportPipelineTests.metadataFailureRemovesMovedPermanentPhotoFiles`
- 真实 iPhone 17 模拟器验证：
  - build 产物安装到 `CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C` 并启动。
  - live DB 已记录 `v20_backfill_entry_photo_attachments_from_media_artifacts`。
  - 最新记录 `山海河流，壮丽景色` 有 attachment row 和 original artifact，详情页显示大图，accessibility image 为“已选照片”。
  - 旧无 metadata 记录 `这一片是树叶` 显示“照片缺失”可见降级态，不再静默空白。

验证命令与证据：

```bash
swift test --package-path Packages/LangoTraceData --filter MediaArtifactPhotoMigrationTests/v20RepairMigrationBackfillsAttachmentsFromExistingPhotoArtifacts
swift test --package-path Packages/LangoTraceData --filter PhotoImportPipelineTests/metadataFailureRemovesMovedPermanentPhotoFiles
swift test --package-path Packages/LangoTraceData --filter MediaArtifactPhotoMigrationTests
swift test --package-path Packages/LangoTraceData --filter PhotoImportPipelineTests
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests
xcodebuild -project LangoTrace.xcodeproj -scheme LangoTrace-iOS -configuration Debug -destination 'platform=iOS Simulator,id=CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C' -derivedDataPath build/DerivedData/LangoTraceRuntimeCheck build
xcrun simctl install CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C build/DerivedData/LangoTraceRuntimeCheck/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C com.zibuyu.LangoTrace
```

截图证据：

- `logs/iphone17-v20-photo-detail-loaded.png`
- `logs/iphone17-v20-photo-missing-state.png`

## 13. 剩余风险

旧版本已经留下且没有 `media_artifacts` metadata 的照片文件无法安全绑定回 entry；只能保证从本修复后不再制造这类孤立状态，并修复仍有 metadata 的 legacy 数据。
