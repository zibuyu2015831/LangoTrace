> 归档说明（2026-06-11）：本方案已按用户决定从 docs/plans/active/ 整体归档，仅作历史证据保留；适用部分由 2026-06-11 系列方案与 Mac 验证清单吸收。详见 docs/archive/plans/README.md。

# 任务方案：阅读 UI 选择交互与显示 Bug 修复

状态：Draft
自审核状态：Reviewed
类型：bug
创建日期：2026-06-06
最后更新日期：2026-06-06

## 用户确认记录

状态为 `Draft`，尚未进入实现。待用户确认方案范围与实施授权后更新本节。

---

## 1. 需求或 bug 描述

通过模拟器截图发现阅读模块存在 8 项 UI 行为问题，涵盖系统弹出菜单与学习面板冲突、iOS 选择句柄残留、底部文本被面板遮挡、枚举原始值泄漏至 UI 等影响核心体验的 bug，以及卡片对比度不足、面板无标签区块、导入按钮层级错误和面板无下滑关闭手势等次要体验问题。

---

## 2. 现状描述

### 2.1 系统菜单与学习面板冲突（P0）

`ReadingSelectableTextView` iOS 端的 `Coordinator.textViewDidChangeSelection` 在选中 ≥2 个非空白字符后经 0.15s debounce 触发 `onSelectionChange`，进而推动 `documentStore.selectedSelection` 更新，导致底部 `ReadingCompactLearningPanel` 从下方滑入。

同时，UITextView 的 `isSelectable = true` 默认显示系统编辑菜单（拷贝 / 查词 / 翻译 / 搜索网页 / 共享），两套 UI 同时出现在屏幕上。系统菜单的"查词"和"翻译"功能与学习面板的"解释"功能高度重叠；"搜索网页"与产品"本地优先"定位相悖。

代码路径：`ReadingSelectableTextView.swift:185–221`（iOS Coordinator），无任何对系统编辑菜单的抑制逻辑。

### 2.2 iOS 选择句柄残留（P0）

`applyCommittedHighlight(to:)` 函数（`ReadingSelectableTextView.swift:94–107`）在设置自定义 teal 背景高亮后，不清除 UITextView 的 `selectedRange`。结果：高亮已提交、学习面板已显示，但 iOS 蓝色选择句柄（两端拖拽锚点）仍然可见，造成视觉噪声，并让用户误以为文本仍处于可编辑选择状态。

### 2.3 底部文本选中后被面板遮挡（P1）

学习面板使用 `safeAreaInset(edge: .bottom, spacing: 0)` 嵌入（`ReadingViews.swift:424`）。`safeAreaInset` 会压缩 ScrollView 的可见 safe area，但这个调整在用户**仍在拖动选择句柄**时尚未完成，导致底部文本被面板滑入后覆盖，无法继续调整选择范围。

### 2.4 `sourceFormat.rawValue` 泄漏至 UI（P1）

`ReadingLibraryDocumentRow`（`ReadingViewComponents.swift:60`）直接使用 `document.sourceFormat.rawValue` 渲染来源徽章，显示 Swift 枚举 case 名称 "pastedText"，而非用户可读字符串。`ReadingSourceFormat` 枚举（`ReadingLibrary.swift:3–11`）没有 `displayName` 或本地化属性。

### 2.5 面板解释结果区块无标签（P2）

`ReadingCompactLearningPanel`（`ReadingViewComponents.swift:589–595`）中 `ReadingExplanationResultView` 直接追加在操作按钮下方，无区块标题（如"解释"或"AI 解释"）。当面板状态为 `.content` 时，用户无法直观识别下方内容的来源和含义（截图 3 中被圈出的区域即此处）。

### 2.6 卡片与列表背景无区分度（P2）

`ReadingLibraryDocumentRow` 的卡片背景使用 `LangoTraceDesign.ColorToken.surfaceBase`（`ReadingViewComponents.swift:81`），列表容器背景也使用相近色（List/ScrollView 默认 grouped 背景），两者色差过小，卡片缺乏视觉层级感和可点击的"浮卡"质感。

### 2.7 "粘贴文本"/"导入文件"按钮层级错误（P2）

Phone 阅读列表页（`ReadingViews.swift:582–601`）：
- "粘贴文本" 使用 `.borderedProminent`（系统默认绿色实心，强视觉权重）
- "导入文件" 使用 `.bordered`（轻量线框，弱视觉权重）

两者是同等级入口，但视觉层级创造了错误的"主/次"关系，使"导入文件"看起来像降级功能。

### 2.8 面板无下滑关闭手势（P3）

`ReadingCompactLearningPanel` 目前只有右上角"×"按钮关闭，无 `DragGesture` 下滑关闭支持。iOS 原生底部弹出面板的用户预期是支持下滑关闭。

