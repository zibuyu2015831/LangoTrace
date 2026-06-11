# 任务方案：全面代码审查修复与新版原型开发方案系列

状态：Implemented - Pending Mac Verification
自审核状态：Reviewed
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
审核方式：隔离审查（阶段 1 的七个只读子代理审查即本方案的隔离审查输入）+ 主会话自审核
审核轮次：双轮（第一轮架构边界 / 第二轮测试与落地性）
未使用隔离审查的原因：不适用
发现摘要：共产出约 110 条 P0–P3 发现（2 条 P0、14 条 P1），见附录 A
写回修改：阶段调整为两波修复（包内并行 + 跨包顺序）；用户中途补充三条指令（Linux 无法测试改为
  静态修复 + Mac 清单、逐条记录现状/原因/修复方案、归档 4 份旧 active 方案）已并入范围
仍需用户确认的问题：系列方案文档为 Draft，逐个实施前仍需用户确认；E10 练习录音导出默认值冲突、
  E0b 中 APP-12 welcome 跳过行为等已在对应方案中标注待确认
是否允许进入实现：阶段 2/3 已按用户授权执行；Mac 验证后收口
```

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

环境约束：本机为 Linux，无 Swift 工具链。经用户确认，全部 Swift 修复为静态修复（全文阅读 + 调用点 grep + 括号配平 + xcstrings JSON 校验），需在 Mac 上运行的命令与人工检查统一登记到 [Mac 待验证清单](../../testing/2026-06-11-mac-verification-checklist.md)。

- 2026-06-11 阶段 0：创建本方案。commit `68da21e`。
- 2026-06-11 阶段 1：七个只读子代理并行审查（A=Core、B=Data、C=AI、D=Speech/Sync/App/工程配置/scripts/仓库卫生、E1=UI store/model 层、E2=UI view 层、F=原型差距图谱），全部源文件全文阅读，产出约 110 条 P0–P3 发现与系列方案建议。发现与处置全表见附录 A。
- 2026-06-11 阶段 1.5（用户指令插入）：归档 `docs/plans/active/` 存量 4 份旧方案到 `docs/archive/plans/`（带归档说明）；修复 verify.sh P0（管道吞错、非法 lint 参数、heartbeat 残留）；同步 docs/README.md 第 10 节展开；移除被跟踪的 `build_output*.txt`、归档根目录 `docs-system-improvement-plan.md`、补 `.gitignore`。commits `71bfc01`、`bb3e30b`（阶段 1.5 一次批量 git add 因失效 pathspec 中止导致部分文件漏入 `71bfc01`，由 `bb3e30b` 如实补提交）。
- 2026-06-11 阶段 2 第一波：五个修复子代理按包并行实施（互不触碰对方文件），逐条修复 + 先失败测试。commits：Core `a9fc73e`、Data `0675371`、AI `0a27bc4`、Speech/App/工程 `f1bb891`、UI `c1b7947`。
- 2026-06-11 阶段 2 第二波（跨包顺序实施）：隐私状态文案 Core→UI 本地化下沉（含纠正"请求预览"过度承诺）、启动恢复失败 Welcome 浮出 + 重试、RootView init 全局副作用移除、操作摘要 1970 epoch 时间戳清除。commit `274b7db`。
- 2026-06-11 阶段 3：三个子代理并行撰写系列方案 15 份（E0a/E0b/E1/E2/R1/E3–E12，含双轮自审核记录，状态 Draft），主会话修正跨引用并通过 `scripts/check-docs.sh`。commit `a2b1be3`。
- 2026-06-11 阶段 4：创建 [Mac 待验证清单](../../testing/2026-06-11-mac-verification-checklist.md)，回填本方案自审核记录、实施记录与附录 A，文档检查收口。

偏离方案的记录：

```text
项目：阶段 2 中对大型重构类发现（AI-09、APP-08、UIV-20、CORE-13 等）不做即时修复
决策类型：deferred
原因：无编译器环境下大范围结构调整风险过高；且按 CLAUDE.md §1.1 重要重做应有独立方案与用户确认
影响：相关债务仍在代码中，但已全部固化为系列方案 E0a/E0b 的工作项
后续事实源或复审入口：docs/plans/active/2026-06-11-01-refactor-architecture-foundations.md、
  docs/plans/active/2026-06-11-02-refactor-ui-architecture-debt.md
