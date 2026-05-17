# 语迹 / LangoTrace 技术框架与开发路线参考

本文档记录语迹 / LangoTrace 在 Apple 三端开发上的技术路线判断，作为后续进入工程设计、原型开发和架构拆分时的参考。

本文档重点回答：

- MacBook、iPad、iPhone 三端应使用什么开发框架。
- 如何在三端之间共享业务逻辑，同时保持各自优秀体验。
- 本地优先、隐私、AI Provider、自定义同步、向量化长期记忆应如何影响技术选型。
- 使用 MacBook Air M4 作为开发设备时，推荐怎样推进第一版。

## 1. 总体结论

语迹第一版应优先采用 Apple 原生技术栈：

```text
SwiftUI Multiplatform
+ Swift Package 模块化
+ SQLite / GRDB 作为长期主存储候选
+ 本地文件系统管理图片与音频附件
+ SQLite FTS5 全文搜索
+ 本地可重建向量索引
+ AVFoundation / AVSpeechSynthesizer / Speech / Vision / PhotosUI
+ Keychain 存储 API Key
+ Provider 抽象 AI / Embedding / TTS / OCR
+ 自定义 Sync Engine，iCloud / WebDAV / S3 / R2 作为适配器
```

核心判断：

> SwiftUI 负责 Apple 平台体验，SQLite / GRDB 负责长期本地数据，Provider 与 Sync Adapter 负责未来扩展能力。

语迹不是普通内容 App，也不是一次性 AI 工具，而是用户可能每天打开、长期写作、长期听读、长期沉淀个人语言记忆的收费 App。付费用户会非常在意输入体验、系统融合度、隐私感、稳定性和长期数据可控性。因此，第一版不建议以 React Native、Flutter 或 Tauri 作为主框架。

## 2. 决策依据与取舍记录

本节用于后续回溯：当产品目标、团队能力、商业模式或平台范围发生变化时，应先回看这些依据，再决定是否调整技术路线。

### 2.1 关键前提

当前技术路线基于以下产品前提：

- 首发目标平台是 Apple 生态：iPhone、iPad、MacBook。
- 产品定位是收费精品 App，而不是快速验证型 Web 工具。
- 核心体验依赖长时间写作、照片、音频、TTS、跟读、听写、手写识别、文件导入导出和三端体验。
- 产品强调本地优先、隐私、买断制、自定义 AI Provider 和自定义同步。
- 用户数据会长期积累，不能被单一云服务、单一 AI 服务或封闭同步方案锁死。
- 开发者使用 MacBook Air M4，可以直接使用 Xcode、Swift、SwiftUI 和 Apple 真机调试链路。

如果未来前提变成“必须同时覆盖 Android / Windows / Web”，或“必须由 Web 前端团队快速开发”，则本路线需要重新评估。

### 2.2 为什么选择 SwiftUI 原生

决策：

> 使用 SwiftUI Multiplatform 作为 Apple 三端主框架。

依据：

- iPhone、iPad、macOS 都是 Apple 一等平台，SwiftUI 能共享语言、工程结构、组件、状态和部分 UI。
- 语迹高度依赖 Apple 原生能力，包括相机、照片、麦克风、语音、TTS、Vision、文件、菜单栏、快捷键、Keychain、StoreKit 和 App Sandbox。
- 付费 App 的价值不只在功能覆盖，也在输入体验、系统融合、动画、权限提示、文本编辑和设备习惯。
- SwiftUI 允许三端共享业务逻辑，同时针对不同屏幕和交互方式设计不同界面。

放弃方案：

- React Native：移动端效率高，但 Mac 原生体验、系统集成和长期维护成本不符合精品三端目标。
- Flutter：跨平台一致性强，但 Apple 原生质感、系统能力和 Mac 细节需要额外打磨。
- Tauri：桌面工具优势明显，但 iOS / iPadOS 上的相机、音频、TTS、Apple Pencil、StoreKit 等体验不如原生自然。

复审条件：

- 产品决定同时首发 Android / Windows / Web。
- 团队扩大为前端优先团队，Swift 原生能力成为实际瓶颈。
- Mac 版变成唯一主版本，移动端降为辅助版本。

### 2.3 为什么选择 SQLite / GRDB 作为长期主存储候选

决策：

> 使用 SQLite / GRDB 作为长期主存储候选，SwiftData 仅作为快速原型或局部方案备选。

依据：

- 语迹的数据不是简单列表，而是长期增长的个人语言资产：Entry、Rendering、Practice、Memory、Prompt Preset、单词本、词典、附件、同步状态、AI 请求元数据和索引。
- 需要稳定迁移、批量导入导出、全文搜索、同步元数据、冲突记录和派生索引管理。
- SQLite 更可控、更透明，更适合本地优先和自定义对象存储同步。
- GRDB 是 Swift 生态中成熟的 SQLite 工具，适合在 SwiftUI 应用中构建 Repository 层。

放弃方案：

