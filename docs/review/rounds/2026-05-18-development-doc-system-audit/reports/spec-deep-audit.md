# Spec 深审报告

日期：2026-05-18
状态：Verified Findings
范围：`docs/spec/` 平铺规范、`docs/spec/ui-design/`、`docs/spec/interface-localization/` 与相关代码 / 配置抽样。

## 1. 审查口径

本轮按以下口径判断 `docs/spec/` 是否全面、准确、严谨：

- 产品定位：是否服务“用生活记录学习语言”，避免把 App 做成聊天工具、课程目录、后台系统或泛翻译器。
- Apple 三端：是否分别约束 iPhone、iPadOS、macOS，而不是把一套移动端 UI 放大到所有端。
- SwiftUI 架构：是否保护 App Shell、UI、Core、Data、AI、Speech、Sync 的依赖方向和替换边界。
- 隐私与本地优先：是否防止 AI、同步、权限、Keychain、日志和用户内容外发边界被页面实现绕开。
- AI 可执行性：新 AI 会话读取入口和 spec 后，是否知道读什么、改什么、不能改什么、如何验证。

## 2. 总体判断

`docs/spec/` 的方向是正确的。它已经覆盖导航、UI 设计系统、SwiftUI 架构、AI Provider / Prompt / 隐私、界面国际化五个高风险方向，并且大多数规则能回到产品主参考、技术路线和 ADR。

主要问题不在“没有规范”，而在三类治理缺口：

1. 部分 Draft 规格已经被入口和实现当作生效规范使用，状态与权威层级不一致。
2. 若干阶段性规格写成 `Implemented` 或“当前事实”，但实现证据只满足一部分，容易让后续 AI 误判能力已完全落地。
3. 数据存储、权限、本地隐私加密、错误状态、日志诊断、测试验证、StoreKit / 发布等高风险方向仍停留在 `docs/spec/README.md` 的“后续建议补充”，或虽已有局部规则但缺少 spec 级统一入口。

复审修正：本报告的问题已经过 `reports/spec-findings-rereview.md` 的代码与文档复核。`SPEC-007` 和 `SPEC-008` 的描述已收窄；其余问题维持原判断。

修复收口：2026-05-18 已根据本报告完成长期文档修复。`006` 已升级为 Accepted，多语言扩展状态已改为 Partially Implemented，数据 / 权限 / 测试验证 spec 已新增，interface localization / navigation / learning content 实现地图已新增，MVP UI 当前事实已修正。下表状态表示本轮审查问题在文档体系中的修复状态。

## 3. 问题清单

