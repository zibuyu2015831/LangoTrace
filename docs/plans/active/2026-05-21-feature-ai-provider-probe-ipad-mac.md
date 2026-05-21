# 任务方案：iPad 和 macOS AI Provider 请求测试适配

状态：Implemented
类型：feature
创建日期：2026-05-21
最后更新日期：2026-05-21

## 用户确认记录

- 2026-05-21：用户要求按照 iOS 端已实现的 Provider 请求测试能力，制定方案文档，完成 iPad 和 macOS 端的 Provider 请求测试。

## 0. 实施者快速上下文

本任务不是重新实现 AI Provider 文本模型合成测试网络层，而是把已在 iPhone compact 交互中完成的请求测试能力，可靠落地到 iPad 和 macOS 设置详情入口。

当前已有基础设施包括：

- `AIProviderConfigurationProbeService`：执行文本回复和 JSON 结构化输出两个合成 probe。
- `AIProviderConfigurationService.testDefaultTextEndpoint(...)` 与 `testDraftTextEndpoint(...)`：区分已保存 profile 和未保存 draft。
- `AIProviderSettingsActions.testProviderConfiguration(...)`：UI 到 App / AI 服务层的 action seam。
- `AIProviderProbeResultPanelContent`：共享的分能力结果内容组件。
- `AIProviderSettingsView`：表单、保存、测试按钮和测试状态机的共享 View。
- `SettingsCapabilityDetailView`：iPhone、iPad、macOS 工作台和 macOS Settings scene 共同承载 AI Provider 设置详情。

本任务必须保留以下边界：

- 不新增 Provider 网络协议，不改变 OpenAI Responses / OpenAI-compatible Chat 的请求构造。
- 不把 API Key、Authorization header、Keychain account、请求体或响应体暴露给 SwiftUI View、诊断日志、validation event 或测试输出。
- 不复制 `PadAIProviderSettingsView` 或 `MacAIProviderSettingsView`。
- 不把 iPhone compact bottom sheet 形态硬套到 iPad / macOS。
- iPad / macOS 必须复用同一表单、同一 action seam、同一 probe result model 和同一结果内容组件。

推荐阅读顺序：

