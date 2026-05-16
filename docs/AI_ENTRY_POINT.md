# 语迹 / LangoTrace AI 会话入口

本文档是后续 AI 辅助编程、产品讨论、技术评审和原型迭代时优先携带的入口文件。它的目标不是替代所有文档，而是让 AI 在每次新会话中先建立全局上下文，再按任务类型读取必要细节。

## 1. 使用原则

每次新会话应先阅读本文档，然后根据任务类型继续读取相关文档。

AI 不应只根据用户当前一句需求直接实现功能。涉及产品、数据、隐私、同步、AI 请求、付费、测试或发布的任务，都必须回到对应文档确认边界。

默认工作方式：

1. 先确认当前任务属于产品、原型、工程、架构、测试、发布或研究中的哪一类。
2. 按本文档的阅读路径读取相关资料。
3. 对照既有产品决策和 ADR，避免引入冲突概念。
4. 如果形成新的重要判断，更新对应文档，不只停留在聊天记录。
5. 完成前运行适合当前任务的检查，例如链接检查、文档一致性检查、构建或测试。

## 2. 项目当前状态

当前仓库处于从产品文档和静态 HTML 原型进入原生工程初始化的阶段。

已完成：

- 产品主参考文档。
- 技术框架与开发路线参考。
- 开发环境记录。
- 开源项目参考记录。
- 多端静态 HTML 原型。
- 文档体系、初始模块边界和关键 ADR。

尚未完成：

- SwiftUI Multiplatform 工程。
- XcodeGen `project.yml`。
- Swift Package 模块。
- 数据库 schema。
- AI Provider 代码。
- 同步引擎。
- StoreKit 配置。

如果后续工程已经创建，必须同步更新本节和 [文档总入口](README.md)。

## 3. 项目北极星

产品名称：

- 中文名：语迹。
- 英文名：LangoTrace。

固定主 slogan：

- 用生活记录学习语言。
- Learn languages from your life.

一句话定位：

> 语迹是一款把你的真实生活变成外语学习材料的本地优先语言学习 App。

产品不是：

- 不是 AI 聊天工具。
- 不是传统背单词 App。
- 不是课程驱动产品。
- 不是云端账号和平台绑定优先的学习平台。

产品是：

- 生活记录工具。
- 语言学习工具。
- 跟读、听写、回译和写作修改工具。
- 本地优先的个人语言记忆系统。

## 4. 不可轻易破坏的核心决策

后续讨论和开发必须遵守以下当前决策。若要改变，必须新增或更新 ADR。

1. Apple 三端首发，主框架采用 SwiftUI Multiplatform。
2. iPhone、iPad、macOS 共享业务逻辑，但界面按设备分别设计。
3. 第一版采用买断制、单人使用，不做多用户、家庭或教师学生系统。
4. 一个语言空间对应一门目标语言，例如英语空间、日语空间。
5. 工作、生活、旅行、会议、情绪不是空间，而是标签、场景或 Prompt 模式。
6. 首次启动不默认创建语言空间，先询问母语、目标语言、水平自评，再创建第一个语言空间。
7. 首次启动不要求用户选择数据目录，数据默认保存在 App 私有容器。
8. AI Provider、Embedding、TTS、OCR、语音识别等能力通过 Provider 抽象。
9. API Key 默认存入 Keychain，默认不同步。
10. 照片、日记、音频等敏感内容只有在用户明确触发对应 AI 能力时才发送给 Provider。
11. SQLite / GRDB 是长期主存储候选，SwiftData 只能作为备选或局部原型方案。
12. 向量索引是本地可重建派生数据，默认不同步。
13. 同步采用 Sync Engine + Adapter 思路，不绑定 CloudKit-only。
14. Xcode 工程推荐通过 XcodeGen 生成，工程结构以 `project.yml` 为主要来源。

## 5. 按任务类型读取文档

### 5.1 产品、功能和交互讨论

优先读取：

- [产品主参考文档](product-main-reference.md)
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 2、10 节
- [ADR-004：采用语言空间作为核心信息模型](decisions/004-use-language-space-as-primary-model.md)

适用任务：

- 新功能是否应该做。
- 首次启动、语言空间、导航、设置入口、用户路径。
- iPhone、iPad、Mac 的体验差异。
- AI 生成模式、Prompt Preset、长期记忆体验。

### 5.2 原型和 UI 设计

优先读取：

- [产品主参考文档](product-main-reference.md) 的第 7、8、9 节
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 10 节
- `prototypes/langotrace-multi-device-prototype/README.md`

适用任务：

