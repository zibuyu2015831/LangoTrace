# 任务方案：最近 Welcome 提交文档影响检查

状态：Verified

类型：docs

创建日期：2026-05-19

最后更新日期：2026-05-19

## 1. 用户确认记录

2026-05-19：用户要求检查最近几次 commit 的改动，思考 `docs` 中是否有文档需要更新，是否有某些内容需要沉淀为规范或记录，便于后续开发时遵循。

## 2. 需求描述

复查最近几次 Welcome、三端 UI、界面语言和 SwiftUI 文件组织相关提交，判断哪些一次性任务经验应进入长期规范，避免后续开发只依赖归档任务方案或聊天记录。

## 3. 现状描述

最近提交已经通过 `docs/plans/done/` 记录了 Mac / iPad / iPhone Welcome 页面优化、Welcome 示例卡片改写、双语展示、String Catalog 和 SwiftLint 长度收口等执行细节。但部分跨任务经验尚未进入长期 spec：

- Welcome 静态示例内容属于产品解释用 demo，不完全等同于 App chrome，也不等同于真实用户内容。
- Welcome 示例需要清楚展示“生活线索 -> 目标语言表达”的跨语言关系。
- 大型 SwiftUI 页面在多端布局持续迭代后，应把布局 helper、叶子组件和测试按职责拆分，而不是把 SwiftLint 长度 warning 当成噪音。
- Welcome 是首次解释产品闭环的入口，不应退回营销 landing page 或功能清单。

## 4. 目标、范围和不做什么

目标：

- 把最近 Welcome 相关提交中已经反复验证的规则沉淀到长期规范。
- 明确静态演示内容、真实用户内容、App chrome 和目标语言内容之间的边界。
- 明确 SwiftUI 大型页面文件和测试拆分的治理规则。

范围：

- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`

不做：

- 不修改产品代码。
- 不修改 String Catalog。
- 不新增 ADR。
- 不改变首次启动路由、语言空间模型、AI Provider、权限、同步、StoreKit 或发布策略。

## 5. 证据与决策依据

- `080fe53 Polish welcome examples and layout tests`：Welcome 示例双语展示、布局测试和源码组织已经完成。
- `c3e40d7 Polish welcome experience across Apple platforms`：Welcome 三端体验、示例卡片和布局策略已经多轮优化。
- `b7450cd Optimize welcome home experience`：Welcome 由小预览卡扩展为更清楚的产品解释页。
- `docs/plans/done/2026-05-19-bug-welcome-bilingual-and-lint.md`：明确 Welcome 双语展示和 SwiftLint 长度收口。
- `docs/plans/done/2026-05-19-feature-ipad-welcome-page-design.md`：明确 Welcome 不承诺录音输入，三端共享副标题和静态示例边界。

## 6. 涉及的代码文件路径

- 本任务不修改代码。

## 7. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView+Layout.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeCapsuleLabel.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeTracePreviewContentTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeLayoutTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeSourceOrganizationTests.swift`

## 8. 涉及的文档路径

- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/plans/active/2026-05-19-docs-recent-welcome-commit-impact.md`

## 9. 实施方案

1. 在 `spec/006` 增补“静态演示内容语言”规则，明确 Welcome demo 的双语展示策略与真实用户内容边界。
2. 在 `spec/004` 增补大型 SwiftUI 页面文件治理规则，沉淀 Welcome 拆分后的代码组织经验。
3. 在 `spec/003` 增补 Welcome / 首次解释体验规则，明确 Welcome 不是营销页，也不暗示真实 AI、TTS、录音、同步或外部请求已经发生。
4. 运行 docs-only 校验并把本方案移入 done。

## 10. 复查方法

- 复查新增规范是否只约束 Welcome / 静态 demo / SwiftUI 代码组织，不误改核心产品决策。
- 复查没有引入占位型标记或未收口说明。
- 复查 `git diff --check` 无空白错误。

## 11. 验证命令

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 12. 文档影响检查

本任务本身是文档影响检查。它不改变 ADR 级核心决策；沉淀内容属于 UI、SwiftUI 架构和界面语言边界规范的细化。

## 13. 实施记录

- 2026-05-19：创建任务方案。
- 2026-05-19：已更新 `docs/spec/006-interface-localization-and-language-boundaries.md`，补充静态演示内容语言边界，明确 Welcome demo、App chrome、真实用户内容和语言空间目标语言的关系。
- 2026-05-19：已更新 `docs/spec/004-swiftui-architecture.md`，补充大型 SwiftUI 页面文件治理规则，要求多端页面按布局 helper、叶子组件和测试职责拆分。
- 2026-05-19：已更新 `docs/spec/003-ui-design-system.md`，补充 Welcome 与首次解释体验规则，明确首屏解释产品闭环、三端共享语义和未接入能力承诺边界。
- 2026-05-19：验证通过：
  - `find docs -maxdepth 3 -type f | sort`
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`
  - `git diff --check`
  - `git status --short`

## 14. 完成标准

- 长期 spec 覆盖 Welcome 静态 demo 语言边界、首次解释体验边界和 SwiftUI 大型页面拆分规则。
- docs-only 校验通过。
- 本方案移入 `docs/plans/done/`。

## 15. 剩余风险

- 本任务不运行完整 Swift 工程验证；如后续同步修改代码或 String Catalog，应另行运行 `scripts/verify.sh`。