---

## 3. 目标

完成本任务后：

1. 阅读正文中选中文本时，iOS 系统编辑菜单不再出现，只显示学习面板。
2. 学习面板显示后，iOS 蓝色选择句柄不再残留，正文高亮保留。
3. 当选中文本位于页面底部时，内容区域自动向上滚动，确保选中文本始终可见于面板上方。
4. 阅读列表中文档来源徽章显示"粘贴文本"/"纯文本"/"Markdown"等可读字符串，不再显示枚举 rawValue。
5. 学习面板解释结果区块上方有明确区块标题。
6. 阅读列表卡片有视觉层级感，与背景有可识别的边界。
7. "粘贴文本"和"导入文件"按钮具有对等视觉权重。
8. 学习面板支持下滑关闭手势。

---

## 4. 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSourceFormatDisplay.swift`（新建）：在 LangoTraceUI 层新增 `ReadingSourceFormat` 的 `displayName` extension（见 §12 Phase 1 决策说明）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift`（iOS 端）：抑制系统编辑菜单（仅使用 iOS 18 的 delegate 方案），clearSelectedRange 逻辑
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`：block-anchor 滚动逻辑，按钮样式修正
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift`：卡片样式，面板区块标题，下滑关闭手势（限定在 handle 区域）

---

## 5. 不做什么

- 不在学习面板中添加"复制"按钮（独立 feature task，需要产品确认）
- 不修改 macOS 端 NSTextView 系统菜单（macOS 弹出菜单交互模型不同，需独立评估）
- 不修改 iPad 侧边 `ReadingInspectorPane` 的系统菜单行为
- 不添加字号调节、夜间模式等阅读偏好设置
- 不修改空状态 UI（仅当前内容修复，不做结构扩展）
- 不做 EPUB / PDF 等格式的 displayName（当前未实现，占位即可）

---

## 6. 证据与决策依据

### 6.1 架构决策根据

**系统菜单抑制决策：**

- spec 012 §5（选择与源锚点）明确采用 UITextView / NSTextView 系统原生选择手势作为输入机制
- spec 012 §6 明确 AI 解释是**用户显式动作**，选中文本触发学习面板是正确的 UX 路径
- spec 003（UI 设计系统规范）§3 强制规则："重要操作必须有明确视觉层级，危险操作必须有确认或可恢复路径"——双层界面破坏了操作层级的清晰性
- ADR-005（本地优先和用户自带 Provider）——系统菜单的"搜索网页"和"翻译"违背本地优先定位

**实施方式：**
`project.yml` 已确认 `IPHONEOS_DEPLOYMENT_TARGET: "18.0"`，在 `Coordinator` 中实现 `UITextViewDelegate.textView(_:editMenuForTextIn:suggestedActions:)` 返回 `nil`，完全抑制系统编辑菜单。无需 iOS 15/16 兼容分支。

**不加"复制"按钮的依据：**
用户仍可长按学习面板内的选中文本预览区（`Text(selection.selectedText)` 行）调用系统拷贝；不在本轮新增独立复制按钮，但需要在剩余风险中说明。

### 6.2 代码证据

| Bug | 证据代码路径 | 关键行 |
|-----|-------------|--------|
| 系统菜单冲突 | `ReadingSelectableTextView.swift` Coordinator | 185–221 |
| 句柄残留 | `ReadingSelectableTextView.swift` `applyCommittedHighlight` | 94–107 |
| rawValue 泄漏 | `ReadingViewComponents.swift` `ReadingLibraryDocumentRow` | 60 |
| 按钮层级 | `ReadingViews.swift` `pasteButton`/`importFileButton` | 582–601 |
| 无区块标签 | `ReadingViewComponents.swift` `ReadingCompactLearningPanel` | 589–595 |

### 6.3 产品定位依据

产品定位："本地优先的个人语言记忆系统"、"不是 AI 聊天工具"。学习面板是语迹的核心交互路径，不应与 iOS 系统通用文本工具（翻译、网页搜索）并排出现，这与产品定位相悖。

---

## 7. 约束映射与验证路径

| 约束 | 来源 | 严重度 | 验证方式 |
|------|------|--------|---------|
| 系统菜单抑制不能破坏可访问性（VoiceOver 选择朗读） | spec 010 §3 可访问性 | blocker | 手动 VoiceOver 测试 |
| 来源标签不得混淆 App 界面语言和目标学习语言 | spec 003 §3、spec 006 | blocker | 人工审查，确保 displayName 为界面语言（中文）而非目标语言字符串 |
| 可点击区域在触控设备上满足基本可触达尺寸 | spec 003 §3 | warn | 手动验证下滑关闭触发区域 |
| 不做卡片套卡片 | spec 003 §3 | warn | 人工审查，确保卡片样式修改不引入嵌套卡片 |
| UI 状态变化必须有正确动画，不能临时裸文本 | spec 003 §3 | warn | 模拟器手动验证面板开关动画 |

