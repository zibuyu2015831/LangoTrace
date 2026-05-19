# Welcome 首页下一轮三端优化

状态：Verified

类型：feature

创建日期：2026-05-18

最后更新日期：2026-05-18

## 用户确认记录

- 2026-05-18：用户要求阅读并参考 `docs/reference/LangoTrace 首页下一轮优化指导.md`，调用专业 skill，进行下一轮优化。

## 需求描述

基于参考指导文档，对 LangoTrace Welcome 首页继续做三端空间与比例精修：

- iPhone：按钮置于底部安全区上方，示例卡居中，主要区块拉开，主标题减重，副标题更清晰。
- iPad：保留左右结构，放大右侧示例卡，增强大屏原生感，左侧按钮收窄。
- macOS：保留桌面欢迎页方向，收窄 CTA，整体重心略微上移。

## 现状描述

上一轮优化已完成价值优先标题、AI 可选文案、今日语迹示例卡和三端差异化布局。当前不足主要是 iPhone CTA 仍在内容流中、iPhone 示例卡展示感不足、iPad 右侧预览卡偏小，以及宽屏 CTA 偏宽。

## 目标

1. iPhone 形成认知区、理解区、底部行动区的三段式结构。
2. iPad 保留左右结构，并让右侧今日语迹成为明确的大屏预览面板。
3. macOS CTA 控制在桌面端合理宽度内。
4. 保持当前语义和本地优先、AI 可选、开始设置、默认本地保存等文案方向。

## 范围

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`
- 本任务方案文档

## 不做什么

- 不改 onboarding 数据模型。
- 不接入真实 AI、数据库、同步或 StoreKit。
- 不把 iPad 主方案改为纯上下结构。
- 不新增长期产品/架构决策。

## 证据与决策依据

- `docs/reference/LangoTrace 首页下一轮优化指导.md` 明确建议：iPhone 底部 CTA、示例居中、区块拉开；iPad 保留左右结构并放大右侧预览；Mac 收窄按钮。
- iOS HIG 强调移动端主操作应易于触达并尊重安全区。
- iPadOS HIG 强调 iPad 不应只是放大 iPhone UI，应使用适合大屏的多区布局。
- macOS HIG 强调桌面窗口应可伸缩且控件尺寸克制。

## 涉及的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/WelcomeView.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/WelcomeHomeOptimizationTests.swift`

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`

## 涉及的文档路径

- `docs/reference/LangoTrace 首页下一轮优化指导.md`
- `docs/plans/active/2026-05-18-feature-welcome-home-next-optimization.md`

## 实施方案

1. 先补充 Welcome 布局回归测试，覆盖底部行动区、紧凑示例居中、宽屏 CTA 宽度和 iPad/Mac 预览卡尺寸策略。
2. 重构 `WelcomeView` 的紧凑布局：内容区与底部行动区分离，底部 action 使用 `safeAreaInset`，示例卡在剩余空间中居中。
3. 调整宽屏布局：根据尺寸选择 iPad 与 Mac 的 CTA 宽度、预览卡宽度、内容上边距和左右比例。
4. 保持本地化 key 不变，避免扩大 String Catalog 范围。
5. 品牌标识使用 `LangoTrace` 产品大小写，避免全大写标牌感，并收敛字距。

## 复查方法

- 对照指导文档 P0/P1 清单逐项检查源码实现。
- 运行 Welcome UI package 测试。
- 运行仓库统一验证脚本。
- 检查 `git diff --check` 与工作区状态。

## 验证命令

```bash
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
git diff --check
git status --short
```

## 文档影响检查

本次仅调整 Welcome 首页 UI 比例和布局，不改变产品北极星、导航规则、数据、AI、隐私、同步、权限、付费或发布规则；无需新增 ADR 或长期 spec。任务完成后将本方案移入 `docs/plans/done/` 并记录验证结果。

## 实施记录

- 2026-05-18：创建任务方案，并按 TDD 增加 Welcome 布局回归测试。
- 2026-05-18：新增测试先失败，失败点覆盖底部行动区、紧凑示例居中、宽屏预览尺寸和 CTA 宽度。
- 2026-05-18：实现紧凑布局底部 `safeAreaInset` 行动区、示例卡居中、宽屏自适应预览卡尺寸、iPad/Mac CTA 宽度收敛和副标题可读性调整。
- 2026-05-18：`swift test --package-path Packages/LangoTraceUI` 通过，48 个测试通过。
- 2026-05-18：修正 SwiftLint line length warning 后，准备执行最终全量验证。
- 2026-05-18：根据人工视觉复查反馈，将 Welcome 品牌标识从 `LANGOTRACE` 调整为 `LangoTrace`，并新增回归测试避免回退到全大写。
- 2026-05-18：根据 iPad 模拟器截图复查反馈，重新设计宽屏 Welcome 布局：使用水平居中且垂直落在上中部的 stage、固定 iPad 预览卡列宽、放大宽屏标题与副标题、将 CTA 从左列移到 stage 下方，避免 iPad 页面呈现左上角小块与大面积空白。

## 完成标准

- iPhone CTA 从内容流分离到底部行动区。
- iPhone 示例卡水平居中且宽度受控。
- iPad 仍为左右结构，右侧预览卡尺寸明显增强。
- iPad 宽屏内容形成居中 stage，避免预览卡被 `HStack` 压缩。
- Mac CTA 宽度收窄。
- 品牌标识使用 `LangoTrace`，不使用 `LANGOTRACE`。
- Welcome 相关测试通过。
- `scripts/verify.sh` 通过。

## 剩余风险

- 当前验证以源码约束和构建测试为主，不替代真机视觉 QA；建议后续在 iPhone、iPad、macOS 模拟器中人工扫一遍视觉比例。
