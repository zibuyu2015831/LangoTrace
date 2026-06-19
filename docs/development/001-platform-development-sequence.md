# 三端开发顺序方案

本文档记录语迹 LangoTrace 在 MacBook、iPad、iPhone 三端上的开发顺序策略。它用于指导 SwiftUI 工程初始化、MVP 范围控制和后续里程碑拆分。

## 1. 结论

语迹采用以下开发顺序：

```text
工程三端同时初始化；
核心学习闭环优先 iPhone + iPad；
Mac 第一阶段保持基础可运行，后续增强为语言资料库与创作工作台。
```

这不是“三端同时做完整功能”，也不是“先只做 iPhone 再补 Mac”。正确边界是：

- 工程、模块、target、构建验证从第一天支持 Apple 三端。
- 产品功能、交互打磨和真实使用闭环先集中在 iPhone 与 iPad。
- Mac 在早期不阻塞架构，但不承担 MVP 的完整功能压力。
- 开发顺序不等于公开发版顺序。工程支持三端，不代表首个收费公开版本必须同时宣传完整 Mac 体验。

本文档使用 `Stage` 描述平台推进顺序，避免和 [技术框架与开发路线参考](../technical-framework-roadmap.md) 中的 `Phase` 混淆。技术路线中的 `Phase 0：技术原型` 可以包含 SQLite、Provider、TTS 和一条学习闭环；本文档中的 `Stage 0：三端 App Shell` 只定义工程壳和平台边界。

## 2. 决策依据

### 2.1 为什么工程要三端同时初始化

语迹的首发定位是 Apple 三端收费 App。即使 MVP 功能优先 iPhone 与 iPad，工程初始化也必须同时覆盖 iOS、iPadOS 和 macOS。

原因：

- SwiftUI Multiplatform 的价值在于共享业务逻辑、模块边界、资源组织和构建配置。
- 早期同时验证三端 target，可以尽早发现依赖、资源、编译条件、权限声明和平台 API 差异。
- 如果 Mac target 后期才加入，可能反过来影响模块拆分、导航状态、窗口模型和数据层设计。
- 付费 App 需要从第一天保持工程可回放、可验证，而不是先做单端 Demo 再重构。

工程初始化阶段应至少做到：

- iPhone 可以构建和启动。
- iPad 可以通过 iOS target 自适应启动，并保留 iPad 专属布局入口。
- macOS 可以构建和启动。
- App shell、模块边界和 XcodeGen 配置不把业务逻辑绑定到单一平台。

第一阶段不创建独立 iPad target。iPad 作为 iOS target 的设备形态处理，通过 size class、idiom、NavigationSplitView 和平台布局分支获得专属体验。只有在后续出现明确的 entitlement、资源、发布或构建隔离需求时，才重新评估是否拆出独立 iPad target。

### 2.2 为什么 MVP 功能优先 iPhone + iPad

语迹的核心验证问题是：

> 用户是否愿意每天记录自己的生活，并把这些熟悉内容转化为目标语言学习材料。

这个闭环最容易先在 iPhone 和 iPad 上验证。

iPhone 的核心价值：

- 随手记录一句生活片段。
- 拍照生成写作话题。
- 通勤、睡前或碎片时间听一句、跟读一句。
- 快速查词、收藏表达、完成轻量复习。

iPad 的核心价值：

- 沉浸式写作。
- 双语对照阅读。
- 分句跟读、听写、回译。
- 图片写作、手写文章 OCR、Apple Pencil 标注。
- 更接近“学习桌面”的主力体验。

如果 MVP 同时追求 Mac 完整工作台，会明显拉长开发周期，并稀释最关键的产品验证。

### 2.3 为什么 Mac 后增强

MacBook 对语迹很重要，但它的价值更偏长期管理与深度创作，而不是第一天验证每日记录习惯。

Mac 适合承担：

- 多窗口编辑。
- 菜单栏与快捷键。
- Command Palette。
- 批量导入和批量导出。
- 高级搜索。
- 本地词典管理。
- Prompt Preset 管理。
- AI Provider 高级配置。
- 对象存储和同步配置。

