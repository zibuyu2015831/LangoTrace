# Spec 问题复审报告

日期：2026-05-18
状态：Verified Findings
范围：对 `reports/spec-deep-audit.md` 中 8 个问题做基于代码和现有文档的严格复审。

## 1. 复审口径

本轮不新增产品判断，只复核三个问题：

- 记录的问题是否真实存在。
- 问题描述是否准确，是否把“没有规则”和“规则分散 / 权威边界不清”混为一谈。
- 修复方向是否能在当前文档体系内落地，不要求本轮顺手修 Swift 代码。

证据优先级：

1. 当前源码、`project.yml`、资源文件和测试入口。
2. `docs/README.md`、`docs/spec/README.md`、相关 spec、`docs/testing/README.md`。
3. 已归档的任务方案和 review round 只作为过程记录，不作为当前实现事实的唯一依据。

## 2. 复审结论

8 个问题均可保留，但其中 2 个需要修正表述：

- `SPEC-007`：原问题方向成立，但应明确为“未分层表达内存 mock 闭环已存在与真实持久化缺口”，不能写成代码完全没有 Entry 创建 / 详情路径。
- `SPEC-008`：原问题方向成立，但应明确为“缺少 spec 级验证入口和权威关系”，不能写成项目没有测试 / 验证文档。

其余 6 个问题的描述、证据和修复方向与当前代码事实一致。

## 3. 分项复审

| ID | 复审结论 | 准确性修正 | 可行性判断 |
| --- | --- | --- | --- |
| SPEC-001 | 成立 | 无需修正。`006` 仍是 Draft，但已被 `docs/spec/README.md` 列为核心规范，并且 Core 枚举与 bundle localizations 已按 8 语言落地。 | 可行。将 `006` 升级为 `Accepted`，或在入口明确 Draft 规范的非强制性质，均为文档内修复。 |
| SPEC-002 | 成立 | 无需修正。扩展设计文档标 `Implemented`，但 String Catalog 并未覆盖 8 语言。该问题是文档状态过度承诺，不是 Core 枚举缺失。 | 可行。把状态改为部分实现，并补 String Catalog 覆盖检查即可，不要求立即补齐所有翻译。 |
| SPEC-003 | 成立 | 无需修正。正式数据存储、迁移、导出、附件 spec 仍不存在；当前 Data package 只有空语言空间协议和内存学习内容 repository。 | 可行。新增数据 spec，先定义主数据 / 派生数据 / 附件 / 导出 / 删除边界，再驱动后续实现。 |
| SPEC-004 | 成立 | 需避免解读为“没有任何隐私规则”。准确问题是 AI 隐私规则存在，但 Photos / Speech / OCR / 录音 / Keychain / 日志诊断缺少统一执行源。 | 可行。新增权限与本地隐私 spec，或将 AI 隐私、权限、日志诊断拆成可检索的规则入口。 |
| SPEC-005 | 成立 | 无需修正。当前 App 只有 `WindowGroup`，没有 `Settings` scene、`.commands`、菜单或快捷键；现有 spec 也只写到原则和候选方向。 | 可行。先补阶段门槛和实现地图，不需要本轮补代码。 |
| SPEC-006 | 成立 | 无需修正。`docs/spec/README.md` 定义了模块级 `impl.md`，当前 `docs/spec/` 下没有真实模块 `impl.md`。 | 可行。优先补 interface localization、navigation / launch flow、MVP learning content 三个实现地图。 |
| SPEC-007 | 成立但已收窄 | 修正为：MVP UI 规格没有分层表达“内存 / mock 学习内容闭环已存在”和“真实持久化、编辑保存、启动恢复仍缺失”。 | 可行。只需更新当前事实段，并引用 `InMemoryLearningContentRepository`、Entry editor/detail、practice/memory 路由。 |
| SPEC-008 | 成立但已收窄 | 修正为：验证内容已经存在于 `docs/testing/README.md` 和多个 spec 中，但 `docs/spec/` 缺少统一入口或明确委托关系。 | 可行。可新增 `008-testing-and-verification.md`，也可在 `docs/spec/README.md` 明确把验证权威委托给 `docs/testing/README.md` 并列任务类型矩阵。 |

## 4. 关键证据

### SPEC-001 / SPEC-002：界面语言状态与资源覆盖