- 直接绑定 SwiftData：早期开发轻，但后期复杂同步、开放导出、迁移、FTS、向量索引和跨端可控性可能受限。
- 纯文件存储：适合简单笔记，但不适合复杂查询、练习记录、索引和冲突处理。
- Core Data 直连 UI：Apple 生态成熟，但抽象层较重，且容易把业务逻辑绑进持久层细节。

复审条件：

- 原型证明 SQLite / GRDB 与 SwiftUI 状态同步成本过高。
- 产品缩小为单机轻量日记，不再需要复杂同步和索引。
- 未来有明确理由使用 Core Data / SwiftData 获得更大收益。

### 2.4 为什么采用 Provider 架构

决策：

> AI、Embedding、TTS、OCR、图片理解和语音识别均通过 Provider 抽象接入。

依据：

- 语迹的商业定位是不替用户强绑定官方 AI 服务，而是允许用户自定义 API Key、base URL、模型和请求信息。
- 不同用户会使用不同 OpenAI-compatible 服务、私有模型、第三方 TTS 或本地模型。
- AI 请求涉及隐私，Provider 层可以统一实现请求预览、日志元数据、错误处理和脱敏策略。
- Prompt Preset 是产品核心能力，必须独立于具体 Provider。

放弃方案：

- 直接写死 OpenAI 或某个 AI 服务：实现快，但违背用户掌控和本地优先定位。
- 每个页面自行发请求：短期方便，长期会导致隐私、日志、错误处理和模型配置散乱。

复审条件：

- 产品决定提供官方托管 AI 作为默认服务。
- App Store 审核、地区合规或模型能力要求迫使某些 Provider 受限。
- 本地模型能力成熟到可作为默认选项。

### 2.5 为什么同步不绑定 CloudKit

决策：

> 设计自定义 Sync Engine，CloudKit / iCloud Drive / WebDAV / S3 / R2 作为可选 Sync Adapter。

依据：

- 产品定位强调用户自定义对象存储和数据掌控，不应把同步主权交给单一 Apple 云服务。
- CloudKit 对 Apple 生态用户体验好，但不适合作为唯一同步协议抽象。
- 语迹数据包含文本、附件、音频、Prompt Preset、练习记录、同步状态和可重建索引，需要明确主数据与派生数据边界。
- 自定义同步需要冲突处理、resource manifest、change log 和密钥管理，必须从架构上保留位置。

放弃方案：

- CloudKit-only：实现路径更短，但和自定义对象存储卖点冲突。
- 文件夹同步-only：透明度高，但冲突、索引、附件元数据和跨设备一致性处理复杂。
- MVP 即完整同步：复杂度过高，会拖慢核心学习闭环验证。

复审条件：

- 第一版市场反馈显示大多数付费用户只需要 iCloud。
- 自定义对象存储同步实现成本显著高于商业收益。
- 后续提供官方同步服务，并且需要重新定义商业边界。

### 2.6 为什么向量索引默认本地可重建

决策：

> 向量索引作为本地可重建派生数据，默认不跨设备同步。

依据：

- 向量数据可能体积大、模型相关、版本相关，不适合作为长期主数据。
- 不同设备可能使用不同 embedding provider 或模型版本。
- 原文、目标语言文本、收藏、练习记录和图片摘要才是主数据；向量索引可以根据主数据重建。
- 本地重建更符合隐私优先原则，也减少同步协议复杂度。

放弃方案：

- 同步向量索引：可能节省重建时间，但增加体积、兼容性和隐私风险。
- 不做向量化：短期简单，但削弱长期语言记忆、相似召回和个人表达分析能力。

复审条件：

- 本地 embedding 成本过高，普通设备重建体验不可接受。
- 用户明确需要跨设备保留完全一致的语义检索结果。
- 官方同步服务未来承担向量索引托管。

### 2.7 为什么 iPhone + iPad MVP 优先，Mac 后增强

决策：

> 第一阶段以 iPhone + iPad MVP 验证核心学习闭环，Mac 先基础可运行，后续增强为深度工作台。

依据：

- “用生活记录学习语言”的最高频入口在 iPhone：随手写、拍照、听读、碎片复习。
- iPad 更适合沉浸写作、分屏学习、手写录入、双语对照和跟读练习。
- Mac 对高级管理、批量导入、Prompt 管理和同步配置很重要，但不是验证每日记录习惯的最短路径。
- 三端同时做完整体验会显著拉长 MVP 周期。

放弃方案：

- Mac 优先：适合知识管理工具，但不利于验证随手记录和照片输入。
- 三端全功能同时上线：体验完整，但开发风险和范围过大。
- iPhone-only：验证快，但会低估 iPad 作为主力学习桌面的价值。

复审条件：

- 早期目标用户主要是 Mac 重度写作者。
- 产品首发策略改为桌面高价专业工具。
- iPad 真机体验验证不符合预期。

### 2.8 为什么把权限、迁移、加密、StoreKit 和测试列为基础架构

决策：

> 权限、密钥、迁移、导出、StoreKit 和测试不作为后期补丁，而是从工程设计阶段纳入基础边界。

依据：

