# 设计系统与视觉审查报告

## 结论摘要

设计系统已经进入 token / component 阶段，但尚未达到付费级 Apple 应用可收敛底座。核心问题是固定浅色调、卡片样式过度统一、状态视觉区分弱、组件缺少响应式和本地化布局策略。

## 主要 Findings

- VD-P1-01：固定浅色纸张 + 青绿 / 金色体系不足以承载深浅色和长期付费级视觉。
- VD-P1-02：`langoPanel` 被用于几乎所有内容容器，页面层级趋向卡片堆叠。
- VD-P1-03：Local Mock、Ready、Unavailable 状态视觉区分偏弱。
- VD-P1-04：长文案和本地化后的布局风险缺少组件级策略。
- VD-P2-01：三端视觉形态过于同源，平台材质差异不足。
- VD-P2-02：empty / unavailable 状态偏说明页，缺少下一步动作。
- VD-P2-03：主次按钮层级和控件密度缺少统一规则。
- VD-P2-04：设计 token 覆盖不足，魔法数仍在组件中扩散。
- VD-P3-01：UI 文案中仍有偏工程术语，降低付费用户视角完成度。

## 第一轮建议

1. 扩展 `LangoTraceDesign` semantic token、平台 surface、状态色、spacing / radius / action 层级。
2. 以 iPhone 今日 + Entry detail、iPad 三栏、macOS 主工作台 + Inspector 作为样板页。
3. 重构 `langoPanel` 使用边界。
4. 建立状态矩阵组件。
5. 为 `SentencePairView`、`EntryDetailHeader`、`LanguageSpaceFooter`、`HeroActionCard` 增加 compact pattern。
6. 主路径文案从工程术语改为用户语言，技术边界保留在详情层。
