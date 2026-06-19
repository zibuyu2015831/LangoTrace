# 任务方案：宽屏首次创建 CTA 与 Mac 同步范围开关修正

状态：Verified
类型：bug
创建日期：2026-05-20
最后更新日期：2026-05-20

## 1. 背景

在 iPad / macOS 同步设置适配提交后，人工验证发现两个 UI 问题：

1. 首次打开 App 的创建语言空间页面，底部“创建语言空间”按钮在 macOS 宽窗口、iPad 横屏和 iPad 竖屏下横向过长；iPad 宽屏时顶部内容又过于贴近上方，CTA 贴近底部，与 Welcome 页的页面节奏不一致。
2. macOS 工作台的“同步”设置页面中，“照片附件”和“音频附件”虽然已经是可切换草稿项，但 macOS 默认 `Toggle` 呈现为 checkbox，不符合 iOS 端已确认的开关式表达。

这两个问题都属于平台视觉承载层缺口，不改变产品同步策略、数据范围或真实同步能力边界。

## 2. 决策

采纳推荐方案 A：做最小 UI 修正，保持现有信息架构和共享组件。

- `OnboardingView` 在 compact 宽度继续使用 `safeAreaInset(edge: .bottom)` 的 sticky 主操作；在 iPad regular 宽屏和 macOS 宽窗口下改为内容流内 CTA。
- “创建语言空间”按钮不再在 Mac 宽窗口或 iPad 宽画布下铺满整屏；iPad / Mac 宽屏下主内容整体下移，CTA 跟随表单内容形成居中的主操作区域。
- `SyncScopeRow` 中只有附件草稿项继续显示交互控件，并显式使用 switch 样式。
- 固定纳入项、向量索引和密钥凭证仍使用状态文字或 badge，不改成开关，避免用户误以为当前 Local Mock 已具备完整同步范围控制。

## 3. 实施方案

### 3.1 Onboarding 底部 CTA

修改文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift`

实施要求：

- 为 `OnboardingView` 增加明确的底部行动区宽度常量，例如：
  - `contentMaxWidth = 680`
  - `bottomActionMaxWidth = 520`
- `createButton` 内层 `VStack` 或按钮容器设置 `.frame(maxWidth: bottomActionMaxWidth)`。
- compact 分支的外层 material 背景可以继续覆盖窗口底部，但交互内容必须 `.frame(maxWidth: .infinity, alignment: .center)` 居中。
- regular 宽屏分支使用 `wideOnboardingContent(size:)`，把 `inlineCreateButton` 放入页面内容流，参考 Welcome 页的 iPad 视觉节奏下移顶部内容，并避免 CTA 贴底。
- 按钮可以在 520pt 内铺满，不允许在 2048pt 宽窗口或 iPad 横竖屏下铺满整屏。

验收点：

- Mac 宽窗口、iPad 横屏和 iPad 竖屏下 CTA 形成收敛的居中主操作区域，不再贴底。
- iPad 横屏和竖屏下顶部标题区域不能过度贴近状态栏，应参考 Welcome 页形成更舒展的垂直节奏。
- iPhone / iPad 窄宽度仍保持底部主操作按钮易触达。
- 不新增 Mac 专属 Onboarding 视图，避免三端首次启动语义分叉。

### 3.2 同步范围开关样式

修改文件：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncSettingsView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/SyncSettingsTests.swift`

实施要求：

- `SyncScopeRow` 中 `item.kind.isUserToggleableDraft` 分支保留 `Toggle(isOn:)`。
- 对该 Toggle 显式添加 `.toggleStyle(.switch)`。
- 保留 `.labelsHidden()`、`.tint(...)`、accessibility label/value。
- 不把不可切换项改为 `Toggle`。

验收点：

- macOS 上“照片附件”和“音频附件”呈现为 switch，而不是 checkbox。
- iOS / iPad 上仍是开关式表达。
- 生活记录、学习材料、Prompt Preset、AI 生成内容、向量索引、密钥凭证仍不是用户可切换控件。

## 4. 测试方案

先写失败测试，再实现：

1. `PageClosureStateTests` 增加源码级测试，确认 `OnboardingView.swift` 存在底部行动区最大宽度约束，且底部内容居中承载。
2. `PageClosureStateTests` 增加源码级测试，确认 Onboarding 在 iPad / Mac 宽屏下使用 inline CTA，而不是 pinned bottom action。
3. `SyncSettingsTests` 增加源码级测试，确认同步附件 Toggle 显式使用 `.toggleStyle(.switch)`。
3. 运行聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI --filter PageClosureStateTests
swift test --package-path Packages/LangoTraceUI --filter SyncSettingsTests
```

4. 运行完整验证：

```bash
scripts/verify.sh
```

## 5. 非目标

- 不实现真实 CloudKit、S3、R2、WebDAV 或数据库同步。
- 不写入 Keychain。
- 不改同步范围默认策略。
- 不重做 Mac Settings scene 或工作台整体信息架构。
- 不改变首次启动创建语言空间的数据模型。

## 6. 文档影响

实现完成后需要：

- 将本方案状态更新为 `Verified` 并移入 `docs/plans/done/`。
- 如代码事实影响 `docs/platform-page-inventory.md` 中 Mac onboarding 或同步设置页面描述，应同步更新。
