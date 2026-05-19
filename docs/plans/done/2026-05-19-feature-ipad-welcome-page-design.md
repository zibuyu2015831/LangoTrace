# 任务方案：iPad 首次打开 Welcome 页面设计优化

状态：Implemented
类型：feature
创建日期：2026-05-19
最后更新日期：2026-05-19

## 用户确认记录

2026-05-19：用户确认本任务优化对象是“首次打开 App 的 Welcome 页面”，不是已创建语言空间后的主首页。

2026-05-19：用户确认中文副标题使用第一版方向：

```text
拍照、写日记、录音，
语迹会帮你整理成表达和练习。
```

用户同时说明当前项目处于起步阶段，拍照、写作/随笔、录音等功能都待开发；当前主要任务是完成页面设计。

2026-05-19：用户进一步确认副标题改为：

```text
拍照、随笔、录音，
语迹会帮你整理成表达和练习
```

2026-05-19：用户进一步确认去除副标题中的“录音”。原因是多语言语音转文本功能开发难度较大，Welcome 首屏不应过早承诺音频输入。用户采纳的新副标题为：

```text
拍照、随笔，
语迹会帮你整理成表达和练习
```

本次用户重点指出该改动涉及 iOS 和 iPad 端；由于当前实现刻意保持 `welcome.valueSubtitle` 为 Welcome 三端共享 key，不新增平台专用副标题，因此实现时按共享 Welcome 文案同步更新全部已支持界面语言，避免 macOS 继续保留“录音”语义造成产品承诺不一致。

## 1. 需求或 bug 描述

优化首次打开 App 时的 Welcome 页面设计。当前视觉重点是 iPad 端，并且需要同时考虑 iPad 横屏和竖屏；页面需要借鉴用户提供的两张参考图：横屏采用左右分栏的安静舞台，竖屏采用单列居中的首屏结构。

同时，`welcome.valueSubtitle` 是三端共享的 Welcome 副标题文案。本任务后续实现时必须让 iPhone、iPad 和 macOS 的 Welcome 页面使用同一套副标题语义，不能只在 iPad 页面局部改文案。

本任务不是实现真实拍照、日记、录音、AI 生成、TTS、同步或持久化能力，而是确定 Welcome 页面作为产品第一印象的视觉结构、文案层级、响应式布局和不误导用户的能力边界。

## 2. 现状描述

当前 Welcome 实现已经具备以下基础：

- `WelcomeView.swift` 使用 `welcome.valueTitle`、`welcome.valueSubtitle`、`welcome.cta.startSetup` 等本地化 key。
- `WelcomeView.swift` 已按尺寸区分 wide layout 和 compact layout。
- `WelcomeTracePreviewCarousel.swift` 已提供三张示例语迹卡片，并支持分页。
- `Localizable.xcstrings` 中 `welcome.valueSubtitle` 的简体中文当前为：

```text
拍照、写日记、记录声音，语迹会帮你整理成单词、表达和练习。
```

当前文案问题：

- `记录声音` 不如 `录音` 自然，动作感弱。
- `单词、表达和练习` 偏功能清单，会让 Welcome 页面显得更像工具目录。
- `表达和练习` 更贴近产品核心闭环，也更符合参考图中安静、直接的产品表达。

当前设计问题：

- 需要进一步明确 iPad 横屏和竖屏的布局目标，避免 iPad 竖屏像被压缩的横屏，或横屏像放大的 iPhone。
- 需要把参考图中“品牌 / 价值主张 / 预览卡 / 开始设置”结构固化为可执行设计方案。
- 当前功能尚未实现，页面必须避免让用户误以为点击后会立即拍照、录音、调用 AI 或保存学习内容。

## 3. 目标

- 将 iPad Welcome 页面定义为首次打开 App 的产品入口，而不是已进入语言空间后的主首页。
- 保留主标题：

```text
把生活，
变成你的语言素材。
```

- 将简体中文副标题改为：

```text
拍照、随笔，
语迹会帮你整理成表达和练习
```