- 语迹处理日记、照片、语音和学习记录，隐私风险比普通工具更高。
- 买断制收费 App 必须处理购买、恢复购买、未来增值服务和离线可用性。
- 长期记录产品最怕数据迁移失败、导出受限、密钥泄露和同步冲突。
- AI 请求可能外发敏感内容，必须有请求预览、授权状态和测试约束。

放弃方案：

- MVP 只做功能，不考虑迁移和导出：短期快，但会积累高风险技术债。
- 权限随页面临时处理：容易造成体验割裂和隐私边界不一致。
- 先不上测试：对数据迁移、同步和 AI 隐私请求不可接受。

复审条件：

- MVP 被明确限定为一次性内部原型，不面向真实用户。
- 商业模式从收费 App 改成完全免费实验项目。

### 2.9 为什么采用多语言空间且首次引导创建第一个

决策：

> 语迹采用多语言空间模型：一个 Space 对应一个目标语种学习档案。首次启动不默认创建 Space，而是先询问并记录用户的母语、目标语言和水平自评；用户确认后再创建第一个 Space，例如“英语空间”。数据默认存储在 App 私有容器；首次启动不要求用户选择目录；UI 不使用 Project 概念。

依据：

- 语言学习的用户心智按目标语言组织，例如英语、日语、法语，而不是按抽象 Project 组织。
- 每个目标语言的学习等级、Prompt Preset、TTS 声音、词典、错误模式、复习队列和成长报告都不同，按 Space 隔离更清晰。
- 工作/生活不应作为顶层空间；它们更适合作为标签、场景、Prompt 模式或筛选条件。
- Project 管理会增加初次使用负担，让用户在还没体验学习闭环前就面对抽象信息架构选择。
- 询问母语、目标语言和水平自评是创建学习空间的必要信息，不属于额外负担；它能让用户理解“这个空间就是我的英语学习档案”。
- iPhone / iPad 上选择目录的体验不自然，也容易和 App Sandbox、文件权限、iCloud Drive 心智混在一起。
- 买断制和本地优先不等于首次就把文件系统暴露给用户；更好的体验是默认安全保存，之后提供备份、导出、迁移和同步配置。
- 买断制第一版应默认单人使用，不支持多用户、家庭成员或教师/学生管理；这更符合隐私承诺，也更利于单人授权销售。

放弃方案：

- 首次启动要求选择本地目录：数据可见性强，但明显增加新手门槛。
- 第一版暴露多 Project：适合专业知识库工具，但不适合以随手记录为入口的语言学习 App。
- 单一总 Space 下混合多个目标语言：生活时间线连续，但复习、Prompt、TTS、词典、错误模式和成长报告会混杂。
- 按工作/生活拆分 Space：看似贴近场景，但真实记录经常跨场景，会造成分类压力。
- 支持多用户：会引入账号权限、数据隔离、共享和协作复杂度，偏离第一版个人买断 App。

复审条件：

- 早期付费用户明确把语迹作为专业资料库，而不是生活记录学习工具。
- 多用户、教学或工作/生活隔离成为明确刚需。
- App Store 或平台限制使默认私有容器无法满足备份、迁移或透明度要求。

## 3. 推荐框架：SwiftUI 原生三端

推荐使用 SwiftUI Multiplatform App 开始项目。

适用平台：

- iPhone。
- iPad。
- macOS。
- 未来可评估 visionOS。

SwiftUI 的价值不在于三端界面完全复用，而在于：

- 使用同一语言和同一平台工具链开发。
- 共享数据模型、业务逻辑、状态管理和基础组件。
- 允许针对 iPhone、iPad、macOS 分别设计界面结构。
- 更自然接入 Apple 原生能力，例如照片、相机、语音、文件、菜单栏、快捷键、Keychain、StoreKit。

语迹应采用：

> 同一套数据，同一套学习逻辑，同一套 AI 能力，不同设备不同界面。

不应采用：

> 三端完全相同 UI，只根据屏幕宽度做拉伸适配。

## 4. 为什么不建议第一版使用跨平台框架

### 4.1 React Native

优点：

- iOS / iPadOS 移动端开发效率较高。
- 前端生态丰富。
- AI SDK、网络请求和界面状态管理生态成熟。

主要问题：

- macOS 不是 React Native 的主战场。
- 菜单栏、快捷键、窗口、多面板、拖拽导入、原生文件交互需要大量桥接。
- 语音、拍照、OCR、TTS、Keychain、StoreKit、对象存储同步等能力会逐步堆出较高 native bridge 成本。
- 对收费 Apple 生态 App 来说，细节质感更难做到原生水准。

适合场景：

- 快速验证 iPhone / iPad 移动端 MVP。
- 团队已有强 React Native 经验，并且暂时不重视 Mac 原生体验。

不适合作为语迹第一版主框架。

### 4.2 Flutter

优点：

- 跨平台一致性强。
- UI 可控，性能较好。
- 适合同时面向 iOS、Android、Web、桌面的产品。

主要问题：

