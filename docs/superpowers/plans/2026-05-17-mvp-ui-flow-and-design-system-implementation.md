# MVP 页面闭环与设计系统实施计划

状态：Verified

日期：2026-05-17

关联文档：

- `docs/worklogs/2026-05-17-feature-ui-completeness-and-design-system-review.md`
- `docs/superpowers/specs/mvp-ui-flow-and-design-system.md`
- `docs/spec/003-ui-design-system.md`
- `docs/testing/README.md`

## 1. 目标

本计划执行规格中的第一批实现，范围保持在早期 MVP 可验证闭环：

- 建立 `Entry`、`Rendering`、`Practice`、`Memory` 的最小模型和内存 repository。
- 让 iPhone “写一句”进入记录编辑、保存、详情、mock rendering 和练习入口。
- 让 iPad 时间线选择驱动中栏和右栏内容。
- 扩展首批 design token，并抽取能复用的产品对象组件。
- 不接入真实数据库、真实 AI Provider、TTS、Speech、OCR、同步或 StoreKit。

## 2. 任务

### 2.1 数据模型与内存 repository

- 已完成：在 `Packages/LangoTraceData` 中新增最小学习内容模型。
- 已完成：增加 `InMemoryLearningContentRepository`。
- 已完成：为 repository 增加测试 target 和单元测试。
- 已保留：SQLite / GRDB 仍为空缺口，不引入迁移。

### 2.2 App 状态注入

- 已完成：扩展 `AppEnvironment`，注入学习内容 repository。
- 已完成：通过 root view 把 repository 传入 iPhone / iPad 主页面，页面进入后按当前语言空间 seed mock 内容。
- 已保留：不做启动恢复。

### 2.3 iPhone 页面闭环

- 已完成：将 `PhoneMainView` 从静态卡片切换为基于 repository 的列表与选中 Entry。
- 已完成：“写一句”打开 `EntryEditorView`。
- 已完成：保存后进入 `EntryDetailView`。
- 已完成：`EntryDetailView` 展示原文、mock rendering、句子对照、请求预览和练习入口。
- 已完成：AI Provider 未配置时明确显示 mock / 不发送。
- 已修复：模拟器冒烟发现普通 in-memory repository seed 后 UI 不刷新，已增加轻量 content revision 触发刷新。

### 2.4 iPad 工作台联动

- 已完成：`PadMainView` 使用 repository entries。
- 已完成：时间线项可选择，并更新中栏 Entry。
- 已完成：右栏按选中 Entry 展示请求预览、句子讲解和记忆提取。
- 已保持：面板收起逻辑保持现有行为。

### 2.5 设计系统基础

- 已完成：扩展 `LangoTraceDesign` 语义 token。
- 已完成：抽取第一批产品对象组件：`EntryTimelineRow`、`SentencePairView`、`RequestPreviewCard`。
- 已保持：视觉安静、克制，不做装饰性重设计。

## 3. 验证

开发中：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

收尾：

```bash
scripts/verify.sh
```

如完整验证因环境工具缺失失败，必须记录具体失败项和剩余风险。

## 4. 文档影响

实现完成后至少更新：

- 已更新：本计划状态和验证结果。
- 已更新：关联 worklog 的实施记录、文档影响检查和验证结果。
- 已更新：`docs/testing/README.md` 已补充模拟器截图验证要求。

## 5. 验证结果

2026-05-17 已执行：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
xcrun simctl install CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C com.zibuyu.LangoTrace
xcrun simctl io CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C screenshot /private/tmp/langotrace-ui-review/2026-05-17-iphone17-main-seeded.png
```

结果：

- Data package 测试通过，覆盖 seeded repository、创建记录和选择记录。
- UI package 测试通过，现有 iPad 面板手势测试保持通过。
- `scripts/verify.sh` 通过。
- iPhone 17 模拟器视觉冒烟通过：首次创建语言空间后主页面显示 seeded mock 记录，不再停留在空状态。
