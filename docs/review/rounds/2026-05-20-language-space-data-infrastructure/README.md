# 2026-05-20 语言空间数据基础设施专项审查

状态：Verified
类型：专项审查
启动时间：2026-05-20
完成时间：2026-05-20
代码快照：`a6e4c46bc26d3aa2d7b612360eac529b13f7e89a` 加本轮未提交工作区改动

## 1. 审查范围

本轮审查由语言空间数据基础设施任务触发，覆盖：

- Core 语言空间模型、输入规范化、软删除展示投影。
- Data SQLite / GRDB schema、migration、Repository、Application Support 数据库位置、当前空间本地状态、soft delete 和 fallback。
- AppSessionState 启动恢复、新增、切换、重命名、删除 fallback 和根路由保护。
- iPhone 设置页语言空间管理入口。
- 对应单元测试、源码级 UI 测试和长期文档事实源。

不覆盖：

- Entry、Rendering、Practice、Memory 的真实数据库表。
- 附件、导出、同步、StoreKit、AI Provider、TTS、Speech、OCR。
- iPad / macOS 完整语言空间管理 UI。

## 2. 发现与处理

### F1：missing current fallback 未实现

问题描述：`currentLanguageSpace()` 只处理 current 指向 deleted 空间的情况；当 `app_state.current_language_space_id` 指向不存在的 ID 时会返回 nil，和方案中 missing / deleted 统一 fallback 的要求不一致。

涉及代码：

- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLanguageSpaceRepository.swift`
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/LanguageSpaceRepositoryTests.swift`

处理结果：已新增 `repairCurrentLanguageSpaceID(using:db:)`，missing / deleted / nil current 都会尝试 fallback 到最近使用 active 空间并修复 `app_state`；无 active 空间时写回 nil。

复查方法：新增 `repositoryRepairsMissingCurrentLanguageSpaceID` 测试，直接篡改 `app_state` 为 missing ID 后验证 fallback 和修复。

### F2：iOS 管理页缺少重命名闭环

问题描述：方案完成标准要求 iOS 设置页支持新增、切换、重命名、删除；当前 UI 只支持新增、切换、删除。

涉及代码：

- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`

处理结果：已新增 `updateLanguageSpace(id:input:)` AppSessionState action，Root / PhoneMain 通过 action closure 传入管理页；管理页新增 edit mode 和 rename action，继续保持 UI 不直接持有 GRDB / SQL。

复查方法：新增源码级 UI 测试确认 `case edit(LanguageSpace)`、`UpdateLanguageSpaceInput`、`onUpdate(space.id,input)` 和 Phone settings route 的 update closure 存在。

### F3：长期文档仍描述旧事实

问题描述：`docs/README.md`、模块边界和数据规范仍把语言空间持久化、SQLite / GRDB repository 视为未完成，和当前实现不一致。

涉及文档：

- `docs/README.md`
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/development/environment.md`
- `docs/development/mvp-development-roadmap.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/navigation/impl.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/testing/README.md`

处理结果：已更新为“语言空间已落地真实 SQLite / GRDB 基础设施；Entry、附件、导出、同步等仍未完成”的分层事实，避免把语言空间完成状态和完整数据层完成状态混淆。

复查方法：重新搜索语言空间、SQLite / GRDB、Repository、已完成/尚未完成相关条目，确认长期文档不再声称语言空间持久化仍完全未完成。

### F4：重命名后 row action 可访问性标签复用旧状态

问题描述：iPhone 人工验收时，`Work English` 重命名为 `Travel English` 后，视觉列表已更新，但辅助操作树仍显示 `Delete Work English`。这说明 SwiftUI row 复用可能让 swipe / context action 暂时保留旧状态。

涉及代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LanguageSpaceManagementView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LanguageSpaceManagementTests.swift`

处理结果：已在语言空间 row 上增加 `.id(space.updatedAt)`，让更新后的 row action 随 repository 更新结果刷新；源码级测试补充该边界。

复查方法：重新安装更新后的 iPhone build，进入语言空间管理页确认重命名后的辅助操作树显示 `Delete Travel English`。

## 3. 剩余风险

- AppSessionState 目前没有独立可运行的单元测试 target；现阶段通过 Core/Data/UI package 测试和 app build 验证，后续若继续增加启动恢复错误态，应补 App 层测试 target 或把状态机抽入可测 package。
- 新增语言空间管理文案目前以 en / zh-Hans 为主；后续在完整人工验收或发布前应补齐全部 `CFBundleLocalizations` 对应翻译。
- iPad / macOS 只共享底层状态和路由保护，完整管理页需在 iOS 人工验收后按平台设计单独补齐。

## 4. 验证记录

已运行：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
```

结果：

- Core：31 tests passed。
- Data：19 tests passed。
- UI：122 tests passed。
- `scripts/verify.sh`：通过，包含 XcodeGen、三端 build、SwiftLint、SwiftFormat 和文档占位扫描。
- `find docs -maxdepth 3 -type f | sort`：完成。
- 文档占位扫描：无匹配。
- `git diff --check`：通过。
- iPhone 17 Simulator 人工验收：通过，覆盖首次创建、数据库落盘、重启恢复、新增同目标语言空间、切换、重命名、删除非当前空间、删除最后空间回 onboarding，以及 SQLite active 数和 current state 复查。
