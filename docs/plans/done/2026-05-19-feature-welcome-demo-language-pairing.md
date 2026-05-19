# Welcome 示例语言配对方案

状态：Done

日期：2026-05-19

## 背景

Welcome 示例卡片用于解释语迹核心闭环：生活线索或随笔 -> 目标语言改写 -> 配音提示 -> 跟读练习。上一轮已把示例固定为中文随笔和英文改写，解决了英文界面下 rewrite 仍是英文但缺少双语对照的问题的一部分。

用户进一步确认：当默认或显式界面语言为中文时，示例应表现为学习英语；当界面语言为英文或其他语言时，示例应表现为学习中文，以便新用户明确这是语言学习 App，而不是单语笔记或单语文本展示。

## 目标

- 中文界面：示例卡片显示中文 source note，英文 rewrite，配音/跟读提示围绕英文练习。
- 英文、西班牙语、日语、法语、德语、韩语、俄语界面：示例卡片显示对应界面语言的 source note，中文 rewrite，配音/跟读提示围绕中文练习。
- iPhone、iPad、macOS 继续共享 `WelcomeTracePreviewCarousel`，不做平台分叉。
- 不实现真实 AI、TTS、录音、语音识别、权限请求、持久化或语言空间创建逻辑。

## 实施方案

1. 更新 UI 测试，先断言 8 种界面语言下 Welcome 示例具备正确语言方向。
2. 复用现有 `sourceNoteKey / rewrittenTextKey / audioCueKey / shadowingCueKey`，在 String Catalog 中按 locale 写入不同示例内容。
3. 保持 `zh-Hans` 为中文到英文，其他 locale 为该界面语言到中文。
4. 保持示例难度排序不变：咖啡店点单、通勤说明、工作会议。
5. 验证 `swift test --package-path Packages/LangoTraceUI`、`git diff --check`、`scripts/verify.sh`。
6. 验证后重启 iPhone 17 与 iPad Pro 13-inch (M5) 模拟器，供人工检查最新效果。

## 非目标

- 不新增真实学习语言选择器。
- 不把 Welcome 示例写入语言空间或用户内容模型。
- 不根据用户母语、目标语言或 onboarding draft 动态生成内容。
- 不改变现有界面语言偏好设置的存储语义。

## 文档影响

本轮只调整 Welcome 演示内容和测试，符合 `spec/006-interface-localization-and-language-boundaries.md` 中“界面语言、用户母语、目标学习语言三条独立轴线”的原则。当前 Welcome 示例仍属于静态演示内容，不代表真实语言空间默认值。无需新增 ADR。

## 完成记录

- 已将 Welcome 示例改为 `zh-Hans` 界面显示中文到英文，其余 7 种界面语言显示该界面语言到中文。
- 已新增 `WelcomeTraceLanguagePairingTests` 覆盖 8 种界面语言下的示例方向。
- 已保持三端共享 `WelcomeTracePreviewCarousel`，未新增 iPhone、iPad 或 macOS 分叉。
- 已验证：`swift test --package-path Packages/LangoTraceUI`。
- 已验证：`scripts/verify.sh`，包含 Core/Data/UI package tests、iPhone/iPad/macOS build、SwiftLint 0 violations、SwiftFormat 0 files require formatting。
