# Reading Lifecycle And CRUD Governance

状态：Verified
自审核状态：Reviewed
类型：docs
创建日期：2026-06-03
最后更新日期：2026-06-03

## 用户确认记录

- 2026-06-03：用户要求检查阅读 UI 改动后的相关文档是否需要更新或归档。
- 2026-06-03：检查后确认需要将 `2026-06-01-feature-reading-ai-tts-vertical-slice.md` 从 `active/` 收口归档，并修正 research 文档中仍把该方案写成 `Draft / active` 的历史表述。
- 2026-06-03：用户进一步要求从系统架构师视角评估“新增功能默认需要考虑增删改查”的适用范围，并将结论沉淀为规范。
- 2026-06-03：已向用户提出“对象生命周期分层规范 + Reading 先落地”的方案，用户确认“好，立即进行”。

## 需求描述

当前阅读纵向切片和 2026-06-03 UI 重构已经完成功能和页面事实更新，但文档体系里仍存在两个问题：

1. 阅读主方案仍停留在 `active/`，会误导后续会话把阅读纵向切片当成未完成任务。
2. 仓库缺少一条通用规则，约束“用户导入或创建的主数据对象默认需要具备完整生命周期，而不是只实现创建或展示入口”。这在 `ReadingDocument` 上已经暴露为导入与阅读已落地，但编辑能力和 CRUD 原则没有被明确记录。

本任务需要一并完成 plan 生命周期收口、focused review round 和跨领域生命周期规范沉淀。

## 当前现状

- 阅读纵向切片主方案在本任务开始前仍处于 `Implemented` 但未正式归档的状态。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md` 仍多次引用旧的 `active` 路径和 `Draft` 时态。
- `docs/spec/012-reading-learning-domain.md` 已定义 Reading import、rendering、selection、AI explanation 和 TTS 边界，但没有明确把 `ReadingDocument` 归类为“用户主数据”，也没有写出默认 CRUD 要求。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 已有主数据 / 派生数据 / 附件 / 偏好分层，但没有把不同对象类型对应的默认生命周期职责写成显式规范。
- `docs/workflows/add-platform-screen.md` 只要求检查页面、状态和导航，没有要求在新增主数据页面时检查对象生命周期是否完整。
- `docs/review/INDEX.md` 最近一轮专项审查仍停留在 2026-05-24，没有记录这次阅读生命周期文档治理。

## 目标

1. 将阅读纵向切片主方案正式从 `active/` 收口归档到 `done/`，并修正 research 文档中的旧路径和旧时态。
2. 建立“对象生命周期分层规范”：
   - 用户主数据默认必须设计完整 `Create / Read / Update / Delete` 路径。
   - 派生数据、配置对象和运行期记录使用各自适配的生命周期，不强行套同一 CRUD 模型。
3. 在 Reading domain 明确 `ReadingDocument` 属于用户主数据，因此粘贴导入和文件导入后的阅读材料默认必须考虑基础 CRUD。
4. 在 workflow / review 体系中加入对应门禁，防止后续新增对象时再次只做“创建”或“只读”半闭环。

## 范围

- `docs/plans/active/`、`docs/plans/done/` 的阅读方案收口归档。
- `docs/reference/research/2026-06-01-reading-integration-assessment.md` 的路径和时态修正。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 生命周期分层规则补充。
- `docs/spec/012-reading-learning-domain.md` 中 ReadingDocument 的 CRUD 规则补充。
- `docs/workflows/add-platform-screen.md` 的页面 / 对象生命周期检查补充。
- `docs/review/rounds/` 与 `docs/review/INDEX.md` 的 focused review round 记录。

## 不做什么

- 不在本任务内实现 ReadingDocument 正文编辑 UI 或 repository 新接口。
- 不把所有对象都粗暴统一成同一 CRUD 模板。
- 不修改 ADR、产品北极星或 Provider / Sync / StoreKit 核心决策。
- 不重写历史 review 正文，只通过新 round 和索引标注当前事实。

## 证据与决策依据

- `docs/spec/007-data-storage-migration-export-and-attachments.md`：已经区分主数据、派生数据、附件和偏好，是最适合补充对象生命周期分层规范的权威文档。
- `docs/spec/012-reading-learning-domain.md`：当前明确了 ReadingDocument 的主数据属性和导入边界，但未明确默认 CRUD 责任。
- `docs/spec/004-swiftui-architecture.md`：强调 UI、Store、Repository 和异步状态边界清晰，支持把“对象生命周期检查”作为实现前门禁，而不是在 View 层临时补洞。
- `docs/review/README.md`：多端导航结构、AI 会话发现文档与代码不一致、数据库 / AI / TTS / 三端入口变化默认应考虑专项审查或在任务方案中说明。
- 系统架构评估结论：LangoTrace 至少存在用户主数据、派生学习数据、配置对象和运行期记录四类对象；统一要求“所有对象都 CRUD”是错误抽象，最优方案是建立分层生命周期规范。

## 涉及代码文件路径

- 无生产代码改动。

## 参考的代码与文档路径

- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/012-reading-learning-domain.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/workflows/add-platform-screen.md`
- `docs/review/README.md`
- `docs/review/INDEX.md`
- `docs/plans/done/2026-06-03-refactor-reading-library-ui-redesign.md`
- `docs/plans/done/2026-06-03-refactor-reading-workbench-ipad-mac.md`