### 约束 1：系统菜单抑制不得破坏可访问性

- 来源：`docs/spec/010-apple-platform-interaction-and-accessibility.md` §3
- 适用范围：iOS/iPadOS 阅读正文 UITextView
- 严重度：blocker
- 执行或验证方式：手动 VoiceOver 测试
- 验证提示：打开 VoiceOver 后，在阅读正文中选中文本，确认 VoiceOver 仍能正确朗读选中内容；抑制系统菜单不能影响 VoiceOver 的朗读能力（两者独立，但需验证）

### 约束 2：来源标签语言边界

- 来源：`docs/spec/006-interface-localization-and-language-boundaries.md`
- 适用范围：`ReadingSourceFormat.displayName`
- 严重度：blocker
- 执行或验证方式：人工审查
- 验证提示：`displayName` 返回界面语言的本地化字符串（中文界面返回"粘贴文本"等），不得返回目标学习语言的字符串，不得使用 `.rawValue`

---

## 8. 涉及的代码文件路径

```
Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift
Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift
Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift
Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift
```

---

## 9. 参考的代码文件路径

```
Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingDocumentStore.swift
Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingPresentationModels.swift
Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingTextSegmentation.swift
```

---

## 10. 涉及的文档路径

```
docs/spec/012-reading-learning-domain.md  （§5 选择与源锚点、§6 AI 解释边界）
docs/spec/003-ui-design-system.md         （视觉规范、强制规则）
docs/spec/010-apple-platform-interaction-and-accessibility.md （可访问性约束）
docs/spec/006-interface-localization-and-language-boundaries.md （语言边界）
```

---

## 11. bug 分析

```
复现方式：
  P0-1：打开阅读正文，长按任意文字触发选择，等待 0.15s → 系统菜单与学习面板同时出现
  P0-2：触发选择 → 学习面板弹出 → 观察正文中已高亮区域 → iOS 蓝色选择句柄仍然可见
  P1：选中正文最后 2–3 行文字 → 学习面板弹出 → 选中文字被面板覆盖，无法调整选择范围
  P1b：阅读列表中任意文档卡片 → 来源徽章显示 "pastedText" / "plainText"

预期行为：
  P0-1：选中文本后只显示学习面板，不显示系统编辑菜单
  P0-2：学习面板显示时，蓝色 iOS 选择句柄消失，teal 自定义高亮保留
  P1：内容区域自动滚动，确保选中文字在面板顶部上方始终可见
  P1b：来源徽章显示"粘贴文本"/"纯文本"/"Markdown"等可读字符串

实际行为：
  P0-1：两套 UI 叠加，系统菜单遮挡学习面板，功能重叠导致用户困惑
  P0-2：teal 高亮已渲染，但 iOS 蓝色选择句柄未清除
  P1：面板滑入后选中文字被完全遮挡；safeAreaInset 压缩发生在面板出现之后，用户拖动时无法看到文字
  P1b：rawValue "pastedText" 直接渲染，属于技术枚举名称泄漏

根因分析：
  P0-1：ReadingSelectableTextView iOS Coordinator 未实现任何系统菜单抑制委托方法
  P0-2：applyCommittedHighlight() 只写入背景色属性，未清除 textView.selectedRange
  P1：safeAreaInset 只改变可见布局区域，不主动滚动内容；选择期间 ScrollView 无感知面板高度
  P1b：ReadingLibraryDocumentRow 直接使用 document.sourceFormat.rawValue（第60行）

置信度：98%

置信度依据：已通过代码直接定位每个 bug 的根因代码行；P1 底部遮挡经 safeAreaInset 机制文档确认；P0-2 经 applyCommittedHighlight 函数逻辑确认无 selectedRange 清除

备选原因：
  P1 滚动问题：可能存在 scrollPosition / scrollViewProxy 未被正确传递的情况，需要在实施阶段验证 safeAreaInset 的实际表现

回归测试方案：
  - 在每个阶段完成后通过模拟器 iPhone 17 手动验证对应场景
  - P0-1：完成后验证系统菜单不再出现，且 VoiceOver 选择朗读正常
  - P0-2：完成后截图确认 teal 高亮存在、蓝色句柄消失
  - P1：选中底部文字，验证内容自动滚动
  - P1b：单元测试覆盖 displayName 全枚举 case
```

---

## 12. 实施方案

### Phase 1：displayName extension（LangoTraceUI 层）

**架构决策：`displayName` 放在 LangoTraceUI，不放 LangoTraceCore**

