# 语迹 / LangoTrace 文档总入口

本文档是语迹 LangoTrace 后续开发的唯一真实文档入口，也是 AI 辅助编程、产品讨论、技术评审和原型迭代时优先阅读的入口文件。

仓库根目录的 `AI_ENTRY_POINT.md`、`CLAUDE.md` 和 `AGENTS.md` 都是指向本文档的软链接，用于方便不同 AI 工具从仓库根目录直接读取入口内容。后续只维护本文档，不单独维护第二份入口内容。

## 1. 使用原则

每次新会话应先阅读根目录 `AI_ENTRY_POINT.md`、`CLAUDE.md`、`AGENTS.md` 或本文档，然后根据任务类型继续读取相关文档。这些入口指向同一份内容。

AI 不应只根据用户当前一句需求直接实现功能。涉及产品、数据、隐私、同步、AI 请求、付费、测试或发布的任务，都必须回到对应文档确认边界。

默认工作方式：

1. 先确认当前任务属于产品、原型、工程、架构、测试、发布或研究中的哪一类。
2. 按本文档的阅读路径读取相关资料。
3. 对照既有产品决策和 ADR，避免引入冲突概念。
4. 如果形成新的重要判断，更新对应文档，不只停留在聊天记录。
5. 完成前运行适合当前任务的检查，例如链接检查、文档一致性检查、构建或测试。
6. 如果任务可能导致文档滞后于代码，按 [文档审查机制](review/README.md) 做日常文档影响检查、事件触发专项审查或里程碑轻量全审。
7. 如果在开发、审查或阅读文档时发现文档体系自身存在结构性问题，例如模板缺陷、规范过期、历史记录误用、文档谬误或无用临时文件，应按 [文档审查机制](review/README.md) 主动汇报，并给出证据、影响、必要性、可行性、风险和推荐方案。

### 1.1 早期开发阶段的重构原则

当前项目仍处于开发起步阶段，已有 SwiftUI App Shell、Mock 数据、原型页面和文档方案都属于可快速迭代的早期资产。它们用于帮助验证产品方向和工程边界，不应成为后续正确设计的历史负担。

因此，在真实用户数据、正式数据库 schema、同步协议、StoreKit 付费流程和公开发布版本形成之前，开发时遵守以下原则：

1. 如果发现现有框架、模块边界、数据模型、路由设计、UI 结构或交互方案存在明显问题，可以直接提出推翻重做，不必为了保留早期 mock 或临时代码而做复杂兼容。
2. 当前阶段不为尚不存在的历史数据设计迁移，不为临时展示字符串设计向后兼容，不为已废弃的原型页面保留代码路径。
3. 重要重做仍必须先写入 `docs/plans/active/` 任务方案，说明为什么原设计不再适合、替代方案是什么、会删除或重写哪些内容，并经用户确认后执行。
4. 如果推翻的是第 4 节中的核心产品或架构决策，必须新增或更新 ADR；如果只是清理早期实现细节，可在任务方案中记录即可。
5. 判断优先级是：产品正确性、长期架构清晰度、三端体验质量、测试可维护性，优先于早期代码的局部兼容。

简言之：早期实现可以被重写，核心决策需要有记录地调整。不要让临时代码变成长期架构。

### 1.2 保守文档自进化原则

LangoTrace 的文档体系是工程控制面，承载产品北极星、隐私边界、AI 请求边界、数据和同步路线、验证入口以及后续 AI 会话恢复能力。AI 发现文档体系问题时，有主动汇报和提出优化方案的义务，但该机制不授权 AI 在未获确认时自动删除历史记录、改写核心决策或改变文档权威关系。

处理文档体系问题时遵守以下边界：

1. 当前事实源优先修正，历史证据优先保留。
2. 文档权威关系高于单次任务便利性；不能为了让当前任务顺利而把代码偏差包装成新决策。
3. 删除是最后手段；降权、归档、索引标注和补充当前事实源优先。
4. 涉及产品北极星、隐私、数据、同步、AI Provider、权限、StoreKit、发布或核心架构边界的文档变化，必须按 ADR、spec、architecture、review 或 task plan 的职责分流，并保留用户确认链路。
5. 轻微措辞、排版或非误导性风格问题默认不升级为文档治理任务，除非用户明确要求或它反复造成误判。

