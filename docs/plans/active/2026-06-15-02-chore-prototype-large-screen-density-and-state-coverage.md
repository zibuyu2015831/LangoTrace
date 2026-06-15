# 任务方案：原型第二轮收尾——iPad / macOS 大屏密度优化 + 空/加载/失败/未配置状态原型补全

状态：User Approved
自审核状态：Reviewed
类型：chore
创建日期：2026-06-15
最后更新日期：2026-06-15（用户确认 Q1/Q2 推荐方案，授权进入实现）

## 用户确认记录

- 2026-06-15：用户要求对 `prototypes/` 第一轮优化后的成果做花叔Design 第二轮评审；评审给出 7 项改进方向。
- 2026-06-15：用户确认「直接落地，本轮不必加 active plan」，已完成其中 5 项系统/页面级优化并提交（commit `0379905`）。
- 2026-06-15：用户要求对评审中**未在上一轮落地的两项**（#5 大屏画布密度、#6 空/失败态原型）「起草 active plan」。
- 2026-06-15：用户确认「按推荐顺序执行」，采纳 Q1（单列 + 富 inspector + 边注 gutter，不做多列）与 Q2（4 必做 +1 可选状态页，删 reading-empty / sync-states）推荐方案，授权进入实现；要求每阶段单独 commit、必要时用子代理。`状态` 推进至 `User Approved`。

## 1. 需求或 bug 描述

花叔Design 第二轮评审的 7 项方向中，已落地 5 项（衬线嗓音、accent 收敛、时间线层次、排印精修、onboarding 选择收敛）。剩余两项因属「更大改动 / 净新增页面」未在上一轮处理，本方案承接它们：

- #5 iPad / macOS 中央画布与 inspector 未吃满大屏：横向空间多转化为留白，密度仍接近 iPhone 放大版，未体现桌面/平板应有的信息密度与桌面阅读体验。
- #6 happy-path 全覆盖，缺空/加载/失败/未配置态原型：`prototypes/index.html` 设计原则声称「状态有设计：空状态、加载、失败、未配置均不是裸文本」，但现有抽样页全是满数据，该承诺缺少可见的原型资产佐证。

## 2. 现状描述

- 原型为纯静态 HTML/CSS，无 npm / 框架 / 远程依赖，直接 `file://` 打开；设计 token 与组件在 `prototypes/shared/{tokens.css,components.css}`。
- `components.css` 已内置 `.empty-state` 组件（icon + 标题 + 说明），以及 `.pill-warn/.pill-error`、`.sentence-note` 等状态表达原语——空/失败态有现成视觉语言可复用，无需新造组件体系。
- iPad/macOS 工作台已具备 `.workbench / .sidebar / .main-pane / .inspector` 三栏骨架；句子卡 `.sentence-card`、双语正文 `.body.target` 在三端共用。
- 记录详情已有「生成学习材料 / 重新分析」action seam（真实实现侧支持取消、取消保持取消态），但原型 `iphone/entry-detail.html`、`ipad/workspace.html`、`mac/workspace.html` 只画了「已生成」终态，未画加载中 / 失败 / 未生成（详情页内）态。
- 设置页 `iphone/settings-ai-provider.html` 只画「已配置」态；`iphone/settings-sync.html` 同步只画推荐路径，未画「未配置 / 同步失败」态。
- 实现事实源以 `docs/platform-page-inventory.md` 为准；原型只表达目标设计。

## 3. 目标

1. iPad / macOS 中央画布与 inspector 的信息密度与桌面阅读体验得到针对性提升，且不损害可读性（阅读行长受控）。
2. 关键流程的空 / 加载 / 失败 / 未配置态成为可见的原型资产，兑现 `index.html` 的「状态有设计」原则。
3. 新增/改动页面同步登记进 `prototypes/index.html` 总览与 `prototypes/README.md`，并与 `docs/spec/003-ui-design-system.md`「状态有设计」约束一致。
4. 全部页面 Playwright 重渲染零控制台错误；`scripts/check-docs.sh`、`git diff --check` 通过。

## 4. 范围

- 阶段 A（#5 大屏密度）：审计并优化 `ipad/workspace.html`、`ipad/reading.html`、`mac/workspace.html`、`mac/reading.html`（必要时 `mac/memory.html`）的中央画布 + inspector 密度。**取向已定（见 §12 决策）：保持阅读列宽不变，横向余量转化为更富 inspector + 句子边注 gutter，不做正文多列。** 优先复用既有类，密度策略可下沉 `components.css` 的桌面/平板变体。工作台页（sentence cards）与阅读页（long-form article）的余量去向不同，需分别处理（见 §12 F-3）。
- 阶段 B（#6 状态覆盖）：新增静态状态原型页（具体清单见实施方案 §12，已由 6 收敛为 4 必做 + 1 可选），复用 `.empty-state` 与状态 pill；详情页加载/失败态优先在新文件中表达，避免破坏现有 happy-path 文件的可读性。
- 文档：更新 `prototypes/index.html` 总览与 `prototypes/README.md`；按 `docs/review/README.md` 判断是否触发文档影响检查。

