# MVP 开发路线规划

状态：Draft
创建日期：2026-05-18
最后更新日期：2026-05-18

关联文档：

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/spec/ui-design/mvp-ui-flow-and-design-system.md`
- `docs/spec/ui-design/2026-05-18-premium-ui-principles-and-review-plan.md`

## 1. 目的

本文档沉淀 LangoTrace 从当前 SwiftUI 页面骨架阶段推进到 MVP 可用闭环的整体开发规划。

它回答三个问题：

- 当前已有大量 Mock 页面后，下一步应该继续铺页面、转入真实功能，还是先做全面审核。
- 页面、领域模型、数据库、AI Provider、TTS、同步和 StoreKit 应按什么顺序推进。
- 每个阶段完成到什么程度，才可以进入下一阶段。

本文档是跨任务开发路线，放在 `docs/development/`。单个功能、bug、重构或文档治理仍必须写入 `docs/plans/active/`，验证完成后移入 `docs/plans/done/`。

## 2. 当前阶段判断

当前项目已经从纯 App Shell 进入产品体验骨架阶段，并且已经完成多轮页面闭合和 UI 质量提升。现有页面可以表达：

- Welcome / Onboarding / Main 启动路由。
- 真实语言空间 SQLite / GRDB 持久化、启动恢复和 iPhone 管理页。
- iPhone `记录 / 练习 / 记忆` 三个 Tab。
- iPad 三栏学习工作台。
- macOS Sidebar / 主区 / Inspector 工作台骨架。
- Mock Entry 创建、详情、练习、记忆和设置能力说明。
- Local Mock、未配置、不可用和隐私状态的初步表达。

当前最主要风险已经不是页面数量不足，而是：

- 页面结构是否真正服务 `Space -> Entry -> Rendering -> Practice -> Memory` 学习闭环。
- 三端是否有清晰的平台分工，而不是同一套信息架构的放大和缩小。
- Mock、未配置、不可用、本地优先和外部请求边界是否表达准确。
- 页面中的临时状态、内存 repository 和 preview model 是否会阻碍后续真实数据层接入。
- 设计系统是否已经从视觉关键词沉淀为稳定 token、组件和状态规则。

因此，当前阶段应从“继续搭建更多页面”转入“全面审核、设计收敛和领域边界校准”。

## 3. 总体路线结论

推荐路线：

```text
当前状态盘点
-> 全面页面审核与设计提升
-> 领域模型和接口边界校准
-> 最小真实持久化闭环
-> 最小真实 AI / TTS 能力
-> 本地记录、练习和记忆闭环扩展
-> 同步、StoreKit、发布与长期维护能力
```

核心原则：

- 可以页面先行，但不能所有页面无限制先行。
- 可以使用 Mock 数据验证交互，但 Mock 数据形状必须靠近未来领域模型。
- 可以延后 SQLite / GRDB、真实 AI、TTS、同步和 StoreKit，但它们的接口边界、隐私边界和状态表达不能延后到最后。
- 每个阶段都应产出可运行、可验证、可回退的纵向闭环，而不是一次性横向铺满所有能力。

阶段门禁：

- 没有完成全面页面审核前，不继续横向扩展大量新页面。
- 没有稳定领域模型和 repository / provider 边界前，不把真实数据库或真实 AI 请求直接接入 View。
- 没有请求预览、隐私说明、失败状态和用户触发边界前，不接入会外发生活记录、照片或音频的真实能力。
- 没有本地记录和导出 / 恢复边界前，不进入复杂同步和 StoreKit 发布阶段。
- 每个阶段如果发现需要改变核心产品、隐私、同步、付费或平台路线，必须先更新 ADR 或相关 spec，再继续实现。

## 4. 不推荐路线

### 4.1 先完成所有页面，再设计数据库

这个路线短期能快速看到完整界面，但风险较高：

- 页面可能围绕临时 Mock 形状生长，后续数据库和 repository 被迫迁就 UI。
- 真实请求预览、权限、同步、错误和保存失败状态会被当成后补细节。
- 页面数量越多，后续统一设计系统和领域模型的成本越高。

### 4.2 立刻转入完整数据库和基础设施

这个路线会让功能更早真实可用，但也有明显风险：

- 当前页面和产品对象关系仍需要全面复查。
- SQLite / GRDB、附件、AI Provider、TTS、同步和 StoreKit 同时展开会超过 MVP 早期控制面。
- 如果 UI 审核后发生结构调整，真实数据层可能需要返工。

### 4.3 三端同时做完整功能

这个路线不符合当前产品优先级：

- iPhone 是高频记录入口。
- iPad 是沉浸学习工作台。
- macOS 是资料库和生产力工作台，但第一阶段不需要完整深度能力。

MVP 应优先保证 iPhone + iPad 核心学习闭环成立，macOS 保持可信骨架和后续扩展边界。

## 5. 阶段规划

### 阶段 0：当前状态盘点

目标：

- 盘点现有页面、路由、Mock 数据、done plan、active plan、实现地图和已知偏差。
- 明确哪些能力已经真实实现，哪些只是 Local Mock、unavailable 或只读说明。

主要产物：

- 页面地图。
- 现有实现证据清单。
- Mock / 真实能力边界清单。

完成标准：

- 能按 iPhone、iPad、macOS 列出所有主页面和关键二级页。
- 能按 `Space / Entry / Rendering / Practice / Memory` 列出已有 UI 支撑和缺口。
- 能指出现有 active plan 与下一轮工作的关系。

文档落点：

- 当前状态盘点若只是服务本轮 UI 审核，写入 `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`。
- 如果盘点发现长期实现地图过期，同步更新 `docs/spec/navigation/impl.md`、`docs/spec/learning-content/impl.md` 或相关 spec。

### 阶段 1：全面页面审核与设计提升

目标：

- 对现有页面做一轮系统审查，而不是继续扩展页面数量。
- 将“页面更高级、更适合付费 App”转化为可执行问题清单和优化顺序。

审核维度：

- 产品闭环：是否服务“用生活记录学习语言”。
- 三端平台：iPhone、iPad、macOS 是否各自原生。
- 状态真实性：Mock、未配置、不可用和外部请求边界是否准确。
- 设计系统：token、组件、状态、无障碍和本地化是否可维护。
- 工程边界：View 是否仍依赖可替换的 mock / repository 边界。

主要产物：

- `docs/plans/active/2026-05-18-feature-comprehensive-ui-review-and-design-uplift.md`
- 页面级问题清单。
- 组件级问题清单。
- 第一轮 UI 收敛实施顺序。

完成标准：

- 明确哪些页面保留、哪些重构、哪些降级为占位、哪些需要补状态。
- 明确第一轮只做设计收敛，不引入真实数据库、真实 AI、TTS、同步或 StoreKit。
- 完成后可以进入页面优化实施计划。

文档落点：

- 审核发现和优化顺序写入本轮 active plan。
- 若形成新的长期 UI 规则，更新 `docs/spec/003-ui-design-system.md` 或 `docs/spec/ui-design/`。
- 若只是一轮页面实现问题，不新增长期规则，保留在 active plan 实施记录中。

### 阶段 2：领域模型和接口边界校准

目标：

- 在不急于引入完整 SQLite / GRDB 的前提下，稳定核心领域对象和 repository / provider 接口边界。
- 避免 UI 继续直接围绕临时 Mock 结构生长。

核心对象：

- `LanguageSpace`
- `Entry`
- `Rendering`
- `SentencePair`
- `PracticeSession`
- `MemoryItem`
- `PromptPreset`
- `ProviderConfig`
- `Attachment`
- `RequestPreview`

边界要求：

- View 不直接访问 SQLite、Keychain、网络、对象存储或具体 Provider。
- Mock repository 可以继续存在，但接口应接近真实实现。
- Local Mock 生成必须明确不会发送外部请求。
- Request Preview 可以先只展示 mock 请求结构，但 UI 必须表达真实 Provider 未配置时不会外发内容。

完成标准：

- UI 使用的核心模型和未来真实模型之间有清晰映射。
- Repository / Provider / Permission / Sync 状态不再散落在页面内部。
- 后续真实持久化可以替换 mock repository，而不是重写全部 UI。

文档落点：

- 长期对象边界进入 `docs/spec/learning-content/impl.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md` 或新的 architecture 文档。
- 如果改变 `LanguageSpace`、本地优先或 Provider 取舍，必须新增或更新 ADR。

### 阶段 3：最小真实持久化闭环

目标：

- 先完成最小真实本地状态，再进入完整数据库。
- 让首次启动、语言空间和本地记录具备基本可恢复能力。

优先顺序：

1. 语言空间持久化与启动恢复已先行落地，仍需 iPhone 人工验收后收口。
2. Entry 本地保存和启动后恢复。
3. Rendering / Practice / Memory 的本地 mock 结果保存边界。
4. Entry / 附件 / 导出相关 SQLite / GRDB schema、迁移和 repository。
5. 附件存储、导出和搜索。

边界：

- 语言空间启动恢复必须按真实数据基础设施建设，直接使用 SQLite / GRDB 和多语言空间模型；不得再以单空间 UserDefaults 或轻量 repository 作为可交付方案。
- Entry 一旦进入真实持久化，必须开始考虑迁移、导出、错误和数据损坏处理。
- SQLite / GRDB 仍是长期主存储候选，SwiftData 只能作为局部原型备选。

完成标准：

- 用户完成 onboarding 后，重启仍能恢复第一个语言空间；语言空间已由 `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md` 落地并完成人工验收。
- 用户创建的文本 Entry 可以本地保存并恢复。
- 保存失败、数据损坏和缺少语言空间时有明确 UI 和测试覆盖。

文档落点：

- 语言空间数据基础设施、启动恢复和 iOS 语言空间管理页已由 `docs/plans/done/2026-05-20-feature-language-space-data-infrastructure.md` 收口。
- Entry 本地保存需要单独创建 active plan。
- 数据 schema、迁移、导出和附件规则进入 `docs/spec/007-data-storage-migration-export-and-attachments.md` 或 architecture 文档。

### 阶段 4：最小真实 AI / TTS 能力

目标：

- 在本地记录闭环成立后，接入最小真实外部能力。
- 先保证隐私、请求预览、错误处理和日志边界，再扩展模型能力。

优先顺序：

1. AI Provider 配置边界和 Keychain API Key 存储。
2. Request Preview，明确将发送和不会发送的内容。
3. 最小文本转换：Entry 到目标语言 Rendering。
4. 请求失败、取消、重试和本地记录不丢失。
5. AVSpeechSynthesizer 或 Provider TTS 的最小播放。
6. 跟读、听写、回译和写作检查的真实流程。

边界：

- 默认不自动发送生活记录、照片或音频。
- 用户明确触发并确认外部请求后，才允许发送对应内容。
- Prompt Preset 必须独立于具体 Provider。

完成标准：

- 用户可以从一条本地 Entry 触发一次可预览、可确认、可失败恢复的目标语言生成。
- 生成结果可以回到 Entry 详情和练习入口。
- 未配置 Provider、请求失败和取消时，数据不丢失，状态表达可信。

文档落点：

- Provider、Prompt、请求预览和隐私边界进入 `docs/spec/005-ai-provider-prompt-and-privacy.md`。
- 权限、诊断日志和外发边界进入 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`。
- 真实 Prompt 出现后必须进入 `docs/prompts/`，保留中英文版本、输入变量、输出契约和隐私边界。

