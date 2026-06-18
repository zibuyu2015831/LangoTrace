# 批量自主执行 Playbook（active/ 剩余系列）

> 本文件存放在**仓库根目录**，是一份 **run 控制器 / 编排层执行手册**，不是 `docs/plans/` 下的代码实施方案、不是工作项、不是事实源。它只规定「一次 `/goal` 驱动的批量自主开发怎么编排」。
> 配套 `/goal` 指令：根目录 `BATCH-EXECUTION-GOAL.md`（用户复制其中指令到 Claude Code `/goal`）。

创建日期：2026-06-18
最后更新日期：2026-06-18（第 2 轮自审核：补规范遵从/文档反哺、分支基线新鲜度、每方案适用 spec 映射、git hooks 边界、deferred 方案存放位置）

## 0. 这份文档是什么

驱动一次 `/goal` 控制的**批量自主开发**：一次性把 `docs/plans/active/` 下**剩余的全部工作项方案**实现、验证、收口、移入 `docs/plans/done/`。

它**不替代任何权威文档**：

- 每份子方案的权威范围、TDD 落点、自审核记录 → 各子方案文件本身（`docs/plans/active/*.md`）。
- 系列推进指针与状态总表 → `docs/plans/active/2026-06-11-00-docs-series-progress.md`（下称「仪表盘 00」）。
- 验证真相（CI 跑没跑、绿没绿）→ 各 Phase 待验证清单 + `gh run` 记录。
- 流程纪律权威 → 根 `CLAUDE.md` / `docs/README.md`、`docs/plans/plan-review-protocol.md`、`docs/development/002-ci-and-branch-workflow.md`、`docs/spec/009-testing-and-verification.md`。
- **开发规范权威 → `docs/` 开发文档体系，尤其 `docs/spec/`**：`docs/` 是指导 AI 辅助编程的开发控制面，不是事后说明。`docs/spec/` 是项目开发规范，实现的代码必须符合相关 spec（导航、SwiftUI 架构、UI、AI Provider/隐私、数据存储/迁移/导出、权限、TTS、阅读/练习领域、国际化、测试等）。每份方案按 `docs/README.md` §5「按任务类型读取文档」加载其适用 spec（映射见本 Playbook §2 表后）。spec 不是一成不变的：实现中若发现更优设计，可更新对应 spec，并按 §4.6 把新规范/模式沉淀回 `docs/`，使文档与代码保持一致。

冲突时一律以上述权威文档为准；本 Playbook 只规定编排。

## 1. 用户确认记录（关键：满足核心决策 16 的实现前确认）

2026-06-18，用户通过结构化确认，对本 Playbook §2 列出的全部工作项方案给予**标准实现授权**，等价于核心决策 16 要求的「实现前用户确认」对每份子方案的前置授权：

1. **确认模式 = 完全预授权不停**：本 Playbook 与 `BATCH-EXECUTION-GOAL.md` 即对全部工作项方案的总授权。AI 连续实施，**不逐份停下等待确认**。任何疑问站在系统架构师角度，基于产品北极星、本地优先边界与各权威文档直接采取最优推荐方案，跑到第 8 节 stop 条件满足。
2. **分支与 main = 每方案独立分支 → 本地测试 → 本地 merge 进 `dev`（不走仓库 PR）→ 全程不动 `main`**。
3. **顺序与进度 = AI 自审后重排实施顺序**，进度复用仪表盘 00，不另起重复进度文档。

授权边界（即便「不停」也必须遵守）：

- **运行期隐私边界不被预授权覆盖**：核心决策 10「敏感内容只有用户明确触发对应 AI 能力时才发送 Provider」是运行期行为契约，实现中必须保留真实的运行期显式触发；预授权只授权「在 dev 阶段构建该功能」，不授权「默认自动外发」。
- **不预授权改动核心决策 / ADR**：若某份子方案自审核发现其实现会**反转**核心决策（`docs/README.md` §4）或某条 ADR，AI **必须暂停该方案**，在仪表盘 00 与该子方案记录冲突、证据、推荐处置，转去执行其他不冲突方案，并在本次 run 结束汇总时把该冲突单独列出等用户裁决。这是「不停」的唯一例外。
- **不动 `main`**：`main` 是受保护发布主干，本次 run 全程不合并、不推送 `main`。dev→main 发布由用户另起会话单独处理。

