# 任务方案：iPhone 记录详情导航标题层级优化

状态：Verified
类型：refactor
创建日期：2026-05-27
最后更新日期：2026-05-27

## 1. 用户确认记录

2026-05-27：用户基于 iPhone 17 模拟器截图指出记录详情页同时显示页面标题 `记录详情` 和记录标题 `人工测试记录`，询问是否可以删除页面标题，并把记录标题放到原页面标题位置。经专业 UI 评估，当前两个强标题相邻导致首屏层级重复、内容下移和视觉焦点分散；推荐在 iPhone compact 记录详情页中使用当前记录标题作为导航栏标题，并移除正文顶部重复的记录标题。用户要求立即创建对应 active plan，并明确要求考虑文本标题较长等边界问题。

## 2. 需求描述

iPhone 记录详情页当前通过 `.navigationTitle(localizedText("entryDetail.title"))` 在导航栏显示通用页面名 `记录详情`，正文顶部又通过 `EntryDetailHeader(entry:)` 显示当前记录标题。该结构在小屏上形成重复标题层级，挤压母语记录、目标语言表达和逐句练习的首屏空间。

本任务目标是在 iPhone 记录详情页中将导航栏标题改为当前记录标题，并删除正文中的重复记录标题区，让首屏直接进入内容卡片。

## 3. 现状描述

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` 中 `EntryDetailView.body` 的 `VStack` 首项为 `EntryDetailHeader(entry: entry)`。
- 同一 `EntryDetailView` 末尾设置 `.navigationTitle(localizedText("entryDetail.title"))`，因此 iPhone 导航栏显示固定页面名 `记录详情`。
- `EntryDetailHeader.swift` 当前已在上一轮优化中简化为只显示 `Text(entry.title)`，不再显示 metadata 或能力状态 badge。
- `EntryDetailView` 被 `EntryDetailStoreView` 复用，并由 iPhone、iPad、macOS 路径共同接入；直接删除 header 或改导航标题可能影响大屏工作台语义，需要先定义平台边界。
- `PadMainModels.swift` 仍有 route 级 `navigationTitleKey` 使用 `entryDetail.title`，大屏外壳可能仍需要页面类型标题作为分栏语义。

## 4. 目标

- iPhone compact 记录详情页导航栏标题显示 `entry.title`，而不是固定 `记录详情`。
- iPhone compact 记录详情正文不再重复显示 `EntryDetailHeader(entry:)`。
- 长记录标题在导航栏中保持系统级单行标题行为，允许截断，不撑开导航栏、不挤压返回按钮、不进入多行大标题。
- 空白或异常标题有稳定 fallback，避免导航栏出现空标题；fallback 使用本地化 `entryDetail.title`。
- 保留返回按钮和系统返回手势，不引入自定义顶部栏。
- 不改变正文卡片、编辑 sheet、学习材料生成、重新分析、逐句 `听`、逐句 `练`、练习录音、TTS、AI Provider、GRDB 或媒体资产路径。
- 自动化测试锁定 iPhone 记录详情使用记录标题作为 navigation title，并且 iPhone 调用路径不再显示正文 `EntryDetailHeader`。
- 自动化测试锁定 iPad / macOS 调用路径显式选择大屏标题呈现策略，避免共享 `EntryDetailView` 的修改意外改变大屏工作台语义。
- 同步更新 UI 规范和三端页面清单，记录该层级规则和长标题处理边界。

## 5. 范围

预计修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`
- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`
- 本方案文档

可能参考但不一定修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`

## 6. 不做什么

- 不重新设计记录详情正文卡片。
- 不新增自定义 navigation bar、sticky header 或 toolbar overlay。
- 不把完整长标题迁移到正文顶部、弹窗或新信息面板。
- 不改变 iPad / macOS 工作台、分栏或外壳标题语义；若大屏需要后续统一标题策略，另建任务。
- 不删除 `EntryDetailHeader.swift` 文件，除非确认所有平台都不再引用且测试覆盖清楚；本任务优先做到 iPhone 可见层级优化。
- 不新增截图自动化；本任务先用源码级 UI contract 测试和 iOS build 验证。

## 7. 边界问题与处理决策

### 7.1 长标题

- 导航栏标题只显示单行系统 inline 标题。
- 长标题允许省略号截断，避免多行标题占据 Dynamic Island 下方空间。
- 不在正文顶部恢复完整标题，因为这会抵消本任务减少首屏标题占用的目标。
- 后续如需完整标题查看，应结合记录编辑入口或详情元信息面板另行设计。

### 7.2 空标题或仅空白标题

- 虽然当前创建记录应有可用标题，但 UI 层仍应防御空白标题。
- 新增 `entryNavigationTitle` 计算属性或等价 helper：`entry.title.trimmingCharacters(in: .whitespacesAndNewlines)` 为空时使用 `localizedString("entryDetail.title")`。

### 7.3 Dynamic Type

- 不使用多行 navigation title。
- 正文移除 header 后，Dynamic Type 增大时首屏收益更明显。
- 内容卡片继续按既有动态布局自然增高，不由标题区预留额外高度。

