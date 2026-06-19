# iPadOS 交互审查报告

## 结论摘要

- 三栏方向适合 LangoTrace iPad 角色，但当前实现是固定宽度 HStack 原型，不是完整自适应 iPad 工作台。
- 左栏职责过重，右栏更像功能清单而不是状态驱动学习 Inspector。
- 键盘、pointer、focus 和 context menu 基本缺失。

## 主要 Findings

- P1-01：Split View / Stage Manager 响应式不足。
- P1-02：hardware keyboard、pointer、context menu 支持基本缺失。
- P1-03：Sidebar 同时承担 timeline、filters、route list、language-space footer，隐藏左栏会隐藏重要入口。
- P2-01：empty / filtered-empty 状态缺少下一步动作。
- P2-02：右学习面板不是状态驱动，像功能 inventory。
- P2-03：部分 iPad/shared controls 未达到 44pt。
- P2-04：`PadWorkspaceBar` 是 custom chrome，缺少 toolbar / command 语义。
- P3-01：panel edge gestures 有测试但不可发现，应保持为 accelerator。

## 第一轮建议

1. 定义三栏、两栏、单栏断点。
2. 窄宽度默认隐藏两侧辅助面板，保护主内容。
3. 增加 Cmd+N、Cmd+F、panel toggle、Settings 入口。
4. 给 rows / chips / route buttons / panel toggles 增加 hover / focus。
5. 左栏只承担学习材料上下文，配置入口移到稳定 command / footer。
6. 右栏改为 `Entry -> Rendering -> Practice -> Memory` 状态驱动 Inspector。
