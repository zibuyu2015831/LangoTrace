# 任务方案：首次引导当前水平选择器三端优化

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

状态：Done - 用户已检查无误并确认归档
类型：feature
创建日期：2026-05-20
最后更新日期：2026-05-20

**Goal:** 将首次创建语言空间时的“当前水平”从裸露 A1-C2 segmented control 优化为更直观的紧凑单选列表，并完成 iPhone、iPad、macOS 三端体验。

**Architecture:** 保留 `LanguageLevel` 的 A1-C2 数据模型和语言空间摘要格式，把解释性文案放在 `LangoTraceUI` 的 onboarding 表现层。三端共享同一个解释性等级列表，按现有 compact / wide onboarding 布局承载，不再保留裸 segmented picker。

**Tech Stack:** SwiftUI, Swift Package `LangoTraceUI`, Swift Testing, String Catalog `Localizable.xcstrings`, XcodeGen verification script.

---

## 用户确认记录

- 2026-05-20：用户认为裸 `A1, A2, B1, B2, C1, C2` 不够直观，要求头脑风暴优化方案。
- 2026-05-20：用户采纳“方案 A”的方向：保留 A1-C2，但增加 `入门：认识少量词句，刚开始学` 这类解释。
- 2026-05-20：用户在可视化草图中选择 C 方案，并确认采用“紧凑单选列表”：最多露出三个选项，内部滚动，同时需要保证整个页面元素协调。
- 2026-05-20：用户人工查看 iPhone 页面后指出元素偏多，确认顶部说明改为 `创建一个语言空间，把生活变成学习材料。`，字段标题从 `水平自评` 收敛为 `当前水平`，并删除 `你现在大概能用 English 做到什么？` 这类问题句。
- 当前状态：用户已确认 iPhone 效果通过，并要求检查文档影响后完成 iPad / macOS 修改、重新构建并重启模拟器。
- 2026-05-20：用户人工查看 iPad / macOS onboarding 后指出“数据默认保存在本地”卡片视觉权重过高，确认将其降级为“创建语言空间”按钮下方的浅色轻提示。
- 术语澄清：本方案中的“先完成 iOS 版”按本仓库三端边界解释为先完成 iPhone 体验；iPadOS 虽然属于 iOS target，但产品与交互上作为第二阶段处理。

## 1. 需求描述

当前首次创建语言空间时的“当前水平”如果只展示 `A1 / A2 / B1 / B2 / C1 / C2`，对熟悉 CEFR 的用户准确，但对普通首次使用者不够直观，容易造成“不知道该选哪个”的理解成本。

本任务要在不改变语言空间核心模型的前提下，让 iPhone 首次引导中的等级选择同时具备：

- 仍保留 A1-C2 作为可见等级代码。
- 每个等级显示当前界面语言下的自然名称和一句话说明。
- 控件占用高度受控，默认只露出约三个选项，其他等级通过内部滚动查看。
- 控件视觉与现有 onboarding 页面、语言选择行、隐私说明卡片协调。
- 先完成 iPhone 体验，人工查看确认后，再开发 iPad 和 macOS 版本。

## 2. 现状描述

