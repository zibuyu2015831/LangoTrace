# 任务方案：全面代码审查修复与新版原型开发方案系列

状态：User Approved
自审核状态：Not Reviewed
类型：chore
创建日期：2026-06-11
最后更新日期：2026-06-11

## 用户确认记录

2026-06-11 用户明确授权本任务，原文要点：

1. 严格审查现有代码，发现架构、设计、代码问题立即修复并记录。
2. 根据新版原型图，在 `docs/plans/active/` 制定一系列详细、按顺序实施的方案文档，作为后续开发依据。
3. 遇到疑问时站在系统架构师角度，基于项目定位和愿景充分思考后采取最优方案。
4. 每完成一个阶段需检查、测试和 commit。
5. 实施过程保留进度记录，支持中断后恢复。

授权范围：代码问题修复（含必要测试）、本方案及系列开发方案文档的创建。系列方案文档本身创建后仍为 `Draft`，进入实现前仍需逐个走自审核与用户确认链路（本任务只负责"制定方案"，不实施系列方案）。

## 1. 需求或 bug 描述

前序任务已完成三端原型重做（`prototypes/iphone|ipad|mac/`）和 spec 修订（003 / 010 / 013 等）。需要：

1. 对现有 Swift 代码（App + 六个 Package + 工程配置 + 脚本）做一次严格审查，修复确认的问题。
2. 基于新版原型图与修订后规范，产出按顺序实施的开发方案系列，覆盖从当前实现到原型所示产品形态的差距。

## 2. 现状描述

- 代码：App Shell、语言空间 GRDB 持久化、learning content 主路径、AI/TTS Provider 配置、逐句 TTS 播放、单句跟读录音闭环已存在；完整时间线、阅读视图、听写、回译、记忆、搜索、同步、StoreKit 未实现。
- 原型：新版三端原型已覆盖 iPhone 19 页、iPad 5 页、Mac 7 页，包含大量未实现能力（reading、memory、dictation、backtranslation、photo-writing、search、import-export、sync 设置等）。
- `docs/plans/active/` 存量 4 份旧方案（2 份 2026-05-26 bug、2 份 2026-06-06），需要在系列规划中确认其去留。
- 仓库根目录存在被 Git 跟踪的 `build_output.txt`、`build_output_mac.txt`、`docs-system-improvement-plan.md`，疑似不应入库或位置不当。

## 3. 目标

1. 完成一轮覆盖全部 Package、App target、project.yml、scripts 的严格代码审查，输出 P0–P3 分级发现。
2. P0 / P1 发现全部修复或给出明确暂缓决策记录；P2 / P3 修复或写入系列方案 / architecture notes。
3. 产出一组按依赖顺序排列的 `docs/plans/active/` 开发方案文档（Draft），每份符合模板必填项。
4. 每阶段独立 commit；本方案"实施记录"持续更新，支持中断恢复。

## 4. 范围

- 只读审查：`LangoTraceApp/`、`LangoTraceAppTests/`、`Packages/*`、`project.yml`、`scripts/`、`Tests/`。
- 可修改：确认问题对应的代码与测试、本方案、新增系列方案文档、必要的文档同步（platform-page-inventory、specs 受影响处）。
- 修复遵循 TDD：行为可自动化验证的问题先写失败测试。

## 5. 不做什么

- 不实施系列方案中的新功能（时间线、阅读、听写、回译、记忆、搜索、同步、StoreKit 等）。
- 不跑 `scripts/verify.sh` 全量验证（环境无 macOS / Xcode；见剩余风险）。
- 不删除或改写历史文档记录。
- 不重写原型。

## 6. 证据与决策依据

- 用户 2026-06-11 授权（见用户确认记录）。
- CLAUDE.md 第 1.1 / 1.2 节早期重构原则：允许指出并推翻明显问题设计。
- `docs/plans/README.md`、`docs/plans/plan-review-protocol.md`：方案模板与自审核门禁。
- 审查证据：见第 18 节实施记录中各阶段发现清单。
- 已核实初始证据：`git ls-files` 确认 `build_output.txt`、`build_output_mac.txt`、`docs-system-improvement-plan.md` 被跟踪。

## 7. 约束映射与验证路径

### 约束 1：TDD 与测试落点

- 来源：CLAUDE.md 第 1.4 节、`docs/spec/009-testing-and-verification.md`
- 适用范围：本任务全部代码修复
- 严重度：blocker
- 执行或验证方式：单元测试 + `swift test --package-path Packages/<target>`
- 验证提示：每个行为修复先有失败测试，再有最小修复。

### 约束 2：轻量验证优先

- 来源：CLAUDE.md 第 1.4 节第 6、7 条
- 适用范围：验证命令选择
- 严重度：warn
- 执行或验证方式：仅运行受影响 Package 的 `swift test`；不主动运行 `scripts/verify.sh`。

### 约束 3：方案文档模板与自审核

