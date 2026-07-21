# 任务方案：语伴升级为设置「能力」+ 独立详情页（设置 IA 统一）

状态：Done（2026-06-27 用户授权 → TDD 落地 → 全量 CI 绿 run 28281128222 → §17 回写 → 移 done/，见 §11）
自审核状态：Reviewed（见 §10）
类型：feature
创建日期：2026-06-27
最后更新日期：2026-06-27
上游决策：ADR-008（语伴定位，§2.6 默认关 toggle）；UI 规范 003 §411（卡片仅用于重复 item，非默认外壳）；ADR-004（语言空间）
Workflow：[`workflows/add-platform-screen.md`](../../workflows/add-platform-screen.md)（三端页面/入口）

## 1. 背景与定位

三端设置页顶部，「学习画像」(`LearnerProfileSettingsRow`) 与「语伴」(`CompanionSettingsToggleRow`) 是两个**裸行**，悬在下方一排能力卡（语言空间/界面语言/外观/AI Provider/同步，均 `CapabilityStatusRow` + `.langoPanel()`）之上，视觉「孤儿」。用户提问：(1) 是否符合预期；(2) 语伴开关是否该并入「学习画像」配置页。

**调研结论**：
- 两行**刻意**非 `SettingsCapability`（代码注释 + ADR-008）。UI 规范 003 §411 明确「卡片只用于重复 item，不作所有 section 默认外壳」→「都套卡片」反违规范，且语伴是 toggle 非导航。
- **不该折叠进学习画像**：学习画像是 LM02 **只读查看面**（副标题「查看 App 对你的了解」），埋开关伤可发现性；ADR-008 要语伴是默认关的显式 opt-in，开关应在可见层级；语伴消费画像的关系已由独立 consent 闸 `uses_learner_profile`（注入时）治理，无需物理合并。

**真正异常 = 语伴是裸 toggle，而其它每项都是「列表一行 → 详情页配置」。** 本任务把语伴升级为标准 `SettingsCapability`：主列表 → 能力卡（带 `已启用/已关闭` 尾值）→ 点进**语伴详情页**（开关移入）。三端列表自动统一、不违规范 411、语伴获未来配置（场景/语音/向量）承载页；「学习画像」保留为顶部**唯一**非能力导航行（iOS「Apple ID 行」式惯例，不再孤儿）。

ADR-008 §2.6「默认关」不变（toggle 仍在、仍默认关、仅迁位），**无需新增/改 ADR**。属设置 IA + UI 结构调整，非 LM03 切片。

## 2. 前置（全部 BUILT，调查 2026-06-27）

| 前置 | 状态 | 事实源 |
| --- | --- | --- |
| capability 列表单一源 | ✅ | `GRDBLearningContentRepositoryBridge.settingsCapabilities`（静态数组）；三端均 `ForEach(settingsCapabilities)` 渲染 `CapabilityStatusRow` |
| 通用详情路由 | ✅ | 三端 capability 行 action → `onRoute(.settings(kind))` / push / selection → `SettingsCapabilityDetailView`（按 `kind` 分支） |
| 语伴 feature flag | ✅ | `companionFeatureEnabled`/`setCompanionFeatureEnabled`（env）；`UserDefaultsCompanionFeatureStore`（key `LanguageCompanionEnabled`，默认 false）；App 注入 |
| toggle 组件 | ✅ | `CompanionSettingsToggleRow`（读 env，复用 `companion.settings.toggle` + `.description` 文案） |
| 尾值机制 | ✅ | `settingsRowValue(for:status:interfaceLanguage:appearance:)`（纯函数）→ `.trailingValue(...)`（iPhone `SettingsView` + iPad `LangoTraceSettingsSceneView` 已用；Pad/Mac 主区 ForEach 暂无尾值） |
| 全局上下文先例 | ✅ | `requiresLanguageSpaceContext`（appearance/interfaceLanguage 已豁免语言空间）；`canShowDetail` 同例 |

## 3. 设计

### 3.1 Data：新增 capability kind（单一源驱动三端）
- `SettingsCapability.swift`：`Kind` 加 `case companion`；`systemImage` 加 `case .companion: "bubble.left.and.bubble.right"`。
- `GRDBLearningContentRepositoryBridge.settingsCapabilities`：**首位**插入 `companion`（`status: .ready`，`settings.companion.{summary,detail,nextRequirement}`），作为第一张能力卡紧跟「学习画像」行，保留当前顶部位置语义。

