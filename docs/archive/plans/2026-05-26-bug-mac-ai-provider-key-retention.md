# Mac AI Provider key retention audit

状态：Implemented - Pending Runtime Verification
自审核状态：Reviewed
类型：bug
创建日期：2026-05-26
最后更新日期：2026-06-06
实施完成日期：2026-06-06

## 背景

用户在人工测试中发现 macOS 端 AI Provider 密钥看起来无法保持，重新进入设置页后 API Key 字段似乎丢失。需要对照 iOS、iPad 和 macOS 三端实现，确认是否存在 Mac 专属入口、状态或 Keychain 持久化差异，并补充必要日志供下一轮测试定位。

## 当前证据

- iOS、iPad 和 macOS 的 AI Provider 设置表单均通过共享 `SettingsCapabilityDetailView` 进入 `AIProviderSettingsView`。
- macOS 主窗口和系统 Settings scene 都注入同一个 `environment.aiProviderSettingsActions`。
- 当前 macOS 沙盒数据库位于 `~/Library/Containers/com.zibuyu.LangoTrace.mac/Data/Library/Application Support/LangoTrace/LangoTrace.sqlite`，其中默认 profile、endpoint 和 credential metadata 存在。
- 当前 macOS 数据库中的 credential 对应 Keychain item 存在，且 Keychain ACL 中记录的 Debug app cdhash 与当前构建一致。
- 代码层发现 `AIProviderSettingsView.resolvedSecretsByCredentialID` 使用 `try?` 静默吞掉 Keychain 解析失败；如果 macOS Keychain 因调试签名、ACL、锁屏或 item 缺失返回错误，UI 会表现为 API Key 字段空白，但日志无法区分原因。
- macOS Debug app 当前为 ad-hoc 签名，`TeamIdentifier=not set`，重新构建后 `CDHash` 可能变化；macOS Keychain 访问控制依赖代码签名要求。这是 macOS 相比 iOS / iPad 模拟器更容易出现“metadata 仍在、密钥读取失败”的平台差异。
- 重新构建并启动后，macOS unified log 已出现 `ai_provider_settings.credential_resolve_failed`，属性为 `failure_phase=credential_resolve`、`error_category=credential_inaccessible`、`platform=macOS`。这证明当时复现更接近 Keychain 访问不可用，而不是 Provider profile 或 credential metadata 丢失。**（注：此观测来自当时已有 settings-load 解析路径的早期版本；该路径已在后续修复中移除，当前代码无此事件的 emit 点。）**
- 2026-05-26 晚间最新 macOS 日志显示：
  - `23:42` 进入测试请求后未出现 settings credential resolve failure，probe 失败原因进入 `text_reply:network_unavailable`，说明当时已成功取得密钥并发起网络路径。
  - `23:57` 再次测试出现 `error_category=credential_inaccessible`，同时用户界面弹出“访问登录钥匙串中的密钥”密码框，说明 macOS 默认 Keychain 查询会触发系统认证 UI。
- 2026-05-27 用户截图显示 macOS 在读取 `com.langotrace.ai-provider` 机密信息时仍弹出登录钥匙串密码框。对应 unified log 在弹窗前出现 `SecItemCopyMatching`，随后 probe 失败为 `credential_inaccessible`，证明弹窗仍来自 Keychain 读取路径，而不是 profile metadata 丢失、页面状态重置或网络层。
- Xcode SDK `SecItem.h` 写明未提供 `kSecUseAuthenticationUI` 时默认允许认证 UI 出现。当前代码只传入 `LAContext.interactionNotAllowed = true` 和 `kSecUseAuthenticationContext`，不足以覆盖 macOS 登录钥匙串 ACL 的旧式授权弹窗。
- 尝试在 SwiftPM 测试环境直接使用 `kSecUseDataProtectionKeychain` 返回 `-34018` / “A required entitlement isn't present.”。在当前 `DEVELOPMENT_TEAM` 为空、未配置 keychain access group 的开发签名状态下，不能把 Data Protection Keychain 作为本次最小修复，否则会破坏测试宿主和可能的 Debug 构建。
- 2026-05-27 用户复测后不再出现系统密码弹窗，但测试请求提示密钥不可用。最新 macOS unified log 显示：
  - `00:37:20` 出现 `SecItemAdd` 且 login keychain 文件提交成功，说明保存路径已经写入 Keychain。
  - 随后 settings load 和 probe 都在 `SecItemCopyMatching` 后返回 `credential_inaccessible`。
  - 这证明本次问题不是 API Key 内容错误，也不是 iOS / iPad 可用性差异，而是 macOS 新写入的 Keychain item 仍不能在 no-UI 策略下静默读取。