## 5. 不做什么

- 不改 SwiftUI 生产代码、不动 `Packages/*`、不触发数据/AI/同步真实链路；本方案纯原型（设计基准）。
- **不做正文/句子卡多列网格（已定，非候选）**：与「单焦点当前句子」交互模型（`.sentence-card.current`/`.op-btn.playing` + inspector「当前句子」镜像）冲突，且违反 macOS 既定「不做 dashboard」决策、损害第一轮确立的衬线阅读嗓音。横向余量改投 inspector 与边注 gutter（见 §12 决策）。
- 不为 #6 在尚不存在的子系统上画失败态：同步引擎未实现，本轮不出 `settings-sync-states`（含「同步失败」），避免把不存在能力的失败原型误读为已具备（见 §20 deferred 记录）。
- 不重做第一轮已定的视觉基准（衬线嗓音、accent 收敛、色板）。
- 不新增需要 JS 状态机的交互态（原型保持静态；加载/失败用静态定格表达，不做动画）。
- 不为状态态发明新组件体系；只复用 `components.css` 既有原语，必要时补极小变体。
- 不修改 `prototypes/archive/`（只读历史）。

## 6. 证据与决策依据

- 第二轮评审证据：本会话对三端 15 页真实渲染截图 + 代码审计（`tokens.css`/`components.css`，token 覆盖率 786 `var()` vs 118 hex）。
- 设计原则证据：`prototypes/index.html` 设计原则「状态有设计：空状态、加载、失败、未配置均不是裸文本；状态不以颜色为唯一信息」。
- 既有组件证据：`prototypes/shared/components.css` 的 `.empty-state`(676 行附近，commit `0379905` 插入衬线/tabular 规则后下移)、`.pill-*`、`.sentence-note`。
- 平台页面事实源：`docs/platform-page-inventory.md`（确认哪些状态对应已实现行为，避免原型表达不存在的能力时不加「目标设计」标）。

```text
证据能证明什么：第二轮评审指出 #5/#6 为剩余改进点，且 index.html 原则已承诺状态设计。
证据不能证明什么：无证据表明多列句子卡在大屏更好，反而与 as-built 单焦点模型冲突（F-2）——故本轮明确不做多列；不能证明每个失败态都对应已实现行为（需对照 page-inventory 决定是否标「目标设计」）。
迁移前提：复用既有 token / 组件，不引入远程依赖、不改生产代码。
照搬风险：盲目加密度会损害桌面阅读；盲目加状态页会让原型表达超出真实实现，误导为实现授权——用「目标设计」标缓解。
```

```text
是否需要 spike / probe / fixture / evidence：否（纯静态原型，验证靠 Playwright 截图人工目检）。
需要时的落点：不适用。
是否包含真实用户敏感内容：否（沿用现有 mock 中文→英语示例主线）。
如何验证和清理：Playwright 临时截图输出到 /tmp，不入库；无需清理仓库。
```

来源对照：本方案来源于一次设计评审（非 review round / health ledger / runtime trigger），无 finding id 体系；以本会话评审 7 项中的 #5、#6 作为 work item 锚点。

## 7. 约束映射与验证路径

### 约束 1：原型只表达目标设计，不构成实现授权
- 来源：`prototypes/README.md` 维护规则 1、3；`docs/platform-page-inventory.md`
- 适用范围：全部新增/改动原型页
- 严重度：blocker
- 执行或验证方式：人工审查 + 对照 page-inventory
- 验证提示：未实现行为对应的状态页须带 `tag-target-design` 标；已实现行为的状态页不滥标
- 说明：避免把「失败/未配置」原型误读为实现已具备

### 约束 2：状态有设计且不以颜色为唯一信息
- 来源：`prototypes/index.html` 设计原则；`docs/spec/003-ui-design-system.md`
- 适用范围：阶段 B 全部状态态
- 严重度：warn
- 执行或验证方式：人工目检（文案 + tone + 图标多重表达）
- 验证提示：失败态须有文案说明 + 恢复动作，不只红色

