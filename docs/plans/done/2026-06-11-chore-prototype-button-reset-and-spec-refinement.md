# 原型按钮渲染修复与 spec 体系修订（prototype button reset and spec refinement）

状态：Verified
自审核状态：Reviewed
类型：chore
创建日期：2026-06-11
最后更新日期：2026-06-11

## 用户确认记录

2026-06-11 用户在会话中明确授权本任务：

> 我检查了一下原型图，发现出现滚动选择条的页面都存在问题，具体可以查看【img/image.png】图片，需要对整套原型图进行一次检查和优化；另外，根据你对 iOS 应用开发的了解和官方规范文档，对【docs/spec】目录下的文档再进行一次检查、修订和更新，使其能正确、高效指导之后的开发工作。检查和更新工作包括但不限于：基于原型图中规定的内容，补充、新增【docs/spec】中没有的规范文档；对于任何你觉得有必要的地方，对规范文档进行细化或拆分；如有必要，补充官方文档的地址或摘要内容，或补充示例。遇到任何疑问或需要抉择的地方，需要你站在系统架构师的角度，基于项目的定位和愿景，进行充分思考，然后采取最优方案。

## 需求与诊断结论

### 工作流 A：原型渲染问题

用户截图（`img/image.png`，onboarding 页）显示选择列表渲染成一摞内容宽度、带系统灰边的小盒子，形似系统滚动选择器。诊断根因：

- `prototypes/shared/tokens.css` 的按钮 reset 只有 `font: inherit; cursor: pointer;`，未清除浏览器 UA 默认的 border、background、padding 和居中 text-align。
- `<button>` 即使设为 `display: flex` 仍保持收缩适应宽度（表单控件 `width: auto` 语义），不会像普通块级元素一样撑满容器。
- 因此块级容器 `.list` 内的 `<button class="row">`（onboarding、language-spaces、memory、reading 共 13 处）渲染为窄的灰边按钮；其余依赖 UA 默认值的按钮（如 `mac/reading.html` 的 `.doc-row`）也带系统按钮外观。
- 已审计全部 30 页的按钮类：共享基础类（`.btn` / `.icon-btn` / `.op-btn` / `.chip` / `.capsule` / `.nav-back` / `.seg button`）和页面局部类（`.level-card`、`.sent-row`、`.timeline-row`、`.practice-card`、`.rec-btn` 等）均自带完整视觉定义，加全局 reset 后不受 UA 默认值影响；flex / grid 容器内的按钮由 stretch 对齐自然撑满，不依赖 width。

### 工作流 B：spec 检查结论

- **事实错误**：`docs/spec/010` 第 3 节仍写「当前顶层保持 `记录 / 练习 / 记忆` 三个主目的地」；阅读已于 2026-06-01 提升为一级 Tab（spec 002 已更新，010 漏改）。
- **可用性问题**：`docs/spec/003` §4.3 中 SentencePairView、单句练习页、记录详情文本卡三段约束为超长整段文本（单段超过 600 字），检索和遵循成本高。
- **缺口 1**：spec 003 只定义了 token 维度，没有字号层级与 Apple 文本样式（Dynamic Type）的对应基准；原型已形成完整字号 scale，需要明确「原型 px 是视觉层级基准，实现必须用语义 Font.TextStyle」的映射规则。
- **缺口 2**：练习域没有 domain spec。阅读有 `012-reading-learning-domain.md`，而练习的会话 / 录音模型、route seed 契约、隐私边界和练习方式扩展边界分散在 spec 003、页面清单和架构备忘录中；听写 / 回译落地前需要一份汇集的练习域规范。
- **缺口 3**：各 spec 缺少 Apple 官方文档（HIG、开发者文档）引用，AI 会话和人工开发无法快速对照官方规范。

## 目标、范围和不做什么

目标：

1. 修复 `tokens.css` 全局按钮 reset（border / background / padding / text-align / appearance），`components.css` 为 `.row` 补 `width: 100%` 和左对齐，使列表行按钮在所有页面正确撑满。
2. 修正 spec 010 的 iPhone 顶层导航事实（三主目的地 → 四 Tab 含阅读）。
3. spec 003 §4.3 三段超长约束重构为带子标题的条目列表（纯结构调整，不改变任何约束语义）；新增字号层级与 Dynamic Type 映射基准；新增官方参考小节。
4. spec 002 / 010 各新增官方参考小节（HIG 导航、Tab、Sheet、可访问性、布局等）。
5. 新增 `docs/spec/013-practice-learning-domain.md` 练习域规范，汇集当前实现事实与扩展边界，更新 `docs/spec/README.md` 索引。

不做什么：

- 不修改归档原型（`prototypes/archive/`）。
- 不改变 spec 既有约束的语义；§4.3 重构逐句保留原约束内容。
- 不把原型目标设计（听写 / 回译 / 时间线 / 搜索 / 导入导出）写成 spec 当前强制规则；013 中扩展边界明确标注未实现，并引用架构备忘录。
- 不修改 Swift 代码、ADR 和 `docs/plans/` 历史方案。

## 涉及的文件路径

