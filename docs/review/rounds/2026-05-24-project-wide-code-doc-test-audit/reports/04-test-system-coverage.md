# 04 测试体系完整性审查

状态：Verified

## 1. 审查目标

判断测试体系是否覆盖项目当前已实现功能点，并识别自动化测试、手动验证、截图验证、权限验证、真实 Provider 验证和发布前验证的缺口。

## 2. 测试覆盖矩阵

| 测试面 | 当前证据 | 状态 | 缺口 |
| --- | --- | --- | --- |
| Core package | `swift test --package-path Packages/LangoTraceCore` 通过，76 tests | Implemented | 暂未发现缺口。 |
| Data package | `swift test --package-path Packages/LangoTraceData` 通过，77 tests | Implemented | 仍需继续抽查 export / future sync coverage 是否只在 docs 中。 |
| AI package | `swift test --package-path Packages/LangoTraceAI` 通过，74 tests | Implemented | 真实外部 Provider 人工验证不由单元测试证明。 |
| Speech package | `swift test --package-path Packages/LangoTraceSpeech` 通过，13 tests | Implemented | 真机 / 系统播放体验未由本轮证明。 |
| UI package | `swift test --package-path Packages/LangoTraceUI` 通过，216 tests | Implemented | 截图、Dynamic Type、VoiceOver、Stage Manager 未由本轮证明。 |
| Sync package | `Packages/LangoTraceSync/Package.swift` 无 test target；`scripts/verify.sh` 未运行 Sync；直接运行 `swift test --package-path Packages/LangoTraceSync` 编译后以 `no tests found` 退出 | Not Wired | 见 AUDIT-ARCH-001。 |
| App target integration | `xcodebuild test ... LangoTraceAppTests` 通过，2 tests | Partially Implemented | 见 AUDIT-ARCH-002。 |
| Tooling tests | `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py` 通过，6 tests | Implemented | 尚未进入 `scripts/verify.sh`。 |
| Full verification script | `scripts/verify.sh` 退出码 0，完成 XcodeGen、package tests、iPhone / iPad / macOS build、SwiftLint、SwiftFormat 和 docs 占位扫描 | Partially Implemented | 不覆盖 Sync package 和 Python tooling tests；SwiftLint 140 warnings 不阻断。 |

## 3. 问题清单

已记录：

- AUDIT-ARCH-003：语言空间切换与 `LearningContentStore` 绑定缺少 root-level 回归测试。
- AUDIT-ARCH-004：学习材料取消缺少“实际 provider request 被取消”的回归测试。
- AUDIT-ARCH-001：Sync package 缺 test target 且不在统一验证脚本中运行。
- AUDIT-ARCH-002：App 层集成测试覆盖面过窄。

### AUDIT-TEST-001

问题 ID：AUDIT-TEST-001
严重度：P2
标题：统一验证脚本通过但门禁不完整，Sync 和 Python tooling 测试未进入日常验证
问题现状：`scripts/verify.sh` 本轮完整运行退出码为 0，但脚本未执行 `swift test --package-path Packages/LangoTraceSync`，也未执行 `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`。此外 SwiftLint 输出 `Found 140 violations, 0 serious`，在当前配置下 warning 不阻断验证。
证据：`scripts/verify.sh:8-16` 只运行 Core / Data / AI / Speech / UI package tests 和 macOS AppTests；本轮直接运行 Python tooling tests 通过 6 tests；本轮直接运行 Sync package test 编译后以 `no tests found` 失败；完整 `scripts/verify.sh` 退出码 0 并输出 140 SwiftLint warnings。
影响范围：统一验证脚本、CI / 本地收口、Sync 后续开发、OpenAI-compatible probe tooling。当前脚本可以给出“全量验证通过”的信号，但它没有覆盖所有已存在测试入口，也不会暴露 Sync package 无测试 target。
涉及的代码文件路径：`scripts/verify.sh`、`Tests/Tooling/test_probe_openai_compatible_api.py`、`Packages/LangoTraceSync/Package.swift`
涉及的文档路径：`docs/spec/009-testing-and-verification.md`、`docs/testing/README.md`
复查方法：检查 `scripts/verify.sh` 是否加入 Sync package test 和 Python tooling unittest；确认 SwiftLint warning 是否有明确治理策略或基线机制。
优化方案：在 Sync test target 补齐后，把 `swift test --package-path Packages/LangoTraceSync` 加入 `scripts/verify.sh`；把 Python tooling tests 纳入脚本或在 `docs/testing/README.md` 说明它们是专项验证；针对 SwiftLint warnings 建立明确基线、逐步收敛计划或只把 serious 作为门禁的文档化决策。
影响：补齐后，本地“完整验证通过”的语义会更可靠，后续 audit 不需要额外手动补跑 tooling / Sync 命令。
所属维度：测试门禁 / 基础设施 / 文档一致性
建议处理：纳入后续测试基础设施 active plan；不在本轮审查中直接改脚本。

后续继续审查：

- `scripts/verify.sh` 全量运行结果。
- 手动截图 / 可访问性 / Stage Manager / 真机 / 真实 Provider 验证缺口。

## 4. 修复后覆盖记录

- `AUDIT-TEST-001`：已由 `docs/plans/done/2026-05-24-chore-project-wide-audit-remediation.md` 完成主要整改。`scripts/verify.sh` 已纳入 `swift test --package-path Packages/LangoTraceSync` 和 `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`。
- Sync package 已新增 `LangoTraceSyncTests` test target；App target tests 已从 2 tests 扩展到 4 tests，覆盖 AppEnvironment bootstrap 关键边界。
- 验证：`swift test --package-path Packages/LangoTraceSync` 通过，1 test；Python tooling tests 通过，6 tests；`scripts/verify.sh` 通过，退出码 0。
- 剩余风险：SwiftLint warning 仍为 0 serious 门禁口径，warning 基线和逐步收敛策略尚未单独制度化。