| ID | 严重度 | 类型 | 问题 | 证据 | 优化方向 | 复查方法 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SPEC-001 | P1 | 文档准确性问题 | `006` 界面国际化规范仍标为 Draft，但 `docs/spec/README.md` 已把它列为“当前核心规范”，且代码已按其 8 语言方向实现。Draft 状态会让后续 AI 不知道它到底能不能作为强制依据。 | `docs/spec/README.md:32-42` 将 `006` 列为核心规范；`docs/spec/006-interface-localization-and-language-boundaries.md:1-4` 状态仍是 Draft；`Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift:3-14` 已支持 8 语言；`project.yml:47-55`、`project.yml:91-99` 已声明 8 语言 bundle localizations。 | 将 `006` 升级为 `Accepted`，或在 `docs/spec/README.md` 明确 Draft 规范只能作为候选规则。推荐升级 `006`，因为它已被 UI、Core 和 App target 配置使用。 | 检查 `docs/spec/README.md` 与 `006` 状态一致；抽查语言设置实现仍符合 `System` / 显式语言分层。 | Fixed |
| SPEC-002 | P0 | spec 过度承诺 | `2026-05-18-interface-language-expansion-design.md` 标为 `Implemented`，但 String Catalog 并未完整覆盖 8 语言；当前 277 个 key 中有 198 个缺少 `es/ja/fr/de/ko/ru`。这会让后续 AI 误以为主流语言扩展已完整落地。 | `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md:1-4` 标 `Implemented`；同文档 `47-53` 写明覆盖 App chrome；`jq` 检查 `Localizable.xcstrings` 得到 277 个 key、198 个 key 缺失新增 6 语言；样例缺口包括 `audioPanel.title`、`entry.empty.title`、`unavailable.generic.title`。 | 将该文档状态拆成“Core / App target implemented，String Catalog 8 语言 incomplete”，或改为 `Partially Implemented` / `In Progress`。同时新增 String Catalog 覆盖检查命令或脚本，避免只看 Core 枚举和 bundle localizations。 | 运行 String Catalog 完整性检查：统计所有 key 是否包含 `en / zh-Hans / es / ja / fr / de / ko / ru`；检查状态文档不再宣称完整支持。 | Fixed |
| SPEC-003 | P1 | 文档完整性缺口 | 数据存储、迁移、导出和附件边界仍缺少正式 spec，但 MVP 页面和技术路线都已经频繁引用 Entry / Rendering / Practice / Memory、SQLite / GRDB、附件和导出。进入真实本地记录闭环前，这会留下高风险架构空白。 | `docs/spec/README.md:60-68` 仍把数据存储、迁移与导出列为后续建议；`docs/spec/ui-design/mvp-ui-flow-and-design-system.md:39-47` 明确当前缺少 Repository、SQLite / GRDB、附件存储和启动恢复；`Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift:3-6` 的 `LanguageSpaceRepository` 仍为空协议。 | 在真实数据层前新增 `docs/spec/007-data-storage-migration-export.md` 或模块化 `docs/spec/data/spec.md`，定义 Space / Entry / Rendering / Practice / Memory 的主数据、派生数据、附件、迁移、导出和删除边界。 | 新 spec 应能让 AI 判断：哪些对象是主数据、哪些可重建、哪些可同步、哪些必须有迁移和导出测试。 | Fixed |
| SPEC-004 | P1 | 文档完整性缺口 | 权限、本地隐私、Keychain、加密、日志诊断目前散落在 AI / UI / 技术路线中，没有一个统一的执行规则源。现有 AI 隐私规范可用，但不足以覆盖 Photos、Speech、OCR、录音、TTS、系统权限弹窗、本地加密和日志诊断的完整执行边界。 | `docs/spec/005-ai-provider-prompt-and-privacy.md:3-40` 管 AI 与 Keychain；`docs/spec/003-ui-design-system.md:103-116` 只列 UI 状态；`docs/spec/README.md:64-68` 把权限、本地隐私和日志诊断列为后续建议。 | 新增权限与本地隐私 spec，至少覆盖权限解释路径、InfoPlist purpose strings、Keychain 存储、日志脱敏、AI 请求预览、失败/取消状态、系统弹窗语言边界。日志诊断可作为同一文档章节或单独 spec。 | 抽样一个能力如照片 OCR 或录音，检查 AI 会话能否只凭 spec 找到权限说明、数据外发边界、日志边界和验证方式。 | Fixed |
| SPEC-005 | P2 | Apple 平台完整性缺口 | macOS 平台规则在 UI 规格中已有原则，但 `002` / `004` 对 Mac 菜单栏、`Settings` scene、`Cmd+,`、窗口状态恢复、多窗口的规范仍偏“后续候选”。对于付费 Mac App，这些是平台原生性核心，不应长期只停留在 UI polish 文档。 | `docs/spec/002-navigation-and-routing.md:60-69` 提到菜单栏、快捷键、多窗口；`docs/spec/002-navigation-and-routing.md:143-144` 又说明页面闭环阶段不能写成已完成；`LangoTraceApp/LangoTraceApp.swift:22-50` 当前只有 `WindowGroup`，没有 `Settings` scene 或 `.commands`。 | 保持当前实现不强行补 Mac，但在 spec 中明确 Mac command surface 的阶段门槛：何时必须接入 Settings scene、菜单命令、快捷键、窗口尺寸和多窗口恢复。可新增 macOS 平台实现地图或写入 `004`。 | 新会话开发 Mac 设置或命令入口时，应能从 spec 判断 Sidebar 设置入口、系统 Settings scene 和菜单命令的关系。 | Fixed |
| SPEC-006 | P2 | spec 缺少实现地图 | `docs/spec/README.md` 已定义模块级 `spec.md / impl.md` 模式，但当前高风险模块没有 `impl.md`。结果是很多“当前事实”混在长期规范和阶段方案里，后续 AI 需要同时读多份 done plan 才能知道代码在哪里。 | `docs/spec/README.md:43-58` 定义 impl map；当前 `find docs/spec -maxdepth 2` 没有 `*/impl.md`；实现事实散在 `docs/spec/ui-design/*`、`docs/spec/interface-localization/*` 和 done plans。 | 优先为 interface localization、navigation / launch flow、MVP learning content 三个当前活跃方向补 `impl.md`，只记录代码路径、核心类型、测试和偏差，不承载新决策。 | 新会话应能从 `impl.md` 找到 `InterfaceLanguagePreference`、`Localizable.xcstrings`、App shell locale 注入、UI 测试路径。 | Fixed |
| SPEC-007 | P2 | 文档准确性问题 | `mvp-ui-flow-and-design-system.md` 仍标 Draft，且“当前缺口”部分没有分层表达当前事实：代码已有 `InMemoryLearningContentRepository` 支持 Entry 创建、mock rendering、practice 和 memory，也已有 Entry editor/detail/practice 路由；但真实持久化、真实编辑保存、启动恢复、SQLite / GRDB 和附件仍未完成。 | `docs/spec/ui-design/mvp-ui-flow-and-design-system.md:39-47` 写缺口；`Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift:68-115` 已有内存 createEntry 并生成 mock rendering / practice / memory；`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 已有 Entry editor/detail；`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift` 已有保存后的详情导航。 | 更新为“真实持久化未完成、内存/Local Mock 页面闭环已部分存在”，避免后续 AI 重复实现已落地的内存闭环或误删现有 mock 路径。 | 对照 `Packages/LangoTraceData` 和 `Packages/LangoTraceUI` 当前代码，重写当前事实段。 | Fixed |
| SPEC-008 | P2 | 测试与验证缺口 | `docs/testing/README.md` 已有验证内容，多个 spec 也提出截图、Dynamic Type、Reduce Motion、长文本、本地化、VoiceOver 要求；问题是 `docs/spec/` 缺少统一验证入口或对 `docs/testing/README.md` 的明确委托关系，后续 AI 不容易按任务类型选择最低验证集合。 | `docs/spec/003-ui-design-system.md:118-128`、`docs/spec/006-interface-localization-and-language-boundaries.md:267-285`、`docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md:404-412` 均提出验证矩阵；`docs/testing/README.md` 已有验证规则；`docs/spec/README.md:66` 仍把测试与验证规范列为后续建议。 | 新增 `docs/spec/008-testing-and-verification.md`，或在 `docs/spec/README.md` 明确把验证权威委托给 `docs/testing/README.md` 并补任务类型矩阵。定义文档-only、Swift package、Xcode build、截图、本地化、无障碍各自最低检查。 | 新任务结束前，AI 能按任务类型选择验证命令和截图 / 手动检查范围。 | Fixed |

## 4. 逐份审查摘要

### 001 规范文档治理

结构清楚，优先级和变更规则可用。主要缺口是它没有强制定义“Draft 规范被列入核心规范时如何处理”，导致 `006` 的状态问题。建议补充：`Draft` 可以被入口列为候选阅读材料，但不能被称为“当前核心规范”，除非该入口同时说明其非强制性质。

### 002 导航与路由规范

产品方向与 Apple 平台差异基本准确：iPhone Tab、iPad 三栏、macOS Sidebar / Inspector 方向合理，也明确了语言空间和主数据写入边界。短板在 macOS command surface 仍偏后续描述；进入 Mac 工作台阶段前，应把 Settings scene、菜单栏、快捷键、多窗口和窗口状态写成更明确的执行规则或实现地图。

### 003 UI 设计系统规范

对产品气质、状态表达、Mock 边界、语言空间底部工具区、可访问性和本地化的约束较完整，能防止“装饰性美化”。当前主要问题是它承载了过多跨领域规则，包括权限、错误状态、测试矩阵和本地化验证；这些规则需要分流到专门 spec，否则后续开发者很难知道哪个文档才是最终执行规则。

### 004 SwiftUI 架构规范

模块依赖方向、View 副作用边界、状态分层和平台外壳 / 共享内容分层都符合当前代码结构。需要补充的是现代 SwiftUI API 选择和最低系统版本策略：项目部署 iOS 18 / macOS 15，仍使用 `ObservableObject` / `@StateObject` 是可接受的 App shell 早期选择，但 spec 目前只把 `@Observable` vs `ObservableObject` 放在“可演进部分”，没有告诉后续新功能默认如何选。

### 005 AI Provider、Prompt 与隐私规范

隐私和请求边界严谨，能防止 UI 直接发请求、日志记录完整请求体、长期记忆无限发送等高风险错误。缺口是 Prompt Registry、Provider 配置模型、请求日志元数据、失败类型、结构化输出 schema 仍处于原则层。真实 AI 接入前应从该规范拆出或补充 AI 实现地图。

### 006 界面国际化与语言边界规范

内容是当前最完整的 spec 之一，准确区分了界面语言、母语、目标学习语言、Provider / Prompt 输出语言、地区格式和内容语言。问题是状态仍为 Draft，与当前代码和入口地位冲突。推荐优先升为 Accepted，并把 8 语言扩展的“已实现范围”和“未完整翻译范围”写清。

### ui-design 子目录

两个 UI 设计规格能有效约束付费级 UI 审查，不是泛泛美化。但它们仍是 Draft，且部分“当前事实”没有区分内存 / mock 闭环与真实持久化缺口。建议保留为专项设计规格，但不要让它们替代 `003` 的长期规范；已采纳的结论应回写 `003`，当前实现事实应进入 `impl.md`。

### interface-localization 子目录

规格质量高，但状态管理混乱：一个 String Catalog 闭环文档仍是 Draft，另一个扩展文档是 Implemented，却存在 String Catalog 覆盖缺口。建议把“设计方案”“实现状态”“验证报告”拆清：设计方案可 Done / Accepted，当前实现状态应由 `impl.md` 或 review round 记录。

## 5. 修复落点

本轮已按以下顺序完成修复：

1. 状态准确性：处理 `SPEC-001`、`SPEC-002`、`SPEC-007`，避免后续 AI 被 Draft / Implemented 误导。
2. 高风险缺口：新增数据存储、权限隐私、测试验证三份 spec。
3. 实现地图：新增 interface localization、navigation / launch flow、MVP learning content 三份 `impl.md`。
4. 平台规则：通过 navigation 实现地图明确 macOS `Settings` scene、菜单、快捷键和多窗口仍未实现，不把当前代码写成已完成。

## 6. 后续独立任务

- 真实数据层实现时，应基于 `docs/spec/007-data-storage-migration-export-and-attachments.md` 创建独立 feature 任务方案。
- 权限、Photos、Speech、OCR、录音或 TTS 接入时，应基于 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 创建独立 feature 任务方案。
- 完成 8 语言 String Catalog 翻译、人工审校和发布材料时，应基于 `docs/spec/interface-localization/impl.md` 与 `docs/testing/README.md` 创建独立 docs / feature 任务方案。

## 7. 本轮不修改的内容

本轮只修订文档体系，不修改 Swift 代码，不把未接入的真实数据库、AI、Speech、Sync、StoreKit 或 macOS command surface 写成已完成能力。
