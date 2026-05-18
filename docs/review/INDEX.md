# 文档审查索引

本文档是所有文档审查轮次的长期索引。单轮细节放在 `docs/review/rounds/<round-id>/` 中。

## 最新状态摘要

- 最近审查轮次：`2026-05-18-development-doc-system-audit`。
- 最近完成时间：2026-05-18。
- 待用户澄清的问题数：0。
- 延后项：0。

## 轮次索引

| 轮次 ID | 类型 | 启动时间 | 完成时间 | 状态 | 链接 |
| --- | --- | --- | --- | --- | --- |
| `2026-05-18-development-doc-system-audit` | 专项审查 | 2026-05-18 | 2026-05-18 | Verified | [README](rounds/2026-05-18-development-doc-system-audit/README.md) |
| `2026-05-17-string-catalog-interface-language-settings` | 专项审查 | 2026-05-17 | 2026-05-17 | Verified | [README](rounds/2026-05-17-string-catalog-interface-language-settings/README.md) |
| `2026-05-17-interface-localization-foundation` | 专项审查 | 2026-05-17 | 2026-05-17 | Verified | [README](rounds/2026-05-17-interface-localization-foundation/README.md) |

## 重审触发日志

| 日期 | 触发原因 | 触发的轮次 | 涉及文档 |
| --- | --- | --- | --- |
| 2026-05-18 | 用户要求基于项目定位、Apple 三端愿景和 Apple 相关 skill 审核开发文档体系，重点深审 `docs/spec/` | `2026-05-18-development-doc-system-audit` | `docs/README.md`、`docs/spec/`、`docs/product-main-reference.md`、`docs/technical-framework-roadmap.md`、`docs/review/README.md` |
| 2026-05-17 | String Catalog、App shell locale 注入、设置入口和 package resources 变更 | `2026-05-17-string-catalog-interface-language-settings` | `docs/spec/006-interface-localization-and-language-boundaries.md`、`docs/testing/README.md`、`docs/archive/superpowers/plans/2026-05-17-string-catalog-interface-language-settings.md` |
| 2026-05-17 | `scripts/verify.sh` 增加 Data package 测试 | `2026-05-17-interface-localization-foundation` | `scripts/verify.sh`、`docs/README.md`、`docs/testing/README.md` |

## 长期健康度追踪

| 轮次 | 问题数 | 代码问题记录数 | 新会话可用抽样 |
| --- | --- | --- | --- |
| `2026-05-18-development-doc-system-audit` | 8 个问题，均已修复为长期文档或实现地图 | 0 | 通过：spec 入口、数据 / 权限 / 测试规范、实现地图和阅读路径均已写回 |
| `2026-05-17-string-catalog-interface-language-settings` | 0 个阻断问题，3 个延后项 | 0 | 通过：验证命令、String Catalog 边界和视觉记录风险均已写入单轮记录 |
| `2026-05-17-interface-localization-foundation` | 0 | 0 | 通过：入口文档、验证脚本和测试文档均能指向当前验证方式 |