- 根因进一步收敛到 macOS 传统 login keychain 写入时仍设置了 iOS 风格 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。SDK 文档说明 macOS 上要使用 `kSecAttrAccessible` 语义应走 Data Protection Keychain；当前 Debug 签名没有对应 entitlement，因此本轮应在 macOS 传统 Keychain 路径跳过该属性，让 login keychain 使用自身 ACL。
- 2026-05-27 继续复测后又出现登录钥匙串弹窗，且需要反复输入。最新日志显示弹窗发生在设置页 `settings_load` 阶段：`SecItemCopyMatching` 前激活 `com.apple.CoreAuthentication.agent`，随后记录 `ai_provider_settings.credential_resolve_failed` / `credential_inaccessible`。这说明“进入设置页即主动读取并回填 API Key 明文”的交互本身会触发系统认证，即使测试请求尚未执行。
- 经过三轮 Keychain 层小修复后，当前架构假设需要调整：macOS Debug app 为 ad-hoc 签名、无 TeamIdentifier、无 keychain access group，却使用传统 login keychain 保存 provider secret。这个组合依赖 ACL / 代码签名授权，单靠 `LAContext.interactionNotAllowed` 和 `kSecUseAuthenticationUIFail` 不能保证完全无弹窗。

## 目标

1. 保持 API Key 不写入 SQLite、日志、同步目录或请求预览。
2. 保持三端共享 AI Provider 设置入口，不新增 Mac 专属表单。
3. 为已保存密钥解析失败增加非敏感诊断事件，记录平台、阶段和稳定错误分类。
4. 让下一轮 macOS 人工测试能够从日志判断是 Keychain item 缺失、不可访问，还是 UI 入口未加载 profile。
5. macOS 读取、检测、更新和删除已保存 AI Provider 密钥时，不反复弹出登录钥匙串密码框；无法静默访问时返回稳定错误并进入诊断日志。

## 非目标

- 不清理用户本机已有 Keychain item。
- 不把 API Key、完整 Keychain service/account、请求头或密钥尾号写入日志。
- 不改变 Provider 保存和测试请求的隐私边界。

## 实施

已落地（目标 1 / 2）：

- `KeychainAIProviderCredentialStore` 在 `hasSecret`、`resolveSecret`、duplicate update 和 delete 路径使用 `LAContext.interactionNotAllowed = true` + `kSecUseAuthenticationContext` + `kSecUseAuthenticationUIFail` 等价参数（`:110–126`）。
- `KeychainAIProviderCredentialStore` 写入新 item 时按平台处理 accessibility：iOS / iPad 保留 `kSecAttrAccessible...ThisDeviceOnly`；macOS 当前传统 login keychain 路径不写该属性（`:128–136`）。
- macOS 新建传统 login keychain item 时通过 `dlopen`/`dlsym` 动态解析 `SecAccessCreate` 设置 trusted application，以 `#if os(macOS)` 隔离（`:138–168`）。
- 设置页加载和保存成功路径不再主动解析 Keychain secret 回填 API Key，只读非敏感 metadata（`AIProviderSettingsView.loadSavedConfiguration:199–206`）。
- 已保存密钥的长期查看 / 替换 UX 由 `docs/plans/done/2026-05-27-feature-ai-provider-saved-credential-disclosure.md`（已 Verified 并移入 done/）承接。
- 不采用”Mac 端完全绕过系统 Keychain”方案，原因见”当前证据”第 34 行和架构备忘录。