- Apple 平台原生质感仍需要额外打磨。
- macOS 菜单栏、快捷键、窗口、多面板、文件拖拽、系统服务集成不如 SwiftUI 自然。
- 文本输入、系统语音、iCloud、Share Extension、StoreKit、Spotlight 等细节会增加平台适配成本。

适合场景：

- 产品从第一天就要覆盖 iOS + Android + Web。
- 团队更重视跨平台一致性，而不是 Apple 生态精品体验。

语迹当前目标是 Apple 三端收费 App，不建议为了跨平台一致性牺牲原生体验。

### 4.3 Tauri + React

优点：

- 桌面端能力强。
- 文件系统、本地处理、Rust 后端、Web 前端生态适合工具型产品。
- 后续如果扩展 Windows / Linux，Tauri 有吸引力。

主要问题：

- iOS / iPadOS 的成熟度和生态自然度不如 SwiftUI。
- 相机、录音、TTS、Speech、Apple Pencil、照片权限、StoreKit、Keychain 等能力需要额外适配。
- 对高级付费 iOS / iPadOS App 来说，容易出现 WebView 工具感。

适合场景：

- 未来单独开发跨 Windows / Linux 的桌面版。
- 桌面优先、移动端弱需求的产品。

语迹首发 Apple 三端，不建议以 Tauri 作为主框架。

## 5. 数据层选择

### 5.1 不建议把业务模型绑死在 SwiftData

SwiftData 适合快速原型和 Apple 生态内的数据建模，但语迹的数据复杂度会持续上升：

- 日记原文。
- AI 生成版本。
- 逐句对照。
- 图片附件。
- 音频附件。
- TTS 生成记录。
- 跟读录音。
- 听写和回译记录。
- 单词本和词典。
- Prompt Preset。
- AI Provider 配置。
- 同步状态。
- 冲突记录。
- 全文搜索索引。
- 向量索引。

如果早期直接把业务逻辑绑定到 SwiftData 模型上，后期接入自定义对象存储、复杂同步、导出、迁移和向量索引时会比较被动。

### 5.2 长期推荐：SQLite / GRDB

更稳妥的长期路线是：

```text
SQLite + GRDB + Repository Layer
```

推荐理由：

- SQLite 稳定、可控、跨平台、可迁移。
- GRDB 是 Swift 生态里成熟的 SQLite 工具。
- 方便做事务、迁移、全文搜索、批量导入导出。
- 适合记录同步状态、冲突状态和本地索引元数据。
- 更容易支持自定义对象存储同步。

建议：

- MVP 可以用 SQLite / GRDB 直接起步。
- 如果为了快速原型使用 SwiftData，也必须通过 Repository 层隔离。
- UI 和 Use Case 不应直接依赖具体存储框架。

### 5.3 附件存储

文本和结构化元数据进入数据库。

大文件走本地文件系统：

- 图片。
- 原始照片。
- 裁剪图。
- OCR 来源图。
- TTS 音频。
- 用户跟读录音。
- 导入的外部文件。
- 导出包。

数据库只保存：

- 本地路径或资源 ID。
- hash。
- mime type。
- 文件大小。
- 图片尺寸。
- 音频时长。
- 创建时间。
- 同步状态。
- 是否允许上传给 AI。

这种设计更适合本地优先、对象存储同步和后期备份。

## 6. 搜索与向量化长期记忆

### 6.1 全文搜索

第一阶段建议使用 SQLite FTS5 做本地全文搜索。

搜索对象：

- 母语日记。
- 目标语言版本。
- 单词和短语。
- 标签。
- 图片说明。
- AI 生成摘要。
- 写作修改解释。

FTS5 适合解决“我记得写过某件事”这类精确或半精确查找。

### 6.2 向量索引

向量化是语迹长期记忆系统的底层能力，但第一版不应过度复杂化。

建议原则：

- 向量索引默认本地保存。
- 向量索引可以删除和重建。
- 向量索引默认不跨设备同步。
- 同步文本、元数据和必要附件后，各设备本地重建向量。
- 使用外部 embedding API 时，必须让用户明确知道哪些内容会发送出去。

向量化对象：

- 用户原始记录。
- AI 生成目标语言文本。
- 逐句双语对照。
- 用户收藏的词句。
- 写作修改前后文本。
- 错误模式。
- 图片摘要和用户补充说明。

向量化用途：

- 相似生活记录召回。
- 相关表达推荐。
- AI 生成时参考用户历史表达。
- 高频主题分析。
- 错误模式分析。
- 长期语言成长回顾。

## 7. AI / TTS / OCR Provider 架构

语迹不应把 AI 能力写成固定服务调用，而应设计 Provider 抽象。

建议核心接口：

```text
TextGenerationProvider
EmbeddingProvider
TTSProvider
OCRProvider
ImageUnderstandingProvider
SpeechRecognitionProvider
```

Provider 应支持：

- OpenAI-compatible endpoint。
- 用户自定义 base URL。
- 用户自定义 API Key。
- 用户自定义请求头。
- 用户自定义模型名。
- Prompt Preset 选择。
- 请求前隐私预览。
- 请求日志元数据。