### 7.4 可访问性

- 可见标题变为记录标题后，VoiceOver 进入详情页时优先读出当前对象名，符合对象详情页语义。
- `记录详情` 仍可保留在路由、测试命名和 fallback 文案中，不要求常驻可见。

### 7.5 跨平台

- iPhone compact 是本任务主范围。
- 当前 `EntryDetailView` 已被 iPhone、iPad 和 macOS 共享，因此必须通过显式参数控制 header / navigation title，而不是直接在 shared view 中删除 header 或全局改 title。
- iPhone 调用路径选择对象标题策略：导航栏使用当前记录标题，正文隐藏 `EntryDetailHeader`。
- iPad / macOS 调用路径选择嵌入式标题策略：继续允许正文显示 `EntryDetailHeader`，并保留外壳路由标题或工作台语义。
- iPad / macOS 后续是否也使用对象标题，应结合分栏选择态、工作台栏位和 inspector 信息架构另行评估。

### 7.6 状态同步

- 导航标题必须直接从传入的 `LearningEntry.title` 派生，不新增 `@State` 缓存，避免记录切换或未来标题编辑后标题不同步。
- 标题 fallback 只在 UI 层处理空白字符串，不写回 repository，不改变数据一致性。
- `EntryDetailStoreView` 继续通过 `contentStore.entry(id:)` 获取当前 entry；本任务不改变 entry 查找、rendering 派生或 route identity。

## 8. 证据与决策依据

- 用户截图显示 `记录详情` 与 `人工测试记录` 在首屏连续出现，二者都是高权重标题，造成重复。
- iOS 对象详情页通常以对象名称作为导航标题，页面类型可通过返回路径和内容结构隐含表达。
- `docs/spec/003-ui-design-system.md` 已要求 iPhone 记录详情优先服务阅读和练习，并减少标题区 metadata / 状态 badge 对首屏层级的干扰。
- 当前正文顶部 `EntryDetailHeader` 已只剩记录标题，继续保留会与导航栏对象标题重复。

## 9. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PhoneIOSConvergenceTests.swift`

## 10. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 11. 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/platform-page-inventory.md`
- `docs/plans/active/2026-05-27-refactor-iphone-entry-detail-navigation-title.md`

## 12. 实施方案

### Task 1：测试先行锁定 iPhone 标题层级

- 在 `PhoneIOSConvergenceTests.swift` 新增测试，例如 `iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader`。
- 读取 `PhoneMainSupportingViews.swift`，断言：
  - `EntryDetailView` 中存在基于 `entry.title` 的导航标题 helper。
  - `EntryDetailView` 通过显式标题呈现策略决定是否显示 `EntryDetailHeader(entry: entry)`，而不是无条件显示。
  - 不再使用 `.navigationTitle(localizedText("entryDetail.title"))` 作为记录详情页可见标题。
  - 存在空白标题 fallback 到 `entryDetail.title` 的逻辑。
- 读取 `PhoneMainView.swift`，断言 iPhone `.entryDetail` 路由创建 `EntryDetailStoreView` 时显式选择对象导航标题策略。
- 读取 `PadMainSections.swift` 和 `MacWorkspaceContentView.swift`，断言大屏创建 `EntryDetailStoreView` 时显式选择嵌入式标题策略。
- 预期首次运行失败，因为当前代码仍渲染 `EntryDetailHeader` 并使用固定 `entryDetail.title`。

聚焦命令：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader
```

### Task 2：实现 iPhone 记录详情导航标题

- 在 `PhoneMainSupportingViews.swift` 中新增轻量标题呈现策略，示例：

```swift
enum EntryDetailTitlePresentation {
    case objectNavigationTitle
    case embeddedHeader

    var showsInlineHeader: Bool {
        self == .embeddedHeader
    }

