# iPad AI Provider 测试结果 Sheet 布局修复方案

状态：Verified

类型：bug

创建日期：2026-05-25

最后更新日期：2026-05-25

## 用户确认记录

- 2026-05-25：用户提供 iPad Pro 13-inch 横屏截图，指出 AI Provider 设置页点击“测试请求”后的弹出界面顶部存在大量空白，要求从专业 UI 设计师和 Apple 应用交互设计师角度深入优化。
- 2026-05-25：已评估三种方向：自适应状态 sheet、按钮锚定 popover、右侧 inspector。用户确认采用方案 A，即保留状态反馈 sheet，并修正 iPad regular width 下的尺寸、顶部结构和内容密度。
- 2026-05-25：用户授权后续疑问由系统架构师和资深 Apple 交互设计师视角评估并采纳最优推荐方案；本任务进入实现。实现不改变 AI Provider 请求语义、Provider 配置数据模型或跨平台设置路由。

## 需求或 Bug 描述

在 iPad 端 AI Provider 设置详情页点击“测试请求”后，测试结果 sheet 的内容区顶部出现明显大空白。截图中自定义 handle、标题和能力结果卡片被整体下推，弹窗视觉焦点不稳，像一个没有完成布局约束的调试面板。

该问题破坏了 `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 中对 AI Provider 测试结果 sheet 的规则：顶部应使用克制 handle、完成后中性面板标题、右上关闭按钮，能力结果使用 grouped card 和细分隔；不应出现大面积无意义留白。

## 复现方式

1. 在 iPad 模拟器或真机横屏打开 LangoTrace。
2. 进入设置中的 AI Provider 详情页。
3. 填入或加载可测试的 Provider 配置。
4. 点击“测试请求”。
5. 观察弹出的结果 sheet：内容顶部存在大空白，handle 和标题不靠近 sheet 顶部。

## 预期行为

- iPad regular width 下，测试结果弹窗应呈现为内容自适应高度的状态反馈 sheet / card。
- 顶部从上到下应为：少量 top inset、克制 handle、中性标题和右上关闭按钮、能力结果 grouped card。
- 成功态不显示 prominent 重试按钮；失败、部分可用、取消或不支持状态才显示恢复操作。
- 能力结果行保持 44pt 以上触控目标，文本不溢出，状态不只靠颜色表达。
- iPhone compact width 继续使用当前 compact sheet detent 语义。
- 不新增 iPad 专用 AI Provider 设置页，不改变三端共享设置详情 seam。

## 实际行为

- iPad regular width 的 sheet 在内容上方保留了大面积空白。
- 视觉上像系统 presentation 高度与内容理想高度没有对齐，导致自定义状态 chrome 被推到 sheet 中部。
- 用户第一眼看到的是空白，而不是“测试请求”状态和能力结果。

## 根因分析

置信度：85%

当前 `AIProviderSettingsView` 在 sheet 中直接放置 `AIProviderProbeResultPanelContent`，只限制了 `maxWidth`，没有为 iPad regular width 明确指定符合内容理想高度的 presentation sizing。iOS 18+ 已提供 SwiftUI `presentationSizing(_:)`，项目 deployment target 为 iOS 18.0 / macOS 15.0，可以使用 fitted presentation 让 iPad sheet 的垂直尺寸跟随内容理想高度。当前实现只在 compact width 下套用 `.presentationDetents([.medium, .large])`，regular width 没有等价的高度控制。

## 置信度依据

- 截图中的空白出现在自定义 handle 之上，而不是 grouped card 内部，说明问题主要在 sheet presentation 与根内容垂直布局关系。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 当前 sheet 内容只有 `.frame(maxWidth: aiProviderProbeRegularWidth, alignment: .leading)`，没有 regular width fitted sizing。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift` 的 `AIProviderProbeResultPanelContent` 内部顺序已经是 handle、title、capability list、retry button，逻辑上不应该主动制造顶部大空白。
- 项目最低 iOS 版本为 18.0，使用 `presentationSizing(_:)` 不需要降低部署兼容性。

