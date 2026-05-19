# iOS 页面元素级设计审查

审查类型：专项审查
日期：2026-05-19
代码快照：`36528543257e11104b0a0b76f8c79ed8c2d51082`
状态：Verified
当前事实源：`docs/review/rounds/2026-05-19-ios-page-element-design-audit/`
后续覆盖记录：`docs/plans/done/2026-05-19-feature-ios-page-element-convergence-and-mock-photo-writing.md`
可作为依据：Yes

## 1. 触发原因

用户要求统一前一轮关于 iOS 记录详情页“请求预览”卡片的结论，并将审查范围扩大到 iOS 端所有页面。审查必须站在 LangoTrace 的项目定位和愿景上，对所有页面的每一个元素判断是否服务“用生活记录学习语言”，而不是只判断局部页面是否美观。

本轮只做 iOS 页面和元素级设计审查，不修改 SwiftUI 实现，不接入真实 AI、TTS、OCR、Speech、同步、StoreKit 或权限流程。

## 2. 使用的专业依据

本轮选择一个专业 skill，避免设计准则冲突：

- `ios-design-guidelines`：用于 iPhone HIG、触控目标、层级、导航、Dynamic Type、系统手势和主操作位置判断。

仓库内依据：

- `docs/product-main-reference.md`：语迹是“把真实生活变成外语学习材料”的本地优先语言学习 App，不是 AI 聊天、课程闯关、云平台或后台配置中心。
- `docs/spec/002-navigation-and-routing.md`：iPhone 应围绕 `记录 / 练习 / 记忆` 三个主目的地，设置低干扰可达。
- `docs/spec/003-ui-design-system.md`：UI 应高级、现代、简洁、长期可读；隐私边界可理解但不打扰主流程。
- `docs/spec/005-ai-provider-prompt-and-privacy.md`：中高风险外部 AI 请求需要可理解的请求预览和确认；低风险短文本可以简洁确认。

## 3. 总体裁决

当前 iOS 骨架方向正确：主导航已经收敛为 `记录 / 练习 / 记忆`，记录是首屏主动作，设置不再作为底部 Tab。问题集中在元素层级：不少元素仍把“能力边界、mock 状态、隐私解释、后续接入条件”放进主学习流程，导致页面像产品规范展示，而不是付费级日常学习工具。

本轮统一结论：

1. iOS 主流程页面应把“生活记录 -> 目标语言表达 -> 逐句练习 -> 记忆沉淀”作为唯一主线。
2. “请求预览”不应常驻出现在 iOS 记录详情页或练习页；它应只在用户显式触发外部 AI 能力时以 sheet / confirmation path 出现。
3. 本地优先和隐私边界仍是产品优势，但在主流程里应降级为短状态、图标、设置页说明或首次相关动作确认，不能用大块说明卡反复打断学习。
4. iOS 页面要减少“解释系统将来会做什么”的文字，增加“现在用户下一步做什么”的动作。
5. 真实级展示不等于隐藏边界，而是把边界放到正确层级：主流程轻、设置和外发确认清楚。

## 4. 页面与元素审查

### 4.1 Welcome

涉及代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView+Layout.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`

判断：

- 保留：品牌名、价值主标题、产品预览、底部 CTA。它们能解释“生活内容如何变成学习材料”。
- 保留但弱化：状态条若只是表达本地优先、买断、AI 可选，应短而轻；不要扩展成隐私说明列表。
- 调整：iPhone compact 首屏不应像营销页停留太久。CTA 应明确导向“创建第一个语言空间 / 开始记录”，不要让预览卡压过行动。
- 风险：欢迎页作为首次体验可以解释价值，但不能成为长期 App 首页。

设计结论：Welcome 是一次性入口，不是主产品页面。后续截图和真实级演示应更多展示记录页和练习闭环。

### 4.2 Onboarding

涉及代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`

判断：

