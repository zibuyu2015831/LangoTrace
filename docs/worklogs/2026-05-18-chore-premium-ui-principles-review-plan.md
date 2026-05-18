# 工作记录：付费级 UI 设计原则与审查计划

类型：chore

状态：Implemented

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/superpowers/specs/mvp-ui-flow-and-design-system.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 未提交

## 1. 背景

当前项目已经完成 macOS、iPad 和 iOS 三端页面整体搭建，但用户认为页面还不够美观、高级，未达到付费 App 级别的设计感。直接要求 AI “美化页面”容易导致装饰性渐变、卡片堆叠、阴影堆砌或跨平台风格发散，不能稳定服务语迹的产品定位。

用户提出先基于项目定位和愿景设定设计原则与要求，再创建或完善 UI 规范文档，随后基于新规范和开发原则对项目做全面检查，记录问题并给出优化方案。本次工作先完成设计原则与审查计划文档，为后续 UI 审查和实施提供依据。

## 2. 目标

本次工作的目标：

- 把“高级感”转译为可审查、可执行、可验证的设计原则。
- 明确 LangoTrace 付费级 UI 的视觉气质、平台差异、组件方向和禁止项。
- 建立三端 UI 全面审查流程，避免后续 AI 凭主观审美直接改页面。
- 明确审查产物、优先级和后续实施前置条件。

## 3. 范围

本次处理：

- 新增 `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`。
- 记录三端付费级 UI 的设计原则、审查维度、问题记录格式和优化方案结构。
- 明确后续 UI 审查应读取的项目文档和代码范围。
- 明确后续不得直接进入全量视觉重写，应先完成设计审查和样板页面确认。

## 4. 不做什么

本次不处理：

- 不修改 SwiftUI 代码。
- 不调整现有页面布局、颜色、组件或交互。
- 不建立完整品牌手册。
- 不引入真实数据库、真实 AI、语音、同步或 StoreKit。
- 不把设计原则写成已完成的视觉升级成果。
- 不创建新的 ADR；本次没有改变核心产品和架构决策。

## 5. 分析

现有 `docs/spec/003-ui-design-system.md` 已经定义了“安静、清晰、温和、现代、长期可读、学习工具感、个人资料库感”的基本方向，也明确禁止营销首页、游戏化闯关、后台管理系统和 AI 聊天室风格。

当前缺口不是没有 UI 规范，而是缺少一份专门面向“付费级感知质量”的中间层文档。它需要把产品愿景、Apple 三端平台差异、视觉系统、组件质量、状态表达和审查流程连接起来，让后续 UI 改进能先判断问题，再制定样板页面和实施计划。

本次新增规格文档承担这个中间层职责：它不替代 Accepted 状态的 guidelines，而是作为后续全面 UI 审查和视觉升级计划的设计依据。

## 6. 方案

采用“原则先行、规范落地、审查驱动、分批实现”的方案：

1. 先在规格文档中定义 LangoTrace 的付费级 UI 判断标准。
2. 再定义三端审查维度，按 iPhone、iPad、macOS 分别检查平台原生感、信息密度、视觉层级和学习闭环表达。
3. 审查完成后输出问题清单、严重度、证据、建议和优先级。
4. 后续再选择一个三端代表样板页面，先沉淀 token 和组件，再推广到其他页面。

## 7. 风险与边界

- 如果只追求视觉装饰，页面可能短期更漂亮，但会偏离本地优先学习工具的定位。
- 如果一次性要求全项目重写，容易引发平台差异丢失、组件风格不一致和测试成本失控。
- 如果不先做审查，AI 会难以区分真实设计问题、早期 Mock 边界和已被文档接受的阶段性状态。
- 本次文档不代表可以跳过后续 worklog；实际 UI 改造仍影响三端体验，进入实现前需要单独创建或更新实施 worklog。

## 8. 测试与验证

本次是文档任务，完成前检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

本次不运行 `scripts/verify.sh`，因为没有修改 Swift、XcodeGen、package 或资源编译内容。后续进入 UI 代码实现时应按实际改动运行 `scripts/verify.sh`，并增加模拟器截图验证。

## 9. 文档影响检查

- `docs/README.md`：不需要更新。项目当前状态和阅读路径没有变化。
- `docs/product-main-reference.md`：不需要更新。产品定位和核心闭环没有变化。
- `docs/spec/003-ui-design-system.md`：本次不直接修改 Accepted guideline；新增规格文档作为后续审查依据。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：不需要更新，但后续审查必须使用该文档检查本地化文案长度和语言边界。
- `docs/review/`：本次不触发专项审查。没有改变数据库、AI Provider、权限、同步、StoreKit、XcodeGen、包边界、App 启动结构或 ADR。

## 10. 用户确认记录

2026-05-18：用户确认立即进行，创建设计原则与审查计划文档。

## 11. 实施记录

2026-05-18：

- 新增 `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`。
- 新增本 worklog，记录本次文档工作的背景、目标、范围和验证方式。

2026-05-18 深度复审：

- 从系统架构师角度补充工程落地边界：设计 token、平台外壳与共享内容、状态归属、Mock / InMemory 可替换性、View 副作用边界和可测试 helper。
- 从专业 iOS / iPadOS / macOS 交互设计角度补充审查维度：iPhone 小屏与键盘、iPad Split View / Stage Manager、边缘手势替代入口、macOS 菜单栏 / Toolbar / Settings 关系、触控 / 指针 / 键盘 / VoiceOver。
- 补充审查问题类型、验证方式、截图与手动验证矩阵，避免把所有问题笼统归因于“视觉不高级”。
- 补充真实能力与 Mock、数据隐私、平台尺寸、语言本地化和设计债务边界，避免后续 UI 改造误导 AI、同步、语音、购买或导出能力。

## 12. 验证结果

2026-05-18 文档级验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

结果：

- `find docs -maxdepth 3 -type f | sort` 已确认新增文档位于预期目录。
- 占位词扫描无命中。
- `git diff --check` 通过。
- `git status --short` 显示本次新增规格、worklog 和 specs README 修改；另有既存未提交文档改动 `docs/worklogs/2026-05-18-bug-interface-language-settings-detail-localization.md`，本次未修改。

本次未运行 `scripts/verify.sh`，因为没有修改 Swift、XcodeGen、package 或资源编译内容。

2026-05-18 深度复审后补充验证：

```bash
rg -n "^## |^### " docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md docs/worklogs/2026-05-18-chore-premium-ui-principles-review-plan.md
```

结果：

- 章节编号从第 1 节到第 9 节连续，新增小节编号无冲突。
- 新增规格和本 worklog 占位词扫描无命中。