### 3.2 UI：title key + 尾值（响应式，不动 Core）
- `LocalizedChrome.swift` `localizedTitleKey` switch 加 `case .companion: "settings.companion.title"`。
- `SettingsRowValuePresentation.swift`：`settingsRowValue` 增参 `companionEnabled: Bool? = nil`，加 `case .companion: companionEnabled.map { localizedString($0 ? "settings.value.companion.enabled" : "settings.value.companion.disabled") }`。**不动 Core `SettingsStatusProjection`**——尾值经 env `companionFeatureEnabled` 传入，保证 iPad/Mac 双栏同屏切换即时反应（projection 需刷新才更新，env 响应式）。

### 3.3 详情页：语伴内容 + 全局上下文
`SettingsCapabilityDetailView.swift`：
- `requiresLanguageSpaceContext`：加 `&& kind != .companion`（设备级全局 flag，像 appearance 无需语言空间）。
- `showsCapabilityHeader`：companion → `false`（toggle 自带标题，免重复）。
- `detailContent` 加 `else if capability.kind == .companion { companionSettingsContent }`。
- 新增 `companionSettingsContent`：`CompanionSettingsToggleRow().langoPanel(padding: 16)`（开关在详情页获卡片框定）+ `LocalizedTextPanel(settings.companion.detail)`（ADR-008：始终目标语 / 单一对话对象 / 扎根记录 / 默认关）+ `LocalizedTextPanel(settings.companion.nextRequirement)`（隐私边界：启用后仅在显式使用按 consent 发送；语音/场景为远期）。**不**复用 `settingsNoSideEffects` 面板（语伴启用后存在显式发送副作用，不能宣称无副作用）。

### 3.4 三端：移除裸 toggle，接入尾值（保留 `LearnerProfileSettingsRow`）
- `PhoneMainSections.swift:371`（`SettingsView`）：删 toggle；`SettingsView` 加 `@Environment(\.companionFeatureEnabled)`，`.trailingValue(...)` 补 `companionEnabled: companionFeatureEnabled`。
- `PadMainSections.swift:350`：删 toggle；companion 行补 `.trailingValue(capability.kind == .companion ? localizedString(companionFeatureEnabled ? enabledKey : disabledKey) : nil)`（读 env；余行维持无尾值现状）。
- `MacWorkspaceContentView.swift:227`：删 toggle；已有 env（行 33），companion 行同补尾值。
- `LangoTraceSettingsSceneView.swift`：`canShowDetail` 加 `|| kind == .companion`（无语言空间也能进语伴详情）；加 env，`capabilityRows` 的 `settingsRowValue(...)` 补 `companionEnabled:`。

### 3.5 本地化（`Localizable.xcstrings`，en + zh-Hans）
新增 `settings.companion.title`(语伴 / Language Companion)、`.summary`、`.detail`、`.nextRequirement`、`settings.value.companion.enabled`(已启用 / Enabled)、`settings.value.companion.disabled`(已关闭 / Off)。toggle 复用现有 `companion.settings.toggle` + `.description`。新 Swift 代码零中文（`no-hardcoded-Han` 守卫）。

## 4. TDD 落点（先写失败测试，再最小实现）

### Data（`Packages/LangoTraceData/Tests`）
1. `SettingsCapability.Kind.allCases` 含 `.companion`；`.companion.systemImage == "bubble.left.and.bubble.right"`。
2. `GRDBLearningContentRepositoryBridge.settingsCapabilities.first?.kind == .companion`（首位）且 `status == .ready`。

### UI（`Packages/LangoTraceUI/Tests`）
3. `PageClosureStateTests`：`Kind.companion.localizedTitleKey == "settings.companion.title"`；`allCases.contains(.companion)`。
4. `SettingsRowValuePresentationTests`：`value(.companion, companionEnabled: true) == localizedString("settings.value.companion.enabled")`；`false → ...disabled`；`nil → nil`。
5. **源码守卫**（沿用现有 source-scan 风格 PageClosureStateTests）：`SettingsCapabilityDetailView.swift` 源含 `CompanionSettingsToggleRow`（开关已入详情）；`PhoneMainSections`/`PadMainSections`/`MacWorkspaceContentView` 源**不再**含 `CompanionSettingsToggleRow()`（迁移回归守卫）。
6. 全量 UI（`no-hardcoded-Han` + 既有守卫）确保新代码零硬编码中文。

### App
7. `LangoTraceApp` 编译靠 macOS app test（App 非 SPM 包，不单测）——env 透传无逻辑分支变更，零新装配。

## 5. 故障与恢复矩阵

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| 无语言空间进语伴详情 | `requiresLanguageSpaceContext` 豁免 + `canShowDetail` 放行 → 正常显示开关 | 源码守卫 + 人工 |
| 开关 env 未注入（默认） | env 默认 false → 尾值 `已关闭`、详情 toggle 关 | settingsRowValue 测试 |
| 尾值刷新滞后（projection） | 改走 env 而非 projection → 即时响应 | 设计 §3.2，人工双栏 |

