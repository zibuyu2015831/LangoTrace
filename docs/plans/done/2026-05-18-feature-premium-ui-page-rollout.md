# 工作记录：付费级 UI 页面推广

类型：feature

状态：Implemented

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/plans/done/2026-05-18-feature-premium-ui-audit.md`
- `docs/plans/done/2026-05-18-feature-interface-premium-ui-convergence.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 本阶段提交

## 1. 背景

上一阶段已把 iPhone Today / Entry Detail、iPad Workspace Bar、macOS Toolbar / Inspector 和共享学习组件中的高频 chrome 迁入 String Catalog，并补了样板路径回归测试。阶段 3 的目标是把样板页沉淀出的组件和状态语言推广到记录、练习、记忆、设置、unavailable、request preview 和 footer 状态。

阶段 3 范围较大，本轮先做第一批页面推广：处理三端共用的 unavailable 状态和从 footer / toolbar / secondary action 进入的未接入能力说明。原因是这些入口跨 iPhone、iPad、macOS 复用，且直接承载本地优先、不会触发真实副作用和后续接入条件，是最容易影响用户信任的状态面。

## 2. 目标

- 将 `UnavailableCapabilityView` 的固定标题和副作用说明迁入 `Localizable.xcstrings`。
- 为 iPhone、iPad、macOS 共用的 photo writing、listen one、language space、search、import/export、vector index 和 generic unavailable 建立 key-based 描述。
- 让 iPhone sheet、iPad 页面和 macOS route 复用同一套 unavailable 描述语义，保留各平台自己的承载方式。
- 增加测试扫描，防止本轮迁移的未接入能力文案重新硬编码回样板外页面。

## 3. 范围

本轮处理：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/UnavailableCapabilityView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

## 4. 不做什么

- 不做阶段 3 的全量页面推广；记录、练习、记忆、设置和 request preview 的全部文案仍需后续批次继续收敛。
- 不接入真实照片、OCR、TTS、搜索、SQLite / GRDB、embedding、同步、导入导出或 StoreKit。
- 不新增 ADR；本轮只推广现有状态表达，不改变核心产品或架构决策。
- 不宣称深色模式、截图矩阵、Dynamic Type 全尺寸验证或 VoiceOver 实机走查完成。

## 5. 实施方案

1. 给 `UnavailableCapabilityView` 增加 key-based 初始化入口，保留 raw string 初始化用于用户内容或尚未迁移的局部页面。
2. 新增 `UnavailableCapabilityContent`，集中描述未接入能力的 `titleKey`、`summaryKey`、`nextRequirementKey` 和 `systemImage`。
3. 将 `PhoneUnavailableAction`、`MacUnavailableContent` 和 iPad/Mac 的 search、import/export、language space、vector index 调用迁到 `UnavailableCapabilityContent`。
4. 在 String Catalog 中加入英文和简体中文资源。
5. 增加 UI package 测试，扫描样板外推广路径，禁止本轮迁移的关键 unavailable 中文文案重新出现在 Swift 源码中。

## 6. 文档影响检查

- `docs/spec/003-ui-design-system.md` 已要求 unavailable 页面包含当前边界、后续接入条件和不会发生的副作用；本轮是在代码层推广该约束。
- `docs/spec/006-interface-localization-and-language-boundaries.md` 已要求 UI chrome 由 UI 层 String Catalog 渲染；本轮不需要修改 Accepted guideline。
- 本轮不触发数据库、AI Provider、权限、同步、StoreKit、发布验证、ADR 冲突、XcodeGen、包边界或 App 启动结构专项审查。

## 7. 用户确认记录

2026-05-18：用户要求“继续推进第三阶段”。根据既有方案文档，第三阶段为页面推广；本轮先执行 unavailable 状态的第一批跨页面推广。

## 8. 验证计划

完成前运行：

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

额外扫描：

```bash
rg -n '后续接入条件|不会发生|照片写作尚未接入|听一句尚未接入|语言空间切换尚未接入|导入导出尚未接入|搜索尚未接入|本地向量索引尚未接入|当前不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
```

## 9. 实施记录

- `UnavailableCapabilityView` 已改为 `UnavailableCapabilityContent` 驱动，统一使用 `CapabilityStatusRow`、`LocalizedTextPanel` 和 String Catalog key 渲染标题、说明、后续接入条件与不会发生的副作用。
- 新增 `UnavailableCapabilityContent` 的 photo writing、listen one、language space、search、import/export、vector index 和 generic 描述，集中维护 title / summary / next requirement / system image。
- iPhone `PhoneUnavailableAction` 已从 raw 中文文案切到 `UnavailableCapabilityContent`，sheet 仍保持 iPhone 自己的承载方式。
- iPad search sheet、memory page、import/export page 和 language space unavailable page 已复用同一套 unavailable content。
- macOS unavailable route 和 memory vector index 状态已复用同一套 unavailable content，保留 Mac workspace 的 route 分发边界。
- `Localizable.xcstrings` 新增 unavailable 系列英文和简体中文资源。
- `PremiumUIBehaviorTests` 新增两项测试：稳定 key 映射测试，以及阶段 3 unavailable 页面硬编码回归扫描。

## 10. 验证结果

已运行：

```bash
ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'
rg -n '后续接入条件|不会发生|照片写作尚未接入|听一句尚未接入|语言空间切换尚未接入|导入导出尚未接入|搜索尚未接入|本地向量索引尚未接入|当前不会访问照片、麦克风、网络、Keychain、真实数据库、同步服务或导出文件' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
swiftformat . --cache ignore
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
```

当前结果：

- String Catalog JSON 可解析。
- 阶段 3 unavailable 关键中文 chrome 扫描无命中。
- `Packages/LangoTraceUI`：22 个 Swift Testing 测试通过。
- `scripts/verify.sh` 通过：重新生成 Xcode 工程；`LangoTraceCore` 26 个测试、`LangoTraceData` 10 个测试、`LangoTraceUI` 22 个测试通过；iPhone 17、iPad Pro 13-inch (M5) 和 macOS arm64 build 通过；SwiftLint 0 violations；SwiftFormat 0 files require formatting。
