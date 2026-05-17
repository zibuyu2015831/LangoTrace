# 文档审查：界面国际化基础与验证脚本

审查类型：专项审查

日期：2026-05-17

代码快照：`39e1ada` 之后的工作区改动

状态：Verified

## 1. 触发原因

界面国际化基础落地时新增了 `Packages/LangoTraceData` 测试，并更新 `scripts/verify.sh` 将 Data package 测试纳入统一验证。根据 `docs/review/README.md`，验证脚本变化默认触发专项审查。

## 2. 审查范围

- `scripts/verify.sh`
- `docs/README.md` 中验证脚本展开说明
- `docs/testing/README.md`
- `docs/guidelines/006-interface-localization-and-language-boundaries.md`
- `docs/worklogs/2026-05-17-feature-interface-localization-foundation.md`

## 3. 相关源码、脚本和配置

- `Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift`
- `Packages/LangoTraceCore/Tests/LangoTraceCoreTests/InterfaceLanguagePreferenceTests.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/SettingsCapability.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/SettingsCapabilityTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`
- `project.yml`

## 4. 结论摘要

- `scripts/verify.sh` 和 `docs/README.md` 的脚本展开说明已同步加入 `swift test --package-path Packages/LangoTraceData`。
- `docs/testing/README.md` 已补充界面国际化基础验证清单。
- 国际化 guideline 已明确当前只是基础模型、设置入口和验证规则，不声称已完成 String Catalog 全量迁移或 App 内即时切换。
- 未发现 ADR 冲突：界面语言偏好未写入语言空间主数据、同步 manifest 或学习记录。

## 5. 问题清单

本轮未发现需要阻断当前实现的问题。

已识别但延后：

- String Catalog 全量迁移尚未开始。
- App 内界面语言即时切换、UserDefaults 持久化和系统 per-app language 关系仍需单独计划。
- RTL、伪本地化和本地化截图验证仍属于后续设计系统阶段。

## 6. 文档修改记录

- 更新 `docs/README.md`：验证脚本展开说明加入 Data package 测试。
- 更新 `docs/testing/README.md`：新增界面国际化基础验证清单。
- 更新 `docs/worklogs/2026-05-17-feature-interface-localization-foundation.md`：记录实现和验证脚本影响。

## 7. 用户澄清

无。

## 8. 延后项和原因

- String Catalog：当前页面文案仍处于 mock 骨架和视觉优化前阶段，先建立语言边界和测试基础。
- App 内语言切换：需要单独设计系统 per-app language、Locale 注入、系统 UI 和持久化优先级。
- 发布本地化：StoreKit、权限和 App Store 元数据尚未进入发布阶段。

## 9. 验证命令与结果

已执行：

```bash
scripts/verify.sh
```

结果：

- Core：20 个测试通过。
- Data：9 个测试通过。
- UI：7 个测试通过。
- iPhone 17 simulator build：通过。
- iPad Pro 13-inch (M5) simulator build：通过。
- macOS arm64 build：通过。
- SwiftLint：0 violations，0 serious。
- SwiftFormat：0/61 files require formatting。
- 文档占位扫描：无匹配。

## 10. 剩余风险

- 当前没有执行本地化截图或运行时语言切换验证，因为本次未实现真实 String Catalog 和界面语言切换。
- 当前设置入口仍是 Local Mock / 只读说明，不能视为用户可配置语言偏好的完整功能。