- 来源：`docs/plans/README.md` 第 3 节、`docs/plans/plan-review-protocol.md`
- 适用范围：本方案与系列方案文档
- 严重度：blocker
- 执行或验证方式：人工对照模板必填项；`scripts/check-docs.sh`。

### 约束 4：提交纪律

- 来源：用户偏好记录（不使用 `git add -A`；分阶段提交）
- 适用范围：全部 commit
- 严重度：blocker
- 执行或验证方式：逐文件 `git add`；每阶段一个 commit。

## 8. 涉及的代码文件路径

待审查后确定，见第 18 节实施记录。预计候选：`.gitignore`、被跟踪的 build_output 文件、审查发现的 Package 源码与测试。

## 9. 参考的代码文件路径

`LangoTraceApp/`、`Packages/*/Sources`、`Packages/*/Tests`、`project.yml`、`scripts/`。

## 10. 涉及的文档路径

- 本方案。
- 新增：`docs/plans/active/2026-06-11-*` 系列方案文档。
- 可能更新：`docs/platform-page-inventory.md`、`docs/architecture/notes/`、存量 4 份 active 方案的状态标注。

## 11. bug 分析

非 bug 任务，不适用（审查发现的具体 bug 在第 18 节按条记录根因与置信度，重大者单独立案）。

## 12. 实施方案

- 阶段 0：创建本方案并 commit（进度锚点）。
- 阶段 1：并行隔离审查。子代理分组：A=Core+Data，B=AI+Speech+Sync，C=UI，D=App+工程配置+scripts+仓库卫生，E=原型/规范/存量方案差距图谱。输出 P0–P3 发现。
- 阶段 2：主会话核验发现，逐条确认/驳回；将确认发现写回本方案；完成本方案自审核；按 TDD 修复，跑受影响 Package 测试，按主题分组 commit。
- 阶段 3：基于 E 的差距图谱与修复后代码基线，制定系列方案文档（Draft + 自审核记录），commit。
- 阶段 4：文档影响检查、`scripts/check-docs.sh`、收尾 commit，更新本方案实施记录。

## 13. 严格方案自审核记录

```text
审核日期：2026-06-11
审核方式：隔离审查（阶段 1 的五个只读子代理审查即本方案的隔离审查输入）+ 主会话自审核
审核轮次：双轮（第一轮架构边界 / 第二轮测试与落地性）
未使用隔离审查的原因：不适用
发现摘要：见第 18 节阶段 1 记录
写回修改：见第 18 节
仍需用户确认的问题：系列方案文档为 Draft，逐个实施前仍需用户确认
是否允许进入实现：阶段 2 修复在发现核验与写回后进入
```

（阶段 1 完成后回填，回填前自审核状态保持 Not Reviewed。）

## 14. 复查方法

- 代码修复：对应 Package `swift test` 全绿；修复点有回归测试。
- 系列方案：对照模板必填项逐份检查；阅读顺序与依赖关系自洽；与 ADR / spec 无冲突。
- 文档：`scripts/check-docs.sh` 通过；占位符扫描通过。

## 15. TDD / 测试落点

```text
测试落点：按发现归属 Package 决定，写入第 18 节各修复条目
先失败用例：每条行为修复在实施记录中写明测试名与预期失败原因
聚焦验证命令：swift test --package-path Packages/<受影响 target>
不新增单元测试的原因（如适用）：纯文档 / 仓库卫生（如移除 build_output）类修复无行为变化
```

## 16. 验证命令

```bash
# 聚焦（按受影响 Package）
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI
swift test --package-path Packages/LangoTraceSpeech
swift test --package-path Packages/LangoTraceSync
swift test --package-path Packages/LangoTraceUI

# 文档
scripts/check-docs.sh
rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'
git diff --check
git status --short
```

## 17. 文档影响检查

- 系列方案创建会新增 `docs/plans/active/` 条目：是。
- 代码修复若改变页面/能力事实：同步 `docs/platform-page-inventory.md`。
- 若推翻核心决策：需新增/更新 ADR（预计无；如有，先停下记录并请求确认）。
- 审查若发现文档体系结构性问题：按 `docs/review/README.md` 汇报。

## 18. 实施记录

- 2026-06-11 阶段 0：创建本方案，commit（见下方提交记录）。
- （后续阶段在此追加。）

## 19. 完成标准

1. 阶段 1 审查发现全部有"修复 / 列入系列方案 / 记录暂缓"三态之一的归宿。
2. 受影响 Package 测试全绿（在当前环境可运行的范围内）。
3. 系列方案文档全部创建且通过模板检查与自审核。
4. 每阶段有独立 commit；本方案实施记录完整。

## 20. 剩余风险

- 当前环境为 Linux，无法运行 xcodebuild / 模拟器构建与 swiftlint / swiftformat；`swift test` 可运行性待阶段 1 确认。若 Swift 工具链不可用，代码修复的验证降级为静态审查 + 在方案中记录待 macOS 环境补跑的命令清单。
- 系列方案基于原型推断的能力边界可能与用户预期有偏差，逐份实施前的用户确认是兜底。
