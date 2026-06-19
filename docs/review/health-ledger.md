# 文档健康趋势记录

状态：Accepted
创建日期：2026-05-25
最后更新日期：2026-06-15

本文档是 `docs/review/` 下的轻量趋势记录，吸收 VMark `house-cleaning/ledger.md` 的 append-only 思路。它不替代 review round、active plan、ADR、spec 或 architecture 文档。

## 1. 记录规则

- 只记录可机械采集、方向明确、能指导行动的少量指标。
- 不记录 raw LOC、总提交数、文档总数等难以直接指导行动的 vanity metrics。
- 每条记录必须包含日期、commit、trigger、metrics、verdict 和 notes。
- 同一问题连续三次出现且没有改善时，必须转为 active plan、review round 或显式接受风险。
- 转为 active plan 或 review round 时，应分配稳定 trigger id 或引用后续 finding id，并记录 trigger -> work item / review round 的对照。
- 每条发现都必须有 verdict，例如已修、转为 active plan、明确接受、延后原因或由某个 review round 承接。
- 语义问题仍进入 `docs/plans/active/` 或 `docs/review/rounds/`；本 ledger 只保存趋势和处置结论。
- 本 ledger 不是第二套 issue tracker；只保存趋势、触发条件和处置结果，不维护完整任务状态。

## 2. Ledger

| 日期 | Commit | Trigger | Metrics | Verdict | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-06-15 | `7f5e7cb` | 全量代码审查修复系列（15 个 Draft plan + chore 方案）Mac 验证门关闭 | active plans（非 idea）: 15；chore 方案状态：Done → 移入 done/；Mac 验证清单：Closed；SwiftLint error 级超限：0；SwiftFormat 漂移：0；CI 状态：全绿 | 验证门已关闭，15 个 Draft plan 可按顺序实施；idea 孵化区 3 份构想（01/02/03）后续按推荐顺序转 active plan | 代码快照 `7f5e7cb`；验证期追加 5 类修复（AVAudioSession API、continuation 竞态、@MainActor 隔离、SwiftLint 体量超限、swiftformat 漂移）；详情见 `docs/testing/2026-06-11-mac-verification-checklist.md §6` |
| 2026-05-25 | `36f45a074cb6b2f2abb33e0110853b9714060d0b` | 参考 VMark dev-docs 优化 docs 体系 baseline | active plans: 1；active plans older than 7 days: 0；Deferred / Superseded / Invalidated review rows: 0；placeholder scan hits: 0；tracked `.DS_Store`: 0 | 已建立 baseline | 本记录只作为趋势起点；本次实施由 `docs/plans/done/2026-05-25-docs-vmark-docs-system-optimization.md` 完成收口。 |
