# 任务方案：记录场景标签（scene）输入、展示与时间线筛选

状态：In Progress
自审核状态：Reviewed
类型：feature
创建日期：2026-07-22
最后更新日期：2026-07-22

## 用户确认记录

- 本任务在 `FABLE-MISSION.md` 授权的自主运行中执行（§2 第 3 条：未竟任务推进范围完全自主判断；§4 active plan 自批授权）。产品依据为既有核心决策 5「工作、生活、旅行、会议、情绪不是空间，而是标签、场景或 Prompt 模式」与产品主参考 §8.1「语种是空间，场景是标签」——本任务是既有决策的兑现，不引入新决策，无需新增 ADR。

## 需求描述

`entries.scene` 列自 schema 初版即存在，产品定义明确「场景是标签」（示例：日常生活、工作表达、旅行、情绪、会议、邮件），但当前：创建路径写死空串、无任何输入 UI、无筛选维度，且 iPhone/iPad 记录行在 scene 为空时渲染出尾部残留「· 」。`docs/README.md`「尚未完成」第 1 条即「时间线场景标签筛选与搜索联动」。本任务落地 v1：预设场景选择（创建时）、三端展示修正、iPhone/iPad 时间线场景筛选维度。

## 现状描述（HEAD `4070f6f`，经独立接缝勘查子代理核查）

- 数据层已就绪：`NewLearningEntryDraft.scene`（Core）、`LearningEntry.scene`（Data 模型）、GRDB `createEntry` 完整 trim + INSERT scene（`GRDBLearningContentRepository.swift:25-63`）、行映射 `row["scene"]`。
- 断点一（协议/桥接）：`LearningContentRepository.createEntry(spaceID:title:body:source:)`（`LearningContent.swift:17`）签名不含 scene；`GRDBLearningContentRepositoryBridge.swift:76` 写死 `scene: ""`；`InMemoryLearningContentRepository.createEntry` 写死 `scene: "今天"`（`LearningContent.swift:124`），seed 数据含「今天/昨天/本周」自由文本（`SeedLearningContent.swift:13/23/33`）——两实现写死值不同（隔离审核 P1-2 修正初稿「创建路径写死空串」的失真表述）。
- 生产库已存在自由文本 scene 入口：E10 导入路径 `GRDBLocalExportService.importPackage` 经 `insertOrIgnoreEntry` 把 `PortableEntrySnapshot.scene` 原样写入真实 `entries` 表（`GRDBLocalExportService.swift:89-151`）——自由文本兼容不是防御性过度设计，而是既有导入能力的必然要求（隔离审核 P1-3）。
- 断点二（创建 UI）：`EntryEditorView`（`PhoneMainSupportingViews.swift:5-96`，纯 @State View，`onSave: (String, String) throws -> Void`）无 scene 控件；iPhone（`PhoneMainView.swift:122`）与 iPad（`PadMainView.swift:96-101`）复用它；macOS 用独立 `MacEntryEditorSheet`（同款 onSave 签名，`MacEntryEditorSheetTests` 源码守卫禁止复用 mobile Form / 系统 sheet）。照片写作链路（`PhotoWritingSaveCoordinator`）同样不传 scene。
- 断点三（筛选）：`EntryTimelineFilter`（`EntryTimeline.swift:8-41`）为固定四例状态枚举（all/photo/needsPractice/settled），scene 是动态标签集，塞不进该枚举，需正交维度。iPhone 筛选为横向 chips（`PhoneMainSections.swift:99-153`，`@State selectedFilter`）；iPad 为侧栏 `FilterPill` 带 count（`PadMainSections.swift:47-59`，`PadMainView.swift:30`）；**macOS 无任何筛选 UI**（entries 未过滤直传）。Phone/Pad 过滤全部为视图内内存过滤，非 SQL。
- 展示 bug：iPhone `EntryCard`（`PhoneMainSupportingViews.swift:1073`）与 iPad `EntryTimelineRow`（`LearningContentComponents.swift:24`）用裸 `entry.scene`，空串时渲染 `文本输入 · 英语 · `；macOS `MacInspectorContent.swift:24` 已用兜底 helper `displayScene`（`LearningEntryDisplayExtensions.swift:23-27`，空串回退本地化 key `entry.defaultScene`，en `Journal` / zh `记录`）。
- 本地化惯例：xcstrings 只 ship en + zh-Hans，其余 6 语走 en fallback；守卫测试模板 `EntryDetailLocalizationTests`（读 catalog JSON 断言新 key 两语非空 + key 互异）。key 风格点分域名式（`entrySource.*`、`pad.filter.*`、`filter.settled`）。
- 测试先例：`Timeline/EntryTimelineFilterTests.swift`（逐 case `includes()`，fixture 已含 `scene: "今天"` 自由文本）、`EntryTimelineProjectionTests`（分组/计数）、`PhotoWriting/PhotoWritingSaveFlowTests`（coordinator）。