## 2. 范围：剩余工作项方案（9 份）

| 系列 | 方案文件（`docs/plans/active/`） | 主题 | 进入本次 run 时状态 |
|---|---|---|---|
| E6 | `2026-06-11-09-feature-ai-request-preview-and-log-foundation.md` | AI 请求预览 + 请求日志基础 | Draft |
| E5 Slice2 | `2026-06-11-08-feature-practice-backtranslation.md` | 回译练习「可选 AI 点评」（Slice1 已落地 CI 绿） | In Progress（Slice2 deferred，依赖 E6） |
| E7 | `2026-06-11-10-feature-memory-deposit-foundation.md` | 记忆沉淀基础 | Draft |
| E8 | `2026-06-11-11-feature-memory-review-queue.md` | 记忆复习队列 | Draft |
| E9 | `2026-06-11-12-feature-local-fts-search.md` | 本地 FTS 全文搜索 | Draft |
| E10 | `2026-06-11-13-feature-import-export-backup.md` | 导入导出与可恢复备份包 | Draft |
| E11 | `2026-06-11-14-feature-sync-engine-icloud-foundation.md` | 同步引擎 + iCloud 首通道 | Draft |
| E12 | `2026-06-11-15-feature-settings-status-projection.md` | 设置真实状态投影 | Draft |
| LM01 | `2026-06-15-01-feature-learner-model-boundary-and-ability-coverage.md` | 学习者模型边界 + Ability 覆盖 | Draft |

**编排层文件（不是工作项，不计入 stop 条件的「实现」要求）**：

- 根目录 `BATCH-EXECUTION-PLAYBOOK.md`（本文件）与 `BATCH-EXECUTION-GOAL.md`（run 控制器，存放在仓库根目录，不在 `active/`）。
- `docs/plans/active/2026-06-11-00-docs-series-progress.md`（仪表盘 00，进度指针，仍在 active/，系列收尾后移入 `done/`）。

**每份方案的适用规范（自审核与实现时必须加载并核验代码符合，起点，可被自审核补充）**：

| 方案 | 主要适用 spec / 权威（除通用 004 SwiftUI 架构、009 测试外） |
|---|---|
| E6 AI 请求预览+日志 | `spec/005-ai-provider-prompt-and-privacy`、`spec/008-permissions-local-privacy-and-diagnostics`、ADR-005 |
| E5 Slice2 回译 AI 点评 | `spec/013-practice-learning-domain`、`spec/005`（外发隐私边界） |
| E7 记忆沉淀基础 | `spec/007-data-storage-migration-export-and-attachments`、`spec/learning-content/impl`、ADR-004 |
| E8 记忆复习队列 | `spec/007`、`spec/013`、`spec/006-interface-localization-and-language-boundaries` |
| E9 本地 FTS | `spec/007`（FTS/索引章节）、`spec/learning-content/impl` |
| E10 导入导出/备份 | `spec/007`（导出/附件/备份）、`spec/008` |
| E11 同步引擎+iCloud | `spec/007`、ADR-005、`architecture/notes/`（同步备忘录，创建前必检）、核心决策 9/12/13 |
| E12 设置状态投影 | `spec/008`、`spec/002-navigation-and-routing`、`spec/010-apple-platform-interaction-and-accessibility`、`platform-page-inventory` |
| LM01 学习者模型边界 | `spec/012-reading-learning-domain`、`spec/013`、`spec/learning-content/impl`、ADR-004 |

## 3. 实施环境约束