- 横屏使用左右分栏：左侧承载品牌、标题、副标题、状态 badge 和 CTA；右侧承载语迹预览卡。
- 竖屏使用单列居中：上方承载品牌与标题，中部承载 badge 和预览卡，底部承载 CTA。
- iPhone、iPad 和 macOS 的 Welcome 副标题保持统一，均使用 `welcome.valueSubtitle` 的新语义，不按平台分叉成不同产品表达。
- Welcome 副标题不再承诺录音或语音转文本输入；配音和跟读属于后续基于目标语言文本的学习输出与练习能力，不等同于录音输入。
- CTA 保持 `开始设置`，进入母语、目标语言和水平自评，不直接创建语言空间。
- 保持 `本地优先` 与 `AI 可选` 语义，避免把未接入能力包装成已完成能力。
- 为后续实现提供明确文件、测试、验证和文档影响边界。

## 4. 范围

- Welcome 页面 iPad 横屏与竖屏布局设计。
- Welcome 页面三端共享副标题设计，其中 iPad 是本轮布局优化重点，iPhone 和 macOS 必须同步使用新副标题。
- Welcome 预览卡在首屏中的位置、密度和视觉层级。
- `Localizable.xcstrings` 中对应 key 的后续修改范围。
- `WelcomeView.swift` 和 `WelcomeTracePreviewCarousel.swift` 的后续实现范围。
- 针对 Welcome 文案、布局边界和本地化 key 的回归测试范围。

## 5. 不做什么

- 不实现真实拍照、照片权限、OCR、随笔/日记持久化、录音、Speech、TTS、AI Provider、同步或数据库。
- 不改变首次启动路由：仍由 Welcome 进入 Onboarding，再询问母语、目标语言和水平自评。
- 不默认创建语言空间。
- 不要求用户在首次启动选择数据目录。
- 不把 Welcome 页面改成营销 landing page。
- 不改变已创建语言空间后的 iPad 三栏工作台设计。
- 不为 iPhone、iPad 和 macOS 分别创造不同 Welcome 副标题，除非后续有明确平台文案设计理由。
- 不改产品长期 slogan 和产品主参考中的北极星定位。
- 不新增 ADR。

## 6. 证据与决策依据

- `docs/README.md`：首次启动不默认创建语言空间，先询问母语、目标语言和水平自评。
- `docs/product-main-reference.md`：产品核心是“把你的真实生活变成外语学习材料”，首页应围绕“今天记录一点生活”延展。
- `docs/spec/002-navigation-and-routing.md`：首次启动是状态路由；iPad 不应复用放大的 iPhone UI。
- `docs/spec/003-ui-design-system.md`：App 首屏不做营销式首页，应体现高级、现代、简洁和长期使用的安静质感。
- `docs/spec/006-interface-localization-and-language-boundaries.md`：新增或改进页面时必须考虑多语言长度差异，不能依赖固定中文短标签。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`：当前 Welcome 页面已有 wide / compact 结构，是本任务后续实现主文件。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`：当前 Welcome 预览卡和分页组件已存在，是本任务后续实现主文件。
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`：当前副标题文案的真实落点。

## 7. 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeTracePreviewCarousel.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 8. 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceRootView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/OnboardingView.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LangoTraceDesign.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/LocalizedChrome.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/LaunchRoute.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/OnboardingDraft.swift`

## 9. 涉及的文档路径

- `docs/README.md`
- `docs/product-main-reference.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/plans/active/2026-05-19-feature-ipad-welcome-page-design.md`

## 10. bug 分析

非 bug 任务，不适用。

## 11. 设计方案

### 11.1 页面定位

本页面命名为 Welcome 页面，承载首次打开 App 的第一印象。它回答三个问题：

1. 语迹做什么：把生活变成语言素材。
2. 用户可以从什么开始：拍照、随笔。
3. 语迹产出什么：表达和练习。

页面不承诺当前版本已经完成拍照、AI 生成或保存能力。当前阶段通过 `开始设置` 进入语言空间创建前的 Onboarding；副标题不承诺录音或语音转文本输入。

副标题属于 Welcome 页面的三端共享产品表达。iPad 本轮负责优化横竖屏视觉承载，iPhone 和 macOS 仍应显示同一副标题，保证用户在不同 Apple 设备上看到一致的产品承诺和能力边界。

### 11.2 中文核心文案

主标题：

```text
把生活，
变成你的语言素材。
```

副标题：

```text
拍照、随笔，
语迹会帮你整理成表达和练习
```

状态 badge：

```text
本地优先
AI 可选
```

