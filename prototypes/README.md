# 语迹 LangoTrace 多端原型（2026-06 重建版）

本目录是语迹 iPhone / iPad / macOS 三端页面的静态 HTML 原型集，覆盖已实现页面与路线中待开发页面的目标设计。原型是设计基准，不是实现事实源：当前实现事实以 `docs/platform-page-inventory.md` 为准；页面与区块若标注「目标设计」，表示尚未实现，落地前仍需独立 active plan 和用户确认。

重建背景与设计决策记录见任务方案 `docs/plans/done/2026-06-11-chore-prototype-redesign.md`。

## 打开方式

直接打开总览页，无需本地服务器，不依赖 npm、框架、CDN、远程图片或远程字体：

```text
prototypes/index.html
```

示例主线为中文母语 → 英语学习（「英语空间」）。

## 目录结构

```text
prototypes/
  index.html        # 三端页面总览与设计原则
  shared/
    tokens.css      # 设计 token（基于已审核外观色板）
    components.css  # 设备框、App chrome 与通用组件
  iphone/           # iPhone 页面（393pt 设备框）
  ipad/             # iPad 横屏工作台页面
  mac/              # macOS 窗口页面
  archive/          # 已完成使命的历史审核原型（只读）
```

## 视觉基准

- 色板沿用 2026-05-23 用户审核通过的外观基准（见 `archive/appearance-theme-review/`）：暖纸面背景、墨色文字、松绿 accent `#126b5d`。
- 双字形嗓音：UI chrome 与母语用系统 sans 栈（SF Pro / PingFang SC）；**目标语言学习内容**（英文美段 / 阅读正文 / 记忆词句 / 文档标题）用衬线栈 `--font-serif`（Apple 命中 New York，回退 Georgia），给「被学习的语言」一套阅读字形。内联描边 SVG 图标（1.6px stroke），不使用 emoji 图标。
- accent 收敛：松绿 accent 只表示「可操作 / 主动作」；目标语言内容靠衬线 + 暖墨色 `--target-lang` 区分，不再借用 accent 绿，避免一种颜色同时承担「语言内容 / 主操作 / 当前导航」三重语义。
- 排印精修：标题 `text-wrap: balance`、正文 `text-wrap: pretty`；统计数字 / 计数 / 日期用 `tabular-nums` 等宽对齐。
- 大屏密度：iPad / macOS 的横向余量投向 inspector（当前句分析 + 相关记忆 / 本文已加入记忆）而非拉宽阅读列或做正文多列——逐句学习是单焦点顺序模型，多列与之冲突；阅读 measure 守在 ≤ ~75ch / ~700px。
- 状态有设计：空 / 加载 / 失败 / 未配置均有独立原型（见 `index.html`「状态与边界」分区）；失败 / 未配置不以纯色表达状态，含「为何不可用 + 如何恢复 + 本地数据是否受影响」三要素。
- 触控目标 ≥ 44pt；状态以文案 + tone 共同表达，不只靠颜色。

## 维护规则

1. 页面专属样式写在各页面 `<style>` 内；`shared/` 下的 token 与组件变更会影响全部页面，需整体目检。
2. 新增页面后同步更新 `index.html` 总览和本 README。
3. 原型表达目标设计；当 SwiftUI 实现与原型出现有意偏差时，以实现与 spec 为准，并在相关任务方案中记录，不回改原型冒充历史。
4. 涉及视觉与交互约束时，以 `docs/spec/003-ui-design-system.md` 和 `docs/spec/010-apple-platform-interaction-and-accessibility.md` 为权威。