## 备选原因

- iOS 26 模拟器的 sheet 默认外观或设备 chrome 造成额外 safe area inset；如果 fitted sizing 后仍有空白，需要通过截图确认是否还存在系统层 inset。
- 根 VStack 在某些 presentation 容器中被父级 proposal 拉伸并居中；如果 `presentationSizing(.fitted)` 不足，需要增加一个明确的 `AIProviderProbeResultPanelSheet` 容器，控制理想宽高和顶部对齐。
- 动态字体或能力行数量变化可能使理想高度超过 fitted sheet 的舒适范围；应保留内容滚动或高度上限作为后续扩展方向，本任务先覆盖当前 4-6 个能力结果行。

## 目标

- 修复 iPad regular width 测试结果 sheet 顶部大空白。
- 保留当前三端共享 AI Provider 设置详情和测试服务边界。
- 使用 Apple 原生 SwiftUI presentation API 优先解决布局，不引入 UIKit bridge。
- 增加源代码级回归测试，锁定 fitted sizing、compact detents 和非成功态重试按钮规则。
- 更新方案实施记录和验证结果。

## 范围

涉及：

- AI Provider 测试结果 sheet presentation。
- `AIProviderProbeResultPanelContent` 的外层容器、宽度、高度和顶部对齐。
- UI package 中 AI Provider probe 相关测试。
- 本任务方案的实施记录和验证结果。

不涉及：

- AI Provider 请求内容、网络 adapter、Keychain、SQLite / GRDB 保存逻辑。
- Provider preset、TTS probe、图片 probe、语言支持 probe 的语义变化。
- 新增 request preview、请求日志或 Prompt Preset 执行链路。
- 将测试结果改成 iPad inspector、popover 或主页面 inline panel。
- 修改 iPhone 设置主流程或 macOS Settings scene 信息架构。

## 证据与决策依据

- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 已要求 AI Provider 测试结果 sheet 采用 Apple 风格状态面板，能力结果使用 grouped card 和细分隔。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md` 已区分任务型 sheet 与状态反馈 sheet；测试结果属于状态反馈。
- iPad 设计评估结论：测试结果是按钮触发的短生命周期反馈，应聚焦确认，不应占用长期 inspector；popover 对多能力结果和失败恢复操作承载不足。
- SwiftUI 官方 API `presentationSizing(_:)` / `PresentationSizing.fitted` 支持 iOS 18+ 内容自适应 presentation sizing；当前项目最低 iOS 18.0。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 涉及的文档路径

- `docs/plans/active/2026-05-25-bug-ai-provider-probe-ipad-sheet-layout.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`

## 实施方案

### Task 1：写回归测试，锁定 iPad regular width 使用 fitted sizing

修改 `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift` 中现有 presentation 测试：

```swift
@Test("Probe result sheet uses fitted sizing on regular width and compact detents only on compact width")
func probeResultSheetUsesFittedSizingOnRegularWidthAndCompactDetentsOnlyOnCompactWidth() throws {
    let viewSource = try String(contentsOf: sourceFileURL(named: "AIProviderSettingsView.swift"), encoding: .utf8)
    let componentSource = try String(
        contentsOf: sourceFileURL(named: "AIProviderSettingsComponents.swift"),
        encoding: .utf8
    )

    #expect(viewSource.contains("AIProviderProbeResultPanelSheet("))
    #expect(viewSource.contains("aiProviderProbePresentationStyle(compactWidth: isCompactWidth)"))
    #expect(viewSource.contains("presentationSizing(.fitted)"))
    #expect(viewSource.contains("presentationDetents([.medium, .large])"))
    #expect(viewSource.contains(".presentationDragIndicator(.hidden)"))
    #expect(viewSource.contains("if compactWidth"))
    #expect(viewSource.contains("else"))
    #expect(componentSource.contains("struct AIProviderProbeResultPanelSheet"))
    #expect(componentSource.contains(".frame(maxWidth: aiProviderProbeRegularWidth"))
    #expect(componentSource.contains(".fixedSize(horizontal: false, vertical: true)"))
    #expect(!viewSource.contains(".frame(maxWidth: aiProviderProbeRegularWidth, alignment: .leading)"))
}
```

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

预期：测试失败，提示缺少 `AIProviderProbeResultPanelSheet`、`presentationSizing(.fitted)` 或 `fixedSize(horizontal: false, vertical: true)`。

### Task 2：提取结果 sheet 容器并控制理想尺寸

修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`：