API Key 存储：

- 使用 Keychain。
- 默认只保存在本机。
- 不参与对象存储同步。
- 若未来支持跨设备同步密钥，必须独立开关并清楚提示风险。

## 8. Apple 原生能力使用建议

### 8.1 TTS 朗读

MVP 优先使用：

```text
AVSpeechSynthesizer
```

适合：

- 目标语言朗读。
- 分句播放。
- 慢速 / 正常速度。
- 听写模式。
- 跟读前示范。

注意：

- AVSpeechSynthesizer 适合基础朗读，不等同于完整高质量音频资产系统。
- 若后续需要高质量拟真语音、音频文件生成、跨设备同步音频，应通过 TTSProvider 接入外部服务。

### 8.2 录音与跟读

使用：

```text
AVFoundation
```

适合：

- 用户跟读录音。
- 音频播放。
- 分句录音。
- 跟读回放。
- 简单波形或进度显示。

MVP 不必一开始做专业发音评分。更合理的第一版闭环是：

```text
听示范 -> 跟读录音 -> 回放 -> 文本对照 -> 收藏问题句
```

### 8.3 语音识别与听写校验

可使用：

```text
Speech Framework
```

适合：

- 用户跟读转文字。
- 听写结果辅助校验。
- 基础文本相似度对比。

边界：

- 不应把 Speech Framework 包装成专业发音评分。
- 真正的音素级发音反馈需要后续评估 Whisper、Azure Speech、Google Speech 或其他 pronunciation assessment API。

### 8.4 拍照、图片与手写识别

iPhone / iPad：

- 使用相机拍照。
- 使用 PhotosUI 选择图片。
- 使用 Vision 做 OCR 或基础图像处理。
- 对手写文章识别结果提供人工校对步骤。

Mac：

- 不强调拍照。
- 支持图片导入、拖拽、剪贴板、文件夹批量导入。

隐私原则：

```text
照片默认本地保存。
只有用户明确点击“用 AI 分析照片”时，才发送给用户配置的 AI Provider。
```

## 9. 同步架构

语迹的同步不应从第一天绑定 CloudKit。

推荐设计：

```text
Sync Engine
+ Sync Adapter
+ Conflict Resolver
+ Local Change Log
+ Remote Object Manifest
```

可选适配器：

- iCloud Drive。
- CloudKit。
- WebDAV。
- S3。
- Cloudflare R2。
- Dropbox。
- 本地文件夹。

推荐同步原则：

- 原始记录、目标语言文本、Prompt Preset、收藏词句可以同步。
- 图片和音频由用户选择是否同步。
- 向量索引默认不同步，在每台设备本地重建。
- API Key 默认不同步。
- 同步协议必须支持冲突记录和用户选择。

第一版可以只保留架构接口，不急于完整实现同步。

同步边界必须提前写清楚：

- 同步传输不等于云端备份服务，语迹默认不承诺替用户托管数据。
- 自定义对象存储意味着用户要自行承担存储可用性、流量费用和凭证管理。
- API Key、对象存储密钥、加密密钥默认不写入同步目录。
- 附件同步必须支持按类型和大小限制，例如只同步文本、不同步音频，或仅在 Wi-Fi 下同步媒体。
- 冲突解决不能只覆盖文本，也要覆盖 Prompt Preset、单词收藏、练习记录和附件元数据。
- 向量索引、FTS 索引和缓存均应视为可重建派生数据，不作为跨端同步的主数据。

## 10. 三端产品与交互差异

### 10.1 iPhone：随手记录与碎片练习

iPhone 是最高频入口。

核心场景：

- 随手写一句。
- 拍照生成写作话题。
- 睡前复习。
- 通勤听读。
- 快速查词。
- 快速跟读。

推荐 UI：

```text
底部 Tab + 单列时间线 + 全屏编辑器 + 卡片式练习
```

推荐 Tab：

- 今日。
- 记录。
- 练习。
- 记忆。
- 设置。

不建议使用“我的”作为 iPhone 一级 Tab。“我的”容易形成账号中心或社区产品心智；语迹更应直接呈现用户要操作的对象。也不建议把“单词”作为一级 Tab 名称，因为语迹的长期记忆不只是单词，还包括短语、整句、错误模式、相似生活记录和复习状态。

首页重点：

```text
今天想记录什么？
[写一句] [拍照] [录音]
```

iPhone 不应承载太多复杂配置、表格和批量管理。

首次启动不应要求用户选择数据目录，也不应在没有询问用户前默认创建语言空间。推荐先收集母语、目标语言和水平自评，用户确认后创建第一个语言空间，例如“英语空间”。数据保存在 App 私有容器；用户可稍后在设置中配置 AI Provider、备份、导出、自定义同步和添加新的学习语言。

iPhone 首页应显示当前语言空间，例如“英语 · B1”。切换器可以显示“英语 / 日语 / 添加学习语言”，但不要命名为 Project。

### 10.2 iPad：主力学习与沉浸写作

iPad 可能是语迹最重要的学习设备。

核心场景：

