# 工作记录：付费级 UI 收敛完成扫尾

类型：feature

状态：Implemented

日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/superpowers/specs/2026-05-18-premium-ui-principles-and-review-plan.md`
- `docs/worklogs/2026-05-18-feature-premium-ui-audit.md`
- `docs/worklogs/2026-05-18-feature-interface-premium-ui-convergence.md`
- `docs/worklogs/2026-05-18-feature-premium-ui-page-rollout.md`
- `docs/testing/2026-05-18-premium-ui-completion-verification.md`

关联 ADR：

- `docs/decisions/002-use-swiftui-multiplatform.md`
- `docs/decisions/004-use-language-space-as-primary-model.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

关联提交：

- 本阶段提交

## 1. 背景

严格复查确认：阶段 2 和阶段 3 第一批提交已经通过构建、测试、lint 和关键回归扫描，但仍留下全量 SwiftUI chrome 本地化、request preview 本地化、Data mock 边界说明和第四阶段质量验证清单等未完成项。

本轮目标是一次性完成“UI 收敛范围内”的剩余项。真实 SQLite / GRDB、真实 AI Provider、真实 TTS / Speech / OCR / Photos、同步、StoreKit、导入导出和发布材料属于产品路线，不在本轮伪装完成。

## 2. 方案

1. 将 `Packages/LangoTraceUI/Sources/LangoTraceUI` 内剩余硬编码中文 UI chrome 迁入 `Localizable.xcstrings`。
2. 为需要在 SwiftUI `locale` 环境中刷新的文案使用 `localizedText(_:)` 或 key-based View；模型中只保留 stable key，不保留中文展示值。
3. 将 `RequestPreviewCopy` 从 raw 中文文案改为 key + 动态字段组合，保留 Local Mock 与真实 external request 的语义区分。
4. 保留 `LangoTraceData` 中 seed entry、用户内容、目标语言句子、mock note 等内容资产，但在 worklog 中明确它们不是 App chrome。
5. 增加测试扫描：UI Swift 源码不再包含中文字符；Data 中只允许 mock content 文件保留中文，不允许设置能力 chrome 回流。
6. 新增第四阶段质量验证清单文档，覆盖 iPhone / iPad / macOS 截图矩阵、Dynamic Type、VoiceOver、键盘焦点、Reduce Motion 和深色模式边界。

## 3. 不做什么

- 不接入真实照片、OCR、TTS、Speech、搜索、SQLite / GRDB、embedding、同步、导入导出或 StoreKit。
- 不把深色模式、真实 AI、真实语音、真实搜索、真实同步或真实购买写成已完成能力。
- 不把 Data seed 用户内容强行翻译成界面语言；这些内容用于验证生活记录和目标语言材料的混合语言边界。
- 不做大规模视觉重写；本轮只完成前面检查确认的收敛缺口。

## 4. 验证计划

完成前运行：

```bash
ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'
rg -n '[\p{Han}]' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

## 5. 实施记录

- `LangoTraceUI` 剩余 SwiftUI chrome 已迁移为 key-based 渲染，覆盖 iPhone、iPad、macOS 主页面、辅助栏、Inspector、request preview、accessibility label / value / hint 和 onboarding hint。
- `RequestPreviewCopy` 改为从 `Localizable.xcstrings` 读取 Local Mock 与 external request 两套正文，动态字段只保留 entry title 和 prompt label，不在 Swift 源码中写中文 chrome。
- `LocalizedChrome` 增加 `.xcstrings` 读取器，用同一份 String Catalog 支撑 SwiftUI `Text` 和运行时字符串组合，避免 SwiftPM 测试环境只复制原始 catalog 时动态 key 回退为 key 本身。
- `PadFilter`、`PadWorkspaceRoute`、`MacWorkspaceSection` 等模型只暴露 stable localization key；展示层负责本地化。
- `LangoTraceData` seed 内容保持为生活记录、目标语言句子和 mock note，不作为 App chrome 强行翻译。
- 新增 `docs/testing/2026-05-18-premium-ui-completion-verification.md`，记录本轮自动化门禁和发布前手工截图补证矩阵。

## 6. 验证结果

- `ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'` 通过。
- `rg -n '[\p{Han}]' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'` 无命中。
- `swift test --package-path Packages/LangoTraceUI` 通过，23 个 Swift Testing 用例通过。
- `scripts/verify.sh` 通过：包含 `xcodegen generate`、Xcode project list、Core / Data / UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat lint、docs placeholder scan 和最终 status 输出。
- `swiftlint --no-cache` 复查为 0 violations、0 serious。
- `rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'` 无命中。
- `git diff --check` 通过。
- 最终提交前 `git status --short` 中另有非本轮 UI 收尾范围的 `.gitignore` 改动，未纳入本轮提交。
