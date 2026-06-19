# 工作记录：设置与练习状态闭环

类型：feature

状态：Verified

日期：2026-05-17

关联文档：

- `docs/README.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/testing/README.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/archive/superpowers/plans/2026-05-17-settings-and-practice-state-closure.md`

## 1. 背景

上一阶段已经完成最小学习内容模型、iPhone 记录创建与详情、iPad 时间线联动和首批设计组件。当前仍有两个明显缺口：

- 设置页只有静态列表，AI Provider、同步、本地数据、隐私和导出入口不能进入二级说明页。
- 练习入口只展示目标文本，缺少可识别的 mock 会话阶段、不可用状态和结果状态。

这些缺口会让页面看起来仍像静态 Demo，也不利于后续接入真实 AI、语音、同步和存储前保持隐私边界清晰。

## 2. 目标

本次目标：

- 补齐 iPhone 设置二级页面的 mock / unavailable 状态闭环。
- 让练习页从单一文本展示升级为可验证的 mock 会话路径。
- 增加可测试的设置项和练习会话状态模型。
- 更新测试文档和相关规范，记录第二阶段 UI 验证范围。

## 3. 范围

本次处理：

- 在 `LangoTraceData` 增加不触发真实副作用的设置项模型和练习会话状态模型。
- 在 iPhone 设置页增加 AI Provider、同步、本地数据、隐私和导出二级页面。
- 在练习页和记录详情中使用统一的 practice control / state 表达。
- 增加单元测试覆盖模型状态和 repository 练习会话。
- 更新 `docs/testing/README.md` 的手动 UI 验证清单。
- 视实际路由和状态变化更新导航、设计系统或 SwiftUI 架构规范。

## 4. 不做什么

本次不处理：

- 不保存真实 API Key，不读写 Keychain。
- 不触发真实 AI、TTS、Speech、OCR、照片权限、同步或网络请求。
- 不引入 SQLite / GRDB schema、迁移或启动恢复。
- 不实现 macOS 完整工作台命令系统。
- 不把 mock 设置页写成真实配置能力。

## 5. 方案

采用小步闭环：

1. 数据层只增加 UI 可消费的纯值模型，表达 unavailable、mock、ready 等状态。
2. iPhone 设置入口使用 `NavigationStack` 的 value route 进入二级页面；二级页面展示当前能力、不会发生什么、后续真实接入需要什么。
3. 练习会话使用本地 mock 阶段：准备、跟读、对照、完成。按钮只切换本地状态，不播放音频、不录音、不保存结果。
4. 复用现有 `LangoTraceDesign` token 和产品对象组件，避免页面继续散落一次性状态样式。

## 6. 风险与边界

- mock 页面必须明确“不可用但可预览”，避免用户误以为真实 Provider、同步或导出已经完成。
- 设置二级页不能抢占记录和学习主流程；它是低频配置说明，不是新的产品首页。
- 练习会话必须保持与 Entry / Rendering 关联，不能变成脱离生活记录的通用练习页。

## 7. 用户确认记录

2026-05-17：用户在确认下一步任务后要求“立即进行”，本 worklog 进入 `In Progress`。

## 8. 验证方式

开发中：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
```

收尾：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
scripts/verify.sh
git status --short
```

## 9. 文档影响检查

本次影响：

- `docs/README.md`：不改变当前阶段定位，暂不更新。
- `docs/spec/002-navigation-and-routing.md`：已补充配置路由只读说明页边界。
- `docs/spec/003-ui-design-system.md`：已补充能力状态和 mock 练习步骤规范。
- `docs/spec/004-swiftui-architecture.md`：已补充 MVP 早期 mock 纯值状态边界。
- `docs/testing/README.md`：已补充第二阶段手动 UI 验证清单。
- `docs/review/`：本次不接入真实数据库、AI Provider、Keychain、权限、同步或 StoreKit；若只推进 mock 状态闭环，按 worklog 记录影响检查，不触发专项审查。

## 10. 实施记录

2026-05-17：

- 在 `LangoTraceData` 中新增 `CapabilityStatus`、`SettingsCapability`、`PracticeSessionStep` 和 `PracticeSessionState`。
- 将学习内容模型、练习会话状态、设置能力状态和 seed 内容拆成独立文件，避免 `LearningContent.swift` 继续膨胀。
- 为 `InMemoryLearningContentRepository` 增加设置能力列表和 mock 练习会话 helper。
- 增加 Data 测试，覆盖默认设置能力只读、不暗示外部服务，以及 mock 练习会话本地步骤推进。
- 在 iPhone 设置页增加语言空间、AI Provider、同步、本地数据、隐私边界和导出的二级说明路由。
- 新增 `CapabilityStatusRow` 和 `PracticeControlBar`，统一设置、不可用状态和 mock 练习步骤的视觉表达。
- 将 `PracticeSessionView` 改为准备、跟读、对照、完成四步本地状态；不触发音频、录音、AI 请求或持久化。

2026-05-17 严格复查：

- 复查 Data diff，确认学习内容模型、设置能力状态、练习会话状态和 seed 内容已拆分，`LearningContent.swift` 只保留 repository 职责。
- 复查 UI diff，确认设置详情和练习会话均通过 `NavigationStack` value route 进入，页面不直接访问 Keychain、网络、数据库、麦克风或照片权限。
- 复查文档 diff，确认导航、设计系统、SwiftUI 架构和测试文档都已同步当前 mock / unavailable 边界。
- 使用 iPhone 17 模拟器手动冒烟：从 onboarding 创建英语空间，进入设置 Tab，打开 AI Provider 二级页，确认显示当前边界、后续接入条件和“不会发生”；进入练习 Tab，打开跟读会话并点击下一步，确认准备步骤切换到跟读步骤。
- 模拟器截图证据：`/private/tmp/langotrace-ui-review/2026-05-17-stage2-practice-shadow.png`。

2026-05-17 补充单元测试：

- 新增设置能力详情完整性测试，覆盖所有设置项都有唯一 ID、摘要、边界说明和后续接入条件。
- 新增无 rendering 记录的练习会话不可用测试，覆盖不可用状态的数据来源。
- 新增新建记录自动获得 mock rendering 和 local-only practice session 的测试。
- 为 `PracticeSessionState` 增加 `isLocalOnly` 纯值属性，明确 UI 可依赖的本地-only 语义。

## 11. 验证结果

2026-05-17 已执行：

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
swiftlint --no-cache
swiftformat --lint . --cache ignore
scripts/verify.sh
```

结果：

- Data package 8 个测试通过。
- UI package 3 个测试通过。
- `git diff --check` 通过。
- 文档占位词扫描无命中。
- SwiftLint 0 violations。
- SwiftFormat 0/48 files require formatting。
- `scripts/verify.sh` 通过，覆盖 XcodeGen、Core / UI 测试、iPhone 17 构建、iPad Pro 13-inch 构建、macOS arm64 构建、lint、format 和文档占位词扫描。
- 复查阶段再次执行 Data / UI package 测试、文档占位词扫描、`git diff --check` 和 `scripts/verify.sh`，结果保持通过。