- 本机 = **MacBook Air（被动散热）**：只做**轻量动作**——单个改动包 `swift test --package-path Packages/<X>`、`swiftformat --lint`/`swiftlint --no-cache` 自查、文档检查。**不在本机跑** `scripts/verify.sh` 全量、三端 `xcodebuild` 构建、跨多包测试。
- **重测试一律走 GitHub Actions**（`.github/workflows/ci.yml` 是 `verify.sh` 的远程镜像门禁，macOS runner）。
- **仓库 = public**（本次 run 期间保持 public，macOS CI 免费无上限）。run 结束可由用户设回 private。
- CI 触发：push 到 `dev` 仅当 commit message 含 `[ci]` 时跑（见 runbook §2）。本次 run 用「push dev 带 `[ci]`」触发远程验证，**不开 PR**。PR 总是触发 CI，但本次不走 PR。
- **本仓 git hooks 已生效**（`core.hooksPath = scripts/git-hooks`）：`pre-commit` 扫描暂存文件是否误提交密钥/凭证，`pre-push` 拦截直接推送 `main`。因此 E11/E10 等涉及对象存储密钥、加密密钥、Provider 凭证的实现**绝不能把敏感值写进受版本控制的文件**（必须走 Keychain 或等价安全存储，核心决策 9）；遇到 pre-commit 拦截应视为真实安全信号而非误报排查。

## 4. 每份方案的执行循环（核心工作流）

对第 7 节排定顺序中的每一份子方案，按以下闭环执行：

### 4.1 自审核（实现前，强制）

1. 读取入口：根 `CLAUDE.md`/`docs/README.md` → 目标子方案 → `docs/plans/README.md` → `docs/plans/plan-review-protocol.md` → 该方案引用的 ADR/spec/architecture/workflow + 相关代码路径。
2. **优先用子代理做隔离审查**（`docs/plans/plan-review-protocol.md` §9 的子代理 prompt）。可并行派发多份子代理审不同维度或不同方案。子代理**只读审查、不写生产代码**；主会话汇总、核验证据、写回。
3. 因为这些方案制定时的代码与当前实现已漂移，自审核**必须用当前代码/脚本/权威文档核验**方案自述，不接受过期假设。重点核对：上游契约是否还存在、下游消费点是否变了、schema/migration 版本号是否要顺延、引用的类型/seam 名是否仍在。
   - **同时按 §2 表加载该方案适用 spec，核对现有代码与方案设计是否符合规范**（命名、模块边界、SwiftUI 架构分层、AI 外发隐私边界、migration 规范、本地化 key 边界等）。若发现 spec 本身已落后于更优设计，按 §4.6 在实现阶段更新 spec 并记录理由；若发现代码已偏离 spec，在该方案记录为待修正项。
4. 输出按 P0/P1/P2/P3 分级，每条含：问题、证据、影响、建议修改、是否阻塞。
5. **把确认的问题、修订、TDD 落点、验证命令、剩余风险写回该子方案**；更新其 `状态`→`User Approved`（本 Playbook §1 已是该方案的用户授权）、`自审核状态`→`Reviewed`。
6. 自审核发现的「未来想法」不塞进本轮实施步骤：影响当前边界的写进该方案「非目标/剩余风险」；架构级跨任务提醒写 `docs/architecture/notes/`。

### 4.2 决策自主性（遇到疑问怎么办）

- 任何审核或实现中的疑问，**站在系统架构师角度**，基于产品北极星（用生活记录学习语言、本地优先、单人买断、Provider 抽象、SQLite/GRDB 主存储、向量/派生数据可重建不同步）、三端体验质量、长期架构清晰度、测试可维护性，**直接采取最优推荐方案**并在该方案实施记录中写明理由与被否决的备选。
- **唯一暂停例外**见 §1 授权边界第 2 条（反转核心决策/ADR）。
- **诚实 defer，不伪装完成**：若某方案自审核发现其依赖一个当前仍不存在的能力（真实 Provider 凭证安全存储、StoreKit、尚未落地的上游表/seam 等），且本次 run 内无法在不违反隐私/安全边界前提下补齐，则把该方案**部分实现到可验证边界**、把剩余项标为 deferred，在该方案与仪表盘 00 写清：项目、决策类型、原因、影响、后续事实源/复审入口（遵守 `docs/plans/README.md`「不得把 deferred 包装成完成」）。已落地部分仍走 §4.4 合并 dev + CI 绿，但**方案文件保留在 `docs/plans/active/`**（`状态` 用 `In Progress`，不移入 `done/`，因为未真正完成），其 deferred 段落明确剩余工作。然后继续下一份。

