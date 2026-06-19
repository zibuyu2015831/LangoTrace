# 完善统一验证脚本

状态：Verified

类型：chore

创建日期：2026-05-27

最后更新日期：2026-05-27

## 用户确认记录

- 2026-05-27：用户要求“立即完善” `scripts/verify.sh`。

## 需求描述

完善 `scripts/verify.sh`，让统一验证入口覆盖已有文档结构检查、补充补丁格式检查，并提升脚本失败定位能力。

## 现状描述

当前脚本已覆盖 XcodeGen、Swift package tests、Python tooling test、三端构建、macOS app tests、SwiftLint、SwiftFormat 和文档占位扫描，但没有调用 `scripts/check-docs.sh`，也没有运行 `git diff --check`。`Packages/LangoTraceUI` 测试命令带有无实际日志价值的 `tee /dev/null`。

## 目标

- 复用 `scripts/check-docs.sh` 作为文档治理检查入口。
- 增加 `git diff --check`。
- 去掉无意义的 `tee /dev/null`。
- 为长脚本增加阶段输出，便于定位失败步骤。
- 保留现有核心 Swift / Xcode / Python / lint / format 门禁。
- 将 Python tooling 测试入口改为 discovery，避免新增工具测试后遗漏统一门禁。

## 范围

涉及文件：

- `scripts/verify.sh`
- `Tests/Tooling/test_verify_script_contract.py`

参考文件：

- `scripts/check-docs.sh`
- `docs/spec/009-testing-and-verification.md`
- `docs/testing/README.md`

不做：

- 不重写验证体系。
- 不拆分 fast/full 模式。
- 不运行完整 `scripts/verify.sh`，除非本轮环境和时间允许。

## 证据与决策依据

- `docs/spec/009-testing-and-verification.md` 将 `scripts/verify.sh` 定义为 Swift 工程收尾门禁。
- `scripts/check-docs.sh` 已包含入口软链、workflow、plan 命名、review 元数据和占位符扫描等结构检查，统一验证脚本应复用它。

## 实施方案

1. 新增脚本契约测试，验证 `scripts/verify.sh` 包含关键门禁命令。
2. 先运行测试确认当前脚本缺口。
3. 修改 `scripts/verify.sh`。
4. 运行聚焦测试、`bash -n`、`scripts/check-docs.sh` 和 `git diff --check`。

## 复查方法

- 检查脚本命令顺序清晰。
- 检查没有删除既有核心门禁。
- 检查文档结构检查不再只靠复制占位符扫描。

## 验证命令

```bash
python3 -m unittest Tests/Tooling/test_verify_script_contract.py
python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'
bash -n scripts/verify.sh
scripts/check-docs.sh
git diff --check
```

## 文档影响检查

本次只完善现有统一验证入口，不改变 `docs/spec/009-testing-and-verification.md` 的长期规则。

## 实施记录

- 新增 `Tests/Tooling/test_verify_script_contract.py`，锁定统一验证脚本的关键门禁。
- `scripts/verify.sh` 增加阶段化 `run` helper 和工具预检。
- `scripts/verify.sh` 将 Python tooling 测试改为 `unittest discover`。
- `scripts/verify.sh` 复用 `scripts/check-docs.sh`，并新增 `git diff --check`。
- 移除 UI package 测试中的无意义 `tee /dev/null`。
- 验证通过：
  - `python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'`
  - `bash -n scripts/verify.sh`
  - `scripts/check-docs.sh`
  - `git diff --check`
  - `scripts/verify.sh`

## 完成标准

- 聚焦脚本契约测试通过。
- `scripts/verify.sh` 语法检查通过。
- `scripts/check-docs.sh` 通过。
- `git diff --check` 通过。

## 剩余风险

- 完整 `scripts/verify.sh` 已通过。SwiftLint 当前仍报告 warning，但没有 serious violation，未阻断统一验证脚本。