## 2. 项目当前状态

当前仓库已经完成 SwiftUI Multiplatform 工程初始化，并从纯 App Shell 推进到产品体验骨架阶段。现有实现可以展示 Welcome / Onboarding / Main 启动路由、内存语言空间 preview、iPhone / iPad / macOS 分平台主界面、Mock 学习内容、隐私状态图标、iPad 侧栏折叠和边缘手势。

当前仍处于真实数据、真实 AI、真实语音、真实同步和 StoreKit 之前的早期阶段。现有页面和状态用于验证产品方向、平台结构和工程边界，不代表核心学习闭环已经可用。

已完成：

- 产品主参考文档。
- 技术框架与开发路线参考。
- 开发环境记录。
- 参考项目使用指南。
- 多端静态 HTML 原型。
- 文档体系、初始模块边界和关键 ADR。
- 第一批开发一致性规范。
- 统一任务方案目录和模板。
- SwiftUI Multiplatform App Shell。
- XcodeGen `project.yml` 和生成的 `LangoTrace.xcodeproj`。
- Core / UI / Data / AI / Speech / Sync 初始本地 Swift Package 边界。
- `LangoTraceApp` 中的 `AppEnvironment` 和 `AppSessionState`。
- Welcome / Onboarding / Main 三段启动状态。
- `LaunchRoute` 缺少语言空间时回到 onboarding 的路由保护。
- `OnboardingDraft`、`LearningLanguage`、`LanguageLevel` 和 `LanguageSpacePreview` 的内存模型。
- iPhone Tab、iPad 学习桌面、macOS 工作台的原生 SwiftUI 骨架。
- 隐私状态模型和 AI / 同步 / 设置状态图标展示。
- iPad 左右辅助面板折叠按钮和边缘手势判定 helper。
- Core、Data 和 UI package 的首批单元测试。
- 统一验证脚本 `scripts/verify.sh`。

尚未完成：

- 真实语言空间持久化和启动恢复。
- 真实生活记录创建、时间线选择和本地记录闭环。
- 数据库 schema。
- SQLite / GRDB Repository、迁移、FTS、附件存储和导出。
- AI Provider 真实配置、Keychain API Key、请求预览、请求日志和外部请求。
- Prompt Preset 的真实渲染和执行链路。
- TTS、录音、Speech、OCR、照片和权限接入。
- 同步引擎。
- Sync Adapter、冲突处理和对象存储配置。
- StoreKit 配置。
- TestFlight / App Store 发布材料和隐私标签。

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
15. 具体开发前应读取相关 `docs/spec/` 规范，避免导航、UI、SwiftUI 架构和 AI 请求路径发散。
16. 新功能、bug 修复、架构调整、数据/AI/隐私/同步/权限/付费相关任务，实现前必须先创建 `docs/plans/active/YYYY-MM-DD-<type>-<short-topic>.md` 并经用户确认。
17. 高风险实现或阶段性完成后必须检查文档影响。数据库、AI Provider、权限、同步、StoreKit、发布验证、ADR 冲突、首次启动闭环、语言空间闭环、本地记录闭环、验证脚本、XcodeGen、包边界或 App 启动结构变化，应按 [文档审查机制](review/README.md) 触发专项审查或在任务方案中说明跳过原因。

## 5. 按任务类型读取文档

### 5.1 产品、功能和交互讨论

优先读取：

- [任务方案文档规范](plans/README.md)
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
- [UI 设计系统规范](spec/003-ui-design-system.md)
- [导航与路由规范](spec/002-navigation-and-routing.md)
- [界面国际化与语言边界规范](spec/006-interface-localization-and-language-boundaries.md)
- `prototypes/langotrace-multi-device-prototype/README.md`

适用任务：