### 约束 3：shared/ 改动影响全部页面需整体目检
- 来源：`prototypes/README.md` 维护规则 1
- 适用范围：若密度策略下沉 `components.css`
- 严重度：warn
- 执行或验证方式：Playwright 三端代表页重渲染对比
- 验证提示：改 shared 后须复检 iPhone 页未被波及

### 约束 4：纯系统字体栈，不依赖远程字体/图片/CDN
- 来源：`prototypes/README.md` 打开方式说明
- 适用范围：全部
- 严重度：blocker
- 执行或验证方式：人工审查新增标记
- 验证提示：不得引入 web font / 远程图片

## 8. 涉及的代码文件路径

无（纯原型，非 `Packages/*` 生产代码）。原型文件：

- 阶段 A：`prototypes/ipad/workspace.html`、`prototypes/ipad/reading.html`、`prototypes/mac/workspace.html`、`prototypes/mac/reading.html`、（候选）`prototypes/mac/memory.html`、（如下沉密度策略）`prototypes/shared/components.css`
- 阶段 B（修订后）：必做 `prototypes/iphone/entry-detail-generating.html`、`prototypes/iphone/entry-detail-failed.html`、`prototypes/iphone/settings-ai-provider-unconfigured.html`、`prototypes/iphone/record-empty.html`；可选 `prototypes/iphone/memory-empty.html`。删去 `reading-empty.html`、`settings-sync-states.html`（见 §12 决策 / §20 deferred）。最终清单以 §12 为准。

## 9. 参考的代码文件路径

- `prototypes/shared/components.css`（`.empty-state`、`.pill-*`、`.sentence-card`、`.workbench/.inspector`）
- `prototypes/iphone/entry-detail.html`、`prototypes/iphone/settings-ai-provider.html`、`prototypes/iphone/settings-sync.html`（happy-path 参照）

## 10. 涉及的文档路径

- `prototypes/index.html`（总览，新增页登记）
- `prototypes/README.md`（目录结构 / 维护规则同步）
- `docs/platform-page-inventory.md`（对照已实现行为，判断「目标设计」标注；可能需补登记）
- `docs/spec/003-ui-design-system.md`（状态设计约束参照，原则上只读）
- `docs/review/README.md`（判断是否触发文档影响检查）

## 11. bug 分析

非 bug 任务，不适用。

## 12. 实施方案

### 阶段 A：iPad / macOS 大屏密度审计与优化

**决策（Q1，已定）**：保持阅读列宽不变，横向余量投向 inspector 与边注，**不做正文多列**。依据见 §13 自审核记录的 F-1/F-2 与「不做什么」。

1. 对 4–5 个工作台页逐页量测中央画布 measure 与留白占比，列出「真正浪费的空间 vs 必要的呼吸留白」。as-built 基线：`ipad .content-col` 640px、`mac .pane-content` 680px（≈70–76ch 衬线），**已在舒适区，本轮不加宽**。
2. 应用**针对性**密度提升（按审计结论取舍，不是全量加密）：
   - 主手段 a：**inspector 加密** —— 大屏 inspector 承载当前句子完整分析、相关记忆库条目、词句详情，填满现有半空 inspector，而非留白。
   - 主手段 b：**句子边注 gutter** —— 桌面/平板将 `.sentence-note` 浮到句子右侧边注栏（Tufte 式 sidenote），抬升信息密度但不挤压阅读列、不下推正文（iPhone 保持内联折叠）。
   - 工作台页 vs 阅读页区分（F-3）：`reading.html` 为长文正文而非句子卡，余量去向为持久 TOC / 生词 gutter，**不套用句子 inspector 模型**。
3. 密度差异若具通用性，下沉为 `components.css` 的平板/桌面变体类（如 `.sentence-card.dense`、`.sentence-note.sidenote`），避免逐页散落。
4. 守门：中央正文阅读 measure 控制在 ≤ ~75ch / ~700px（与 as-built 640–680px 一致，不收紧到原 620px——F-1）；改 shared 后回归 iPhone 代表页。

### 阶段 B：空/加载/失败/未配置状态原型

**决策（Q2，已定）**：按「状态类别 × 现实贴近度」收敛为 **4 必做 + 1 可选**，每类至少一页，优先已实现行为；删去最冗余/最不贴近的两页（见 §13 与 §20）。复用 `.empty-state` + 状态 pill；详情态优先独立文件避免污染 happy-path。

