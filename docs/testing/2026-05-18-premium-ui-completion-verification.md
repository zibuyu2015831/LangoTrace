# 付费级 UI 收敛完成验证记录

日期：2026-05-18

范围：本记录覆盖本轮 UI 收敛扫尾，包括 `LangoTraceUI` Swift chrome 本地化、request preview 文案来源、iPhone / iPad / macOS 页面闭环 helper 回归，以及未接入能力的边界表达。

不覆盖：真实 SQLite / GRDB、真实 AI Provider、真实 TTS / Speech / OCR / Photos、同步、StoreKit、导入导出和发布材料。

## 自动化门禁

本轮必须通过以下检查后才能关闭：

```bash
ruby -rjson -e 'JSON.parse(File.read("Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings")); puts "json ok"'
rg -n '[\p{Han}]' Packages/LangoTraceUI/Sources/LangoTraceUI --glob '*.swift'
swift test --package-path Packages/LangoTraceUI
scripts/verify.sh
find docs -maxdepth 3 -type f | sort
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*'
git diff --check
git status --short
```

## 回归覆盖点

- `PremiumUIBehaviorTests` 覆盖 Local Mock request preview 不使用 external request 发送语义。
- `PremiumUIBehaviorTests` 覆盖 external request preview 只保留给真实 Provider 请求路径。
- `PremiumUIBehaviorTests` 覆盖 `Packages/LangoTraceUI/Sources/LangoTraceUI` Swift 源码不再包含硬编码中文 chrome。
- `PageClosureStateTests` 覆盖 iPad footer、Mac footer、iPad closure pages 和 settings capability localization key。
- `PadPanelGestureTests` 覆盖 iPad 左右辅助面板边缘手势判定。

## 手工截图矩阵

本轮代码收敛后，发布前仍需保留一轮手工截图或录屏证据：

| 平台 | 覆盖页面 | 重点 |
| --- | --- | --- |
| iPhone 17 | Welcome、Onboarding、今日、记录详情、练习、记忆、设置详情、unavailable 页 | 长文本不重叠；二级标题不遮挡；Local Mock 和 unavailable 语义清楚 |
| iPad Pro 13-inch (M5) | 三栏默认、左栏收起、右栏收起、记录详情、学习面板、设置详情 | 主内容不被辅助栏挤压；面板收起状态可访问；Split View 窄宽度可读 |
| macOS arm64 | 默认窗口、Sidebar 收起、Inspector 收起、记录库、练习、设置、导入导出 unavailable | 窗口最小宽度可用；toolbar 文案正确；Inspector 不读出 catalog key |

## 验收结论填写规则

- 自动化门禁失败时，不得标记完成。
- 截图矩阵未执行时，只能说明“自动化完成、手工截图待发布前补证”，不能写成已经完成全量视觉验收。
- 如果发现真实能力尚未接入，页面必须保持 Local Mock 或 unavailable 表达，不得把路线项写成已完成。
