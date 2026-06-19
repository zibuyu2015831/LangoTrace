# 项目级审查一致性检查

状态：Verified

## 1. 跨报告一致性

- AUDIT-ARCH-001 与 AUDIT-INFRA-001 指向同一 Sync 基础设施缺口：前者关注测试门禁，后者关注 domain model 与 UI mock 的长期边界。
- AUDIT-DOC-001、AUDIT-DOC-002 与 AUDIT-DOC-003 指向同一项目状态漂移：README、技术路线和测试清单都落后于 spec / 页面清单 / 代码事实。
- AUDIT-ARCH-003 与页面清单的“语言空间管理三端 Implemented”存在张力：生命周期 action 已接通，但内容 store 是否随空间切换仍未被证明。
- AUDIT-ARCH-004 与 `AUDIT-TEST-001` 的关系：前者是具体 AI 请求取消 bug，后者是验证门禁未覆盖这类取消语义的体系缺口。

## 2. 术语、路径和状态一致性

- `Implemented / Local Mock / Unavailable` 在 `docs/platform-page-inventory.md` 中定义清楚；本轮三端矩阵沿用该语义，并在报告内映射为计划要求的状态值。
- `docs/README.md` 中“真实数据 / 真实 AI / 真实语音之前”与 `docs/spec/007`、`docs/spec/011`、页面清单当前状态不一致。
- `docs/testing/README.md` 中本地听读预览 / 内存 repository 口径与页面清单当前 GRDB / TTS 播放事实不一致。

## 3. 验证命令一致性

- `scripts/verify.sh` 覆盖 Core / Data / AI / Speech / UI package tests 和 macOS AppTests，但不覆盖 Sync package，也不覆盖 `Tests/Tooling/test_probe_openai_compatible_api.py`。
- 计划中的 `find docs -maxdepth 3 -type f | sort` 会列出 ignored `docs/.DS_Store`；后续收口应在剩余风险或命令改进建议中处理。
- 本轮 `scripts/verify.sh` 退出码 0；SwiftLint warnings 不阻断，需在后续门禁治理中明确策略。

## 4. 决策关系一致性

- 尚未发现代码直接违反核心 ADR；当前问题主要是测试 / 文档状态漂移和 Sync 前置边界不足。
- AUDIT-ARCH-003 涉及 ADR-004 语言空间核心模型的实现隔离，但当前证据显示的是 UI state binding 风险，不是 ADR 本身错误。
- AUDIT-ARCH-004 涉及 ADR-005 下用户自带 Provider 和显式触发边界；当前证据显示取消语义未闭合，不是 ADR 本身错误。
