# 多端原型目标设计扩展备忘录

状态：Accepted
创建日期：2026-06-11
适用范围：记录时间线与筛选、记忆 Tab 体验、练习方式扩展（听写 / 回译）、搜索、macOS 导入导出，以及承载这些能力的路由、数据投影和共享组件设计。

## 1. 目的

2026-06-11 重建的多端原型（入口 `prototypes/index.html`，背景见 `docs/plans/done/2026-06-11-chore-prototype-redesign.md`）为一批尚未实现的能力给出了「目标设计」页面。这些页面只是设计基准，不构成实现授权；但其中的结构决策会影响后续路由、数据模型和共享组件设计。本备忘录保存这些跨任务提醒，供后续创建相关 active plan 时检查。

后续任务采纳其中任一结论时，必须写回对应 active plan、spec、architecture 或 ADR；本备忘录不替代它们。

## 2. 目标设计决策与扩展点

### 2.1 记录 Tab 演进为生活时间线（`prototypes/iphone/record.html`）

- 目标设计：保留 Hero 双入口（写一句 / 用照片开始），列表演进为按日分组的时间线，加入轻量筛选 chips（全部 / 照片 / 待练习 / 已沉淀）。
- 扩展点：`PhoneRecordWorkspaceView` 列表区引入日期分组 section 和筛选状态；筛选语义应与 iPad `PadFilter` 共享，不做平台各自的枚举。
- 后续必须重新决策：分组粒度（日 / 周）和跨语言空间行为；「待练习 / 已沉淀」的判定来源（practice session 状态、memory candidate 状态）需要真实数据投影，不得复用 mock 推导。

### 2.2 记忆 Tab 目标体验（`prototypes/iphone/memory.html`、`ipad/memory.html`、`mac/memory.html`）

- 目标设计：「从生活沉淀的词句 / 整句」卡片流 + 低压力复习队列入口；不暴露向量索引、embedding 等工程概念（页面清单第 8 节红线）。
- 扩展点：memory candidate 数据已在 GRDB learning content 主路径中，第一步可做只读沉淀列表；复习队列依赖 Embedding / 检索方案，相关边界见 [2026-05-27-embedding-infrastructure-notes.md](2026-05-27-embedding-infrastructure-notes.md)。
- 后续必须重新决策：沉淀项与原始记录的回链导航；三层记忆（内容 / 语言 / 学习）在用户语义下的呈现层级（spec 003 §4.14 要求区分三层但不暴露技术结构）。
- 词句收藏与词典能力交叉处见 [2026-05-25-dictionary-feature-extension-notes.md](2026-05-25-dictionary-feature-extension-notes.md)。

### 2.3 听写与回译作为练习方式层级（`prototypes/iphone/practice-dictation.html`、`practice-backtranslation.html`）

- 目标设计：练习 Tab 首层维持记录卡片列表（页面清单红线：不混排未实现任务类型）；听写 / 回译作为「记录 → 句子列表」层级的练习方式切换（跟读 / 听写 / 回译）。
- 扩展点：`PracticeSessionRouteSeed` 需要增加 practice mode 字段，复用同一句子快照、TTS 示范路径和 `PracticeActions` seam；`practice_sessions` 已有 exercise type 字段可承接。
- 后续必须重新决策：听写校对是否纯本机（原型按本机校对设计）；回译参考表达的来源（已有 LearningMaterial 翻译 vs 新 AI 请求，后者必须走显式触发和请求预览边界）。
- 录音 / 练习产物的同步、导出边界见 [2026-05-26-practice-recording-sync-export-notes.md](2026-05-26-practice-recording-sync-export-notes.md)。

### 2.4 搜索（`prototypes/mac/search.html`、iPad 顶部搜索）

- 目标设计：macOS 为 Command Palette 风格全局搜索，iPad 为顶部搜索浮层；范围限定当前语言空间。
- 扩展点：依赖 FTS（尚未实现）；搜索结果类型至少覆盖记录、阅读文档和沉淀词句。
- 后续必须重新决策：跨语言空间搜索是否提供（页面清单 iPad 搜索条目已留「需定义跨空间范围」提醒）；FTS 索引作为可重建派生数据的失效 / 重建策略。

### 2.5 macOS 导入导出（`prototypes/mac/import-export.html`）

- 目标设计：桌面端为自然落点；导出包含范围选择、附件开关，并显式说明不含 API Key / 对象存储密钥等 Keychain 内容。
- 扩展点：导出包格式、附件纳入策略和可恢复备份必须遵守 `docs/spec/007-data-storage-migration-export-and-attachments.md`；练习录音默认排除在导出外（见 2.3 链接备忘录）。
- 后续必须重新决策：导出包与未来同步 manifest 的格式关系；导入冲突处理。

### 2.6 设置类页面（`prototypes/iphone/settings*.html`）

- 原型仅做视觉升级，沿用现有信息架构（AI Provider 分能力测试、iCloud 推荐 + S3 高级），不改变范围与密钥边界表达；无新增架构提醒。
- 设置主列表未来的真实健康状态投影仍按 [2026-05-24-settings-status-projection-notes.md](2026-05-24-settings-status-projection-notes.md) 处理。

## 3. 不应在当前阶段提前实现的内容

- 不提前建 FTS 表、复习队列调度或听写评分数据结构；这些必须等对应能力的独立方案。
- 不为时间线筛选预埋未经评审的 Entry 字段或派生表；筛选投影应在能力方案中定义。
- 不把原型页面结构直接转译为 SwiftUI 代码而跳过 active plan 和用户确认。

## 4. 读取规则

创建记录时间线、记忆、练习扩展、搜索或导入导出相关任务方案前，应读取本备忘录，并在方案中说明采纳、暂不采纳或需要提升为 spec / architecture / ADR 的内容。