- 保留：母语、目标语言、水平自评。这三项与语言空间决策一致。
- 保留：底部固定创建按钮，符合 iPhone 主操作拇指区。
- 调整：隐私卡可以保留一行本地创建说明，但不应成为与三项核心选择同等视觉重量的大卡。
- 调整：语言选择 `Menu` 的 36pt 视觉高度偏低；外部行高有 52pt，但菜单自身应确保可感知为可点控件。
- 删除倾向：若隐私卡与底部摘要同时出现导致首屏拥挤，应优先保留底部摘要，隐私说明降为创建按钮上方短句。

设计结论：Onboarding 的任务是创建语言空间，不是讲完整数据政策。

### 4.3 iPhone 全局框架与顶部上下文

涉及代码：

- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneContextHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`

判断：

- 保留：底部 `记录 / 练习 / 记忆` 三 Tab。它符合当前导航规范和 iPhone 使用场景。
- 保留：顶部语言空间 capsule。用户需要随时知道“我正在学哪门目标语言”。
- 调整：语言空间 capsule 不应看起来像高频切换器；第一阶段更像当前空间摘要入口。辅助标签可以继续说“打开语言空间详情”，视觉文案不必暗示频繁切换。
- 保留：gear 设置入口。它低干扰、稳定可达。
- 调整：每个 Tab 顶部都重复上下文 header 是可接受的，但视觉上应更轻，避免每页第一屏都先看到配置上下文。

设计结论：全局框架已基本正确，后续重点是压低 header 重量，让内容主线更靠前。

### 4.4 记录 Tab

涉及代码：

- `PhoneRecordWorkspaceView`
- `HeroActionCard`
- `EntryCard`
- `EmptyEntryPanel`

判断：

- 保留：Hero 主卡和“写一句”主按钮。它最贴近产品北极星。
- 调整：“写一句”可以更自然地表达为“记录一点生活”或“写下今天的一句”。当前 `common.writeSentence` 偏功能控件，不如生活记录导向。
- 调整：`照片写作`、`听` 两个 secondary chips 现在会进入 unavailable sheet。真实级展示中，不建议把未接入能力放在 Hero 主卡第二层。可以移到 `更多`、后续能力区，或在未接入阶段隐藏。
- 保留：最近生活记录列表。
- 调整：EntryCard 同时展示标题、来源、目标语、场景、练习摘要、原文、目标语，信息密度偏高。iPhone 列表应优先展示：标题 / 原文摘要 / 目标语一句预览 / 练习状态。来源、场景可进入详情页。
- 调整：右侧 practice summary chip 和 chevron 与标题共享同一行；在窄屏或 Dynamic Type 下存在挤压风险。优先保留 chevron 或状态，不要两者都抢占第一行。
- 保留：空状态动作，但文案应指向“写下第一条生活记录”，不要说“没有记录”后停住。

设计结论：记录 Tab 是 iOS 的核心页面，应最先做“去边界化”和“生活记录语言化”精简。

### 4.5 新建记录 Sheet

涉及代码：

- `EntryEditorView`

判断：

- 保留：sheet、标题输入、正文 TextEditor、保存 / 取消。
- 调整：标题不应成为必填心智。目前保存只校验正文，但 UI 上标题与正文同组，用户可能以为标题也必须写。建议标题弱化为可选，或自动从正文生成。
- 调整：隐私 section 视觉占比偏高。新建记录时用户最关心写作，不是读隐私说明。可改为表单底部一行 footnote：`保存在本机`。
- 调整：TextEditor 180pt 对随手记录足够，但对于“日记/照片故事”偏短；可根据内容增长或使用更沉浸的输入区域。

设计结论：新建记录要像写生活片段，不像填写设置表单。

### 4.6 记录详情页

涉及代码：

- `EntryDetailView`
- `EntryDetailHeader`
- `TextPanel`
- `RequestPreviewCard`
- `SentencePairView`

判断：

- 保留：标题、母语记录、目标语言表达、逐句练习。这是核心闭环。
- 删除：常驻 `RequestPreviewCard`。它不应出现在详情页默认阅读流。
- 删除或大幅弱化：`entryDetail.header.boundary`。当前文案“使用在线能力前，可先在本机检查学习材料”像边界说明，不像记录详情。
- 调整：`TextPanel` 对母语和目标语使用同等卡片，导致页面卡片化。详情页可采用更像阅读页面的连续排版，用轻分隔而非每段一个大卡。
- 调整：`逐句练习` subtitle 应删除或变短。当前“从真实记录进入听、读、跟读和回译”是在解释理念，不是页面必要信息。
- 调整：`进入练习` section 与每个句子的“练”按钮存在重复。若每句已可练，底部 practice entry 区应删除；若要进入完整会话，只保留一个底部主按钮。
- 调整：句子卡内 `听` 在未接入时弹 unavailable，会让真实级页面显得未完成。未接入 TTS 前，建议显示 disabled 状态或隐藏 `听`，保留 `练`。
- 调整：句子编号 34pt 小于 44pt 但非交互；可保留。按钮区域需保证 Dynamic Type 下不挤压正文。

设计结论：记录详情页应是最清爽的学习材料页。请求预览、边界说明、重复练习入口都应移出主流。

### 4.7 练习 Tab

涉及代码：

- `PracticeView`
- `CapabilityStatusRow`

判断：

- 保留：练习作为一级 Tab。它适合 iPhone 碎片学习。
- 调整：按 Entry 展示多种 practice item 时，列表会变成能力状态清单。用户更需要“继续上次练习 / 今天可练的 3 句 / 最近记录”。
- 调整：`CapabilityStatusRow` 的 badge、图标、summary、chevron 适合设置能力，不适合练习列表。练习列表应有更轻的行组件。
- 调整：无练习内容时应给出主动作：去记录一条生活，或选择最近记录生成本地学习材料。

设计结论：练习 Tab 不应像功能状态页，应像“今天练什么”的行动页。

### 4.8 练习会话页

涉及代码：

- `PracticeSessionView`
- `PracticeControlBar`
- `PracticeStepPanel`
- `RequestPreviewCard`

判断：

- 保留：step control 和当前练习内容。
- 删除：常驻 `RequestPreviewCard`。练习时反复看到请求边界会打断学习。
- 调整：`practice.sourceBoundary` 与同页常驻请求预览卡都在解释本机/外发边界，可降级为小号来源信息，或只在详情菜单中展示。练习页主视觉应给目标语、播放/跟读/下一步。
- 调整：当前没有音频、录音和评分时，练习页应诚实但不消极。可以聚焦“朗读 / 对照 / 回译自测”，避免出现“不会录音”这类防御性文案。

设计结论：练习页要进入状态，而不是解释状态。

### 4.9 记忆 Tab

涉及代码：

- `MemoryView`
- `MemoryLayerSummaryView`
- `CompactPanel`

判断：

- 保留：个人词句列表。它符合“长期语言资产”。
- 调整：`Content Memory / Language Memory / Study Memory` 三层摘要偏系统架构，不是 iPhone 用户的第一屏信息。可以合并成一个轻量 summary 或移到后续统计页。
- 删除：`Vector Index` 常驻卡片。向量索引是技术能力，不应出现在 iPhone 记忆主页面。
- 调整：Memory item 需要回到原始生活上下文。目前 `CompactPanel` 只是静态卡，缺少“来自哪条记录 / 复习 / 打开上下文”的行动感。

设计结论：记忆页应呈现“我从生活里积累了哪些表达”，不是呈现数据层结构。

### 4.10 设置列表与设置详情

涉及代码：

- `SettingsView`
- `SettingsCapabilityDetailView`
- `LanguageSpaceSummaryView`

判断：

- 保留：设置作为 toolbar 入口，不进入底部 Tab。
- 保留：AI Provider、同步、本地数据、隐私、导出、界面语言等能力入口。
- 调整：设置列表标题“当前空间”与内容不完全匹配，因为列表包含全局偏好和能力边界。应拆分为 `语言空间`、`能力与数据`、`界面` 等组。
- 调整：`CapabilityStatusRow` 在设置页可用，但所有能力都使用大卡会显得沉重。iPhone 设置更适合系统 `List` 风格或紧凑分组行。
- 调整：设置详情中的 `当前状态 / 接下来 / 隐私说明` 三块是工程计划式表达。真实级产品应改为：当前配置、可用动作、数据范围。未接入时可以保留“尚不可用”，但少说内部实现条件。
- 保留：界面语言 picker，但说明文本三段过长。应把 package/app/system/language-boundary 的详细解释移入帮助说明，主设置只保留必要差异。

设计结论：设置页可以承载边界，但要像用户偏好页，不像开发验收页。

### 4.11 Unavailable Sheet

涉及代码：

- `UnavailableCapabilityView`
- `UnavailableCapabilityContent`

判断：

- 保留：未接入能力必须诚实说明，避免假功能。
- 调整：不应从 Hero 或高频练习按钮频繁进入 unavailable。真实级页面应减少未接入入口的可见性。
- 调整：sheet 内三张大卡 `状态 / 接下来 / 不会发生` 过重。更适合一张说明卡 + 一个主要替代动作。
- 调整：关闭按钮使用文字可接受，但在 sheet header 中可以使用系统 close icon 或 `Done`，保持 iOS 语义。

设计结论：unavailable 是边界兜底，不是主流程组成部分。

### 4.12 共享组件

涉及代码：

- `CapabilityStatusRow`
- `RequestPreviewCard`
- `SectionHeader`
- `CompactPanel`
- `TextPanel`
- `SecondaryActionChip`
- `InlineStatusLabel`

判断：

- `RequestPreviewCard`：保留为外部 AI 请求确认组件，但从 iOS默认详情/练习流移除。
- `CapabilityStatusRow`：保留给设置、能力状态和 unavailable；不要复用为练习列表主组件。
- `TextPanel`：适合短说明，不适合承载全部阅读内容；记录详情应减少连续大卡。
- `SectionHeader`：subtitle 默认应谨慎。iOS 高级感来自清晰结构，不来自解释每个 section。
- `SecondaryActionChip`：适合已可用的次级动作；未接入功能不应长期占据 Hero。
- `InlineStatusLabel`：适合轻状态，但列表右侧空间有限，应避免和 chevron 同时挤压标题。

## 5. P1 / P2 / P3 问题清单

### P1

| ID | 问题 | 证据 | 影响 | 推荐方向 |
| --- | --- | --- | --- | --- |
| IOS-ELEMENT-001 | 请求预览常驻在记录详情和练习会话主流 | `EntryDetailView` 和 `PracticeSessionView` 直接渲染 `RequestPreviewCard` | 打断学习主线，页面显得像隐私/开发说明页 | 从默认流移除，仅在显式外部 AI 请求 sheet 中使用 |
| IOS-ELEMENT-002 | 记录详情有过多边界说明 | `entryDetail.header.boundary`、`entryDetail.practiceEntry.subtitle`、`requestPreview.*` | 削弱阅读和练习沉浸感 | 只保留短状态，边界说明移到设置或外发确认 |
| IOS-ELEMENT-003 | 记录 Hero 把不同域的未接入能力并列 | `照片写作`、`听` 直接进入 unavailable | 首屏像 demo，不像真实付费工具，且记录入口和练习入口混在一起 | 保留并产品化 `照片写作`，用本地模拟展示承接；`听` 移到练习域 |
| IOS-ELEMENT-004 | 记忆页展示技术结构 | `MemoryLayerSummaryView`、`memory.vectorIndex.*` | 用户看到数据层概念，而不是个人表达资产 | 改为词句列表、来源上下文、复习动作 |
| IOS-ELEMENT-005 | 练习列表复用能力状态组件 | `PracticeView` 使用 `CapabilityStatusRow` | 练习页像能力清单，不像行动页 | 新建轻量练习任务 row，突出继续练习 |

### P2

| ID | 问题 | 证据 | 影响 | 推荐方向 |
| --- | --- | --- | --- | --- |
| IOS-ELEMENT-006 | 新建记录隐私 section 过重 | `EntryEditorView` 第二个 Form section | 写作表单像合规表单 | 改为底部 footnote 或保存按钮附近短句 |
| IOS-ELEMENT-007 | 设置详情偏工程计划表达 | `settings.*.nextRequirement`、`settings.detail.*` | 真实级页面露出内部路线 | 改为用户动作、当前配置和数据范围 |
| IOS-ELEMENT-008 | EntryCard 信息密度偏高 | 标题行同时含来源、目标语、场景、状态 chip 和 chevron | 小屏和 Dynamic Type 下存在可读性风险 | 列表只放识别、预览和下一步状态 |
| IOS-ELEMENT-009 | 练习页来源边界文案与请求预览说明重复 | `PracticeStepPanel` 渲染 `practice.sourceBoundary`，同一页面随后渲染 `RequestPreviewCard` | 练习状态被说明文字稀释 | 改为小号来源元信息或详情菜单 |
| IOS-ELEMENT-010 | Onboarding 隐私卡层级偏高 | `privacyNote` 与核心选择同级 | 首次创建路径不够聚焦 | 降为短句或创建按钮附近说明 |

### P3

| ID | 问题 | 证据 | 影响 | 推荐方向 |
| --- | --- | --- | --- | --- |
| IOS-ELEMENT-011 | 部分 section subtitle 是理念解释 | `entryDetail.sentences.subtitle`、`phone.practice.fromLife.subtitle` | 文案显得啰嗦 | 删除或改成动作型短句 |
| IOS-ELEMENT-012 | 语言空间 capsule 视觉略重 | `PhoneContextHeader` capsule 每页重复 | 主内容首屏位置被配置上下文占用 | 视觉弱化，保持可达 |
| IOS-ELEMENT-013 | 设置列表分组不足 | `SettingsView` 单 section 承载全部能力 | 信息结构不够 iOS 原生 | 拆分为语言空间、能力与数据、界面 |

## 6. 推荐改造顺序

1. iOS 主流程去说明化：移除详情/练习常驻 `RequestPreviewCard`，删除或弱化边界型 subtitle。
2. 记录页真实级收敛：Hero 保留写一句主动作和照片写作强次级入口；未接入但关键的照片写作先用本地模拟展示承接；EntryCard 精简。
3. 练习页行动化：练习 Tab 和练习会话改成任务/步骤导向，不复用设置状态行。
4. 记忆页产品化：隐藏向量索引和三层技术摘要，突出词句、来源记录和复习动作。
5. 设置页承接边界：把 AI、同步、隐私、导出等说明集中到设置详情，改成用户语言而非工程语言。
6. Onboarding 轻量化：只保留创建语言空间必要信息，把隐私说明变成短确认。

## 7. 与请求预览的统一设计边界

请求预览不取消，但改变出现层级：

- 不出现在：iOS 记录详情默认流、练习会话默认流、记录列表、记忆主页面。
- 可以出现在：用户点击“在线生成 / AI 改写 / 分析照片 / 分析音频 / 引入历史记忆”后的确认 sheet。
- 应出现在：中高风险外部请求，包括完整记录、照片、音频转写、OCR 文本、长期记忆片段或多条历史记录。
- 可简化：低风险、用户当前刚输入的短文本请求，可以使用简洁确认和设置级透明说明。

这与产品定位不冲突：LangoTrace 可以保持随手记录和高级感，同时不牺牲本地优先和外发透明。

## 8. 复查方法

后续实现后至少检查：

- iPhone 记录详情首屏不出现 `请求预览`、`Provider`、`不会发送` 等大块边界说明。
- iPhone 练习会话中不出现常驻请求预览卡。
- 记录 Tab 首屏主动作 5 秒内可识别为“记录生活”，且没有未接入功能占据主按钮旁最高层级。
- 记忆 Tab 不出现 `向量索引` 作为普通用户主卡片。
- 设置页仍可找到 AI、同步、隐私、导出和界面语言边界。
- Dynamic Type 下 EntryCard、SentencePairView、Practice row 不出现横向挤压或遮挡。

建议验证命令：

```bash
swift test --package-path Packages/LangoTraceUI
xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

