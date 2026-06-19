# 产品与信息架构审查报告

## 结论摘要

- 当前产品方向仍围绕“用生活记录学习语言”，没有偏向 AI 聊天、课程、背单词或云账号中心。
- `Space -> Entry -> Rendering -> Practice -> Memory` 已有骨架，但 Rendering 需要更显性，不能让保存 Entry 等同于未来真实 AI 生成。
- iPhone `今日` 和 `记录` 建议合并，`设置` 不建议继续作为顶层 Tab。
- 语言空间删除应允许，但必须拆新 active plan 定义数据、路由、导出、撤销和同步边界。
- iPad 三栏结构应保留，但 Sidebar 配置入口要收敛。
- macOS 应从功能 section 列表收敛为工作台，Settings、AI、Sync、Import/Export 走 toolbar、footer detail、Settings scene 或 commands。

## 主要 Findings

- P1-IA-01：iPhone `今日 / 记录` 顶层目的地重复，`设置` 作为 Tab 过重。
- P1-IA-02：语言空间删除应允许，但不能在当前 UI 直接加入。
- P1-IA-03：Rendering 边界不够显性，Local Mock 自动生成可能掩盖未来真实 AI 用户触发边界。
- P1-IA-04：macOS Sidebar 与 footer 设置入口语义重叠。
- P2-IA-01：iPad Sidebar `Pages` 区把 Memory、Import/Export、Settings 混在时间线旁。
- P2-IA-02：Onboarding 当前实现信息密度合理，但产品 / 导航文档仍有“是否现在配置 AI Provider”的潜在分歧。
- P2-IA-03：语言空间入口当前多为 unavailable，无法完成“添加学习语言 / 切换语言”的最小预期。
- P3-IA-01：`Memory` 尚未体现内容记忆、语言记忆、学习记忆三层模型。

## 第一轮建议

1. 合并 iPhone `今日 / 记录`，降级 `设置`。
2. Entry detail 中显性化 Rendering 状态。
3. 收敛 iPad Sidebar 配置入口。
4. 收敛 macOS Sidebar / footer 设置语义。
5. 将语言空间 unavailable 改为只读 Space summary。
6. 更新 `docs/spec/002-navigation-and-routing.md`。
7. 拆出语言空间生命周期 active plan。