- `LanguageLevel` 位于 `Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift`，当前枚举为 `A1, A2, B1, B2, C1, C2`。
- `OnboardingDraft.level` 默认值为 `.b1`，位于 `Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`。
- `OnboardingView` 位于 `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`，当前在 `languageForm` 内使用 segmented `Picker` 和 `ForEach(LanguageLevel.allCases)` 展示裸等级。
- `OnboardingView` 目前三端共用，通过 `usesInlineWideOnboardingLayout(in:)` 按尺寸选择 compact / wide 布局。iPadOS 也编译在 `os(iOS)` 分支内，因此第一阶段不能只用 `#if os(iOS)` 作为 iPhone gate。
- 当前 string catalog 已有 `onboarding.level.title`、`onboarding.level.summary` 和 `onboarding.level.accessibilityHint`，但没有每个等级的自然名称和说明。
- `project.yml` 当前对 iOS 和 macOS target 均声明了 `en / zh-Hans / es / ja / fr / de / ko / ru`。新增 onboarding 文案不能只补英文和简体中文，否则会破坏当前界面语言候选清单下的完整性。
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift` 已经存在通过源码和资源检查 UI 结构约束的测试风格，可作为本任务轻量回归测试入口。

## 3. 目标

1. iPhone 首次引导页的水平选择控件从 6 段 segmented control 改为紧凑单选列表。
2. 列表项展示结构为：等级代码、自然名称、说明句、选中态。
3. 默认视觉高度只展示约三个选项，并允许内部滚动浏览其余等级。
4. 保持 `LanguageLevel`、`OnboardingDraft`、创建语言空间摘要和后续数据模型不变。
5. iPad 和 macOS 第一阶段不改变可见行为，等 iPhone 人工确认后再做第二阶段。
6. 增加测试或静态验证，防止新控件缺少 A1-C2 展示、说明文案、iPhone-only gate 或无障碍标记。

## 4. 范围

- 修改 iPhone onboarding 水平选择控件。
- 新增或调整 `LangoTraceUI` 内部私有 SwiftUI 子视图。
- 新增 `onboarding.level.a1.title`、`onboarding.level.a1.description` 等等级展示文案。
- 删除水平问题句，避免在高密度区域重复解释；字段标题统一使用“当前水平”，说明句保留“用于调整生成难度，之后可以随时修改”。
- 将“数据默认保存在本机”从表单卡片降级为主按钮下方的低权重轻提示，减少 onboarding 垂直占用。
- 新增或扩展 `LangoTraceUI` package 测试。
- 必要时更新 `docs/spec/002-navigation-and-routing.md` 或 `docs/spec/003-ui-design-system.md` 中关于首次引导水平选择的长期约束。

## 5. 不做什么

- 不改变 `LanguageLevel` 的枚举值、顺序或 raw value。
- 不把自然语言等级名写入 Core 数据模型。
- 不改变语言空间创建流程、默认 `.b1`、启动路由或语言空间摘要格式。
- 不在第一阶段改 iPad onboarding 或 macOS onboarding 的可见控件。
- 不实现真实语言空间持久化、多空间切换或设置页内等级修改。
- 不把 CEFR 替换为三档或四档模糊等级。
- 不在 onboarding 中提前展开 AI Provider、备份、同步、目录选择或对象存储配置。

## 6. 证据与决策依据

- 代码证据：`OnboardingView.swift` 当前使用 `.pickerStyle(.segmented)` 展示裸 `LanguageLevel.rawValue`。
- 代码证据：`LanguageLevel` 已是 `CaseIterable`，适合继续作为列表数据源。
- 产品依据：`docs/README.md` 和 `docs/spec/002-navigation-and-routing.md` 都要求首次启动先询问母语、目标语言和当前水平，再创建第一个语言空间。
- 设计依据：用户确认采用紧凑单选列表，最多露出三个选项，内部滚动，且要与页面整体协调。
- 交互依据：悬浮说明在 iPhone 上发现成本高，也不利于 VoiceOver 和 Dynamic Type；固定列表说明更直接。
- 国际化依据：`docs/spec/006-interface-localization-and-language-boundaries.md` 要求界面语言、用户母语和目标学习语言分离；本控件的 UI chrome 使用界面语言，目标语言只能作为变量或语义上下文出现，不能硬编码为英语。

## 7. 涉及的代码文件路径

- 修改：`Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- 修改：`Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- 修改或新增测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- 可选新增测试：`Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

## 8. 参考的代码文件路径

- 参考：`Packages/LangoTraceCore/Sources/LangoTraceCore/LanguageLevel.swift`
- 参考：`Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`
- 参考：`Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- 参考：`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- 参考：`Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

## 9. 涉及的文档路径

- 本方案：`docs/plans/active/2026-05-20-feature-onboarding-level-selector-ios-first.md`
- 参考：`docs/README.md`
- 参考：`docs/spec/002-navigation-and-routing.md`
- 参考：`docs/spec/003-ui-design-system.md`
- 完成后如形成长期 UI 规则：更新 `docs/spec/002-navigation-and-routing.md` 或 `docs/spec/003-ui-design-system.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

### Task 1：增加 iPhone-only gate 和可测试 seam

**Files:**
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify or Create: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

- [ ] **Step 1: 编写失败测试，确认第一阶段必须有 iPhone-only gate**

  在 `OnboardingLevelSelectorTests.swift` 中读取 `OnboardingView.swift` 源码，断言存在明确的 iPhone / compact gate，例如 `levelSelectorStyle` 或等价命名，并断言该 gate 不只是 `#if os(iOS)`。

  建议测试意图：

  ```swift
  @Test("Onboarding compact level selector is gated to iPhone first")
  func onboardingCompactLevelSelectorIsGatedToIPhoneFirst() throws {
      let source = try String(contentsOf: sourceFileURL(named: "OnboardingView.swift"), encoding: .utf8)

      #expect(source.contains("OnboardingLevelSelectorStyle"))
      #expect(source.contains("levelSelectorStyle"))
      #expect(source.contains("userInterfaceIdiom"))
      #expect(source.contains(".phone"))
      #expect(source.contains("segmentedLevelPicker"))
  }
  ```

