# Workflow：新增 Prompt 或 Prompt Preset

适用场景：新增真实发送给 Provider 的 Prompt、Prompt Preset、模板渲染、结构化输出 schema、请求预览文本或 Prompt 版本变更。

## 1. 必读文档

- `docs/README.md`
- `docs/plans/README.md`
- `docs/prompts/README.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

## 2. 任务方案要求

实现前必须创建或更新 active plan，并明确：

- Prompt id、version、所属能力和状态。
- 英文 canonical Prompt、中文审阅版本、输入变量和输出契约。
- 是否包含用户原文、照片、音频、OCR、历史记忆、附件摘要或语言空间上下文。
- 是否需要请求预览、用户确认、日志脱敏和评测样例。
- 修改 Prompt 是否影响 Data 映射、AI service 测试或现有结果兼容性。

## 3. 关键落点

- `docs/prompts/<feature>/<prompt-id>.md`：完整 Prompt 文档。
- AI package：Prompt registry、template renderer、schema、parser 和 fixture tests。
- Data package：结构化输出映射、schema version、operation metadata。
- UI package：请求入口、请求预览、结果状态和错误展示。

## 4. 测试要求

至少覆盖：

- Prompt registry 能返回正确 id / version / schema version。
- 模板变量完整，敏感变量不会进入日志或 metadata。
- 结构化输出解析拒绝自然语言前后缀、缺字段、非法枚举、额外字段和数组超限。
- 中文审阅版本与英文 canonical 的隐私语义一致。
- 请求元数据只保存非敏感字段。

## 5. 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| 模型返回非 JSON | 拒绝写入 Data 层并显示可恢复失败 | parser 测试 |
| Prompt version 不匹配 | 保留旧结果 metadata，新请求使用新版本 | registry / mapping 测试 |
| 变量缺失 | 本地构造失败，不发起 Provider 请求 | template 测试 |
| 用户取消 | 不写失败 operation | service / store 测试 |

## 6. 完成前检查

更新 `docs/prompts/README.md` 的当前登记列表或版本记录；运行相关 AI / Data / UI 聚焦测试。文档-only Prompt 登记至少运行 `scripts/check-docs.sh`、占位符扫描、`git diff --check` 和 `git status --short`。

## 7. 反例

- 把 Prompt 写在按钮 action 或 View 文件里。
- 只写 Prompt 摘要，不保存完整英文 canonical 和中文审阅版本。
- Prompt 引入新的隐私判断，但不更新 spec、architecture 或 ADR。
- 解析半成品模型输出后写入 Data 层。
