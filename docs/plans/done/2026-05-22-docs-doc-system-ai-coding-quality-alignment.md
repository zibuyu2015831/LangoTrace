# 文档体系 AI 编程与 Apple 三端质量对齐治理

状态：Verified
类型：docs
创建日期：2026-05-22
最后更新日期：2026-05-22

## 用户确认记录

- 2026-05-22：用户要求从系统架构师和资深 Apple 应用交互师角度，检查当前 docs 文档体系是否清晰、完备、准确，是否能高效指导 AI 辅助编程，尤其是规范文档体系是否能支持项目一致性、高质量设计和 UI 体验。
- 2026-05-22：审查结论为整体体系可用，但存在会误导后续 AI 和人工验证的事实漂移，以及 Apple 三端交互 / 可访问性规范入口不足。用户确认“立即进行”修复。

## 1. 需求或 bug 描述

修正文档体系中会影响后续 AI 辅助编程、手动验收和 Apple 三端 UI 质量判断的结构性问题：

- 产品主参考仍保留已淘汰的 iPhone 五 Tab 推荐。
- 测试文档仍使用旧页面闭环清单，和当前三端页面事实不一致。
- 页面清单中 Onboarding 语言空间创建仍写成内存预览，未反映 SQLite / GRDB 持久化。
- `docs/spec/` 缺少独立的 Apple 三端交互与可访问性验收入口，导致已有规则分散在 UI、导航、本地化和测试文档中。

## 2. 现状描述

当前文档体系已有清晰的入口、目录职责、任务方案、审查机制、spec 分层和验证门禁。`docs/spec/002`、`003`、`004`、`006` 和 `docs/testing/README.md` 已经包含大量 Apple 三端、响应式布局、可访问性和平台交互规则。

但长期事实源仍存在局部漂移：

- `docs/product-main-reference.md` 第 8.4 节仍推荐 `今日 / 记录 / 练习 / 记忆 / 设置` 五 Tab。
- `docs/testing/README.md` 的三端页面闭环验证清单仍要求验证五 Tab、旧 unavailable 入口和只读设置详情。
- `docs/platform-page-inventory.md` 的 Onboarding 能力边界仍写“当前创建内存语言空间预览，未持久化”。
- `docs/spec/README.md` 把可访问性规范列为后续建议，而不是当前生效规范。

## 3. 目标

本任务完成后必须达到：

- 产品主参考和当前 iPhone IA 保持一致：`记录 / 练习 / 记忆` 三个主目的地，设置通过 gear、语言空间入口或平台设置稳定可达。
- 三端页面闭环验证清单与当前页面事实、Local Mock、真实本地能力和配置合成测试一致。
- 页面清单准确反映 Onboarding 已通过 App Shell / Data repository 创建并恢复真实语言空间。
- 新增 Apple 三端交互与可访问性规范，作为 UI / SwiftUI / 平台交互任务的长期检查入口。
- `docs/spec/README.md` 和必要入口同步登记新规范。

## 4. 范围

本任务覆盖：

- `docs/product-main-reference.md`
- `docs/testing/README.md`
- `docs/platform-page-inventory.md`
- `docs/spec/README.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md`
- `docs/README.md`
- 本任务方案生命周期收口。

## 5. 不做什么

- 不修改 Swift 源码。
- 不新增 UI 测试或截图。
- 不删除历史 `docs/plans/done/`、`docs/review/rounds/` 或 `docs/archive/` 记录。
- 不改变产品核心决策、三端首发、语言空间模型、本地优先或用户自带 Provider ADR。
- 不补完整 StoreKit / TestFlight / App Store 发布规范；该项保留为后续发布阶段治理任务。

## 6. 证据与决策依据

代码证据：

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`：当前 iPhone 顶层 Tab 只有 `entries / practice / memory`。
- `LangoTraceApp/AppEnvironment.swift`：`AppSessionState.createLanguageSpace()` 通过 `LanguageSpaceRepository` 创建语言空间，默认装配 `GRDBLanguageSpaceRepository`。
- `LangoTraceApp/LangoTraceApp.swift`：macOS 已有原生 `Settings` scene、`New Entry`、`Search`、`Toggle Sidebar`、`Toggle Inspector` 和 `Settings...` 命令。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/`：当前三端页面已有语言空间管理、AI Provider 设置、同步设置、照片写作本地预览和听一句本地预览等页面事实。

文档证据：

- `docs/spec/002-navigation-and-routing.md`：iPhone 一级入口为 `记录 / 练习 / 记忆`，设置不作为底部 Tab。
- `docs/spec/003-ui-design-system.md`：已有触控尺寸、状态表达、Reduce Motion、面板、操作反馈和管理类 sheet 规则。
- `docs/spec/004-swiftui-architecture.md`：定义共享内容视图与平台外壳边界。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：定义长文案、Dynamic Type、本地化和语言边界。
- `docs/review/INDEX.md`：已有多轮 UI 和文档体系审查记录。

## 7. 涉及的代码文件路径

无，文档-only 任务。

## 8. 参考的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacMainView.swift`

## 9. 涉及的文档路径