```swift
let aiProviderProbeRegularWidth: CGFloat = 520

struct AIProviderProbeResultPanelSheet: View {
    let result: AIProviderConfigurationProbeResult?
    let isTesting: Bool
    let activeCapabilities: [AIProviderProbeCapability]
    let displayedCapabilities: [AIProviderProbeCapability]
    let onRetry: () -> Void
    let onClose: () -> Void
    var onPlaySpeechPreview: @MainActor (TTSAudioPreviewResource) -> Void = { _ in }

    var body: some View {
        AIProviderProbeResultPanelContent(
            result: result,
            isTesting: isTesting,
            activeCapabilities: activeCapabilities,
            displayedCapabilities: displayedCapabilities,
            onRetry: onRetry,
            onClose: onClose,
            onPlaySpeechPreview: onPlaySpeechPreview
        )
        .frame(maxWidth: aiProviderProbeRegularWidth, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }
}
```

同时从 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 移除文件顶部的 `private let aiProviderProbeRegularWidth: CGFloat = 520`，避免同一常量分散在 view 和组件文件中。

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

预期：仍可能失败，因为 sheet 调用处尚未改用新容器，presentation style 尚未加 fitted sizing。

### Task 3：在 sheet 调用处使用新容器

修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 的 `.sheet` 内容：

```swift
.sheet(isPresented: $isProbeResultPresented) {
    AIProviderProbeResultPanelSheet(
        result: latestProbeResult,
        isTesting: isTesting,
        activeCapabilities: activeProbeCapabilities,
        displayedCapabilities: displayedProbeCapabilities,
        onRetry: validateConfiguration,
        onClose: { isProbeResultPresented = false },
        onPlaySpeechPreview: playSpeechPreview
    )
    .aiProviderProbePresentationStyle(compactWidth: isCompactWidth)
}
```

保留 `AIProviderProbeResultPanelContent` 作为 presentation-independent 内容组件，避免把 sheet API 写进内容组件。

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

预期：仍可能失败，因为 regular width presentation style 尚未补 `presentationSizing(.fitted)`。

### Task 4：为 regular width 添加 fitted presentation sizing

修改 `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` 的 `aiProviderProbePresentationStyle(compactWidth:)`：

```swift
private extension View {
    @ViewBuilder
    func aiProviderProbePresentationStyle(compactWidth: Bool) -> some View {
        #if os(iOS)
            if compactWidth {
                presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            } else {
                presentationSizing(.fitted)
            }
        #else
            self
        #endif
    }
}
```

运行：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

预期：测试通过。

### Task 5：人工检查视觉和可访问性风险

在 iPad regular width 模拟器中检查：

- sheet 顶部没有截图中的大空白。
- handle、标题、关闭按钮和能力结果 card 靠近 sheet 顶部，整体垂直节奏紧凑。
- 成功态不显示 prominent “重新测试”。
- 部分可用或失败态保留重试入口。
- 能力行高度不低于 44pt，语音试听按钮仍可点击。
- 关闭按钮有 accessibility label。

优先使用以下构建命令确认 iPad target 可编译：

```bash
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
```

如当前环境不能启动模拟器或截图，需要在实施记录写明未验证项和剩余风险。

### Task 6：完整验证和方案收口