1. `docs/plans/active/2026-05-21-feature-ai-provider-text-model-test-request.md`
2. `docs/spec/005-ai-provider-prompt-and-privacy.md` 第 4.7 节
3. `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 第 4.1、5、6 节
4. `docs/platform-page-inventory.md` 中 `AIProviderSettingsView`、iPad 设置详情、macOS Settings detail route 条目
5. `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
6. `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
7. `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`
8. `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
9. `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

## 1. 需求描述

当前 iPhone compact 端已经可以在 AI Provider 设置页点击 `测试请求`，打开测试结果面板，并通过 Provider 层发起固定合成文本模型请求。由于 iPad 和 macOS 复用同一个 `AIProviderSettingsView`，现有代码路径理论上也会触发同一测试 action；本任务要把这种“共享路径自然可用”的状态收口为可验证、可维护的大屏实现，确保用户在 iPad 和 Mac 设置详情中也能保存配置、发起测试、查看分能力结果并重新测试。

这里的“按照 iOS 端的实现”理解为：沿用 iOS 已完成的业务链路、状态机、隐私边界和结果内容，不要求 iPad / macOS 完全复刻 iPhone compact 的 bottom sheet 交互。

## 2. 现状描述

当前代码事实：

- `AIProviderSettingsView` 是共享 View，已包含 `测试请求` 按钮、`draft.textProbeReadiness` 判断、`validateConfiguration()` 状态机、`latestProbeResult` 和 `.sheet(isPresented:)`。
- `AIProviderSettingsView` 在 iOS compact width 时对测试结果 sheet 添加 `.presentationDetents([.medium, .large])`；iPad 常规宽度和 macOS 当前不加 detents。
- `AIProviderProbeResultPanelContent` 已是平台无关内容组件，展示文本回复、JSON 输出、图片理解、语音生成和向量化五类 capability 状态。
- `SettingsCapabilityDetailView` 在 `capability.kind == .aiProvider` 时直接承载 `AIProviderSettingsView()`，并用最大宽度控制 iPad / macOS 阅读栏。
- `PadMainSections.swift`、`MacWorkspaceContentView.swift` 和 `LangoTraceSettingsSceneView.swift` 都通过 `SettingsCapabilityDetailView` 进入 AI Provider 设置详情，未复制独立平台 View。
- `LangoTraceApp.swift` 已向主 App root 和 macOS Settings scene 注入同一套 `aiProviderSettingsActions`。
- `AIProviderSettingsProbeTests` 已有源码级测试确认测试按钮走 `actions.testProviderConfiguration`、结果内容组件不直接拥有 sheet / detents、UI View 不含 `URLSession` / `Authorization` / `Bearer ` 请求拼接。
- `AIProviderSettingsTests` 已有源码级测试确认 iPad / Mac 路由通过共享设置详情，不直接实例化 `AIProviderSettingsView()`，并确认 macOS Settings scene 和 root 注入同一 action。

当前不足：

- 没有专门测试锁定 iPad / macOS 对请求测试结果 presentation 的平台规则；现有测试只证明共享 View、共享 action seam 和结果内容组件存在。
- `AIProviderSettingsView` 内部直接拥有 sheet 状态，虽然能在 iPad / macOS 弹出 sheet，但缺少对大屏尺寸、最大宽度、关闭 / 重试行为和嵌入外层 `ScrollView` 场景的明确约束。
- macOS 工作台设置详情使用 `presentation: .embeddedInExistingScroll`，需要确认测试结果展示不会与外层滚动结构、窗口宽度和 Settings scene 入口产生冲突。
- 文档已声明 iPad / macOS 不强制使用移动端 detents，但尚未有本任务级实施与验证记录。

## 3. 目标

本任务完成后必须达到：

- iPad 设置详情中可点击 `测试请求`，发起与 iPhone 相同的 Provider 配置合成测试。
- macOS 工作台设置详情中可点击 `测试请求`，发起与 iPhone 相同的 Provider 配置合成测试。
- macOS 原生 Settings scene 中如展示 AI Provider 设置详情，也必须复用同一 action seam，可发起同一合成测试。
- iPad / macOS 测试结果展示复用 `AIProviderProbeResultPanelContent`，并显示文本回复、JSON 输出、图片理解、语音生成、向量化五项状态。
- iPad / macOS 的 presentation 不使用 iPhone compact 专属 detents；结果内容应有合理最大宽度，避免在大屏横向拉满。
- 关闭、重新测试、测试中禁用按钮、缺少必填项禁用按钮、部分成功、失败、暂不支持 provider 等状态在三端一致。
- 仍然通过 `AIProviderSettingsActions` 进入 AI / App 服务层，不在 UI 层拼接网络请求、读取 Keychain 或持有 Authorization header。
- 新增回归测试覆盖 iPad / macOS presentation 规则和平台入口 action 注入。
- 完成后更新相关文档的实施记录；如只改变 presentation 和测试覆盖，不更新 ADR。

## 4. 范围

本任务覆盖：

- 评估并必要时调整 `AIProviderSettingsView` 的结果展示 presentation，使 iPad / macOS 行为明确且可测试。
- 必要时新增小型平台 presentation helper，例如把 compact detents 和 regular/macOS 最大宽度收敛到独立 modifier 或 wrapper。
- 保持 `AIProviderProbeResultPanelContent` 为共享内容组件，不拆平台版。
- 补充 UI package 测试，锁定 iPad / macOS 仍走共享详情和共享 action seam。
- 补充测试，确认 iPad / macOS 不引入独立 Provider settings view、不直接创建网络请求、不使用 iPhone compact detents 作为唯一承载。
- 如代码事实发生变化，更新 `docs/platform-page-inventory.md` 和本方案实施记录。

## 5. 不做什么

本任务不实现：

- 不新增真实学习内容 AI 请求。
- 不执行 Prompt Preset。
- 不新增请求预览 UI。
- 不接入 TTS、Embedding 或图片理解真实网络 probe。
- 不新增 Anthropic / Gemini 专用真实测试 adapter。
- 不改变 `AIProviderConfigurationProbeService` 的请求体、JSON prompt 或响应解析。
- 不改变 Keychain、SQLite / GRDB、validation event 或 diagnostic event 数据模型。
- 不引入平台专属 Provider 配置字段模型。
- 不为 iPad 或 macOS 复制独立 `PadAIProviderSettingsView` / `MacAIProviderSettingsView`。

## 6. 证据与决策依据

代码依据：

- `AIProviderSettingsView.swift` 已提供共享测试状态机，现有差异主要在 `.sheet` presentation modifier。
- `AIProviderSettingsComponents.swift` 中 `AIProviderProbeResultPanelContent` 已平台无关，适合作为三端共享结果内容。
- `SettingsCapabilityDetailView.swift` 是 AI Provider 设置详情的共享承载层，已经负责 iPad / macOS 最大内容宽度。
- `AIProviderSettingsProbeTests.swift` 已通过源码测试锁定测试按钮使用 `actions.testProviderConfiguration`、结果内容组件展示五类 capability、结果内容组件不拥有 presentation。
- `AIProviderSettingsTests.swift` 已通过源码测试锁定 iPad / Mac 不复制表单 View，并锁定 macOS Settings scene 注入同一 `aiProviderSettingsActions`。
- `LangoTraceApp/AppEnvironment.swift` 已装配真实 `AIProviderConfigurationProbeService` 和 `testProviderConfiguration` action。

文档依据：

- `docs/spec/005-ai-provider-prompt-and-privacy.md` 要求测试请求必须走 Provider 层，SwiftUI View 不得直接创建请求或读取密钥。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md` 要求诊断日志不得包含 API Key、请求头、请求体、响应体和完整 Keychain account。
- `docs/platform-page-inventory.md` 已记录 AI Provider 设置页三端共享同一表单和结果内容，iPhone compact 使用 bottom sheet detents，iPad 常规宽度和 macOS 不强制套用移动端 detents。