主按钮：

```text
开始设置
```

辅助说明：

```text
首次设置约 30 秒 · 默认本地保存
```

### 11.3 横屏布局

横屏采用左右分栏舞台：

- 页面背景使用安静纸面色，不使用强装饰渐变、光球或复杂纹理。
- 内容整体居中，最大宽度约 `980-1120pt`，不贴边拉满。
- 左列宽度约 `400-440pt`，从上到下为品牌、主标题、副标题、状态 badge、CTA 和辅助说明。
- 右列宽度约 `460-560pt`，承载完整预览卡。
- 左右列间距约 `56-88pt`，根据宽度调整。
- 视觉顺序为：价值主张先读，预览卡提供具象理解，CTA 给出下一步。
- CTA 应与左侧叙事形成同一组，不应孤立漂到页面底部。

横屏参考结构：

```text
[ LangoTrace                  ]    [ 今日语迹预览卡       ]
[ 把生活，                    ]    [ 工作会议 / 咖啡店等   ]
[ 变成你的语言素材。          ]    [ 词汇                 ]
[ 拍照、随笔，                ]    [ 表达                 ]
[ 语迹会帮你整理成表达和练习  ]    [ 练习                 ]
[ 本地优先 ][ AI 可选 ]       ]
[ -> 开始设置                 ]
[ 首次设置约 30 秒 · 默认本地保存 ]
```

### 11.4 竖屏布局

竖屏采用单列居中舞台：

- 内容最大宽度约 `520pt`。
- 顶部保留品牌和主标题，不把品牌做成大 logo。
- 副标题在标题下方，允许自然换行。
- badge 放在副标题之后，保持触控舒适度。
- 预览卡位于中部，尺寸压缩但不拥挤。
- CTA 固定在底部 safe area 附近或随内容流保持首屏可见。
- 竖屏下不使用左右分栏，避免阅读路径断裂。

竖屏参考结构：

```text
LangoTrace

把生活，
变成你的语言素材。

拍照、随笔，
语迹会帮你整理成表达和练习

[ 本地优先 ] [ AI 可选 ]

[ 今日语迹预览卡 ]

-> 开始设置
首次设置约 30 秒 · 默认本地保存
```

### 11.5 预览卡内容

预览卡表达“生活记录会如何变成学习材料”，但不暗示真实能力已经执行。

推荐预览卡信息层级：

```text
今日语迹

工作会议
今天在会议中讨论了负责人、时间节点和下一步。

词汇
deadline · owner · clarify · next step

表达
Could we clarify the next step?

练习
改写 · 跟读 · 收藏句型
```

后续实现可以保留多示例 carousel，但首屏必须保证第一张卡在横屏和竖屏都完整、稳定、可读。

### 11.6 能力边界表达

虽然副标题包含拍照、随笔，但当前阶段这些能力尚未开发。因此实现时必须遵守：

- Welcome 页面只展示产品方向，不直接出现相机、麦克风或 AI 生成按钮。
- `开始设置` 只进入 Onboarding，不触发权限弹窗。
- 预览卡是静态示例，不触发真实记录、AI 请求、TTS、录音或保存。
- 后续如果在 Welcome 或 Onboarding 中加入更多说明，必须明确“默认本地保存”和“AI 可选”，不能暗示自动外发。

### 11.7 国际化策略

本次中文副标题确定后，其他界面语言不应简单保留旧的泛化句子。后续实现时必须同步调整 `welcome.valueSubtitle` 的所有已支持语言，使三端语义保持一致：

- 强调输入动作：photo / quick writing。
- 强调产出：expressions and practice。
- 避免把 `words` 作为 Welcome 副标题的核心产物。

英文建议方向：

```text
Take photos and jot notes.
LangoTrace turns them into expressions and practice.
```

如果双句在部分语言中过长，可以使用同义短句，但语义必须保持“生活动作 -> 表达和练习”。

## 12. 实施方案

### 12.1 文案更新

修改 `Localizable.xcstrings`：

- `welcome.valueSubtitle` 的 `zh-Hans` 改为已确认文案。
- 同步更新 `en / es / ja / fr / de / ko / ru`，从当前泛化句子改为“生活动作 -> 表达和练习”的同义结构。
- 保持 `welcome.valueTitle` 不变。
- 确认 `WelcomeView.swift` 的 iPhone、iPad 和 macOS 展示路径都继续读取同一个 `welcome.valueSubtitle` key，而不是新增平台专用副标题字符串。