- 静态 HTML 原型修改。
- iPhone / iPad / Mac 页面结构优化。
- 高级感、简洁性、导航和设置入口调整。
- 界面语言、母语和目标学习语言的显示边界。

### 5.3 SwiftUI 工程初始化

优先读取：

- [任务方案文档规范](plans/README.md)
- [项目初始化规划](development/project-initialization.md)
- [三端开发顺序方案](development/001-platform-development-sequence.md)
- [开发环境记录](development/environment.md)
- [初始模块边界](architecture/001-initial-module-boundaries.md)
- [开发规范治理](spec/001-guideline-governance.md)
- [SwiftUI 架构规范](spec/004-swiftui-architecture.md)
- [导航与路由规范](spec/002-navigation-and-routing.md)
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

- [任务方案文档规范](plans/README.md)
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 2、5、6、9 节
- [文档体系规范](_meta/documentation-system.md) 的第 4 节
- [数据存储、迁移、导出与附件规范](spec/007-data-storage-migration-export-and-attachments.md)
- [learning-content 实现地图](spec/learning-content/impl.md)
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

- [任务方案文档规范](plans/README.md)
- [产品主参考文档](product-main-reference.md) 的第 9、10 节
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 7、8 节
- [初始模块边界](architecture/001-initial-module-boundaries.md)
- [AI Provider、Prompt 与隐私规范](spec/005-ai-provider-prompt-and-privacy.md)
- [权限、本地隐私与诊断日志规范](spec/008-permissions-local-privacy-and-diagnostics.md)
- [ADR-005：坚持本地优先和用户自带 Provider](decisions/005-local-first-and-user-owned-providers.md)

适用任务：

- Prompt Preset 设计。
- AI 文本转换、写作检查和修改。
- 请求预览、请求日志和隐私边界。
- AVSpeechSynthesizer、AVFoundation、Speech、Vision、PhotosUI 集成。

### 5.6 测试、发布和付费

优先读取：

- [文档体系规范](_meta/documentation-system.md) 的第 2.7、2.8、4.3 节
- [技术框架与开发路线参考](technical-framework-roadmap.md) 的第 2.8 节
- [测试与验证入口规范](spec/009-testing-and-verification.md)
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

- [参考项目使用指南](reference/README.md)
- [参考研究文档目录](reference/research/README.md)

适用任务：

- 下载或研究开源项目。
- 许可证风险判断。
- 对比竞品。
- 调整产品差异化。

### 5.8 文档审查和文档一致性治理

优先读取：

- [任务方案文档规范](plans/README.md)
- [文档体系规范](_meta/documentation-system.md)
- [文档审查机制](review/README.md)
- [文档审查索引](review/INDEX.md)

适用任务：

- 检查 docs 是否和代码实现一致。
- 阶段性功能完成后的文档影响检查。
- 数据、AI、权限、同步、StoreKit、发布验证或 ADR 冲突后的专项审查。
- MVP、数据层、AI 层、同步层、付费发布层结束时的里程碑轻量全审。
- AI 会话发现文档与代码不一致后的定向审查。

## 6. 文档更新落点

形成新结论时，按以下规则写回：

- 每次重要开发或修复任务的任务方案：写入 `docs/plans/active/`，完成后移入 `docs/plans/done/`。
- 产品定位、语言空间、买断制、核心功能：更新 [产品主参考文档](product-main-reference.md)。
- 技术选型、平台策略、数据和同步路线：更新 [技术框架与开发路线参考](technical-framework-roadmap.md)。
- 不可轻易反转的取舍：新增或更新 `docs/decisions/`。
- 模块边界、数据流、Provider、Sync、StoreKit 架构：新增或更新 `docs/architecture/`。
- 导航、UI、SwiftUI 架构、AI 请求路径等开发一致性约束：新增或更新 `docs/spec/`。
- 具体实施步骤：写入 `docs/plans/active/`。
- 大功能规格和长期规范：写入 `docs/spec/`；如果只是一次性任务执行方案，写入 `docs/plans/active/`。
- 验证流程和手动测试：写入 `docs/testing/`。
- App Store、TestFlight、StoreKit 和隐私标签：写入 `docs/release/`。
- 外部参考、研究材料和未定结论：写入 `docs/reference/` 或 `docs/reference/research/`；结论被采纳后写回主参考、spec、architecture 或 ADR。
- 文档审查机制、审查轮次索引、专项审查和里程碑全审：写入 `docs/review/`。

