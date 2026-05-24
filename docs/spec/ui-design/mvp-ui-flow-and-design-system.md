# MVP 页面闭环与设计系统规格

状态：Draft

日期：2026-05-17

关联文档：

- `docs/plans/done/2026-05-17-feature-ui-completeness-and-design-system-review.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`

## 1. 目标

本规格用于把语迹当前 SwiftUI 体验骨架推进到可验证的 MVP 页面闭环，并把已有 UI 原则升级为可执行的设计系统。

目标结果：

- 用户可以从“今天记录一点生活”进入最小记录闭环。
- 页面结构能表达 `Entry -> Rendering -> Practice -> Memory` 的产品对象链路。
- iPhone 与 iPad 优先形成可用体验，macOS 保持基础工作台和未来高级能力边界。
- UI 设计系统从方向性规范升级为 tokens、组件、状态和页面模式。

## 2. 当前事实

当前已经具备：

- Welcome / Onboarding / Main 启动路由。
- 语言空间已通过 SQLite / GRDB repository 持久化，启动恢复、添加、切换、重命名和删除 fallback 已接入三端共享会话状态。
- iPhone `记录 / 练习 / 记忆` 三个主 Tab；设置通过 toolbar gear 或配置 route 稳定可达。
- 学习内容已通过 `LearningContentRepository` 和 `LearningContentStore` 暴露给 UI；App Shell 主路径使用 GRDB learning content repository，内存 repository 只作为测试替身和开发期 seed preview。
- Entry 保存只创建原始记录；真实学习材料必须由用户在详情页显式点击 `生成学习材料` 或 `重新生成` 触发，不再在 `createEntry` 后自动生成 Practice 和 Memory。
- iPhone 记录创建 sheet、Entry 保存后详情导航、三端共享 Entry detail、真实学习材料生成入口、mock practice session 和 Memory 三层摘要。
- iPad 三栏工作台、响应式宽度布局、时间线和学习面板收起/展开、Settings / Search / New Entry 稳定入口、基础 pointer / keyboard / context menu。
- macOS Sidebar / 主区 / Inspector 工作台骨架、Settings scene、菜单 commands 和关键快捷键。
- `LanguageSpaceFooter`、能力状态图标、面板切换按钮、状态矩阵和基础设计 token。

当前缺口：

- Entry、LearningMaterial、analysis、memory candidate、practice candidate 和 operation summary 已进入 GRDB 主路径；附件、FTS、导出、可恢复备份、同步和向量索引尚未实现。
- iPad / macOS 记录详情 action wiring 已接入真实生成路径，但仍需后续人工验收大屏布局、AI Provider 披露和创建入口保存失败恢复。
- 请求预览、请求日志、Prompt Preset 自定义执行和跨 Provider 请求体尚未完整接入；基础生成结果、失败分类、取消和重试入口已由 LearningMaterial generation state 承载。
- 没有真实 TTS、播放、跟读、听写、回译和练习结果。
- 没有 Memory 提取、收藏、复习队列和回到原始上下文。
- 附件存储、FTS、导出、可恢复备份、同步和向量索引尚未实现。
- 设计系统已有第一轮 token 和状态矩阵，但仍缺少完整深色模式、高对比、截图矩阵和真实错误 / 权限 / 同步流程样板。

## 3. 产品对象边界

后续页面围绕五个对象组织：

- `Space`：目标语言学习空间，提供当前母语、目标语言、等级、AI Provider 和同步上下文。
- `Entry`：用户原始生活记录，可以是文本、照片摘要、手写转写或目标语言自主写作。
- `Rendering`：AI 或 Mock Provider 基于 Entry 生成的目标语言学习材料。
- `Practice`：围绕 Rendering 的朗读、跟读、听写、回译和自测结果。
- `Memory`：从 Entry、Rendering、Practice 中沉淀出的词、短语、句子、错误模式和相似生活片段。

每个主数据对象必须归属于一个 `Space`。任何创建主数据的页面在缺少语言空间时不得写入。

当前真实主路径应使用 repository / store seam，不能把页面数据写死在 View 内。最低要求是：

- `Entry`、`Rendering`、`Practice`、`Memory` 有轻量模型或可测试的 preview model。
- Repository 至少支持当前语言空间内的列表、选择、创建、保存和真实 LearningMaterial 持久化。
- Mock Rendering / seed preview 必须明确标记为本地 mock，不触发网络请求，也不得替代真实用户路径。
- 用户新建 Entry 后不会自动创建 Rendering、Practice 或 Memory；学习材料生成是详情页中的显式动作。
- Request Preview 后续接入时必须清楚表达将发送和不会发送的内容；真实 Provider 未配置时不能暗示内容已经发送到外部服务。