- [ ] **Step 2: 运行测试确认失败**

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
  ```

  Expected: FAIL，因为 `levelSelectorStyle` 和新测试文件尚未实现。

- [ ] **Step 3: 在 `OnboardingView` 增加 gate**

  在 `OnboardingView` 内增加私有 style seam，用于判断是否启用新的紧凑等级列表。第一阶段应严格限定 iPhone：

  - iPhone：使用新紧凑列表。
  - iPad：继续使用旧 segmented picker，等待第二阶段。
  - macOS：继续使用旧 segmented picker，等待第二阶段。

  推荐实现方向：

  ```swift
  private enum OnboardingLevelSelectorStyle {
      case compactList
      case segmented
  }

  #if os(iOS)
      private var levelSelectorStyle: OnboardingLevelSelectorStyle {
          UIDevice.current.userInterfaceIdiom == .phone ? .compactList : .segmented
      }
  #else
      private var levelSelectorStyle: OnboardingLevelSelectorStyle {
          .segmented
      }
  #endif
  ```

  如果引入 `UIDevice`，文件顶部在 `#if os(iOS)` 内 `import UIKit`，避免 macOS 编译受影响。不要在多个 view 分支中散落 `UIDevice.current` 判断；平台差异统一收敛到 `levelSelectorStyle`。

- [ ] **Step 4: 把现有 segmented picker 抽出为 `segmentedLevelPicker`**

  将现有 picker 抽为私有 view，保持旧行为供 iPad/macOS 使用：

  ```swift
  private var segmentedLevelPicker: some View {
      Picker(selection: $draft.level) {
          ForEach(LanguageLevel.allCases, id: \.self) { level in
              Text(level.rawValue).tag(level)
          }
      } label: {
          localizedText("onboarding.level.title")
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .accessibilityLabel(localizedText("onboarding.level.title"))
      .accessibilityHint(
          localizedString("onboarding.level.accessibilityHint", draft.resolvedTargetLanguage.nativeName)
      )
  }
  ```

- [ ] **Step 5: 运行测试确认 gate 存在**

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
  ```

  Expected: PASS。

### Task 2：实现紧凑等级单选列表

**Files:**
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify or Create: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

- [ ] **Step 1: 编写失败测试，确认列表结构和固定高度**

  测试源码中应包含：

  - `compactLevelSelector`
  - `ScrollView`
  - `LanguageLevel.allCases`
  - `onboarding.level.a1.title`
  - `onboarding.level.c2.description`
  - `levelSelectorApproxVisibleRows`
  - `@ScaledMetric`
  - `Button`
  - `accessibilityValue`

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
  ```

  Expected: FAIL，因为紧凑列表尚未实现。

- [ ] **Step 2: 增加列表高度常量**

  在 `OnboardingView` 内增加与现有布局常量并列的常量：

  ```swift
  private let levelSelectorApproxVisibleRows: CGFloat = 3
  @ScaledMetric(relativeTo: .body) private var compactLevelRowMinHeight: CGFloat = 58
  @ScaledMetric(relativeTo: .body) private var compactLevelRowSpacing: CGFloat = 8
  ```

  列表高度按约 `3` 行控制，允许内部滚动。实现时避免把控件高度写成魔法数字，也不要固定每行高度导致 Dynamic Type 裁切；行使用 `minHeight`，列表使用 `maxHeight`。

- [ ] **Step 3: 新增 `compactLevelSelector`**

  新增私有 view，使用 `ScrollView(.vertical)` 和 `LazyVStack` 或 `VStack` 展示 `LanguageLevel.allCases`。每行使用 `Button` 更新 `draft.level`。

  行内容结构：

  - 左侧：`level.rawValue`，如 `B1`。
  - 中间：`localizedText(onboardingLevelTitleKey(for: level))` 和 `localizedText(onboardingLevelDescriptionKey(for: level))`。
  - 右侧：选中态图标，例如 `checkmark.circle.fill` 或圆形选中标记。

  视觉要求：

  - 行最小高度约 `58`，总高度约三行加间距；Dynamic Type 放大时宁可露出少于三项，也不能裁切文字或缩小字号。
  - 背景、圆角、边框、选中态使用 `LangoTraceDesign.ColorToken`，与 `languageForm` 的 panel 风格一致。
  - 选中态低调，不能让列表比创建按钮更抢眼。
  - `ScrollView` 内部显示滚动指示器，帮助用户发现还有更多等级。
  - 每一行触控目标不低于 44pt。

