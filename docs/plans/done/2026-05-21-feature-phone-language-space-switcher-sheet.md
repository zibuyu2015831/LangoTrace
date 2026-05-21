# iPhone 顶部语言空间切换 Sheet 方案

状态：Verified

类型：feature

创建日期：2026-05-21

最后更新日期：2026-05-21

## 用户确认记录

- 2026-05-21：用户提供 iPhone 首页顶部语言空间信息栏和点击后 summary sheet 截图，要求从专业架构师和 Apple 交互设计角度判断是否去掉 sheet 或继续优化，并提出点击该信息栏至少应支持切换和新建语言空间。
- 2026-05-21：讨论结论为保留 sheet 承载形式，但把语义从“只读说明 summary”调整为“快速语言空间切换 sheet”；用户要求立即创建对应方案文档，包含详细现状说明、决策依据、修改方向和路径。
- 2026-05-21：用户确认“如果没有其他疑问的话，立即进入实施”。本方案进入实现阶段。

## 需求描述

iPhone 首页顶部当前显示轻量语言空间信息栏，例如 `中文 -> 英语 · B1`。当前用户点击该信息栏后会打开一个只读说明 sheet，内容包括当前语言空间、Local First 状态、当前状态、下一步和隐私说明。

新的产品方向是：该入口应优先服务当前学习上下文切换，而不是再次解释语言空间概念。用户点击顶部语言空间信息栏后，应能快速完成以下动作：

1. 查看当前语言空间。
2. 在已有 active 语言空间之间切换。
3. 新建一个语言空间，并在创建成功后沿用现有会话层语义自动切换到新空间。
4. 进入完整语言空间管理页，处理重命名、删除等低频生命周期操作。

## 现状说明

### 现有产品和文档事实

- `docs/product-main-reference.md` 第 8.4 节明确 iPhone 顶部或首页应有轻量语言空间切换器，点击后显示类似 `英语 / 日语 / 法语 / 添加学习语言` 的选择，而不是 Project 管理。
- `docs/spec/002-navigation-and-routing.md` 第 4.8 节定义语言空间是当前记录、练习、记忆和 AI 生成内容的全局学习上下文，不是与三大主 Tab 并列的高频主导航。
- 同一节还记录：iPhone 设置页语言空间入口已经进入真实管理页，支持新增、切换、重命名和删除；顶部语言空间摘要仍可保持轻量 summary，但不得成为唯一管理入口。
- `docs/spec/003-ui-design-system.md` 第 4.15 节要求 iPhone 管理类 sheet 使用语义化 panel、字段行、状态提示和 design token，保留原生输入行为，避免默认系统 `Form` 灰底和临时感。

### 现有代码事实

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
  - `PhoneMainView` 已接收 `languageSpace`、`languageSpaces`、`onAddLanguageSpace`、`onSelectLanguageSpace`、`onUpdateLanguageSpace`、`onDeleteLanguageSpace`。
  - `PhoneRecordWorkspaceView`、`PracticeView`、`MemoryView` 的 `onLanguageSpaceAction` 当前都设置为 `presentedSheet = .languageSpaceSummary`。
  - `.sheet(item: $presentedSheet)` 中的 `.languageSpaceSummary` 分支只展示 `LanguageSpaceSummaryView(languageSpace:)`，没有传入空间列表或生命周期 action。
  - `PhoneRoute.settings(.languageSpace)` 已经进入 `LanguageSpaceManagementView`，该页面支持完整管理。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`
  - 当前只接收 `LanguageSpacePreview`。
  - 页面结构是只读 summary：当前空间卡片、`CapabilityStatusRow`、多个 `LocalizedTextPanel`。
  - 不支持切换、新建、进入管理页，也不需要接收 `LanguageSpace` 列表。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
  - 已支持 active 空间列表、当前空间标记、新增、切换、编辑、删除。
  - 新增和编辑通过 `LanguageSpaceEditorView` 以 sheet 承载。
  - 删除通过 `confirmationDialog` 承载。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceEditorView.swift`
  - `LanguageSpaceEditorMode` 和 `LanguageSpaceEditorView` 是 UI package 内部类型，可被同 module 的新 switcher 视图复用。
  - 当前 `LanguageSpaceEditorView` 的取消按钮直接调用 `@Environment(\.dismiss)`。如果把它嵌入 switcher 的同一个 `NavigationStack`，需要明确取消是返回 switcher 还是关闭整个 sheet；如果继续用嵌套 `.sheet`，则要接受两层 modal 的交互成本。