## 涉及的文档路径

- `docs/plans/done/2026-06-03-docs-reading-lifecycle-and-crud-governance.md`
- `docs/plans/done/2026-06-01-feature-reading-ai-tts-vertical-slice.md`
- `docs/reference/research/2026-06-01-reading-integration-assessment.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/012-reading-learning-domain.md`
- `docs/workflows/add-platform-screen.md`
- `docs/review/rounds/2026-06-03-reading-lifecycle-governance/README.md`
- `docs/review/INDEX.md`

## 实施方案

1. 先创建本 docs 任务方案并完成自审核，明确这是文档治理和 focused review 任务，而不是代码功能实现。
2. 将 `2026-06-01-feature-reading-ai-tts-vertical-slice.md` 收口归档到 `done/`，并把状态更新为 `Verified`。
3. 修正 `2026-06-01-reading-integration-assessment.md` 中对旧 active plan 路径和旧时态的引用。
4. 在 `docs/spec/007-data-storage-migration-export-and-attachments.md` 新增对象生命周期分层规则：
   - 用户主数据默认要求完整 CRUD。
   - 派生数据使用“生成 / 查看 / 失效 / 重建 / 清理”。
   - 配置对象使用“读取 / 保存 / 更新 / 删除或重置 / 验证”。
   - 运行期记录使用“保留 / 清理 / 脱敏 / 导出排除或受控披露”。
5. 在 `docs/spec/012-reading-learning-domain.md` 明确 `ReadingDocument` 属于用户主数据，并写出导入后的基础 CRUD 预期。
6. 在 `docs/workflows/add-platform-screen.md` 补充页面 / 对象生命周期门禁，要求新增用户主数据页面时检查是否完整覆盖 CRUD。
7. 创建 focused review round `2026-06-03-reading-lifecycle-governance`，记录问题、证据、修复和剩余风险。
8. 更新 `docs/review/INDEX.md`，将该 round 纳入索引和最新状态摘要。

## 复查方法

- 检查阅读主方案不再残留在 `docs/plans/active/`。
- 检查 research 文档不再把 2026-06-01 阅读方案描述成当前 `Draft / active`。
- 检查 `spec/007` 明确区分对象类型与默认生命周期，不再把 CRUD 粗暴套给所有对象。
- 检查 `spec/012` 明确 `ReadingDocument` 的用户主数据属性与 CRUD 责任。
- 检查 `workflows/add-platform-screen.md` 补入生命周期门禁。
- 检查 `docs/review/INDEX.md` 和新 round 路径一致。

## 验证命令

```bash
scripts/check-docs.sh
rg "2026-06-01-feature-reading-ai-tts-vertical-slice" docs --glob '*.md'
git diff --check
git status --short
```

## 文档影响检查