## 目标、范围和不做什么

目标：把「场景是标签」从产品文字变成可用闭环——创建时可选场景、三端一致展示、iPhone/iPad 时间线可按场景筛选；存储用 canonical slug，展示走本地化，符合 spec/006 界面语言边界。

范围内：

1. **Core**：新增 `EntryScenePreset: String, CaseIterable, Sendable`（rawValue 即存储 slug）：`daily` / `work` / `travel` / `mood` / `meeting` / `email`（产品主参考 §8.1 :204 示例集；:185 另提「社交媒体」，v1 有意不纳入预设——自由文本与未来自定义场景可承载，避免预设集过宽）。空串 = 未标注（沿用现状，不引入新哨兵值）。
2. **Data 协议与桥接**：`LearningContentRepository.createEntry` 增加 `scene: String` 参数；`GRDBLearningContentRepositoryBridge` 透传（删除写死空串）；`InMemoryLearningContentRepository` 改为 **trim 后透传**（与 GRDB 语义一致；其原写死 `"今天"` 的 fixture 行为随之变为默认空串——经核查约 20 处 UI 测试调用均无对该值断言，无红）；`UnavailableLearningContentRepository` 同步；`LearningContentStore.createEntry` 增加 `scene: String = ""` 默认参数（照片写作等既有调用零改动；协议 conformance 全仓仅上述三个，测试内 fake conform 的是 `GRDBLearningContentRepositoryProtocol`，走 draft 不受影响）。
3. **创建 UI**：`EntryEditorView` 与 `MacEntryEditorSheet` 增加预设场景单选 chips（可取消选择，默认未标注；`onSave` 增加 scene 参数）；iPhone/iPad/macOS 调用点透传。Mac 侧遵守既有源码守卫（自定义 overlay 内加 chips，不引入 mobile Form）；**同步更新 `MacEntryEditorSheetTests.swift:49` 的 `onSave(title, bodyText)` 源码守卫断言为新调用形态**（守卫语义不变：Mac 不复用 mobile Form、onSave/onCancel 存在），并同步 `MacEntryEditorSheet.swift` 的 `#else` 非 macOS stub（:224-233，同签名）。
4. **展示**：iPhone `EntryCard` 与 iPad `EntryTimelineRow` 改用 `displayScene`（修尾部「· 」）；`displayScene` 升级——scene 为预设 slug 时显示本地化标签，为历史自由文本时原样显示（防御旧数据），空串回退 `entry.defaultScene`。
5. **筛选（正交维度，三个状态语义钉死｜隔离审核 P1-4）**：`EntryTimeline.swift` 新增纯函数层——`availableScenes(entries:)`（当前空间实际出现的非空 scene 值，预设按枚举序、自由文本按 **Unicode 码点序**附后——locale 无关保证测试确定性）、`entriesMatching(scene:)` 应用函数、per-scene 计数。语义钉死：(a) 状态与场景两维的计数**均基于全量 entries**（沿用 iPad `matchCount` 既有先例，语义 =「该维度单独命中数」，不随另一维联动）；(b) `selectedScene: String?` 随 `languageSpace.id` 变化**重置为 nil**；(c) 选中场景不再出现在 `availableScenes` 时**自动回退 nil**（不留 stale 空时间线）。iPhone 在既有 chips 行尾部加场景 Menu（选中态高亮，含「全部场景」重置）；iPad 侧栏新增「场景」分区 pill 列表（带 count）。scene 与既有状态筛选为 AND；空结果复用既有 `timeline.filter.empty.*` 空态。
6. **展示 label 双通道（隔离审核 P1-5）**：既有 `FilterChipButton` / `FilterPill` 均为 key-based（`titleKey` 走 `localizedText`），**自由文本场景严禁作为 key 传入**（spec/006 用户内容边界）。场景展示 label 在 presentation 层解析（slug → 本地化 string；自由文本 → 原样 string），组件层增加接受已解析文本的入口（如 `FilterPill` 加 `init(text:)` 变体；iPhone 场景控件实现于 `PhoneMainSections.swift` 文件内，`FilterChipButton` 保持 private 不改可见性）。
7. **本地化**：预设 label key 沿 `entrySource.*` 风格统一为 `entryScene.daily|work|travel|mood|meeting|email`；筛选相关 `filter.scene.all`（全部场景）、`pad.sidebar.scenes`（场景分区标题）；en + zh-Hans；新增对应 LocalizationTests 守卫。

