# 文档审查：阅读生命周期与 CRUD 治理

审查类型：专项审查
日期：2026-06-03
代码快照：091abd93479a42c3356a3f3f19fb3a9545696f56
状态：Verified
当前事实源：`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/012-reading-learning-domain.md`、`docs/workflows/add-platform-screen.md`、`docs/platform-page-inventory.md`
后续覆盖记录：`docs/plans/done/2026-06-03-docs-reading-lifecycle-and-crud-governance.md`
可作为依据：Yes

## 1. 触发原因

阅读纵向切片和 2026-06-03 三端阅读 UI 重构已经落地，但文档体系仍存在两个会误导后续实现的问题：

- 阅读主方案仍残留在 `docs/plans/active/`，容易让后续会话误把已完成的 Reading vertical slice 当成未完成任务。
- 当前规范没有明确“用户主数据默认必须具备完整生命周期”，导致 ReadingDocument 已完成导入与阅读，但“增删改查是否是默认要求”没有被写成跨领域规则。

这同时命中文档体系漂移和多端页面 / 数据主对象治理缺口，因此创建 focused review round。

## 2. 审查范围

- `docs/plans/done/2026-06-01-feature-reading-ai-tts-vertical-slice.md`
- `docs/reference/research/2026-06-01-reading-integration-assessment.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/012-reading-learning-domain.md`
- `docs/workflows/add-platform-screen.md`
- `docs/platform-page-inventory.md`

## 3. 相关源码、脚本和配置

- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingLibraryStore.swift`
- `Packages/LangoTraceUI/Sources/LangoTraceUI/ReadingViews.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBReadingLibraryRepository.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/ReadingLibrary.swift`
- `scripts/check-docs.sh`

## 4. 结论摘要

本轮审查确认：

- `ReadingDocument` 已经是按 `LanguageSpace` 隔离的本地主数据，不是临时导入缓存，也不是只读演示对象。
- 对 LangoTrace 来说，“所有对象都统一 CRUD”是错误抽象；正确做法是将对象至少分成用户主数据、派生数据、配置对象和运行期记录四类，并分别定义默认生命周期。
- 阅读领域当前最需要补的是规范和门禁，不是再新增一份产品主参考或 ADR。

## 5. 问题清单

| 编号 | 严重度 | 类型 | 证据 | 处理 |
| --- | --- | --- | --- | --- |
| READ-LIFE-1 | P0 | Plan 生命周期漂移 | 阅读主方案仍在 `docs/plans/active/`，但实现和验证已经完成 | 已归档到 `docs/plans/done/2026-06-01-feature-reading-ai-tts-vertical-slice.md` 并改为 `Verified` |
| READ-LIFE-2 | P1 | 规范缺口 | `spec/012` 定义了 ReadingDocument 是主数据，但未写出导入后默认需要基础 CRUD | 已在 `spec/012` 补充用户主数据和基础 CRUD 责任 |
| READ-LIFE-3 | P1 | 抽象层级错误风险 | 若直接写“任何对象都必须 CRUD”，会错误覆盖派生数据、配置和日志对象 | 已在 `spec/007` 新增对象生命周期分层规则 |
| READ-LIFE-4 | P1 | Workflow 门禁缺口 | `add-platform-screen.md` 未要求页面设计检查对象生命周期是否完整 | 已补充用户主数据页面和对象入口的生命周期检查要求 |
| READ-LIFE-5 | P2 | Research 历史表述过期 | reading integration assessment 仍多次写旧 active 路径和旧时态 | 已修正为 done 路径和历史时态 |

## 6. 文档修改记录

- 归档 `docs/plans/done/2026-06-01-feature-reading-ai-tts-vertical-slice.md`，并将状态更新为 `Verified`。
- 更新 `docs/reference/research/2026-06-01-reading-integration-assessment.md`，修正旧 active 路径和 `Draft` 时态。
- 更新 `docs/spec/007-data-storage-migration-export-and-attachments.md`，新增对象生命周期分层和默认治理规则。
- 更新 `docs/spec/012-reading-learning-domain.md`，明确 `ReadingDocument` 属于用户主数据，并默认要求基础 CRUD 设计。
- 更新 `docs/workflows/add-platform-screen.md`，补充用户主数据页面必须检查生命周期完整性。
- 更新 `docs/review/INDEX.md`，登记本轮专项审查。

## 7. 用户澄清

无待澄清问题。用户已确认采用“对象生命周期分层规范 + Reading 先落地”的方案，并要求立即执行。

## 8. 延后项和原因

- `ReadingDocument` 正文编辑、批量管理和更完整的删除 / 恢复交互：需要单独功能任务，不在本轮 docs 治理范围内。
- `MemoryItem`、附件主数据、PromptPreset 等其他对象的页面级 CRUD 闭环：后续任务按本轮新规则逐步检查和落地。

## 9. 验证命令与结果

已通过：

- `scripts/check-docs.sh`
- `rg "2026-06-01-feature-reading-ai-tts-vertical-slice" docs --glob '*.md'`
- `git diff --check`

## 10. 剩余风险

- 本轮只建立规则，不等于 ReadingDocument 已经具备完整 UI 编辑体验；当前仍只有导入 / 列表 / 搜索 / 打开 / 删除恢复 / metadata 赋值。
- 旧文档里关于其他对象的生命周期描述仍可能不够完整；后续新增主数据对象时必须继续按本轮规则执行。
