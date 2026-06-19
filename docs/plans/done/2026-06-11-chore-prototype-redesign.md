# 多端 HTML 原型重建（prototypes redesign）

- 状态：Verified
- 自审核状态：Reviewed
- 类型：chore
- 创建日期：2026-06-11
- 最后更新日期：2026-06-11

## 用户确认记录

2026-06-11 用户在会话中明确授权本任务：

> prototypes 目录下存放着这个项目设计阶段时完成的 html 原型图，随着项目的开发，这些原型图已经远远落后了，考虑将其删除，然后根据目录的项目定位和愿景，将已经实现和待开发的所有页面，都重新设计原型图。考虑到这个项目同时支持 iPad、iOS 和 Mac 端，原型图可以创建子目录，分别存放。如果设计原型图的过程中，你遇到存在疑问的地方，请站在项目定位和愿景的角度进行思考并自行决策；如果你发现目前的页面或功能设计有不合理的地方，可以大胆重新设计，在原型图中体现并创建 active plan 文档详细说明原因和后续代码改进方案。整体要求是：设计一个功能符合设想、且页面设计现代、简约风、高级的 iOS 应用。实施的过程中，每个阶段都需要进行检查和 commit，便于后续回溯。

授权范围包含：删除过时原型、按平台子目录重建全部页面原型、对不合理设计自行决策并在本方案记录原因与后续代码改进方案、分阶段 commit。

## 需求描述

`prototypes/langotrace-multi-device-prototype/` 是产品设计阶段的静态原型，其信息架构（iPhone 五区结构、`今日` 首页、`听` 首屏入口、聊天式 AI 转换等）已远落后于当前实现（四 Tab `记录 / 阅读 / 练习 / 记忆`、记录详情真实生成闭环、逐句 TTS、单句跟读录音、阅读资料库等）。需要重建一套与当前实现事实和产品路线一致、覆盖"已实现 + 待开发"全部页面的多端原型，作为后续 UI 迭代和未来能力（时间线、听写、回译、记忆复习、搜索、同步、导入导出）的设计基准。

## 现状描述

- `prototypes/langotrace-multi-device-prototype/`：2026-05 初版设计原型，信息架构过时（来自 commit `7ce34b7`）。
- `prototypes/appearance-theme-review/`：2026-05-23 用户审核通过的浅色 / 深色色板基准（`Palette Approved Prototype`），结论已落地 `LangoTraceDesign.swift`。
- `prototypes/practice-session-prompt-card/`：单句练习内容卡交互原型，结论已落地 spec 003 与 `PracticePromptCard.swift`。
- 当前页面事实源：`docs/platform-page-inventory.md`（2026-06-01 快照）；视觉与交互约束：`docs/spec/003-ui-design-system.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`。

## 目标、范围和不做什么

目标：

1. 删除过时的 `langotrace-multi-device-prototype/`。
2. 将两个已完成使命但承载用户审核结论的小原型移入 `prototypes/archive/`（保留历史证据，不作为新任务入口）。
3. 重建 `prototypes/` 为按平台分目录的完整原型集：`shared/`（设计 token 与组件样式）、`iphone/`、`ipad/`、`mac/`，根目录 `index.html` 总览和 `README.md`。
4. 覆盖已实现页面（与页面清单一致）和路线中待开发页面（时间线筛选、听写、回译、记忆复习、搜索、同步、导入导出）的目标设计。
5. 视觉基调：现代、简约、高级、安静的学习工具感；沿用已审核通过的外观色板方向（暖纸面背景、墨色文字、松绿 accent）。

不做什么：

- 不修改任何 Swift 代码、`project.yml` 或测试。
- 不修改 spec / ADR / 页面清单的当前事实描述（原型中的"待开发"页面均在原型 README 标注为目标设计，不冒充已实现）。
- 不引入 npm、框架、CDN、远程字体或远程图片；原型保持本地双击可打开。
- 不为原型实现真实交互逻辑，仅静态展示 + 极少量演示性 CSS 状态。

