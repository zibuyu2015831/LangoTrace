# iOS 页面元素收敛与照片写作模拟展示任务方案

状态：Verified
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

- 2026-05-19：用户要求重新阅读 `docs/review/rounds/2026-05-19-ios-page-element-design-audit/README.md`，并进行修复、完整工作。
- 2026-05-19：用户确认未真实接入的能力应先使用模拟数据，搭建真实级页面展示，用以确定 UI 设计。

## 需求描述

基于 iOS 页面元素级设计审查，先修复 iPhone 端最影响真实级展示的问题：

1. 记录页 Hero 保留 `照片写作` 作为高频入口，移出同级 `听`。
2. `照片写作` 不再进入普通 unavailable sheet，而是进入本地模拟的真实级预览流。
3. 记录详情和练习会话不再常驻显示请求预览卡。
4. 练习页从能力状态清单改为更像“今天练什么”的任务入口，并承接听/跟读入口。
5. 记忆页不再在 iPhone 主页面展示向量索引和三层技术摘要。
6. 对应审查文档写回“未接入能力真实级模拟展示原则”。

## 现状描述

- `HeroActionCard` 同时展示 `照片写作` 和 `听` 两个 secondary chip。
- `PhoneMainView` 将 `照片写作` 和 `听` 都接入 `.unavailable(...)`。
- `EntryDetailView` 和 `PracticeSessionView` 默认渲染 `RequestPreviewCard`。
- `PracticeView` 复用 `CapabilityStatusRow` 展示练习内容。
- `MemoryView` 在 iPhone 主页面展示 `MemoryLayerSummaryView` 和 `memory.vectorIndex.*`。

## 目标

- iPhone 记录页首屏保持一个主 CTA 和一个强次级照片写作入口。
- 点击照片写作进入本地 mock 预览 sheet，展示照片场景、话题建议、母语草稿、目标语示例和本地预览边界。
- 用户可从 mock 预览创建一条 `photoWriting` 记录，并进入记录详情；不访问相册、不请求权限、不发起网络或 AI Provider 请求。
- 练习页把听/跟读放在练习域，而不是记录 Hero。
- 默认学习流去掉常驻请求预览。

## 不做什么

- 不接入 PhotosUI、相机、OCR、真实 AI Provider、TTS、Speech、录音或权限流程。
- 不改变 iPad / macOS 的页面结构。
- 不重写数据库、Repository 长期模型或同步边界。
- 不删除 `RequestPreviewCard` 组件；它仍保留给后续显式外部 AI 请求确认路径。

## 证据与决策依据

- `docs/review/rounds/2026-05-19-ios-page-element-design-audit/README.md`
- `docs/product-main-reference.md` 的产品北极星：用生活记录学习语言。
- `docs/spec/002-navigation-and-routing.md` 的 iPhone 三 Tab 结构。
- `docs/spec/003-ui-design-system.md` 的高级、现代、简洁、长期可读原则。
- `docs/spec/005-ai-provider-prompt-and-privacy.md` 的外部请求预览边界。

## 涉及的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContent.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSections.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/EntryDetailHeader.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 参考的代码文件路径

- `Packages/LangoTraceData/Sources/LangoTraceData/SeedLearningContent.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/LearningContentModels.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/PremiumUIBehaviorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/LearningContentStoreTests.swift`

## 涉及的文档路径

- `docs/review/rounds/2026-05-19-ios-page-element-design-audit/README.md`
- `docs/review/INDEX.md`
- `docs/plans/done/2026-05-19-feature-ios-page-element-convergence-and-mock-photo-writing.md`

## 实施方案