关键决策：

| 决策 | 结论 | 理由 |
| --- | --- | --- |
| 是否重做网络 probe | 不重做 | 当前网络 probe 已在 AI package 落地，本任务只补齐 iPad / macOS presentation 与验证。 |
| 是否复制平台 View | 不复制 | 三端字段语义和 action seam 必须一致，复制会放大隐私边界和测试矩阵。 |
| iPad / macOS 展示形态 | 使用共享内容 + 大屏适配 wrapper | 业务结果一致，外层 presentation 可按平台调整。 |
| iPhone detents | 仅 compact width 使用 | iPad / macOS 不应被移动端 bottom sheet 尺寸约束。 |
| 测试策略 | 先源码/状态机单元测试，再完整 `scripts/verify.sh` | 当前 UI package 多用源码级边界测试；真实网络依赖外部 Key，不进入自动化。 |

## 7. 涉及的代码文件路径

预计修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsProbeTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`
- `docs/platform-page-inventory.md`

可能修改：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/SettingsCapabilityDetailView.swift`：如果需要由详情承载层显式注入 presentation 风格或最大结果宽度。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`：如果新增大屏结果展示相关可见文案。
- `LangoTraceApp/LangoTraceApp.swift`：仅当发现 macOS Settings scene action 注入遗漏时修改；当前证据显示不需要。

预计不修改：

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationService.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBAIProviderConfigurationRepository.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/AIProviderConfiguration.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacWorkspaceContentView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceSettingsSceneView.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `LangoTraceApp/LangoTraceApp.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationServiceTests.swift`

## 9. 涉及的文档路径

本方案创建：

- `docs/plans/active/2026-05-21-feature-ai-provider-probe-ipad-mac.md`

实施完成后预计更新：

- `docs/platform-page-inventory.md`
- 本方案实施记录、验证记录和剩余风险

预计不需要更新：

- `docs/spec/005-ai-provider-prompt-and-privacy.md`：本任务沿用既有 Provider 请求边界，不新增长期规则。
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`：本任务沿用既有诊断边界，不新增日志字段。
- `docs/decisions/005-local-first-and-user-owned-providers.md`：不改变本地优先和用户自带 Provider 决策。