## 证据与决策依据

- 页面事实：`docs/platform-page-inventory.md` 第 2–6 节（Root / iPhone / iPad / macOS / 共享组件清单）、第 8 节（不应出现的页面表现）。
- 视觉约束：`docs/spec/003-ui-design-system.md`（强制规则、状态矩阵、SentencePairView / 练习页 / 详情页布局规则、底部工具区规范）。
- 已审核色板：`prototypes/appearance-theme-review/styles.css`（暖纸面 `#ede8de`、墨 `#17201e`、muted `#5e6c66`、accent `#126b5d`），2026-05-23 用户确认通过。
- 路线：`CLAUDE.md` 第 2 节"尚未完成"列表与第 9 节优先级。
- 保守文档自进化原则（CLAUDE.md 1.3）：历史证据优先保留 → 已审核原型移入 `prototypes/archive/` 而非删除；过时设计原型无审核结论残值 → 直接删除。

## 设计决策与重新设计建议

以下为原型中体现的、与当前实现不同或超前于当前实现的设计决策，及对应后续代码改进方向。均不推翻第 4 节核心决策，不需要新增 ADR：

1. **记录 Tab 演进为生活时间线**：当前实现是"Hero + 最近记录列表"；原型在保留 Hero 双入口（写一句 / 用照片开始）的前提下，将列表演进为按日分组的时间线，并加入轻量筛选 chips（全部 / 照片 / 待练习 / 已沉淀）。对应路线中"完整生活记录时间线、跨端筛选"。后续代码改进：`PhoneRecordWorkspaceView` 列表区引入日期分组 section 和筛选状态，与 iPad `PadFilter` 共享筛选语义。
2. **记忆 Tab 目标体验**：当前为 Local Mock；原型设计为"从生活沉淀的词句 / 整句"卡片流 + 低压力复习队列入口，不暴露向量索引等工程概念（符合页面清单第 8 节红线）。后续代码改进：memory candidate 数据已在 GRDB learning content 主路径中，可先做只读沉淀列表，复习队列待 Embedding / 检索方案落地后接入。
3. **听写与回译以"练习方式"层级出现**：页面清单禁止把未实现任务类型混排进练习 Tab 首层；原型将其放在"记录 → 句子列表"层级的练习方式切换中（跟读 / 听写 / 回译），首层仍是记录卡片。后续代码改进：`PracticeSessionRouteSeed` 增加 practice mode 字段，复用同一句子快照与 TTS 示范路径。
4. **搜索**：iPad 顶部搜索与 macOS 搜索当前为 unavailable；原型给出目标设计（iPad 顶部搜索浮层、macOS Command Palette 风格全局搜索），范围限定当前语言空间，标注依赖 FTS。
5. **macOS 导入导出**：当前 unavailable；原型以桌面端为自然落点设计导出包（含范围选择、附件开关、不含密钥的边界说明）目标流程。
6. **同步设置**：沿用现有 Local Mock 信息架构（iCloud 推荐 + S3 高级），原型仅做视觉升级，不改变范围与密钥边界表达。
7. **保持不变的红线**：iPhone 维持四 Tab + gear；首屏不营销化；记录详情无 metadata badge；设置主列表无状态角标；逐句 `听` 原位播放；单句练习页遵守 spec 003 的 prompt card / control bar / 句间导航规则。

## 涉及的代码文件路径

无生产代码变更。删除 / 新增均在 `prototypes/` 下：

- 删除：`prototypes/langotrace-multi-device-prototype/`（全部 17 文件）。
- 移动：`prototypes/appearance-theme-review/`、`prototypes/practice-session-prompt-card/` → `prototypes/archive/` 下。
- 新增：`prototypes/README.md`、`prototypes/index.html`、`prototypes/shared/*.css`、`prototypes/iphone/*.html`、`prototypes/ipad/*.html`、`prototypes/mac/*.html`。

