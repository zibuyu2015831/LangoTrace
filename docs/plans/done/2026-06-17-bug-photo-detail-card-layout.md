# 任务方案：照片记录详情图片卡片布局修复

状态：Verified
自审核状态：Reviewed
类型：bug
创建日期：2026-06-17
最后更新日期：2026-06-17

## 用户确认记录

2026-06-17：用户指出带图片记录详情页中“图片没有自动缩放，内容块被放大、没有边框”，并要求立即创建 active plan、完成自审，然后修复并在模拟器中截图验证。

## 1. 需求或 bug 描述

当前照片记录详情页虽然已经能显示照片，但视觉呈现仍像沉浸式 hero：图片使用 fill 裁切，顶部贴边，成功图片分支没有明显卡片边框；下方内容区域在同色背景上显得贴边、放大、层级不清。

## 2. 现状描述

- `EntryDetailPhotoSection` 的 loaded 分支使用 `photoImage.resizable().scaledToFill()`。
- loaded 分支只在外层做 `aspectRatio(4 / 3)` 和 `clipShape`，没有与缺失态一致的 background / stroke。
- `EntryDetailView` 本身是 `ScrollView` + `VStack`，整体 padding 存在，但顶部图片视觉太强，导致用户感知为图片和内容块缺少卡片边界。

## 3. 目标

1. 照片详情页成功加载图片时，图片应完整缩放显示，不裁切主体内容。
2. 图片区域应有明确卡片背景、圆角和边框，与缺失态视觉一致。
3. 图片高度应有上限，避免大图把首屏撑成 hero。
4. 保持现有照片加载、缺失态、失败态和隐私边界不变。
5. 重新 build、安装、运行 iPhone 17 模拟器并截图验证。

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailPhotoPresentation.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/EntryDetailPhotoLayoutTests.swift`
- 本方案和必要事实源文档。

## 5. 不做什么

- 不重做整个记录详情页信息架构。
- 不改变照片附件读取、迁移或数据库逻辑。
- 不新增图片全屏预览、图片编辑、多图布局或手势缩放。
- 不改变照片不发送 AI Provider 的边界。

## 6. 根因分析

根因是 loaded 图片分支的布局语义错误：它把详情照片当作顶部填充型 hero 图处理，而用户期望的是记录详情中的普通内容卡片。`scaledToFill()` 会裁切图片；loaded 分支缺少 `.background` / `.overlay stroke`，视觉上没有边框。

置信度：95%

置信度依据：截图现象与代码中的 `scaledToFill()`、缺少 loaded 分支边框完全匹配；数据链路已在前一任务验证正常。

备选原因：

- 系统导航栏透明叠在图片上加强了 hero 感，但主要问题仍是图片区 fill 裁切和缺少卡片 chrome。
- 文本卡片本身有 `.langoPanel`，但当前配色下边界弱；本轮先修图片卡片，若仍不满意再单独做详情页整体视觉任务。

## 7. 约束映射与验证路径

- active plan + 自审核：`docs/README.md`、`docs/plans/README.md`、`docs/plans/plan-review-protocol.md`。
- iPhone UI：`docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`。
- 轻量验证：本机跑 UI package 聚焦测试和 iOS build，不主动跑 `scripts/verify.sh`。

## 8. 实施方案

1. TDD：新增 `EntryDetailPhotoLayoutTests`，锁定 loaded 图片布局应为 fit、带 visible chrome、最大高度受限。
2. 实现：新增轻量 `EntryDetailPhotoLayout` presentation model，并在 `EntryDetailPhotoSection` 使用它。
3. 将 loaded 图片从 `scaledToFill()` 改为 `scaledToFit()`，放入有背景、描边、圆角、padding 的卡片容器。
4. 保持 missing / failed / loading 状态继续显示同一外层卡片 chrome。
5. 聚焦测试、clean build、安装、运行模拟器并截图验证。

## 9. 严格方案自审核记录

审核日期：2026-06-17
审核方式：主会话自审核
审核轮次：第一轮 + 第二轮
未使用隔离审查的原因：当前修复范围窄，用户明确要求立即推进；主会话已基于截图、代码和仓库规则完成自审。

发现摘要：

- [P0] 不能继续把问题误判为数据链路。证据：当前页面已有 `image Description: 已选照片`，问题是布局。处理：计划聚焦 UI presentation。
- [P1] 只改 `scaledToFit()` 不够，仍可能没有边框。处理：要求 loaded 分支使用和状态分支一致的 background / stroke。
- [P1] 视觉 bug 需要模拟器截图确认。处理：完成后 clean build、安装、运行并保存截图。
- [P2] SwiftUI 视觉细节难以完整单元测试。处理：用 presentation model 锁定核心意图，并以模拟器截图作为最终证据。

写回修改：已写入目标、范围、TDD 落点、验证命令和剩余风险。
仍需用户确认的问题：无，用户已明确授权立即修复。
是否允许进入实现：是。

## 10. TDD / 测试落点

新增：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhotoWriting/EntryDetailPhotoLayoutTests.swift`
- `loadedPhotoUsesFittedCardChrome`

