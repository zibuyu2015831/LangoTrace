# 开发 Workflow 手册

状态：Accepted
创建日期：2026-05-25
最后更新日期：2026-05-25

本目录保存高频、高风险开发动作的执行手册。Workflow 的作用是告诉后续会话“做这类任务时按什么顺序读文档、改文件、跑验证”，不是新的产品决策源、架构事实源或实现事实源。

## 1. 权威边界

- 产品定位、语言空间、买断制和核心用户路径以 `docs/product-main-reference.md`、`docs/technical-framework-roadmap.md` 和 ADR 为准。
- 架构边界、数据流和模块关系以 `docs/architecture/` 为准。
- 开发一致性规则以 `docs/spec/` 为准。
- 具体任务执行方案以 `docs/plans/active/` 为准。
- Prompt 正文和隐私契约以 `docs/prompts/` 为准。
- Workflow 只引用上述权威文档，不复制长期规则正文。

如果 workflow 与 spec、ADR、architecture 或 review 记录冲突，先按权威文档处理，并在当前任务方案中记录冲突和修正落点。

## 2. 首批 Workflow

- [新增 AI Provider 或 AI 能力](add-ai-provider.md)
- [新增 TTS Provider 或逐句播放能力](add-tts-provider.md)
- [新增数据存储或迁移](add-storage-migration.md)
- [新增三端平台页面或入口](add-platform-screen.md)
- [新增 Prompt 或 Prompt Preset](add-prompt.md)

## 3. 编写规则

每份 workflow 至少包含：

- 适用场景。
- 必读文档。
- 任务方案要求。
- 关键代码和文档落点。
- 必做测试。
- 完成前检查。
- 反例。

高风险 workflow 还应补充：

- 故障和恢复路径。
- 数据、隐私、权限或同步影响。
- 是否需要专项文档审查。

## 4. 从参考项目吸收的原则

本目录吸收 OpenWriter `dev_docs/workflows/` 的“动作手册”思路，也吸收 VMark `dev-docs` 的以下原则：

- 重要开发入口要能快速指向系统地图、入口点、数据流和模块边界。
- 审查输出要区分严重度、证据、修复建议和剩余风险。
- 高风险能力需要显式列出已知故障模式、恢复路径和测试覆盖。
- 文档健康治理应有低成本脚本和周期性检查，但不能替代人工语义审查。

不吸收的部分：

- 不新增 `docs/bug/`、`docs/ideas/` 或分块审计目录。
- 不把周期性清理机制升级为自动删除或自动改写长期文档的机制。
- 不把参考项目的技术栈规则直接套用到 Apple 三端、SwiftUI、Keychain、SQLite / GRDB、StoreKit 和本地优先隐私边界。