不做什么（登记去向）：

- **macOS 筛选 UI**：Mac 当前连状态筛选都没有，补齐属「Mac 时间线筛选整体切片」，不在本批塞入；登记入本方案「剩余风险/后续方向」。
- **场景编辑（已建记录改 scene）**：需新增 repo update 方法与三端详情 UI，作为紧随其后的独立小切片；登记于下（§后续方向），不在本批。
- **自定义场景输入**（用户自造标签）与**多标签**：涉及标签管理 UX 与可能的表结构演进，登记 `docs/architecture/notes/`（见文档影响）。
- **FTS/搜索联动与 SQL 级过滤**：沿用现有内存过滤惯例；搜索面板接 scene 维度留待搜索联动切片。
- **场景注入 AI Prompt**：不改任何 AI 请求路径、外发类目、请求预览投影（scene 不进入本批任何 Provider 请求）。
- 无 migration（列已存在）；无 Keychain / 权限 / 同步触碰。

## 证据与决策依据

- 接缝勘查子代理报告（2026-07-22，上文现状全部行号出处）+ 隔离双轮自审核（P1×5 已写回，见自审核记录）。
- 自由文本兼容的必要性证据：E10 导入路径可把任意 scene 写入生产 `entries` 表（`GRDBLocalExportService.swift:139-151`），三态 displayScene（slug→本地化 / 自由文本→原样 / 空串→默认）是导入能力的必然要求，且符合 spec/006 §3.6「用户内容不因界面语言重写」与 §4「稳定 code 存储、展示名仅 UI」。
- 产品主参考 §8.1（场景示例与「语种是空间，场景是标签」）；核心决策 5。
- `docs/workflows/add-platform-screen.md`（三端页面动作手册——本批不新增页面，仅在既有页面加控件，仍按其检查清单核对入口/状态/页面清单落点）。
- spec/006（界面语言边界：存储 canonical slug、展示本地化、内容不因界面语言重写——历史自由文本 scene 属用户内容，原样显示）。
- spec/003（UI 设计系统：chips/pill 样式复用既有 `FilterChipButton` / `FilterPill`）。

## 约束映射与验证路径

- 决策 5 / §8.1：场景为标签维度，不建新空间概念 ✓。
- spec/006：slug 存储 + 本地化展示 + 用户自由文本不翻译 ✓；新 key 只 ship en + zh-Hans ✓。
- 决策 10 / spec/005：scene 不进入任何 AI 请求，无预览/日志/外发类目变化 ✓。
- §1.4 TDD：见测试落点；Linux 无工具链，红相位逻辑成立 + CI 实证（先例：批次②）。

## 涉及的代码文件路径

- `Packages/LangoTraceCore/Sources/LangoTraceCore/EntryScenePreset.swift`（新建）
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`（协议 + InMemory + Unavailable）
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepositoryBridge.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`（EntryEditorView + EntryCard）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacEntryEditorSheet.swift`、`MacMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`、`PadMainView.swift`（调用点 + 筛选状态）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`、`PadMainSections.swift`（筛选 UI）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryTimeline.swift`（场景维度纯函数）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningEntryDisplayExtensions.swift`（displayScene 升级）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`（EntryTimelineRow）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PadSidebarControls.swift`（FilterPill text 入口变体）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/MacEntryEditorSheetTests.swift`（onSave 守卫断言同步更新）

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/MacInspectorContent.swift`（displayScene 用法先例）
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/Timeline/EntryTimelineFilterTests.swift`、`EntryDetail/EntryDetailLocalizationTests.swift`（测试模板）
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhotoWritingSaveCoordinator.swift`（确认零改动）