### 阶段 5：本地练习、记忆和学习闭环扩展

目标：

- 将产品从记录和转换推进到真实学习工具。
- 让 Practice 和 Memory 不只是页面占位，而是可积累、可回溯、可复习的学习资产。

优先顺序：

1. Sentence Pair 的播放、收藏和练习入口。
2. 跟读、听写、回译中的一个真实练习闭环。
3. PracticeSession 的本地结果保存。
4. MemoryItem 的提取、收藏和回到原始 Entry。
5. 复习队列和轻量成长反馈。

完成标准：

- 用户能从自己的生活记录进入一次真实练习。
- 练习结果和词句记忆能回到原始上下文。
- 复习入口服务个人语言资料库，而不是外部课程或游戏化关卡。

文档落点：

- 练习、记忆和复习队列的长期对象边界进入 `docs/spec/learning-content/impl.md`。
- 手动测试流程进入 `docs/testing/README.md` 或新增测试清单。

### 阶段 6：同步、StoreKit、发布与长期维护

目标：

- 在本地核心闭环稳定后，再接入高风险长期能力。

优先顺序：

1. 数据导出和备份。
2. Sync Engine 主数据 / 派生数据边界。
3. iCloud / WebDAV / S3 / R2 Adapter。
4. StoreKit 买断制、恢复购买和离线可用边界。
5. TestFlight、App Store 隐私标签、权限说明和发布检查清单。