    var usesObjectNavigationTitle: Bool {
        self == .objectNavigationTitle
    }
}
```

- 给 `EntryDetailStoreView` 和 `EntryDetailView` 增加参数：

```swift
let titlePresentation: EntryDetailTitlePresentation
```

- 在 `EntryDetailView` 内新增私有计算属性：

```swift
private var entryNavigationTitle: String {
    let trimmed = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return localizedString("entryDetail.title")
    }
    return trimmed
}
```

- 将 `.navigationTitle(localizedText("entryDetail.title"))` 改为按策略选择标题：

```swift
.navigationTitle(
    titlePresentation.usesObjectNavigationTitle
        ? entryNavigationTitle
        : localizedString("entryDetail.title")
)
```

- 确认该标题在 iOS 上保持 inline 显示；如当前默认表现不是 inline，则在 iOS 条件下显式设置 `.navigationBarTitleDisplayMode(.inline)`。
- 将正文顶部 header 改为策略控制：

```swift
if titlePresentation.showsInlineHeader {
    EntryDetailHeader(entry: entry)
}
```

- `PhoneMainView` 的 `.entryDetail` 路由传入 `.objectNavigationTitle`。
- `PadMainSections` 和 `MacWorkspaceContentView` 的大屏入口传入 `.embeddedHeader`，保留大屏现有标题语义。

### Task 3：长标题和 fallback 复查

- 增加或扩展源码级测试，断言实现包含 `trimmingCharacters(in: .whitespacesAndNewlines)` 和 `localizedString("entryDetail.title")` fallback。
- 复查没有使用 `.fixedSize`、自定义 `ToolbarItem(placement: .principal)` 或多行 `Text(entry.title)` 放入 toolbar。
- 复查没有新增 `@State` 保存标题，标题应随 `entry.title` 输入值重新计算。
- 如存在 SwiftUI 预览或 fixture 中可快速查看长标题，使用一个长标题样例人工运行 iPhone build；否则记录为后续模拟器人工验收项。

### Task 4：同步文档事实

- 更新 `docs/spec/003-ui-design-system.md`：iPhone 记录详情导航栏使用当前记录标题，正文不重复显示记录标题；长标题走系统单行截断，空白标题 fallback 到 `记录详情`。
- 更新 `docs/platform-page-inventory.md`：记录详情页面说明增加标题层级事实和 iPhone / 大屏边界。

## 13. 复查方法

- 代码复查：确认 `EntryDetailView` 在 `.objectNavigationTitle` 策略下不再在正文顶部渲染重复记录标题，在 `.embeddedHeader` 策略下仍可服务 iPad / macOS 大屏嵌入式标题。
- 平台边界复查：确认 iPhone、iPad、macOS 三个调用点都显式传入标题呈现策略，且 iPad / macOS 没有被无意中移除必要的工作台标题语义。
- 长标题复查：确认没有自定义多行 toolbar 标题或固定大标题。
- 可访问性复查：确认返回按钮仍由系统提供，未阻断系统返回手势。
- 文档复查：确认 UI 规范和页面清单都描述新标题规则。

## 14. 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader
swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests
```

iPhone 构建验证：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
```

文档与格式验证：

```bash
scripts/check-docs.sh
git diff --check
```

必要时完整验证：

```bash
scripts/verify.sh
```

## 15. 文档影响检查

本任务改变 iPhone 记录详情页可见 UI 事实，应同步 `docs/spec/003-ui-design-system.md` 和 `docs/platform-page-inventory.md`。不改变产品北极星、数据、AI Provider、TTS、隐私、同步、权限、StoreKit 或发布边界，不需要新增 ADR。

由于记录详情属于平台页面和验证脚本关注范围，完成后应在实施记录中写明是否运行 iPhone build 和是否需要后续人工截图复核。

## 16. 实施记录

- 2026-05-27：创建 active plan，等待用户确认后实施。
- 2026-05-27：提交 active plan 后开始实施；新增 `PhoneIOSConvergenceTests.iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader`，首次运行按预期失败，失败点覆盖标题呈现策略、iPhone 对象标题入口、大屏嵌入式标题入口和空白标题 fallback。
- 2026-05-27：新增 `EntryDetailTitlePresentation`，让 iPhone 入口传入 `.objectNavigationTitle`，iPad / macOS 入口传入 `.embeddedHeader`；`EntryDetailView` 按策略选择 navigation title 和正文 header，标题直接从 `entry.title` 派生并为空白标题 fallback 到 `entryDetail.title`。
- 2026-05-27：更新 `docs/spec/003-ui-design-system.md` 和 `docs/platform-page-inventory.md`，记录 iPhone / 大屏标题呈现边界、长标题截断和空白标题 fallback。
- 2026-05-27：验证完成，方案归档至 `docs/plans/done/`。

## 17. 完成标准

- iPhone 记录详情导航栏显示当前记录标题。
- iPhone 记录详情正文顶部不再重复显示记录标题。
- iPad / macOS 入口显式选择大屏标题呈现策略，避免被 iPhone 优化隐式影响。
- 长标题不会撑高导航栏或遮挡返回按钮。
- 空白标题有稳定 fallback。
- 聚焦 UI contract 测试通过。
- iPhone、iPad 和 macOS build 通过。
- `scripts/check-docs.sh` 和 `git diff --check` 通过。
- 相关文档已同步。
- 方案完成后移动到 `docs/plans/done/` 并记录验证结果。

## 18. 剩余风险

- 源码级测试能锁定结构和边界，但不能替代真实模拟器截图对长标题截断效果的人工审美验收。
- 如果 iPad / macOS 在参数化后仍出现视觉变化，需要在实施记录中保留人工复核结论，并另建大屏标题策略任务处理。

## 19. 验证结果

- `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests/iPhoneEntryDetailUsesEntryTitleAsNavigationTitleWithoutDuplicateBodyHeader`：先失败后通过。
- `swift test --package-path Packages/LangoTraceUI --filter PhoneIOSConvergenceTests`：通过，16 个测试。
- `swift test --package-path Packages/LangoTraceUI`：通过，262 个测试。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build`：通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`：通过。
- `xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build`：通过。
- `scripts/verify.sh`：通过；SwiftLint 当前仍报告 warning，但 0 serious violation，未阻断统一验证脚本。
