# 工作记录：界面语言与付费级 UI 收敛

类型：feature

状态：Implemented

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/worklogs/2026-05-18-feature-premium-ui-audit.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 本阶段提交

## 1. 背景

上一轮 `08dd72a feat: refine premium UI interactions` 已修复 iPhone 全屏 Tab 横滑、iPad 搜索伪输入、Mac toolbar 候选、Local Mock 请求预览和 Data 层部分 UI chrome 边界。复查 worklog 仍明确留下 S-01 / S-04 / S-05：设计 token 和组件层级只完成第一层补强，多数样板外 SwiftUI chrome 仍有中文硬编码，String Catalog 覆盖不完整。

本轮根据用户要求继续推进“阶段 2：界面语言与付费级 UI 收敛”。因为项目仍处于真实数据、真实 AI、真实语音、真实同步和 StoreKit 之前，本轮只收敛 UI chrome、状态表达和样板组件边界，不接入真实能力。

## 2. 目标

- 将三端样板路径中最高频、最像产品 chrome 的硬编码文案迁入 `Localizable.xcstrings`，优先覆盖 iPhone Today / Entry Detail、iPad Workspace Bar、macOS Toolbar / Inspector 和共享学习组件。
- 继续收敛 Local Mock、unavailable、entry rendering 状态和主动作文案，避免中文短标签成为布局和交互前提。
- 增加测试约束，防止样板路径重新引入明显中文硬编码 chrome 或误导性发送文案。
- 更新本 worklog 记录实施范围、验证结果和剩余边界。

## 3. 范围

本轮处理：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- iPhone 样板相关 `PhoneMainSections.swift`、`PhoneMainSupportingViews.swift`、`EntryDetailHeader.swift`
- iPad 样板相关 `PadWorkspaceBar.swift`、`PadSidebarControls.swift`
- macOS 样板相关 `MacMainView.swift`、`MacInspectorContent.swift`
- 共享组件 `LearningContentComponents.swift`
- UI 测试 `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`

## 4. 不做什么

- 不做全量 String Catalog 迁移；用户 mock 内容、seed entry、目标语言句子、母语记录和示例学习内容可以保留原语言。
- 不修改 `project.yml`、Swift Package 结构、Xcode 工程结构或资源目录结构。
- 不接入真实 SQLite / GRDB、AI Provider、Keychain、TTS、Speech、OCR、Photos、Sync、StoreKit。
- 不宣称深色模式、截图矩阵、VoiceOver 实机走查或完整品牌系统已完成。
- 不新增 ADR；本轮不改变核心产品或架构决策。

## 5. 分析

阶段 2 的关键不是把所有中文都删除，而是区分：

- UI chrome：按钮、状态、toolbar、accessibility label、不可用说明、组件标题，应迁入 UI 层本地化资源。
- 用户/示例内容：生活记录正文、目标语言句子、mock note、practice summary，可在当前早期阶段保持特定语言，但要避免被当作界面语言能力。

第一轮扫描显示硬编码主要集中在 `PadWorkspaceBar`、`PhoneMainSupportingViews`、`EntryDetailHeader`、`MacMainView`、`MacInspectorContent`、`LearningContentComponents` 和少量空态。它们都属于样板路径或共享组件，适合本轮优先收敛。

## 6. 方案

采用小步收敛：

1. 先增加 String Catalog key，覆盖本轮要迁移的标题、按钮、状态、hint 和短说明。
2. 在 SwiftUI 中优先使用 `localizedText(_:)` 和 label builder，保持 SwiftUI `locale` 环境可刷新。
3. 对需要动态插值的句子，保留用户内容变量，但把固定 chrome 前缀迁到可测试的本地化入口；暂不做复杂复数和格式化资源。
4. 增加测试扫描样板文件，禁止重新出现本轮已收敛的关键硬编码片段。

## 7. 风险与边界

- String Catalog key 大量增加可能造成翻译质量不均；本轮以英文和简体中文准确性为主，其他第一批语言保持可用但后续仍需术语审校。
- `Text` 动态插值和 accessibility 组合仍可能存在局部中文标点或用户内容语言；本轮只收敛明确 UI chrome。
- 截图矩阵未纳入本轮完成条件，因此不能把“付费级 UI 最终完成”写入文档。