- 长文本写作。
- 双语对照。
- 分句跟读。
- 听写。
- 回译。
- 图片写作。
- 手写文章 OCR。
- Apple Pencil 标注。

推荐 UI：

```text
三栏布局
左侧：时间线 / 日历 / 标签
中间：写作区 / 双语正文 / 图片与语音材料
右侧：AI 转换 / 跟读 / 单词 / 修改解释 / 练习面板
```

iPad 工作区顶部应保留轻量全局条，而不是重型导航：

```text
[英语空间 · B1 v]                         [搜索] [本地保存] [设置图标]
```

语言空间切换代表当前学习上下文，应该常驻可见；设置入口只使用低干扰图标或 Sheet，不作为主要 Tab。

iPad 定位：

> 语迹的学习桌面。

### 10.3 MacBook：语言资料库与创作工作台

MacBook 不应是 iPhone 的放大版，也不应强调拍照录入。

核心场景：

- 长文编辑。
- 拖拽图片、音频、Markdown。
- 批量导入。
- 批量导出。
- 词典管理。
- Prompt Preset 管理。
- AI Provider 配置。
- 对象存储同步配置。
- 高级搜索。
- 多窗口工作。

推荐 UI：

```text
Sidebar + 主编辑区 + Inspector + Toolbar + Command Palette
```

MacBook 顶部 Toolbar 应包含轻量语言空间切换、命令搜索、本地/同步状态和设置图标：

```text
[英语空间 · B1 v] [资料库 / Prompt / 同步 / 导入导出]     [Cmd K] [本地保存] [设置图标]
```

左侧 Sidebar 应承载当前功能域的列表或筛选，不建议重复做成多个语言空间卡片。语言空间切换应集中在顶部，避免和资料库分类、设置分类混在一起。

Mac 端应重点支持：

- 菜单栏。
- 快捷键。
- 多窗口。
- 拖拽导入。
- 文件系统集成。
- Markdown / JSON 导出。
- 高级设置。

建议快捷键：

```text
Cmd + N      新建记录
Cmd + K      命令面板
Cmd + F      全局搜索
Cmd + Enter  生成目标语言
Space        播放 / 暂停音频
R            开始跟读录音
Cmd + S      手动保存或同步
```

Mac 定位：

> 语迹的语言资料库与创作工作台。

## 11. 推荐工程结构

建议使用 Swift Package 拆分模块：

```text
LangoTraceApp
├── LangoTraceCore
│   ├── Models
│   ├── UseCases
│   ├── Repositories
│   └── Domain Logic
│
├── LangoTraceData
│   ├── SQLiteStore
│   ├── MediaStore
│   ├── SearchIndex
│   └── SyncMetadata
│
├── LangoTraceAI
│   ├── ProviderProtocols
│   ├── OpenAICompatibleProvider
│   ├── PromptPresets
│   └── RequestLogging
│
├── LangoTraceSpeech
│   ├── TTSService
│   ├── RecordingService
│   ├── SpeechRecognitionService
│   └── AudioPlaybackService
│
├── LangoTraceSecurity
│   ├── KeychainStore
│   ├── PrivacyPolicy
│   ├── PermissionState
│   └── EncryptionSupport
│
├── LangoTraceImportExport
│   ├── MarkdownExport
│   ├── JSONExport
│   ├── BackupPackage
│   └── DictionaryImport
│
├── LangoTraceUI
│   ├── SharedComponents
│   ├── iPhoneViews
│   ├── iPadViews
│   └── MacViews
│
└── LangoTraceSync
    ├── SyncEngine
    ├── iCloudAdapter
    ├── S3Adapter
    ├── WebDAVAdapter
    └── ConflictResolver
```

模块原则：

- UI 不直接调用具体 AI 服务。
- UI 不直接访问 SQLite。
- Use Case 负责业务流程。
- Repository 负责数据读写抽象。
- Provider 负责外部能力适配。
- Sync Adapter 负责不同同步目标。
- Prompt Preset 是产品能力，不是散落在代码里的字符串。
- 安全、权限和导入导出必须独立成模块，不能散落在具体页面里。

## 12. 开发路线

### Phase 0：技术原型

目标：

验证 Apple 原生三端、数据层和核心闭环是否可行。

范围：

- SwiftUI 三端壳。
- SQLite / GRDB 数据模型验证。
- 本地图片 / 音频附件存储。
- 一个 OpenAI-compatible Provider。
- 一个 Prompt Preset。
- 系统 TTS 播放。
- 一条记录生成目标语言并播放的闭环。

当前进度：

- 已完成 SwiftUI 三端工程壳、XcodeGen 工程定义和本地 package 边界。
- 已完成 Welcome / Onboarding / Main 启动路由、内存语言空间 preview、iPhone / iPad / macOS 产品体验骨架、隐私状态图标和 iPad 面板手势 helper。
- 已建立 Core / UI 的首批单元测试和 `scripts/verify.sh` 统一验证入口。
- 尚未完成 SQLite / GRDB 数据模型验证、本地附件存储、真实 OpenAI-compatible Provider、Prompt Preset 执行、系统 TTS 播放和记录生成目标语言并播放的闭环。

