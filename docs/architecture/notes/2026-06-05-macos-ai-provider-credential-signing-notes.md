# macOS AI Provider Credential Signing Notes

状态：Accepted
创建日期：2026-06-05

## 适用范围

适用于后续 macOS 敏感凭证存储、AI Provider / Embedding / TTS / 对象存储密钥、Keychain access group、代码签名策略、低安全级本地密钥库，以及任何依赖 macOS Keychain 静默读取的方案。

## 背景

`docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 在多轮修复后确认：当前 macOS Debug app 为 ad-hoc 签名、`TeamIdentifier=not set`、未配置 keychain access group，却使用传统 login keychain 保存 AI Provider secret。该组合下：

- 读取 / 检测 / 更新 / 删除已保存 secret 依赖 login keychain 的 ACL 与代码签名授权。
- 单靠 `LAContext.interactionNotAllowed = true` + `kSecUseAuthenticationContext` + `kSecUseAuthenticationUIFail` 等价参数，无法保证在所有情况下完全不弹出登录钥匙串密码框。
- 重建后 `CDHash` 变化可能使旧 item 的 ACL 不再匹配，表现为 metadata 仍在、secret 读取失败（`credentialInaccessible`）。

本备忘录记录这一残余安全边界问题，避免后续把“已降低弹窗频率的缓解”误当成“macOS 凭证持久化已彻底解决”。

## 已有设计留下的扩展点

- `KeychainAIProviderCredentialStore` 已按平台分支处理 accessibility 与 trusted-application（macOS 跳过 `kSecAttrAccessible…ThisDeviceOnly`，并通过动态解析 `SecAccessCreate` 设置 trusted app），可作为后续签名 / access group 方案的迁移起点。
- App Shell 已将 store 错误映射为 Core 层稳定分类（`missingCredential` / `credentialInaccessible`），后续可在此基础上补诊断 emit。
- 设置页已改为加载期不解析 secret、仅显式动作读取，缩小了触发系统认证的入口。

## 后续任务必须重新决策的问题

- 签名策略：是否引入稳定 Apple Development / Distribution 签名，使 `TeamIdentifier` 固定、Keychain ACL 在重建后保持稳定。
- Keychain access group：是否配置正式 access group 并迁移到 Data Protection Keychain；这需要对应 entitlement，会改变测试宿主与 Debug 构建行为（当前缺 entitlement 时 `kSecUseDataProtectionKeychain` 返回 `-34018`）。
- 低安全级本地密钥库：是否提供用户显式选择的本地密钥库作为替代；若加密密钥也存于 App 容器，实际安全性接近本地可读混淆存储，必须有清晰隐私披露。
- 诊断交付：`ai_provider_settings.credential_resolve_failed` 事件名已存在但当前无生产 emit 点；若要让日志区分 item 缺失 / 不可访问 / profile 未加载，需在 reveal 失败路径补 emit，或显式声明该事件保留为未来扩展。

## 当前任务不实现

- 不改变“敏感凭证默认存入 Keychain 或等价安全存储、默认不同步”的核心决策（见 ADR-005 与 `docs/README.md` 第 4 节第 9 条）。
- 不引入新的签名证书、entitlement 或 access group。
- 不新增低安全级本地密钥库。
- 不清理用户本机已有 Keychain item。

## 进入正式方案前检查

任何改变 macOS 敏感凭证存储位置、签名策略、Keychain access group 或新增本地密钥库的方案，都会改变敏感凭证安全边界，必须按 ADR / spec 立项，读取本备忘录并说明采纳、延后或提升为正式决策的处理方式。在补足签名 / access group 或完成一次干净的 macOS 无弹窗静默读取人工复测前，不得将 macOS Keychain 凭证持久化问题标记为已解决。