- [ ] **Step 4: 增加 key helper**

  在 `OnboardingView.swift` 增加私有 helper：

  ```swift
  private func onboardingLevelTitleKey(for level: LanguageLevel) -> String {
      "onboarding.level.\(level.rawValue.lowercased()).title"
  }

  private func onboardingLevelDescriptionKey(for level: LanguageLevel) -> String {
      "onboarding.level.\(level.rawValue.lowercased()).description"
  }
  ```

- [ ] **Step 5: 在当前水平分组中切换新旧控件**

  在原水平分组中使用：

  ```swift
  switch levelSelectorStyle {
  case .compactList:
      compactLevelSelector
  case .segmented:
      segmentedLevelPicker
  }
  ```

  这样第一阶段 iPhone 使用新列表，iPad/macOS 继续使用旧 segmented picker。

- [ ] **Step 6: 运行测试确认列表结构通过**

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
  ```

  Expected: PASS。

### Task 3：补充等级文案和无障碍语义

**Files:**
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- Modify or Create: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

- [ ] **Step 1: 编写失败测试，确认 string catalog 包含全部等级文案和简化文案**

  测试读取 `Localizable.xcstrings`，确认以下 12 个 key 存在，并覆盖 `project.yml` 当前声明的 8 个界面语言：`en / zh-Hans / es / ja / fr / de / ko / ru`。同时确认 `onboarding.level.title` 的简体中文为 `当前水平`，`onboarding.subtitle` 的简体中文为 `创建一个语言空间，把生活变成学习材料。`。

  - `onboarding.level.a1.title`
  - `onboarding.level.a1.description`
  - `onboarding.level.a2.title`
  - `onboarding.level.a2.description`
  - `onboarding.level.b1.title`
  - `onboarding.level.b1.description`
  - `onboarding.level.b2.title`
  - `onboarding.level.b2.description`
  - `onboarding.level.c1.title`
  - `onboarding.level.c1.description`
  - `onboarding.level.c2.title`
  - `onboarding.level.c2.description`

- [ ] **Step 2: 删除水平问题句，减少 iPhone 首屏密度**

  不再展示 `你现在大概能用 English 做到什么？` 这类问题句。`水平自评` 字段标题改为 `当前水平`，下方仅保留用途说明：

  ```text
  用于调整生成难度，之后可以随时修改。
  ```

  英文建议：

  ```text
  What can you do in %@ right now?
  ```

  变量使用 `draft.resolvedTargetLanguage.nativeName` 或现有 UI display projection 中适合当前界面的目标语言展示名。不能在 SwiftUI 代码或 string catalog key 中写死 `英语` / `English` 作为通用问题。

- [ ] **Step 3: 添加中文等级文案**

  建议中文文案：

  ```text
  A1 入门：认识少量词句，刚开始学
  A2 初级：能说简单日常句子
  B1 日常交流：能处理旅行、生活中的常见表达
  B2 独立表达：能较完整表达观点和经历
  C1 熟练表达：能自然讨论复杂话题
  C2 高级掌握：接近专业、学术或高强度使用
  ```

- [ ] **Step 4: 添加英文等级文案**

  建议英文文案：

  ```text
  A1 Beginner: You know a few words and phrases.
  A2 Elementary: You can use simple everyday sentences.
  B1 Everyday: You can handle common travel and daily situations.
  B2 Independent: You can describe experiences and explain opinions.
  C1 Advanced: You can discuss complex topics naturally.
  C2 Proficient: You can use the language in demanding professional or academic contexts.
  ```

  其他 6 个已声明界面语言必须同步补齐简洁译文，不能只依赖英文 fallback。若翻译质量后续需要人工校对，应在实施记录中写明“文案需本地化 QA”，但 key 覆盖必须完整。

- [ ] **Step 5: 增加每行无障碍值**

  每个等级行应组合读出：等级代码、自然名称、说明。选中项应有 selected trait 或等价语义。

  示例语义要求：

  ```swift
  .accessibilityLabel(Text("\(level.rawValue), \(localizedString(onboardingLevelTitleKey(for: level)))"))
  .accessibilityValue(localizedText(onboardingLevelDescriptionKey(for: level)))
  .accessibilityAddTraits(draft.level == level ? .isSelected : [])
  ```

  如果 SwiftUI `Text` 拼接方式更适合现有 helper，应保持可本地化且不硬编码中文。

- [ ] **Step 6: 运行测试**

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
  ```

  Expected: PASS。