- `LangoTraceApp/AppEnvironment.swift`
  - `AppSessionState` 已经实现 `addLanguageSpace`、`selectLanguageSpace`、`updateLanguageSpace`、`deleteLanguageSpace`，并通过 repository 刷新 `currentLanguageSpace` 和 `languageSpaces`。
  - 当前 action closure 返回 `Void`，失败时只会把 `recoveryState` 置为 `.failed`，不会把具体错误同步返回给 sheet。因此 switcher 不能在文档中假设选择或新增一定成功。
- `docs/platform-page-inventory.md`
  - 当前仍记录 `语言空间摘要 sheet`、`LanguageSpaceSummaryView` 和 `PhoneSheet.languageSpaceSummary`，这是本任务实现后必然过期的页面事实源，必须同步更新。

## 目标

1. iPhone 顶部语言空间入口点击后打开快速切换 sheet。
2. 快速切换 sheet 首屏优先展示当前空间和 active 空间列表。
3. 点击非当前空间后调用 `onSelectLanguageSpace(space.id)`，成功路径由 `AppSessionState` 更新当前空间，sheet 关闭。
4. 点击“添加学习语言”后打开现有 `LanguageSpaceEditorView` 新建流程，保存后调用 `onAddLanguageSpace`，并关闭编辑层。
5. 提供“管理语言空间”次级入口，关闭 sheet 后进入 `PhoneRoute.settings(.languageSpace)`，复用完整管理页。
6. 保留低权重本地优先/隐私边界说明，但不再用多张说明卡占据首屏。
7. 删除或降级原有只读 summary sheet，避免首页顶部入口的主动作和用户预期不匹配。
8. 明确失败边界：如果选择或新增语言空间失败，不能把 UI 表现写成“已成功切换 / 已成功创建”。在现有 void action 架构下，至少不得提前展示成功反馈；若实现选择关闭 sheet，应在方案中承认错误展示仍由根状态接管。

## 范围

本任务只处理 iPhone 顶部语言空间入口的 sheet 语义和 UI 承载。

包含：

- 新增或重命名 iPhone 快速切换 sheet 视图。
- 更新 `PhoneMainView` 中的 sheet enum、presented action 和 route 连接。
- 复用现有 `LanguageSpaceEditorView` 完成新建语言空间。
- 复用现有 `LanguageSpaceManagementView` 作为完整管理页。
- 补充 UI package 测试，覆盖顶部入口不再是 summary-only，且 sheet 具备切换、新建和管理入口。
- 补充本地化 key。
- 如长期规范需要更精确表达，更新 `docs/spec/002-navigation-and-routing.md` 和 `docs/spec/003-ui-design-system.md` 的对应小节。

不包含：

- 不改动 `LanguageSpaceRepository`、SQLite / GRDB schema、migration 或事务边界。
- 不重新设计 `LanguageSpaceManagementView` 的完整管理能力。
- 不新增语言空间删除、重命名或同目标语言校验规则。
- 不把语言空间切换状态写入同步 manifest、语言空间模型或学习记录。
- 不调整 iPad / macOS 的语言空间入口。
- 不接入真实 Entry 按空间过滤；当前 mock 学习内容随空间切换的展示边界仍由后续本地记录闭环任务处理。
- 不在本轮重构 `AppSessionState` 的 action 返回值或错误模型；如果实现过程中发现关闭 sheet 后错误不可见，应先在本方案中追加失败反馈补丁，而不是默默保留无反馈失败。

## 决策依据

### 产品判断

顶部语言空间 pill 是当前学习上下文，而不是帮助文档入口。用户在首页看到当前空间并点击时，最自然的目的通常是切换学习语言或添加新的学习语言。

当前 summary sheet 的信息价值集中在早期教育阶段；当语言空间配置已经真实可用后，它继续作为顶部入口的唯一结果，会造成“点击当前上下文却只能阅读说明”的错位。

### Apple 交互判断

iPhone 顶部轻量上下文控件适合触发短任务 sheet：选择、切换、添加、进入更完整管理。完整管理页适合承载重命名、删除、复杂提示和确认流程。

这符合 iOS 上“快速动作就地完成，复杂配置进入二级页面”的心智，也避免把用户从记录主流程强行带入管理页面。

### 架构判断

当前依赖注入已经到位：`PhoneMainView` 拥有当前空间、active 空间列表以及所有 lifecycle action。将 summary sheet 改为 switcher sheet 不需要穿透 Data 层，也不需要让 UI 直接持有 repository。