## 涉及的文档路径

- `docs/README.md`（「尚未完成」第 1 条改口径：场景筛选落地，搜索联动仍留）
- `docs/platform-page-inventory.md`（iPhone 记录 Tab、iPad 侧栏、macOS 编辑 sheet 行 + 变更记录）
- `docs/spec/learning-content/impl.md`（若其登记 createEntry 契约则同步）
- `docs/architecture/notes/`（新建：自定义场景/多标签演进备忘录）
- `FABLE-WORKLOG.md`

## 实施方案

按 TDD 分五步，每步先落测试：

1. **Core**：`EntryScenePreset` + 测试（slug 稳定性、allCases 顺序）。
2. **Data**：协议 `createEntry` 加 scene → bridge 透传 + InMemory/Unavailable 同步 → GRDB round-trip 测试（带 scene 创建后 `entries(for:)` 读回）。
3. **UI 纯函数**：`EntryTimeline.swift` 场景维度（availableScenes 排序、AND 过滤、计数）+ `displayScene` slug 本地化升级 → Timeline 测试扩展。
4. **UI 控件**：EntryEditorView / MacEntryEditorSheet chips + onSave 扩参 + 三端调用点 + iPhone Menu + iPad 侧栏分区 + EntryCard/EntryTimelineRow 换 displayScene → source-boundary 与本地化守卫测试。
5. **文档同批**：README 口径、页面清单三端行 + 变更记录、架构备忘录、worklog；提交带 `[ci]` 推送并观察。

## TDD / 测试落点

（逐条标注红相位性质：**行为红** = 断言驱动新行为；**编译红** = 签名/类型驱动，行为早已存在、参数接通即绿，属回归钉——两者按隔离审核 P2-1 区分，§1.4 未禁止编译红，先例批次②已认可。）

- **Core**（`Packages/LangoTraceCore/Tests/.../EntryScenePresetTests.swift` 新建，行为红）：`rawValue` 稳定性（存储契约，改动破坏历史数据语义）与 `allCases` 顺序（仅服务 availableScenes 排序）**分开断言、分别注明契约理由**。
- **Data**（`GRDBLearningContentRepositoryTests` 既有文件扩展，编译红/回归钉）：`createEntry(spaceID:title:body:source:scene: "work")` 后 `entries(for:)` 首条 `scene == "work"`。
- **UI Timeline**（`Timeline/` 新 `EntrySceneFacetTests.swift`，行为红）：`availableScenes` 预设枚举序 + 自由文本 Unicode 码点序附后 + 空串排除；scene AND 状态双重过滤；per-scene 计数基于全量 entries；**导入包携带自由文本 scene 的混合场景**（P1-3 补）；`selectedScene` 空间切换重置与 stale 回退的纯函数判定。
- **UI 展示**（source-boundary，挂进既有 convergence suite，行为红）：`PhoneMainSupportingViews.swift` 与 `LearningContentComponents.swift` 不再含 `entry.scene)` 裸插值（改用 `displayScene`）；**自由文本 label 不经 `localizedString(key:)` 查找**（P1-5 边界守卫）。
- **UI 本地化**（新 `EntryScene/EntrySceneLocalizationTests.swift`，复制 EntryDetailLocalizationTests 模板——`#filePath` 回溯层级与 `EntryDetail/` 子目录相同，行为红）：新 key en + zh-Hans 非空、互异。
- **displayScene 升级**（`LearningEntryDisplayExtensions` 对应测试，行为红）：slug 显示本地化标签、自由文本原样、空串回退 `entry.defaultScene`。
- **Mac 守卫同步**：`MacEntryEditorSheetTests.swift:49` 断言更新为新 onSave 调用形态（属守卫更新，非行为回归）。
- 红相位在本环境以「新断言/新签名在旧代码下必然失败」逻辑成立，绿相位由 CI 实证（先例：批次②）。

## 验证命令