**无新数据/网络路径**（feature flag 仍 UserDefaults，无新 migration / 无新 Provider 调用）。

## 6. 边界小结
- **无新 migration**（feature flag 仍 UserDefaults）。
- **无新 `AIRequestCapability` / 无外发类目变更**（纯设置 IA）。
- **无 Core 模型变更**（尾值走 env，不碰 `SettingsStatusProjection`）。
- **`SettingsCapability.Kind` 闭集新增 `.companion`**：须同步全部 exhaustive 消费点——`systemImage`(Data)、`localizedTitleKey`(UI)、`settingsRowValue`(UI)。三处均 switch（非 default），新 case 不加则编译失败 → **本任务故意逐一覆盖**（见 §10 P1）。
- ADR-008「默认关」不变，无 ADR 变更。

## 7. 范围外
- 「学习画像」分组化——现为唯一非能力行，引入分组 chrome 属过度设计；保留顶部单行（Apple-ID-row 惯例）。后续如仍觉孤儿另开小任务。
- 语伴远期（语音/场景/向量）不实现，仅详情页文案预留定位。

## 8. 验证
- 轻量（本机，单包逐个、**勿并发**——本会话教训共享 module cache 损坏）：`swift test --package-path Packages/LangoTraceData`、`Packages/LangoTraceUI`。
- App 编译靠 CI（`LangoTraceApp` 非 SPM 包）。完整 `Build & Test` 走 GitHub Actions（public→`gh workflow run ci.yml --ref dev`→绿→private），切可见性先取用户许可。
- 人工（iOS 模拟器）：设置页顶部仅「学习画像」单行；语伴变第一张能力卡（尾值 `已关闭`）；点进详情见开关+说明；开关后返回尾值变 `已启用`；练习 Tab 语伴入口随之出现。

## 9. 文档影响（§17 收口落点，实现后回写）
- `docs/platform-page-inventory.md`：设置页 changelog——语伴提升能力卡 + 详情页，开关迁入；学习画像为唯一非能力导航行。
- `docs/spec/003-ui-design-system.md`：changelog——设置行构成决议（能力卡走 `CapabilityStatusRow`；语伴入列；学习画像刻意保留单一非能力导航行，呼应 §411）。
- `docs/idea/03-conversation-partner.md`：语伴获独立设置详情页（IA 记录）。
- `docs/architecture/002-system-map.md`：如涉设置/语伴入口微调。
- 审查：纯 UI/IA，无数据/AI/权限/同步变化 → 按 `docs/review/README.md` 判断无需专项审查（在收口记录说明）。

## 10. 双轮隔离自审核记录（plan-review-protocol）

**轮次一（架构 / 正确性）**：
- **P1（闭集破坏，主风险，计划内逐一覆盖）**：`SettingsCapability.Kind` 加 `.companion` **必然破坏**三处 exhaustive switch——`systemImage`（Data）、`localizedTitleKey`（UI LocalizedChrome）、`settingsRowValue`（UI）。三处均无 `default`，不补即编译失败。**已在 §3/§4/§6 逐点钉死**，非 CI 才发现（吸取 S3b-1/S4b 教训）。`SettingsCapabilityDetailView` 用 `if/else if` 链（非 switch），加分支即可，不破。
- **P1（尾值数据源选择）**：尾值需反映 feature flag。两选项：(a) 扩 Core `SettingsStatusProjection`（一致但需刷新才更新，iPad/Mac 双栏同屏切换会滞后）；(b) 走 env `companionFeatureEnabled`（响应式即时）。**选 (b)**——更优 UX + 零 Core 变更 + 可单测（参数注入）。代价：Pad/Mac 主区 ForEach 需补 `.trailingValue`（这两面板其余行本就无尾值，仅 companion 特例，churn 小）。
- **P1（全局上下文豁免）**：语伴 flag 设备级全局，非语言空间作用域。`requiresLanguageSpaceContext` + `canShowDetail` 必须豁免 companion，否则无语言空间时详情被 boundary 拦截。已 §3.3/§3.4 覆盖（appearance 同例先证）。
- **P2（数组位置）**：companion 插首位 → 紧跟「学习画像」行，保留当前顶部语义。若插末位则语伴沉底，违背「保留位置」。钉首位。