快速切换 sheet 和完整管理页应分工明确：

- 快速切换 sheet：当前上下文切换、新建入口、管理入口。
- 完整管理页：列表管理、重命名、删除、完整生命周期操作。

两者可以共享 `LanguageSpaceEditorView` 和部分 row 视觉语言，但不应把完整管理页直接塞进首页顶部 sheet，否则会增加主流程打断感。

## 修改方向

推荐采用“保留 sheet，改为快速切换器”的方案。

### 交互结构

点击顶部语言空间 pill 后打开中等高度 sheet：

```text
语言空间
当前：英语空间
中文 -> 英语 · B1

所有语言空间
✓ 英语空间       中文 -> 英语 · B1
  日语空间       中文 -> 日语 · A2
  法语空间       中文 -> 法语 · A1

[+ 添加学习语言]
[管理语言空间]

数据默认保存在本机。切换语言空间不会改变 App 界面语言。
```

行为规则：

- 当前空间 row 只表达 selected 状态，不显示伪按钮。
- 非当前空间 row 是 `Button`，点击后调用 `onSelectLanguageSpace(id)` 并关闭 sheet。
- `添加学习语言` 进入新增语言空间编辑层。推荐优先使用同一个 `NavigationStack` 内的 pushed editor 或 sheet 内部阶段切换，避免在快速切换 sheet 上再叠第二层 sheet；如果复用现有 `.sheet` 承载 editor，必须在实现记录中说明原因和人工验证结果。
- 新建保存后调用 `onAddLanguageSpace(input)`；是否自动切换到新空间沿用 `AppSessionState.addLanguageSpace` 的现有语义。关闭时机必须和现有 void action 失败边界一起处理，不能在用户可见文案中承诺未确认的成功。
- `管理语言空间` 关闭快速切换 sheet，并把 `navigationPath.append(.settings(.languageSpace))` 交给 `PhoneMainView`。
- 底部说明只保留一条低权重边界文案，不再显示当前 summary 的多张说明 panel。

### 视觉方向

- sheet 使用 `NavigationStack`，标题为“语言空间”。
- 内容使用 `ScrollView` 或 `List` 均可，但应符合现有语迹 token。若使用 `List`，需要确认背景、row 和 selection 视觉与当前 paper / elevatedPaper 系统协调。
- 当前空间使用 teal 轨道、selected surface 或 checkmark 表达；不能只靠颜色表达。
- 行高不低于 56pt，整体 tap target 不低于 44pt。
- “添加学习语言”是主要操作，但不能压过记录主流程；推荐使用 icon + text 的 row/button，不使用全宽巨大 CTA。
- “管理语言空间”作为次级文字或 row，视觉权重低于切换列表和添加动作。
- 如果 active 语言空间较多，列表区域应可滚动，底部“添加学习语言 / 管理语言空间”和隐私 footnote 不应被长列表挤出不可达区域；必要时将底部动作放在 sheet 底部 safe-area 区或列表尾部固定分组。

## 代码修改路径

### 1. UI sheet 新视图

建议新增：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSwitcherSheet.swift`

职责：

- 接收 `spaces: [LanguageSpace]`、`currentSpaceID: String?`。
- 接收 `onSelect: (String) -> Void`、`onAdd: (CreateLanguageSpaceInput) -> Void`、`onManage: () -> Void`。
- 内部可以管理 `@State private var isAddingLanguageSpace = false` 或等价阶段状态。
- 推荐把新增流程作为同一 sheet 内的 `NavigationStack` destination / 阶段视图，而不是默认嵌套第二层 `.sheet`。如果实现选择嵌套 `.sheet(item:)` 复用 `LanguageSpaceEditorView`，必须验证取消、保存、拖拽关闭和 VoiceOver 逃逸路径都符合 iPhone 预期。
- 内部通过 `@Environment(\.dismiss)` 处理切换和管理后的关闭；但 route owner 仍应是 `PhoneMainView`。

可选拆分：

- `LanguageSpaceSwitcherRow`：只负责 row 展示和 selected 状态。
- `LanguageSpaceSwitcherFooter`：只负责低权重本地优先和语言边界说明。
- `LanguageSpaceSwitcherPresentation` 或等价纯 helper：负责 active 空间排序、当前态判断、可选择 row 推导。该 helper 应优先写单元测试，避免只靠源码字符串测试判断行为。

### 2. PhoneMainView 路由连接

修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`

具体方向：