## 4. MVP 页面地图

### 4.1 iPhone

iPhone 保持三个主 Tab：

- 记录：主入口，承载“记录一点生活”、最近记录、当前 Entry 状态、`生成学习材料` 入口和必要的隐私 / AI 边界轻提示。
- 练习：按当前语言空间聚合跟读、听写、回译和写作检查。
- 记忆：内容记忆、语言记忆、学习记忆三层摘要，后续扩展为词句、整句表达、错误模式、相似生活片段和复习入口。

设置不作为底部 Tab，与语言空间、AI Provider、同步、本地数据、隐私和导出相关的配置通过 toolbar gear、语言空间摘要或二级 route 进入。

必须补齐的子页面：

- `EntryEditorView`：创建或编辑生活记录。
- `EntryDetailView`：展示母语记录、目标语言 LearningMaterial / Rendering 状态、`生成学习材料` 入口、句子对照和练习入口；缺少 LearningMaterial 时必须显示明确状态和 AI Provider 边界披露。
- `RequestPreviewView`：展示即将发送与不会发送的内容；真实 Provider 未配置时只能执行 mock 生成或提示配置，不得暗示已经发送到外部服务。
- `PracticeSessionView`：承载跟读、听写或回译中的一种练习会话。
- `MemoryItemDetailView`：展示词句来源、例句、原始 Entry 和复习状态。
- `AIProviderSettingsView`：已进入本地配置保存阶段；非敏感 Provider / endpoint metadata 保存到 SQLite / GRDB，API Key 保存到 Keychain，并在用户再次打开配置页时通过服务边界回填到短生命周期 UI draft。

### 4.2 iPad

iPad 保持顶部工具条和三栏主体：

- 顶部工具条：左面板切换、搜索入口、右学习面板切换。
- 左栏：时间线、筛选、当前语言空间底部工具区。
- 中栏：Entry 详情、双语正文、编辑和练习主内容。
- 右栏：句子讲解、词句提取、请求预览、练习入口、相似生活片段。

必须补齐：

- 时间线项可选择，并更新中栏 Entry。
- 筛选项可切换，并有空状态。
- 中栏支持 Entry 编辑态和阅读态。
- 右栏根据当前 Entry / Rendering / Practice 状态切换内容。
- 左右面板收起后主内容保持合理行长，不留下空白占位。

### 4.3 macOS

macOS 第一阶段不追求完整深度工作台，但必须保持可信的基础结构：

- Sidebar：今日、记录库、词句记忆、设置或状态入口。
- Toolbar 或主区顶部：Sidebar 切换、Inspector 切换、新建记录、搜索入口。
- 主区：Entry 详情、搜索结果或记录库。
- Inspector：请求预览、词句提取、元数据、练习状态。
- Settings scene：承载通用设置和能力边界说明，通过菜单或 `Cmd+,` 打开。
- Commands：New Entry、Search、Toggle Sidebar、Toggle Inspector、Settings 等基础桌面命令；未接入真实搜索时必须打开 unavailable / local mock 说明。

第一阶段不实现：

- 多窗口文档系统。
- Command Palette。
- 批量导入导出。
- 完整菜单栏命令体系和批量资料库管理。
- 大规模资料库管理。

这些能力保留在 macOS 后续工作台规格中。

## 5. 设计系统规格

### 5.1 视觉方向

语迹 UI 应保持：

- 安静。
- 清晰。
- 温和。
- 现代。
- 长期可读。
- 学习工具感。
- 个人资料库感。

禁止把页面做成：

- 营销首页。
- 游戏化闯关。
- 社区 feed。
- AI 聊天室。
- 后台管理系统。

### 5.2 Design Token 分层

后续 `LangoTraceDesign` 应至少分为以下 token：

- `ColorToken`：`surfaceBase`、`surfaceRaised`、`surfaceMuted`、`textPrimary`、`textSecondary`、`borderSubtle`、`accent`、`accentStrong`、`warning`、`danger`、`privacyLocal`、`privacyExternal`。
- `TypographyToken`：`screenTitle`、`sectionTitle`、`body`、`bodyEmphasis`、`caption`、`controlLabel`、`dataLabel`。
- `SpacingToken`：`pageMargin`、`sectionGap`、`cardPadding`、`controlGap`、`inlineGap`。
- `RadiusToken`：`panel`、`control`、`badge`、`sheet`。
- `ShadowToken`：`panelSoft`、`floatingPopover`。
- `MotionToken`：`panelToggle`、`contentReplace`、`pressFeedback`，并统一尊重 Reduce Motion。