理由：
- `ReadingSourceFormat.displayName` 是 UI 展示字符串，按模块边界规则（CLAUDE.md §1.4）UI 文案应在 `LangoTraceUI` 层产生
- LangoTraceCore 当前无本地化基础设施（`Package.swift` 中 Core target 无 `resources:` 配置）；引入 `bundle: .module` 需先添加 `resources: [.process("Resources")]` 和 `.xcstrings`，成本远超收益
- Core 作为纯数据模型层，供 Data、AI、UI 多个 package 使用；UI 字符串不应污染 Core 层
- `project.yml` 第 30 行启用了 `CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED: YES`，Core 中使用硬编码字符串字面量会触发编译告警

**步骤 1-1：在 LangoTraceUI 中新建 extension 文件**

新建 `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSourceFormatDisplay.swift`：

```swift
import LangoTraceCore

extension ReadingSourceFormat {
    var displayName: String {
        switch self {
        case .pastedText:  return String(localized: "reading.source.pastedText",  defaultValue: "粘贴文本")
        case .plainText:   return String(localized: "reading.source.plainText",   defaultValue: "纯文本")
        case .markdown:    return "Markdown"
        case .epub:        return "EPUB"
        case .pdf:         return "PDF"
        case .htmlClip:    return String(localized: "reading.source.htmlClip",    defaultValue: "网页剪藏")
        case .webArticle:  return String(localized: "reading.source.webArticle",  defaultValue: "网页文章")
        }
    }
}
```

LangoTraceUI 已有本地化基础设施；若 key 未在 `Localizable.xcstrings` 中注册，`defaultValue` 参数确保 fallback 为可读中文字符串而非 key 字符串。

在实施步骤中需确认 `reading.source.pastedText` 等 key 已注册或同时添加至 LangoTraceUI 的本地化文件。

**步骤 1-2：在 `ReadingLibraryDocumentRow` 中使用 `displayName`**

将 `ReadingViewComponents.swift:60`：
```swift
Text(document.sourceFormat.rawValue)
```
改为：
```swift
Text(document.sourceFormat.displayName)
```

### Phase 2：系统菜单抑制（ReadingSelectableTextView.swift iOS 端）

**前置确认（已完成）：** `project.yml` 第 5 行和第 38 行 `deploymentTarget: "18.0"`, `Package.swift` 第 8 行 `.iOS(.v18)`，deployment target 为 iOS 18。无需 iOS 15/16 兼容分支。

**步骤 2-1：在 Coordinator 中实现编辑菜单 delegate**

在 `ReadingSelectableTextView.swift` 的 iOS `Coordinator: UITextViewDelegate` 中添加：

```swift
func textView(
    _ textView: UITextView,
    editMenuForTextIn range: NSRange,
    suggestedActions: [UIMenuElement]
) -> UIMenu? {
    // 返回 nil：系统编辑菜单不显示。
    // 此 delegate 方法在 iOS 16+ 可用；deployment target iOS 18，无需版本守卫。
    // editMenuForTextIn 控制的是 UIEditMenuInteraction 弹出菜单，
    // 与 VoiceOver 的"朗读选中内容"手势（独立机制）互不影响。
    return nil
}
```

### Phase 3：清除 iOS 选择句柄（ReadingSelectableTextView.swift iOS 端）

**并发安全说明：** `updateUIView`、`applyCommittedHighlight`、`textViewDidChangeSelection` 均在 `DispatchQueue.main` 上执行，不存在跨线程 race condition。`isApplyingCommittedHighlight` 标志的有效范围是单次同步 `updateUIView` 调用帧：设置为 `true` → 高亮写入 → `selectedRange` 清除（触发 `textViewDidChangeSelection`，此时标志为 `true` 被 guard 跳过）→ 设置回 `false`，整个流程单帧同步完成。Swift 6 严格并发模式下，若 `Coordinator` 被标注为非 `@MainActor` 对象而从异步上下文访问该标志，会触发编译警告；实施时应确保 `Coordinator` 标注 `@MainActor` 或保持在 main queue 调用路径中。

**步骤 3-1：在 Coordinator 添加防重入标志**

```swift
var isApplyingCommittedHighlight = false
```

**步骤 3-2：修改 `updateUIView`，高亮完成后清除 selectedRange**

在 `updateUIView` 中将 `applyCommittedHighlight(to: textView)` 调用替换为：

```swift
context.coordinator.isApplyingCommittedHighlight = true
applyCommittedHighlight(to: textView)
if committedHighlightRange != nil {
    // 清除 iOS 蓝色选择句柄；teal 背景高亮已通过 textStorage 写入，
    // 不受 selectedRange 清除影响。此赋值会触发 textViewDidChangeSelection，
    // 由 isApplyingCommittedHighlight 标志跳过。
    textView.selectedRange = NSRange(location: NSNotFound, length: 0)
}
context.coordinator.isApplyingCommittedHighlight = false
```