因此，当前项目处于 Phase 0 的前半段：平台和产品骨架已经可运行，数据层、AI、TTS 和核心学习闭环仍待单独设计与实现。

### Phase 1：iPhone + iPad MVP

目标：

验证用户是否愿意每天记录，并用自己的内容学习语言。

范围：

- 本地日记。
- 目标语言设置。
- AI Provider 配置。
- Prompt Preset。
- AI 转换目标语言。
- 双语对照。
- 系统 TTS。
- 跟读录音。
- 基础单词收藏。
- 本地数据库。

Mac 在这个阶段可以只保证基础运行，不必做完整工作台。

### Phase 2：iPad 学习桌面

目标：

让 iPad 成为沉浸学习主场景。

范围：

- 三栏布局。
- 分句学习。
- Shadowing。
- 听写。
- 回译。
- 右侧学习面板。
- 图片引导写作。
- 手写文章 OCR + AI 修改。
- Apple Pencil 标注。

### Phase 3：Mac 深度工作台

目标：

让 Mac 成为高级付费用户的资料库和创作工作台。

范围：

- 原生 macOS 窗口体验。
- 菜单栏。
- 快捷键。
- Command Palette。
- 批量导入。
- 批量导出。
- 高级搜索。
- 本地词典导入。
- Prompt Preset 管理。
- AI Provider 高级配置。
- 对象存储同步配置。

### Phase 4：同步与长期记忆增强

目标：

让语迹从学习工具升级为个人语言资产系统。

范围：

- iCloud / WebDAV / S3 / R2 同步适配器。
- 冲突处理。
- 向量索引重建。
- 相似记录召回。
- 个人高频表达分析。
- 错误模式分析。
- 语言成长报告。
- 年 / 月 / 地点回顾。

## 13. MacBook Air M4 开发环境判断

使用 MacBook Air M4 开发该产品是可行的。

建议准备：

- 最新稳定版 Xcode。
- iOS / iPadOS / macOS Simulator。
- 一台真实 iPhone，用于相机、麦克风、照片权限和实际听读体验测试。
- 如果预算允许，准备一台 iPad，用于横屏、Apple Pencil、分屏和沉浸学习体验测试。
- Apple Developer Program 账号，用于真机调试、TestFlight、StoreKit 和 App Store 发布。

注意：

- 模拟器不能完全替代相机、麦克风、TTS 语音、权限弹窗、后台音频和真实触控体验。
- 语迹高度依赖输入和听读体验，必须尽早用真机测试。

## 14. 风险与架构约束

### 14.1 SwiftUI macOS 细节风险

SwiftUI 可以支持 macOS，但复杂 Mac App 仍可能遇到窗口、菜单、焦点、快捷键和文本编辑细节问题。

策略：

- 主体使用 SwiftUI。
- 对复杂 macOS 能力保留 AppKit bridge 空间。
- Mac 端不要早期就追求所有高级能力。

### 14.2 数据层过早抽象风险

如果一开始做过重架构，会拖慢 MVP。

策略：

- Repository 层必须有。
- Sync Engine 可以先有接口和元数据，不必完整实现。
- 向量索引可以先设计数据结构，后续逐步启用。

### 14.3 AI Provider 复杂度风险

如果第一版支持太多 Provider，会拖慢核心体验验证。

策略：

- 第一版只做 OpenAI-compatible Provider。
- Provider 接口要保留扩展能力。
- Prompt Preset 必须从第一版开始结构化。

### 14.4 同步复杂度风险

对象存储同步、冲突处理和附件同步是高复杂度模块。

策略：

- MVP 本地优先。
- 先支持导出和备份。
- 后续再做同步。
- 设计时保留 change log、resource manifest 和 conflict metadata。

## 15. 必须提前明确的工程边界

以下边界不一定都要在 MVP 中完整实现，但必须在工程设计阶段提前决定或保留接口。

### 15.1 最低系统版本

技术路线应在原型阶段明确最低支持版本。

建议评估维度：

- SwiftUI 多平台能力和 NavigationSplitView 可用性。
- Swift Concurrency、Observation、SwiftData 或替代方案的可用性。
- PhotosUI、Vision OCR、Speech、AVFoundation、Keychain、StoreKit 的最低系统要求。
- 目标用户设备覆盖率。
- 维护成本。

原则：

- 不为了覆盖过旧系统牺牲交互体验和开发效率。
- 如果使用 SQLite / GRDB 作为主存储，可以降低对 SwiftData 系统版本的依赖。
- Mac 端最低版本应结合 SwiftUI macOS 成熟度和 AppKit bridge 成本决定。

### 15.2 权限、Entitlement 与隐私提示

语迹涉及照片、相机、麦克风、语音识别、文件访问、网络请求、Keychain、后台播放和同步。

必须提前设计：

- 相机权限。
- 照片库权限。
- 麦克风权限。
- 语音识别权限。
- 文件访问和安全书签。
- 网络访问说明。
- 后台音频能力是否启用。
- App Sandbox 下的 macOS 文件导入导出边界。
- App Store 隐私标签和隐私说明。

