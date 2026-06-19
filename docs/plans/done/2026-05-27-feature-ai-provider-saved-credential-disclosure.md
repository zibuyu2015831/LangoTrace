# AI Provider 已保存密钥查看与替换交互方案

状态：Verified
类型：feature
创建日期：2026-05-27
最后更新日期：2026-05-27

## 用户确认记录

- 2026-05-27：用户在 iOS 模拟器测试向量化通过后，指出 AI Provider 设置页进入后不会读取已保存密钥并回填输入框，询问是否符合预期。
- 2026-05-27：确认当前最新代码为了避免进入设置页即读取 Keychain，已不自动回填 API Key；用户追问如果用户需要查看已保存密钥该怎么办。
- 2026-05-27：用户要求针对这一块需求深入思考，站在 Apple 交互设计师角度给出方案，并创建 active plan。
- 2026-05-27：用户在评估“将密钥加密后存储到数据库、不涉及系统 Keychain 调用”的安全降级方案后，确认仍采用方案 A，即继续使用 Apple 官方推荐的系统 Keychain 作为默认敏感凭证存储方式；本方案进入实现时不得把“可解密密文存 SQLite”作为默认路径。
- 已确认：本方案进入实现时采用“保留当前 API Key 输入框 UI，默认不自动回填，已有密钥时 placeholder 显示 `已保存到本机 Keychain`，用户点击右侧可见性按钮才解析 Keychain 并把明文加载到同一可编辑输入框”的交互方向。

## 需求描述

AI Provider 设置页当前保存 API Key 后，再次进入页面不会把 Keychain 中的明文密钥写回输入框。这降低了 macOS 登录钥匙串弹窗风险，也符合近期代码测试约束，但用户会看到空输入框，容易误判为密钥未保存或配置丢失。

本任务要在尽量保留当前 AI Provider 表单 UI 的前提下，重新设计已保存密钥的展示、显式解密、编辑替换和不可访问恢复路径：用户必须能理解密钥是否已保存；需要查看时由右侧可见性按钮触发显式 Keychain 解析；解析成功后明文进入同一可编辑输入框，用户可以直接修改并保存；页面打开、滚动、保存非敏感配置和切换设置项不得自动解密密钥。

## 现状描述

- `AIProviderSettingsView.loadSavedConfiguration()` 只加载非敏感 profile / endpoint / credential metadata，然后调用 `draft.applyLoadedProfile(profile)`。
- `AIProviderDraftConfiguration.applyLoadedProfile(...)` 会清空 `apiKeyDraft`，只有调用 `applyResolvedSecrets(...)` 时才会把明文写入 UI draft。
- `AIProviderEndpointDraftConfiguration.makeNewSecretCredentialMode()` 在 `apiKeyDraft` 为空且已有 `credentialID` 时保存为 `.existing(credentialID)`，不会删除旧 Keychain item。
- `AIProviderSettingsTests` 目前包含 “Settings view does not resolve secrets when loading or saving profile” 和 “Settings view does not log secret metadata while avoiding load time resolution”，明确防止设置页加载/保存阶段解析 secret。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 和 `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 仍保留“用户主动打开 Provider 配置页时可以通过服务边界读取 Keychain 并回填短生命周期 UI draft”的历史边界；这与近期 macOS Keychain 弹窗修正后的代码事实需要重新对齐。
- `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 记录了 macOS Debug app 在设置页加载阶段主动读取 Keychain 会触发登录钥匙串认证弹窗，因此已将“进入设置页即回填 API Key”降级为不安全交互。

## Apple 交互设计判断

### 1. 默认界面应强调状态，不暴露秘密

Apple 平台的敏感配置体验应优先让用户确认“已保存、仅本机、最近可用性”，而不是默认展示或默认解密秘密。输入框为空不能作为已保存状态的唯一表达；在保留当前表单 UI 的前提下，已保存状态应通过字段 placeholder 和必要的辅助反馈表达。

在本方案中，为了保留当前页面密度和 Apple 设置表单的低干扰体验，状态表达不新增复杂状态行，而是落在现有 API Key 输入框 placeholder 和必要的辅助文案：

