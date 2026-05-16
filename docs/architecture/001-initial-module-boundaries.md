# 初始模块边界

本文档记录语迹 LangoTrace 原生工程初始化阶段的模块边界。它用于指导第一版 SwiftUI 工程骨架，不代表所有模块都必须在第一天完整实现。

## 1. 边界原则

第一阶段的重点是让工程结构支持长期演进：

- App 可以在 iPhone、iPad 和 macOS 启动。
- 产品核心概念不被写死在单个视图文件里。
- 后续接入数据库、AI、TTS、OCR、同步和 StoreKit 时有明确放置位置。
- 早期可以使用协议、空实现或内存实现，但不把外部服务请求直接写进 UI。

## 2. 推荐模块

### 2.1 App Shell

职责：

- 应用入口。
- 根导航。
- 平台窗口配置。
- 首次启动状态路由。

不负责：

- 直接执行 AI 请求。
- 直接读写数据库。
- 直接管理同步冲突。

### 2.2 Core

职责：

- 领域模型。
- 用例协议。
- 语言空间、记录、句子、词句记忆、练习记录等核心类型。
- 与平台无关的业务规则。

不负责：

- SwiftUI 视图。
- SQLite 细节。
- 网络请求细节。

### 2.3 UI

职责：

- 共享设计 token。
- 共享 SwiftUI 组件。
- iPhone、iPad、macOS 的根布局适配。
- 原型中的视觉方向转化为原生界面。

不负责：

- 数据持久化。
- AI Provider 调用。
- 同步协议。

### 2.4 Data

职责：

- 本地 Repository 接口和实现。
- SQLite / GRDB 接入。
- 数据迁移。
- FTS 索引。
- 附件元数据。

第一阶段可以只定义协议和内存实现。

### 2.5 AI

职责：

- AI Provider 协议。
- OpenAI-compatible 配置模型。
- Prompt Preset。
- 请求预览和请求元数据。
- 图片理解、文本转换、写作检测和改写的接口。

第一阶段不发送真实请求。

### 2.6 Speech

职责：

- TTS 播放接口。
- 录音接口。
- 语音识别接口。
- 跟读、听写和回译流程所需的音频状态。

第一阶段可以使用空实现或占位状态。

### 2.7 Sync

职责：

- 同步状态。
- Sync Adapter 协议。
- 冲突模型。
- manifest 和变更记录的抽象。

第一阶段不实现 WebDAV / S3 / R2 / iCloud 同步。

## 3. 依赖方向

推荐依赖方向：

```text
App Shell -> UI -> Core
App Shell -> Data / AI / Speech / Sync
Data -> Core
AI -> Core
Speech -> Core
Sync -> Core
```

约束：

- Core 不依赖 UI。
- Core 不依赖具体数据库。
- Core 不依赖具体 AI Provider。
- UI 不直接知道 API Key、base URL 或同步密钥。
- Data、AI、Speech、Sync 通过协议向 App Shell 暴露能力。

## 4. 第一阶段最小落地

第一阶段工程初始化只需要落地：

- App Shell。
- 根视图。
- 最小 Core 类型，例如 App tagline 或占位语言空间状态。
- 可以编译的模块结构。

不需要落地：

- 真实数据库。
- 真实 AI 请求。
- 真实 TTS。
- 真实同步。
- StoreKit。

