# 项目级审查发现项集中整改方案

状态：Verified
类型：chore
创建日期：2026-05-24
最后更新日期：2026-05-24

## 1. 用户确认记录

- 2026-05-24：用户要求“针对发现的问题，立即进行修复”。本方案承接 `2026-05-24-project-wide-code-doc-test-audit` 中除两个独立 P1 bug plan 以外的测试基础设施、验证门禁和文档状态对齐整改。

## 2. 目标

- 补齐 Sync package 最小 test target，并纳入统一验证脚本。
- 补 AppEnvironment bootstrap 集成测试，覆盖生产 repository boundary 与 disabled external service boundary。
- 将 Python tooling tests 纳入 `scripts/verify.sh`。
- 修正 README、技术路线、testing 入口和 testing spec 中的当前状态漂移。
- 更新项目级审查 round 的修复记录。

## 3. 范围

- `Packages/LangoTraceSync/Package.swift`
- `Packages/LangoTraceSync/Tests/LangoTraceSyncTests/`
- `LangoTraceAppTests/`
- `scripts/verify.sh`
- `docs/README.md`
- `docs/technical-framework-roadmap.md`
- `docs/testing/README.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/review/rounds/2026-05-24-project-wide-code-doc-test-audit/`

## 4. 不做什么

- 不实现真实 Sync Engine、adapter、manifest、tombstone 或 conflict model。
- 不实现完整生活记录时间线、附件、导出、StoreKit 或发布材料。
- 不做截图、真机、VoiceOver、Dynamic Type 或 Stage Manager 验证。

## 5. 实施方案

1. 以 `swift test --package-path Packages/LangoTraceSync` 的 `no tests found` 作为红灯，新增 `LangoTraceSyncTests` 和 disabled boundary 测试。
2. 新增 `AppEnvironmentBootstrapTests`，验证 bootstrap 使用 GRDB learning content repository boundary，并保持 AI / Speech / Sync 外部服务 disabled。
3. 将 `swift test --package-path Packages/LangoTraceSync` 和 `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py` 加入 `scripts/verify.sh`。
4. 更新入口状态、Phase 0 进度、手动测试清单和验证规范。

## 6. 验证命令

```bash
swift test --package-path Packages/LangoTraceSync
python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py
xcodegen generate
xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests
scripts/verify.sh
git diff --check
git status --short
```

## 7. 实施记录

- 2026-05-24：新增 Sync test target 和 disabled boundary test。
- 2026-05-24：新增 AppEnvironment bootstrap tests；重新生成 Xcode project 后确认 App target tests 实际执行 4 tests。
- 2026-05-24：更新 `scripts/verify.sh`，纳入 Sync package 和 Python tooling tests。
- 2026-05-24：修正 README、技术路线、testing 入口和 spec 009 的当前事实。
- 2026-05-24：通过 Sync、Python tooling、App target tests 和完整 `scripts/verify.sh` 验证。

## 8. 完成标准

- Sync package test 不再以 `no tests found` 失败。
- `scripts/verify.sh` 包含 Sync 和 Python tooling tests。
- App target tests 至少覆盖 bootstrap repository / disabled service boundary。
- 文档不再把 GRDB learning content 和逐句 TTS 播放路径写成早期 mock。
- 完整验证通过。

## 8.1 验证结果

- `swift test --package-path Packages/LangoTraceSync`：通过，1 test。
- `python3 -m unittest Tests/Tooling/test_probe_openai_compatible_api.py`：通过，6 tests。
- `xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests`：通过，4 tests。
- `scripts/verify.sh`：通过，退出码 0。

## 9. 剩余风险

- Sync domain model 仍未冻结；真实同步前必须另建 feature / refactor plan。
- AppEnvironment integration tests 仍是最小边界测试，不覆盖所有 action closure 的真实外部请求路径。