## 10. 实施方案

### 10.1 代码复查与失败测试

1. 复查 `AIProviderSettingsView` 当前 `.sheet` 在 iPad / macOS 的行为，确认是否只是缺少测试锁定，还是需要显式 presentation wrapper。
2. 在 `AIProviderSettingsProbeTests.swift` 和 `AIProviderSettingsTests.swift` 先新增或调整失败测试：
   - iPad / macOS 仍通过 `SettingsCapabilityDetailView` 进入共享 `AIProviderSettingsView`。
   - `AIProviderSettingsView` 的测试结果内容使用 `AIProviderProbeResultPanelContent`。
   - compact detents 仅出现在 iOS compact helper 中，不能作为 iPad / macOS 唯一 presentation 规则。
   - 源码中不得出现 `PadAIProviderSettingsView`、`MacAIProviderSettingsView`。
   - `AIProviderSettingsView.swift` 不得出现 `URLSession`、`Authorization`、`Bearer `、`dataTask` 或 `uploadTask`。
3. 如需覆盖状态映射，补充纯模型测试，验证 failed / partial / unsupported / cancelled 结果的 title key 与三端共享。

### 10.2 Presentation 调整

优先采用最小改动：

- 保留 `AIProviderSettingsView` 内部 sheet 状态。
- 把现有 `aiProviderProbePresentationDetents(compactWidth:)` 扩展为更明确的 `aiProviderProbePresentationStyle(compactWidth:)`。
- iPhone compact：保留 `.presentationDetents([.medium, .large])`。
- iPad regular 和 macOS：不添加 detents，对 panel 内容设置合理最大宽度和 leading alignment，例如通过 `AIProviderProbeResultPanelContent` 或 wrapper 限制 `maxWidth`。

如果实测发现 macOS 工作台 embedded scroll 中 sheet 体验不稳定，再采用第二方案：

- 将结果展示拆成 `AIProviderProbeResultPresentation` wrapper。
- wrapper 内部仍复用 `AIProviderProbeResultPanelContent`。
- iPhone compact 使用 sheet + detents。
- iPad / macOS 使用 sheet + 最大宽度内容，或在设置详情中嵌入临时结果 panel。

第二方案只有在第一方案无法满足 macOS/iPad 使用体验或测试约束时采用。

### 10.3 文档更新

实施后更新：

- `docs/platform-page-inventory.md`：确认 iPad / macOS Provider 设置详情已支持发起合成测试和查看结果。
- 本方案 `实施记录`：记录具体采用的 presentation 方案、验证命令和人工验证情况。

除非实现改变长期隐私、Provider 请求或诊断边界，否则不更新 spec / ADR。

## 11. 复查方法

代码复查重点：

- 搜索 `PadAIProviderSettingsView`、`MacAIProviderSettingsView`，确认没有平台复制。
- 定向搜索 `AIProviderSettingsView.swift`、结果 presentation helper 和相关测试新增代码中的 `URLSession`、`Authorization`、`Bearer `、`dataTask`、`uploadTask`，确认设置页 UI 没有网络或密钥拼接。`AIProviderSettingsModels.swift` 允许保留面向用户的认证方式标签，例如 `Bearer token`，该标签不是请求头拼接。
- 搜索 `presentationDetents`，确认 AI Provider probe detents 只用于 iPhone compact。
- 检查 `LangoTraceApp.swift`，确认 macOS Settings scene 和 App root 都注入同一 `aiProviderSettingsActions`。
- 检查 `SettingsCapabilityDetailView.swift`，确认 iPad / macOS 仍通过共享详情承载 AI Provider 设置。
- 检查 `AIProviderSettingsView.swift`，确认测试按钮禁用、testing 状态、sheet 展示、重试和关闭行为不因平台分支而分叉。

文档复查重点：

- `docs/platform-page-inventory.md` 中 iPhone、iPad、macOS 的 AI Provider 条目与代码事实一致。
- 本方案不把已实现代码误写成未来能力，也不把未实现的 TTS / Embedding / 图片理解真实 probe 写成已完成。

## 12. 验证命令

聚焦测试：

