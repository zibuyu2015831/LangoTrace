# MVP 页面闭环与设计系统规格

状态：Draft

日期：2026-05-17

关联文档：

- `docs/worklogs/2026-05-17-feature-ui-completeness-and-design-system-review.md`
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
- 内存语言空间 preview；当前还不是可持久化 Space。
- iPhone `今日 / 记录 / 练习 / 记忆 / 设置` 五个 Tab。
- iPad 三栏工作台、时间线和学习面板收起/展开。
- macOS Sidebar / 主区 / Inspector 工作台骨架。
- `LanguageSpaceFooter`、隐私状态图标、面板切换按钮和基础设计 token。

当前缺口：

- `LangoTraceData` 的 `LanguageSpaceRepository` 仍是空协议，没有 Entry / Rendering / Practice / Memory repository。
- 没有真实 Entry 创建、编辑、保存和详情路由。
- 没有 Rendering 请求预览、生成结果、失败状态和重试路径。
- 没有真实 TTS、播放、跟读、听写、回译和练习结果。
- 没有 Memory 提取、收藏、复习队列和回到原始上下文。
- 没有 SQLite / GRDB Repository、附件存储和启动恢复。
- 设计系统缺少完整 token、组件状态、页面模式、空/错/加载状态和深色模式映射；当前 `LangoTraceDesign.ColorToken` 是固定浅色 token。

## 3. 产品对象边界

后续页面围绕五个对象组织：

- `Space`：目标语言学习空间，提供当前母语、目标语言、等级、AI Provider 和同步上下文。
- `Entry`：用户原始生活记录，可以是文本、照片摘要、手写转写或目标语言自主写作。
- `Rendering`：AI 或 Mock Provider 基于 Entry 生成的目标语言学习材料。
- `Practice`：围绕 Rendering 的朗读、跟读、听写、回译和自测结果。
- `Memory`：从 Entry、Rendering、Practice 中沉淀出的词、短语、句子、错误模式和相似生活片段。

每个主数据对象必须归属于一个 `Space`。任何创建主数据的页面在缺少语言空间时不得写入。

第一阶段可以用内存实现，但不能继续把页面数据写死在 View 内。最低要求是：

- `Entry`、`Rendering`、`Practice`、`Memory` 有轻量模型或可测试的 preview model。
- Repository 至少支持当前语言空间内的列表、选择、创建和保存。
- Mock Rendering 明确标记为本地 mock，不触发网络请求。
- Request Preview 可以先确认 mock 请求，但 UI 必须清楚表达真实 Provider 未配置时不会发送内容。

## 4. MVP 页面地图

### 4.1 iPhone

iPhone 保持五个一级 Tab：

- 今日：主入口，承载“今天记录一点生活”、最近记录、今日练习和隐私/AI 状态轻提示。
- 记录：Entry 列表、创建入口、照片写作入口、目标语言写作入口。
- 练习：按当前语言空间聚合跟读、听写、回译和写作检查。
- 记忆：词句、整句表达、错误模式、相似生活片段和复习入口。
- 设置：语言空间、AI Provider、同步、本地数据、隐私和导出入口。

必须补齐的子页面：

- `EntryEditorView`：创建或编辑生活记录。
- `EntryDetailView`：展示母语记录、目标语言 Rendering、句子对照和练习入口。
- `RequestPreviewView`：展示即将发送与不会发送的内容；真实 Provider 未配置时只能执行 mock 生成或提示配置，不得暗示已经发送到外部服务。
- `PracticeSessionView`：承载跟读、听写或回译中的一种练习会话。
- `MemoryItemDetailView`：展示词句来源、例句、原始 Entry 和复习状态。
- `AIProviderSettingsView`：第一版可先做配置占位和隐私说明，不保存真实密钥。

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

第一阶段不实现：

- 多窗口文档系统。
- Command Palette。
- 批量导入导出。
- 完整菜单栏命令体系。
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
- `SentencePairView`：展示母语句子、目标语言句子、播放、练习、收藏状态。
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

## 7. 首批实施建议

第一批实现应保持小范围：

1. 设计系统基础升级：
   - 扩展 `LangoTraceDesign` token。
   - 抽取 `EntryTimelineRow`、`SentencePairView`、`RequestPreviewCard`。
   - 为组件补 SwiftUI preview 和轻量测试可验证的模型状态。

2. 最小模型和内存 repository：
   - 为 `Entry`、`Rendering`、`Practice`、`Memory` 增加第一版 preview model 或测试模型。
   - 增加当前语言空间内的 in-memory repository，支持列表、选择、创建、保存和 mock rendering。
   - 继续保持 SQLite / GRDB 为后续阶段，不在本批次引入真实数据库迁移。

3. iPhone 记录闭环：
   - 让“写一句”进入 `EntryEditorView`。
   - 保存到内存 repository。
   - 进入 `EntryDetailView`。
   - 用 Mock Rendering 展示双语对照和句子练习入口。

4. iPad 详情工作台：
   - 时间线选择驱动中栏 Entry。
   - 右栏根据 Entry 状态展示请求预览、句子讲解和记忆提取。
   - 面板收起时保持主内容行长和焦点。

5. 设置占位闭环：
   - AI Provider、同步和本地数据设置先做只读说明或 Mock 配置页。
   - 不保存真实 API Key。
   - 不触发网络请求。

## 8. 测试与验证要求

文档阶段：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!worklogs/TEMPLATE.md'
git diff --check
git status --short
```

实现阶段：

```bash
scripts/verify.sh
```

如果某次实现只修改一个 package，可先运行对应 package 测试，再在收尾阶段运行统一验证。

手动验证至少覆盖：

- iPhone：onboarding、五个 Tab、记录创建、记录详情、请求预览、练习入口、设置入口。
- iPad：面板展开/收起、时间线选择、Entry 详情、学习面板、请求预览。
- macOS：窗口最小尺寸、Sidebar/Inspector 切换、新建记录入口不会造成假写入。
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
- 具体实施任务：创建 `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`。

## 10. 通过标准

本规格对应的 MVP UI 通过标准：

- 用户能在 iPhone 完成从创建 Entry 到看到 Mock Rendering 和进入练习入口的闭环。
- iPad 能用时间线选择 Entry，并在中栏与右栏展示不同学习上下文。
- 所有主页面都有明确 empty / unavailable / request preview 状态。
- AI Provider 未配置时，页面不会暗示已经能自动生成内容或自动发送数据。
- 新组件使用稳定 token，不在页面中继续扩散临时颜色、圆角和状态样式。
- 文档、代码和测试对当前实现阶段的表述一致。
