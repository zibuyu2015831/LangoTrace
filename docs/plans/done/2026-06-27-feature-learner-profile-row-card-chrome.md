# 学习画像设置行补齐卡片底（设置 IA 视觉统一收尾）

状态：Done（2026-06-27 用户授权「立即进行」→ TDD 落地 → 轻量 UI 628 绿 → 全量 CI 绿 run 28281981091 → §17 回写 → 移 done/）
自审核状态：Reviewed（见末节双轮自审记录）
类型：feature
创建日期：2026-06-27
最后更新日期：2026-06-27

## Context（为什么做）

继语伴升级为标准 `SettingsCapability`（见 `done/2026-06-27-feature-companion-settings-capability.md`）后，三端设置列表里每一张能力行都是 `CapabilityStatusRow`，其 `body` 内部自带 `.langoPanel(padding: 16)`（`LearningContentComponents.swift:390`），因此都有卡片底。

而「学习画像」用的是 `LearnerProfileSettingsRow`（`PhoneMainSections.swift:398`）——一个裸 `Button`/`HStack`，**没有 `.langoPanel()`**。三端 call site（`PhoneMainSections.swift:371`、`PadMainSections.swift:359`、`MacWorkspaceContentView.swift:226`）均裸调，不补面板。结果它是这份列表里**唯一没有卡片底**的行，视觉上像孤儿——这正是用户截图指出的不一致。

## 决议（范围内 / 范围外）

把「卡片」拆成两件正交的事：

1. **视觉容器（卡片底）→ 补**。给 `LearnerProfileSettingsRow.body` 加 `.langoPanel(padding: 16)`，一处改动三端同时统一。
   - 不违背 UI 规范 003 §411：§411 反对「拿卡片当 section 默认外壳」，而这份列表的设计语言本就是「每行一张卡」，学习画像是唯一漏网行，补齐是回归一致，不是新增外壳。也更贴近 iOS 设置「Apple ID 行」——同样是带卡片底的 inset 行。

2. **是否升级为 `SettingsCapability` → 不升**（**范围外**）。学习画像是 LM02 的只读查看面（副标题「查看 App 对你的了解」），没有 `.ready/.mockOnly/.unavailable` 状态，也没有 `未配置/已开启` 尾值；塞进 capability 模型只会逼出无意义假状态。保留为顶部**唯一**非 capability 导航行（与语伴方案 scope-out 一致）。

3. **范围外**：分组化、新增 section chrome、改 chevron 语义、改 LM02 画像查看页内容。

不涉及 ADR 变更（无核心决策反转）；不涉及 Core/Data；纯 UI 视觉容器调整。

## 实现步骤（TDD：先失败，再改）

### 1. 失败测试（UI 源码守卫，沿用现有 source-scan 风格）
`Packages/LangoTraceUI/Tests/LangoTraceUITests/PageClosureStateTests.swift` 新增一个 `@Test`：
- `LearnerProfileSettingsRow` 所在源码 `PhoneMainSections.swift` 含 `struct LearnerProfileSettingsRow` 且其实现含 `langoPanel`（验证卡片底已补）。
- 断言它仍**不是** `CapabilityStatusRow`（源码仍含 `struct LearnerProfileSettingsRow: View`，回归「未被误升级为 capability」）。

### 2. 生产代码（一处）
`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift` 的 `LearnerProfileSettingsRow.body`：
- Button 的 label（`HStack`）补 `.frame(maxWidth: .infinity, alignment: .leading)` + `.langoPanel(padding: 16)`，镜像 `CapabilityStatusRow.rowContent` 的收尾，使整张卡可点且与能力行同款卡片底。保留行内既有 `chevron.right`（能力行也经 trailingImage 画 chevron，一致）。移除冗余 `.contentShape(Rectangle())`（面板背景已提供命中形状，镜像 `CapabilityStatusRow`）。
- 三端 call site 无需改（统一从 row body 生效）。

零新增中文（`no-hardcoded-Han` 守卫）；无新增本地化 key（复用现有 `learnerProfile.title` / `settings.learnerProfile.summary`）。

## 验证
- 轻量（本机，单包，勿并发）：`swift test --package-path Packages/LangoTraceUI`。
- App 编译靠 CI；全量 `Build & Test` 走 GitHub Actions（public→`gh workflow run ci.yml --ref dev`→绿→private），需用户许可切可见性。
- 人工：iOS 模拟器——设置页「学习画像」行获得与下方能力卡同款卡片底，三端一致；点击仍进 LM02 画像查看页，行为不变。

## §17 文档回写
- `docs/platform-page-inventory.md`：设置页 changelog——学习画像补齐卡片底，视觉与能力卡统一；仍为唯一非 capability 导航行（不带状态/尾值）。
- `docs/spec/003-ui-design-system.md`：changelog——设置列表「每行一张卡」为既定设计语言，学习画像补齐 `.langoPanel`，呼应 §411（非 section 外壳，是 per-row 卡片一致性）。

## 双轮自审记录（plan-review-protocol）

**Round 1（边界 / 正确性）**
- Q：补 `.langoPanel` 是否违背 §411？A：不违背。§411 针对「section 默认外壳」；此处是 per-row 卡片，列表内 5/6 行已是卡片，补齐第 6 行是一致性修复。已在决议 1 记录依据。
- Q：会不会破坏点击区域？A：镜像 `CapabilityStatusRow`（panel 在 Button label 内 → 整卡可点），移除 contentShape 与之对齐；风险低，模拟器人工复核点击。
- Q：是否影响 LM02 画像页本身？A：否，只改入口行容器，`action: onSelectLearnerProfile` 不变。
- Q：band 红线 / 隐私 / Provider？A：全不沾，纯视觉。

**Round 2（落点 / 回归）**
- 三端 call site 确认均裸调无自带 panel（已 grep 验证 `PhoneMainSections:371`/`PadMainSections:359`/`MacWorkspaceContentView:226`），改 row body 即三端生效，无遗漏面。
- 现有测试 `phoneSettingsListOmitsDuplicateCurrentSpaceExplainer` 与 `companionToggleMovedIntoCapabilityDetailPage` 不受影响（断言内容不含 LearnerProfile panel）。
- 新增源码守卫与现有 `sourceFileURL(named:)` helper 同风格，无新基础设施。
- 剩余风险：`.langoPanel(padding: 16)` 与能力行同参，视觉应一致；若设计上想让学习画像略突出（更大/置顶强调），属后续可选项，本任务不做。

## 收口（实现后回填）
- [x] 失败测试先红（`learnerProfileRowUsesCardChromeButStaysNonCapability` 初版红：缺 `langoPanel`）
- [x] 生产代码改后绿（本机 LangoTraceUI 单包 628 绿）
- [x] swiftformat 干净；swiftlint 仅 PhoneMainSections:251 / 测试文件头部既有 pre-existing warning，非本次新增
- [x] CI Build & Test 绿 run 28281981091（SHA 0270b41）
- [x] §17 文档回写（spec/003 + platform-page-inventory）
- [x] 移入 done/

实现期一处偏差与修订：源码守卫初版用 `!rowBody.contains("CapabilityStatusRow")`，被生产代码里「Mirror CapabilityStatusRow: …」**注释**误触发；改为 `!rowBody.contains("CapabilityStatusRow(")`（构造调用才是「是否升级为能力」的真实信号，注释提名无妨），同时把 rowBody 切片严格 bound 到 `LearnerProfileSettingsRow` 与下一个 top-level `struct` 之间，避免误纳同文件后续 `langoPanel`。