### Task 4：iPhone 人工查看前的构建和截图准备

**Files:**
- Modify: no product code expected in this task

- [ ] **Step 1: 运行 iOS package 测试**

  Run:

  ```bash
  swift test --package-path Packages/LangoTraceUI
  ```

  Expected: PASS。

- [ ] **Step 2: 构建 iPhone 目标**

  Run:

  ```bash
  xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```

  Expected: BUILD SUCCEEDED。

- [ ] **Step 3: 启动 iPhone 17 Simulator 并人工查看 onboarding**

  检查点：

  - 当前水平控件与母语、目标语言、隐私说明、底部创建按钮协调。
  - 默认高度只露出约三个等级。
  - 内部滚动可以查看 B2、C1、C2。
  - 默认 `.b1` 选中态清晰但不过度抢眼。
  - 页面在 iPhone 17 上不出现元素重叠、按钮遮挡或上下文断裂。
  - 目标语言不是英语时，问题文案仍然正确，例如选择日语空间时不能继续显示“英语”。
  - 英文和简体中文界面至少各查看一次；如能快速切换，也抽查一个长文本语言，例如德语。
  - Dynamic Type 放大后仍能选择等级；如果高度不足，应优先保持可滚动和可读，不压缩到不可读。

- [ ] **Step 4: 如环境允许，补充小屏或窄宽度人工查看**

  优先查看 iPhone SE 或等价窄宽度设备。如果当前模拟器环境没有对应设备，应在实施记录中说明，并至少通过 iPhone 17 上的 Dynamic Type / 窄内容约束检查替代。

- [ ] **Step 5: 用户人工确认**

  在用户确认 iPhone 效果无误前，不进入 iPad 和 macOS 适配。

### Task 5：iPad 和 macOS 后续适配门槛

**Files:**
- Modify later: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify later: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`

- [ ] **Step 1: 用户确认 iPhone 版本后，更新本方案状态**

  在实施记录写明人工确认时间、设备、截图或观察结果。

- [ ] **Step 2: 设计 iPad/macOS 适配方式**

  候选路径：

  - iPad 使用同一紧凑列表，但在 wide layout 中允许更舒展的行距。
  - macOS 使用列表或 popover 式说明，但不得恢复裸 `A1-C2` 不解释的状态。

- [ ] **Step 3: 解除或调整 iPhone-only gate**

  只有在 iPad/macOS 视觉确认后，才把 `levelSelectorStyle` 改成跨平台规则。

### Task 6：iPad 和 macOS 三端收口

**Files:**
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`
- Modify: `docs/spec/002-navigation-and-routing.md`
- Modify: `docs/spec/003-ui-design-system.md`
- Modify as needed: `docs/spec/006-interface-localization-and-language-boundaries.md`
- Modify as needed: `docs/product-main-reference.md`
- Modify as needed: `docs/technical-framework-roadmap.md`

- [x] **Step 1: 文档影响检查**

  因 iPhone 方案已通过人工检查，并准备扩展到 iPad / macOS，长期规则需要从“iPhone 阶段性实现”升级为“三端 onboarding 当前水平规则”。更新导航规范和 UI 设计系统规范，明确：

  - 字段名使用“当前水平”。
  - A1-C2 是可见等级代码和模型值，但不能裸露为唯一解释。
  - 三端都使用解释性等级列表，不再回退裸 segmented control。
  - 该变化不改变 `LanguageLevel`、`OnboardingDraft` 或语言空间模型。

- [x] **Step 2: 测试先行，确认三端不再保留旧 gate**

  更新 `OnboardingLevelSelectorTests`，断言 `OnboardingView` 不再包含 `OnboardingLevelSelectorStyle`、`levelSelectorStyle`、`userInterfaceIdiom`、`segmentedLevelPicker` 或 `.pickerStyle(.segmented)`。

- [x] **Step 3: 移除旧 gate 和 segmented picker**

  在 `OnboardingView` 中直接使用 `compactLevelSelector`，删除旧 iPhone-only gate、`UIKit` import、`segmentedLevelPicker` 和相关 switch。iPad / macOS 继续通过现有 wide onboarding layout 控制页面结构，但水平选择控件与 iPhone 共享。