### 4.3 TDD 实现（按 Phase 小步推进）

0. **从当前最新 `dev` 切 feature 分支**：`git switch dev && git pull --ff-only && git switch -c feature/<topic>`（命名如 `feature/e7-memory-deposit`）。**关键边界**：因方案间有依赖且每份收口都会把改动累积进 `dev`，后一份方案的 feature 分支**必须基于已合入前序方案的最新 `dev`**（如 E5 Slice2 必须基于已并入 E6 的 dev、E8 基于已并入 E7 的 dev），否则会丢失上游 seam。
1. 按方案的 Phase 拆分；**每个 Phase 是一个最小可验证单元**。
2. 行为可自动化时**先写/改能失败的单元测试，再改生产代码**（测试靠近被测模块，放对应 `Packages/*/Tests`）。
3. 在该方案的 **feature 分支**上：每完成一个 Phase →
   - 本机**轻量验证**：只测改动到的包 `swift test --package-path Packages/<X>` + `swiftformat --lint`/`swiftlint --no-cache`；
   - **commit**（feature 分支过程提交**不带 `[ci]`**，commit message 标注系列与 Phase，如 `feat(data): … (E7 Phase 2)`）。
4. XcodeGen 相关（新增文件/target/migration）改动后，记得 `xcodegen generate` 纳入验证；新增 migration 必须顺延版本号并与现有 schema 校验。

### 4.4 收口该方案（重测试 + 合并 dev + 移 done）

1. 该方案全部 Phase 在 feature 分支完成、本机轻量验证通过后：
2. **本地 merge 进 `dev`**（不开 PR）：`git switch dev && git merge --no-ff feature/<topic>`。
3. **触发远程重测试**：`git push origin dev`，且本次推送的 commit（或合并提交）message 含 `[ci]`。
4. **用 `gh` 跟踪 CI 直到 `Build & Test` 通过**：`gh run list --branch dev --limit 3` → `gh run watch <id> --exit-status`。红了按 runbook §6 拿 `--log-failed`、在 dev 或临时 fix 分支修复、再推。
5. **CI 绿后**：更新该方案 `状态`→`Implemented`/`Verified`、写实施记录（commit、CI run id、验证命令与结果）；把方案文件 `git mv` 到 `docs/plans/done/`；删除该 feature 分支。
6. **同步仪表盘 00**：状态总表对应行改绿、推进「当前指针」到下一份、更新本 Playbook 第 9 节「当前 run 状态」。这一步的文档提交可与收口一起，message 视情况带不带 `[ci]`。

### 4.5 文档影响检查

每份方案收口前按 `docs/review/README.md` 做文档影响判断：数据库/AI Provider/权限/同步/StoreKit/启动闭环/包边界/验证脚本变化要触发专项审查或在方案中说明跳过原因；结论回写对应 spec/architecture/ADR/platform-page-inventory/impl map，不只留在 commit。

### 4.6 规范遵从与文档反哺（dev docs ↔ 代码一致性，强制）

`docs/` 是指导 AI 辅助编程的开发文档体系，必须随实现保持与代码一致；它是控制面，不是事后说明。每份方案在 §4.1 自审核、§4.3 实现、§4.4/§4.5 收口三处都要落实下面三条：