## 9. 剩余风险

- 本轮基于代码和文案审查，未运行模拟器截图矩阵、VoiceOver、Dynamic Type 自动截图或真机手势验证。
- 本轮不修改代码；P1/P2 仍需新的 iOS 页面精简与产品化收敛任务方案承接。
- 若后续决定“低风险短文本完全不弹确认”，需要同步更新 `docs/spec/005-ai-provider-prompt-and-privacy.md` 的同意级别描述，而不是只改 UI。

## 10. 代码复查记录

复查日期：2026-05-19
复查方式：逐条对照当前 SwiftUI 代码和 `Localizable.xcstrings` 文案，不以截图印象替代代码证据。
复查结论：P1 / P2 / P3 清单中的 13 个问题均真实存在；其中 `IOS-ELEMENT-008` 和 `IOS-ELEMENT-009` 的描述已在本轮复查中收紧，避免把风险判断写成已发生事实。

| ID | 复查结论 | 代码证据 | 修正 |
| --- | --- | --- | --- |
| IOS-ELEMENT-001 | 成立 | `EntryDetailView` 在有 `rendering` 时渲染 `RequestPreviewCard`；`PracticeSessionView` 在有 `session` 时也渲染 `RequestPreviewCard`。 | 无 |
| IOS-ELEMENT-002 | 成立 | `EntryDetailHeader` 渲染 `entryDetail.header.boundary`；详情页同时渲染 `entryDetail.practiceEntry.subtitle` 和 `RequestPreviewCard`。 | 无 |
| IOS-ELEMENT-003 | 成立 | `HeroActionCard` 渲染 `SecondaryActionChip(titleKey: "entrySource.photoWriting")` 和 `SecondaryActionChip(titleKey: "common.listen")`；`PhoneMainView` 将二者接到 `.unavailable(.photoWriting)` / `.unavailable(.listenOne)`。 | 无 |
| IOS-ELEMENT-004 | 成立 | `MemoryView` 先渲染 `MemoryLayerSummaryView`，后渲染 `LocalizedCompactPanel(titleKey: "memory.vectorIndex.title")`。 | 无 |
| IOS-ELEMENT-005 | 成立 | `PracticeView` 对无练习和有练习两种分支都使用 `CapabilityStatusRow`。 | 无 |
| IOS-ELEMENT-006 | 成立 | `EntryEditorView` 的 `Form` 包含独立隐私 `Section`，展示 `entryEditor.privacy.localOnly`。 | 无 |
| IOS-ELEMENT-007 | 成立 | `SettingsCapabilityDetailView` 固定渲染 `settings.detail.currentBoundary`、`settings.detail.nextRequirement` 和 `settings.detail.noSideEffects` 三块；文案包含多个 `settings.*.nextRequirement`。 | 无 |
| IOS-ELEMENT-008 | 成立，但属于布局风险 | `EntryCard` 首行左侧包含 title、source / target / scene，右侧包含 `InlineStatusLabel` 和 chevron。未运行截图矩阵，因此准确表述为窄屏 / Dynamic Type 风险。 | 已收紧措辞 |
| IOS-ELEMENT-009 | 成立 | `PracticeStepPanel` 渲染 `practice.sourceBoundary`；同一 `PracticeSessionView` 随后渲染 `RequestPreviewCard`。 | 已明确重复对象是同页请求预览 / 本机边界说明 |
| IOS-ELEMENT-010 | 成立 | `OnboardingView` 的主体 `VStack` 依次包含 `header`、`languageForm`、`privacyNote`；`privacyNote` 使用完整 panel。 | 无 |
| IOS-ELEMENT-011 | 成立 | `EntryDetailView` 使用 `entryDetail.sentences.subtitle`；String Catalog 文案为“从真实记录进入听、读、跟读和回译。” | 无 |
| IOS-ELEMENT-012 | 成立，属设计层级判断 | `PhonePage` 在每个 Tab 内容前渲染 `PhoneContextHeader`；header 中语言空间 capsule 使用 `surfaceAccentMuted` 背景并重复出现。 | 无 |
| IOS-ELEMENT-013 | 成立 | `SettingsView` 只有一个 `SectionHeader(titleKey: "phone.settings.currentSpace.title")`，随后直接 `ForEach(capabilities)` 渲染全部 capability。 | 无 |