- [x] **Step 4: 三端验证和重启**

  运行 UI package 测试、iPhone / iPad / macOS 构建，重新安装并启动 booted iPhone 和 iPad 模拟器，并重新打开 macOS app。

### Task 7：本地保存说明降级为底部轻提示

**Files:**
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- Modify: `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- Modify: `Packages/LangoTraceUI/Tests/LangoTraceUITests/OnboardingLevelSelectorTests.swift`
- Modify: `docs/spec/003-ui-design-system.md`
- Modify: `docs/product-main-reference.md`

- [x] **Step 1: 更新文档设计决策**

  已将 `docs/spec/003-ui-design-system.md` 补充为“Onboarding 本地保存轻提示”规则，并同步更新 `docs/product-main-reference.md` 中的首次体验说明。

- [x] **Step 2: 测试先行，禁止本地保存说明继续作为表单卡片**

  更新 UI package 测试，断言 `OnboardingView.swift` 不再将本地保存说明作为 `privacyCard`、`localStorageCard` 或等价卡片放在表单主体中；新增断言确认存在按钮下方轻提示 seam，例如 `localStorageFootnote`。

- [x] **Step 3: 移除旧卡片，新增按钮下方轻提示**

  在 `OnboardingView` 中删除“数据默认保存在本机”卡片式结构，将说明移到创建语言空间主按钮下方。已确认文案为 `数据默认保存在本机，可在设置中查看与调整。`，使用低权重文本、可选小锁图标、静态无障碍提示，并保持与底部 safe area 的距离。

- [x] **Step 4: 更新 8 语言 String Catalog**

  更新或新增轻提示对应 key，覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`。若沿用现有 key，应确认旧标题/正文拆分不再导致未使用文案残留。

- [x] **Step 5: 三端构建与模拟器重启**

  运行 `scripts/verify.sh`，通过后重新安装并启动 iPhone 17 与 iPad Pro 13-inch (M5) 模拟器中的 Debug App，并重新打开 macOS Debug App。

## 12. 复查方法

- 代码复查：
  - `LanguageLevel` 和 `OnboardingDraft` 不应发生数据模型改动。
  - 新控件应位于 `LangoTraceUI` 表现层。
  - iPhone-only gate 必须能区分 iPhone 与 iPad，不得只使用 `#if os(iOS)`，且平台判断必须收敛在单一 style seam 中。
  - iPad/macOS 第一阶段仍能走旧 segmented picker。

- UI 复查：
  - iPhone onboarding 页面整体视觉协调，控件密度和页面留白一致。
  - 水平列表不遮挡底部创建按钮。
  - 选中态、滚动指示、无障碍语义清晰。
  - 问题文案不把目标语言固定为英语。

- 文档复查：
  - 如果实现后形成长期规则，应更新对应 spec。
  - 如果只是 iPhone 阶段性实现，先在本方案实施记录中记录，等待三端完成后再判断是否升级到长期 spec。

## 13. 验证命令

第一阶段 iPhone 完成前至少运行：

```bash
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
if rg -n "英语|English" Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift; then
  echo "OnboardingView.swift must not hard-code a target language." >&2
  exit 1
fi
git diff --check
git status --short
```

如果进入三端收口，运行：

```bash
scripts/verify.sh
```

如果 `scripts/verify.sh` 中某项因为环境或工具缺失不能运行，必须在实施记录中写明具体失败原因、影响范围和补充验证。

## 14. 文档影响检查

本任务影响首次启动 onboarding 的 UI 设计和交互说明，但不改变语言空间核心决策、数据模型、AI Provider、同步、权限或付费边界。

- 第一阶段完成后：在本方案实施记录中记录 iPhone UI 事实和人工验收结果。
- 三端完成后：检查是否需要更新 `docs/spec/002-navigation-and-routing.md`，补充“当前水平不应裸露 A1-C2，应提供自然语言解释”的长期约束。
- 如新增长期 UI 组件规则：检查 `docs/spec/003-ui-design-system.md` 是否需要增加“紧凑可滚动单选列表”的使用规范。
- 如本地保存说明从卡片降级为轻提示：更新 `docs/spec/003-ui-design-system.md` 和 `docs/product-main-reference.md`，明确本地优先承诺仍保留，但视觉权重不与必填表单项并列。
- 如本次补充 8 语言文案但未完成母语者审校，应在实施记录中标注后续本地化 QA 风险，不得在产品文案中宣称这些翻译已经完成发行级审校。