1. **代码符合 spec**：实现的生产代码必须符合 §2 表所列适用 `docs/spec/` 规范。Phase 内若引入与某 spec 冲突的写法，要么改代码对齐 spec，要么走第 2 条更新 spec，二者必居其一，不允许代码静默偏离规范。
2. **spec 可演进**：spec 不是一成不变的。实现中若发现更优设计（更清晰的边界、更安全的隐私路径、更可维护的分层），可更新对应 spec/impl map，并在该方案与 spec 变更处写明「为什么旧规范不再适用、新规范是什么、影响范围」；涉及核心决策或 ADR 的改动仍按 §1 授权边界暂停待裁决。
3. **主动沉淀**：实现中产生的、对后续开发有复用价值的新规范、模式、契约、边界提醒，要**主动写回 dev docs**而不是只留在代码或 commit：跨任务架构提醒 → `docs/architecture/notes/`；新的实现约束/领域规范 → 新增或更新 `docs/spec/*` 与对应 `impl.md`；新的 Prompt → `docs/prompts/`；页面/入口事实变化 → `platform-page-inventory.md`；高频高风险动作顺序 → `docs/workflows/`。目标是 run 结束后「文档记录与代码实际一致」，不留下只有代码知道、文档不知道的隐性规范。

## 5. 上下文与子代理管理

- **主动 compact**：单份方案收口后、或上下文接近膨胀时，主动压缩上下文，只保留「当前 run 状态 + 下一份方案入口」即可断点续传（所有续传所需事实都在仪表盘 00 + 本 Playbook §9 + 各方案文件磁盘上，不依赖聊天记忆）。
- **子代理用法**：自审核隔离审查、跨多文件搜索、并行审多份方案、独立验证某条证据，优先派子代理（`Explore`/`general-purpose`/`Plan`）。子代理结论必须经主会话核验后才写回权威文档。生产代码改动默认主会话执行（保持对 migration、seam、commit 边界的连续控制）。

## 6. 断点续传与进度记录

- **进度事实源 = 仪表盘 00**（状态总表 + 当前指针 + 各系列 Phase 子进度）。每次方案/Phase 推进**同步更新**它。
- **本次 run 的轻量游标 = 本 Playbook §9**（当前在跑哪份、哪个 Phase、最后 commit、最后 CI run、排定顺序）。
- 不新建第三份进度文档。新会话续传 = 读 `docs/README.md` → 根 `BATCH-EXECUTION-PLAYBOOK.md` → 仪表盘 00 §当前指针 → 目标方案。

## 7. 实施顺序（AI 自审后重排，下为依赖推导起点）

进入 run 后，AI 在首轮自审核阶段基于真实依赖确认/调整顺序，并在 §9 记录最终顺序与重排理由。依赖推导起点（可被自审核推翻）：

```
E6 ─→ E5 Slice2        （E5 可选 AI 点评依赖 E6 的请求预览/日志基础）
E6 ─→ E12              （设置状态投影需 AI 请求/日志状态作为数据源）
E7 ─→ E8               （记忆复习队列消费记忆沉淀产出）
E9                      （本地 FTS：依赖已存在的 Entry/learning content 表，相对独立，可早做）
E10 ─→ E11             （同步引擎建立在稳定数据模型/可导出快照之上；import/export 先于 sync）
E11, E10 ─→ E12        （设置投影展示同步/AI/导出真实状态，宜靠后）
LM01                    （学习者模型边界：相对基础，但 Draft；顺序由自审核依赖判定）
```

建议起步顺序（自审核后定稿）：**E6 → E5 Slice2 → E9 → E7 → E8 → E10 → E11 → LM01 → E12**。E12（设置真实状态投影）依赖最多子系统已落地，放最后；LM01 视其与 E7/E8 记忆模型的耦合程度，可前移到 E7 之前或保持其后。

## 8. 完成标准（stop 条件，描述状态而非动作）

本次 `/goal` run 的**可验证终止状态**：

> 第 2 节列出的 **9 份工作项方案全部满足**：实现完成 → 该方案 CI（`Build & Test` on `dev`）跑绿 → `状态` 推进到 `Implemented`/`Verified` 且实施记录含 commit + CI run id → 方案文件已移入 `docs/plans/done/`；仪表盘 00 状态总表对应 9 行全部标绿、当前指针指向「系列收尾」；`docs/plans/active/` 中**不再存在「可在本 run 内完成却未完成」的工作项方案**——剩下的至多是：仪表盘 00（随后移入 `done/`），以及因 §4.2 诚实 defer 或 §1 核心决策冲突而**合法留存**的方案（`状态` 为 `In Progress` 且 deferred/冲突段落齐全，不算「全绿」但有据可查）。根目录的 `BATCH-EXECUTION-PLAYBOOK.md` 与 `BATCH-EXECUTION-GOAL.md` 是 run 控制器，收尾后由用户决定保留或归档。
>
> 若存在因 §4.2 诚实 defer 或 §1 核心决策冲突而**未能完成**的方案：该方案不计入「全绿」，但其 deferred/冲突项必须在仪表盘 00 与该方案中**有明确记录和后续入口**；本次 run 在「其余可完成方案全部收口 + 所有未完成项均有据可查的 defer 记录」时视为达到终止状态，并在最终汇总里向用户列出待裁决项。