第一版 token 只服务 MVP 页面和核心组件，不做完整品牌手册。

Token 落地顺序：

1. 先替换页面中会反复出现的颜色、圆角、面板、按钮、badge 和状态样式。
2. 再补字体层级和状态色，确保 empty / unavailable / request preview / error 有稳定表达。
3. 最后补深色模式映射和动效 token；在没有暗色适配前，文档和 UI 不得宣称已支持完整深色模式。

### 5.3 核心组件

需要稳定沉淀的组件：

- `LanguageSpaceSwitcher`：切换或展示当前语言空间；Mock 阶段可只展示，不写入数据。
- `EntryTimelineRow`：展示 Entry 标题、类型、时间、练习状态和选中状态。
- `SentencePairView`：展示母语句子、目标语言句子、播放、练习、收藏状态；逐句播放按钮必须使用原位反馈，不打开解释型 sheet。
- `PracticeControlBar`：播放、暂停、速度、跟读、听写、回译入口。
- `RequestPreviewCard`：展示将发送内容、不会发送内容、Provider 状态和确认动作。
- `PromptPresetPicker`：选择生成目标语言、自然表达、逐句解释、写作检查等模式。
- `MemoryItemRow`：展示词、短语、整句、来源 Entry 和复习状态。
- `PrivacyStatusPopover`：解释 AI Provider、同步和本地优先状态。
- `AttachmentPreview`：展示图片、音频或手写录入附件。

组件要求：

- 使用产品对象命名，不只用抽象样式命名。
- 图标按钮必须有 accessibility label、value 或 hint。
- 触控设备交互目标不小于 44pt。
- 不用颜色作为唯一状态表达。
- 支持浅色和深色设计预留。
- 高频学习操作应避免弹出说明型 sheet。逐句“听”在真实 TTS 接入前只表达本地播放 / 暂停视觉状态；真实生成、播放、失败和未配置提示需要等待 TTS Provider 配置测试与 Speech 服务边界完成后再接入。

### 5.4 状态矩阵和 action hierarchy

第一轮实现后的状态 kind 包括 `ready`、`localPreview`、`unavailable`、`warning`、`error`、`permissionDenied`、`syncConflict` 和 `loading`。状态组件必须同时使用标题、说明、图标、tone 和可访问信息表达，不把颜色作为唯一状态。

Action hierarchy：

- Primary：创建 Entry、生成学习材料、继续练习。
- Secondary：筛选、查看设置详情、切换面板、查看不可用说明。
- Tertiary：播放、收藏、更多、AI / Sync / gear 状态图标。
- Destructive：删除语言空间、删除 Entry、清空数据；必须有确认、导出或可恢复方案，本规格当前不实现真实语言空间删除。

## 6. 状态设计

必须设计并实现的状态：

- 没有语言空间：进入 onboarding 或语言空间选择，不显示空主页面。
- 没有记录：展示创建第一条生活记录的行动入口。
- 未配置 AI Provider：功能可见但需要说明不会发送任何内容。
- 请求预览：明确“将发送”和“不会发送”。
- 请求失败：展示错误原因、可重试动作和不会丢失本地记录的说明。
- 权限被拒绝：解释相机、照片、麦克风或语音权限用途，并提供设置入口。
- 本地保存完成：轻量反馈，不打断记录流程。
- 同步未启用：表达为正常状态，不使用错误视觉。
- 同步冲突：必须进入用户确认或可恢复路径。
- 向量索引未建立：表达为可重建派生数据，不影响原始记录。
- 本地预览：只作为 seed preview 或测试替身表达为可替换的本地示例，不触发真实 AI、TTS、同步或外部请求，不作为真实记录详情主路径。

Memory 页面第一轮至少表达三层：

- 内容记忆：从生活记录回到原始上下文。
- 语言记忆：沉淀词、短语、句子和自然表达。
- 学习记忆：记录练习进度、错误模式和后续复习线索。

## 7. 首批实施建议

第一批实现应保持小范围：

1. 设计系统基础升级：
   - 扩展 `LangoTraceDesign` token。
   - 抽取 `EntryTimelineRow`、`SentencePairView`、`RequestPreviewCard`。
   - 为组件补 SwiftUI preview 和轻量测试可验证的模型状态。