## 11. 第二 Skill 复查记录

复查日期：2026-05-19
复查 skill：`ui-ux-pro-max`
复查视角：移动端产品 UI/UX、信息层级、渐进披露、表单反馈、空状态和主操作层级。

### 11.1 一致意见

`ui-ux-pro-max` 与 `ios-design-guidelines` 在核心结论上没有冲突：

- `RequestPreviewCard` 不应常驻在 iOS 记录详情和练习会话主流。它属于显式外部请求确认，不是默认学习内容。
- iOS 记录页必须保持一个清晰主动作。当前 Hero 中主按钮之外同时放 `照片写作` 和 `听` 两个未接入入口，会稀释主动作。
- `CapabilityStatusRow` 不适合作为练习列表的主 row。它包含状态 badge、说明、图标和 chevron，更像设置/能力状态组件。
- 记忆页不应把 `Vector Index` 当作普通用户主卡片。
- 设置页可以承载 AI、同步、隐私、导出边界，但当前三块式 `当前状态 / 接下来 / 隐私说明` 过于工程计划化。

### 11.2 不同或补充意见

第二 skill 没有推翻 P1 / P2 / P3 清单，但给出以下补充：

1. 对 `IOS-ELEMENT-003` 的推荐方向应避免简单“全部隐藏未接入能力”。更稳妥的产品化策略是渐进披露：首屏 Hero 只显示可用主动作；未接入的照片/听一句可以进入低频 `更多`、设置中的能力说明，或在 seed/demo 内容中以 disabled preview 出现。这样既不把主流程做成 demo，也不让用户完全不知道路线。
2. 对 `IOS-ELEMENT-006`，新建记录中的隐私说明不一定要删除，只应从独立 section 降级。表单底部 persistent helper text 比隐藏说明更好，因为用户输入的是生活记录，仍需要最小信任提示。
3. 对 `IOS-ELEMENT-008`，如果后续保留 EntryCard 的双语预览，应采用明确的信息优先级，而不是只删字段。优先级建议为：标题或首句 -> 母语摘要 -> 目标语一句 -> 练习状态。来源、场景、source title 可进入详情。
4. 对 `IOS-ELEMENT-010`，Onboarding 隐私卡的层级问题成立，但完全移除会削弱本地优先的首次信任。更好的做法是把它变成创建按钮附近的短句，或在创建完成后的设置/语言空间摘要中承接。
5. 对 `IOS-ELEMENT-012`，语言空间 capsule 重复出现不一定是问题本身。问题是视觉重量和首屏占位。后续可以保留每页上下文，但应降低背景、字号或位置权重，而不是取消上下文。

