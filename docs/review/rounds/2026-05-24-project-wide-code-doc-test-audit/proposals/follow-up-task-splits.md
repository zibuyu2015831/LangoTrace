# 后续任务拆分

状态：Verified

## 1. 当前候选任务

| 来源问题 | 类型 | 推荐文件 | 范围 |
| --- | --- | --- | --- |
| AUDIT-ARCH-004 | `bug` | `docs/plans/active/YYYY-MM-DD-bug-learning-material-cancel-provider-request.md` | 先写失败测试证明取消会终止实际 provider request；修复 generate / analyze 的 task cancellation、diagnostic cancelled mapping 和 late result 状态保护。 |
| AUDIT-ARCH-003 | `bug` | `docs/plans/active/YYYY-MM-DD-bug-learning-content-store-language-space-switch.md` | 先写失败测试证明切换 `languageSpace.id` 后 content store 重建或换绑；修复三端共享 store 的空间隔离、运行中 operation 取消和 playback observation 清理。 |
| AUDIT-ARCH-001 / AUDIT-INFRA-001 | `chore` 或 `refactor` | `docs/plans/active/YYYY-MM-DD-chore-sync-package-test-boundary.md` | 增加 `LangoTraceSyncTests`、Sync minimal domain contracts、`scripts/verify.sh` Sync test gate，并引用同步 architecture note。 |
| AUDIT-ARCH-002 | `chore` | `docs/plans/active/YYYY-MM-DD-chore-app-environment-integration-tests.md` | 补 App target integration tests，覆盖 `AppEnvironment.bootstrap()` 的 repository / action / disabled service / Settings scene 注入边界。 |
| AUDIT-TEST-001 | `chore` | `docs/plans/active/YYYY-MM-DD-chore-verification-gate-coverage.md` | 把 Sync package、Python tooling tests 和 SwiftLint warning 策略纳入统一验证门禁或测试文档。 |
| AUDIT-DOC-001 / AUDIT-DOC-002 / AUDIT-DOC-003 | `docs` | `docs/plans/active/YYYY-MM-DD-docs-project-status-and-roadmap-alignment.md` | 用户确认后统一 `docs/README.md`、`docs/technical-framework-roadmap.md` 与 `docs/testing/README.md` 的当前状态口径。 |

## 2. 暂不拆分的事项

- 三端截图、VoiceOver、Dynamic Type、Stage Manager、真机和真实 Provider 人工验证：本轮先继续收集缺口，最终再决定是否拆成一个 testing / QA plan。
- `find docs` 命中 ignored `.DS_Store` 与 package `.swiftpm/xcode/xcuserdata` 噪音：先记录在一致性检查；若最终确认会反复污染审查命令，再并入文档 / 脚本治理任务。