聚焦（CI 内等价步骤）：`swift test --package-path Packages/LangoTraceCore`、`swift test --package-path Packages/LangoTraceData`、`swift test --package-path Packages/LangoTraceUI`。
完整：GitHub Actions `Build & Test`（HEAD 带 `[ci]`），conclusion=success 为准；三端构建步骤覆盖 App 调用点改动。

## 文档影响检查

- 页面清单：iPhone 记录 Tab（筛选 chips + 场景 Menu）、iPad 侧栏（场景分区）、macOS 编辑 sheet（场景 chips）三行 + 变更记录条目——确定交付。
- `docs/README.md`「尚未完成」第 1 条拆分：场景标签筛选完成，「搜索联动」保留。
- 新建架构备忘录：自定义场景 / 多标签 / SQL 级过滤 / Mac 筛选整体切片 / 场景编辑切片的演进提醒；顺带登记「E10 导入可引入自由文本 scene」的事实（P2-5）。
- 无 schema / AI / 权限 / 同步变化，不触发专项审查；spec/006 边界在方案内自证。

## 严格方案自审核记录

```text
审核日期：2026-07-22
审核方式：隔离审查（独立 general-purpose 子代理，新上下文、只读，HEAD 4070f6f 核验）
审核轮次：双轮合并
未使用隔离审查的原因：不适用（已使用）
发现摘要：P0=0；P1=5（① MacEntryEditorSheetTests:49 onSave 源码守卫会被扩参打红、未登记；② 「创建路径写死空串」失真——InMemory 写死「今天」、seed 含自由文本，扩参后行为未定义；③ 「库里只有空串」被证伪——E10 导入路径可写任意自由文本 scene，三态 displayScene 是必需而非过度设计，论据应换为导入证据；④ scene 正交维度三个状态语义未钉死（计数联动/空间切换重置/选中场景消失）；⑤ 既有 chips/pill 组件 key-based，自由文本不得作为 key 传入，需 presentation 层解析 + 组件 text 入口）；P2=5（编译红/行为红区分标注、#else stub 同步、自由文本排序钉 Unicode 码点序、本地化 key 前缀统一 entryScene.*、备忘录登记导入事实）；P3=3（Core 归属合适、社交媒体排除注明有意取舍、rawValue 与 allCases 分开断言）。
关键核验：协议 conformance 全仓仅 3 个（测试 fake 走 GRDBLearningContentRepositoryProtocol 不受影响）；store.createEntry 默认参数使 3 处生产 + 约 20 处测试调用零改动；六预设与 §8.1 :204 逐一对应；scene 不进入任何 AI 请求路径。
写回修改：现状描述两处事实修订；范围 2/3/5/6/7 条扩展（InMemory trim 透传、Mac 守卫与 #else stub、三语义钉死、label 双通道、key 统一）；TDD 落点逐条标注红相位性质 + 新增导入混合场景与边界守卫用例；涉及文件补 2 个；证据依据换导入路径论证。
仍需用户确认的问题：无（既有决策 5/§8.1 的兑现，无新决策、无外发、无 migration，自批授权范围内）。
是否允许进入实现：是（P1 修订已全部写回本方案）。
```

## 实施记录

（待实施后写回）

## 完成标准

- 三端创建记录可选预设场景并持久化；iPhone/iPad 时间线可按场景筛选（与状态筛选 AND）；三端行展示无尾部「· 」残留。
- 全部新测试随实现入库；CI `Build & Test` success。
- 页面清单、README、备忘录同批更新；plan 移 `done/`。

## 后续方向（登记，不在本批）

- 场景编辑小切片（repo update 方法 + 详情 UI）。
- Mac 时间线筛选整体切片（状态 + 场景）。
- 搜索联动（SearchPalette 场景维度 / SQL 过滤）。
- 自定义场景与多标签（见架构备忘录）。

## 剩余风险

- `EntryEditorView.onSave` 扩参波及三端调用点与 Mac 源码守卫测试；缓解：逐调用点核对 + CI 三端构建。
- 历史自由文本 scene（如测试 fixture「今天」）与预设并存的排序/显示语义已定义（预设序 + 字典序附后、原样显示）；缓解：专门测试用例覆盖混合场景。
- 本机无法跑 Swift；缓解：红绿逻辑推演 + CI 实证，遵循批次②教训（命名避开歧义、聚焦包全列）。