## 15. 实施记录

### 2026-05-20 iPhone 第一阶段实现

- 已在 `.gitignore` 中加入 `.superpowers/`，避免本地 agent 临时目录进入版本控制。
- 已新增 `OnboardingLevelSelectorTests`，覆盖 iPhone-only gate、紧凑等级列表结构、8 语言 String Catalog key 覆盖、目标语言不硬编码为英语。
- 已在 `OnboardingView` 中增加 `OnboardingLevelSelectorStyle` 和 `levelSelectorStyle`，第一阶段仅 `UIDevice.current.userInterfaceIdiom == .phone` 使用紧凑等级列表；iPad 和 macOS 继续走 `segmentedLevelPicker`。
- 已新增 iPhone 紧凑等级列表：保留 A1-C2 代码，显示自然名称和一句话说明，约三行可见，内部滚动，使用 Button 选中态和无障碍 value / selected trait。
- 已新增 `onboarding.level.question` 以及 A1-C2 的 title / description 文案，覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`。这些翻译为当前实现文案，后续发行前仍建议做本地化 QA。
- 已保持 `LanguageLevel`、`OnboardingDraft`、语言空间创建流程和摘要格式不变。
- 已构建并安装到 iPhone 17 模拟器，当前应用停留在 Welcome 页，等待用户点击“开始设置”进入 onboarding 人工查看新控件。

### 2026-05-20 iPhone 视觉密度收敛

- 根据人工截图反馈，顶部说明改为 `创建一个语言空间，把生活变成学习材料。`，减少对“长期学习档案”和“最少信息”的解释。
- 字段标题从 `水平自评` 改为 `当前水平`，避免听起来像一个正式评估流程。
- 删除 `你现在大概能用 English 做到什么？` 问题句，保留标题和用途说明，降低水平区域的视觉密度。
- 移除未使用的 `onboarding.level.question` string catalog key，避免保留不再使用的界面文案。
- 同步更新 welcome 文案中对首次使用信息的描述，将“水平自评”统一为“当前水平”。

追加验证结果：

```bash
swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
# PASS: 4 tests

swift test --package-path Packages/LangoTraceUI
# PASS: 111 tests in 18 suites

rg -n "onboarding.level.question|你现在大概|长期学习档案|水平自评" Packages/LangoTraceUI/Sources/LangoTraceUI
# PASS: no matches

git diff --check
# PASS

xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
# PASS: BUILD SUCCEEDED
```

### 2026-05-20 iPad / macOS 三端收口

- 用户确认 iPhone 检查通过后，文档影响检查结论为：需要更新长期规范。已将 `docs/spec/002-navigation-and-routing.md` 和 `docs/spec/003-ui-design-system.md` 补充为三端 onboarding 当前水平规则，并同步修正 `docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md` 中仍使用“水平自评”的当前事实表述。
- 已更新 `OnboardingLevelSelectorTests`，要求三端共享解释性等级列表，并禁止继续保留 `OnboardingLevelSelectorStyle`、`levelSelectorStyle`、`userInterfaceIdiom`、`segmentedLevelPicker` 和 `.pickerStyle(.segmented)`。
- 已移除 `OnboardingView` 中的 iPhone-only gate、`UIKit` import 和旧 segmented picker；iPhone、iPad、macOS 均使用同一个 `compactLevelSelector`，页面布局仍由现有 compact / wide onboarding layout 控制。
- 已重新构建 iPhone、iPad、macOS，并重启 iPhone 17 与 iPad Pro 13-inch (M5) 模拟器后安装和启动当前 Debug App；macOS Debug App 已重新打开。

验证结果：

```bash
swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests
# PASS: 4 tests

swift test --package-path Packages/LangoTraceUI
# PASS: 111 tests in 18 suites

if rg -n "英语|English" Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift; then
  echo "OnboardingView.swift must not hard-code a target language." >&2
  exit 1
fi
# PASS: no matches

git diff --check
# PASS

xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
# PASS: BUILD SUCCEEDED

xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
# PASS: BUILD SUCCEEDED

xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
# PASS: BUILD SUCCEEDED