## 参考的代码文件路径

- `Packages/LangoTraceUI/Sources/LangoTraceUI/`（PhoneMainView、PadMainView、MacMainView 及详情 / 练习 / 设置组件，用于核对页面结构）。
- `prototypes/appearance-theme-review/styles.css`（已审核色板）。

## 涉及的文档路径

- `docs/plans/done/2026-06-11-chore-prototype-redesign.md`（本方案，创建于 `docs/plans/active/`，完成后移入 done）。
- `prototypes/README.md`（新原型入口说明）。
- `docs/README.md` 5.2 节引用的原型路径 `prototypes/langotrace-multi-device-prototype/README.md` 需要更新为新入口。

## 实施方案

分阶段执行，每阶段 commit：

1. **阶段 1**：创建本方案并 commit。
2. **阶段 2**：删除过时原型、归档两个已审核原型到 `prototypes/archive/`，commit。
3. **阶段 3**：搭建 `shared/` 设计 token / 组件样式、根 `index.html`、`README.md`，并完成 iPhone 端样板页（record + entry-detail）确立质量基准，commit。
4. **阶段 4**：完成 iPhone 全部页面（welcome、onboarding、record、entry-editor、photo-writing、entry-detail、reading、reading-document、practice、practice-sentences、practice-session、practice-dictation、practice-backtranslation、memory、settings、settings-ai-provider、settings-sync、language-spaces），commit。
5. **阶段 5**：完成 iPad 页面（workspace、reading、practice、memory、settings），commit。
6. **阶段 6**：完成 macOS 页面（workspace、reading、practice、memory、settings、search、import-export），commit。
7. **阶段 7**：更新 `docs/README.md` 原型路径引用，跑文档检查，移动本方案到 done，commit。

页面命名与目录：

```text
prototypes/
  README.md
  index.html
  shared/
    tokens.css
    components.css
  iphone/   # 393pt 设备框
  ipad/     # 横屏 1180pt 设备框
  mac/      # 1280pt 窗口框
  archive/
    appearance-theme-review/
    practice-session-prompt-card/
```

视觉基准（沿用已审核色板方向）：

- 背景：暖纸面 `#f6f1e8 → #ede8de` 渐变页面，卡片为暖白。
- 文字：墨 `#17201e`，次级 `#5e6c66`。
- Accent：松绿 `#126b5d`，浅 tint 用于选中 / 高亮。
- 字体：系统字体栈（SF Pro / PingFang SC），无远程字体。
- 图标：内联 SVG（描边风格，统一 1.6px stroke），不使用 emoji 图标。
- 触控目标 ≥ 44pt，状态不只靠颜色表达，空状态 / 加载 / 错误有真实设计。

## 严格方案自审核记录

按 `docs/plans/plan-review-protocol.md` 自审核，确认的问题与修订：

1. **问题**：直接删除 `appearance-theme-review/` 会销毁用户审核通过的色板证据，违反保守文档自进化原则"历史证据优先保留"。**修订**：移入 `prototypes/archive/`，README 标注 archived 状态。
2. **问题**：把听写 / 回译直接画进练习 Tab 首层会违反页面清单第 8 节红线。**修订**：放入句子列表层级的练习方式切换，并在原型页面标注"目标设计"。
3. **问题**：`docs/README.md` 5.2 节链接旧原型 README，删除后产生死链。**修订**：阶段 7 同步更新该引用并跑 `scripts/check-docs.sh`。
4. **问题**：原型若使用文档占位标记词会触发 verify 的文档占位扫描（仅扫 docs/，原型不在扫描范围，但 README 在 prototypes/ 下也不在 docs/ 内）。**修订**：占位扫描仅针对 `docs/`，prototypes 不受影响；仍避免在任何新文件中使用占位词。
5. **TDD 落点**：纯静态 HTML / CSS 原型与文档，无可自动化行为，按 CLAUDE.md 1.4 第 9 条豁免单元测试；验证以链接检查、文档检查和人工目检为主。
6. **剩余风险**：见文末。