### 11.3 对原审查结论的调整

无需调整 P1 / P2 / P3 严重度。

需要在后续实现方案中吸收的补充约束：

- 不把“隐藏未接入能力”作为唯一修复方式；优先使用渐进披露、disabled preview 或设置承接。
- 不把“去说明化”误解为“去信任提示”。主流程可以轻，但新建记录、外部请求和设置仍要保留必要信任提示。
- 列表精简应按信息优先级重排，不只是机械删除字段。

## 12. 用户反馈后的记录页入口裁决

更新日期：2026-05-19
触发原因：用户指出 `照片写作` 对 iPhone 记录页有高频价值：当用户打开 App 但不知道输入什么时，可以拍照，让 AI 提供话题、示例或表达起点；`听` 则更适合进入练习域。

### 12.1 裁决

`IOS-ELEMENT-003` 的问题不应理解为“照片写作和听都应从记录页删除”。更准确的裁决是：

- `照片写作` 应保留为记录页高频次级入口，因为它服务记录页的核心阻塞点：用户不知道写什么。
- `听` 不应作为记录页 Hero 的同级入口。它不是记录起点，而是已有学习材料后的练习动作，应移到 `练习` Tab、记录详情的句子级操作，或练习会话中。
- 记录页 Hero 的动作层级建议为：主动作 `写一句 / 记录一点生活`；次级高频入口 `照片写作 / 用照片开始`；不再并列展示 `听`。
- 如果真实 AI、PhotosUI 或权限尚未接入，`照片写作` 可保留为 disabled preview、低风险说明或明确 unavailable sheet，但视觉层级仍应高于普通后续能力，因为它属于记录起点而不是配置能力。

