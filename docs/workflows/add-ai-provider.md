# Workflow：新增 AI Provider 或 AI 能力

适用场景：新增文本生成、图片理解、Embedding、OCR、Speech、Provider adapter、Provider probe、请求预览、请求日志或 AI 能力入口。

## 1. 必读文档

- `docs/README.md`
- `docs/plans/README.md`
- `docs/product-main-reference.md` 第 9、10 节
- `docs/technical-framework-roadmap.md` 第 7、8 节
- `docs/architecture/001-initial-module-boundaries.md`
- `docs/spec/005-ai-provider-prompt-and-privacy.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/009-testing-and-verification.md`
- `docs/prompts/README.md`
- `docs/decisions/005-local-first-and-user-owned-providers.md`

## 2. 任务方案要求

实现前必须创建或更新 `docs/plans/active/YYYY-MM-DD-feature-<topic>.md`、`bug`、`refactor` 或 `docs` 类型方案，并经用户确认。

方案必须写清：

- 是否发送用户生活记录、目标语言文本、照片、音频、OCR、历史记忆或附件摘要。
- Provider 配置、endpoint、credential、Keychain 引用和非敏感 SQLite / GRDB 配置如何分层。
- 请求预览、请求日志、诊断日志和 validation event 的允许字段。
- 失败、取消、超时、配额限制、模型不支持、返回格式不合法时的恢复路径。
- 是否新增或修改 Prompt Registry 文档。

## 3. 关键落点

- AI package：Provider protocol、adapter、probe、结构化输出解析和错误分类。
- Data package：Provider profile、endpoint、credential metadata、validation event repository。
- App / UI package：设置页状态机、保存状态、测试入口、结果展示和三端共享 seam。
- Prompt Registry：真实 Prompt、变量、输出契约和隐私边界。
- Review：若涉及 AI Provider、Keychain、请求预览、请求日志或隐私边界，按 `docs/review/README.md` 判断是否触发专项审查。

## 4. 测试要求

至少覆盖：

- Credential 明文不进入 SQLite、日志、同步目录或测试输出。
- Draft probe 不持久化 Keychain、SQLite 或 validation event。
- Saved probe 通过 Keychain 引用解析密钥。
- 结构化输出解析拒绝非法 JSON、缺字段、非法枚举和超限数组。
- 取消不会写入失败 validation event。
- iPhone、iPad、macOS 共享同一 action / service seam。

## 5. 故障与恢复路径

任务方案应列出最小故障矩阵：

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| API Key 缺失 | 进入可恢复 credential missing 状态 | 单元测试或 service 测试 |
| Provider 不支持能力 | 稳定错误分类，不伪装成网络失败 | adapter 测试 |
| 用户取消 | 终止请求，不写失败事件 | service / store 测试 |
| 返回格式不合法 | 拒绝写入 Data 层 | AI 解析测试 |

## 6. 完成前检查

运行当前任务方案列出的聚焦测试；涉及 Swift 工程行为时运行 `scripts/verify.sh`。文档-only 变更至少运行 `scripts/check-docs.sh`、占位符扫描、`git diff --check` 和 `git status --short`。

## 7. 反例

- 在 SwiftUI View 里直接创建 `URLRequest` 或拼接 Authorization header。
- 把 API Key 保存进 SQLite、日志、请求预览或同步目录。
- 新增 Prompt 但只在代码里写字符串，不登记 `docs/prompts/`。
- 让保存 Entry、打开页面或滚动列表自动触发 AI 请求。