- 已有 credential 且未解析：placeholder 显示 `已保存到本机 Keychain`。
- 没有 credential 且无草稿：placeholder 显示 `当前未保存 API Key`，辅助文案提示输入或粘贴后保存会写入本机 Keychain。
- 已解析或用户正在输入：输入框显示当前明文草稿，右侧按钮用于隐藏 / 显示。
- Keychain 不可读：在字段附近显示短错误和恢复动作，不把配置标记为损坏。

### 2. 查看密钥必须是显式动作

“查看已保存 API Key”应是用户点按的显式命令，不能由进入页面、获得焦点、保存成功、切换 Provider 或展开分区触发。点击后再读取 Keychain，并在必要时触发 Face ID、Touch ID、设备密码或 macOS 登录钥匙串认证。这样系统认证弹窗有明确上下文，用户知道为什么被要求认证。

### 3. 查看与编辑替换共用现有字段，但必须有清晰状态

查看用于确认现有值；替换用于输入新值并保存。经过当前 UI 评估后，本任务不采用独立 `查看 / 复制 / 替换` 状态行和 sheet 方案，而是保留现有 API Key 字段。风险控制不靠分离界面，而靠明确状态机：

推荐交互：

- 默认：已有 credential 时输入框为空，placeholder 为 `已保存到本机 Keychain`，右侧显示眼睛按钮。
- 显式解密：用户点击眼睛按钮后才调用 Keychain resolver；认证成功后把 secret 写入当前字段并切换为可见或可隐藏状态。
- 编辑替换：用户可直接编辑已解析字段，或不解析旧值直接粘贴新值；保存时使用 `.newSecret(...)` 替换。
- 空值保存：已有 credential 且字段为空时，保存为 `.existing(credentialID)`，不得删除旧密钥。
- 删除密钥：不复用清空输入框语义；如果后续需要删除，应单独设计明确的破坏性动作。

### 4. 三端应共享语义，平台化承载

- iPhone：保留字段内右侧可见性按钮，按钮触达区不得小于 44pt；Keychain 认证由点击眼睛触发。
- iPad：regular width 保持同一字段语义和合理表单宽度；Split View / Stage Manager resize 不得丢失用户输入草稿。
- macOS：不在窗口打开、设置页切换或字段获得焦点时触发钥匙串认证；认证弹窗必须由用户点击眼睛触发。菜单或快捷键不提供后台解密能力。

### 5. 错误恢复要用用户语言

Keychain 不可读不是普通表单错误。UI 应区分：

- 已保存但当前不可读取：提示重新认证、重新输入或稍后再试。
- Keychain item 缺失：提示重新输入 API Key。
- 当前设备没有该密钥：提示密钥默认不跨设备同步。
- 用户取消认证：回到隐藏状态，不标记配置损坏。

## 目标

1. AI Provider 设置页默认通过现有 API Key 字段清楚展示已保存密钥状态，已有 credential 时 placeholder 为 `已保存到本机 Keychain`。
2. 用户点击右侧可见性按钮后才读取 Keychain，必要时触发本机认证；页面加载、保存非敏感配置和切换设置项不得自动解析。
3. 解析成功后，明文密钥进入同一个可编辑输入框；用户可以直接修改并保存为新密钥。
4. 用户不解析旧值也可以直接粘贴新 API Key；保存时按新密钥替换。
5. 明文密钥只存在于短生命周期 UI 状态，不写入 SQLite、diagnostic event、validation event、日志、请求预览、同步目录、导出包或测试输出。
6. iPhone、iPad 和 macOS 使用同一字段状态模型和 action seam，平台差异只体现在表单宽度、导航位置、认证弹窗和窗口行为。
7. 更新长期规范，移除“主动打开配置页即可回填密钥”的旧表述，改为“用户显式查看或测试/请求时才解析 Keychain”。

## 非目标