## 复查方法

- 打开 `prototypes/index.html` 逐页目检三端页面。
- 对照 `docs/platform-page-inventory.md` 检查已实现页面覆盖，无遗漏一级页面。
- 对照 spec 003 第 8 节红线清单逐条检查原型不出现禁止表现。

## TDD / 测试落点

不新增单元测试。原因：纯静态原型与文档任务，无可自动化验证的行为变化；剩余风险通过人工目检和文档检查覆盖。

## 验证命令

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
python3 - <<'EOF'
# 校验原型内部相对链接无死链
import pathlib, re, sys
root = pathlib.Path('prototypes')
bad = []
for f in root.rglob('*.html'):
    for m in re.finditer(r'href="([^"#]+\.(?:html|css))"', f.read_text()):
        t = (f.parent / m.group(1)).resolve()
        if not t.exists():
            bad.append(f"{f}: {m.group(1)}")
print('\n'.join(bad) or 'prototype links OK')
sys.exit(1 if bad else 0)
EOF
```

## 文档影响检查

- 不改变数据、AI、权限、同步、StoreKit、ADR、启动闭环、语言空间闭环、验证脚本、XcodeGen、包边界或 App 启动结构，不触发专项审查。
- `docs/README.md` 5.2 节原型路径引用需随阶段 7 更新。
- 页面清单、spec、ADR 均不需修改：原型不改变实现事实。

## 实施记录

- 2026-06-11：阶段 1 完成，方案创建并自审核（commit `04977c4`）。
- 2026-06-11：阶段 2 完成，删除 `langotrace-multi-device-prototype/`（17 文件），归档两个已审核原型到 `prototypes/archive/` 并添加归档 README（commit `41e425e`）。
- 2026-06-11：阶段 3 完成，`shared/tokens.css` + `shared/components.css`（基于已审核色板）、`index.html` 总览、`README.md` 和 iPhone 样板页 record / entry-detail（commit `2244652`）。
- 2026-06-11：阶段 4 完成，iPhone 全部 18 页（commit `8ec91eb`）。
- 2026-06-11：阶段 5 完成，iPad 5 页（commit `e9eda44`）。
- 2026-06-11：阶段 6 完成，macOS 7 页（commit `86e2da8`）。
- 2026-06-11：阶段 7 完成，更新 `docs/README.md`、`docs/development/project-initialization.md`、`docs/development/environment.md` 中的原型路径引用（done plans 作为历史记录不改写）。验证：原型内部链接检查通过（30 页无死链）、全部页面含设计说明块、占位词扫描通过、`scripts/check-docs.sh` 通过、`git diff --check` 通过。
- 实施偏差：实际页面数为 iPhone 18 / iPad 5 / macOS 7（方案阶段 4-6 列表一致，无 scope 缩减）；done 目录下历史 plan 中的旧原型路径保留原样，属历史证据不回改。

## 完成标准

1. 旧多端原型删除，两个已审核原型归档且 README 标注状态。
2. 三端原型覆盖页面清单全部一级页面 + 本方案列出的待开发目标页面。
3. `prototypes/index.html` 可导航到全部页面，链接检查通过。
4. `scripts/check-docs.sh` 与占位扫描通过，`docs/README.md` 无死链。
5. 每阶段独立 commit。

## 剩余风险

1. 原型为目标设计快照，随实现推进会再次滞后；缓解：README 写明"以 `docs/platform-page-inventory.md` 为当前实现事实源，原型表达目标设计"。
2. 待开发页面（听写、回译、记忆复习、搜索、导入导出）的设计未经真实方案评审，落地时仍需独立 active plan 和用户确认；本原型不构成实现授权。
3. 静态原型无法验证 Dynamic Type、VoiceOver 与真实触控；相关验收仍依赖 SwiftUI 实现阶段。