这是一个**状态**，可被布尔判定（active/ 是否还有工作项、9 行是否全绿、done/ 是否就位、deferred 是否有记录），不是「resume」这类动作，符合 `/goal` 停止条件应描述状态的要求。

## 9. 当前 run 状态（每次推进同步更新）

- 排定顺序（自审核后定稿）：**E6 → E5 Slice2 → E9 → E7 → E8 → E10 → E11 → LM01 → E12**（采纳 §7 建议顺序；E6 解锁 E5 Slice2 与 E12 的 AI 状态源；E9 相对独立可早做；E7→E8 记忆链；E10→E11 导出先于同步；E12 依赖最多子系统放最后）。每份方案进入前的隔离自审核可微调其后续顺序，调整记入本节。
- 当前方案：**E7**（`docs/plans/active/2026-06-11-10-feature-memory-deposit-foundation.md`）— 记忆沉淀基础，实现前隔离自审核已完成（见该方案「批量 run 实现前隔离自审核」段），状态 User Approved，待实现
- 当前 Phase：E7 实现前（E6 + E5 Slice2 + E9 已收口）
- 最后 commit：`de222e2`（E9 CI fix on dev）
- 最后 CI run：`27742853935`（E9 Build & Test success on dev）
- 已收口（移入 done/）：**E6**（CI `27738605916`）、**E5（Slice1+Slice2）**（CI `27741263024`）、**E9**（CI `27742853935`）
- deferred / 待裁决项：_无_
- 关键漂移基线：最新 migration = **v25**；下一新表从 **v26** 起。E7 记忆表 = **v26_create_memory_item_infrastructure**（sibling 文件放 helper，AppDatabase.swift 已近 file_length 1300 上限）。
- E7 自审核结论（隔离子代理，2026-06-18）：无 P0 架构阻塞，无核心决策/ADR 反转（memory_items 是主数据，spec 007 §3.1 + ADR-004；决策 12 仅约束向量索引）。关键修订：①v26；②候选 5 kind→deposit kind 显式映射(word/phrase→wordPhrase、sentencePattern→sentence、grammarPoint/errorPattern 显式定)；③新 Core 类型命名 DepositedMemoryItem/MemoryRecord 避免 MemoryItem 跨包 rename；④reading 来源沉淀需幂等键或 defer；⑤memory_items 须含 E8 review 列（review_state/review_rung/review_due_at/last_reviewed_at/review_count/mastered_at）；建议 Phase A（Core+Data+repo+v26）先 CI 绿即解锁 E8 + E9 记忆搜索组。

> 维护约定：本节是 run 级游标，只记「跑到哪、下一步从哪继续」；详细决策、验证结果、TDD 落点写回各子方案与仪表盘 00。

## 10. 完成前检查（每份方案收口 + 整批结束时）

```bash
# 文档一致性
scripts/check-docs.sh
git diff --check
git status --short
# 残留待办扫描（排除模板/示例/idea）
rg "TO""DO|TB""D|待补充|稍后完善|以后再写|待定" docs --glob '!plans/examples/*' --glob '!spec/examples/*' --glob '!**/idea/**'
# 远程重验证（push dev 带 [ci] 后）
gh run list --branch dev --limit 3
gh run watch <id> --exit-status
```

整批结束时确认：`docs/plans/active/` 不再有工作项方案；仪表盘状态总表与各方案 `状态` 字段一致；所有 deferred/冲突项有据可查。