### 12.2 设计理由

`照片写作` 与产品北极星一致。语迹不是让用户凭空完成写作任务，而是把真实生活材料变成语言学习材料。照片是生活记录的重要入口，尤其适合 iPhone 的随手记录场景：

- 用户不知道写什么时，照片可以降低启动成本。
- 照片可以把“生活场景”具体化，再由 AI 生成话题、描述示例或目标语表达。
- 拍照入口能让 iPhone 端区别于纯文本日记 App，也能自然连接后续 OCR、照片故事、TTS 和跟读。

`听` 的任务属性不同。听力和跟读是学习材料生成后的消费与练习行为，不是记录页的创建起点。把它放在记录 Hero 中，会让用户不清楚当前页面到底是“记录生活”还是“开始练习”。

### 12.3 后续实现要求

后续 iOS 页面精简方案应把 `IOS-ELEMENT-003` 拆成两个动作处理：

1. 保留并产品化 `照片写作`：文案可评估为 `照片写作`、`用照片开始`、`拍照写一句`，最终以中文自然度和 iOS 按钮宽度为准。
2. 移出记录 Hero 的 `听`：优先放入 `练习` Tab 的高频入口；如果在记录详情中保留，应绑定具体句子或具体目标语文本。

复查方法：

- 记录页首屏仍只有一个主 CTA。
- `照片写作` 是主 CTA 下的唯一或最强次级 CTA。
- `听` 不再与 `照片写作` 在记录 Hero 中同级出现。
- 未接入真实照片 / AI 时，点击 `照片写作` 的反馈必须诚实说明边界，不伪装成真实可用能力。