- 静态 HTML 原型修改。
- iPhone / iPad / Mac 页面结构优化。
- 高级感、简洁性、导航和设置入口调整。

### 5.3 SwiftUI 工程初始化

优先读取：

- [项目初始化规划](project-initialization.md)
- [开发环境记录](development-environment.md)
- [初始模块边界](architecture/001-initial-module-boundaries.md)
- [ADR-002：使用 SwiftUI Multiplatform](decisions/002-use-swiftui-multiplatform.md)
- [ADR-003：使用 XcodeGen 管理 Xcode 工程生成](decisions/003-use-xcodegen-for-project-generation.md)

适用任务：

- 安装或检查 XcodeGen。
- 创建 `project.yml`。
- 创建 SwiftUI App shell。
- 建立初始 Swift Package 或模块目录。
- 运行 iOS Simulator 和 macOS 构建验证。

### 5.4 数据、存储、同步和长期记忆

优先读取：

- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 2、5、6、9 节
- [文档体系规范](documentation-system.md) 的第 4 节
- [ADR-005：坚持本地优先和用户自带 Provider](decisions/005-local-first-and-user-owned-providers.md)

适用任务：

- SQLite / GRDB schema。
- Repository、迁移和导出。
- 附件存储。
- FTS 和向量索引。
- WebDAV / S3 / R2 / iCloud 同步。
- 冲突解决。

### 5.5 AI、Prompt、TTS、OCR 和语音能力

优先读取：

- [产品主参考文档](product-main-reference.md) 的第 9、10 节
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 7、8 节
- [初始模块边界](architecture/001-initial-module-boundaries.md)
- [ADR-005：坚持本地优先和用户自带 Provider](decisions/005-local-first-and-user-owned-providers.md)

适用任务：

- Prompt Preset 设计。
- AI 文本转换、写作检查和修改。
- 请求预览、请求日志和隐私边界。
- AVSpeechSynthesizer、AVFoundation、Speech、Vision、PhotosUI 集成。

### 5.6 测试、发布和付费

优先读取：

- [文档体系规范](documentation-system.md) 的第 2.5、2.6、4.3 节
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 2.8 节
- [测试文档目录](testing/README.md)
- [发布文档目录](release/README.md)

适用任务：

- StoreKit 买断制。
- 恢复购买。
- 权限说明。
- App Store 隐私标签。
- TestFlight。
- 手动测试和回归检查清单。

### 5.7 开源参考、竞品和外部研究

优先读取：

- [开源项目参考记录](development-open-source-references.md)
- [研究文档目录](research/README.md)

适用任务：

- 下载或研究开源项目。
- 许可证风险判断。
- 对比竞品。
- 调整产品差异化。

## 6. 文档更新落点

形成新结论时，按以下规则写回：

- 产品定位、语言空间、买断制、核心功能：更新 [产品主参考文档](product-main-reference.md)。
- 技术选型、平台策略、数据和同步路线：更新 [技术框架与开发路线参考](technical-framework-roadmap.md)。
- 不可轻易反转的取舍：新增或更新 `docs/decisions/`。
- 模块边界、数据流、Provider、Sync、StoreKit 架构：新增或更新 `docs/architecture/`。
- 具体实施步骤：写入 `docs/development/` 或 `docs/superpowers/plans/`。
- 大功能规格：写入 `docs/superpowers/specs/`。
- 验证流程和手动测试：写入 `docs/testing/`。
- App Store、TestFlight、StoreKit 和隐私标签：写入 `docs/release/`。
- 研究材料和未定结论：写入 `docs/research/`。

## 7. 当前优先级

后续开发优先级应保持克制：

1. 创建可启动、可构建的 SwiftUI Multiplatform App shell。
2. 建立最小模块边界和工程生成方式。
3. 做首次启动引导与语言空间的最小闭环。
4. 做本地记录和英语示例学习闭环。
5. 再接入真实 AI Provider、TTS、听写、回译、SQLite、同步和 StoreKit。

第一阶段不要同时实现完整数据库、完整 AI、完整同步、完整 StoreKit 和完整视觉系统。

## 8. 完成前检查

涉及文档任务时，至少检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TODO|TBD|待补充|稍后完善|以后再写" docs --glob '!AI_ENTRY_POINT.md'
git status --short
```

涉及 Swift 工程任务时，根据实际工程状态检查：

```bash
xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
xcodebuild -scheme LangoTrace -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace -destination 'platform=macOS' build
swiftlint
swiftformat --lint .
git status --short
```

如果某项检查暂时不能运行，必须说明原因和剩余风险。
