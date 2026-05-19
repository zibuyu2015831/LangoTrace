# 任务方案：App 图标重设计与替换

状态：Verified

类型：chore

创建日期：2026-05-20

最后更新日期：2026-05-20

## 用户确认记录

- 2026-05-20：用户提供当前测试图标截图，要求根据产品定位和愿景重新设计。
- 2026-05-20：经过多轮视觉方向对比，用户确认定稿方向为“抽象语言字根种子”，并回复“可以”，同意进入图标替换。

## 需求描述

将当前临时测试 App 图标替换为符合语迹 / LangoTrace 产品定位的正式方向图标。

定稿方向：

- 苔绿深色场。
- 象牙折面种子。
- 抽象语言字根。
- 低调暖金折射光。

图标应表达“个人生活材料被转译、沉淀为语言学习记忆”，避免被理解为普通笔记、聊天、翻译、课程闯关或音频 App。

## 现状描述

当前图标由 `scripts/generate-app-icon.swift` 生成，主要是深绿色底、纸页和曲线轨迹，属于快速测试资产。AppIcon 资源位于 `LangoTraceApp/Resources/Assets.xcassets/AppIcon.appiconset/`。

## 目标

- 更新 `scripts/generate-app-icon.swift`，让图标可以重复生成。
- 重新生成 `AppIcon.appiconset` 全尺寸 PNG。
- 保持 `Contents.json` 资源映射不变。
- 不改动 App 功能、导航、数据、AI、同步或本地化逻辑。

## 范围

涉及代码文件路径：

- `scripts/generate-app-icon.swift`
- `LangoTraceApp/Resources/Assets.xcassets/AppIcon.appiconset/*.png`

涉及文档路径：

- `docs/plans/done/2026-05-20-chore-app-icon-redesign.md`

## 不做什么

- 不引入真实文字、国旗、书本、对话气泡、麦克风或课程符号。
- 不改 `Contents.json`。
- 不调整产品文案、启动页或 UI 设计系统。
- 不处理当前工作区中与图标无关的其他改动。

## 证据与决策依据

- `docs/product-main-reference.md`：语迹定位为“把你的真实生活变成外语学习材料的本地优先语言学习 App”。
- `docs/spec/003-ui-design-system.md`：视觉应安静、清晰、温和、现代、长期可读，避免游戏化、营销页、AI 聊天室。
- 用户确认的视觉方向：抽象语言字根种子。

## 实施方案

1. 修改 `scripts/generate-app-icon.swift` 的绘制逻辑：
   - 背景使用低饱和苔绿到深青的斜向渐变。
   - 中心绘制象牙色折面种子。
   - 种子内部绘制抽象语言字根。
   - 增加弱暖金折射光，降低装饰感。
2. 运行 `swift scripts/generate-app-icon.swift` 生成所有 AppIcon PNG。
3. 视觉检查 `Icon-1024.png` 和小尺寸代表图标。
4. 运行轻量验证命令，确认资源和脚本状态。

## 复查方法

- 检查生成的 `Icon-1024.png` 是否符合定稿方向。
- 检查 `Icon-60@3x.png`、`Icon-40@3x.png`、`Icon-29@3x.png` 小尺寸是否仍能读出“深色底 + 折面种子 + 抽象字根”。
- 检查 `git diff --check`。
- 检查 `git status --short`，确认变更范围。

## 验证命令

```bash
swift scripts/generate-app-icon.swift
swiftformat scripts/generate-app-icon.swift --cache ignore
git diff --check
git status --short
find LangoTraceApp/Resources/Assets.xcassets/AppIcon.appiconset -maxdepth 1 -name '*.png' | wc -l
```

本任务未运行完整 `scripts/verify.sh`，因为图标资源替换不改变 Swift 编译逻辑；若后续进入提交、发布或模拟器验收，应再运行完整验证。

## 文档影响检查

本任务不改变产品定位、核心决策、导航、数据、AI、隐私、同步、StoreKit 或发布流程；无需更新 ADR、architecture 或 spec。任务方案本身记录本次图标决策。

## 实施记录

- 2026-05-20：更新 `scripts/generate-app-icon.swift`，用苔绿深色场、象牙折面种子、抽象语言字根和弱暖金折射光替换旧纸页测试图标。
- 2026-05-20：运行 `swift scripts/generate-app-icon.swift`，重新生成 `AppIcon.appiconset` 下 25 个 PNG。
- 2026-05-20：视觉检查 `Icon-1024.png`、`Icon-60@3x.png`、`Icon-40@3x.png`、`Icon-29@3x.png`，大图和代表性小尺寸均保留定稿主符号。
- 2026-05-20：运行 `swiftformat scripts/generate-app-icon.swift --cache ignore`，结果为 `0/1 files formatted`。
- 2026-05-20：运行 `git diff --check`，通过，无输出。
- 2026-05-20：提交前运行 `scripts/verify.sh`，首次因 `scripts/generate-app-icon.swift` 函数长度和行长触发 SwiftLint 失败；已将绘制逻辑拆成背景、折射光、折面种子和语言字根 helper 后重跑。
- 2026-05-20：再次运行 `scripts/verify.sh`，通过；覆盖 XcodeGen、Core/Data/UI package tests、iPhone 17 build、iPad Pro 13-inch (M5) build、macOS arm64 build、SwiftLint、SwiftFormat lint 和文档占位扫描。

## 完成标准

- 图标生成脚本已更新。
- AppIcon PNG 已重新生成。
- 视觉检查通过。
- `git diff --check` 通过。

## 剩余风险

- 未进行真实设备主屏 / Dock 截图矩阵；本轮先完成资源替换和本地视觉检查。
- `.superpowers/` 下保留本次视觉伴随临时设计稿，未纳入正式 App 资源。