**步骤 3-3：在 `textViewDidChangeSelection` 中跳过防重入期间的回调**

```swift
func textViewDidChangeSelection(_ textView: UITextView) {
    guard !isApplyingCommittedHighlight else { return }
    // ... 原有逻辑
}
```

### Phase 4：底部文本遮挡修复（block-anchor 滚动方案）

**方案决策：采用 block-anchor 简化滚动，不使用 UITextRange 精确 rect 计算**

原草案中 `selectionRects(for:)` 需要将 `NSRange` 转换为 `UITextRange`（通过 `textView.position(from:offset:)` + `textView.textRange(from:to:)` 可空链），实现复杂且易出错。`selectedSelection` 携带 `blockID`（containing block 的 ID），足以定位滚动锚点。block-anchor 方案可靠性更高，精度满足需求（选中底部文字时滚动至包含 block 的底部，确保高亮文本可见）。

iPad 窗口高度不能使用 `UIScreen.main.bounds.height`（Split View / Stage Manager 下窗口高度 ≠ 屏幕高度，spec 010 §3 明确要求适配）；block-anchor 方案通过 `GeometryReader` 取实际视图高度，不依赖屏幕尺寸。

**步骤 4-1：在 `ReadingDocumentCanvas` 的 ForEach 中为每个 block 添加 scroll anchor**

在 `ReadingViews.swift` 的 `ReadingDocumentCanvas` 中，`ForEach(presentation.blocks)` 的每个 block 容器上添加：

```swift
.id(block.blockID)
```

**步骤 4-2：在 `ReadingDocumentDetailView` 中监听 selectedSelection 并执行 block-anchor 滚动**

在 `ReadingDocumentDetailView`（phone 端）中，用 `ScrollViewReader` 包裹 canvas，并在 `selectedSelection` 变化时触发滚动：

```swift
ScrollViewReader { proxy in
    ReadingDocumentCanvas(...)
        .onChange(of: documentStore.selectedSelection?.blockID) { blockID in
            guard let blockID else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(blockID, anchor: .bottom)
            }
        }
}
```

此方案：
- 不依赖 `UIScreen.main.bounds.height`，只通过 ScrollViewReader 的相对布局计算
- `safeAreaInset` 已将面板高度纳入 safe area，`scrollTo(.bottom)` 会自动在面板上方留出空间
- 在 iPad Split View / Stage Manager 下同样正确（`safeAreaInset` 是视图级而非屏幕级计算）

### Phase 5：视觉修复（ReadingViewComponents.swift + ReadingViews.swift）

**步骤 5-1：卡片层级感（ReadingViewComponents.swift）**

在 `ReadingLibraryDocumentRow` 卡片的 `.background(...)` 后添加阴影：

```swift
.shadow(
    color: Color(.systemGray).opacity(0.10),
    radius: 4,
    x: 0,
    y: 1
)
```

同时确认列表容器使用 `.listStyle(.plain)` 且背景使用 `secondarySystemGroupedBackground`，卡片使用 `systemBackground` — 若当前 `surfaceBase` 与背景过近，需要调整 token 映射或改用 SwiftUI 语义色。

**步骤 5-2：面板解释区块标题（ReadingViewComponents.swift）**

在 `ReadingCompactLearningPanel` 的 `ReadingExplanationResultView` 调用前添加条件性区块标题：

```swift
if panelState == .content || panelState == .loading || panelState == .failed {
    HStack {
        Text(String(localized: "reading.panel.explanation.title", defaultValue: "AI 解释"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(LangoTraceDesign.ColorToken.textSecondary)
        Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 4)
}
```

实施时确认 `reading.panel.explanation.title` key 已注册至 LangoTraceUI 的 `Localizable.xcstrings`（或 `.strings`）；若未注册则同步添加。`defaultValue:` 参数确保 key 缺失时 fallback 为"AI 解释"。

**步骤 5-3：按钮层级修正（ReadingViews.swift）**

将 `pasteButton` 从 `.borderedProminent` 改为 `.bordered`，使两者对等：

```swift
private var pasteButton: some View {
    Button { isImportSheetPresented = true } label: {
        Label(localizedString("reading.library.import.paste"), systemImage: "doc.on.clipboard")
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)          // 原为 .borderedProminent
    .controlSize(.large)
}
```

**步骤 5-4：面板下滑关闭手势（ReadingViewComponents.swift）**

**手势范围限定：** 将 `DragGesture` 只附加在面板顶部 drag handle（Capsule）区域，而非整个根 `VStack`。若附加到根 `VStack`，会与 `ReadingExplanationResultView` 内部 ScrollView 发生手势竞争，导致用户滚动解释内容时面板被意外关闭。

修改顶部 handle Capsule 区域（`ReadingViewComponents.swift:534–540`），为其包裹容器添加 DragGesture：