先失败原因：当前没有独立 layout presentation model，且生产代码使用 fill 语义。

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoLayoutTests
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests
```

## 11. 文档影响检查

本轮改变照片详情当前事实，应更新 `docs/platform-page-inventory.md` 和 `docs/spec/learning-content/impl.md` 中照片详情展示描述。

## 12. 完成标准

- 新增测试先失败后通过。
- UI package 聚焦测试通过。
- iPhone 17 模拟器 clean build + install + launch 后截图显示图片完整缩放、带边框，不再是无边框 hero 裁切。

## 13. 实施记录

2026-06-17：

- 新增 `EntryDetailPhotoLayout` / `EntryDetailPhotoImageSizing`，将照片详情成功态布局意图固定为 fitted image、visible chrome、`280`pt 最大高度。
- 新增 `EntryDetailPhotoLayoutTests.loadedPhotoUsesFittedCardChrome`，先验证缺少 layout model 时失败，再实现通过。
- 将 `EntryDetailPhotoSection` 成功态从 `scaledToFill()` / 4:3 hero 改为 `scaledToFit()` + card background + rounded clipping + visible stroke + inner padding。
- 删除详情照片 layout 中未使用的 fill sizing 分支，避免后续误切回裁切填充语义；列表 44×44 缩略图仍保留 `scaledToFill()`。
- 加载中、附件缺失和解码失败态继续复用同一外层 card chrome，避免成功态和降级态视觉分裂。
- 更新 `docs/platform-page-inventory.md` 和 `docs/spec/learning-content/impl.md` 中照片详情展示事实。
- 修正 `PhoneIOSConvergenceTests` 中过宽的 `RoundedRectangle(cornerRadius: 12...)` 禁止断言，改为正向检查照片布局模型，避免误伤合法照片卡片 chrome。

验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoLayoutTests
swift test --package-path Packages/LangoTraceUI --filter EntryDetailPhotoPresentationTests
swift test --package-path Packages/LangoTraceUI --filter PhotoWriting
swift test --package-path Packages/LangoTraceUI
xcodebuild -project LangoTrace.xcodeproj -scheme LangoTrace-iOS -configuration Debug -destination 'platform=iOS Simulator,id=CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C' -derivedDataPath build/DerivedData/LangoTraceRuntimeCheck clean build
xcrun simctl install CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C build/DerivedData/LangoTraceRuntimeCheck/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C com.zibuyu.LangoTrace
xcrun simctl io CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C screenshot logs/iphone17-photo-detail-card-layout.png
```

截图证据：`logs/iphone17-photo-detail-card-layout.png`。截图显示照片完整缩放在带背景、圆角、描边和内边距的卡片内，下方文本块保留独立边框卡片层级，不再是无边框 hero 裁切。

## 14. 剩余风险

本轮只修照片卡片区域。若用户希望进一步调整整个详情页的信息密度、标题位置、tab bar 遮挡或内容卡片配色，应另起 UI 设计任务。