- 需要更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`，因为对象生命周期分层是长期执行规则。
- 需要更新 `docs/spec/012-reading-learning-domain.md`，因为 ReadingDocument 的主数据生命周期边界属于 Reading 领域规范。
- 需要更新 `docs/workflows/add-platform-screen.md`，因为新增页面 / 入口的高风险动作需要检查是否遗漏主数据生命周期。
- 需要新增 `docs/review/rounds/2026-06-03-reading-lifecycle-governance/README.md` 并更新 `docs/review/INDEX.md`，因为本任务既修正文档漂移，也新增长期治理规则。
- 无需更新 ADR；本任务不改变核心产品、隐私、同步或 Provider 决策。

## 严格方案自审核记录

审核日期：2026-06-03
审核方式：主会话自审核
审核轮次：双轮
未使用隔离审查的原因：当前任务范围集中在 docs 治理和 review 收口，同一会话已完成代码和页面事实核对，继续在同一上下文中收口更直接。
发现摘要：

- P0：阅读纵向切片主方案仍停留在 `active/`，会误导后续会话把已完成功能当成未完成任务。必须先收口归档。
- P1：如果直接把“所有对象都要 CRUD”写成统一规则，会错误覆盖派生数据、配置对象和运行期记录。必须先做对象类型分层。
- P1：ReadingDocument 已经是用户主数据，但当前 spec 未把“导入后的基础 CRUD 责任”写成显式规则，后续容易再次只做导入与阅读半闭环。
- P1：新增页面 workflow 缺少生命周期门禁，后续对象页面仍可能只实现导入 / 列表 / 详情之一。

写回修改：

- 采用“对象生命周期分层规范 + Reading 先落地”的方案，而不是粗暴统一 CRUD。
- 将 focused review round 和 review index 更新纳入本任务范围。
- 验证命令包含旧路径检索，确保不再残留过期 active 引用。

仍需用户确认的问题：无。用户已明确要求立即执行推荐方案。
是否允许进入实现：允许。

## 实施记录

- 2026-06-03：创建本 active plan，记录阅读文档收口、对象生命周期分层规范和 focused review round 的范围。
- 2026-06-03：将 `2026-06-01-feature-reading-ai-tts-vertical-slice.md` 从 `active/` 移入 `done/`，更新为 `Verified`，并修正 reading integration research 中仍引用旧 active 路径和 `Draft` 时态的段落。
- 2026-06-03：更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`，新增对象生命周期分层规则，明确用户主数据默认需要完整 CRUD，而派生数据、配置对象和运行期记录采用各自适配的生命周期。
- 2026-06-03：更新 `docs/spec/012-reading-learning-domain.md` 与 `docs/workflows/add-platform-screen.md`，把 `ReadingDocument` 的用户主数据属性和页面 / 对象生命周期门禁写成执行规则。
- 2026-06-03：新增 review round `docs/review/rounds/2026-06-03-reading-lifecycle-governance/README.md` 并更新 `docs/review/INDEX.md`。
- 2026-06-03：运行 `scripts/check-docs.sh`、`rg "2026-06-01-feature-reading-ai-tts-vertical-slice" docs --glob '*.md'`、`git diff --check`，全部通过。

## 完成标准

- `2026-06-01-feature-reading-ai-tts-vertical-slice.md` 已从 `active/` 移入 `done/` 并标记为 `Verified`。
- `2026-06-01-reading-integration-assessment.md` 不再把该方案写成当前 `Draft / active`。
- `docs/spec/007-data-storage-migration-export-and-attachments.md` 明确对象生命周期分层和默认规则。
- `docs/spec/012-reading-learning-domain.md` 明确 `ReadingDocument` 的用户主数据属性与 CRUD 责任。
- `docs/workflows/add-platform-screen.md` 增加生命周期门禁。
- 新 review round 和 `docs/review/INDEX.md` 一致。
- 文档检查命令通过。

## 剩余风险

- 本任务只沉淀生命周期规则，不等于本轮已经实现 ReadingDocument 全部编辑能力；后续若补正文编辑、批量管理或 Memory CRUD，仍需独立 active plan。
- 其他对象例如 `MemoryItem`、附件主数据和 `PromptPreset` 目前尚未逐一补到页面事实源；本次规范只建立默认门槛，具体实现仍需后续任务逐步落地。