这些能力适合在核心学习闭环跑通后再做。早期 Mac 只需要保持：

- 可以启动。
- 可以展示基础根界面。
- 可以读取共享状态或占位状态。
- 不阻塞后续扩展成桌面级工作台。

## 3. 阶段拆分

### Stage 0：三端 App Shell

目标：

- 建立可启动、可构建、可回放的 SwiftUI Multiplatform 工程。

范围：

- 使用 XcodeGen 管理 `project.yml`。
- 创建 iOS / iPadOS / macOS 可运行 App shell。
- 建立 App、Core、UI、Data、AI、Speech、Sync 的初始模块边界。
- 根界面展示产品名称和固定 slogan。
- iPad 与 Mac 保留差异化布局入口，但不做完整功能。
- 不接入真实数据库、真实 AI 请求、真实 TTS、真实同步和 StoreKit。

验证：

- `xcodegen generate` 成功。
- iPhone Simulator build 成功。
- iPad Simulator build 成功。
- macOS build 成功。
- `xcodebuild -list` 能列出 scheme。
- `git status --short` 没有意外临时文件。

### Stage 1：iPhone + iPad 核心学习闭环

目标：

- 验证“记录生活 -> 生成目标语言 -> 听读练习”的最小价值闭环。

范围：

- 首次启动询问母语、目标语言、水平自评。
- 创建第一个语言空间。
- 本地创建生活记录。
- 以“中文母语 -> 英语目标语言”作为首个验证样例。
- Prompt Preset 占位或最小实现。
- 双语对照展示。
- 系统 TTS 播放。
- 基础单词收藏。

语言边界：

- 首个验证样例可以使用中文到英语，因为它便于开发、测试和原型表达。
- 数据模型、Prompt Preset、语言空间、TTS 设置和 UI 文案不能硬编码中文或英语。
- 任意目标语言能力通过语言空间配置表达，英语只是第一条被验证的路径。

持久化边界：

- Stage 1 可以先用 InMemory Repository 或轻量本地持久化打通体验。
- 如果同一阶段引入 SQLite / GRDB，应作为单独 worklog 或实施计划处理。
- 不应为了完成 Stage 1 一次性实现迁移、FTS、向量索引、同步状态和完整附件管理。

Mac 状态：

- 保持可构建、可启动。
- 可展示基础占位界面或简化阅读界面。
- 不实现多窗口、复杂菜单、Command Palette、批量导入、批量导出、对象存储配置、同步冲突处理和高级管理。

### Stage 2：iPad 学习桌面

目标：

- 把 iPad 打磨成沉浸式学习主场景。

范围：

- 三栏布局。
- 右侧学习面板。
- 分句练习。
- Shadowing。
- 听写。
- 回译。
- 图片引导写作。
- 手写文章 OCR + AI 修改。
- Apple Pencil 标注。

### Stage 3：Mac 深度工作台

目标：

- 把 Mac 增强为高级付费用户的语言资料库与创作工作台。

范围：

- 原生 macOS 窗口体验。
- 菜单栏。
- 快捷键。
- Command Palette。
- 批量导入和导出。
- 高级搜索。
- 本地词典导入。
- Prompt Preset 管理。
- AI Provider 高级配置。
- 同步和对象存储配置。

## 4. 平台完成度定义

为了避免“支持三端”被误解，后续文档和里程碑应区分四级完成度：

```text
Buildable：可以编译通过。
Runnable：可以启动并显示根界面。
Usable：可以完成该平台的核心用户路径。
Shippable：达到可公开发版和收费宣传的完成度。
```

Stage 0 对三端的要求是 Buildable + Runnable。

Stage 1 对 iPhone 和 iPad 的目标是逐步达到 Usable；Mac 只要求保持 Buildable + Runnable。

Stage 3 之前，不应把 Mac 描述为完整 Shippable 的核心卖点。是否在首个公开收费版本中宣传 Mac，需要依据实际完成度决定。

## 5. 发版边界

开发顺序和 App Store 发版顺序需要分开判断。

可接受策略：