- `prototypes/shared/tokens.css`、`prototypes/shared/components.css`
- `docs/spec/003-ui-design-system.md`、`docs/spec/002-navigation-and-routing.md`、`docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/013-practice-learning-domain.md`(新增)、`docs/spec/README.md`
- 本方案（完成后移入 `docs/plans/done/`）

## 实施方案

1. **阶段 1**：创建本方案并自审核，commit。
2. **阶段 2**：原型修复（tokens reset + `.row` 宽度），复跑链接检查与按钮类静态审计，commit。
3. **阶段 3**：spec 010 事实修正 + spec 002 / 010 官方参考，commit。
4. **阶段 4**：spec 003 §4.3 重构 + 字号映射 + 官方参考，commit。
5. **阶段 5**：新增 spec 013 + spec README 索引，commit。
6. **阶段 6**：本方案补实施记录并移入 done，commit。

## 严格方案自审核记录

按 `docs/plans/plan-review-protocol.md` 自审核，确认的问题与修订：

1. **问题**：全局按钮 reset 可能让依赖 UA 默认视觉的按钮类失去样式。**修订**：已用脚本审计全部 30 页按钮类的 CSS 块，确认共享类和页面局部类均自定义 background / border / padding 或有意使用透明外观；唯一受影响的 `mac/reading.html .doc-row` 当前带 UA 灰边属于同类 bug，reset 后恢复设计意图（透明行 + active 态背景）。
2. **问题**：本环境无可用浏览器，无法对 30 页做渲染级目检。**修订**：以静态审计 + 链接检查覆盖；剩余风险记录为需要用户在本机浏览器复查截图页和任意含列表选择的页面。
3. **问题**：spec 003 §4.3 重构存在语义漂移风险。**修订**：重构只做「分段 + 列表化」，逐句搬运原文；变更记录注明纯结构调整；自查方式为重构前后约束条目数比对。
4. **问题**：spec 013 可能与页面清单、spec 003 重复造成事实漂移。**修订**：013 采用与 012 相同的 domain spec 定位 — 记录模型契约、生命周期和边界；页面级实现状态仍以页面清单为准，UI 视觉规则仍以 003 为准，013 显式声明该分工并互链。
5. **问题**：官方文档 URL 可能失效或记忆有误。**修订**：优先使用 HIG 稳定 slug；如当前环境可访问网络则抽样验证，否则在小节内注明链接基于 2026-01 知识截点、失效时以 HIG 站内搜索为准。
6. **TDD 落点**：纯静态原型与文档任务，无可自动化行为，按 CLAUDE.md 1.4 第 9 条豁免单元测试。
7. **剩余风险**：见文末。

## 验证命令

```bash
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
python3 - <<'EOF'
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
- spec 010 事实修正与 spec 002 既有表述对齐，消除两份规范间的矛盾。
- spec 013 新增后，`docs/spec/README.md` 索引同步更新。

## 实施记录

- 2026-06-11：阶段 1 完成，方案创建并自审核（commit `30dc4d7`）。
- 2026-06-11：阶段 2 完成，`tokens.css` 全局按钮 reset（border / background / padding / margin / text-align / appearance），`components.css` 为 `.row` 补 `width: 100%` 与左对齐、为依赖 UA 居中的 `.seg button` 补 `text-align: center`；原型链接检查通过；归档原型不引用 shared CSS，不受影响（commit `9ad525a`）。
- 2026-06-11：阶段 3 完成，spec 010 修正 iPhone 顶层导航事实为四 Tab 并与 spec 002 互链；spec 002 / 010 新增官方参考小节，全部链接 curl 验证 200（commit `0ebc754`）。
- 2026-06-11：阶段 4 完成，spec 003 §4.3 三段整段约束重构为 4.3.1-4.3.3 条目子小节（逐句保留语义）；新增 §4.9.2 字号层级与 Dynamic Type 映射基准；新增官方参考小节（commit `12780e6`）。
- 2026-06-11：阶段 5 完成，新增 `docs/spec/013-practice-learning-domain.md` 并更新 spec README 索引（commit `5e63ebe`）。
- 2026-06-11：阶段 6 完成，方案移入 done。验证：`scripts/check-docs.sh` 通过、占位扫描通过、原型链接检查通过、`git diff --check` 通过。HIG `inspectors` slug 返回 404，未引用该页。

## 完成标准

1. 全部含列表选择行的原型页按钮渲染依赖的 reset 与宽度规则进入 shared CSS；链接检查与按钮类审计通过。
2. spec 010 导航事实与 spec 002 一致。
3. spec 003 §4.3 重构后约束语义零丢失，新增字号映射与官方参考。
4. spec 013 建立并入索引。
5. `scripts/check-docs.sh`、占位扫描、`git diff --check` 通过；每阶段独立 commit。

## 剩余风险

1. 无浏览器渲染验证；需要用户在本机重新打开 `prototypes/index.html` 抽查 onboarding、language-spaces、memory、reading 和 mac/reading 页确认修复效果。
2. 官方文档链接可能随 Apple 站点改版失效；spec 中注明以 HIG 站内检索为兜底。
3. spec 013 基于页面清单与既有 spec 的事实汇编，未重读全部 Swift 源码；若与代码不一致，以代码为当前事实并按规范变更规则修正。
