# Spike / Probe / Fixture 研究入口

状态：Accepted
创建日期：2026-05-25
最后更新日期：2026-05-25

本文档定义研究性 spike、probe、fixture 和审查 evidence 的落点。它吸收 VMark `dev-docs/grills/` 和 `fixtures/` 的证据链经验，但不新增平行事实源。

## 1. 职责边界

| 类型 | 含义 | 默认落点 | 不可替代 |
| --- | --- | --- | --- |
| spike | 实现前的短期可行性验证或技术调研 | 当前任务方案；需要保留研究上下文时放入本目录 | ADR、spec、architecture、当前代码事实 |
| probe | 可重复运行的小型验证脚本、样例或宿主机诊断 | `scripts/`、package tests、`Tests/Tooling/` 或本目录 | App 运行链路、正式测试覆盖 |
| fixture | 自动化测试或研究依赖的稳定样本 | 优先靠近对应 test target；外部格式研究样本可放入 `docs/reference/research/` | 真实用户数据、产品需求 |
| evidence | 审查 round 的命令输出、截图、日志、手动验证记录 | `docs/review/rounds/<round>/` | 当前事实源、长期规范 |

## 2. 写入规则

- spike 通过后，结论若被采纳，必须提升到 `docs/spec/`、`docs/architecture/`、`docs/decisions/` 或当前任务方案。
- spike write-up 可以保留为过程记录，但不能作为当前实现事实源。
- throwaway probe 必须在任务方案中写清保留期限、删除条件和验证价值。
- 长期 probe 必须有稳定运行命令、输入边界和失败含义；如果它验证 App 行为，应优先进入自动化测试或 `Tests/Tooling/`。
- fixture 不得包含真实用户敏感内容、API Key、Authorization header、请求体、响应体、照片、音频或转写全文。
- 外部项目 fixture、格式样本或许可证研究只能作为参考；采纳结论后仍要回写到 LangoTrace 权威文档。
- 依赖外部网络、真实 API Key、本机路径或系统服务的 probe，必须写清离线复现方式、跳过条件和剩余风险。
- 参考研究或重大文档治理结论被采纳前，应使用 evidence-backed claim 写法，明确证据能证明什么、证据不能证明什么、迁移前提和照搬风险。
- spike 或 probe 失败时也要记录 FAIL 原因、后续处理和是否保留证据；不能只删除失败材料。

## 3. Phase 0 Gate

Phase 0 gate 是高风险生产实现前的前置证明层，适用于数据迁移、AI Provider、同步、权限、StoreKit、跨 package 大功能、复杂文档治理或不确定技术路线。它不是所有任务的必填项。

最低记录内容：

- 假设名称。
- probe / fixture / baseline 路径。
- PASS / FAIL 条件。
- FAIL 后处理方式。
- 是否允许进入生产实现。

关系边界：

- Phase 0 gate 可以引用本目录、`docs/reference/research/`、`scripts/`、`Tests/Tooling/` 或 package tests 中的 evidence。
- 研究证据本身不是当前事实源；被采纳后必须写回 active plan、spec、architecture、testing、review 或 ADR。
- 需要真实用户敏感样本时，不得把原始照片、音频、转写全文、请求体、响应体、API Key 或 Authorization header 写入本目录；应使用脱敏 fixture、合成样本或人工验收记录。
- Phase 0 通过只证明该假设在记录的条件下成立，不自动证明完整功能已实现。

## 4. 与其他目录的关系

- `docs/plans/active/`：记录本次任务是否需要 spike / probe / fixture / evidence、实施顺序和清理条件。
- `docs/review/rounds/`：保存审查 evidence，不把 evidence 迁入本目录。
- `docs/testing/`：记录测试策略、fixture 组织原则和验证入口。
- `scripts/`：保存可复用宿主机诊断脚本或结构检查脚本。
- `Packages/*/Tests/`：保存模块自动化测试和靠近测试的长期 fixture。

## 5. 当前已知样例

- `Packages/LangoTraceAI/Sources/LangoTraceAI/Resources/AIProviderProbe/blue-square.png`：AI Provider 图片理解 probe 的内置低敏 fixture。
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/LearningMaterialGenerationServiceFixtures.swift`：学习材料生成服务测试 fixture。
- `Tests/Tooling/test_probe_openai_compatible_api.py`：宿主机 OpenAI-compatible Provider 诊断脚本的单元测试。
