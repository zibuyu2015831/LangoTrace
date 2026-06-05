# Mac AI Provider key retention audit

状态：In Progress
自审核状态：Not Reviewed
类型：bug
创建日期：2026-05-26
最后更新日期：2026-05-26

## 背景

用户在人工测试中发现 macOS 端 AI Provider 密钥看起来无法保持，重新进入设置页后 API Key 字段似乎丢失。需要对照 iOS、iPad 和 macOS 三端实现，确认是否存在 Mac 专属入口、状态或 Keychain 持久化差异，并补充必要日志供下一轮测试定位。

## 当前证据

- iOS、iPad 和 macOS 的 AI Provider 设置表单均通过共享 `SettingsCapabilityDetailView` 进入 `AIProviderSettingsView`。
- macOS 主窗口和系统 Settings scene 都注入同一个 `environment.aiProviderSettingsActions`。
- 当前 macOS 沙盒数据库位于 `~/Library/Containers/com.zibuyu.LangoTrace.mac/Data/Library/Application Support/LangoTrace/LangoTrace.sqlite`，其中默认 profile、endpoint 和 credential metadata 存在。
- 当前 macOS 数据库中的 credential 对应 Keychain item 存在，且 Keychain ACL 中记录的 Debug app cdhash 与当前构建一致。
- 代码层发现 `AIProviderSettingsView.resolvedSecretsByCredentialID` 使用 `try?` 静默吞掉 Keychain 解析失败；如果 macOS Keychain 因调试签名、ACL、锁屏或 item 缺失返回错误，UI 会表现为 API Key 字段空白，但日志无法区分原因。
- macOS Debug app 当前为 ad-hoc 签名，`TeamIdentifier=not set`，重新构建后 `CDHash` 可能变化；macOS Keychain 访问控制依赖代码签名要求。这是 macOS 相比 iOS / iPad 模拟器更容易出现“metadata 仍在、密钥读取失败”的平台差异。
- 重新构建并启动后，macOS unified log 已出现 `ai_provider_settings.credential_resolve_failed`，属性为 `failure_phase=credential_resolve`、`error_category=credential_inaccessible`、`platform=macOS`。这证明当前复现更接近 Keychain 访问不可用，而不是 Provider profile 或 credential metadata 丢失。
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

- 新增 `ai_provider_settings.credential_resolve_failed` 诊断事件名。
- 将 settings load 阶段的 credential resolver 从 `try?` 改为 `do/catch`，保留成功回填逻辑，失败时记录 warning 级诊断事件。
- 诊断属性仅包含 `failure_phase=credential_resolve`、稳定错误分类、`diagnostics_mode=settings_load` 和平台名。
- App Shell 将 Keychain resolver 的 `missingCredential` 和 `credentialInaccessible` 映射为 Core 层稳定分类，避免 UI 只能记录 `credential_inaccessible`。
- `KeychainAIProviderCredentialStore` 在 `hasSecret`、`resolveSecret`、duplicate update 和 delete 路径使用 `LAContext.interactionNotAllowed = true` + `kSecUseAuthenticationContext` 的非交互查询，并额外显式设置 `kSecUseAuthenticationUIFail` 等价参数。这样 Keychain 仍负责加密存储和读取，但 App 不主动触发登录钥匙串密码弹窗；若 macOS 因锁定、ACL 或调试签名变化无法静默授权，则返回 `credentialInaccessible` 并由上层记录诊断。
- `KeychainAIProviderCredentialStore` 写入新 item 时按平台处理 accessibility：iOS / iPad 保留 `kSecAttrAccessible...ThisDeviceOnly`；macOS 当前传统 login keychain 路径不写该属性，避免在无 Data Protection Keychain entitlement 的 Debug 构建中创建需要认证 UI 的 item。
- macOS 新建传统 login keychain item 时显式设置 `kSecAttrAccess`，通过 Security.framework 的 `SecAccessCreate` 语义把当前创建 app 设为 trusted application，减少后续读取同一 item 时触发 ACL 认证 UI 的概率。该调用仅限 macOS login keychain 分支，并通过动态符号调用隔离已废弃 API 的编译 warning。
- 设置页加载和保存成功后不再主动解析 Keychain secret 来回填 API Key 输入框。页面只加载非敏感 profile / endpoint / credential metadata；用户输入新 API Key 才会写入 Keychain；测试已保存配置或真实 AI 请求时才按显式动作读取 secret。这样进入设置界面本身不应再触发登录钥匙串认证弹窗。
- 已保存密钥的长期查看 / 替换 UX 由 `docs/plans/done/2026-05-27-feature-ai-provider-saved-credential-disclosure.md`（已 Verified 并移入 done/）承接：已有 credential 时 API Key 字段显示 `已保存到本机 Keychain`，用户点击小眼睛后才解析 Keychain 并把明文加载到同一可编辑输入框。本 Mac bug 方案继续只追踪 macOS Keychain 可访问性、签名 / ACL 和 no-UI 诊断问题。
- 不采用“Mac 端完全绕过系统 Keychain、自行维护密钥”的方案作为本轮修复。原因：如果加密密钥也保存在 App 容器，实际安全性接近本地可读的混淆存储；若再把主密钥放入 Keychain，仍会回到同一授权问题。长期可选路线是使用稳定 Apple Development / Distribution 签名和正式 Keychain access group，或在未来新增用户明确选择的低安全级别本地密钥库，但这会改变敏感凭证安全边界，需要单独 ADR / spec 讨论。

## 验证计划

- `swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests`
- `swift test --package-path Packages/LangoTraceCore --filter DiagnosticsTests`
- `swift test --package-path Packages/LangoTraceUI --filter AIProviderLoadedSecretRepairTests`（覆盖 `settingsViewDoesNotResolveSecretsWhenLoadingOrSavingProfile`、`settingsViewDoesNotLogSecretMetadataWhileAvoidingLoadTimeResolution`、`settingsActionsExposeNonLoggingCredentialResolver`）
- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`
- `xcodebuild -quiet -scheme LangoTrace-macOS -project LangoTrace.xcodeproj -destination 'platform=macOS,arch=arm64' build`
- 重启本地 macOS Debug app 后，让用户重新进入 AI Provider 设置页并采集 macOS `log show`。

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

完成状态判定：**未解决 / 仍为开放调查态，不应移入 done。**

- 本方案无 Done Criteria 章节，仅有 5 条目标；目标 5（读取/检测/更新/删除不反复弹登录钥匙串，且失败时返回稳定错误并进入诊断）在 ad-hoc 签名、无 TeamIdentifier、无 keychain access group 的传统 login keychain 组合下，单靠 `LAContext.interactionNotAllowed` + `kSecUseAuthenticationUIFail` 无法保证完全无弹窗（见“当前证据”第 34 行）。代码缓解降低了弹窗频率，但缺少一次干净的 macOS 人工复测记录证明重建后可静默读取。
- 边界结论：该 bug 在当前签名 / Keychain 组合下不能被完全消除。残余决策（稳定 Apple Development/Distribution 签名 + 正式 keychain access group，或用户显式选择的低安全级本地密钥库）会改变敏感凭证安全边界，属于 ADR / spec 轨道，需单独立项（“实施”第 61 行已指向该方向）。该残余边界已沉淀为架构备忘录 `docs/architecture/notes/2026-06-05-macos-ai-provider-credential-signing-notes.md`，后续相关方案创建前必须读取。在补足上述任一收口前，本方案不可标记为已解决。