- 将 `PhoneSheet.languageSpaceSummary` 改为 `PhoneSheet.languageSpaceSwitcher`。
- 三个主 Tab 的 `onLanguageSpaceAction` 都改为 `presentedSheet = .languageSpaceSwitcher`。
- sheet 分支改为：

```swift
case .languageSpaceSwitcher:
    NavigationStack {
        LanguageSpaceSwitcherSheet(
            spaces: languageSpaces,
            currentSpaceID: languageSpace.id,
            onSelect: { id in
                onSelectLanguageSpace(id)
                presentedSheet = nil
            },
            onAdd: { input in
                onAddLanguageSpace(input)
                presentedSheet = nil
            },
            onManage: {
                presentedSheet = nil
                navigationPath.append(.settings(.languageSpace))
            }
        )
    }
    .presentationDetents([.medium, .large])
```

实际实现可以让 `LanguageSpaceSwitcherSheet` 自行 dismiss；但 `PhoneMainView` 仍应保留 route ownership，避免 sheet 内直接知道 `PhoneRoute`。

注意：上述闭包示例是结构示意，不代表必须无条件立即关闭。由于当前 `onSelectLanguageSpace` / `onAddLanguageSpace` 返回 `Void`，实现时要么沿用现有管理页的乐观关闭语义并在剩余风险中写清楚，要么扩展 UI 层状态以在失败时保留 sheet 并显示错误。不能同时声称“失败可见”和“action 无返回且无错误状态”。

### 3. 原 summary 视图处理

修改或删除：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceSummaryView.swift`

推荐处理：

- 如果没有其他平台或页面使用 `LanguageSpaceSummaryView`，删除该文件和相关测试引用。
- 如果仍有说明用途，把它降级为设置详情中的说明组件，而不是首页顶部入口的 sheet。

执行前用以下命令确认引用：

```bash
rg -n "LanguageSpaceSummaryView|languageSpaceSummary" Packages LangoTraceApp docs
```

### 4. 本地化资源

修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

新增 key 建议：

- `languageSpace.switcher.title`
- `languageSpace.switcher.currentSection`
- `languageSpace.switcher.allSection`
- `languageSpace.switcher.add`
- `languageSpace.switcher.manage`
- `languageSpace.switcher.localFirstFootnote`
- `languageSpace.switcher.currentBadge`

文案边界：

- 中文界面示例：“语言空间”“所有语言空间”“添加学习语言”“管理语言空间”“数据默认保存在本机。切换语言空间不会改变 App 界面语言。”
- 英文界面示例：“Language Space”“All Language Spaces”“Add Learning Language”“Manage Language Spaces”“Your data stays on this device by default. Switching spaces does not change the app interface language.”

### 5. 测试修改路径

修改或新增：

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`
- 可选新增：`Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceSwitcherTests.swift`

覆盖点：

1. `PhoneMainView.swift` 不再包含 `case .languageSpaceSummary`。
2. `PhoneMainView.swift` 包含 `case .languageSpaceSwitcher`。
3. `PhoneMainView.swift` 的三个主 Tab 均将 `onLanguageSpaceAction` 连接到 `.languageSpaceSwitcher`。
4. `LanguageSpaceSwitcherSheet.swift` 接收 `spaces: [LanguageSpace]` 和 `currentSpaceID: String?`。
5. `LanguageSpaceSwitcherSheet.swift` 包含 `onSelect`、`onAdd`、`onManage` action。
6. `LanguageSpaceSwitcherSheet.swift` 复用 `LanguageSpaceEditorView` 新建语言空间。
7. 本地化 catalog 包含新增 switcher keys 的 `en` 和 `zh-Hans` 文案。

如果实现中能抽出纯 presentation helper，应优先补充行为单元测试。例如：

- 当前空间排在列表第一位或以 selected 状态展示。
- 切换当前空间时不触发重复 select。
- 非当前空间 row 暴露可点击 action。

要求：

- 不能只用源码字符串测试替代全部行为验证。源码字符串测试可以覆盖路由接线和本地化 key，但至少应有一个可执行的 Swift 单元测试覆盖排序 / selected / disabled-current 这类纯展示逻辑。
- 如果新增视图只能通过源码级测试覆盖，应在实施记录中说明原因，并把人工 iPhone Simulator 验证列为必须完成项。

## 实施方案

### 第一阶段：测试先行

