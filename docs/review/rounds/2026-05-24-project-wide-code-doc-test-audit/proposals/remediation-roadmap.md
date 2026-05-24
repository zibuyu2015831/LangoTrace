# 整改路线

状态：Verified

## 1. 必须先修再继续对应领域开发

| 顺序 | 问题 | 推荐处理 | 原因 |
| --- | --- | --- | --- |
| 1 | AUDIT-ARCH-004：学习材料取消不终止实际 Provider 请求 | 创建 P1 bug active plan | 真实 AI Provider 请求可能在用户取消后继续发送敏感文本并消耗额度。 |
| 2 | AUDIT-ARCH-003：语言空间切换后 `LearningContentStore` 可能保持旧 `spaceID` | 创建 P1 bug active plan | 这是核心语言空间隔离风险，会影响记录、AI 生成和 TTS 上下文。 |
| 3 | AUDIT-ARCH-001 / AUDIT-INFRA-001：Sync package 无测试 target，真实 Sync domain model 尚未冻结 | 创建同步前置 `chore/refactor` active plan | 真实同步开发前必须先有 package test target、状态模型、adapter / manifest / conflict 边界和密钥排除规则。 |
| 4 | AUDIT-ARCH-002：App 层集成测试覆盖面过窄 | 创建 AppEnvironment integration tests active plan | 高风险 App Shell 装配变化不能只靠 package tests 证明。 |

## 2. 可作为近期文档治理任务处理

| 顺序 | 问题 | 推荐处理 | 原因 |
| --- | --- | --- | --- |
| 1 | AUDIT-DOC-001：README 当前状态新旧事实混杂 | 用户确认后更新入口当前事实源 | 入口文档会影响所有后续 AI 会话分流。 |
| 2 | AUDIT-DOC-002：技术路线 Phase 0 进度滞后 | 用户确认后更新路线当前进度 | 路线文档会影响阶段优先级和里程碑判断。 |
| 3 | AUDIT-DOC-003：测试手动验证清单仍按早期 mock 口径描述记录和逐句听读 | 用户确认后更新测试入口 | 人工验收清单会直接影响三端真实能力收口判断。 |

## 3. 本轮继续审查项

- 继续扩展三端能力矩阵，尤其是 StoreKit、release、导入导出、权限、OCR、照片、录音和真实 Provider 人工验证。
- 继续抽查 Data / AI / Speech 关键 repository、service 和 failure path，确认是否还有 P0 / P1 数据一致性或隐私问题。
- 运行或归因 `scripts/verify.sh`，若占位扫描因本轮 In Progress 文档失败，需在最终收口前清理或记录。
