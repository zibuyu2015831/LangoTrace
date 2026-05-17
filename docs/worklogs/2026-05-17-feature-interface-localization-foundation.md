# 工作记录：界面国际化基础落地

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/guidelines/003-ui-design-system.md`
- `docs/guidelines/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `project.yml`

关联 ADR：

- 无

关联提交：

- 未提交

## 1. 背景

新增国际化开发规范草案后，用户要求根据方案立即开发。当前代码仍以中文文案和中文 development language 为主，尚未有界面语言偏好模型，也没有设置入口表达“界面语言、用户母语、目标学习语言三轴分离”。

## 2. 目标

- 增加最小界面语言偏好模型，表达跟随系统、英文和简体中文。
- 让界面语言偏好使用稳定 code，不与语言空间目标语言共用字段。
- 在设置能力列表中加入“界面语言”入口，明确当前只表达边界，不修改语言空间或用户内容。
- 将工程基础开发语言切换为英文 fallback，符合国际化规范。
- 增加对应单元测试，防止界面语言偏好改变语言空间。

## 3. 范围

本次处理：

- Core 层界面语言偏好模型。
- Core / Data 测试。
- Data 层设置能力入口。
- XcodeGen development language 基础配置。
- 文档 worklog 和测试说明。

## 4. 不做什么

- 不全量迁移现有 SwiftUI 文案到 String Catalog。
- 不实现 App 内即时切换语言。
- 不实现 UserDefaults 持久化。
- 不修改 onboarding 母语 / 目标语言流程。
- 不改变真实语言空间持久化、AI Provider、TTS、OCR、同步或 StoreKit。
- 不承诺除英文和简体中文以外的正式界面语言。

## 5. 分析

本次应优先建立可测试的语言边界，而不是直接大规模替换 UI 字符串。理由：

- 当前三端页面还处于 mock 骨架阶段，过早全量本地化会放大维护成本。
- Core 模型先明确后，后续 String Catalog、设置页和 Prompt 构建可以围绕稳定 code 落地。
- 设置能力列表已有 Local Mock / unavailable 表达方式，适合先增加“界面语言”只读入口。

## 6. 方案

采用 TDD：

1. 先增加 Core 测试，要求界面语言偏好支持系统解析、英文 fallback 和稳定存储值。
2. 增加 Core 测试，要求界面语言偏好不会修改 `LanguageSpacePreview`。
3. 增加 Data 测试，要求设置能力中包含 `interfaceLanguage`，并且详情说明不改变母语、目标语言和已生成学习内容。
4. 实现 `InterfaceLanguagePreference` 和 `InterfaceLanguageOption`。
5. 在 `SettingsCapability.Kind` 中加入 `interfaceLanguage`。
6. 调整 `project.yml` 的 `developmentLanguage` 为 `en`。

## 7. 风险与边界

- 本次不会让当前 UI 立即显示英文；只是建立 fallback 和设置入口基础。
- `developmentLanguage` 切换后需要重新生成 Xcode 工程，检查构建是否仍通过。
- 当前设置入口仍是只读说明，不保存真实偏好，避免和系统 per-app language 产生未设计的冲突。

## 8. 测试与验证

开发中执行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

完成前执行：

```bash
scripts/verify.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

## 9. 文档影响检查

- 影响 `docs/testing/README.md`：需要记录国际化基础测试覆盖。
- 影响 `docs/guidelines/006-interface-localization-and-language-boundaries.md`：若实现与草案边界不同，需同步修订。
- 触发专项审查：本次更新 `scripts/verify.sh`，已创建 `docs/review/rounds/2026-05-17-interface-localization-foundation/README.md`。

## 10. 用户确认记录

2026-05-17：用户要求“根据这份方案，立即进行开发”，确认进入实现。

## 11. 实施记录

已实现：

- 新增 `InterfaceLanguagePreference`，表达 `system / en / zh-Hans`、稳定存储值、系统语言解析和英文 fallback。
- 新增 Core 测试，覆盖系统解析、稳定存储值和“不改变语言空间上下文”。
- 在 `SettingsCapability.Kind` 中新增 `interfaceLanguage`，并在内存 repository 设置能力列表中加入只读说明入口。
- 新增 Data 测试，确认“界面语言”设置入口说明不改变用户母语、目标语言或已生成内容。
- 修正 UI 页面闭环测试中的 enum 同名简写，显式使用 `SettingsCapability.Kind.aiProvider` 和 `SettingsCapability.Kind.sync`，避免新增设置项后测试期望被误解析。
- 将 `project.yml` 的 `developmentLanguage` 从 `zh-Hans` 调整为 `en`，与英文 fallback 规则对齐。
- 更新 `docs/testing/README.md`，补充界面国际化基础验证清单。
- 更新 `scripts/verify.sh` 和 `docs/README.md` 的验证脚本展开说明，将 `Packages/LangoTraceData` 测试纳入统一验证。

## 12. 验证结果

已执行开发中验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

结果：

- Core：20 个测试通过。
- Data：9 个测试通过。
- UI：7 个测试通过。

最终完整验证：

```bash
scripts/verify.sh
```

结果：

- Core：20 个测试通过。
- Data：9 个测试通过，已纳入统一验证脚本。
- UI：7 个测试通过。
- iPhone 17 simulator build：通过。
- iPad Pro 13-inch (M5) simulator build：通过。
- macOS arm64 build：通过。
- SwiftLint：0 violations，0 serious。
- SwiftFormat：0/61 files require formatting。
- 文档占位扫描：无匹配。
