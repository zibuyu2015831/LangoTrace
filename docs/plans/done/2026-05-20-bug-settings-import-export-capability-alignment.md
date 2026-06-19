# Settings Import Export Capability Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or follow this plan task-by-task inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 统一 iPhone、iPad 和 macOS 设置列表中的导入导出能力项，避免共享设置模型只显示“导出”而漏掉“导入”。

**Architecture:** 当前三端设置列表都来自 `LearningContentRepository.settingsCapabilities(for:)` 返回的 `SettingsCapability.Kind`。本方案把共享能力 kind 从 `export` 改为 `importExport`，让设置列表、详情页 key、String Catalog 和文档事实源统一表达“导入导出”。iPad / macOS 既有独立导入导出页面入口继续保留，作为工作台页面；共享设置 row 作为能力边界说明。

**Tech Stack:** Swift Package (`LangoTraceData`, `LangoTraceUI`), SwiftUI, Swift Testing, String Catalog (`Localizable.xcstrings`), `scripts/verify.sh`。

---

## 状态

- 状态：Verified
- 类型：bug
- 创建日期：2026-05-20
- 最后更新日期：2026-05-20
- 用户确认记录：2026-05-20，用户确认“立即创建对应的方案文档，确认无误后开始执行”。

## Bug 描述

Mac 端截图显示侧栏有“导入导出”工作台入口。检查三端后发现：iPad 也有左侧“导入导出”页面入口，但三端共享设置能力列表中的相关 row 仍叫“导出”。这会让 iPhone 设置页看起来缺少对应能力，也让 iPad / macOS 的工作台入口和设置能力项语义不一致。

## 复现方式

1. 打开 macOS 工作台，侧栏可见 `Import / Export` / `导入导出`。
2. 进入 iPhone 设置列表，查看由 `SettingsView` 渲染的 `settingsCapabilities`。
3. 进入 iPad 设置列表，查看由 `PadWorkspaceContentView.settingsList` 渲染的 `settingsCapabilities`。
4. 对比共享能力项：当前模型为 `SettingsCapability.Kind.export`，本地化 key 为 `settings.export.*`，中文标题为“导出”。

## 预期行为

- iPhone 设置列表应有“导入导出”能力项。
- iPad 设置列表应有“导入导出”能力项；左侧独立“导入导出”页面入口继续保留。
- macOS Settings 能力列表应有“Import / Export”能力项；Sidebar `Import / Export` section 继续保留。
- 详情页仍明确为 unavailable / 规划中状态，不打开文件面板、不读取导入文件、不写入导出包、不访问附件目录。

## 实际行为

- 共享设置模型只定义 `SettingsCapability.Kind.export`。
- `LocalizedChrome.swift` 把该 kind 映射到 `settings.export.title`。
- `Localizable.xcstrings` 的中文标题是“导出”，没有覆盖导入。
- iPhone 没有 iPad / macOS 那样的独立导入导出页面入口，因此用户更容易感知为缺少“导入导出”设置。

## 根因分析

根因是早期页面闭环中把“大屏工作台页面入口”命名为 `importExport`，但共享设置能力项沿用了较窄的 `export` 命名。三端设置列表共享同一能力源，导致 iPhone、iPad、macOS 设置能力列表都只能表达“导出”。

置信度：94%

置信度依据：

- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift` 中 `Kind` 只有 `export`，没有 `importExport`。
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift` 中 service settings capabilities 返回 `kind: .export`。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift` 中 `.export` 映射到 `settings.export.title`。
- `docs/platform-page-inventory.md` 已记录 iPad 和 macOS 独立导入导出页面入口，同时 iPhone 设置列表描述包含“导出”。

备选原因：

- 也可能是有意将“导入导出页面”和“导出设置”分成两个能力。但当前文档与 unavailable 文案都把导入导出作为同一规划能力处理，且真实数据层尚未接入，不需要在设置层拆成两个 row。

## 目标

1. 共享设置能力 kind 统一为 `importExport`。
2. 三端设置列表标题统一显示“导入导出” / `Import / Export`。
3. 设置详情页使用 `settings.importExport.summary/detail/nextRequirement`。
4. iPad / macOS 独立导入导出工作台入口不删除、不降级。
5. 回归测试覆盖 kind、key、repository settings 列表和 catalog key。

## 范围

涉及的代码文件路径：

- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`

涉及的文档路径：

- `docs/platform-page-inventory.md`
- `docs/plans/active/2026-05-20-bug-settings-import-export-capability-alignment.md`