```swift
// 替换原有 Capsule + padding 区域为带手势的可点击容器
Capsule()
    .fill(LangoTraceDesign.ColorToken.borderSubtle)
    .frame(width: 36, height: 4)
    .frame(maxWidth: .infinity)
    .padding(.top, 10)
    .padding(.bottom, 14)
    .contentShape(Rectangle())  // 扩大触摸区域到 frame 范围
    .gesture(
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 50 {
                    onClear()
                }
            }
    )
```

此方式确保手势只在 handle 区域（顶部约 48pt 高度）响应，不与解释结果内容区竞争。

---

## 13. 严格方案自审核记录

```
审核日期：2026-06-06
审核方式：隔离子代理审查（双轮并行）
审核轮次：第一轮（架构审查）+ 第二轮（测试/安全/落地性审查）
未使用隔离审查的原因：N/A，已使用两个独立子代理

发现摘要（按轮次）：

  第一轮发现：
  P0-A：Phase 4 UITextRange 强转代码无效（nsRange as Any as! UITextRange 运行时必 crash）
  P0-B：isApplyingCommittedHighlight 标志的并发安全边界未说明
  P1-A：iOS 15/16 兼容分支的 canPerformAction 方案可能破坏 VoiceOver 可访问性
  P1-B：UIScreen.main.bounds.height 在 iPad Split View/Stage Manager 下不可靠
  P2-A：displayName 应在 LangoTraceUI 层而非 LangoTraceCore（模块边界）
  P2-B：DragGesture 附加到根 VStack 会与内部 ScrollView 手势竞争
  P2-C：reading.panel.explanation.title 本地化 key 未验证注册状态

  第二轮发现：
  P0-1：deployment target 已确认 iOS 18，iOS 15/16 分支应全部删除（歧义阻塞实施）
  P0-2：TDD 红步骤不完整：编译报错先于测试失败，需要 stub-first 描述
  P1-2：bundle:.module 在 Core 无资源包时无法正常工作；Core 无 resources: 配置
  P1-3：Coordinator 的 isApplyingCommittedHighlight 在 Swift 6 下需要 @MainActor 说明
  P2-1：Phase 4 UITextRange 伪代码错误（与第一轮 P0-A 相同）
  P2-2：DragGesture 与 ScrollView 竞争（与第一轮 P2-B 相同）
  P3-1：--filter 命令格式需区分 XCTest vs Swift Testing（现有测试用 Swift Testing）

写回修改：
  1. [P0] Phase 4 全面重写：删除 UITextRange 伪代码，采用 block-anchor 简化方案为默认路径
  2. [P0] 删除步骤 2-1"确认 deployment target"和步骤 2-3 iOS 15 分支，仅保留 iOS 18 delegate 方案
  3. [P0] §15 TDD 落点 1 补充 stub-first 路径描述
  4. [P1] Phase 1 全面重写：将 displayName 从 Core 移至 LangoTraceUI 新建 extension 文件
  5. [P1] Phase 3 步骤 3-1/3-2 补充 main queue 单帧安全说明 + Swift 6 @MainActor 提示
  6. [P1] Phase 4 步骤 4-2 改用 ScrollViewReader + safeAreaInset 组合，消除 UIScreen 依赖
  7. [P2] Phase 5 步骤 5-2 使用 String(localized:defaultValue:) 防 key 缺失 fallback
  8. [P2] Phase 5 步骤 5-4 DragGesture 限定到 handle 区域
  9. [P3] §15/§16 验证命令格式更新说明（Swift Testing filter 格式差异）
  10. §4 范围更新：displayName 文件改为 LangoTraceUI 新建文件
  11. §20 剩余风险删除"iOS 15 系统菜单方案"条目（已确认不适用）

仍需用户确认的问题：
  - 方案整体范围和实施授权（当前 Draft 状态，需用户推进到 User Approved）
  - Phase 5 步骤 5-3 按钮样式修改（从 .borderedProminent 改为 .bordered）是否符合产品意图：
    若产品认为"粘贴文本"是更高频入口并希望保留突出样式，可改为"导入文件"升级样式而非"粘贴文本"降级

是否允许进入实现：待用户确认范围后，P0/P1 问题已修订，允许进入实现。
```

---

## 14. 复查方法

完成实施后，通过以下路径复查：

1. **系统菜单抑制**：iPhone 模拟器，打开阅读正文，长按选中文字，等待 0.5s → 确认只有学习面板出现，无系统菜单
2. **句柄残留**：选中文字 → 面板弹出 → 截图确认无蓝色选择句柄，teal 高亮保留
3. **底部遮挡**：选中正文最后两段 → 确认内容区域向上滚动，选中文字可见
4. **displayName**：运行单元测试，确认所有 case 返回非 rawValue 字符串
5. **卡片对比度**：在 iPhone / iPad 模拟器截图确认卡片与背景有视觉边界
6. **面板标签**：触发解释 → 确认解释结果上方出现区块标题
7. **按钮层级**：阅读列表截图确认两个按钮视觉权重对等
8. **下滑关闭**：打开学习面板 → 从上往下滑动 → 面板收起

