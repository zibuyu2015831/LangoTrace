# 项目级代码、文档与测试审查

审查类型：项目级复杂审查
日期：2026-05-24
代码快照：0c57e030dca477b1854df41e21d470176a020191
状态：Verified
当前事实源：本轮 `reports/`、`consistency_check.md` 和 `proposals/`
后续覆盖记录：`docs/plans/done/2026-05-24-bug-learning-content-store-language-space-switch.md`、`docs/plans/done/2026-05-24-bug-learning-material-cancel-provider-request.md`、`docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md`
可作为依据：Yes

## 1. 触发原因

用户要求完整阅读 `docs/plans/active/2026-05-24-chore-project-wide-code-doc-test-audit.md`，并根据该方案对项目展开深入审核。

本轮不是功能实现或修复任务。审查目标是从长期付费 Apple 三端 App、文档驱动开发、隐私安全和基础设施长期可扩展的角度，找出当前代码、文档、测试和三端同步中的结构性问题。

## 2. 审查范围

- 工程结构、XcodeGen、验证脚本、package 边界和 App 启动装配。
- Core / Data / AI / Speech / Sync / UI package 的模型、协议、repository、service、store、test target 和 production seam。
- iPhone、iPad、macOS 三端入口、页面状态、设置能力、学习材料、练习、记忆、AI Provider、TTS、同步、本地数据、隐私和导入导出。
- `docs/README.md`、主参考文档、技术路线、页面清单、architecture、ADR、spec、testing、review、active / done plans。
- Swift package tests、App target tests、工具脚本 tests、`scripts/verify.sh`、手动验证和截图验证清单。

## 3. 相关源码、脚本和配置

详见 `_meta.md` 的已读文档、已读代码和命令记录。核心抽样入口包括：

- `project.yml`
- `scripts/verify.sh`
- `LangoTraceApp/`
- `LangoTraceAppTests/`
- `Packages/LangoTraceCore/`
- `Packages/LangoTraceData/`
- `Packages/LangoTraceAI/`
- `Packages/LangoTraceSpeech/`
- `Packages/LangoTraceSync/`
- `Packages/LangoTraceUI/`
- `Tests/`

## 4. 结论摘要

本轮未发现 P0 问题。已记录 P1 / P2 问题 9 项：

- P1：学习材料生成 / 分析取消没有终止实际 Provider 请求，见 `AUDIT-ARCH-004`。
- P1：语言空间切换后 `LearningContentStore` 可能保持旧 `spaceID`，见 `AUDIT-ARCH-003`。
- P1：Sync package 已进入工程图但无测试 target，且不在统一验证脚本中，见 `AUDIT-ARCH-001`。
- P1：App 层集成测试覆盖面过窄，见 `AUDIT-ARCH-002`。
- P1：README 当前状态新旧事实混杂，见 `AUDIT-DOC-001`。
- P1：技术路线 Phase 0 进度滞后于代码和 spec，见 `AUDIT-DOC-002`。
- P2：Sync mock UI 早于 Sync domain model 冻结，见 `AUDIT-INFRA-001`。
- P2：统一验证脚本门禁不完整，见 `AUDIT-TEST-001`。
- P2：测试手动验证清单仍按早期 mock 口径描述记录和逐句听读，见 `AUDIT-DOC-003`。

## 5. 问题清单

问题详情以各报告为准：

- `reports/01-architecture-and-serious-bugs.md`
- `reports/02-platform-parity.md`
- `reports/03-docs-code-conformance.md`
- `reports/04-test-system-coverage.md`
- `reports/05-infrastructure-readiness.md`
- `reports/06-deep-recheck-of-findings.md`

## 6. 文档修改记录

- 2026-05-24：创建本复杂 review round 骨架，并将 `docs/review/INDEX.md` 追加为 `In Progress`。
- 2026-05-24：完成项目级深审，更新五份报告、一致性检查、整改路线、后续任务拆分和两个 P1 bug active plan。
- 2026-05-24：按用户要求对审查结果做深度复查，新增 `reports/06-deep-recheck-of-findings.md`，并收紧学习材料取消 bug 方案中的 cancellation mapping 表述。
- 2026-05-24：按用户要求完成发现项修复：学习材料取消传播、语言空间 store identity、Sync test target、AppEnvironment bootstrap tests、统一验证脚本和状态文档均已收口到 done plan。

## 7. 用户澄清

暂无。需要用户判断的产品或架构取舍会写入 `questions/`，不会伪装成长期事实。

## 8. 延后项和原因

- 未执行截图、真机、VoiceOver、Dynamic Type、Stage Manager 验证；本轮结论主要来自代码、文档、测试和构建证据，不证明发布级视觉 / 可访问性质量。
- 未执行真实外部 Provider、真实同步、真实 StoreKit 或 App Store 操作；本轮只确认代码和文档中这些能力的接线状态。
- 未修改生产代码、核心 spec、ADR、产品主参考或技术路线；需用户确认后通过后续 active plan 承接。

## 9. 验证命令与结果

审查启动基线：

- `git status --short`：仅显示 `?? docs/plans/active/2026-05-24-chore-project-wide-code-doc-test-audit.md`。
- `git rev-parse HEAD`：`0c57e030dca477b1854df41e21d470176a020191`。

其余验证命令见 `_meta.md` 和 `evidence/command-logs/`。

本轮关键验证结果：

- `swift test --package-path Packages/LangoTraceCore`：通过，76 tests。
- `swift test --package-path Packages/LangoTraceData`：通过，77 tests。
- `swift test --package-path Packages/LangoTraceAI`：通过，74 tests。
- `swift test --package-path Packages/LangoTraceSpeech`：通过，13 tests。
- `swift test --package-path Packages/LangoTraceUI`：通过，216 tests。
- `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`：通过，2 tests。
- `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`：通过，6 tests。
- `swift test --package-path Packages/LangoTraceSync`：源码编译完成后失败，`no tests found`。
- `scripts/verify.sh`：退出码 0；SwiftLint 输出 140 warnings、0 serious；SwiftFormat 0 files require formatting。

修复后验证结果：

- `swift test --package-path Packages/LangoTraceUI --filter LearningContentStoreCancellationTests`：通过，2 tests。
- `swift test --package-path Packages/LangoTraceUI --filter LanguageSpaceContentStoreBindingTests`：通过。
- `swift test --package-path Packages/LangoTraceData --filter operationSummariesKeepCancelledAsTerminalStatus`：通过。
- `swift test --package-path Packages/LangoTraceSync`：通过，1 test。
- `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`：通过，6 tests。
- `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`：通过，4 tests。
- `scripts/verify.sh`：通过，退出码 0；SwiftLint 输出 144 warnings、0 serious；SwiftFormat 0 files require formatting。

## 10. 剩余风险

- `AUDIT-INFRA-001` 只完成了 Sync test target 和验证入口的基础修复；真实 Sync domain model、adapter、manifest、tombstone 和 conflict model 仍必须在真实同步前另建方案。
- SwiftLint warning 仍存在，当前门禁口径是 0 serious；warning 基线和逐步收敛策略仍是后续测试治理项。
- 手动截图、真机、辅助功能、真实 Provider、真实同步和 StoreKit 验证未执行。