## 13. 未接入能力的真实级模拟展示原则

更新日期：2026-05-19
触发原因：用户明确要求：对于未真实接入的能力，需要先使用模拟数据，搭建真实级页面展示，用以确定 UI 设计。

### 13.1 原则

未接入能力不应只有两种状态：“直接隐藏”或“进入 unavailable”。在早期产品设计阶段，应按能力对核心体验的价值分层处理：

1. 核心 UX 路径：如果能力直接影响用户是否能理解产品价值，应提供真实级本地模拟展示。`照片写作` 属于这一层，因为它解决记录页“不知道写什么”的启动阻塞。
2. 练习域高频动作：如果能力属于学习材料生成后的消费行为，应放在对应域中以本地练习流承接。`听` 属于这一层，不应和记录起点并列在 Hero。
3. 基础设施或低频未来能力：如果能力主要是配置、同步、导出、Provider 或技术能力，应留在设置页、disabled preview 或 unavailable 兜底中，不进入主流程最高层级。

### 13.2 模拟展示边界

真实级模拟展示必须看起来像可评审的产品页面，但不能伪装成已接入真实能力：

- 可以展示：模拟照片缩略图、AI 话题建议、母语草稿、目标语示例、逐句练习、记忆条目和本地状态。
- 必须说明：这是本地预览或模拟材料，未访问照片、未请求系统权限、未调用 AI Provider、未发送网络请求。
- 不应展示：开发调试标记、Provider 请求预览常驻卡、权限流程假成功、真实外发日志或不存在的配置状态。
- 后续接入真实照片 / OCR / AI Provider 时，必须重新走权限与 AI 请求任务方案，并同步 `docs/spec/005-ai-provider-prompt-and-privacy.md` 与 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`。

### 13.3 本轮承接

本轮由 `docs/plans/done/2026-05-19-feature-ios-page-element-convergence-and-mock-photo-writing.md` 承接第一批 iPhone 修复：

- `照片写作` 从 unavailable 改为本地模拟预览 sheet。
- 模拟预览可生成一条 `photoWriting` 记录、mock rendering、practice items 和 memory item。
- `听` 从记录 Hero 移出，由练习页承接。
- 记录详情和练习会话默认流移除常驻请求预览。