### 12.2 布局更新

修改 `WelcomeView.swift`：

- 保留 `usesWideLayout(in:)` 的响应式入口。
- 横屏 wide layout 使用左右分栏，并把 CTA 与左侧叙事绑定。
- 竖屏 compact layout 使用单列居中，并通过 bottom safe area 保证 CTA 可见。
- 调整 spacing、max width、preview card width 和 CTA width，使 iPad 横屏与竖屏分别符合设计目标。
- 保证 iPhone compact、iPad regular / compact、macOS 宽窗口 / 窄窗口都使用同一副标题文案，只在布局承载上自适应。

### 12.3 预览卡更新

修改 `WelcomeTracePreviewCarousel.swift`：

- 第一张示例优先使用与参考图一致的“工作会议”语义。
- 保持静态 carousel，不引入自动轮播。
- 保持 page indicator 靠近卡片，不抢主 CTA。
- 宽屏卡展示完整层级，紧凑卡展示核心层级。

### 12.4 测试更新

修改 `WelcomeHomeOptimizationTests.swift`：

- 断言 `welcome.valueSubtitle` 仍是 Welcome 页面副标题 key。
- 断言旧中文副标题 `拍照、写日记、记录声音，语迹会帮你整理成单词、表达和练习。` 不再出现在 String Catalog。
- 断言新中文副标题 `拍照、随笔，语迹会帮你整理成表达和练习` 存在于 String Catalog。
- 断言 Welcome 页面继续使用 `WelcomeTracePreviewCarousel(isExpanded: true)` 和 `WelcomeTracePreviewCarousel(isExpanded: false)`。
- 断言代码中不出现旧中文片段对应的 hard-coded 内容。
- 断言 `Localizable.xcstrings` 中 Welcome 关键 key 覆盖当前支持语言。
- 断言三端没有新增平台专用副标题 key，例如 `welcome.valueSubtitle.iPad`、`welcome.valueSubtitle.phone` 或 `welcome.valueSubtitle.mac`。
- 如果实现改变布局函数名，同步更新结构测试，测试行为边界而不是锁死无意义内部命名。

## 13. 复查方法

- 代码复查：确认 `WelcomeView.swift` 没有硬编码中文文案，所有用户可见文案来自 String Catalog 或本地化封装。
- 设计复查：对照横屏参考图，检查左右分栏、CTA 位置、预览卡宽度和页面留白是否符合 iPad 首屏。
- 设计复查：对照竖屏参考图，检查标题、副标题、预览卡和 CTA 是否在首屏中形成稳定阅读路径。
- 三端文案复查：检查 iPhone、iPad 和 macOS 的 Welcome 页面均展示同一套副标题语义，只因布局宽度不同而换行，不出现平台文案分叉。
- 产品复查：确认页面没有引导用户误以为拍照、录音、真实 AI 或持久化已经完成。
- 本地化复查：确认中文、英文和长文本语言不会挤压按钮或导致预览卡文字重叠。

## 14. 验证命令

方案文档创建后的文档验证：

```bash
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

后续实现完成后的最低验证：

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
git diff --check
```

后续实现完成后的完整验证：

```bash
scripts/verify.sh
```

## 15. 文档影响检查

本任务创建 Welcome 页面设计与实现方案，不改变产品北极星、首次启动路由、语言空间模型、AI Provider 边界、权限边界、同步边界、StoreKit 或发布策略，因此当前不需要新增 ADR。

如果后续实现过程中决定把“拍照、随笔、录音”提升为当前版本已完成能力，必须另建功能方案，并读取权限、本地隐私、AI、Speech、OCR 和数据存储相关规范。

如果后续实现只改 Welcome 页面文案和布局，完成后只需更新本方案实施记录并移入 `docs/plans/done/`。由于副标题是三端共享 Welcome chrome，实现收口时应在本方案实施记录中写明 iPhone、iPad 和 macOS 的文案一致性检查结果。

## 16. 实施记录

2026-05-19：创建方案，记录 Welcome 页面定位、iPad 横竖屏设计、已确认中文副标题和功能未完成阶段的能力边界。

