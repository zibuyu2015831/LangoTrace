# 工作记录：iPad 产品级 UI 质量审查与优化

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/guidelines/002-navigation-and-routing.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `docs/worklogs/2026-05-17-feature-product-shell-navigation.md`
- `docs/worklogs/2026-05-17-feature-ios-ui-quality-pass.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

当前 iPad 端已经有三栏学习桌面骨架：左侧语言空间与时间线，中间双语正文和音频练习，右侧学习面板。这个方向符合产品定位，但目前实现仍偏静态原型：固定栏宽较硬、英文区块标题较多、顶部全局条缺失、设置入口和语言空间切换不够自然，整体还没有达到付费 iPad App 应有的沉浸写作与学习桌面质感。

用户要求针对 iPad 做一轮审查和优化。本次工作应延续 iPhone UI 质量优化后的视觉方向，但不能把 iPhone 单列体验简单放大；iPad 应成为语迹的“学习桌面”。

## 2. 目标

本次完成后，应达到以下可验证结果：

- iPad 页面从“静态三栏原型”提升为更接近真实产品的学习桌面。
- 顶部全局条清晰呈现当前语言空间、搜索入口、本地优先 / 未配置 AI 状态和设置图标。
- 左侧栏聚焦时间线、标签或记录选择，不重复堆叠多个语言空间卡片。
- 中间主区域突出双语写作和逐句学习，不像普通翻译工具。
- 右侧学习面板承载句子讲解、词句提取、练习入口、请求预览和长期记忆线索。
- 视觉语言与 iPhone 优化后的纸感、深松石、克制金色和安静资料库气质一致。
- iPad 横屏首屏信息密度合理，三栏不挤压主体阅读；窄宽度下至少不出现明显文字重叠或不可读。
- 保持当前 Mock 边界，不误导为真实 AI、TTS、同步或数据库已完成。

## 3. 范围

本次会处理：

- 优化 `PadMainView` 的整体结构和视觉层级。
- 增加 iPad 顶部全局条：
  - 语言空间胶囊。
  - 搜索占位。
  - 本地优先 / 未配置 AI 状态。
  - 设置图标。
- 优化三栏分工：
  - 左侧：时间线、筛选、记录列表。
  - 中间：当前记录、双语对照、音频与逐句练习。
  - 右侧：学习面板、词句记忆、请求预览。
- 尽量复用已有 `LangoTraceDesign` token 和现有共享组件。
- 适度调整 iPad 的 mock 文案，使其体现多语种和语言空间，而不是只像英语专用工具。
- 更新本 worklog 的实施记录和验证结果。

## 4. 不做什么

本次不处理：

- 真实 iPad 多窗口、Stage Manager 或外接键盘快捷键。
- 真实 NavigationSplitView 路由和记录选择状态。
- 真实搜索、过滤、标签系统。
- 真实 AI Provider、TTS、录音、听写、回译、OCR 或手写识别。
- 真实语言空间切换菜单。
- 数据持久化、同步、StoreKit 或权限弹窗。
- macOS 工作台优化。
- 完整深色模式。

## 5. 分析

### 5.1 当前主要问题

1. iPad 顶部缺少全局工作区条。语言空间、搜索、本地状态和设置入口没有形成稳定框架。
2. 左侧栏使用 `LEARNING LANGUAGE`、`TIMELINE` 等英文标题，与中文界面和产品气质不一致。
3. 中间区域现在像“翻译结果展示”，还不够像“生活记录 -> 目标语言学习材料 -> 逐句练习”的桌面。
4. 右侧学习面板只有解释、词句、练习三张卡，缺少请求预览、隐私边界和长期记忆线索。
5. 三栏宽度固定，iPad 横屏可用，但未来小尺寸 iPad 或分屏状态可能拥挤。
6. 设置按钮在左侧底部，和导航规范中“iPad 顶部全局条放设置图标”的方向不一致。

### 5.2 iPad 产品定位

iPad 不应只是 iPhone 的放大版。它最适合：

- 长文本写作。
- 图片和手写文章录入。
- 双语对照阅读。
- 分句朗读和跟读。
- 右侧解释、词句、记忆、请求预览。
- Apple Pencil 标注和校对。

因此 iPad 的 UI 应围绕“学习桌面”构建：中间是用户正在处理的生活记录，右侧是围绕该记录生成的学习辅助，左侧是记录时间线和筛选。

### 5.3 与产品愿景的关系

iPad 首屏要体现语迹不是普通翻译工具。它应该同时出现：

- 用户母语生活记录。
- 目标语言自然表达。
- 逐句学习结构。
- 音频 / 跟读入口。
- 词句记忆与长期记忆。
- 本地优先和请求边界。

这样用户能一眼理解：这是一个把生活内容变成学习材料的个人语言学习桌面。

### 5.4 可扩展点

本次布局应为后续能力预留位置：

- 图片附件和照片写作提示。
- 手写文章拍照录入与 OCR 校对。
- Prompt Preset 选择。
- 请求预览 Sheet 或 Inspector。
- 分句播放、循环、跟读录音。
- 词句收藏、错误模式和相似生活片段。
- iPad 分屏和窄宽度降级。

## 6. 方案

推荐采用“iPad 学习桌面质量打磨”的方案。

### 6.1 设计策略

- 保留三栏，但增加顶部全局条，形成真正的 iPad 工作区。
- 左侧栏减少卡片堆叠，改为更像列表的时间线与筛选。
- 中间主区以记录标题、上下文、双语对照、音频、逐句练习为主。
- 右侧面板加入学习状态、词句记忆、请求预览和隐私边界。
- 使用中文 UI 标题，不用大写英文区块标题作为主要结构。
- 避免过多阴影和卡片套卡片，让页面更安静、更专业。

### 6.2 替代方案

- 方案 A：只改颜色和间距。成本最低，但无法解决 iPad 工作区缺少顶部全局条和三栏职责不清的问题。
- 方案 B：完全重构为 `NavigationSplitView`。方向更原生，但当前阶段会引入更多路由和选中状态设计，容易超过 Mock 骨架范围。
- 方案 C：保留现有自定义三栏，补齐顶部全局条和产品级信息层级。推荐采用。

推荐方案 C。它能较快提升 iPad 观感和产品心智，同时不提前引入真实数据和复杂路由。

## 7. 风险与边界

- 风险：三栏信息过密，iPad 页面像后台管理系统。
  - 缓解：中间主区保持最大视觉权重，左侧和右侧降低对比度。
- 风险：为了展示功能而堆太多卡片。
  - 缓解：只展示当前记录相关的学习辅助，不做功能目录。
- 风险：布局仍使用固定宽度，未来分屏适配不足。
  - 缓解：本次先用合理的 `min/max` 和 `layoutPriority`，后续真实 iPad 适配阶段再引入响应式两栏/三栏切换。
- 风险：iPad 优化和 iPhone 视觉方向不一致。
  - 缓解：复用设计 token 和核心文案，但不复用 iPhone 单列结构。
- 风险：Mock UI 过真。
  - 缓解：保留 `未配置 AI`、`请求预览`、`不会发送` 等状态表达。

## 8. 测试与验证

完成前至少执行：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
git diff --check
```