- `docs/spec/README.md` 把 `006-interface-localization-and-language-boundaries.md` 列为当前核心规范。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 的状态仍为 `Draft`。
- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift` 中 `InterfaceLanguagePreference` 已包含 `system / en / zh-Hans / es / ja / fr / de / ko / ru`。
- `project.yml` 的 iOS 和 macOS `CFBundleLocalizations` 已声明同一组 8 语言。
- 对 `Localizable.xcstrings` 的结构化检查结果为：`total=277`，`missing_any=198`，`missing_new6=198`。样例缺失 key 包括 `audioPanel.title`、`common.currentStep`、`entry.empty.title`、`hero.title`、`ipad.emptyWorkspace.body`。

判断：文档状态确实不准。Core / App target 语言清单已经扩大，但资源覆盖没有完成，不能把语言扩展整体写成 `Implemented`。

### SPEC-003：数据层规范缺口

- `docs/spec/README.md` 仍将数据存储、迁移与导出列为推荐后续补充。
- `Packages/LangoTraceData/Sources/LangoTraceData/DataBoundary.swift` 中 `LanguageSpaceRepository` 仍为空协议。
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift` 的 `InMemoryLearningContentRepository` 能创建内存 Entry、mock rendering、practice 和 memory，但不等同于持久化 schema、迁移、附件和导出规范。

判断：缺失的是正式数据规范，不是完全没有数据模型或演示 repository。

### SPEC-004：权限、本地隐私和日志诊断边界

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 已覆盖 AI Provider、Prompt、API Key、请求预览和日志原则。
- `docs/spec/003-ui-design-system.md` 有 UI 状态与可访问性相关原则。
- `docs/spec/README.md` 仍将权限、本地隐私 / 加密、日志 / 诊断列为后续补充。

判断：现有 AI 隐私规范可用，但它不能独立覆盖 Photos、Speech、OCR、录音、TTS、系统权限弹窗、日志脱敏和本地加密的完整执行边界。

### SPEC-005：macOS command surface

- `LangoTraceApp/LangoTraceApp.swift` 当前只有 `WindowGroup`，未声明 `Settings` scene。
- 代码搜索没有发现 `.commands`、`CommandMenu`、`keyboardShortcut` 或菜单命令实现。
- `docs/spec/002-navigation-and-routing.md` 已提到 macOS 菜单栏、快捷键、多窗口，但仍是原则和阶段候选表达。

判断：问题真实存在。修复应先是 spec 阶段门槛，不应把当前代码写成已经完成。

### SPEC-006：实现地图

- `docs/spec/README.md` 定义模块级 `spec.md / impl.md` 模式。
- `find docs/spec -maxdepth 3 -name impl.md -print` 无输出。
- 当前实现事实散在 UI 设计子规格、interface localization 子规格、任务方案和 review 记录中。

判断：缺少 `impl.md` 是可验证事实。新增实现地图能降低后续 AI 对 done plan 的依赖。

### SPEC-007：MVP UI 当前事实

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift` 中 `InMemoryLearningContentRepository.createEntry` 已能创建 Entry，并生成 mock rendering、practice item 和 memory item。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 已有 `EntryEditorView`、`EntryDetailView` 和 practice session 相关视图。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift` 已有 Entry 创建 sheet、保存后的详情导航、entry detail / practice / settings navigation destinations。
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 的当前缺口没有清楚区分这些内存 / mock 能力与真实持久化缺口。

判断：原问题成立，但必须收窄措辞。真正问题是事实分层不准，而不是代码没有任何 Entry 路径。

### SPEC-008：测试与验证权威关系

- `docs/testing/README.md` 已存在，并覆盖 `scripts/verify.sh`、截图、本地化、Dynamic Type、Reduce Motion、权限等验证方向。
- `docs/spec/003-ui-design-system.md`、`006-interface-localization-and-language-boundaries.md` 和 UI 审查规格也分别提出验证要求。
- `docs/spec/README.md` 仍将测试与验证规范列为推荐后续补充，没有说明 `docs/spec/` 与 `docs/testing/README.md` 的权威关系。

判断：原问题不能表述为“没有测试验证文档”。准确问题是验证要求分散，spec 入口没有给出任务类型到验证方式的统一选择规则。

## 5. 对原报告的回修

本轮已回修 `reports/spec-deep-audit.md` 中 `SPEC-004`、`SPEC-007`、`SPEC-008` 的措辞：

- `SPEC-004`：强调“缺少统一执行规则源”，不否认 AI 隐私规范已有内容。
- `SPEC-007`：强调“真实持久化缺口和内存闭环已存在的事实未分层表达”。
- `SPEC-008`：强调“缺少 spec 级验证入口或委托关系”，不否认 `docs/testing/README.md` 已有验证内容。

## 6. 后续修复建议

本节保留复审时的建议顺序。2026-05-18 后续已按该顺序完成长期文档修复，具体落点见本轮 README 和 `reports/spec-deep-audit.md` 的修复落点。

原建议顺序：

1. 先修状态和事实准确性：`006` 状态、多语言扩展实现状态、MVP UI 当前事实。
2. 再补高风险新 spec：数据存储 / 迁移 / 导出、权限 / 本地隐私 / 日志。
3. 然后补验证入口和实现地图：测试验证权威关系、interface localization / navigation / MVP content 的 `impl.md`。
4. 最后细化 macOS command surface 和 SwiftUI 新功能默认 API 策略。