2026-05-19：完成首轮落地。`Localizable.xcstrings` 中共享的 `welcome.valueSubtitle` 已更新为用户当时确认的简体中文文案：

```text
拍照、随笔、录音，语迹会帮你整理成表达和练习
```

同步更新 `en / es / ja / fr / de / ko / ru`，语义统一为“生活动作 -> 表达和练习”。本次没有新增 iPhone、iPad 或 macOS 平台专用副标题 key，三端 Welcome 页面继续通过 `WelcomeView.swift` 使用同一个 `welcome.valueSubtitle`。

2026-05-19：根据用户最新确认，去除 Welcome 副标题中的“录音”输入承诺。`welcome.valueSubtitle` 的简体中文更新为：

```text
拍照、随笔，
语迹会帮你整理成表达和练习
```

同步更新 `en / es / ja / fr / de / ko / ru`，语义统一为“拍照与随笔 -> 表达和练习”，不再包含 record audio / 录音 / 録音 / 녹음 等音频输入承诺。由于副标题仍为共享 key，本改动自然覆盖 iPhone、iPad 和 macOS，未新增平台专用副标题。

`WelcomeHomeOptimizationTests.swift` 已新增回归测试，覆盖：

- 新中文副标题必须存在。
- `写日记`、`记录声音`、`单词、表达和练习` 等旧表达不能继续出现在 Welcome 副标题中。
- 不能新增 `welcome.valueSubtitle.iphone`、`welcome.valueSubtitle.iPad`、`welcome.valueSubtitle.mac` 等平台专用副标题 key。

验证记录：

- 先运行 `swift test --package-path Packages/LangoTraceUI`，新增测试按预期失败，失败点为旧中文副标题仍存在。
- 修改 String Catalog 后再次运行 `swift test --package-path Packages/LangoTraceUI`，54 个测试通过。
- 收口运行 `scripts/verify.sh`，XcodeGen、Core / Data / UI 包测试、iPhone / iPad / macOS build、SwiftLint、SwiftFormat 和文档占位符扫描均通过。
- 当前 Welcome 布局文件已经具备本方案要求的 wide / compact 分支、iPad 横屏左右分栏、竖屏 bottom safe area CTA、三张静态示例卡片和非自动轮播 page indicator；本次收口保留这些实现，不引入真实拍照、录音、AI、TTS、同步或持久化能力。

2026-05-19：根据模拟器截图复查，发现 iPad 横屏 wide 分支虽然是左右分栏，但 CTA 仍位于页面下方全局居中，没有真正与左侧价值主张形成同一组。已修正 `WelcomeView.swift` 的非 macOS wide layout：新增 `wideLeftColumn(size:)`，将 `开始设置` CTA 移入左侧叙事列，并通过 `centersInAvailableWidth: false` 保持左列对齐；同步更新 `WelcomeHomeOptimizationTests.swift`，防止 iPad wide layout 回退为全局居中 CTA。

## 17. 完成标准

- 用户确认本方案可以进入实现。
- `welcome.valueSubtitle` 的中文文案按用户最新确认版本落地。
- iPhone、iPad 和 macOS 的 Welcome 页面均使用新副标题语义，且不新增平台专用副标题 key。
- iPad 横屏 Welcome 页面使用左右分栏，CTA 与左侧价值主张形成同一组。
- iPad 竖屏 Welcome 页面使用单列居中结构，CTA 首屏可见。
- Welcome 预览卡表达“生活内容变成表达和练习”，不误导为真实生成结果。
- 相关测试覆盖 Welcome 文案 key、布局分支和本地化 key 完整性。
- 后续实现通过 `swift test --package-path Packages/LangoTraceUI`。
- 收口前根据改动范围运行 `scripts/verify.sh` 或说明不能运行的原因和剩余风险。

## 18. 剩余风险

- 参考图展示的是静态视觉效果，真实 SwiftUI 在 Dynamic Type、Split View、Stage Manager 窄窗口和多语言长文本下可能需要进一步调整。
- Welcome 副标题已去除录音输入承诺；后续预览卡仍需避免把“配音 / 跟读”误表达为已完成的录音输入或语音转文本能力。
- 其他语言的副标题翻译如果只是机械翻译，可能损失中文文案的动作感和高级感；实现阶段需要至少人工复查英文与简体中文。