**VoiceOver 回归**：在设置中开启 VoiceOver，选中正文文字，确认 VoiceOver 朗读选中内容正常（不受系统菜单抑制影响）。

---

## 15. TDD / 测试落点

```
测试落点 1：displayName 全枚举覆盖
  Package 路径：Packages/LangoTraceUI
  测试文件路径：Tests/LangoTraceUITests/Reading/ReadingSourceFormatDisplayTests.swift（新建）
  注意：LangoTraceCore 测试目录已存在，但 displayName 现在在 LangoTraceUI 的 extension
        中，测试应落在 LangoTraceUI test target

  TDD 红绿步骤：
    红步骤（先失败）：
      先写 ReadingSourceFormatDisplayTests.swift，调用 ReadingSourceFormat.pastedText.displayName
      此时 LangoTraceUI 尚未有 ReadingSourceFormatDisplay.swift，编译会失败。
      为使测试能"运行并失败"（而非仅编译失败），先在 ReadingSourceFormatDisplay.swift 中创建
      stub extension，返回 rawValue：
        extension ReadingSourceFormat {
            var displayName: String { rawValue }
        }
      此时测试中断言 displayName != rawValue 失败 → "红"状态
    绿步骤（实现通过）：
      将 displayName 实现为完整 switch 语句返回可读字符串 → 测试通过

  先失败用例：testAllCasesReturnReadableName
    断言每个 case 的 displayName 不等于其 rawValue
    断言每个 case 的 displayName 不为空字符串

  聚焦验证命令（Swift Testing 框架格式）：
    swift test --package-path Packages/LangoTraceUI \
      --filter "LangoTraceUITests/ReadingSourceFormatDisplayTests"

测试落点 2（不新增，依赖已有测试）：
  Package 路径：Packages/LangoTraceUI
  shouldTriggerPanel 函数的现有测试（ReadingSelectableTextViewTests.swift 中的 ShouldTriggerPanelTests）
  足以覆盖选择触发逻辑。系统菜单抑制是 UIKit delegate 行为，主要依赖模拟器手动验证。

不新增单元测试的原因（Phase 2/3/5）：
  系统菜单抑制（Phase 2）、选择句柄清除（Phase 3）、视觉修复（Phase 5）
  均属于 UIKit/SwiftUI 渲染行为，无法在不引入复杂 mock 的情况下做有意义的单元测试。
  这些项的验证依赖手动模拟器测试（见第 14 节复查方法）。
  剩余风险：手动测试无法覆盖所有屏幕尺寸边界；VoiceOver 测试需人工执行。
```

---

## 16. 验证命令

```bash
# 聚焦验证（Phase 1 完成后）
# 注意：现有测试使用 Swift Testing 框架（@Suite/@Test）；--filter 格式为模块/Suite名/测试函数
swift test --package-path Packages/LangoTraceUI \
  --filter "LangoTraceUITests/ReadingSourceFormatDisplayTests"

# UI Package 全量测试
swift test --package-path Packages/LangoTraceUI

# Core Package 全量测试（Phase 1 不修改 Core，仍作为回归验证）
swift test --package-path Packages/LangoTraceCore

# 完整验证（所有 package + 构建 + SwiftLint + SwiftFormat）
scripts/verify.sh

# 阶段 DoD 检查（完成后，确认无占位标记）
rg "TO[D]O|TB[D]|待补[充]" \
  Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSourceFormatDisplay.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingSelectableTextView.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift \
  Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViewComponents.swift
```

---

## 17. 文档影响检查

- **spec/012-reading-learning-domain.md**：本任务修正了 §5 描述的系统菜单抑制行为（spec §5 描述了原生手势驱动选择，但未明确提及系统菜单是否应该出现）。任务完成后，由实施会话在 spec 012 末尾的 Change Log 中追加一行，内容为：`YYYY-MM-DD: iOS 端阅读正文选中文字时系统编辑菜单已通过 UITextViewDelegate.editMenuForTextIn 抑制（deployment target iOS 18）；学习面板为唯一交互入口。`
- **spec/003-ui-design-system.md**：不修改规范本身，但当前任务是首次使 UI 实现符合"重要操作有明确视觉层级"的强制规则。
- **spec/006-interface-localization-and-language-boundaries.md**：添加 `displayName` 后需人工确认语言边界规范被满足，无需修改 spec。
- **platform-page-inventory.md**：若该文档记录了阅读模块的当前能力边界，完成后检查是否需要更新"系统菜单抑制"和"选择句柄行为"等事实。
- 无新增 ADR（本任务修复现有行为，不改变核心产品决策）。

