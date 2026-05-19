# iOS 听力 sheet 开发标记清理

## 状态

Verified

## 背景

iPhone 记录详情页中，逐句练习卡片的 `听` 按钮仍会打开 `UnavailableCapabilityView(content: .listenOne)`。该 sheet 显示 `听力播放规划中`、`待配置`、`接下来`、`当前页面只展示入口边界，不播放真实 TTS、不录音、不保存练习结果` 等工程排期式文案。

这与 2026-05-19 iOS 页面元素收敛结论冲突：未真实接入的能力应先使用模拟数据搭建真实级页面展示，而不是把内部接入计划暴露给用户。

## 根因

- `Packages/LangoTraceUI/Sources/LangoTraceUI/LearningContentComponents.swift` 中 `SentencePairView` 保留了可选 `onListen`。
- 调用方没有传入 `onListen` 时，按钮会设置 `isListenUnavailablePresented = true`。
- sheet 内容来自 `UnavailableCapabilityContent.listenOne` 和 `unavailable.listenOne.*` 本地化 key。

## 修复方案

1. 将 `SentencePairView` 的 `听` 行为改为打开本地听力练习预览 sheet。
2. 新 sheet 使用当前句子的目标语言、母语翻译和学习提示，展示真实级练习状态，不写 `规划中`、`待配置`、`TTS 未接入` 或内部服务边界。
3. 保留“本地练习，不录音、不上传”的用户价值边界，但用产品语言表达。
4. 更新 UI regression 测试，禁止详情页听力入口回退到 `UnavailableCapabilityView(content: .listenOne)`。

## 验证

- 2026-05-19：`rg "听力播放规划中|当前页面只展示入口边界|unavailable.listenOne|UnavailableCapabilityView\\(content: \\.listenOne\\)|isListenUnavailablePresented|onListen" Packages/LangoTraceUI/Sources Packages/LangoTraceUI/Tests` 无结果。
- 2026-05-19：`swift test --package-path Packages/LangoTraceUI` 通过，73 tests。
- 2026-05-19：`swiftlint --no-cache` 通过，0 violations。
- 2026-05-19：`swiftformat --lint . --cache ignore` 通过，0/96 files require formatting。
- 2026-05-19：`scripts/verify.sh` 通过；首次运行曾暴露一个测试行长 warning，已拆行修复并重新验证。
