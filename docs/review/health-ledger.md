# 文档健康趋势记录

状态：Accepted
创建日期：2026-05-25
最后更新日期：2026-05-25

本文档是 `docs/review/` 下的轻量趋势记录，吸收 VMark `house-cleaning/ledger.md` 的 append-only 思路。它不替代 review round、active plan、ADR、spec 或 architecture 文档。

## 1. 记录规则

- 只记录可机械采集、方向明确、能指导行动的少量指标。
- 不记录 raw LOC、总提交数、文档总数等难以直接指导行动的 vanity metrics。
- 每条记录必须包含日期、commit、trigger、metrics、verdict 和 notes。
- 同一问题连续三次出现且没有改善时，必须转为 active plan、review round 或显式接受风险。
- 语义问题仍进入 `docs/plans/active/` 或 `docs/review/rounds/`；本 ledger 只保存趋势和处置结论。

## 2. Ledger

| 日期 | Commit | Trigger | Metrics | Verdict | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-05-25 | `36f45a074cb6b2f2abb33e0110853b9714060d0b` | 参考 VMark dev-docs 优化 docs 体系 baseline | active plans: 1；active plans older than 7 days: 0；Deferred / Superseded / Invalidated review rows: 0；placeholder scan hits: 0；tracked `.DS_Store`: 0 | 已建立 baseline | 本记录只作为趋势起点；本次实施由 `docs/plans/done/2026-05-25-docs-vmark-docs-system-optimization.md` 完成收口。 |
