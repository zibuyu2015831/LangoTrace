# 任务方案：iOS 模拟器 AI Provider 保存失败

状态：Implemented
类型：bug
创建日期：2026-05-20
最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户在 iOS 端测试 AI Provider 保存配置时看到“配置保存失败”，要求阅读日志排查。当前先完成根因排查和方案记录；实施修复前需要用户确认。
- 2026-05-20：用户确认立即修复，并要求重新构建、重启本地模拟器。

## 1. 需求或 bug 描述

iOS 模拟器中进入 AI Provider 设置页，填写 API Key 后点击“保存配置”，页面显示“配置保存失败”。用户无法保存 Provider 配置，导致后续“测试请求”也无法验证 Keychain 可读性。

## 2. 复现方式

1. 使用 `xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build` 构建。
2. 使用 `xcrun simctl install` 安装到 `iPhone 17` 模拟器。
3. 启动 `com.zibuyu.LangoTrace`。
4. 进入设置中的 AI Provider 配置页。
5. 填写 API Key 后点击“保存配置”。

## 3. 预期行为

- 保存动作应先写入 Keychain，再写入 SQLite / GRDB metadata。
- 保存成功后 UI 显示保存成功，并清空明文 API Key 草稿。

## 4. 实际行为

- UI 显示“配置保存失败”。
- 当前 App 容器数据库中 `ai_provider_profiles`、`ai_provider_credentials`、`ai_provider_endpoints` 均无记录。
- 系统日志中能看到保存时触发 `SecItemAdd_ios`，但没有后续数据库写入事实。

## 5. 根因分析

根因是当前 `project.yml` 全局设置了 `CODE_SIGNING_ALLOWED: NO`，iOS 模拟器构建产物为 linker-signed / ad-hoc app：

```text
Signature=adhoc
TeamIdentifier=not set
```

同时 `codesign -d --entitlements - .../LangoTrace.app` 没有输出 entitlements。iOS 模拟器中的 Keychain Generic Password 访问依赖应用签名和 entitlement 上下文。当前无有效签名上下文时，`SecItemAdd` 进入 Security 服务后失败，服务层把底层 Keychain 错误映射为 `keychainWriteFailed`，UI 进一步显示“配置保存失败”。

置信度：92%

置信度依据：

- 失败发生前系统日志出现 `SecItemAdd_ios`。
- App 数据库为空，说明保存没有进入或没有完成 SQLite metadata 写入。
- 构建产物确认为 `Signature=adhoc`、`TeamIdentifier=not set`。
- `project.yml` 明确设置 `CODE_SIGNING_ALLOWED: NO`。
- 二次确认 `xcodebuild -showBuildSettings` 显示 iOS target 当前为 `CODE_SIGNING_ALLOWED = NO`、`ENTITLEMENTS_ALLOWED = NO`、`CODE_SIGN_CONTEXT_CLASS = XCiPhoneSimulatorCodeSignContext`、`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES`；其中前两项直接阻止 Xcode 为模拟器产物注入 entitlement。
- 二次确认 `codesign -d --entitlements - .../LangoTrace.app` 只有 executable 行，没有任何 entitlement payload。
- 当前 Keychain store 使用 `SecItemAdd`，且没有 access group 特殊配置；数据库路径和 migration 已存在，不是数据库缺失问题。

备选原因：