1. 在审查记录追加“未接入能力真实级模拟展示原则”，明确关键 UX 路径用本地模拟展示，不伪装成真实 AI/权限能力。
2. 在本地 repository / store 增加 `createMockPhotoWritingEntry`，创建带 mock rendering、practice item 和 memory item 的照片写作记录。
3. 新增 iPhone `PhotoWritingPreviewView` sheet，使用本地模拟内容展示照片写作真实级页面，并提供“用这个片段生成记录”动作。
4. 修改 `HeroActionCard`：只保留照片写作次级入口，移除记录 Hero 的 `听`。
5. 修改记录详情与练习会话：移除默认 `RequestPreviewCard`，删除详情 header 边界说明，压低解释性 subtitle。
6. 修改练习页：用轻量 `PracticeTaskRow` 代替 `CapabilityStatusRow`，并在顶部提供“继续听 / 跟读”的练习动作。
7. 修改记忆页：iPhone 主页面只展示个人词句列表和空状态，不展示向量索引和三层技术摘要。
8. 更新测试：增加源代码级回归，确保 iPhone 记录 Hero 不再并列 `听`，照片写作使用 mock sheet，记录详情/练习会话不再常驻请求预览。

## 复查方法

- 代码层检查 `PhoneMainSupportingViews.swift` 中 `HeroActionCard` 不再渲染 `common.listen`。
- 代码层检查 `EntryDetailView` / `PracticeSessionView` 不再直接渲染 `RequestPreviewCard`。
- 代码层检查 `PhoneMainSections.swift` 的 iPhone `MemoryView` 不再渲染 `MemoryLayerSummaryView` 或 `memory.vectorIndex.*`。
- 测试覆盖照片写作 mock 创建和 iPhone 页面结构约束。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceUI
git diff --check
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git status --short
```

## 文档影响检查

本任务不改变长期 AI 请求隐私原则、不新增真实权限路径、不改变三端导航规范。审查记录需要追加本次用户确认后的模拟展示原则。若后续把照片写作接入真实 PhotosUI / AI Provider，需要新建权限与 AI 请求任务方案，并更新 `docs/spec/005-ai-provider-prompt-and-privacy.md` 与 `docs/spec/008-permissions-local-privacy-and-diagnostics.md`。

## 实施记录

- 2026-05-19：新增 `createMockPhotoWritingEntry` 本地模拟数据路径，可创建 `photoWriting` 记录、mock rendering、听/跟读 practice items 和 memory item。
- 2026-05-19：记录页 Hero 移除同级 `听`，保留 `用照片开始`，点击后进入本地照片写作模拟预览 sheet。
- 2026-05-19：新增 `PhonePhotoWritingPreviewView.swift` 和 `PhonePracticeRows.swift`，避免把新展示流继续塞入已有大文件。
- 2026-05-19：记录详情和练习会话默认流移除常驻 `RequestPreviewCard`；详情 header 移除边界说明。
- 2026-05-19：练习页改用 `PracticeContinuePanel` / `PracticeTaskRow`，把听/跟读承接到练习域。
- 2026-05-19：iPhone 记忆页移除三层技术摘要和向量索引主卡，只保留个人词句和空状态。
- 2026-05-19：新增 `PhoneIOSConvergenceTests`，并扩展 Data / UI store 测试覆盖照片写作 mock 闭环。
- 2026-05-19：审查记录追加“未接入能力的真实级模拟展示原则”，并更新审查索引后续覆盖记录。

验证结果：

- `swift test --package-path Packages/LangoTraceData`：通过，11 tests passed。
- `swift test --package-path Packages/LangoTraceUI`：通过，72 tests passed。
- `swiftlint --no-cache`：通过，0 violations。
- `swiftformat --lint . --cache ignore`：通过，0/95 files require formatting。
- `scripts/verify.sh`：通过；包含 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS build、SwiftLint、SwiftFormat、docs placeholder scan 和 git status 输出。

## 完成标准

- iPhone 记录 Hero 只保留文字记录主 CTA 和照片写作次级入口。
- 照片写作展示真实级本地模拟流，并可创建 mock 学习材料。
- `听` 不再作为记录 Hero 同级入口，练习域承接听/跟读。
- 默认记录详情和练习会话不出现常驻请求预览卡。
- iPhone 记忆页不出现向量索引或三层技术摘要。
- 相关测试和文档检查通过。

## 剩余风险

- 本轮不运行截图矩阵时，只能通过源代码和构建/测试确认页面结构，不能完全替代真实设备视觉验收。
- 照片写作 mock 使用系统图形模拟照片缩略图，不代表真实照片选择体验。