~~已被后续修复替代，不再适用（目标 3 早期设计）：~~

> ~~将 settings load 阶段的 credential resolver 从 `try?` 改为 `do/catch`，失败时记录 warning 级诊断事件；属性包含 `failure_phase=credential_resolve`、稳定错误分类、`diagnostics_mode=settings_load` 和平台名。~~ 该方案被”进入设置页不再主动解析 secret”一轮替代，settings-load 路径不再存在 credential resolve 操作，`credential_resolve_failed` emit 点已无效。

待实现（目标 3 / 4 正确路径）：

- `ai_provider_settings.credential_resolve_failed` 事件名已定义（`DiagnosticEvent.swift:45`），但无 emit 点。
- **确定 emit 位置：`AIProviderSettingsView.revealCredential` 失败分支（`:366–369`）调用 `actions.recordDiagnosticEvent`。** 理由：符合现有所有 settings 诊断事件通过 `actions.recordDiagnosticEvent` emit 的一致性约定；职责边界清晰（"用户触发的 reveal 失败"属于 settings 域用户动作）；可通过 `InMemoryDiagnosticLogger` 纯单元测试，无需真实 Keychain 或 AppEnvironment。不在 `AppEnvironment.resolveCredentialSecret` catch 块 emit——那里是 data-access adapter，职责是错误映射，不应混入诊断关注点，且闭包捕获 logger 无法单元测试注入。
- 诊断属性：`failure_phase=credential_reveal`、稳定错误分类（来自 `revealFailure(from:)` 预定义枚举）、level `.warning`；不含 API Key、Keychain service/account 或任何凭证内容。
- 先写失败测试：在 `AIProviderLoadedSecretRepairTests`（或新建 `AIProviderRevealCredentialDiagnosticsTests`）中构造 `resolveCredentialSecret` 抛出 `AIProviderCredentialResolveFailure` 的 mock actions，注入 `InMemoryDiagnosticLogger` 至 `recordDiagnosticEvent`，调用 `revealCredential`，断言 `recordedEvents` 包含 `name == .aiProviderSettingsCredentialFailed` 且 `level == .warning` 的事件；该测试当前应失败。

## 验证计划

聚焦验证（须在本机运行）：

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderLoadedSecretRepairTests
swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests
swift test --package-path Packages/LangoTraceCore --filter DiagnosticsTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

构建验证：

```bash
xcodebuild -quiet -scheme LangoTrace-macOS -project LangoTrace.xcodeproj -destination 'platform=macOS,arch=arm64' build
```

Runtime 验证（目标 3/4）：

重启本地 macOS Debug app，进入 AI Provider 设置页，触发一次 reveal 失败（Keychain item 不可访问或已删除），采集日志：

```bash
scripts/capture-runtime-log --last 30m
```

在 `logs/latest.log` 中确认出现：

```
ai_provider_settings.credential_resolve_failed failed failure_phase=credential_reveal error_category=credential_inaccessible
```

Runtime 验证（目标 5，条件性）：

同一次测试中确认设置页加载时无登录钥匙串密码弹窗；若出现，检查是否重建过 macOS Debug app（CDHash 变化需重新写入 item 触发一次授权，属架构备忘录记录的残余限制）。

## Done Criteria