- 工程从第一天包含 iPhone、iPad 和 macOS target。
- 内部测试版可以三端都提供。
- 首个公开收费版本可以只重点宣传 iPhone + iPad 核心学习闭环。
- 如果 Mac 只达到基础可运行，不应在营销文案中承诺完整 Mac 工作台。

不应这样做：

- 因为 macOS target 能启动，就把 Mac 当作完整卖点上架。
- 为了追求“三端首发”牺牲 iPhone/iPad 的核心体验质量。
- 在 Mac 体验仍是占位时引导用户为 Mac 工作台能力付费。

## 6. 验证矩阵

不同 Stage 的验证要求不同。

```text
Stage 0：
- iPhone Simulator 构建和启动。
- iPad Simulator 构建和启动。
- macOS 构建和启动。
- xcodebuild -list 可列出 scheme。

Stage 1：
- iPhone 完成首次启动、语言空间创建、记录创建、学习材料展示。
- iPad 完成同一核心路径，并验证横屏布局。
- Mac 保持构建和启动，不要求完成核心学习路径。

Stage 2：
- iPad 真机或模拟器验证三栏、听读、听写、回译、图片和手写输入路径。
- 如涉及 Apple Pencil，应使用真机验证。

Stage 3：
- macOS 验证菜单栏、快捷键、多窗口、导入导出、搜索和高级设置。
```

涉及相机、麦克风、语音识别、照片权限、Apple Pencil 和真实 TTS 体验时，模拟器验证不够，应使用真机补充验证。

## 7. 工程约束

开发时应遵守以下约束：

- 业务逻辑不写死在 iPhone 页面中。
- iPad 和 Mac 不应只是 iPhone UI 的放大版。
- 平台差异通过 UI 层、Platform Adapter 或条件编译处理，不应污染核心领域模型。
- Core / Data / AI / Speech / Sync 模块应尽量保持平台无关。
- 相机、照片、麦克风、语音识别等权限能力必须通过明确服务边界进入功能。
- 第一阶段不要为了 Mac 工作台提前实现批量导入、复杂同步或完整 StoreKit。
- 公开发版能力必须以 `Shippable` 为标准，不能只以 `Buildable` 或 `Runnable` 为标准。

## 8. 不采用的方案

### 8.1 三端完整功能同时开发

不采用。

原因：

- 范围过大。
- 容易导致每端体验都不够精致。
- 延迟核心学习闭环验证。
- 会把 Mac 高级工作台复杂度提前引入 MVP。

### 8.2 只做 iPhone，后续再加 iPad 和 Mac

不采用。

原因：

- 后期加入 iPad 和 Mac 可能倒逼重构导航、模块、窗口和数据层。
- 容易形成移动端单点架构，不利于 Apple 三端付费 App。
- iPad 是语迹最重要的学习桌面之一，不应被视为简单附属端。

### 8.3 Mac 优先

不采用。

原因：

- Mac 更适合深度整理，不是验证随手生活记录的最短路径。
- 会弱化照片、碎片听读、移动复习等关键场景。
- 容易把产品带向知识管理工具，而不是生活驱动语言学习工具。

## 9. 复审条件

如果出现以下情况，应重新评估开发顺序：

- 早期付费用户明确以 Mac 重度写作和资料管理为主。
- iPhone 拍照记录和碎片练习验证失败。
- iPad 沉浸学习场景的真实使用频率低于预期。
- App Store 审核、平台权限或技术限制改变三端能力边界。
- 团队规模变化，需要按端拆分并行开发。
- 首个公开收费版本必须包含完整 Mac 能力。
- macOS SwiftUI、AppKit bridge 或 sandbox 限制造成 Mac target 长期拖慢核心闭环。

## 10. 与其他文档的关系

本文档是执行层方案，结论应与以下文档保持一致：

- [项目初始化规划](project-initialization.md)
- [技术框架与开发路线参考](../technical-framework-roadmap.md)
- [SwiftUI 架构规范](../spec/004-swiftui-architecture.md)
- [导航与路由规范](../spec/002-navigation-and-routing.md)