## 7. 文档目录结构

```text
AI_ENTRY_POINT.md -> docs/README.md
CLAUDE.md -> docs/README.md
AGENTS.md -> docs/README.md
docs/
  README.md
  _meta/
    directory-responsibilities.md
    documentation-system.md
  archive/
  product-main-reference.md
  technical-framework-roadmap.md
  architecture/
  decisions/
  development/
    README.md
    environment.md
    project-initialization.md
    001-platform-development-sequence.md
  plans/
    README.md
    active/
    done/
    examples/
  prompts/
  reference/
    README.md
    projects/
    research/
      README.md
  spec/
  review/
    README.md
    INDEX.md
    rounds/
  release/
  testing/
```

## 8. 目录职责

- `architecture/`：工程架构、模块边界、数据模型、同步模型、AI Provider、长期记忆和安全边界。
- `_meta/`：文档体系自身规则，记录目录职责、权威类型、写入规则和退出目录。
- `archive/`：历史参考和已退出目录内容，不作为新任务入口。
- `decisions/`：架构决策记录，采用 ADR 风格，记录重要取舍、背景、结论和复审条件；不维护 implementation 文档或阶段执行细节。
- `plans/`：统一任务方案目录；一项需求、一个 bug 或一次文档治理只维护一份方案，按 active/done 管理生命周期。
- `prompts/`：Prompt Registry，记录真实代码 Prompt 的英文版本、中文版本、输入变量、输出契约和隐私边界。
- `reference/`：外部参考和研究资料入口，包含本地参考项目软链接、功能参考映射、许可证边界和研究材料；不是产品决策源、架构事实源或实现事实源。
- `spec/`：开发一致性规范和实现地图，记录导航、UI、SwiftUI 架构、AI Provider、隐私等具体开发约束；模块级 `impl.md` 放在这里而不是 `decisions/`。
- `review/`：文档一致性治理机制、审查轮次索引、专项审查和里程碑轻量全审记录。
- `development/`：阶段级开发 runbook、工程初始化记录和跨任务工程路线；不存放单项需求或 bug 的实施方案。
- `release/`：买断制、StoreKit、App Store、TestFlight、版本策略和发布检查清单。
- `testing/`：测试策略、手动测试流程、回归用例、模拟器与真机验证记录。

已退出目录见 [_meta/directory-responsibilities.md](_meta/directory-responsibilities.md)。`docs/worklogs/` 和 `docs/superpowers/` 已完成迁移，不再作为当前目录保留或恢复。

## 9. 当前优先级

后续开发优先级应保持克制：

1. 做首次启动引导与语言空间的最小闭环。
2. 做本地记录和英语示例学习闭环。
3. 再接入真实 AI Provider、TTS、听写、回译、SQLite、同步和 StoreKit。

第一阶段不要同时实现完整数据库、完整 AI、完整同步、完整 StoreKit 和完整视觉系统。

## 10. 完成前检查

涉及文档任务时，至少检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

如果文档任务涉及代码实现状态、核心决策、跨文档一致性或阶段性完成，还应按 [文档审查机制](review/README.md) 做语义检查，确认当前事实、决策、计划和过程记录没有混用。

涉及 Swift 工程任务时，根据实际工程状态检查：

```bash
scripts/verify.sh
```

当前 `scripts/verify.sh` 展开为：

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -list -project LangoTrace.xcodeproj
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
swiftlint --no-cache
swiftformat --lint . --cache ignore
if rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'; then
  echo "Documentation placeholder scan found entries." >&2
  exit 1
fi
git status --short
```

如果某项检查暂时不能运行，必须说明原因和剩余风险。