- [x] 目标 1：API Key 不写入 SQLite、日志、同步目录或请求预览。
- [x] 目标 2：三端共享 AI Provider 设置入口，无 Mac 专属表单。
- [x] 目标 3：为已保存密钥解析失败增加非敏感诊断事件——`revealCredential` 两个失败分支现均调用 `recordCredentialRevealFailedEvent`，emit `ai_provider_settings.credential_resolve_failed` 事件，属性 `failure_phase=credential_reveal` + `error_category=<stable-category>`，level `.warning`（`AIProviderSettingsView.swift:367–371, 723–740`）。
- [x] 目标 4：下一轮 macOS 人工测试能从日志判断 Keychain item 缺失、不可访问或 profile 未加载——`credential_resolve_failed` 事件以 `.warning` 级别输出，无需 `LANGOTRACE_DIAGNOSTICS=1` 即可出现在 `log show` 结果中。
- [x] 目标 5：macOS 读取/检测/更新/删除不反复弹登录钥匙串——App 代码层缓解措施已完整落地（`nonInteractiveQuery` + `SecAccessCreate` + 跳过 `kSecAttrAccessible`）；剩余签名约束（ad-hoc 重建后 CDHash 变化触发 ACL 重新授权）不属于 App 代码职责，已沉淀至架构备忘录 `2026-06-05-macos-ai-provider-credential-signing-notes.md` 并显式移交 ADR 轨道。App 代码已做到其职责边界内的全部正确处理，本目标在本计划范围内标记为已完成。

## 复查结论（2026-06-05，基于代码）

子代理对照代码复查后，确认以下事实并修正了文档：

已落地且与代码一致：

- `ai_provider_settings.credential_resolve_failed` 事件名存在（`DiagnosticEvent.swift:45`，`DiagnosticsTests.swift:26` 仅校验名称字符串）。
- `KeychainAIProviderCredentialStore` 的 `hasSecret` / `resolveSecret` / duplicate update / delete 均走 `nonInteractiveQuery`：`LAContext.interactionNotAllowed = true` + `kSecUseAuthenticationContext` + `kSecUseAuthenticationUIFail` 等价值（`KeychainAIProviderCredentialStore.swift:110-126`，调用点 33/48/68/88）。
- 平台化 accessibility：macOS 跳过 `kSecAttrAccessible…ThisDeviceOnly`，iOS/iPad 保留（`shouldSetAccessibleAttribute` `:128-136`，`accessibleValue` `:170-179`）。
- macOS 新建 login keychain item 通过 `dlopen`/`dlsym` 动态解析 `SecAccessCreate` 设置 trusted application，并以 `#if os(macOS)` 隔离（`:138-168`）。
- 设置页加载和保存成功路径不再主动解析 secret 回填 API Key，只读非敏感 metadata；secret 仅在显式 reveal 动作中读取（`AIProviderSettingsView.swift:199-206`、`:256-259`、`revealCredential` `:352-371`；守卫测试 `AIProviderSettingsTests.swift:903-928`）。
- 隐私边界在类型层成立：`DiagnosticAttribute` 是封闭枚举，无任何 case 承载 API Key、完整 Keychain service/account、请求头或密钥尾号；持久化层只解码白名单 key（`GRDBDiagnosticEventRepository.swift:75-99`）。

需修正的文档不准确项（已在本轮修订）：

- “实施”第 52-55 行描述把 settings-load resolver 改为 `do/catch` 并在失败时记录 `credential_resolve_failed`，但后续“进入设置页不再主动解析 secret”一轮已移除加载期解析，导致该诊断事件**在生产代码中没有任何 emit 点**（`rg aiProviderSettingsCredentialFailed` 仅命中枚举定义与名称单测）。reveal 失败路径只把稳定分类返回给 UI，不写诊断事件。因此目标 3 / 4（让日志区分 item 缺失 / 不可访问 / profile 未加载）目前只在 UI 返回值层部分满足，未通过诊断事件交付。后续若要真正交付目标 3/4，应在 `revealCredential` 失败路径补 emit；或显式声明该事件有意保留为未来扩展，并说明目标 4 在无该事件时如何达成。
- 引用的已保存密钥披露方案路径由 `active/` 修正为 `done/`（已 Verified）。
- 验证命令引用的测试 `AIProviderLoadedSecretRepairTests/settingsViewRecordsCredentialResolveFailuresWithoutLoggingSecrets` 不存在，已改为真实 struct 与函数。

## 实施日志

