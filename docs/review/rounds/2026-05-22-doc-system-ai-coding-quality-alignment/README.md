# 文档审查：文档体系 AI 编程与 Apple 三端质量对齐

审查类型：专项审查
日期：2026-05-22
代码快照：affd73fb8bce12ce8f7debbff7c6c1ea82629093
状态：Verified
当前事实源：`docs/README.md`、`docs/product-main-reference.md`、`docs/platform-page-inventory.md`、`docs/spec/README.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`、`docs/testing/README.md`
后续覆盖记录：`docs/plans/done/2026-05-22-docs-doc-system-ai-coding-quality-alignment.md`
可作为依据：Yes

## 1. 触发原因

用户要求从系统架构师和资深 Apple 应用交互师角度，基于 LangoTrace 的定位和愿景，检查当前 docs 文档体系是否清晰、完备、准确，是否能高效指导 AI 辅助编程，尤其是规范文档体系是否能支持一致性开发、高质量设计和 UI 体验。

审查过程中发现当前事实源存在局部漂移，并且 `docs/spec/` 缺少独立的 Apple 三端交互与可访问性长期入口。该情况属于文档审查机制中的“AI 会话发现文档与代码不一致”和“规范过期 / 缺少新规则”，因此记录为专项审查。

## 2. 审查范围

- 文档入口与任务路由：`docs/README.md`、`docs/_meta/documentation-system.md`。
- 产品和页面事实源：`docs/product-main-reference.md`、`docs/platform-page-inventory.md`。
- 开发规范入口：`docs/spec/README.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/003-ui-design-system.md`、`docs/spec/004-swiftui-architecture.md`、`docs/spec/006-interface-localization-and-language-boundaries.md`。
- 测试与验收入口：`docs/testing/README.md`。
- 相关任务记录：`docs/plans/done/2026-05-22-docs-doc-system-ai-coding-quality-alignment.md`。

## 3. 相关源码、脚本和配置

- `Packages/LangoTraceCore/Sources/LangoTraceCore/PhoneRootTab.swift`：iPhone 顶层主目的地为 `entries / practice / memory`。
- `LangoTraceApp/AppEnvironment.swift`：语言空间创建通过 `LanguageSpaceRepository`，默认装配 `GRDBLanguageSpaceRepository`。
- `LangoTraceApp/LangoTraceApp.swift`：macOS 已具备原生 Settings scene 和菜单命令入口。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`PadMainView.swift`、`MacMainView.swift`：三端页面结构和设置入口事实。

## 4. 结论摘要

文档体系整体可用，入口、目录职责、任务方案、spec 分层和验证门禁已经能支撑当前早期开发阶段。但存在三类会影响后续 AI 辅助编程和人工验收的问题：

- 当前事实源仍残留 iPhone 旧五 Tab 口径，和当前 `记录 / 练习 / 记忆` 主目的地不一致。
- 测试文档仍引用旧页面闭环清单，未反映当前照片写作本地预览、听一句本地预览、语言空间 SQLite / GRDB 管理和 AI Provider 配置合成测试边界。
- Apple 三端交互、macOS 原生性、iPad 自适应、Dynamic Type、VoiceOver、键盘、指针和 Reduce Motion 规则分散在多份文档中，缺少长期规范入口。

本轮已修正文档事实并新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md` 作为长期规范入口。

## 5. 问题清单

| ID | 严重度 | 问题 | 处理结果 |
| --- | --- | --- | --- |
| P1-1 | P1 | `docs/product-main-reference.md` 仍保留 `今日 / 记录 / 练习 / 记忆 / 设置` 五 Tab 推荐，容易误导后续 iPhone IA 实现。 | 已修正为 `记录 / 练习 / 记忆`，并明确设置不作为底部 Tab。 |
| P1-2 | P1 | `docs/testing/README.md` 的 iPhone 页面闭环清单仍包含旧五 Tab、旧 unavailable 入口和只读设置详情。 | 已更新为当前三端页面事实、本地 mock 边界和 AI Provider 配置合成测试边界。 |
| P1-3 | P1 | `docs/platform-page-inventory.md` 的 Onboarding 仍写成内存语言空间预览，未反映 SQLite / GRDB 持久化事实。 | 已修正为 App Shell action + `LanguageSpaceRepository` + SQLite / GRDB 恢复。 |
| P1-4 | P1 | `docs/spec/` 缺少独立 Apple 三端交互与可访问性入口，规则分散，AI 后续开发容易漏验平台原生性和无障碍。 | 已新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md`，并更新入口。 |

## 6. 文档修改记录

- 更新 `docs/product-main-reference.md`：修正 iPhone 一级导航事实。
- 更新 `docs/testing/README.md`：刷新三端页面闭环手动验证清单，并指向 Apple 三端交互与可访问性规范。
- 更新 `docs/platform-page-inventory.md`：修正 Onboarding 语言空间创建和恢复事实，补充新规范维护问题。
- 更新 `docs/spec/README.md`：登记 `010` 规范并更新 AI 读取路径。
- 新增 `docs/spec/010-apple-platform-interaction-and-accessibility.md`：沉淀三端交互、可访问性、键盘 / 指针 / 菜单、动态字体和验证入口。
- 更新 `docs/README.md`、`docs/_meta/documentation-system.md`：补充新规范入口和当前 spec 范围。
- 更新 `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`：移除旧五 Tab 评审口径。

## 7. 用户澄清

- 用户确认需要从项目定位和愿景出发进行文档体系审查。
- 用户确认在发现结构性问题后“立即进行”修复。

## 8. 延后项和原因

- 发布文档仍是占位级。原因：本轮范围是当前 AI 辅助编程和 Apple 三端 UI 质量支撑，不进入 StoreKit、TestFlight、App Store 隐私标签和权限 purpose strings 的发布阶段治理。

## 9. 验证命令与结果

```bash
find docs -maxdepth 3 -type f | sort
```

结果：通过。输出包含宿主机文件 `docs/.DS_Store`，该文件未出现在 `git status --short` 中。

```bash
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
```

结果：通过，无匹配。

```bash
rg -n "今日 / 记录 / 练习 / 记忆 / 设置|当前创建内存语言空间预览，未持久化|设置列表每个能力项可进入只读说明页|五个 Tab" docs/product-main-reference.md docs/testing/README.md docs/platform-page-inventory.md docs/spec docs/README.md docs/_meta
```

结果：通过，无匹配。

```bash
git diff --check
```

结果：通过。

```bash
awk '/[ \t]$/ { print FILENAME ":" FNR ": trailing whitespace" }' docs/spec/010-apple-platform-interaction-and-accessibility.md docs/plans/done/2026-05-22-docs-doc-system-ai-coding-quality-alignment.md docs/review/rounds/2026-05-22-doc-system-ai-coding-quality-alignment/README.md
```

结果：通过，无输出。

```bash
git status --short
```

结果：仅包含本轮文档修改、新增规范、新增 done plan 和新增 review round。

本轮未运行 `scripts/verify.sh`。原因：只修改文档，未修改 Swift 源码、工程配置、资源、验证脚本或 package 边界。

## 10. 剩余风险

- `docs/release/README.md` 仍需在 StoreKit、TestFlight、App Store 隐私标签和权限说明进入实施前补齐。
- 新增 Apple 三端交互与可访问性规范是长期规则入口，不替代后续 UI 任务中的截图、Dynamic Type、VoiceOver、键盘、指针和 Stage Manager 实测。