- Keychain accessibility 取值与模拟器运行状态不兼容。但当前使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`，模拟器已解锁，概率较低。
- 同步属性 `kSecAttrSynchronizable = false` 在某些环境表现异常。现有 macOS package 测试能通过，且 iOS 失败与签名缺失更吻合。
- UI 输入实际缺少必填项。但截图显示已经进入真实保存失败状态，不是 missing required fields。
- 数据库 schema 或路径错误。二次确认同一 App 容器中存在 `ai_provider_profiles`、`ai_provider_credentials`、`ai_provider_endpoints` 和 `diagnostic_events` 表，且 profile / credential / endpoint 计数均为 0；这更符合 Keychain 写入失败后未进入 DB metadata 提交，而不是数据库缺表或路径错误。

## 6. 目标

1. iOS 模拟器 Debug 构建必须具备可访问 Keychain 的签名上下文。
2. 不引入正式发布签名或强依赖某个开发者团队。
3. 保存失败排查能力应能显示非敏感 Keychain 错误阶段；后续可进一步补充 OSStatus 分类，但本轮优先修复根因。
4. 修复后在 iPhone 17 模拟器上重新构建、安装、启动，并验证保存不再失败。

## 7. 范围

预计修改：

- `project.yml`

可能修改：

- `docs/spec/009-testing-and-verification.md`：如果最终确认需要把“需要 Keychain 的模拟器验证不得关闭 signing”沉淀为长期验证规则。
- 本任务方案自身。

## 8. 不做什么

- 不把 API Key 改存 SQLite、UserDefaults 或普通文件。
- 不把 Keychain 失败改成静默成功。
- 不在 UI 或日志中输出 API Key、完整 Keychain account 或请求头。
- 不接入真实 Provider 网络测试。

## 9. 实施方案

推荐方案：

1. 调整 XcodeGen 配置，移除全局 `CODE_SIGNING_ALLOWED: NO`，或至少让 iOS 模拟器 Debug target 使用 Xcode 默认 signing 行为。
2. 保持 `DEVELOPMENT_TEAM` 不写死，避免把个人团队 ID 固化进仓库；模拟器 Debug 构建应可使用本地 Xcode 的 ad-hoc/dev signing 上下文生成可用 entitlements。
3. 运行 `xcodegen generate` 重新生成工程。
4. 重新构建 iPhone 17 模拟器。
5. 重启并安装 app。
6. 复测保存配置。

备选方案：

- 只为 `LangoTrace-iOS` target 删除 `CODE_SIGNING_ALLOWED: NO`，macOS 维持当前设置。若全局修改影响 macOS build，再采用该更窄方案。
- 如果仍失败，再为 Debug iOS 增加最小 entitlements 文件，仅声明必要 application identifier / keychain access groups。但这通常不应手写，优先让 Xcode 管理。

## 10. 复查方法

- `xcodebuild -showBuildSettings` 中 iOS 模拟器 target 的 `CODE_SIGNING_ALLOWED` 应为 `YES`。
- iOS 模拟器构建日志应出现 `Entitlements-Simulated.plist`、`__entitlements` 注入或 `Sign to Run Locally` 本地签名步骤；`codesign -d --entitlements - <LangoTrace.app>` 在模拟器产物上不一定稳定打印 simulated entitlement payload，不作为唯一判断依据。
- 保存后 SQLite 中应出现 `ai_provider_profiles`、`ai_provider_credentials`、`ai_provider_endpoints`。
- UI 应显示保存成功。

## 11. 验证命令

```bash
xcodegen generate
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl shutdown all
xcrun simctl boot 'iPhone 17'
xcrun simctl install 'iPhone 17' /Users/zibuyu/Library/Developer/Xcode/DerivedData/LangoTrace-hdfadqhothdwgbahopjjqiwrxhky/Build/Products/Debug-iphonesimulator/LangoTrace.app
xcrun simctl launch 'iPhone 17' com.zibuyu.LangoTrace
```

必要时补充：

```bash
sqlite3 '<app container>/Library/Application Support/LangoTrace/LangoTrace.sqlite' 'select id, status from ai_provider_profiles;'
```

## 12. 文档影响检查

如果修复确认 signing 是根因，需要更新：

- `docs/spec/009-testing-and-verification.md`

原因：AI Provider / Keychain 相关模拟器验证不能使用完全禁用 code signing 的构建产物。

## 13. 实施记录

- 2026-05-20：已完成根因排查并创建方案，尚未实施修复。
- 2026-05-20：按用户要求再次排查确认。新增证据：`xcodebuild -showBuildSettings` 显示 `CODE_SIGNING_ALLOWED = NO` 与 `ENTITLEMENTS_ALLOWED = NO`；`codesign -dvv` 显示 `Signature=adhoc`、`TeamIdentifier=not set`；`codesign -d --entitlements -` 无 entitlement payload；系统日志保存时出现两次 `SecItemAdd_ios`；SQLite 中 AI Provider profile / credential / endpoint 计数均为 0。将根因置信度从 90% 调整为 92%。
- 2026-05-20：已移除 `project.yml` 全局 `CODE_SIGNING_ALLOWED: NO`，重新运行 `xcodegen generate`。修复后 `xcodebuild -showBuildSettings` 显示 `CODE_SIGNING_ALLOWED = YES`；iOS 模拟器构建日志出现 `Entitlements-Simulated.plist`、`__entitlements` 注入和 `CodeSign ... Signing Identity: "Sign to Run Locally"`。
- 2026-05-20：修复后 `Entitlements-Simulated.plist` 包含 `application-identifier = FAKETEAMID.com.zibuyu.LangoTrace`；`codesign -dvv` 显示 bundle identifier 已恢复为 `com.zibuyu.LangoTrace`。`codesign -d --entitlements -` 未稳定打印 simulated entitlement payload，因此后续以 build settings、simulated entitlement plist 和构建签名日志作为模拟器签名复查依据。
- 2026-05-20：已重新构建 `LangoTrace-iOS`、关闭并重启 `iPhone 17` 模拟器、安装新构建并启动 `com.zibuyu.LangoTrace`。

## 14. 完成标准

- iOS 模拟器保存 AI Provider 配置不再显示“配置保存失败”。
- 数据库中出现对应非敏感 Provider metadata。
- API Key 不进入数据库或日志。
- 重新构建、重启模拟器、安装和启动通过。
- 如有代码/配置改动，完成验证并单独提交 commit。

## 15. 剩余风险

- 本地开发机没有配置 Apple 开发团队时，真机 signing 仍需要单独处理；本任务只解决模拟器 Debug 保存失败。
- 如果后续引入 App Groups 或 iCloud Keychain，需要重新审查 Keychain access group 和同步边界。