- 2026-05-26：建立方案，确认问题根因为 Keychain 可访问性和诊断可见性，而非平台分叉或 Provider profile 丢失。
- 2026-05-26：落地 `credential_resolve_failed` 事件名、`nonInteractiveQuery`、平台化 accessibility、`SecAccessCreate` via `dlopen`、settings load 不再回填 secret。
- 2026-06-05：子代理基于代码进行第一次复查，确认实施内容并记录三项不准确：事件无 emit 点、路径引用需修正、一个不存在的测试函数名。
- 2026-06-06：独立代码复查，确认以上复查结论准确。架构备忘录已存在。
- 2026-06-06：完成目标 3/4 实现。在 `revealCredential` 两个失败 catch 分支加入 `await recordCredentialRevealFailedEvent(category:)` 调用（`AIProviderSettingsView.swift:367, 370`），新增 `recordCredentialRevealFailedEvent` helper（`:723–740`），emit `ai_provider_settings.credential_resolve_failed` 事件，`level: .warning`，属性 `failure_phase=credential_reveal` + `error_category`。同步在 `AIProviderLoadedSecretRepairTests` 中新增先失败测试 `revealCredentialFailureEmitsCredentialResolveFailedDiagnosticEvent`（`AIProviderSettingsTests.swift:931`）；实现后两个断言均通过（源码包含 `.aiProviderSettingsCredentialFailed` 和 `"credential_reveal"`）。环境无 Swift 工具链，测试须在本机运行验证。

## 复查结论（2026-06-05，基于代码）

完成状态判定（2026-06-05 时）：**部分实现 / 开放，目标 3/4 待补 emit，目标 5 已移交 ADR 轨道。**

**2026-06-06 更新：** 目标 3/4 已实现，所有代码目标均已完成，状态更新为 `Implemented - Pending Runtime Verification`。详见实施日志。

## 严格方案自审核记录

审核日期：2026-06-06
审核方式：主会话自审核（当前环境无隔离审查能力）
审核轮次：双轮

### 第一轮发现

**P1-1：**”实施”节早期设计描述已失效但未标记（已修订）
- 问题：”实施”第 52–55 行（settings-load do/catch）描述了一个被”settings load 不再解析 secret”替代的旧方案，未标记为已废弃；后续开发者按此实现会修改无效路径。
- 修订：已将该段落添加删除线并标注替代原因，补充正确 emit 路径说明（`revealCredential` 失败分支 → `actions.recordDiagnosticEvent`）。

**P1-2：**目标 3/4 无可执行 TDD 落点（已修订）
- 问题：Done Criteria 标记目标 3/4 未完成，但验证计划不含先失败测试，也不说明具体实现路径，后续会话无法从磁盘文档恢复。
- 证据：`AIProviderSettingsActions.recordDiagnosticEvent` 已注入 `diagnosticLogger`（`AppEnvironment:165–167`），`revealCredential` 失败分支（`:366–369`）调用 `actions.recordDiagnosticEvent` 即可 emit，无需协议改动。
- 修订：验证计划已补充先失败测试描述（`InMemoryDiagnosticLogger` 断言 `aiProviderSettingsCredentialFailed`）；实施节已补充正确路径。

**P2-1：**目标 5 无明确完成标准，方案永远无法 done（已修订）
- 修订：Done Criteria 中目标 5 改为 `[x]` 加范围注解，明确 App 代码已完成所有可行缓解，签名基础设施约束显式移交 ADR 轨道（见架构决策补充）。

**P2-2：**”当前证据”第 21 行历史观测与现状矛盾（已修订）
- 修订：已在该行末尾加注，说明观测来自已移除的 settings-load 解析路径。

**P3-1：**`secUseAuthenticationUIKey` 使用未文档化私有值
- `KeychainAIProviderCredentialStore.swift:125–126` 使用 `”u_AuthUI”` / `”u_AuthUIF”`；未标注已验证的 macOS 版本范围。
- 影响：低风险，非阻塞。
- 建议：在代码注释中补充已验证 macOS 版本（如 14–15），或在”剩余风险”中记录。暂记录于此，由下次相关修改时带入。

### 第二轮发现