```bash
swift test --package-path Packages/LangoTraceUI
```

AI package 回归测试：

```bash
swift test --package-path Packages/LangoTraceAI
```

完整 Swift 工程验证：

```bash
scripts/verify.sh
```

文档检查：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

人工验证：

- iPad Simulator：进入设置详情 `AI Provider`，填写或加载文本模型配置，点击 `测试请求`，确认结果展示、关闭、重试、测试中禁用按钮可用。
- macOS App 工作台：进入 Settings detail route 的 `AI Provider`，重复同样验证。
- macOS 原生 Settings scene：如当前入口展示 AI Provider 设置详情，确认 action 注入有效且不出现缺环境 action 的占位行为。

如果没有可控真实 Provider / API Key，人工验证可以使用 unsupported provider 或缺密钥路径验证 presentation；真实网络成功路径需在有测试 Key 时单独记录。

## 13. 文档影响检查

本任务属于 AI Provider、隐私相关 UI 行为补齐，完成后必须做文档影响检查：

- 如果只调整 iPad / macOS presentation 和测试覆盖：更新 `docs/platform-page-inventory.md` 与本方案即可。
- 如果新增 Provider 请求字段、诊断字段、validation event 或长期隐私规则：必须同步更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md`，必要时补充 ADR。
- 如果发现现有 active 方案 `2026-05-21-feature-ai-provider-text-model-test-request.md` 状态或事实已过期，应先汇报，再按用户确认移动到 done 或追加收口记录。

## 14. 实施记录

- 2026-05-21：提交方案文档，commit `cb06676`。
- 2026-05-21：按 TDD 先在 `AIProviderSettingsProbeTests.swift` 新增失败测试，锁定测试结果 sheet 必须使用更明确的 `aiProviderProbePresentationStyle(compactWidth:)`、保留 iPhone compact detents，并为 iPad / macOS regular presentation 提供最大宽度规则。首次运行 `swift test --package-path Packages/LangoTraceUI` 失败，失败点集中在旧 helper 名称和缺少大屏宽度约束，符合预期。
- 2026-05-21：在 `AIProviderSettingsView.swift` 增加 `aiProviderProbeRegularWidth`，将结果内容限制为 `520` 最大宽度，并把 helper 从 `aiProviderProbePresentationDetents` 重命名为 `aiProviderProbePresentationStyle`。iPhone compact 仍使用 `.presentationDetents([.medium, .large])`；iPad regular 和 macOS 不添加 detents。再次运行 `swift test --package-path Packages/LangoTraceUI`，155 个 UI package 测试通过。代码阶段 commit `a2e33b9`。
- 2026-05-21：更新 `docs/platform-page-inventory.md`，记录 iPad / macOS AI Provider 测试结果面板已通过共享 action seam 覆盖，并在大屏使用固定最大宽度，未改变 Provider 请求、隐私、诊断或 Data 边界。

## 15. 完成标准

- iPad / macOS 可从现有设置详情入口发起 AI Provider 配置测试。
- iPad / macOS 可查看与 iPhone 一致的分能力测试结果内容。
- iPad / macOS 不复制 Provider 设置 View，不绕过 `AIProviderSettingsActions`。
- `AIProviderSettingsView.swift`、结果 presentation helper 和相关新增 UI 代码不出现网络请求、Authorization header、`Bearer ` 请求头拼接或 Keychain 读取逻辑。
- 新增或更新的 UI package 测试通过。
- `swift test --package-path Packages/LangoTraceAI` 通过。
- `scripts/verify.sh` 通过，或清楚记录无法运行原因和剩余风险。
- 文档检查命令通过。
- `docs/platform-page-inventory.md` 与代码事实一致。

## 16. 剩余风险

- 自动化测试主要能锁定平台路由、源码边界和状态映射，不能替代真实 iPad / macOS 人工点击验证。
- 真实网络成功路径依赖用户提供可控测试 Provider / API Key；没有测试 Key 时，只能验证 presentation、缺密钥、unsupported 和失败分类路径。
- macOS 原生 Settings scene 与工作台 Settings detail route 是两个入口；即使共享 View，也需要分别人工打开确认窗口行为。