1. 新增 `LanguageSpaceSwitcherTests`，先写可执行 presentation helper 测试，覆盖当前空间排序、当前 row 不触发重复切换、非当前 row 可选择。
2. 新增源码级测试覆盖 `PhoneMainView` 的 sheet enum、action 连接和 route owner 边界。
3. 新增源码级测试覆盖 `LanguageSpaceSwitcherSheet` 的必要输入和 action closure。
4. 新增 String Catalog 测试，确认新增 key 同时具备 `en` 和 `zh-Hans`。
5. 运行 `swift test --package-path Packages/LangoTraceUI`，确认新测试先失败。

### 第二阶段：最小实现

1. 新增 `LanguageSpaceSwitcherSheet.swift`。
2. 更新 `PhoneMainView.swift`，把 `.languageSpaceSummary` 替换为 `.languageSpaceSwitcher`。
3. 复用 `LanguageSpaceEditorView` 的 add 模式处理新建语言空间；优先避免双层 modal，若采用嵌套 sheet，必须补人工验证记录。
4. 将管理入口通过 `onManage` 回传给 `PhoneMainView`，由 `PhoneMainView` append `.settings(.languageSpace)`。
5. 更新 `Localizable.xcstrings`。
6. 运行聚焦测试，修复编译和测试失败。

### 第三阶段：清理 summary-only 路径

1. 搜索 `LanguageSpaceSummaryView` 和 `languageSpaceSummary` 引用。
2. 如果没有合理用途，删除 `LanguageSpaceSummaryView.swift`。
3. 如果仍需保留说明组件，将其从首页顶部入口中解耦，并在测试中明确顶部入口不再使用它。
4. 更新相关源码级测试引用。

### 第四阶段：文档影响检查

1. 更新 `docs/spec/002-navigation-and-routing.md` 第 4.8 节，把“顶部语言空间摘要仍可保持轻量 summary”改为“顶部语言空间入口应优先作为快速切换 sheet；完整管理仍由设置页承载”。
2. 如实现形成可复用管理类 sheet 规则，更新 `docs/spec/003-ui-design-system.md` 第 4.15 节，补充“快速切换 sheet 与完整管理页的分工”。
3. 更新 `docs/platform-page-inventory.md` 中 iPhone 页面清单、共享组件清单和页面覆盖自检，移除 `LanguageSpaceSummaryView` / `languageSpaceSummary` 作为当前事实源，改为快速切换 sheet。
4. 在本方案实施记录中写明验证命令和结果。

## 复查方法

代码复查：

- `PhoneMainView` 中不再出现 `.languageSpaceSummary` 作为顶部语言空间入口。
- 快速切换 sheet 不直接持有 repository、GRDB queue、SQL record 或数据库 URL。
- `LanguageSpaceSwitcherSheet` 的业务写入全部通过 action closures 回传。
- `PhoneMainView` 仍然拥有 iPhone route ownership。
- `LanguageSpaceManagementView` 继续作为完整管理页，未被复制成第二套管理实现。
- 新建语言空间复用 `LanguageSpaceEditorView`，不自绘不可访问的选择控件。
- 如果 `LanguageSpaceEditorView` 被嵌入同一个 sheet 的导航层，取消行为必须明确且测试 / 人工验证覆盖；不能出现“取消新增却关闭整个 switcher，且用户无法判断是否保存”的混乱路径。
- 如果选择或新增失败，代码不能展示成功状态；如果沿用现有根状态失败处理，实施记录必须写明这一点是既有架构限制还是本轮已补反馈。

交互复查：

- 点击顶部语言空间 pill 打开快速切换 sheet。
- 当前语言空间被清晰标记。
- 点击其他语言空间后 sheet 关闭，首页顶部 pill 更新为新空间。
- 点击“添加学习语言”打开编辑 sheet，保存后 sheet 关闭并显示新空间。
- 点击“管理语言空间”进入完整管理页。
- Dynamic Type 下 row 和按钮不截断核心文案。
- VoiceOver 能读出当前空间 selected 状态和可切换 row。
- 添加流程的取消、保存、拖拽关闭和从编辑层返回 switcher 的路径符合 iPhone 预期。

## 验证命令

聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI
```

完整验证：

```bash
scripts/verify.sh
```

文档任务检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

人工验证建议：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
```

然后在 iPhone 17 Simulator 中验证：

1. 完成 onboarding 并进入首页。
2. 点击顶部语言空间 pill。
3. 新建第二个语言空间。
4. 从顶部 sheet 切回第一个语言空间。
5. 再次打开顶部 sheet，进入完整管理页。

## 文档影响检查

本任务涉及 iPhone 导航语义和语言空间闭环入口，属于文档影响检查范围。