scripts/verify.sh
# PASS: xcodegen generate, xcodebuild -list, Core 26 tests, Data 11 tests, UI 111 tests,
# iPhone / iPad / macOS builds, SwiftLint 0 violations, SwiftFormat 0 files require formatting
```

运行重启记录：

- iPhone 17 模拟器 `CC9B1A68-B4BA-4253-AAC4-2DC8FF6CB21C`：shutdown -> boot -> bootstatus -> install -> launch，launch PID `61412`。
- iPad Pro 13-inch (M5) 模拟器 `73045FC7-A9FB-4F41-892E-3CE9755D2ECB`：shutdown -> boot -> bootstatus -> install -> launch，launch PID `61411`。
- macOS：`pkill -x LangoTrace` 后重新打开 DerivedData 中的 Debug `LangoTrace.app`。

尚未完成：

- 用户人工查看 iPad / macOS onboarding 页面并确认页面元素协调。
- 方案从 `active/` 移入 `done/`，需等待三端人工验收后执行。

### 2026-05-20 本地保存说明轻提示设计确认

- 根据用户截图反馈，“数据默认保存在本机”卡片当前占据过多页面空间，且信息优先级低于母语、目标语言、当前水平和创建按钮。
- 设计结论：保留本地优先信任提示，但从表单卡片降级为“创建语言空间”主按钮下方的低权重 footnote。
- 已确认中文文案：`数据默认保存在本机，可在设置中查看与调整。`
- 已更新 `docs/spec/003-ui-design-system.md` 和 `docs/product-main-reference.md`。

### 2026-05-20 本地保存说明轻提示实现记录

- 已在 `OnboardingLevelSelectorTests.swift` 增加回归测试，禁止 `privacyNote`、`onboarding.privacy.localStorage`、`onboarding.privacy.noExternalAI` 回到 `OnboardingView.swift`。
- 已在 `OnboardingView.swift` 删除表单主体内的本地保存说明卡片，并在 `createButtonContent` 中把 `localStorageFootnote` 放到创建按钮下方。
- 已将 String Catalog 收敛为 `onboarding.privacy.footnote` 单一 key，覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`，简体中文为 `数据默认保存在本机，可在设置中查看与调整。`。
- 已运行 `swift test --package-path Packages/LangoTraceUI --filter OnboardingLevelSelectorTests`，6 个测试通过。
- 已运行 `swift test --package-path Packages/LangoTraceUI`，113 个测试通过。
- 已运行 `scripts/verify.sh`，Core 26 个测试、Data 11 个测试、UI 113 个测试、iPhone 17 构建、iPad Pro 13-inch (M5) 构建、macOS 构建、SwiftLint、SwiftFormat 和文档 placeholder 扫描均通过。
- 已重启并重新安装 / 启动模拟器 App：iPhone 17 launch PID `66379`，iPad Pro 13-inch (M5) launch PID `66378`；macOS Debug App 已重新打开。

## 16. 完成标准

第一阶段完成标准：

- iPhone onboarding 使用紧凑等级单选列表。
- iPad 和 macOS 第一阶段可见行为未被顺带改变。
- A1-C2 均有自然名称和一句话说明。
- 新增等级文案覆盖 `en / zh-Hans / es / ja / fr / de / ko / ru`。
- 水平问题文案不会把目标语言写死为英语。
- `LanguageLevel` 和 `OnboardingDraft` 未发生模型层变更。
- `swift test --package-path Packages/LangoTraceUI` 通过。
- `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build` 通过。
- 用户已人工查看 iPhone 效果并确认页面元素协调。

全任务完成标准：

- iPhone、iPad、macOS 均完成相应等级选择体验适配。
- “数据默认保存在本机”不再作为表单卡片占据页面中段，而是在创建按钮下方作为低权重静态提示展示。
- 三端人工查看均确认无误。
- 必要长期 spec 已更新或在文档影响检查中说明无需更新。
- 完整验证命令通过。
- 方案从 `active/` 移入 `done/`，状态更新为 `Verified` 或 `Done`。

## 17. 剩余风险

- 第一阶段若使用 `UIDevice.current.userInterfaceIdiom`，需要确认 Swift package 在 iOS target 下引入 UIKit 不影响 macOS 编译。
- 约三行高度在超大 Dynamic Type 下可能只能露出少于三项，需要人工检查是否仍可滚动、可读、可点击。
- 新增 8 语言文案即使 key 覆盖完整，也可能需要后续母语者或专业本地化 QA 校对。
- iPad 窄窗口和 Mac 小窗口后续可能也需要紧凑列表，但必须等 iPhone 版本确认后再统一设计，避免提前扩大改动范围。
