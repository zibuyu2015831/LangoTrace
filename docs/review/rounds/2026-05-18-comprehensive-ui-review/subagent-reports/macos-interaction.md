# macOS 交互审查报告

## 结论摘要

- 当前三栏概念可保留，但 Mac 原生命令面明显不足。
- 左下 AI / Sync / Settings 三个图标不应表现为三个等价 Settings 入口。
- Sidebar 应更接近 native source list，Settings / ImportExport 不应和内容域同级。

## 主要 Findings

- P1-001：缺少 macOS Settings scene、menu commands 和 keyboard shortcuts。
- P1-002：Sidebar 是 custom buttons，不是 native source list。
- P1-003：底部 AI / Sync / Settings 图标都进入 settings-like navigation。
- P2-001：Search 是 unavailable toolbar button，不是标准 search / command surface。
- P2-002：window behavior under-specified，`.windowResizability(.contentSize)` 和 `minHeight: 720` 可能过约束。
- P2-003：Inspector 上下文正确但过于 passive。
- P2-004：toolbar panel toggles 缺少 accessibility state value 和 menu mirror。
- P3：`INSPECTOR` literal 和语言空间 footer unavailable route 仍像原型。

## 第一轮建议

1. 添加 `Settings {}`、`.commands`、`Cmd+,`、`Cmd+N`、`Cmd+F` 和 View menu panel toggles。
2. Sidebar 收敛为内容 source list。
3. AI / Sync 为状态 popover 或 detail，gear 为 general settings。
4. 搜索入口保持诚实 unavailable 或引入标准 `.searchable`。
5. 定义 Mac window sizing 规则并截图验证。