- 不改变 Keychain 存储为本机 ThisDeviceOnly / 不同步的默认策略。
- 不把 AI Provider API Key 改为可解密密文后存入 SQLite / GRDB；如果未来需要提供用户显式选择的本地密码库或开发期低安全 credential store，必须单独创建 ADR / spec / active plan，说明 master key 来源、解锁流程、忘记密码恢复边界、迁移和导出风险。
- 不新增 iCloud Keychain、keychain access group、开发者账号签名或跨设备密钥恢复。
- 不把 API Key 尾号、hash、可解密密文或完整 Keychain account 保存到数据库。
- 不在设置页加载、字段获得焦点、保存非敏感配置、切换 Provider、展开语音或向量分区时解析 Keychain。
- 不把清空 API Key 输入框解释为删除已保存 Keychain item；删除密钥需要未来独立设计明确动作。
- 不改变文本、TTS、Embedding probe 的请求内容或网络行为。
- 不解决 macOS Debug 签名和 login keychain ACL 的长期发布策略；该问题继续由 `2026-05-26-bug-mac-ai-provider-key-retention.md` 追踪。

## 证据与决策依据

- `docs/README.md` 要求 AI Provider 和敏感凭证任务遵循文档优先、TDD 和 Keychain 分层。
- `docs/workflows/add-ai-provider.md` 要求 AI Provider 任务写清 credential、Keychain 引用、日志允许字段、失败恢复和测试落点。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 规定 API Key 不能进入 SQLite、日志或同步目录，已保存 profile 的测试和真实请求必须由服务层通过 Keychain 引用解析密钥。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 规定 Keychain account 不应完整展示，App 启动和普通设置列表不得解密 API Key。
- 2026-05-27 安全评估确认：不采用 App 自管 master key 后将 API Key 加密写入 SQLite 的默认方案。原因是如果 master key 存在代码、SQLite 同库或 App 容器内，攻击者拿到本机 App 数据后仍可能解密；如果 master key 放入 Keychain，则没有消除系统 Keychain 调用；如果由用户密码派生，则会引入独立本地密码库、忘记密码不可恢复和三端解锁体验变化，需要单独 ADR。
- `docs/plans/done/2026-05-20-bug-ai-provider-loaded-secret-and-focus-state.md` 曾允许设置页加载时回填密钥，但该方案后来在 macOS 上暴露系统认证弹窗问题。
- `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 已证明 settings load 阶段主动读取 Keychain 会在 macOS 触发登录钥匙串认证弹窗，用户上下文不明确。
- 当前代码测试明确禁止 `AIProviderSettingsView` 在 loading / saving profile 时调用 `actions.resolveCredentialSecret`。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderAPIKeyField.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderCredentialRevealState.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderDraftConfiguration.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsActions.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `.swiftlint.yml`
- `scripts/verify.sh`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/KeychainAIProviderCredentialStore.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderCredentialStore.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/KeychainAIProviderCredentialStoreTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/SyncS3DraftView.swift`

## 涉及的文档路径

- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/platform-page-inventory.md`
- `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md`
- `docs/plans/done/2026-05-20-bug-ai-provider-loaded-secret-and-focus-state.md`

## 交互方案

### 默认 API Key 字段状态

每个需要独立 API Key 的 endpoint 区块继续显示当前 `AIProviderAPIKeyField` 风格的输入控件，并扩展为可表达已保存状态：

- 没有 `credentialID` 且 `apiKeyDraft` 为空：placeholder 显示 `当前未保存 API Key`，辅助文案提示输入或粘贴后保存会写入本机 Keychain。
- 有 `credentialID` 且 `apiKeyDraft` 为空：placeholder 显示 `已保存到本机 Keychain`，右侧眼睛按钮表示可显式查看。
- 有 `apiKeyDraft`：显示当前明文草稿，右侧眼睛按钮只切换可见 / 隐藏；保存后清空明文草稿并回到已保存 placeholder。
- 共享文本模型凭证：语音和向量分区继续显示共享文本模型 API Key 的现有语义，不新增独立 Keychain 解析按钮；如需查看，用户回到文本模型区点击眼睛。

### 点击眼睛查看已保存密钥

用户点击 API Key 字段右侧眼睛按钮后：

1. UI 创建一次 `credentialReveal` operation id。
2. AppEnvironment 通过现有 `resolveCredentialSecret` 进入 Keychain store。
3. 认证成功后将明文写入当前 endpoint 的 `apiKeyDraft`，并切换字段为可见态；用户可以直接编辑。
4. 如果用户随后隐藏字段，只切换 SecureField / TextField 展示，不再次解析 Keychain。
5. App 进入后台、离开页面、切换 Provider、切换 endpoint credential reference 或保存成功后清空明文草稿。

### 复制已保存密钥

当前阶段不在主表单新增独立复制按钮，避免扩大敏感操作面。用户需要复制时，先点击眼睛显式加载密钥，再使用系统文本选择 / 复制能力。后续如需一键复制，必须走同一显式认证链路，并补充剪贴板风险提示和测试。

### 编辑和替换密钥

用户可以通过两条路径替换密钥：

- 直接粘贴新密钥：不解析旧值，字段有新内容时保存链路使用 `.newSecret(...)` 更新 Keychain。
- 先点击眼睛加载旧密钥再编辑：解析成功后明文进入同一输入框，用户修改后保存为 `.newSecret(...)`。

保存规则：

- `apiKeyDraft` 非空：保存为 `.newSecret(...)`。
- `apiKeyDraft` 为空且有 `credentialID`：保存为 `.existing(credentialID)`。
- `apiKeyDraft` 为空且无 `credentialID`，同时 Provider 需要 API Key：保持输入不完整状态。
- 保存成功后清空明文输入，placeholder 回到 `已保存到本机 Keychain`。

### 不可访问状态

如果点击眼睛解析失败：

- `missingCredential`：显示 `这台设备上找不到已保存的 API Key，请重新输入。`
- `credentialInaccessible`：显示 `无法读取 Keychain 中的 API Key。你可以重新认证、稍后再试，或替换 API Key。`
- `userInteractionRequired`：显示 `需要本机认证后才能查看 API Key。`
- 用户取消认证：显示 `已取消查看`，不改变保存状态。

## 数据与安全边界

- reveal / visibility 状态属于 UI-only 状态，不得 `Codable`，不得进入 Core / Data 持久模型。
- 点击眼睛解析成功后，明文 secret 可以进入当前 endpoint 的 `apiKeyDraft`，因为该字段本来就是短生命周期 UI 明文草稿；它仍不得进入 SQLite、diagnostic event、validation event、日志、请求预览、同步、导出或测试输出。
- 显示 / 隐藏只是 UI 展示状态；保存语义只看 `apiKeyDraft` 是否非空和是否存在 `credentialID`。
- reveal 操作可以记录非敏感 diagnostic event：operation id、endpoint purpose、provider preset、平台、结果状态、错误分类、耗时；不得记录 secret、尾号、hash、完整 Keychain service/account、剪贴板内容或请求头。
- 不新增请求日志，也不改变 validation event；查看密钥不是 Provider 配置测试。
- macOS 上如果系统弹出登录钥匙串认证，必须由用户点击眼睛按钮触发；设置页打开不能触发。

## 实施方案

### 阶段 1：状态模型与 UI 单元测试

1. 在 UI 测试中先新增 API Key 字段 presentation 测试，覆盖未设置、已保存 placeholder、点击眼睛解析成功、解析失败、直接输入新 key、共享文本凭证和保存后清空。
2. 为 `AIProviderAPIKeyField` 增加 credential metadata / reveal action 输入，使其能根据 `credentialID` 和 `apiKeyDraft` 计算 placeholder 与眼睛按钮行为。
3. 新增 UI-only reveal state，明确区分 `idle`、`authenticating`、`revealedVisible`、`revealedHidden`、`failed`、`cancelled`；该状态只控制按钮、错误和可见性，不承担持久保存语义。
4. 保持当前 `SecureField` / `TextField` 视觉结构和表单密度，不引入独立状态行、sheet 或复杂凭证控制组件。

### 阶段 2：显式 reveal action seam

1. 在 `AIProviderSettingsActions` 增加显式 reveal 所需的 action，或复用现有 `resolveCredentialSecret` 但只允许由眼睛按钮动作调用。
2. `AIProviderSettingsView` 根据 endpoint credential metadata 调用 resolver；解析成功后写入对应 `apiKeyDraft`，并把字段切换为可见态。
3. 添加 scene phase / navigation dismiss / provider switch / credential reference switch 清理逻辑，确保后台、关闭、取消或切换 endpoint 后明文草稿清空。
4. macOS / iOS / iPad 保持同一个 action seam，不新增平台专属凭证读取逻辑。

### 阶段 3：编辑替换保存流

1. 直接输入、粘贴或 reveal 后编辑都写入现有 `apiKeyDraft`。
2. 保存时沿用现有 `.newSecret(...)` / `.existing(credentialID)` 规则。
3. 用户清空字段但已有 `credentialID` 时，保存仍为 `.existing(credentialID)`；不得误删旧凭证。
4. 保存成功后不解析 Keychain 回填明文，只清空草稿并显示已保存 placeholder。

### 阶段 4：诊断与文档对齐

1. 若新增 diagnostic event，只允许记录 reveal 的非敏感状态和错误分类。
2. 更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`：把“打开 Provider 配置页可以回填”改为“用户点击眼睛、配置测试或真实请求时才解析 Keychain”。
3. 更新 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：同样修正 Keychain 读取触发条件。
4. 更新 `docs/platform-page-inventory.md` 的 AI Provider 设置页状态描述。
5. 在 `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 追加引用，说明本方案负责长期凭证查看 UX，Mac bug plan 继续负责 Keychain 可访问性诊断。

## 测试方案

### 单元测试

- `swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`
  - 未保存 credential 默认显示现有 API Key 输入框，placeholder 为 `当前未保存 API Key`。
  - 已保存 credential 默认显示现有 API Key 输入框，placeholder 为 `已保存到本机 Keychain`。
  - 设置页加载 / 保存不调用 `actions.resolveCredentialSecret`。
  - 点击 API Key 字段右侧眼睛按钮才调用 resolver。
  - reveal 成功后明文进入对应 `apiKeyDraft`，字段可直接编辑。
  - scene inactive / navigation dismiss / provider switch / credential reference switch 清空明文草稿。
  - 直接输入新 key 后保存为 `.newSecret(...)`。
  - 已有 credential 且字段为空时保存仍为 `.existing(credentialID)`。
  - 共享文本凭证的 TTS / embedding 区不提供独立 Keychain reveal 按钮。

- `swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests`
  - 现有 Keychain upsert / resolve / delete 行为不回归。
  - macOS no-UI 读取策略不因 reveal action 改回 settings load 自动触发。

### 日志与隐私扫描

- 扫描测试输出和本地诊断 fixture，确认不包含 `sk-`、`Bearer `、完整 Keychain account、明文 API Key 或密钥尾号。
- 如果新增 diagnostic event，补充测试证明 event attributes 只包含 allowlisted 非敏感字段。

### 手动验证

- iPhone 17 模拟器：保存 API Key，重新进入设置页，API Key 字段 placeholder 显示 `已保存到本机 Keychain`；点击眼睛后解析并显示到同一输入框；编辑后保存替换；返回再进入不自动回填明文。
- iPad Pro 13-inch 模拟器：Split View / regular width 下字段宽度和眼睛按钮保持可读可点，按钮保持 44pt 以上触达区，resize 不丢失未保存输入。
- macOS Debug app：进入设置页不弹登录钥匙串认证；点击眼睛时才允许出现系统认证；取消认证不改变配置状态。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests
swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests
xcodegen generate
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build
scripts/verify.sh
```