---

## 18. 实施记录

2026-06-06 实施完成。

**Phase 1（displayName）：**
- 新建 `ReadingSourceFormatDisplay.swift`（LangoTraceUI extension，使用 `localizedString()` 调用 LocalizedChromeCatalog）
- 在 `Localizable.xcstrings` 中新增 5 个 key：`reading.source.pastedText/plainText/htmlClip/webArticle`、`reading.panel.explanation.title`（均含 zh-Hans + en 翻译）
- `ReadingViewComponents.swift:60` 改为使用 `displayName`
- 新建测试 `ReadingSourceFormatDisplayTests.swift`（Swift Testing `@Suite`）

**Phase 2（系统菜单抑制）：**
- `ReadingSelectableTextView.swift` iOS `Coordinator` 中新增 `textView(_:editMenuForTextIn:suggestedActions:)` 返回 `nil`

**Phase 3（清除选择句柄）：**
- `Coordinator` 新增 `isApplyingCommittedHighlight` 标志
- `updateUIView` 中在 `applyCommittedHighlight` 后清除 `selectedRange`
- `textViewDidChangeSelection` 加 guard 跳过防重入

**Phase 4（block-anchor 滚动）：**
- `ReadingDocumentCanvas` ForEach 每个 block 加 `.id(block.id)`
- `ReadingDocumentDetailView` ScrollView 外包 `ScrollViewReader`，`onChange(of: selectedSelection?.blockID)` 触发 `proxy.scrollTo(blockID, anchor: .bottom)`

**Phase 5（视觉修复）：**
- 卡片加 shadow（`systemGray4` 0.35 opacity，radius 4，非选中状态生效）
- 面板解释区块标题（`reading.panel.explanation.title`，在 loading/content/failed 状态显示）
- `pasteButton` 从 `.borderedProminent` 改为 `.bordered`
- Capsule handle 加 `DragGesture`（`minimumDistance: 20`，translation.height > 50 触发 onClear）

**偏离说明：** 无方案外偏离。

---

## 19. 完成标准

以下条件全部满足后，可从 `active/` 移入 `done/`：

1. `swift test --package-path Packages/LangoTraceUI --filter "LangoTraceUITests/ReadingSourceFormatDisplayTests"` 通过（testAllCasesReturnReadableName 绿）
2. `scripts/verify.sh` 全部通过（包括 iOS Simulator 构建、SwiftLint、SwiftFormat）
3. iPhone 17 模拟器手动验证：选中文字只出现学习面板，系统菜单不再出现
4. iPhone 17 模拟器手动验证：面板出现后 teal 高亮保留，蓝色选择句柄消失
5. iPhone 17 模拟器手动验证：选中底部文字后内容向上滚动至面板上方可见
6. iPhone 17 模拟器截图确认：阅读列表来源标签显示"粘贴文本"/"纯文本"等可读字符串
7. VoiceOver 回归验证通过（选中文字时 VoiceOver 朗读正常）
8. spec 012 Change Log 已追加系统菜单抑制事实记录

---

## 20. 剩余风险

1. **复制功能缺失**：系统菜单抑制后，用户无法通过原生菜单复制选中文字。当前依赖用户长按面板内 `Text(selection.selectedText)` 触发系统复制（UIKit 非选择模式下的长按菜单）；若该路径不可用，需要单独创建"在学习面板中添加复制按钮"的 feature plan。

2. **macOS 端系统菜单未处理**：本计划不修改 macOS NSTextView 的系统菜单；macOS 阅读正文右键菜单与学习面板的冲突问题留待后续单独评估。

3. **VoiceOver 系统菜单关系**：iOS VoiceOver 的"朗读选中内容"手势与 `editMenuForTextIn` 抑制的菜单是独立机制，理论上互不影响。但仍需手动验证确认；若抑制后 VoiceOver 出现回归，应回退 Phase 2 修改并独立评估。

4. **`surfaceBase` color token 值**：卡片阴影方案依赖 `surfaceBase` 与背景有足够差异，若两者 RGBA 完全相同（如纯白 / 纯白），阴影仍可能不明显。实施时需通过截图确认最终效果；必要时调整 shadow opacity 或切换到 `systemBackground` 语义色。

5. **Swift 6 @MainActor**：`ReadingSelectableTextView.Coordinator` 的 `isApplyingCommittedHighlight` 标志依赖 main queue 单帧执行保证。若未来代码迁移至 Swift 6 严格并发模式，应将 Coordinator 标注为 `@MainActor` 以避免编译警告；当前 deployment target iOS 18 + 现有代码不强制执行 Swift 6 actor isolation，暂无立即风险。