**轮次二（隔离再审，对抗式）**：
- **toggle 迁入详情后可发现性是否下降？**——语伴从顶部裸行变为顶部第一张能力卡（带 `已关闭` 尾值），**仍在设置可见首屏**，反而更醒目（卡片 > 朴素行）；开关在详情页一级位置。结论：可发现性不降反升。非问题。
- **ADR-008 §2.6「默认关」是否被破坏？**——`UserDefaultsCompanionFeatureStore` 默认 false 不变，toggle 仍是同一 env 读写，仅 SwiftUI 位置移动。无行为变更。确认不破。
- **练习 Tab 入口门控是否受影响？**——三端练习区 `if companionFeatureEnabled { CompanionEntryCard }` 读同一 env，与 toggle 物理位置无关。开关迁移后门控逻辑零改动。确认无回归。
- **源码守卫脆性？**——「三面板不再含 `CompanionSettingsToggleRow()`」是 source-scan，沿用既有 PageClosureStateTests 同款风格（已有多处源扫描守卫），与现有基础设施一致；其意义 = 钉死「开关确已迁出列表」回归。可接受。
- **`status: .ready` 是否误导？**——列表 `showsStatusBadge: false`（不显 badge），详情 companion `showsCapabilityHeader: false`（不显能力头），故 `.ready` 不在 UI 暴露为「能力状态」，仅满足模型必填。用户感知的是尾值 `已启用/已关闭`（来自 flag），语义正确。非误导。
- **本地化键命名一致性？**——`settings.companion.*` 严格遵循 `settings.{kind}.{component}` 既有约定（`settingsCapabilityDetailLocalizationKeys` 自动按 `kind.rawValue` 派生 summary/detail/nextRequirement）；`settings.value.companion.*` 遵循 `settings.value.{kind}.*`（aiProvider/sync 同款）。一致。

**自审结论**：单任务连贯、无需下拆。最高风险 = P1 闭集破坏（三处 switch，已逐一钉死、计划内）+ 尾值数据源（选 env，理由充分）。可发现性、ADR-008、练习门控经对抗式审查均无回归。升 **Reviewed**，待用户实现授权。

> 用户 2026-06-27 已批准「按推荐顺序与方案进行」（方向授权）。本方案 Reviewed 后即按此授权进入 TDD 实现。

## 11. 收口记录（2026-06-27）

实现 commit `de86d18`；全量 CI `Build & Test` 绿 **run 28281128222**（App 编译 + 三端构建 + 全包 + lint + docs）。轻量本机：Data 287 / UI 627 绿、swiftformat 干净。

逐落点 TDD 落地：Data `SettingsCapability.Kind.companion`（chat 图标）+ 两处 `settingsCapabilities` 首位插入 / UI `localizedTitleKey` + `settingsRowValue(companionEnabled:)` 三态 + `SettingsCapabilityDetailView.companionSettingsContent`（toggle 入详情 + ADR-008 边界、豁免语言空间上下文）+ 三端移除裸 toggle 接尾值 + `LangoTraceSettingsSceneView.canShowDetail` 放行 + 6 个本地化 key（en/zh）。

**自审验证回填 / 实施期教训**：
- **P1 闭集破坏（计划内逐一覆盖 + 一处计划外）**：`SettingsCapability.Kind` 加 `.companion` 破坏 `systemImage`/`localizedTitleKey`/`settingsRowValue` 三处 switch——方案已列、当场补。**计划外一处**：`InMemoryLearningContentRepositoryTests` 有一条断言能力 kind **精确有序列表**的测试（首位插 companion 后 `==` 失败），本机 Data 测试当场捕获、补 `.companion` 于首位即过——印证「闭集顺序也可能被测试钉死」，本机轻量验证拦在 CI 前。
- **swiftformat docComments**：新增的两处 `// 仅 companion 行带尾值` 紧贴 `private func` 声明，被 `docComments` 规则要求改 `///` doc 注释——本机 `swiftformat --lint` 当场捕获、改 `///` 即过。
- **静态 vs 实例同名歧义**：测试初版引用 `GRDBLearningContentRepositoryBridge.settingsCapabilities`（静态）与实例 `settingsCapabilities(for:)` 基名相同致重载歧义，连类型标注也未消歧 → 改走 `InMemoryLearningContentRepository.seeded` 实例方法（与该测试文件既有风格一致）。

**偏差**：无。「学习画像」分组化按方案范围外保留为顶部单行，非偏差。

**边界确认**：无新 migration / 无新 `AIRequestCapability` / 无新外发类目 / 无 Core 模型变更；feature flag 仍 UserDefaults 默认关、ADR-008 §2.6 不变；练习 Tab 语伴门控读同一 env 无回归。纯 UI/IA，无数据/AI/权限/同步变化，按 `docs/review/README.md` 判断无需专项审查。