原则：

- 权限按功能触发，不在首次启动时集中索取。
- 每次外发 AI 请求前，用户应能知道将发送哪些文本、图片摘要或上下文。
- 隐私状态应进入数据模型，例如某条 Entry 是否允许 AI、是否允许向量化、是否允许同步。

### 15.3 数据迁移、备份与导出

语迹是长期使用产品，数据迁移不是后期附加功能。

必须提前考虑：

- 数据库 schema migration。
- 附件目录迁移。
- 备份包格式。
- Markdown / JSON 导出。
- Prompt Preset 导入导出。
- 单词本和词典导入导出。
- 向量索引重建流程。
- 损坏数据库或缺失附件的修复策略。

原则：

- 原始记录和用户输入内容永远优先保全。
- AI 生成内容、音频、向量索引和缓存可以重建，但需要记录生成配置。
- 导出格式应尽量开放，避免用户被锁死。

### 15.4 本地加密与密钥管理

本地优先不等于天然安全。语迹需要清楚区分本地存储、系统保护和用户可选加密。

建议：

- API Key 存 Keychain。
- 对象存储密钥存 Keychain。
- 普通数据库可先依赖系统文件保护。
- 后续评估数据库级加密或备份包加密。
- 用户自定义同步目录中的数据是否加密，应作为独立产品决策。

原则：

- 不在明文配置文件里保存密钥。
- 不默认同步密钥。
- 若支持加密备份或端到端同步，必须设计密钥遗失后的恢复边界。

### 15.5 后台任务与音频体验

语迹有听读、跟读、TTS、音频生成和同步需求，但后台能力受平台限制。

必须明确：

- 是否支持锁屏播放。
- 是否支持后台 TTS。
- 是否支持后台录音。
- 是否支持后台同步。
- 是否支持批量生成音频。
- iPhone、iPad、Mac 三端的后台能力差异。

原则：

- MVP 优先保证前台听读和录音体验。
- 后台音频和批量任务应单独验证系统限制和 App Store 审核边界。

### 15.6 StoreKit 与商业模式

语迹计划买断制，技术路线必须包含付费能力。

建议：

- 使用 StoreKit 管理买断购买、恢复购买和可能的未来增值服务。
- 买断功能和可选增值服务要在代码层清楚分离。
- 如果未来提供官方同步、官方 AI 或高级 TTS，应作为可选服务，不改变本地优先默认体验。

原则：

- 用户自配 AI 与同步能力不应被设计成订阅服务的前置条件。
- 付费状态校验不能阻塞本地数据访问。

### 15.7 测试与质量门禁

收费 App 的技术路线必须包含质量策略。

建议测试层级：

- Domain / Use Case 单元测试。
- Repository 与 SQLite migration 测试。
- Prompt Preset 渲染测试。
- Provider 请求构造测试，避免泄露不该发送的数据。
- 同步冲突模拟测试。
- 附件缺失、移动、重命名和恢复测试。
- iPhone / iPad / Mac 关键路径 UI 测试。
- 真机测试相机、麦克风、TTS、Speech、权限和后台行为。

原则：

- 所有数据迁移必须有测试。
- 所有会外发数据的 AI 请求必须有隐私边界测试。
- 所有同步逻辑必须有冲突和失败恢复测试。

## 16. 最终技术原则

语迹的技术路线应坚持以下原则：

- Apple 原生体验优先。
- 本地数据可控优先。
- AI 能力可替换优先。
- Prompt Preset 产品化优先。
- 文本、图片、音频、向量索引分层存储。
- 同步可选，不作为 MVP 前置条件。
- 三端共享业务逻辑，但不强行共享完整 UI。
- iPhone 做高频入口，iPad 做学习桌面，Mac 做资料库和工作台。
- 权限、密钥、同步、导出和迁移属于基础架构，不应等到后期才补。
- 会外发数据的能力必须有清晰用户授权和可审计元数据。

最终推荐一句话：

> 语迹应走 SwiftUI 原生精品 App 路线，用 SQLite / GRDB 承载长期本地数据，用 Provider 和 Sync Adapter 保持 AI 与同步能力可替换，用三端差异化交互支撑收费 App 的长期体验价值。

## 17. 参考资料

- Apple SwiftUI: https://developer.apple.com/documentation/technologyoverviews/swiftui
- Apple AVSpeechSynthesizer: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- Apple Interface Fundamentals: https://developer.apple.com/documentation/technologyoverviews/interface-fundamentals
- Apple Speech Framework: https://developer.apple.com/documentation/speech
- Apple StoreKit: https://developer.apple.com/storekit/
- Apple App Sandbox: https://developer.apple.com/documentation/security/app_sandbox
- GRDB: https://github.com/groue/GRDB.swift
- Tauri 2: https://v2.tauri.app/
- Flutter Desktop: https://docs.flutter.dev/platform-integration/desktop
- React Native macOS: https://microsoft.github.io/react-native-macos/