参考的代码文件路径：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`

## 不做什么

- 不接入真实文件导入、真实导出、文件面板、附件目录访问或数据库导出。
- 不新增 iPhone 底部 Tab。
- 不删除 iPad 左侧“导入导出”页面入口。
- 不删除 macOS Sidebar `Import / Export` section。
- 不改变 Sync、Local Data、Privacy 或 AI Provider 的真实能力状态。

## 实施方案

### Task 1: 写失败测试，锁定共享设置能力命名

**Files:**

- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`

- [ ] **Step 1: 在 `PageClosureStateTests.settingsCapabilityChromeUsesUILocalizationKeys` 中加入 importExport 期望**

```swift
#expect(SettingsCapability.Kind.importExport.localizedTitleKey == "settings.importExport.title")
let settingsKinds = SettingsCapability.Kind.allCases
#expect(settingsKinds.contains(.importExport))
#expect(!settingsKinds.map(\.rawValue).contains("export"))
```

- [ ] **Step 2: 在 `LearningContentStoreTests.storeCentralizesRepositoryReadsAndMutations` 中加入 settings capabilities 期望**

```swift
#expect(store.settingsCapabilities.map(\.kind).contains(.importExport))
#expect(!store.settingsCapabilities.map(\.kind.title).contains("export"))
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/settingsCapabilityChromeUsesUILocalizationKeys
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests/storeCentralizesRepositoryReadsAndMutations
```

Expected: FAIL，原因是 `SettingsCapability.Kind.importExport` 尚不存在。

### Task 2: 实现共享能力 kind 和 repository 数据

**Files:**

- Modify: `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- Modify: `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`

- [ ] **Step 1: 将 `SettingsCapability.Kind.export` 改为 `importExport`**

```swift
case importExport
```

- [ ] **Step 2: 保持图标语义为文件导出/导入 tray**

```swift
case .importExport:
    "tray.and.arrow.down"
```

- [ ] **Step 3: repository 中返回 `.importExport` 和 `settings.importExport.*` keys**

```swift
SettingsCapability(
    kind: .importExport,
    status: .unavailable,
    summary: "settings.importExport.summary",
    detail: "settings.importExport.detail",
    nextRequirement: "settings.importExport.nextRequirement"
)
```

- [ ] **Step 4: UI localization 映射到 `settings.importExport.title`**

```swift
case .importExport:
    "settings.importExport.title"
```

- [ ] **Step 5: 运行 Task 1 测试确认通过**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/settingsCapabilityChromeUsesUILocalizationKeys
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests/storeCentralizesRepositoryReadsAndMutations
```

Expected: PASS。

### Task 3: 更新 String Catalog 设置详情文案

**Files:**

- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

- [ ] **Step 1: 将 `settings.export.title/summary/detail/nextRequirement` key 改为 `settings.importExport.title/summary/detail/nextRequirement`**

中文内容：

```text
settings.importExport.title = 导入导出
settings.importExport.summary = 数据模型稳定后，导入导出将围绕本地资料库和附件目录设计。
settings.importExport.detail = 本地资料库模型稳定后，导入导出应覆盖生活记录、学习材料、附件和隐私安全的元数据；当前不会打开文件面板、读取导入文件或写入导出包。
settings.importExport.nextRequirement = 完成本地资料库模型、附件处理、文件访问规则，以及 Markdown、JSON 和附件导入导出格式设计。
```

英文内容：

```text
settings.importExport.title = Import / Export
settings.importExport.summary = Import and export will be designed around the local library and attachments after the data model is stable.
settings.importExport.detail = Import and export should cover life entries, learning material, attachments, and privacy-safe metadata after the local library model is stable. This page does not open file panels, read import files, or write export packages.
settings.importExport.nextRequirement = Finalize the local library model, attachment handling, file access rules, and Markdown, JSON, and attachment import/export formats.
```

- [ ] **Step 2: 增加 catalog key 测试**

```swift
@Test("Import export setting resources are present and export-only keys are removed")
func importExportSettingResourcesArePresentAndExportOnlyKeysAreRemoved() throws {
    let catalogURL = try #require(localizableCatalogURL())
    let data = try Data(contentsOf: catalogURL)
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(root["strings"] as? [String: Any])

    for suffix in ["title", "summary", "detail", "nextRequirement"] {
        #expect(strings["settings.importExport.\(suffix)"] != nil)
        #expect(strings["settings.export.\(suffix)"] == nil)
    }
}
```

