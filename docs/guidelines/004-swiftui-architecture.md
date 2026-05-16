# 004：SwiftUI 架构规范

状态：Accepted

适用阶段：SwiftUI 工程初始化、App Shell、MVP 早期开发。

## 1. 适用范围

本文档规定语迹 LangoTrace SwiftUI 工程的模块边界、视图职责、依赖方向和平台适配原则。

## 2. 当前结论

语迹应采用 SwiftUI Multiplatform 原生路线。业务逻辑和核心模型共享，平台 UI 按设备分别优化。早期可以使用内存实现和 Mock Provider，但必须保留真实 Data、AI、Speech、Sync 模块的替换边界。

## 3. 强制规则

- `View` 只负责渲染、布局和用户交互。
- `View` 不直接访问 SQLite、Keychain、网络、对象存储或具体 AI Provider。
- AI、TTS、OCR、Speech、Sync 必须通过协议或服务层进入 UI。
- Core 不依赖 SwiftUI、SQLite、网络和具体 Provider。
- UI 不直接知道 API Key、base URL、对象存储密钥或加密密钥。
- 平台差异不能大量堆在单个巨型 View 中。
- App Shell 负责根路由、依赖装配和平台入口，不承载业务细节。
- 示例数据、内存 Repository、Mock Provider 必须能被真实实现替换。
- 异步任务不能散落在 View 中长期运行，必须有取消、错误和加载状态边界。
- 业务错误不能只用 `print` 或临时文本处理，必须通过可测试的状态或结果返回到 UI。

## 4. 默认推荐

### 4.1 模块职责

推荐边界：

```text
App Shell -> UI -> Core
App Shell -> Data / AI / Speech / Sync
Data -> Core
AI -> Core
Speech -> Core
Sync -> Core
```

模块职责：

- App Shell：应用入口、根状态路由、依赖装配。
- Core：领域模型、用例协议、业务规则。
- UI：SwiftUI 组件、页面、平台布局。
- Data：Repository、SQLite / GRDB、迁移、附件元数据。
- AI：Provider、Prompt Preset、请求预览、请求元数据。
- Speech：TTS、录音、语音识别、播放状态。
- Sync：同步状态、Adapter、manifest、冲突模型。

### 4.2 View 拆分

推荐按产品对象拆分，而不是按视觉碎片过度拆分。

合理组件：

- Entry 编辑器。
- 双语句子对。
- 练习控制条。
- 请求预览卡。
- 语言空间切换器。

不建议：

- 每几个 `Text` 就拆一个无意义组件。
- 一个页面文件同时承担路由、业务、网络、存储和布局。

### 4.3 平台适配

推荐：

- 共享 Core 和服务协议。
- iPhone、iPad、macOS 可以有不同根布局。
- 小型差异可以使用环境值和条件布局。
- 大型差异应拆成明确的平台 View。

### 4.4 App Environment

推荐在 App Shell 中维护轻量 App Environment，用于装配依赖：

```text
AppEnvironment
  repositories
  aiProviders
  speechServices
  syncServices
  appSettings
```

View 不直接创建真实 Provider、Repository 或 KeychainStore。预览、测试和早期 Demo 使用 Mock 或 InMemory 实现。

### 4.5 状态边界

推荐区分：

- App-level state：首次启动、当前语言空间、全局设置。
- Feature state：记录编辑、生成请求、练习流程、记忆列表。
- Transient UI state：Sheet 展示、选中项、临时筛选。

不要把所有状态塞进单一全局对象，也不要让每个 View 各自复制语言空间状态。

### 4.6 错误与加载

涉及存储、AI、TTS、OCR、Speech、Sync 的能力必须暴露：

- idle。
- loading 或 running。
- success。
- failed，包含可展示错误信息和可诊断错误码。
- cancelled，如果用户可取消。

UI 可以简化展示，但底层状态不能丢失。

## 5. 可演进部分

以下内容需结合最低系统版本和实际 SwiftUI 工程再确定：

- 使用 `@Observable` 还是 `ObservableObject`。
- ViewModel 是否作为统一命名。
- Swift Package 是否第一天完整拆分。
- 是否使用 AppKit bridge 支持复杂 macOS 菜单、焦点和窗口。
- 是否引入依赖注入容器，或先用轻量 App Environment。
- 是否采用统一 Result 类型或领域错误类型。
- 是否引入 snapshot/UI 测试框架。

## 6. 反例

不应这样做：

- 在 Button action 中直接拼接 AI 请求。
- 在 SwiftUI View 中直接读写 Keychain。
- 在页面文件中写 SQLite 查询。
- 为了快速实现，把语言空间、Entry、Prompt 和设置状态都塞进一个全局对象。
- 在 iPhone/iPad/macOS 上强行复用完全相同的大页面。

## 7. AI 开发提示

AI 在写 SwiftUI 代码前应先回答：

- 这个 View 属于哪个平台或是否跨平台？
- 它需要哪些 Core 模型？
- 它依赖哪个用例或服务协议？
- 它是否触发 AI、存储、权限、同步或密钥访问？
- 是否已有合适组件可以复用？
- 异步任务在哪里启动，如何取消，失败如何展示？
- 这个状态属于 App-level、Feature-level 还是 Transient UI？

如果发现为了实现某个页面必须让 UI 直接访问底层服务，说明边界设计有问题，应先补协议或用例层。

## 8. 变更记录

- 2026-05-17：创建第一版 SwiftUI 架构规范。
- 2026-05-17：补充 App Environment、状态边界、异步任务和错误加载状态要求。原因：避免早期 SwiftUI 代码形成全局状态和副作用债务。影响范围：App Shell、UI、服务调用。是否需要 ADR：否。