运行聚焦验证：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
```

运行文档与代码格式检查：

```bash
git diff --check
```

运行完整验证：

```bash
scripts/verify.sh
```

通过后在本方案的实施记录中写入命令和结果。如果实现没有改变长期规范，不更新 `docs/spec/`；如果发现 `presentationSizing(.fitted)` 在 iPadOS 26 行为与预期不符，应回到本方案追加替代路径，而不是把问题只留在聊天记录。

## 复查方法

- 严格检查 diff 是否只触及 AI Provider 测试结果 presentation、相关 UI 测试和本方案。
- 检查 `AIProviderSettingsView` 是否仍只调用 `actions.testProviderConfiguration`，没有引入 URLSession、Authorization、Bearer 或 Keychain 直接访问。
- 检查 `AIProviderProbeResultPanelContent` 是否仍不包含 `.sheet` 或 `presentationDetents`。
- 检查 iPhone compact path 是否仍保留 `.presentationDetents([.medium, .large])` 和隐藏系统 drag indicator。
- 检查 iPad regular path 是否使用 `.presentationSizing(.fitted)`。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
git diff --check
scripts/verify.sh
```

## 文档影响检查

预计不需要更新长期 spec，原因：

- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md` 已有 AI Provider 测试结果 sheet 的目标规则。
- `docs/spec/010-apple-platform-interaction-and-accessibility.md` 已有状态反馈 sheet 的顶部结构和成功态重试按钮边界。
- 本任务是实现对齐既有规则，不改变 AI、隐私、Provider、TTS 或同步边界。

如果实现过程证明需要新增状态反馈 sheet 的 fitted sizing 规则，再更新 `docs/spec/010-apple-platform-interaction-and-accessibility.md`。

## 回归测试方案

- 用 `AIProviderSettingsProbeTests` 的源代码结构测试锁定：
  - sheet 内容通过 `AIProviderProbeResultPanelSheet` 承载；
  - iPad regular width path 使用 `presentationSizing(.fitted)`；
  - compact width path 保留 detents；
  - 内容组件不直接依赖 sheet presentation API。
- 用 iPad build 证明 SwiftUI API 在当前 deployment target 下可编译。
- 用人工或截图验证证明实际 iPad 弹窗不再有顶部大空白。

## 实施记录

- 2026-05-25：创建方案，已完成设计方向评估和用户对方案 A 的确认，尚未进入代码实现。
- 2026-05-25：按 TDD 写入 `AIProviderSettingsProbeTests` 回归测试，首次运行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests` 失败，失败点为缺少 `AIProviderProbeResultPanelSheet`、regular width `presentationSizing(.fitted)` 和组件层 `fixedSize`。
- 2026-05-25：实现 `AIProviderProbeResultPanelSheet`，将结果面板宽度和垂直理想尺寸约束移入组件层；`AIProviderSettingsView` 改为装配该容器，并在 iPad regular width 使用 `presentationSizing(.fitted)`。
- 2026-05-25：重新运行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`，17 个测试通过。
- 2026-05-25：运行 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`，iPad target build 成功。
- 2026-05-25：运行 `git diff --check`，通过。
- 2026-05-25：运行 `scripts/verify.sh`，退出码 0；验证覆盖 XcodeGen 生成、项目列表、Core / Data / AI / Speech / Sync / UI package tests、Python unittest、iPhone / iPad / macOS build、macOS app tests、SwiftLint、SwiftFormat 和文档占位扫描。SwiftLint 输出仍包含既有 warning，未出现 serious violation；SwiftFormat 输出 `0/213 files require formatting`。
- 2026-05-25：按用户要求复查 diff 和运行边界，确认本次改动只涉及 AI Provider 测试结果 sheet presentation、相关 UI 测试和本方案；未新增 `URLSession`、`Authorization`、`Bearer` 或新的 Keychain 访问边界。
- 2026-05-25：使用干净临时 DerivedData 重新构建 iPad 版本：`rm -rf /tmp/langotrace-ipad-deriveddata && xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,id=73045FC7-A9FB-4F41-892E-3CE9755D2ECB' -derivedDataPath /tmp/langotrace-ipad-deriveddata build`，构建成功。
- 2026-05-25：重启 `iPad Pro 13-inch (M5)` 模拟器，安装 `/tmp/langotrace-ipad-deriveddata/Build/Products/Debug-iphonesimulator/LangoTrace.app` 并启动 `com.zibuyu.LangoTrace`，`simctl launch` 返回 PID `99557`；截图保存到 `/tmp/langotrace-ipad-after-restart.png`，画面显示 App 已启动到 Welcome 页面。
- 2026-05-25：根据用户截图反馈继续加宽面板，将 iPad regular width 的测试结果面板从 520pt 加大一半到 780pt；实现方式改为 `AIProviderProbeResultPanelSheet` 接收 `usesRegularWidth`，仅 iPad regular width 使用固定 780pt，compact width 不套固定宽，避免 iPhone / Slide Over 溢出。
- 2026-05-25：更新回归测试后先运行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`，测试按预期失败，随后修正实现并重新运行，17 个 AI Provider probe 测试通过。
- 2026-05-25：重新运行 `rm -rf /tmp/langotrace-ipad-deriveddata && xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,id=73045FC7-A9FB-4F41-892E-3CE9755D2ECB' -derivedDataPath /tmp/langotrace-ipad-deriveddata build`，构建成功；重启 iPad 模拟器并安装启动新包，`simctl launch` 返回 PID `1434`；截图保存到 `/tmp/langotrace-ipad-after-width-780.png`。
- 2026-05-25：根据用户二次截图反馈，将 iPad regular width 的固定面板宽度从 780pt 收敛为其三分之二，即 520pt；继续保留固定 `width` 而非 `maxWidth`，避免回到内容自身收缩导致的过窄问题，compact width 不受此常量影响。
- 2026-05-25：先更新回归测试期望为 520pt 并运行 `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`，测试按预期失败于组件常量仍为 780pt；随后修正实现并重新运行，17 个 AI Provider probe 测试通过。
- 2026-05-25：重新运行 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,id=73045FC7-A9FB-4F41-892E-3CE9755D2ECB' -derivedDataPath /tmp/langotrace-ipad-deriveddata build`，构建成功；重启 iPad 模拟器并安装启动新包，`simctl launch` 返回 PID `2257`；截图保存到 `/tmp/langotrace-ipad-after-width-520.png`。
- 2026-05-25：任务收口前将方案从 `docs/plans/active/` 移入 `docs/plans/done/`，状态更新为 `Verified`；重新运行 `scripts/verify.sh`，退出码 0，覆盖 XcodeGen、项目列表、Core / Data / AI / Speech / Sync / UI package tests、Python unittest、iPhone / iPad / macOS build、macOS app tests、SwiftLint、SwiftFormat 和文档占位扫描。SwiftLint 仍报告既有 warning，`serious` 为 0；SwiftFormat 输出 `0/213 files require formatting`。

## 完成标准

- iPad AI Provider 测试结果 sheet 顶部无明显大空白。
- 结果面板保持 Apple 风格状态反馈：克制 handle、中性标题、右上关闭、grouped capability card。
- iPhone compact sheet 行为未回退。
- AI Provider 请求、Keychain、GRDB 和诊断日志边界未改变。
- 聚焦 UI 测试通过。
- iPad target build 通过。
- `git diff --check` 通过。
- `scripts/verify.sh` 通过，或记录无法运行的具体原因和剩余风险。

## 剩余风险

- `presentationSizing(.fitted)` 的实际视觉效果依赖 iPadOS sheet presentation 行为；如果系统仍保留不可接受的 top inset，需要补充截图证据后改用更明确的 sizing 或自定义 overlay。
- 源代码结构测试能防止关键 API 被移除，但不能替代真实 iPad 截图验证。
- Dynamic Type 极大字号下，fitted sheet 可能需要滚动容器；当前任务先覆盖截图中的常规字号和 4-6 个能力结果行。
- 本次未使用真实 Provider 凭证在模拟器内点击完整测试请求流程截图验证，避免处理用户截图中的敏感 API Key；已通过源结构测试和 iPad target build 验证实现路径。