2. 学习内容 repository：
   - 保留 `Entry`、`Rendering`、`Practice`、`Memory` 的 preview / 测试模型。
   - App Shell 主路径使用 GRDB learning content repository，支持 Entry 创建、更新、LearningMaterial 保存、analysis 替换、候选项和 operation 摘要。
   - in-memory repository 只作为测试替身和开发期 seed preview，不承载真实用户学习闭环。

3. iPhone 记录闭环：
   - 让“写一句”进入 `EntryEditorView`。
   - 保存到 GRDB learning content repository。
   - 进入 `EntryDetailView`。
   - 保存后先进入原始 Entry 详情，再由用户显式点击 `生成学习材料`，展示双语对照和句子练习入口。

4. iPad 详情工作台：
   - 时间线选择驱动中栏 Entry。
   - 右栏根据 Entry 状态展示请求预览、句子讲解和记忆提取。
   - 面板收起时保持主内容行长和焦点。

5. 设置闭环：
   - AI Provider 已支持本地配置保存、Keychain secret、已保存凭证读取，以及配置合成测试。
   - 同步和本地数据设置仍保持只读说明或 Mock 配置页。
   - AI Provider 测试请求当前会触发固定低敏合成请求，覆盖文本回复、JSON 输出，以及用户显式启用后的内置图片理解 probe；它不发送生活记录、用户照片、音频、历史记忆或 Prompt Preset 内容。
   - AI Provider 测试结果 sheet 必须采用 Apple 风格的状态面板：紧凑宽度下隐藏系统 drag indicator，顶部使用克制 handle、测试中居中状态标题、完成后中性面板标题和右上关闭按钮；测试中用小号 `ProgressView` 表达进度，不显示禁用的大号重试按钮；成功态不显示底部 prominent `重新测试` 按钮，失败、部分可用、取消或不支持状态才保留重试恢复操作；能力结果使用 grouped card 和细分隔，不使用整行高亮来表达状态。

## 8. 测试与验证要求

文档阶段：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

实现阶段：

```bash
scripts/verify.sh
```

如果某次实现只修改一个 package，可先运行对应 package 测试，再在收尾阶段运行统一验证。

手动验证至少覆盖：

- iPhone：onboarding、三个 Tab、记录创建、记录详情、生成学习材料、练习入口、设置入口。
- iPad：面板展开/收起、时间线选择、Entry 详情、生成学习材料、学习面板、请求预览。
- macOS：窗口最小尺寸、Sidebar/Inspector 切换、新建记录入口、Entry Detail 生成学习材料不会造成假写入或假生成。
- Accessibility：主要图标按钮有可读 label，面板状态有 value，Reduce Motion 生效。

视觉截图验证至少覆盖：

- iPhone welcome、onboarding、main 今日页和一个二级页面。
- iPad main 三栏、左栏收起、右栏收起。
- 截图需要和代码审查一起判断：是否有文字溢出、主操作不可见、控件过小、空白占位、颜色对比不足或静态 mock 被误读成真实能力。

## 9. 文档落点

后续实现如果产生新结论，按以下方式写回：

- 页面地图或产品闭环变化：更新 `docs/product-main-reference.md`。
- 路由、Sheet、Modal、Inspector 边界变化：更新 `docs/spec/002-navigation-and-routing.md`。
- Token、组件、状态或视觉风格变化：更新 `docs/spec/003-ui-design-system.md`。
- 模拟器截图或手动 UI 验证方式变化：更新 `docs/testing/README.md` 或新增 `docs/testing/` 下的专项清单。
- SwiftUI 状态、Repository、Provider 或模块边界变化：更新 `docs/spec/004-swiftui-architecture.md` 或 `docs/architecture/`。
- AI 请求、Prompt、隐私或 Provider 边界变化：更新 `docs/spec/005-ai-provider-prompt-and-privacy.md`。
- 具体实施任务：创建 `docs/plans/active/YYYY-MM-DD-<type>-<topic>.md`。

## 10. 通过标准

本规格对应的 MVP UI 通过标准：

- 用户能在 iPhone 完成从创建 Entry 到显式生成真实 LearningMaterial 并进入练习入口的闭环。
- iPad 能用时间线选择 Entry，并在中栏与右栏展示不同学习上下文；记录详情应复用真实生成 action seam，而不是退回本地预览主按钮。
- 所有主页面都有明确 empty / unavailable / request preview 状态。
- AI Provider 未配置时，页面不会暗示已经能自动生成内容或自动发送数据。
- 新组件使用稳定 token，不在页面中继续扩散临时颜色、圆角和状态样式。
- 文档、代码和测试对当前实现阶段的表述一致。

## 11. 变更记录