- `docs/product-main-reference.md`
- `docs/testing/README.md`
- `docs/platform-page-inventory.md`
- `docs/spec/README.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/README.md`
- `docs/review/INDEX.md`
- `docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md`
- `docs/plans/done/2026-05-22-docs-doc-system-ai-coding-quality-alignment.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 实施方案

1. 修正产品主参考中 iPhone 一级导航旧五 Tab 口径，保留产品对象和设置稳定可达的结论。
2. 刷新 `docs/testing/README.md` 的三端页面闭环验证清单，删除旧五 Tab 和旧 unavailable 断言，改为当前三端页面、真实本地能力和本地 mock 边界。
3. 修正页面清单 Onboarding 语言空间创建事实。
4. 新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md`，沉淀 iPhone、iPad、macOS、可访问性、动态字体、键盘 / 指针、菜单命令和验证入口。
5. 更新 `docs/spec/README.md` 和 `docs/README.md` 的读取路径。
6. 运行文档门禁并将本方案移入 `docs/plans/done/`。

## 12. 复查方法

- 搜索旧五 Tab 和旧 Onboarding 持久化表述，确认当前事实源不再误导。
- 检查新增 spec 是否包含状态、适用阶段、适用范围、强制规则、默认推荐、反例、AI 开发提示和变更记录。
- 检查文档入口是否能把 UI / SwiftUI / Apple 三端任务路由到新增规范。

## 13. 验证命令

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
rg -n "今日 / 记录 / 练习 / 记忆 / 设置|当前创建内存语言空间预览，未持久化|设置列表每个能力项可进入只读说明页|五个 Tab" docs/product-main-reference.md docs/testing/README.md docs/platform-page-inventory.md docs/spec docs/README.md docs/_meta
git diff --check
git status --short
```

本任务不运行 `scripts/verify.sh`，原因是只修改文档，不修改 Swift 源码、工程配置、资源或验证脚本。

## 14. 文档影响检查

影响 `docs/product-main-reference.md`、`docs/testing/README.md`、`docs/platform-page-inventory.md`、`docs/spec/README.md` 和 `docs/README.md`。新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md`。本轮发现当前事实源漂移和规范入口缺口，已按文档审查机制补充专项审查记录 `docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md` 并更新 `docs/review/INDEX.md`。不需要 ADR，因为本任务不改变核心产品模型、技术路线、隐私边界、同步策略或付费策略。

## 15. 实施记录

- 2026-05-22：修正 `docs/product-main-reference.md` 中 iPhone 旧五 Tab 推荐，当前事实改为 `记录 / 练习 / 记忆` 三个主目的地，设置通过 gear、语言空间入口或二级配置 route 稳定可达。
- 2026-05-22：刷新 `docs/testing/README.md` 三端页面闭环 iPhone 手动清单，删除旧五 Tab、旧 unavailable 入口和只读设置详情断言，改为当前照片写作本地预览、听一句本地预览、语言空间 SQLite / GRDB 管理和 AI Provider 配置合成测试边界。
- 2026-05-22：修正 `docs/platform-page-inventory.md` Onboarding 语言空间创建事实，补充 App Shell action、`LanguageSpaceRepository` 和 SQLite / GRDB 持久化边界。
- 2026-05-22：新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md`，并在 `docs/spec/README.md`、`docs/README.md`、`docs/_meta/documentation-system.md`、`docs/testing/README.md` 和页面清单维护问题中登记入口。
- 2026-05-22：补齐专项审查记录 `docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md`，并更新 `docs/review/INDEX.md`，确保本轮当前事实源漂移和规范入口缺口按文档审查机制可追踪。
- 2026-05-22：运行文档门禁：
  - `find docs -maxdepth 3 -type f | sort`：通过，输出包含未跟踪的宿主机文件 `docs/.DS_Store`。
  - `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'`：通过，无匹配。
  - `rg -n "今日 / 记录 / 练习 / 记忆 / 设置|当前创建内存语言空间预览，未持久化|设置列表每个能力项可进入只读说明页|五个 Tab" docs/product-main-reference.md docs/testing/README.md docs/platform-page-inventory.md docs/spec docs/README.md docs/_meta`：通过，无匹配。
  - `git diff --check`：通过。
  - `awk '/[ \t]$/ { print FILENAME ":" FNR ": trailing whitespace" }' docs/spec/010-apple-platform-interaction-and-accessibility.md docs/plans/done/2026-05-22-docs-doc-system-ai-coding-quality-alignment.md docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md`：通过，无输出。
  - `git status --short`：确认仅有本任务文档变更和新增文档。

## 16. 完成标准

- 已修正发现的 P0/P1/P2 文档事实和规范入口缺口。
- 已按文档审查机制补齐专项审查 round 和索引。
- 已运行文档门禁并记录结果。
- 方案从 `active/` 移入 `done/`，状态为 `Verified`。

## 17. 剩余风险

- 发布文档仍是占位级；StoreKit、TestFlight、App Store 隐私标签和权限 purpose strings 需要在进入发布阶段前另开治理任务补齐。
- 本次新增 Apple 三端交互与可访问性规范是文档规则，不替代后续 UI 任务中的截图、动态字体、VoiceOver、键盘和 Stage Manager 实测。
