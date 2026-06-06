# 架构备忘录：per-block UITextView 阅读渲染模式

创建日期：2026-06-06
关联任务：docs/plans/done/2026-06-04-refactor-reading-natural-text-rendering-and-selection.md

## 1. Per-block UITextView 高度计算模式

`ReadingSelectableTextView` 使用 `@Binding var height: CGFloat` + `DispatchQueue.main.async` 更新的两帧方案：

1. 初始化时 SwiftUI 用 `default: 44` 渲染一个很矮的帧。
2. `updateUIView` 调用 `sizeThatFits(CGSize(width: proposedWidth, height: .greatestFiniteMagnitude))`，把正确高度异步推回 binding。
3. SwiftUI 收到高度变化后重新布局，渲染正确高度。

**已知风险**：初始化时会有一帧高度为 44pt 的闪烁。对于长文档（>20 个 block）这可能造成累积布局跳动。

**后续优化方向**：
- 使用 `PreferenceKey + GeometryReader` 收集自然高度（但 UIViewRepresentable 的 `sizeThatFits` 更可靠）。
- 引入 `intrinsicContentSize` override，通过 `invalidateIntrinsicContentSize()` 触发 SwiftUI 重新测量。
- 长期：考虑全文档单一 NSTextLayoutManager（TextKit 2），完全由系统管理高度和滚动。

## 2. NSRange 多字节安全转换约定

所有从 UITextView/NSTextView 取出的 `selectedRange`（NSRange）到 Swift 字符偏移量的转换，必须通过：

```swift
if let range = Range(nsRange, in: blockText) {
    let characterOffset = blockText.distance(from: blockText.startIndex, to: range.lowerBound)
    let characterLength = blockText.distance(from: range.lowerBound, to: range.upperBound)
}
```

不得直接用 `nsRange.location` 作为 Swift 字符索引——NSRange 使用 UTF-16 单元计数，Swift String 使用 Unicode Scalar（及 Character）计数，在含 emoji、CJK 扩展区字符时两者不等。

此约定已封装在 `ReadingSelectableTextView.swift` 的 `characterRange(from:in:)` 帮助函数中，后续其他涉及 UITextView/NSTextView 的代码应复用此函数。

## 3. macOS NSTextView 不包裹 NSScrollView 的原因

macOS 常规用法是 `NSScrollView { NSTextView }`，但阅读 Canvas 的 ScrollView 由 SwiftUI 管理。直接使用独立 NSTextView（不包 NSScrollView）避免了双层滚动视图冲突。

如果将来需要 macOS 上的代码块语法高亮或超长段落内滚动，再考虑 per-block 包裹 NSScrollView，但届时必须解决与外层 ScrollView 的滚动手势冲突。

## 4. Per-block 粒度的跨 block 选择限制

当前实现每个 Markdown block 对应一个 UITextView 实例，因此**不支持跨 block 边界的文本选择**。

这对语言学习场景是可接受的：学习目标（词汇、短语、句子）几乎总是落在同一段落内。

若未来需要跨 block 选择（例如选择连续两段构成的引文），需要改用全文档单一 UITextView / NSTextView，届时应创建独立任务方案。

## 5. iPad inspector 折叠状态检测（待完善）

当前方案设计：iPad inspector 折叠时降级为底部 compact 面板。实现时发现 `ReadingDocumentCanvas` 没有暴露 `isInspectorExpanded` 状态，降级路径尚未实现。

**后续任务**：在 `ReadingLibraryView` 的 iPad 布局中，通过 `@State private var isInspectorExpanded: Bool = true` + `NavigationSplitView` 或手势检测，把折叠状态传给 `ReadingDocumentDetailView`，条件渲染底部 compact 面板。

此备忘录供该后续任务方案引用。