## 文档影响检查

本任务会改变 AI Provider 凭证查看 UX 和长期隐私规范，完成时必须检查：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 是否不再鼓励页面打开时自动回填。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 是否准确描述 Keychain 读取触发条件。
- `docs/platform-page-inventory.md` 是否记录三端 Provider 设置页共享凭证控制。
- `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 是否仍只承担 Mac Keychain 可访问性问题，不与本方案重复。
- 是否需要 review 事件触发专项审查：涉及 AI Provider、Keychain 和隐私边界，实施完成后应按 `docs/review/README.md` 判断并记录。

## 复查方法

- 代码复查时搜索 `resolveCredentialSecret`，确认只由 API Key 字段眼睛按钮、测试请求或真实 AI 请求调用，不出现在 settings load / save success 自动路径。
- 搜索 `apiKeyDraft = secret`，确认只有用户点击眼睛后的 reveal 流程、用户输入或明确测试 fixture 使用；不得由 settings load 自动注入保存草稿。
- 搜索 diagnostic event attributes，确认没有 secret、tail、hash、Keychain account、Authorization header。
- 检查 `AIProviderSettingsComponents.swift`，确认已保存状态的 placeholder 明确显示 `已保存到本机 Keychain`，且眼睛按钮满足 44pt 最小触达区。
- 检查 `Localizable.xcstrings`，确认中文主路径使用 `API Key`，错误恢复文案不使用偏工程术语。

## 实施记录

- 2026-05-27：创建 Draft 方案，记录 Apple 三端交互设计、安全边界、测试落点和文档影响。
- 2026-05-27：根据用户对当前 iPhone UI 截图的反馈，放弃复杂状态行 / sheet 原型，改为保留现有 API Key 输入框的最小改动方案：已有密钥以 placeholder 表达，眼睛按钮显式解析并加载到同一可编辑字段。
- 2026-05-27：原型样式确认：未保存状态 placeholder 使用 `当前未保存 API Key`，已保存状态 placeholder 使用 `已保存到本机 Keychain`，可见性按钮保留当前小眼睛样式。
- 2026-05-27：完成实现。新增 UI-only credential reveal presentation / state，API Key 字段保留现有小眼睛按钮；无保存密钥时显示 `当前未保存 API Key`，已有 credential 且明文未加载时显示 `已保存到本机 Keychain`；点击小眼睛才调用 `resolveCredentialSecret`，成功后把明文写入同一可编辑字段；保存成功、离开页面、进入后台、切换 Provider 或 credential reference 时清空短生命周期明文草稿。
- 2026-05-27：完成文档同步。`docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`、`docs/platform-page-inventory.md` 和 `docs/plans/active/2026-05-26-bug-mac-ai-provider-key-retention.md` 已更新为“页面打开不自动解析 Keychain；用户点击眼睛、配置测试或真实请求才解析”的边界。
- 2026-05-27：完整验证首次暴露 `scripts/verify.sh` 生成的 `build/DerivedData` 会被 SwiftLint / SwiftFormat 扫描，导致外部 GRDB checkout 参与 lint/format；已将生成目录排除，并让 UI package 测试在脚本内通过 `tee /dev/null` 持续消费 Swift Testing 输出，避免长脚本重定向场景下测试 runner 偶发 idle 挂起。
- 2026-05-27：验证通过：`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests`、`swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsProbeTests`、`swift test --package-path Packages/LangoTraceUI --filter TTSProviderSettingsTests`、`swift test --package-path Packages/LangoTraceAI --filter KeychainAIProviderCredentialStoreTests`、`swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationServiceTests`、`swift test --package-path Packages/LangoTraceUI`、`swift test --package-path Packages/LangoTraceAI`、`scripts/check-docs.sh`、文档占位符扫描、`git diff --check`、`swiftlint --no-cache`、`swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj --cache ignore` 和 `scripts/verify.sh`。

## 完成标准

- 用户重新进入 AI Provider 设置页时，API Key 字段 placeholder 清楚显示 `已保存到本机 Keychain`，而不是只看到普通空输入框。
- 从未保存过 API Key 时，API Key 字段 placeholder 清楚显示 `当前未保存 API Key`，并提示输入或粘贴后保存会写入本机 Keychain。
- 设置页加载和保存成功不会自动读取 Keychain 明文。
- 用户点击眼睛按钮后，才通过服务边界读取 Keychain；认证取消或失败有明确恢复路径。
- 明文密钥进入后台、离开页面、切换 Provider、切换 credential reference 或保存成功后清空。
- 直接编辑或粘贴新 key 可以替换密钥；已有 credential 且字段为空时保存仍复用现有 credential。
- iPhone、iPad、macOS 共享同一语义和 action seam。
- 聚焦测试和 `scripts/verify.sh` 通过。
- 相关 spec 和页面事实文档完成同步。

## 剩余风险

- macOS Debug 签名、login keychain ACL 和系统认证 UI 仍可能导致查看/复制时弹窗或失败；本方案只保证弹窗由用户显式动作触发，不保证所有开发构建都能静默读取。
- 复制到系统剪贴板后，其他 App 可能读取剪贴板；实现时应考虑短暂提示和未来自动清理策略，但当前阶段不承诺系统级剪贴板隔离。
- SwiftUI view-local state 无法从内存层面保证明文立即归零，只能通过缩短生命周期、不持久化和不日志化降低风险。
- 如果未来支持多 credential / 自定义 header secret，本方案需要扩展为通用 secret disclosure 控件，而不是只处理 API Key。