- [ ] **Step 3: 运行 PageClosureStateTests**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
```

Expected: PASS。

### Task 4: 更新页面清单事实源

**Files:**

- Modify: `docs/platform-page-inventory.md`
- Modify: `docs/plans/active/2026-05-20-bug-settings-import-export-capability-alignment.md`

- [ ] **Step 1: 更新 iPhone 设置列表行**

将 iPhone 设置列表能力边界从“语言空间、AI、同步、隐私、导出、界面语言”调整为“语言空间、界面语言、AI、同步、本地数据、隐私、导入导出”。

- [ ] **Step 2: 更新共享组件行**

将 `SettingsCapabilityDetailView` 能力说明中的“导出”调整为“导入导出”。

- [ ] **Step 3: 增加变更记录**

在 `docs/platform-page-inventory.md` 变更记录追加：

```markdown
- 2026-05-20：统一三端设置能力项的导入导出命名。原因：iPad / macOS 已有导入导出工作台入口，但共享设置能力仍显示为“导出”，导致 iPhone 设置页语义缺项。影响范围：SettingsCapability、三端设置列表、设置详情本地化和页面清单。是否需要 ADR：否，未改变真实导入导出能力或核心数据策略。
```

### Task 5: 验证与收口

**Files:**

- Move after verification: `docs/plans/active/2026-05-20-bug-settings-import-export-capability-alignment.md` to `docs/plans/done/2026-05-20-bug-settings-import-export-capability-alignment.md`

- [ ] **Step 1: 运行聚焦测试**

Run:

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
```

Expected: PASS。

- [ ] **Step 2: 运行 UI package 测试**

Run:

```bash
swift test --package-path Packages/LangoTraceUI
```

Expected: PASS。

- [ ] **Step 3: 运行统一验证**

Run:

```bash
scripts/verify.sh
```

Expected: PASS。

- [ ] **Step 4: 文档占位和 diff 检查**

Run:

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

Expected: placeholder scan 无新增违规；`git diff --check` 无输出；`git status --short` 只显示本任务相关文件和进入本轮前已有的未提交改动。

- [ ] **Step 5: 更新方案状态并移动到 done**

将本方案状态更新为 `Verified`，写入验证结果，然后移动到 `docs/plans/done/`。

## 复查方法

- 代码搜索：

```bash
rg -n "SettingsCapability.Kind.export|case export|settings\\.export" Packages docs --glob '!docs/plans/done/*'
rg -n "importExport|settings\\.importExport|导入导出" Packages/LangoTraceData Packages/LangoTraceUI docs/platform-page-inventory.md
```

- 语义复查：
  - iPhone 设置列表来自共享 `settingsCapabilities`，应显示导入导出 row。
  - iPad 左侧导入导出页面入口保留；设置列表也显示导入导出 row。
  - macOS Sidebar `Import / Export` section 保留；Settings 列表显示 `Import / Export` row。
  - 所有导入导出说明仍是不产生真实副作用的 unavailable / planning 状态。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 文档影响检查

- `docs/platform-page-inventory.md` 需要更新，因为它是三端页面事实源。
- 不需要新增 ADR：本任务不改变“本地优先”、数据导入导出策略、文件访问规则或真实能力接入顺序。
- 不需要更新 `docs/spec/002-navigation-and-routing.md`：该 spec 已把导入导出列为配置 route，并要求真实能力接入前显示 mock / unavailable 状态，本任务与该规则一致。
- 不需要更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`：本任务只修正设置入口命名，不设计真实数据格式。

## 实施记录

- 2026-05-20：创建方案并完成方案自检，未发现占位词或同类 active 方案冲突。
- 2026-05-20：按 TDD 增加回归测试，确认当前代码因 `SettingsCapability.Kind.importExport` 不存在而失败。
- 2026-05-20：将共享设置能力从 `export` 统一改为 `importExport`，更新 repository、UI localization mapping、String Catalog、Data/UI 测试和页面清单。
- 2026-05-20：验证通过：
  - `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests/settingsCapabilityChromeUsesUILocalizationKeys`
  - `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests/storeCentralizesRepositoryReadsAndMutations`
  - `swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests`
  - `swift test --package-path Packages/LangoTraceData`
  - `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreTests`
  - `swift test --package-path Packages/LangoTraceUI`
  - `scripts/verify.sh`

## 完成标准

- `SettingsCapability.Kind.allCases` 包含 `importExport`，不再包含 `export`。
- Repository settings capabilities 返回 `.importExport`。
- `settingsCapabilityDetailLocalizationKeys(for: .importExport)` 返回 `settings.importExport.*`。
- String Catalog 有 `settings.importExport.title/summary/detail/nextRequirement`，没有旧 `settings.export.*`。
- 页面清单记录三端设置能力项为导入导出。
- 聚焦测试、UI package 测试和 `scripts/verify.sh` 通过。
- 方案移动到 `docs/plans/done/` 并记录验证结果。

## 剩余风险

- 本轮不做截图验证，自动化只验证模型、key 和文档事实源；视觉上具体排列仍依赖共享 row 现有布局。
- 工作区进入本轮前已有未提交改动，最终 staging / commit 需要严格区分本任务文件与既有改动。
