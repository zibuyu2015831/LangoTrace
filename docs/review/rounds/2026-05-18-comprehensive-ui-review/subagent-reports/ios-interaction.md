# iPhone / iOS 交互审查报告

## 结论摘要

- 当前五 Tab 符合旧规范和 iOS 3-5 tab 数量规则，但 shared `NavigationStack`、Today 首屏不可用 secondary features、Welcome 自动跳转和 Onboarding 说明前置需要优先修复。
- iOS 子审查倾向短期不直接删 Tab，但主审结合产品 IA 裁决为后续第一轮 UI 收敛应调整 Tab IA。

## 主要 Findings

- P1-1：单个 `NavigationStack` 包住所有 Tab，削弱 per-tab state preservation。
- P1-2：Today 首屏的 photo writing / listen unavailable chips 权重过高。
- P1-3：Welcome / Onboarding 过早暴露 AI、sync、dictionary、Prompt 概念。
- P1-4：Welcome 650ms 自动跳转对 VoiceOver 和 Timing accessibility 不友好。
- P2-1：Onboarding menu、practice step、sentence inline controls 存在 44pt / Dynamic Type 风险。
- P2-2：unavailable sheet 缺少 title、close、scroll 和 focus return。
- P2-3：Entry editor `TextEditor` 缺少明确 accessible label。
- P2-4：密集 horizontal rows 缺少 Dynamic Type reflow。
- P2-5：Onboarding language value 仍使用 ChineseUI display helpers。
- P3：Section headings 未标记 heading trait，部分 hints 重复。

## 第一轮建议

1. 收敛 Today 首屏为一个强主动作。
2. Onboarding 只保留三项基础设置和一句本地保存说明。
3. 为每个 Tab 建立独立导航栈或重新设计 iPhone IA。
4. 统一 unavailable sheet 可访问 pattern。
5. 建立 iPhone SE + Accessibility text size + en / zh-Hans / long language 截图基线。