需要检查并可能更新：

- `docs/spec/002-navigation-and-routing.md`
  - 第 4.8 节应从“summary 可保持”收敛为“快速切换 sheet 是顶部入口主语义，完整管理页仍在设置路径”。
- `docs/spec/003-ui-design-system.md`
  - 第 4.15 节可补充快速切换 sheet 和完整管理页的视觉/职责分工。
- `docs/platform-page-inventory.md`
  - 页面清单已经记录 iPhone 顶部语言空间入口为 summary-only；本任务实现时必须更新为 switcher sheet。

不需要新增 ADR。理由：本任务不改变“语言空间是核心信息模型”、不改变多空间策略、不改变本地优先或 SQLite / GRDB 决策，只是把 iPhone 顶部入口从说明型 sheet 调整为符合既有产品文档的快速切换入口。

## 实施记录

- 2026-05-21：创建本方案。尚未开始代码实现。
- 2026-05-21：新增 `LanguageSpaceSwitcherTests`，先覆盖当前空间排序、当前 row 不重复触发切换、非当前 row 可选择、iPhone sheet 路由、本地化 key 和 switcher 视图 action seam。首次运行 `swift test --package-path Packages/LangoTraceUI` 按预期失败，失败原因为 `LanguageSpaceSwitcherPresentation` 未实现。
- 2026-05-21：新增 `LanguageSpaceSwitcherSheet.swift`，包含 `LanguageSpaceSwitcherPresentation`、row presentation 和 iPhone 快速切换 sheet；`PhoneMainView` 将顶部语言空间入口从 `.languageSpaceSummary` 改为 `.languageSpaceSwitcher`；删除 `LanguageSpaceSummaryView.swift`；新增 `languageSpace.switcher.*` 本地化 key。
- 2026-05-21：同步 `docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md` 和 `docs/platform-page-inventory.md`，把 iPhone 顶部语言空间入口事实源更新为快速切换 sheet。
- 2026-05-21：聚焦验证 `swift test --package-path Packages/LangoTraceUI` 通过，输出显示 `Test run with 169 tests in 25 suites passed`。完整验证和文档检查待收口前执行。
- 2026-05-21：首次运行 `scripts/verify.sh` 在 SwiftFormat lint 阶段失败，原因是 `PhoneMainView.swift` 和 `LanguageSpaceSwitcherTests.swift` 需要格式化；执行 `swiftformat Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceSwitcherTests.swift` 后重跑。
- 2026-05-21：完整验证 `scripts/verify.sh` 通过。脚本完成 XcodeGen、`xcodebuild -list`、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat lint 和文档占位扫描；末尾 `git status --short` 仅打印本任务的未提交改动。

## 完成标准

- iPhone 顶部语言空间入口打开快速切换 sheet，而不是只读 summary sheet。
- 用户可从该 sheet 切换已有语言空间。
- 用户可从该 sheet 发起新建语言空间。
- 用户可从该 sheet 进入完整语言空间管理页。
- 完整管理页仍负责重命名、删除和复杂生命周期操作。
- 新增流程的承载方式明确，不存在未经验证的双层 modal 交互。
- 切换 / 新增失败边界在实现记录中明确；如本轮不补错误反馈，必须说明沿用现有 `AppSessionState.recoveryState` 的剩余风险。
- UI package 聚焦测试通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。
- `docs/spec/002-navigation-and-routing.md` 和 `docs/platform-page-inventory.md` 已同步；`docs/spec/003-ui-design-system.md` 如形成新规则也已同步，或在本方案中说明无需更新的证据。

## 剩余风险

- 当前学习内容仍以 mock 数据为主，切换语言空间后首页列表是否完全按空间过滤，需要等真实 Entry schema 和本地记录闭环落地后验证。
- `onAddLanguageSpace` 当前语义是新增后设为当前空间；顶部快速切换 sheet 会沿用该语义。如果未来需要“新增但不切换”，应作为独立交互选项设计。
- `onSelectLanguageSpace` / `onAddLanguageSpace` 当前没有返回成功或错误结果；如果本轮不扩展 action contract，快速 sheet 的错误反馈只能依赖现有根状态失败路径，用户可能看不到就地错误。实现阶段应优先评估是否需要最小错误反馈补丁。
- iPad / macOS 的语言空间入口已走完整管理页，本任务只调整 iPhone 顶部入口，三端入口在短期内会保持不同承载形式，但职责一致：快速上下文入口不替代完整管理能力。