- 2026-05-18：同步第一轮 UI 收敛后的页面地图和状态边界。原因：iPhone 已收敛为记录、练习、记忆三主 Tab；Entry 保存与 local preview 生成已分离；iPad / macOS 已补基础响应式和命令入口；Memory 已出现内容、语言、学习三层表达。影响范围：MVP 页面地图、状态矩阵、设计系统后续实施顺序和手动验证清单。
- 2026-05-20：同步 AI Provider 设置页从占位 / mock 进入本地配置保存阶段的事实。原因：AI Provider 已落地 SQLite / GRDB metadata、Keychain secret、本地凭证验证和已保存 API Key 短生命周期回显；同步和本地数据设置仍未进入真实写入阶段。影响范围：设置闭环、AI Provider 设置 UI、文档一致性。是否需要 ADR：否，沿用 ADR-005。
- 2026-05-21：同步 AI Provider 设置页从本地凭证验证推进到配置合成测试的事实。原因：测试请求已可对文本回复、JSON 输出和用户显式启用后的内置图片理解 probe 发起固定低敏 Provider 请求。影响范围：设置闭环、AI Provider 设置 UI、图片输入边界和文档一致性。是否需要 ADR：否，沿用 ADR-005；真实学习内容请求和用户照片请求仍需单独方案。
- 2026-05-23：同步学习内容主路径和三端记录详情事实。原因：Entry / LearningMaterial 已进入 GRDB 主路径，一键学习材料生成已通过共享 `EntryDetailView` 接入 iPhone / iPad / macOS，规范不应继续以 in-memory repository 或 local preview 作为真实学习闭环口径。影响范围：MVP 页面地图、手动验证清单、通过标准和后续 UI 任务入口。是否需要 ADR：否，沿用 SQLite / GRDB 主存储和三端共享业务逻辑决策。
- 2026-05-23：同步 AI Provider 设置页 TTS 配置测试事实。原因：语音生成模型分组已从占位推进到 voice / format / speed / instructions 配置、单一测试入口中的 TTS capability row、OpenAI / OpenRouter 固定低敏 probe 和 Speech preview playback seam；UI 仍必须保持单一主测试入口，试听按钮只能通过 Speech seam 播放短生命周期 preview audio。影响范围：设置闭环、AI Provider 设置 UI、TTS 结果面板、三端设置详情和后续逐句播放前置。是否需要 ADR：否，沿用 ADR-005 和 011 规范。
- 2026-05-23：补充 TTS 参数设置区表达规则。原因：语音生成模型中的音色、格式、语速和朗读风格属于可见配置项，不能只显示裸菜单值或系统 stepper；应以带标题、简短说明、统一背景和 44pt 触控目标的设置行呈现。“朗读风格”用于面向用户解释可选的语气、节奏和朗读方式，不再使用含义较工程化的“朗读指令”。影响范围：AI Provider 设置页、String Catalog、TTS voice profile UI 和后续 Provider-specific 参数行。是否需要 ADR：否。
- 2026-05-23：补充 AI Provider 测试结果面板 Apple 风格设计规则。原因：半高 sheet 中左侧大图标标题、表格式能力列表和测试中禁用大按钮会形成调试工具感；结果面板应使用居中状态 chrome、grouped capability card、细分隔和完成后才出现的底部操作。影响范围：AI Provider 设置页测试结果 sheet、source-boundary UI 测试和后续能力结果面板。是否需要 ADR：否。
- 2026-05-23：将 AI Provider 测试结果面板归入状态反馈 sheet 规范。原因：不是所有 sheet 都需要页面式标题；任务型 sheet 需要对象 / 流程标题，反馈型 sheet 需要状态 chrome。影响范围：AI Provider 测试结果、保存 / 导出 / 同步反馈和后续 sheet 设计判断。是否需要 ADR：否。
- 2026-05-24：补充 AI Provider 测试结果完成态标题规则。原因：完成后顶部直接显示 `测试成功` 会显得局促且像临时提示；完成态顶部改为中性面板标题，分能力 grouped card 继续表达可用性。影响范围：AI Provider 测试结果 sheet、source-boundary UI 测试和后续状态反馈面板。是否需要 ADR：否。
- 2026-05-24：补充 AI Provider 测试成功态重试按钮层级规则。原因：成功后底部 prominent `重新测试` 不是主路径，会增加 sheet 高度并挤压标题区域；成功态隐藏该按钮，非成功态保留重试恢复操作。影响范围：AI Provider 测试结果 sheet、source-boundary UI 测试和后续状态反馈面板。是否需要 ADR：否。