```

```text
项目：全部 Swift 测试与三端构建验证
决策类型：deferred
原因：Linux 环境无 Swift 工具链（用户已确认该约束）
影响：所有代码修复未经编译验证
后续事实源或复审入口：docs/testing/2026-06-11-mac-verification-checklist.md
```

## 19. 完成标准

1. 阶段 1 审查发现全部有"修复 / 列入系列方案 / 记录暂缓"三态之一的归宿。
2. 受影响 Package 测试全绿（在当前环境可运行的范围内）。
3. 系列方案文档全部创建且通过模板检查与自审核。
4. 每阶段有独立 commit；本方案实施记录完整。

## 20. 剩余风险

- 当前环境为 Linux，全部 Swift 修复未经编译与测试运行，存在编译失败或行为偏差风险；以 [Mac 待验证清单](../../testing/2026-06-11-mac-verification-checklist.md) 为兜底，重点风险点已在清单第 2 节列出。
- 系列方案基于原型推断的能力边界可能与用户预期有偏差，逐份实施前的用户确认是兜底。
- DATA-09 把媒体缓存命中校验从"尺寸 + 哈希"放宽为"尺寸"（commit 时哈希仍校验），同尺寸内容损坏在 lookup 阶段不再被检出，属性能与完整性的已接受折衷。
- 阶段 2 新增的非 en/zh 六种语言翻译为本次撰写，建议后续人工复核。
- CORE-01 修复使带 providerParameters 的既有 TTS 缓存键一次性失效（重新生成一次音频）；AI-17 的 Prompt v4 升级不会使解释缓存失效（缓存键不含 promptVersion），旧缓存仍返回 v3 时期结果。

## 附录 A：审查发现与修复记录

记录格式：每条含现状（修复前）、原因/根因、修复方案；测试落点与 Mac 验证项分别见各 commit 与 [Mac 待验证清单](../../testing/2026-06-11-mac-verification-checklist.md)。

### A.1 P0（commit `71bfc01` + `bb3e30b`）

**SCRIPT-01 verify.sh 吞掉构建失败**
- 现状：`run_with_heartbeat` 用 `"$@" | grep ... || true` 包裹 xcodebuild，`|| true` 抵消整条管道（含主命令）退出码，四个构建/测试门禁失败时脚本照样输出 Verification Successful。
- 原因：为容忍 grep 无匹配返回 1 而加的 `|| true` 误伤主命令退出码。
- 修复：grep 局部豁免（`{ grep ... || true; }`），用 `PIPESTATUS[0]` 取主命令状态并在非零时退出；heartbeat 进程加 trap 清理（SCRIPT-04）。

**SCRIPT-02 非法 lint 参数**
- 现状：`swiftlint --cache`（不存在的选项）与 `swiftformat --cache use`（会在仓库根写出名为 `use` 的杂散文件）。
- 原因：参数误写且无人完整跑过该脚本（被 SCRIPT-01 掩盖）。
- 修复：改回 `swiftlint --no-cache`、`swiftformat --cache ignore`；同步更新 docs/README.md 第 10 节展开（SCRIPT-03）。

### A.2 仓库卫生（commit `71bfc01`）

**HYGIENE-01**：540KB + 514KB 的一次性 xcodebuild 日志 `build_output*.txt` 被 Git 跟踪（含宿主机绝对路径）→ `git rm` 并加 `.gitignore` 规则。
**HYGIENE-02**：2026-05-18 文档重整的已完成"临时权威"`docs-system-improvement-plan.md` 仍在仓库根误导新会话 → 移入 `docs/archive/`。
**旧方案归档**（用户决定）：4 份 active 方案移入 `docs/archive/plans/` 带归档说明；遗留人工验证项并入 Mac 清单第 5 节，仍有效内容由 R1 方案吸收。

### A.3 LangoTraceCore（commit `a9fc73e`）

**CORE-01 TTS 缓存键跨进程不稳定（P1）**
- 现状：coordinator 对 `voice.providerParameters` 字典用 `String(describing:)` 做 SHA-256，字典序受每进程随机 hash seed 影响，多 key 配置每次启动缓存键漂移，重复向付费 TTS Provider 发请求。
- 原因：已有的排序键规范化序列化是 `TTSVoiceProfile` 的 private 成员，coordinator 无法复用。
- 修复：规范化序列化提升为公开 API `TTSProviderParameterValue.canonicalSerialization(of:)`（输出与原实现逐字符一致，fingerprint 不变），coordinator 改用它。

**CORE-02 播放状态跨记录串台（P1）**
- 现状：播放状态与观察者按 `SentenceAudioRequestSummary`（仅空间/句序/语言/长度桶）索引，不同记录同句序的句子共享 UI 播放状态。
- 原因：summary 丢弃了 `sentenceSource`（其 payload 全为 ID，非敏感）。
- 修复：summary 增加 `sentenceSource` 字段（带默认值，外部构造方兼容），`nonSensitiveSummary` 填入真实来源。

**CORE-03 CRLF 文档解析为单行/单段（P1）**
- 现状：markdown 按 Character `"\n"` 切分、段落按 `text[i] == "\n"` 比较；Swift 中 `"\r\n"` 是单一字素，Windows 来源文档整篇不分行/不分段。
- 原因：按 Character 比较无法命中 CRLF 与孤立 CR。
- 修复：两处引入 `isLineBreak` 谓词（匹配 `\n`/`\r\n`/`\r`），保持 range 指向原始输入（保护 Data 层偏移计算），未重写字符串。

**CORE-05 生成异常卡死 + 取消空实现（P2）**：生成/提交抛错时状态停留 `.generating`、`.cancelGeneration` 是空 `break` → 生成任务持有 `Task` 句柄真正取消；do/catch 把错误收敛为 `.failed(分类)`，取消静默归位。
**CORE-12 token 估算遗漏假名/谚文（P2）**：`isCJK` 区段缺 U+3040–30FF、U+FF66–FF9D、U+AC00–D7AF，日/韩文本 token 低估约 4 倍、超长闸门失效 → 补区段。
**CORE-17（P3）**：`". hello"` 被空前缀 `allSatisfy` 空真误判为有序列表 → 加非空守卫。
**CORE-18（P3）**：`-0.0` 格式化为 `"-0.000000"` 导致相等 key 哈希不同 → 归一化为 +0.0。
**CORE-19（P3）**：时长回退纳秒换算对损坏的超大 duration 溢出 trap → clamp 到 86400 秒。
**CORE-21a（P3）**：`LearningLanguage.find(code:)` 只查 native 列表却被用于解析目标语言 → 改为 native∪target 并集查找。
**CORE-23a（P3）**：系统语言 `zh`/`zh-CN`（无 script）匹配不到 `zh-Hans`，简中用户界面回落英文 → 增加裸 `zh` 前缀映射（显式繁体仍回落英文，不擅自映射简体）。

### A.4 LangoTraceData（commit `0675371`）

**DATA-01 保存 Provider 配置摧毁 TTS 缓存元数据（P1）**
- 现状：`saveProfile` DELETE+重插 endpoints，FK CASCADE 连删 `tts_audio_artifacts` 扩展行，`media_artifacts` 主行成永久活跃孤儿；部分唯一索引阻塞同 key 重建，最坏时该句 TTS 永久报错。
- 原因：endpoint 替换式写入未处理依赖它的派生媒体主行；清理也不识别无扩展行的孤儿。
- 修复：同事务内删 endpoints 前按 JOIN 反查将受影响主行置 `invalidated_at`；清理把"无扩展行的活跃主行"视为可清理孤儿。

**DATA-02 练习录音 RESTRICT 外键毒化清理/回滚（P1）**
- 现状：清理候选只排除"已完成 session 的录音"，被任何 `practice_recordings` 行引用的 artifact 先删文件、批量删元数据时被 RESTRICT 整批打爆；commit 失败回滚同样必撞 FK。
- 原因：候选 SQL 条件过窄；批量 `DELETE IN (...)` 一错全毁；reservation 事务已插 recording 行。
- 修复：候选排除被任何 recordings 行引用的 artifact；`deleteArtifactMetadata` 改逐 id（先删 pending recording 行再删主行，单条约束错误只跳过该 id）。

**DATA-03 FK PRAGMA 事务内 no-op（P2）**：init 与 v10 migration 内的 `PRAGMA foreign_keys` 都在事务里（SQLite 规定无效），外部传入的 DatabaseQueue 实际全程无外键 → init 改 `writeWithoutTransaction`；v10 删除死 PRAGMA。
**DATA-04 先写后校验（P2）**：bridge `updateEntryBody` 写完才比对 spaceID，跨空间报错但已写入 → spaceID 下沉到事务内 WHERE/前置校验。
**DATA-06 纪元混用（P2）**：解释缓存表用 2001 纪元、其余表全用 Unix 纪元 → 新 migration v15 清空该派生缓存表并切换 `timeIntervalSince1970`。
**DATA-07 取消后仍落库（P2）**：操作已 `cancelled` 后 `saveGeneratedMaterial` 仍插材料并翻转 `is_current` → 事务开头检查同 operationID 状态，已取消则抛 `operationCancelled` 跳过插入。
**DATA-09 每次命中全量读盘哈希（P2）**：`fileInfo` 每次整文件读入 + SHA256，逐句播放 IO/CPU 翻倍 → 新增 `fileByteSize` 轻量校验，命中/播放走尺寸校验，哈希保留在写入/commit 时。
**DATA-10 清理并发三处风险（P2）**：候选不排除 in-flight pending 行、staging 无条件清空、`markArtifactFileReady` 0 行也静默成功 → pending 1 小时保护窗、staging 按修改时间 1 小时保护、markReady 检查 `changesCount` 失败即抛错。
**DATA-11（P3）**：阅读库业务错误伪装 `DatabaseError(message:)` → 新增 `ReadingLibraryRepositoryError` 类型化枚举。
**DATA-15（P3）**：`event.endpointID ?? ""` 使 probe 结果 UPDATE 静默 no-op → guard 缺失即抛 `missingEndpointID`。
**DATA-16（P3）**：多仓库直接 `Date()` 绕过注入时钟约定 → 统一加 defaulted `clock` 参数。
**DATA-19（P3）**：LIKE 不转义 `%`/`_`、集合/标签归一化不 trim、软删行被复用且不复活 → `ESCAPE` + 转义、trim 后归一化、复用时清 `deleted_at`。
**DATA-20a（P3）**：路径包含检查 `hasPrefix(root)` 缺尾部分隔符（防御深度缺口）→ 锚定 `root + "/"`。

### A.5 LangoTraceAI（commit `0a27bc4`）

**AI-01 非法枚举静默纠偏（P1）**
- 现状：模型返回的非法 `category`/`kind`/`difficulty` 被 `?? 默认值` 替换写入 GRDB，违反 spec 005 §4.7 与 Prompt Registry 的"非法枚举必须拒绝"。
- 原因：解析层 `Enum(rawValue:) ?? default` 写法把校验失败当可恢复默认。
- 修复：四处全部 guard-throw `invalidStructuredResponse`。

**AI-02（P2）**：JSON 解析"首 `{` 到末 `}`"截取接受任意自然语言包裹，超出文档契约 → 改为 code fence 剥离 + 整串解析（与 reading 服务一致）。
**AI-03（P2）**：无数组数量/字符串长度上限校验 → 按 Registry 文档已声明限值实现（sentences 1–20、memory ≤12、practice ≤6 等），超限拒绝。
**AI-04/AI-20（P2）**：非 2xx 一律 `providerRejected`、各服务 status 映射分裂 → 共享 `AIProviderHTTPStatusErrorMapper`（401/403/404/429），四个服务统一接入；Core 枚举缺口（LMGS 无 rateLimited、Reading 无 timeout/auth 类）记入 E0a。
**AI-05（P2）**：Responses API 解析只取 `output.first`，reasoning 模型"配置测试通过但真实功能坏" → 共享 `OpenAICompatibleResponseTextParser` 迭代过滤 `output_text`。
**AI-06（P2）**：probe 与 TTS 请求不应用 `requestTimeoutSeconds` → probe 设置 `timeoutInterval`；TTS 请求输入新增 defaulted timeout 字段并透传。
**AI-07（P2）**：三套 baseURL 拼接实现行为分歧（测试 vs 真实请求 URL 不同）→ 共享 `AIProviderEndpointURLBuilder`（URLComponents + 后缀去重），五处统一。
**AI-08（P2）**：语言样本 120 词/140 字上限把啰嗦但合格的样本误判 `sampleTooShort` → 移除上限（无合适的 tooLong reason case）。
**AI-10（P2）**：`? .failed : .failed` 无效三目 → 简化并加行为固定测试。
**AI-13（P2）**：TTS 凭证/存储错误被 `catch { return textResult }` 吞掉伪装成"未启用" → 仿 embedding 路径映射为显式 failed 能力结果。
**AI-14a（P2）**：`voiceProfile.speed` 参与 fingerprint 但请求体不序列化 → 序列化并 clamp 0.25–4.0。
**AI-17（P3）**：选区文本行内插值进 Prompt，换行可伪造字段 → 六个用户内容字段用 `<<<FIELD>>>...<<<END_FIELD>>>` 分隔符包裹，Prompt 升级 v4，Registry 文档同步。
**AI-18（P3）**：耗时只取整秒，亚秒请求恒为 0 → seconds*1000 + attoseconds 换算。
**AI-19c（P3）**：`.sharedWithPurpose` 凭证解析依赖端点数组顺序，失败时静默保存无凭证端点 → 两段式解析，解析失败抛 `missingRequiredAPIKey`。

### A.6 Speech / App / 工程配置（commit `f1bb891`）

**SPEECH-01（P1）**：`completeAfterPlaybackDuration` 锁外读写 `fallbackTask`（类为 `@unchecked Sendable`）数据竞争 → 持锁交换任务句柄。
**APP-01（P1）**：`recorder.stop()` 之后才读 `currentTime`（stop 后归零），所有真实录音持久化时长恒为 0、时长闸门失效 → stop 前捕获时长；去重双份 SHA256。
**APP-03（P1）**：macOS 沙箱开启但缺 `com.apple.security.network.client`，签名构建下 AI/TTS 出站请求全部被拒 → 补 entitlement + 守护测试。
**TEST-01（P1）**：App 测试调用真实 `bootstrap()` 向用户真实 Application Support 数据库写入且不清理 → `bootstrap(databaseURL:)` 注入点，测试走唯一临时目录并清理。
**SPEECH-03/04（P2）**：试听播放器字典只增不删（叠音 + 泄漏）、preview store 无限驻留 → 重放前停旧播放器 + 按时长调度清理；store 默认仅保留最近 1 条并提供删除 API。
**SPEECH-05/06/07（P2/P3）**：超限 stop 不删暂存文件、validator 只信调用方声明的 byteSize、play() 不停旧播放器 → 协议新增 `discardStagedRecording`（默认空实现）抛错前清理；FileManager 核对落盘尺寸；play 开头先 stop。
**APP-10（P2）**：iOS 播放从不配置 AVAudioSession（默认 `.soloAmbient` 被静音拨片静音）→ 播放引擎 iOS 路径设 `.playback`/`.spokenAudio` 并激活（试听服务未覆盖，列入后续小修）。
**APP-04/05/06/07（P2）**：console 诊断 logger 无条件挂载违反 spec 008 默认关闭、`@Entry appEnvironment` 默认值执行完整生产 bootstrap 且零读取方、重复的 coordinator 工厂闭包无消费者、bootstrap `try?` 三处静默降级 → 仅 `LANGOTRACE_DIAGNOSTICS=1` 挂 console；删除死 environment key 与重复字段；降级路径记录诊断事件。
**APP-11/14（P3）**：stop 用字符串拼接重建相对路径、魔法字符串 `"bootstrap"` spaceID → 保留 start request 回传原路径；命名常量。
**TEST-03（P2）**：启动状态机零测试 → 新增 `AppSessionStateTests`（restore 成败、completeWelcome 三态、删除最后空间 fallback）。
**SPEECH-08/09（P3）**：测试 fixture 重复、testTarget 缺显式 Core 依赖 → 共享 `WAVTestFixtures`；补显式依赖。
**PROJ-01/02/03（P3）**：无用 AppIntents 依赖、版本号硬编码与 build settings 分叉、iOS scheme 空测试配置 → 删除依赖；plist 接 `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`；删空 test 块。需 Mac `xcodegen generate`。

### A.7 LangoTraceUI（commit `c1b7947`）

**UIS-01 双触发杀死生成状态（P1）**
- 现状：生成运行中再次触发时 guard 分支把 `.generating` 覆盖为 `.blocked`，首次操作完成守卫失败 → 结果丢弃、运行表泄漏、cancel 可产生幻影"已取消"，UI 与 GRDB 失同步。
- 原因：blocked 信号写穿了 in-flight 显示状态；完成所有权检查依赖显示状态。
- 修复：blocked 只记诊断不改状态；完成守卫改用 `runningOperationsByEntryID` 的 operationID。

**UIS-02 观察任务保活泄漏（P1）**
- 现状：`[weak self]` 在无限 `for await` 外被一次性升级为强引用，coordinator 流永不结束 → 切换语言空间后旧 store 永不释放、deinit 清理不可达。
- 原因：弱引用升级位置错误。
- 修复：逐事件短暂强持有（`guard let self` 移入循环体），挂起期间仅弱引用。

**UIV-01 iPad 侧栏不可滚动（P1）**：固定 VStack 装时间线/筛选/路由按钮，4–5 条记录后溢出 → ScrollView + LazyVStack，footer 固定滚动区外。
**UIV-02 可保存同语言空间（P1）**：改母语后 target Picker 选中值非法、Save 无校验 → onChange 归一化（镜像 onboarding）+ native==target 时禁用保存。
**UIV-04 搜索框异步绑定（P1）**：Binding set 丢进异步 Task，事实源滞后破坏中文 IME 组字，且每键击全量 reload → 同步写 `searchText` + store 内 250ms 防抖 reload。
**UIS-03/12（P2/P3）**：保存失败后"测试请求"打到旧存档配置、`.missingRequiredFields` 补全字段后状态卡死 → `hasUnsavedEdits` 标志驱动 probe 源；状态机补转移。
**UIS-04/08（P2）**：过期任务完成回调把新请求 `.loading` 打回 `.idle`、缓存回填无文档守卫 → stale 分支直接 return；await 前捕获文档身份、写前校验。
**UIS-14/21（P3）**：降级投影显示 "3 / 1"、`updateLearningText` 绕过 in-flight 注册 → totalCount 取 max；运行表守卫。
**UIS-18（P3）**：测试文件遗留 AI 生成自言自语注释 → 删除。
**UIV-06 静默丢失用户输入（P2）**：三端创建记录/阅读导入失败被 `try?` 吞掉且编辑器无条件 dismiss → 失败显示本地化错误行、保留草稿、成功才关闭。
**UIV-10/11/29（P2/P3）**：hero 副标题三段拼接不可翻译、文档编辑 sheet 借用语言空间标题且显示 rawValue、无空间边界借用同步文案 → 各自专用插值/独立 key（8 语言）。
**UIV-12/13/14/21（P2）**：关闭按钮无辅助标签 + 28pt 命中区、Provider 输入框无可访问名、练习卡片截断大字号 + 辅助标签丢信息 + 裸 "!"、四处控件 <44pt → 44pt 命中区 + accessibilityLabel + 移除 maxHeight + InlineStatusLabel + 完整插值标签。
**UIV-15/16/22（P2）**：ForEach 行内 `.id(updatedAt)` 覆盖身份、主列表非懒加载、阅读首页双大标题 → 删除 id hack（Equatable 正确无需强刷）；LazyVStack；删自绘标题。
**UIV-19（P2）**：TTS `.failed`/`.requiresConfiguration` 渲染与 idle 完全相同 → 独立图标 + 本地化提示。
**UIV-26/27/18（P3/P2）**：阅读动画忽略 Reduce Motion、散落原始颜色、Welcome 固定 46/64pt 字号 → 环境值接入；LangoTraceDesign token（新增平台高亮色 helper）；typography token + `@ScaledMetric`。
**UIV-30（P3）**：缺语言空间 `preconditionFailure` 崩溃、Mac 浮层背景点击丢非空草稿 → 渲染边界视图；草稿非空时忽略背景点击。
**死代码删除**（grep 零生产引用）：AudioPanel、PracticeContinuePanel/PracticeTaskRow、PhoneSheet.unavailable + PhoneUnavailableAction、PracticeSessionStep 展示扩展、ReadingDocumentStore.playAudio()、AIProviderDraftConfiguration mock 测试路径。`ReadingLibraryStore.replaceLanguageSpace` 保留（疑似预留接缝，E0b 复核）。

### A.8 跨包第二波（commit `274b7db`）

**CORE-07 + CORE-14 + UIV-03 + UIV-09 隐私状态文案（P1/P2）**
- 现状：Core 硬编码中文 title/value/summary 且 `.configured` 虚假承诺"AI 请求会在发送前显示请求预览"（实际为非阻塞确认、无预览）；iPad/macOS footer 的 tooltip/VoiceOver 全是中文；辅助标签用全角标点字符串拼接；`PhoneRootTab.title` 为死代码。
- 原因：展示字符串误放 Core 语义层；文案写于"请求预览"尚在规划期。
- 修复：Core 只留语义（case/severity/systemImage）；UI 层 26 个本地化键投影（8 语言），文案改为不过度承诺；tooltip/辅助标签走插值键；删除死属性与对应测试。

**APP-02 启动恢复失败卡死（P1）**
- 现状：数据库打开/迁移失败时 `recoveryState = .failed`，`completeWelcome` 静默 return，UI 无任何错误展示或重试入口——用户表现为"点继续没反应"。
- 原因：恢复状态从未传入 RootView；草稿校验失败还误写恢复失败。
- 修复：RootView 新增失败面板（本地化标题/说明/重试按钮）+ 重试闭包；草稿校验与存储失败分离。

**UIS-16/UIV-24（P3）**：RootView init 内全局副作用（语言 resolver）且与 onAppear/onChange 三处重复 → 移到 App init 一次性执行（覆盖 Settings scene 独立出现的首帧），RootView 仅保留 onAppear/onChange。
**CORE-11（P2）**：`failed`/`cancelled` 操作摘要工厂硬编码 1970 epoch `createdAt` 落库 → createdAt 改必填参数，全部调用方传真实时间；凭证元数据 epoch 默认值一并移除。

### A.9 暂缓项处置全表

以下发现确认真实但本轮不修，全部固化为系列方案工作项（无静默丢弃）：

| 发现 | 去向 |
| --- | --- |
| AI-09 文本 Provider adapter 抽象；AI-15/16 preset 常量与错误分类补全；AI-11 响应上限流式化；AI-12 macOS Keychain dlopen 现代化；AI-21 Keychain 伪测试；DATA-05 bridge 读路径吞错（需 Core 诊断事件名）；CORE-06/08/09/10/15/20/22/24/25；DATA-12/13/17/18/21/22/23；SPEECH-02 WAV chunk walker；spec 012 Prompt v3→v4 同步 | `2026-06-11-01-refactor-architecture-foundations.md`（E0a） |
| UIV-05 每 tab 独立 NavigationStack；UIV-07 嵌套 ScrollView；APP-08/UIV-20 编排下沉；UIS-05/APP-13 阅读 TTS 失败可表达；UIS-06 isPlayingDemo；UIS-07/UIV-17/DATA-14 Data 层中文状态串本地化；UIS-09 影子缓存；UIS-15 LocalizedChrome 机制债务；UIS-19/TEST-02 源码子串断言退坡；APP-09 启动同步 IO；APP-12 welcome 跳过（需用户决策）；UIV-25/28/31/32/33 视觉尾项 | `2026-06-11-02-refactor-ui-architecture-debt.md`（E0b） |
| UIV-08 footer/学习面板硬编码状态接真实投影 | `2026-06-11-15-feature-settings-status-projection.md`（E12） |
| DATA-08 阅读 import 不建结构表 / rebuildStructure 占位句 | `2026-06-11-05-feature-reading-experience-completion.md`（R1） |
| CORE-04 UTF-16 与字素单位混用（与 CORE-15 整数偏移统一处理） | E0a |
| CORE-16 / AI-23 / UIS-20 测试覆盖缺口 | 本轮已随各修复补齐对应用例；剩余项随 E0a/E0b 落点 |
| SYNC-01 占位 target 套套逻辑测试 | `2026-06-11-14-feature-sync-engine-icloud-foundation.md`（E11）落地时替换 |
| HYGIENE-03 根目录 untracked `img/`、`.github/` 归属 | 留待用户决定（未触碰） |
| SCRIPT-05/06/07 capture-runtime-log stream 分支、probe 明文回显（已有测试锁定的已知决策）、生成脚本路径假设 | 低风险，随下次 scripts 任务处理；已在此登记 |