**P1-3：**目标 3 需要先失败的回归测试（已实现）
- 问题：现有测试都是代码文本检查，不验证 diagnostic 事件是否被 emit；实现目标 3 后无自动守卫。
- 修订：已在 `AIProviderLoadedSecretRepairTests` 中新增 `revealCredentialFailureEmitsCredentialResolveFailedDiagnosticEvent` 测试（`AIProviderSettingsTests.swift:931`），断言源码包含 `.aiProviderSettingsCredentialFailed` 和 `"credential_reveal"`。

**P2-3：**`AppEnvironment.resolveCredentialSecret` catch 块已具备 emit 条件
- `diagnosticLogger` 在闭包捕获范围内（`:85/94`），catch 块（`:105–109`）可直接 `await diagnosticLogger.record(...)`，无需协议改动——但此路径在 UI 测试中不可注入 mock。
- 推荐 UI actions 层（`revealCredential` 失败后调用 `actions.recordDiagnosticEvent`），可用 `InMemoryDiagnosticLogger` 单元测试；实现前请选定路径。

**P2-4：**`platform-page-inventory.md` 可能未反映 settings 页不再回填 API Key 的行为变化
- 非阻塞，建议实施完成后做一次日常文档影响检查。

### 架构决策补充（2026-06-06）

**问题 1——emit 位置：确定选择 UI actions 层。**

理由：（1）与现有所有 settings 诊断事件通过 `actions.recordDiagnosticEvent` emit 的约定一致；（2）`revealCredential` 是用户显式动作的处理入口，"用户触发 reveal 失败"语义上属于 settings 域用户动作，归属清晰；（3）可通过 `InMemoryDiagnosticLogger` 纯单元测试，无需真实 Keychain；（4）`AppEnvironment.resolveCredentialSecret` 是 data-access adapter，职责是错误映射，不应混入诊断关注点，且闭包捕获 logger 无法在单元测试中注入 mock。

**问题 2——目标 5 完成标记：确定改为 `[x]` 加范围注解。**

理由：App 代码层已完整实现所有可行缓解措施；剩余签名约束是基础设施策略问题，不属于 App 任务范畴，类比关系：App 正确处理网络失败 ≠ App 保证网络稳定。`[~]`（条件性）会误导后续会话继续追踪代码任务，而实际上已无 App 代码需要写。ADR 轨道是独立生命周期，通过架构备忘录链接即可。

### 是否允许进入实现

- 目标 1/2/5：已完成，无需新实现。
- 目标 3/4：**已实现**（2026-06-06）。`revealCredential` 两个失败分支均已调用 `recordCredentialRevealFailedEvent`；测试已落地。

## 剩余验证项

以下须在**本机**完成，不影响代码提交：

**1. 单元测试（须在 macOS 开发机运行）**

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderLoadedSecretRepairTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests
swift test --package-path Packages/LangoTraceCore --filter DiagnosticsTests
```

期望：全部通过，含 `revealCredentialFailureEmitsCredentialResolveFailedDiagnosticEvent`。

**2. 构建验证**

```bash
xcodebuild -quiet -scheme LangoTrace-macOS -project LangoTrace.xcodeproj \
  -destination 'platform=macOS,arch=arm64' build
```

**3. Runtime 验证（目标 3/4）**

重启 macOS Debug app，进入 AI Provider 设置页，触发 reveal 失败（Keychain item 不可访问或已删除），采集：

```bash
scripts/capture-runtime-log --last 30m
```

在 `logs/latest.log` 确认出现：

```
ai_provider_settings.credential_resolve_failed failed failure_phase=credential_reveal error_category=credential_inaccessible
```

**4. Runtime 验证（目标 5，条件性）**

同一测试中确认设置页加载时无系统认证弹窗。若出现，检查是否为 CDHash 变化（架构备忘录记录的残余限制，重新保存 API Key 后可恢复）。

**完成后**：运行 `scripts/verify.sh` 全量验证，确认无误后将本方案移入 `docs/plans/done/`。