边界：

- 同步不绑定 CloudKit-only。
- 向量索引默认是本地可重建派生数据。
- API Key 默认进入 Keychain，默认不同步。
- StoreKit 接入前，不在 UI 中暗示已支持购买、恢复购买或 Pro 授权。

完成标准：

- 本地数据可导出，可解释，可恢复。
- 同步冲突有用户可理解的处理路径。
- 发布材料、隐私标签和权限说明与真实功能一致。

文档落点：

- 同步架构进入 `docs/architecture/` 或相关 spec。
- StoreKit、TestFlight、App Store 和隐私标签进入 `docs/release/`。
- 发布前回归和手动验证进入 `docs/testing/`。

## 6. 当前最近任务顺序

当前推荐的最近执行顺序：

1. 创建并确认全面 UI 审核与设计提升任务方案。
2. 执行页面审核，沉淀页面级和组件级问题清单。
3. 按审核结果做第一轮 UI 收敛，不扩展真实功能。
4. 语言空间 SQLite / GRDB 数据基础设施已完成；下一步进入 Entry 本地保存最小闭环。
5. 设计并实现 Entry 本地保存最小闭环。
6. 进入 Request Preview 和最小 AI 文本转换。

## 7. 验证策略

文档规划和 UI 审核阶段：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

SwiftUI 和功能实现阶段：

```bash
scripts/verify.sh
```

如果只修改单个 Swift Package，可先运行对应 package 测试；收口阶段仍应运行统一验证脚本，除非当前环境缺少明确工具，并在任务方案中记录原因和剩余风险。

## 8. 复审条件

出现以下情况时，应复审本文档：

- 产品优先级从 iPhone + iPad MVP 改为 macOS-first。
- 首发范围扩展到 Android、Windows 或 Web。
- UI 全面审核发现当前页面结构与核心学习闭环冲突。
- SQLite / GRDB 接入成本明显超过预期。
- AI Provider、TTS、OCR、Speech 或同步能力的真实接入改变隐私边界。
- StoreKit 或发布策略改变买断制、单人使用或本地优先前提。

## 9. 变更记录

- 2026-05-18：创建第一版 MVP 开发路线规划。原因：当前页面已基本搭建，后续需要先做全面审核和设计提升，再进入领域模型、持久化和真实能力接入。