必做（4，覆盖全部 4 类）：
1. `iphone/entry-detail-generating.html`（**加载**）：生成学习材料加载中（静态定格：进度文案 + 取消入口）。对应**已实现**的生成/取消行为，misread 风险低。
2. `iphone/entry-detail-failed.html`（**失败**）：生成失败（失败文案 + 重试 + 「本地记录未受影响」三要素说明）。对应已实现取消/失败行为。
3. `iphone/settings-ai-provider-unconfigured.html`（**未配置**）：AI 未配置态（引导 + 能力为何不可用说明）。对应**已实现**的 provider 配置路径。
4. `iphone/record-empty.html`（**空 · 主入口**）：首启后时间线为空、引导「写下第一条记录」。这是新用户的真正前门，产品价值最高的空态；贴近首启闭环，对照 page-inventory 决定标注。

可选（1，第二个空态、强化定位）：
5. `iphone/memory-empty.html`（**空 · 次要**）：记忆库首次为空，强化「本地优先的个人语言记忆系统」定位（未实现行为 → 带「目标设计」标）。

删去 / 延后（见 §20 deferred 记录）：
- ~~`iphone/reading-empty.html`~~：与 record-empty 同属「空」类、组件相同，且阅读库未实现；冗余，删。
- ~~`iphone/settings-sync-states.html`~~：同步引擎未实现，画「同步失败」误读风险最高、贴近度最低；「未配置」类已由 AI provider 覆盖，延后到同步自身的设计轮次。

每页底部 `.proto-annotations` 写设计说明；按 page-inventory 决定是否带 `tag-target-design`（该类已存在于 `components.css`，无需新建）。

### 阶段 C：文档同步
1. `prototypes/index.html`：在对应平台分区登记新增页（含状态标）。
2. `prototypes/README.md`：如目录结构/维护规则受影响则同步。
3. 按 `docs/review/README.md` 判断是否需登记文档影响检查；如涉及 page-inventory 缺漏则补登记。

实施顺序：A → B → C（A 的密度结论可能影响 B 中 iPad/Mac 状态态画法；故 A 先行）。无 Phase 0 spike（纯静态、低不可逆性）。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-15（第一轮）+ 2026-06-15（第二轮，基于 as-built 代码）
审核方式：主会话自审核
审核轮次：双轮（第一轮架构落地性；第二轮以 ipad/mac workspace as-built 代码核验 Q1/Q2）
未使用隔离审查的原因：纯静态原型、不改生产代码、不可逆性低；按协议 §4 对低风险任务执行主会话审核并覆盖相关测试/落地项即可。

第一轮发现摘要：
  - P1：#5 多列句子卡可能损害阅读行长——已在「不做什么」与阶段 A 守门处理。
  - P1：新增失败/未配置原型可能被误读为实现已具备——已在约束 1 要求对照 page-inventory 决定「目标设计」标注。
  - P2：详情页加载/失败态若塞进现有 entry-detail.html 会破坏 happy-path 可读性——已决定用独立文件表达。
  - P2：密度策略散落各页难维护——已要求通用差异下沉 components.css 变体类。
  - P2：shared 改动波及 iPhone——已在验证命令加入三端回归截图。
  - P3：状态页文件命名——沿用现有 kebab-case + 状态后缀。

第二轮发现摘要（核验 as-built 代码）：
  - F-1（P2，真实矛盾）：守门 measure「≤ ~620px」比 as-built 阅读列（iPad 640px / mac 680px）更紧，会把现有刻意设计判为失败。已将守门改为「≤ ~75ch / ~700px」，并明确本轮不加宽阅读列。
  - F-2（支撑 Q1）：as-built 存在「单焦点当前句子」模型（`.sentence-card.current`/`.op-btn.playing` + inspector「当前句子」镜像），与多列网格结构冲突——多列由「候选」升级为「明确不做」。
  - F-3（P3）：`reading.html` 是长文正文而非句子卡，余量去向应为 TOC/生词 gutter 而非句子 inspector；阶段 A 已区分两类页面。
  - 已确认：`tag-target-design` 类已存在于 components.css 并在 index.html 使用，状态页标注无需新建组件（解除「§5 不发明新组件」隐忧）。

写回修改：上述均已写入第 4/5/8/12/16/20 节，非仅记录于本节。

需用户决策问题的推荐方案（架构师视角，待用户确认范围）：
  - Q1 大屏密度取向 —— 推荐：保持阅读列宽 + 富 inspector + 句子边注 gutter，**明确不做正文多列**。
    理由：产品是顺序式阅读/学习面（macOS 已定「不做 dashboard」）；逐句学习本质线性且依赖单焦点模型（F-2）；多列会损害第一轮确立的衬线阅读嗓音。横向余量投向 inspector 与边注，可在不动 measure 的前提下抬升密度。
  - Q2 状态页清单 —— 推荐：6 收敛为 4 必做 + 1 可选（每类一页，优先已实现行为），删 `reading-empty`（冗余空态、未实现面）与 `settings-sync-states`（同步引擎未实现，误读风险最高），并把最高价值的「首启时间线空态 record-empty」补为主空态。
    理由：原型是设计基准也是维护负债，每个投机性「目标设计」页都是 misread 风险 + shared-CSS 回归面；忠实证明 index.html 原则的最小集是「每类一页」，应优先贴近 shipped 行为的面，未建子系统（同步）的失败态延后到其自身设计轮次。