## 8. 测试与验证

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
rg -n '即将发送|tabSwipeGesture|simultaneousGesture\(tabSwipeGesture\)' Packages/LangoTraceUI/Sources/LangoTraceUI Packages/LangoTraceData/Sources/LangoTraceData
```

阶段 2 样板 chrome 回归扫描：

```bash
rg -n '搜索记录、词句、相似生活片段|照片和语音当前为未接入能力|今天记录一点生活|生活记录和目标语言版本保持来源关系|词句候选|保持完成状态|当前步骤|当前为本地 mock，不播放真实语音|朗读音频' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
```

## 9. 文档影响检查

- `docs/guidelines/003-ui-design-system.md` 和 `docs/guidelines/006-interface-localization-and-language-boundaries.md` 已覆盖本轮原则，不需要修改 Accepted guideline。
- 本轮不触发数据库、AI Provider、权限、同步、StoreKit、发布验证、ADR 冲突、XcodeGen、包边界或 App 启动结构专项审查。
- 需要在本 worklog 中记录剩余边界，避免把样板收敛误写成全量本地化完成。

## 10. 用户确认记录

2026-05-18：用户要求“针对当前改动提交一个 commit，然后继续方案文档中提到的阶段 2 任务：界面语言与付费级 UI 收敛”。上一轮改动已提交为 `08dd72a feat: refine premium UI interactions`，本轮开始阶段 2 实施。

## 11. 实施记录

- 已将 iPad workspace 搜索入口、未接入 badge、新建记录按钮和 accessibility hint 迁入 `Localizable.xcstrings`。
- 已将 iPhone Today hero 标题、主 CTA、次级能力入口、次级能力未接入提示和无记录空态迁入 String Catalog；目标语言名称仍作为语言空间上下文动态插入，不作为 UI chrome key。
- 已将 `EntryDetailHeader` 的来源关系和 Local Mock 边界说明迁入 String Catalog。
- 已将 Mac toolbar 的搜索 / 新建记录、Inspector 的词句候选标题、无词句空态和 unavailable route 边界说明迁入 String Catalog。
- 已将 `SentencePairView` 的听 / 练按钮、听力 mock hint，以及 `PracticeControlBar` 的当前步骤、可切换、下一步和保持完成状态迁入 String Catalog。
- `InlineStatusLabel` 支持纯文本和本地化 key 两种来源，保留用户内容 / mock 内容可以直接传入的能力。
- 新增 `PremiumUIBehaviorTests.stageTwoSamplePathsKeepMigratedChromeLocalized()`，扫描样板路径，防止本轮已迁移的关键中文 chrome 重新写回 Swift 源码。

## 12. 验证结果

已运行：

```bash
ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
rg -n '搜索记录、词句、相似生活片段|照片和语音当前为未接入能力|今天记录一点生活|生活记录和目标语言版本保持来源关系|词句候选|保持完成状态|当前步骤|当前为本地 mock，不播放真实语音' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
rg -n '即将发送|tabSwipeGesture|simultaneousGesture\(tabSwipeGesture\)' Packages/LangoTraceUI/Sources/LangoTraceUI Packages/LangoTraceData/Sources/LangoTraceData
```

当前结果：

- String Catalog JSON 可解析。
- `Packages/LangoTraceUI`：20 个 Swift Testing 测试通过。
- `scripts/verify.sh` 通过：重新生成 Xcode 工程；`LangoTraceCore` 26 个测试、`LangoTraceData` 10 个测试、`LangoTraceUI` 20 个测试通过；iPhone 17、iPad Pro 13-inch (M5) 和 macOS arm64 build 通过；SwiftLint 0 violations；SwiftFormat 0 files require formatting。
- `find docs -maxdepth 3 -type f | sort` 已完成，用于确认文档落点存在且没有意外目录漂移。
- 文档占位扫描无命中。
- `git diff --check` 无输出。
- 样板路径关键中文 chrome 回归扫描无命中。
- `即将发送`、旧 `tabSwipeGesture` 挂载方式和旧 simultaneousGesture 形态扫描无命中。