手动验证：

- 在 iPad Pro 13-inch Simulator 启动 App。
- 完成首次创建语言空间后进入 iPad 主体页面。
- 确认顶部全局条可见，包含语言空间、搜索占位、本地状态和设置入口。
- 确认三栏职责清晰：左侧时间线，中间学习正文，右侧学习面板。
- 确认页面没有明显文字重叠、横向溢出或卡片套卡片观感。
- 截图保存 iPad 主体页用于回看。

## 9. 用户确认记录

2026-05-17：用户确认本方案，可以开始实现。

## 10. 实施记录

2026-05-17：已按方案完成 iPad UI 质量优化。

主要改动：

- `PadMainView`：
  - 增加 iPad 顶部全局条，包含语言空间、搜索占位、本地优先 / 未配置 AI 状态和设置按钮。
  - 左侧栏改为时间线 + 筛选，不再使用 `LEARNING LANGUAGE` / `TIMELINE` 等英文原型标题。
  - 中间主区保留双语对照、朗读音频和逐句练习，并强化“生活记录转学习材料”的文案。
  - 右侧学习面板补充当前句讲解、词句提取、练习入口、相似生活片段和请求预览。
  - 请求预览明确区分“即将发送”和“不会发送”，延续本地优先与隐私边界。
  - 设置入口移动到顶部全局条，符合 iPad 导航规范。
- 保留现有 Mock 边界：
  - 未接真实 AI、TTS、录音、OCR、数据、同步或路由状态。
  - 三栏仍为静态示例，不实现真实记录选择。

## 11. 验证结果

2026-05-17：已完成以下验证。

命令验证：

```bash
xcodegen generate
swift test --package-path Packages/LangoTraceCore
swiftlint --no-cache
swiftformat --lint . --cache ignore
xcodebuild -quiet -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
git diff --check
```

结果：

- `xcodegen generate` 成功生成工程。
- `swift test --package-path Packages/LangoTraceCore` 通过，4 个测试通过。
- `swiftlint --no-cache` 通过，0 violations。
- `swiftformat --lint . --cache ignore` 通过，0 个文件需要格式化。
- iPad Pro 13-inch (M5) Simulator 构建通过。
- `git diff --check` 通过。

模拟器验证：

- 已启动 iPad Pro 13-inch (M5) Simulator。
- 已安装并启动 `com.zibuyu.LangoTrace`。
- 首次引导页在 iPad 上可读，无明显重叠或溢出。
- 点击 `创建 英语 空间` 后进入 iPad 主体学习桌面。
- 主体页显示顶部全局条、左侧时间线 / 筛选、中间双语学习区、右侧学习面板。
- 页面中可见请求预览和本地优先状态，未误导为真实 AI 功能已完成。
- 已保存验证截图：
  - `/private/tmp/langotrace-ipad-ui-quality-onboarding.png`
  - `/private/tmp/langotrace-ipad-ui-quality-main.png`

剩余风险：

- 右侧学习面板信息密度略高，后续真实交互阶段可考虑折叠分组或 Inspector tab。
- 当前三栏仍为静态宽度，未实现分屏、窄屏或竖屏下的两栏降级。
- 当前仍为 Mock UI，未连接真实记录选择、搜索、AI 请求、TTS 或同步。