是否允许进入实现：否——当前 状态：Draft。Q1/Q2 已给出推荐决策并写回方案，待用户确认范围与授权（推进到 User Approved）后方可进入实现。
```

## 14. 复查方法

- 视觉：对每个改动/新增页跑 Playwright 截图，人工目检密度、状态表达、衬线/accent 一致性。
- 一致性：确认新增页登记进 `index.html`、与 README 视觉基准与设计原则一致。
- 故障路径覆盖：阶段 B 的失败/未配置态须含「为何不可用 + 如何恢复 + 本地数据是否受影响」三要素，不只裸红字。
- 回归：改 `components.css` 后复渲染 iPhone 代表页，确认未被波及。

## 15. TDD / 测试落点

```text
测试落点：不适用（纯静态 HTML/CSS 原型，无可执行单元测试目标）。
先失败用例：不适用。
聚焦验证命令：不适用。
不新增单元测试的原因：纯视觉原型，行为无法用 Swift 单元测试覆盖；验证依赖第 16 节 Playwright 截图人工目检 + check-docs。剩余风险见第 20 节。
```

## 16. 验证命令

```bash
# 1) 三端代表页 + 全部新增/改动页 Playwright 重渲染，确认零控制台错误（脚本沿用本会话 /tmp 截图流程）
#    覆盖：ipad/workspace, ipad/reading, mac/workspace, mac/reading 及阶段 B 所有新增页 + iPhone 回归页

# 2) 文档与卫生检查
scripts/check-docs.sh
git diff --check
git status --short
```

（不运行 `scripts/verify.sh`：本任务不涉及 Swift / 工程构建，按 CLAUDE.md §1.4 不主动跑全量验证。）

## 17. 文档影响检查

- 入口/ADR/architecture：不影响。
- spec：`docs/spec/003-ui-design-system.md` 的「状态有设计」约束被本任务正向兑现，原则上只读；如发现 spec 缺状态设计细则可在阶段 C 评估是否补充（需另确认）。
- platform-page-inventory：可能需补登记新增状态原型对应的目标设计条目（对照后决定）。
- testing/release/review：按 `docs/review/README.md` 判断；预期为日常文档影响检查级别，非专项审查。

## 18. 实施记录

（实现阶段按时间补充：实际改动、偏离原因、验证结果、提交哈希。）

## 19. 完成标准

- 阶段 A 4–5 个工作台页密度优化完成且 measure 守门通过；阶段 B 状态原型页全部新增并登记；阶段 C 文档同步完成。
- 全部页面 Playwright 重渲染零控制台错误；`scripts/check-docs.sh`、`git diff --check` 通过。
- 自审核「仍需用户确认的问题」已获答复并落实。
- 方案与产出对账无遗漏后，将本方案移入 `docs/plans/done/`。

## 20. 剩余风险

- 静态原型无法表达加载/失败的动态过渡，只能定格；真实交互手感仍需实现阶段验证。
- 「目标设计」标注依赖对 `platform-page-inventory.md` 的人工对照，存在误判已实现/未实现的风险。
- 大屏密度的「合适值」主观，最终以用户对阶段 A 截图的判断为准；可能需二次微调。
- 阶段 B 页数（4 必做 + 1 可选）以 §12 决策为准，仍可在用户确认后增减。

deferred 项记录：

```text
项目：reading-empty.html（资料库空态原型）
决策类型：deferred
原因：与 record-empty 同属「空」类、复用同一 .empty-state 组件，冗余；阅读库为未实现面。
影响：本轮「空」类由 record-empty（主）+ memory-empty（可选）覆盖，原则不缺类。
后续事实源或复审入口：阅读库闭环进入实现时，按需在对应任务方案补此空态。

项目：settings-sync-states.html（同步未配置/失败态原型）
决策类型：deferred
原因：同步引擎尚未实现，为不存在子系统画「同步失败」误读风险最高、贴近度最低；「未配置」类已由 AI provider 覆盖。
影响：本轮不输出同步状态原型；不影响 4 类状态的完整覆盖。
后续事实源或复审入口：同步引擎/Adapter 设计轮次（届时同步需自身设计 pass，状态态随之产出）。
```
