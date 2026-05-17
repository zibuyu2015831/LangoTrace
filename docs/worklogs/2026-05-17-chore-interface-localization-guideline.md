# 工作记录：界面国际化开发规范草案

类型：chore

状态：Verified

日期：2026-05-17

关联文档：

- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/guidelines/README.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/README.md`

关联 ADR：

- 无

关联提交：

- 未提交

## 1. 背景

用户提出：鉴于语迹的愿景是适配任何语言学习，App 界面语言应支持国际化，默认显示英文，并允许用户主动配置为其他语言。

经过产品设计角度评估，需求成立，但“默认显示英文”应调整为更符合 Apple 平台和全球用户预期的策略：默认跟随系统语言，系统语言未支持时回退英文，用户可在设置中主动覆盖。

## 2. 目标

- 将“界面语言、用户母语、目标学习语言三轴分离”沉淀为开发规范。
- 明确后续设计、改进页面时必须考虑国际化问题。
- 为后续 SwiftUI String Catalog、设置入口、术语表和截图验证提供草案依据。
- 不进入代码实现，不创建真实本地化资源。

## 3. 范围

本次处理：

- 新增国际化与语言边界 guideline 草案。
- 更新 guidelines 入口。
- 在 UI 设计系统规范中加入国际化交叉约束。
- 更新文档总入口中原型和 UI 设计的阅读路径。

## 4. 不做什么

- 不修改 SwiftUI 代码。
- 不创建 String Catalog。
- 不实现界面语言设置。
- 不调整 onboarding 数据模型。
- 不承诺首批发行支持大量界面语言。
- 不改变语言空间、母语或目标语言的核心产品决策。

## 5. 分析

语迹存在四类容易混淆的语言：

- App 界面语言：导航、按钮、设置、状态和隐私说明。
- 用户母语：记录原文、讲解、对照解释。
- 目标学习语言：语言空间对应的学习语言。
- Provider / Prompt 输出语言：AI 请求中显式要求的生成或解释语言。

如果不在早期建立规范，后续页面优化和功能实现容易出现以下问题：

- 中文硬编码沉淀为长期债务。
- 英文 fallback 被误解成强制默认英文。
- 切换语言空间错误地改变 UI 语言。
- 设置界面语言错误地改变目标学习语言。
- Prompt 从展示文案推断语言，导致 AI 请求不稳定。
- 长文本翻译破坏 iPhone、小窗口 iPad 和 macOS Sidebar 布局。

架构与 iOS 交互复查后，补充发现以下遗漏：

- Apple 平台已有系统级 per-app language 心智；App 内语言设置不能默认覆盖所有系统 UI、权限弹窗、StoreKit sheet 和文件选择器。
- 地区格式与语言不同。日期、时间、数字、价格、单位、复数和日历不能用固定中文或英文格式。
- 第一阶段虽然只建议英文和简体中文，但组件结构不应阻断未来 RTL、非拉丁文字或更长翻译。
- 语言学习 App 中会混合用户母语、目标语言和界面语言；VoiceOver / 辅助功能朗读可能需要语言上下文。
- 权限 purpose strings、隐私说明、请求预览、App Store 元数据和截图也属于国际化范围，不只是 SwiftUI 页面 `Text`。

## 6. 方案

采用独立 guideline 方案，而不是只在 UI 设计系统规范中补一句说明。

理由：

- 国际化不仅影响视觉设计，还影响产品语言模型、设置偏好、SwiftUI 资源结构、Prompt 构建和测试。
- 独立 guideline 更容易被后续页面设计、AI Prompt、TTS、OCR 和发布材料任务引用。
- UI 设计系统规范保留交叉引用，避免做页面视觉优化时漏读。

替代方案：

- 只更新 `003-ui-design-system.md`：改动小，但容易把国际化误解为样式问题。
- 直接创建 ADR：约束力更强，但当前没有改变核心产品决策，暂不需要 ADR。

## 7. 风险与边界

- 规范仍为 Draft，后续需要用户复查后再升为 Accepted。
- 草案不代表已实现国际化，也不代表当前页面已经完成 String Catalog 迁移。
- 英文作为 fallback 不等于强制默认英文；默认策略应是跟随系统语言。
- 后续如决定界面语言偏好进入同步或语言空间模型，需要重新评估并可能新增 ADR。

## 8. 测试与验证

文档草案完成后验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

预期：

- 新 guideline 出现在文档目录中。
- 文档没有占位词。
- diff 没有空白错误。
- git status 只显示本次文档改动。

## 9. 文档影响检查

- 影响 `docs/README.md`：需要在原型和 UI 设计阅读路径中加入新的国际化规范。
- 影响 guidelines：新增 `006`，并更新 `docs/guidelines/README.md`。
- 影响 UI 设计系统规范：需要加入后续页面设计必须读取国际化规范的交叉约束。
- 不影响 architecture、testing、release：本次不进入实现、测试流程或发布语言清单。
- 不触发专项审查：本次是规范草案，不改变数据库、AI Provider、权限、同步、StoreKit、验证脚本、包边界或 App 启动结构。

## 10. 用户确认记录

2026-05-17：用户要求“这一点需要添加为项目的开发规范，之后设计、改进页面时，必须考虑国际化问题；立即创建相关草案文档”，确认创建规范草案。

## 11. 实施记录

已创建：

- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/worklogs/2026-05-17-chore-interface-localization-guideline.md`

已更新：

- `docs/guidelines/README.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/README.md`

架构与 iOS 交互复查后，继续补充 `docs/guidelines/006-interface-localization-and-language-boundaries.md`：

- 增加 Apple 平台系统级 App 语言与 App 内语言偏好的关系。
- 增加地区格式、用户内容语言、RTL、辅助功能朗读和 iOS 设置入口边界。
- 增加 String Catalog 的复数、变量、译者上下文、不可翻译对象和本地化资产要求。
- 增加本地化测试、截图、权限隐私文案和 App Store 元数据检查要求。

## 12. 验证结果

已执行：

```bash
find docs -maxdepth 3 -type f
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f` 成功列出文档，新 guideline 和 worklog 已出现在文档目录中。
- 占位扫描退出码为 1 且无输出，表示没有匹配到禁止占位词。
- `git diff --check` 退出码为 0，未发现空白错误。
- `git status --short` 只显示本次文档改动。

架构与 iOS 交互复查补充后再次执行：

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- 占位扫描退出码为 1 且无输出，表示没有匹配到禁止占位词。
- `git diff --check` 退出码为 0，未发现空白错误。
- `git status --short` 只显示本次文档改动。
