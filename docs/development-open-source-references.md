# 语迹 / LangoTrace 开源项目参考记录

本文记录开发语迹 / LangoTrace 时可研究的开源项目。当前结论是：暂未发现一个开源项目完整覆盖“生活记录 + AI 转目标语言 + 配音跟读 + 听写回译 + 单词本 + 本地优先 + 多端同步”这个组合；但以下项目可以按模块拆开研究。

这些项目只作为产品结构、交互逻辑、数据模型和技术方案参考。商业闭源开发时，不应直接复制许可证不兼容项目的代码。

## 0. 本地源码位置

以下源码已克隆到本机 `/Users/zibuyu/code/openSource`，后续开发和调研可直接从本地路径打开。若后续需要引用、复制、改造代码或引入依赖，仍必须先按第 5 节重新检查仓库当前 `LICENSE` 和依赖许可证。

| 项目 | GitHub 地址 | 本地源码位置 |
|---|---|---|
| Memex | https://github.com/memex-lab/memex | `/Users/zibuyu/code/openSource/memex` |
| OpenKoto | https://github.com/hikariming/openkoto | `/Users/zibuyu/code/openSource/openkoto` |
| EchoTalk | https://github.com/alisolphp/EchoTalk | `/Users/zibuyu/code/openSource/EchoTalk` |
| VocabSieve | https://github.com/FreeLanguageTools/vocabsieve | `/Users/zibuyu/code/openSource/vocabsieve` |
| Ulangi | https://github.com/subconcept-labs/ulangi | `/Users/zibuyu/code/openSource/ulangi` |
| Dayflow | https://github.com/JerryZLiu/Dayflow | `/Users/zibuyu/code/openSource/Dayflow` |
| Memos | https://github.com/usememos/memos | `/Users/zibuyu/code/openSource/memos` |
| language-learning-prompts | https://github.com/aoilang/language-learning-prompts | `/Users/zibuyu/code/openSource/language-learning-prompts` |
| Anki | https://github.com/ankitects/anki | `/Users/zibuyu/code/openSource/anki` |
| LinguaCafe | https://github.com/simjanos-dev/LinguaCafe | `/Users/zibuyu/code/openSource/LinguaCafe` |
| Lute v3 | https://github.com/LuteOrg/lute-v3 | `/Users/zibuyu/code/openSource/lute-v3` |
| Readest | https://github.com/readest/readest | `/Users/zibuyu/code/openSource/readest` |
| LibreLingo | https://github.com/kantord/LibreLingo | `/Users/zibuyu/code/openSource/LibreLingo` |

## 1. 优先研究结论

第一批建议优先研究 5 个项目：

| 项目 | GitHub 地址 | 对语迹的参考价值 |
|---|---|---|
| Memex | https://github.com/memex-lab/memex | 最接近“生活记录 + 本地优先 + AI 组织”。支持文字、图片、语音碎片记录、本地数据和用户自带 LLM Provider，适合参考“照片/日记 -> AI 组织”和本地优先产品结构。 |
| OpenKoto | https://github.com/hikariming/openkoto | AI 语言学习桌面工具，Tauri + React + Rust，支持导入 URL、PDF、EPUB、TXT、Word、Markdown，并做翻译、词汇提取、语法解释。适合参考桌面端架构和“任意材料转语言学习材料”。 |
| EchoTalk | https://github.com/alisolphp/EchoTalk | 离线 Shadowing 练习工具，支持录音、TTS、练习历史、IndexedDB、本地存储、PWA。适合参考“跟读/录音/重复播放/训练模式”。 |
| VocabSieve | https://github.com/FreeLanguageTools/vocabsieve | 面向语言学习的 Anki 伴侣，重点是查词、句子挖掘、词典导入、发音、频率表、本地优先、EPUB 阅读、Kindle/KOReader 摘录转 Anki。适合参考“单词本 + 词典导入 + 句子挖掘”。 |
| Ulangi | https://github.com/subconcept-labs/ulangi | React Native 语言学习工具，内置词典、翻译、TTS、图片搜索、间隔重复、写作、quiz。虽然仓库已归档，但对移动端语言学习产品结构有参考价值。 |

这五个项目基本覆盖语迹的核心模块：

- 生活记录、图片语音输入、AI 组织。
- AI 语言学习、文本导入、翻译、词汇提取。
- Shadowing、TTS、录音、本地练习。
- 词典导入、单词本、句子挖掘。
- 移动端语言学习、TTS、间隔重复。

## 2. 按功能模块拆分的参考项目

### 2.1 生活记录、日记、本地优先

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| Memex | https://github.com/memex-lab/memex | 文字、图片、语音碎片记录；本地数据；用户自带 LLM Provider；AI 组织个人材料。 |
| Dayflow | https://github.com/JerryZLiu/Dayflow | Mac 本地优先工作日记；屏幕活动时间轴；本地 AI、Gemini、ChatGPT、Claude 等多 Provider；日/周回顾。 |
| Memos | https://github.com/usememos/memos | 自托管快速记录工具；Markdown-native；timeline-first；标签；数据所有权；私有化部署。 |

对语迹的启发：

- 记录体验要足够轻，不应像写正式作文。
- 时间线、标签、照片、语音和 AI 摘要可以自然结合。
- 本地优先不是一句隐私文案，而是要体现在数据位置、导出、备份、同步配置和 AI 请求透明度上。
- 语迹可以学习时间线和回顾结构，但核心仍是语言学习闭环，而不是通用日记或生活日志。

### 2.2 AI 语言学习与材料转化

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| OpenKoto | https://github.com/hikariming/openkoto | 桌面端 AI 语言学习；多格式材料导入；翻译；词汇提取；语法解释；Tauri + React + Rust 架构。 |
| language-learning-prompts | https://github.com/aoilang/language-learning-prompts | 语言学习 Prompt 集合；可参考写作引导、改写、翻译、解释、练习生成等 prompt 设计。 |

对语迹的启发：

- Prompt Preset 应作为一等能力设计，而不是隐藏在代码中的固定 system prompt。
- 语迹的默认 Prompt Preset 应覆盖自然表达、简化表达、口语表达、正式表达、逐句讲解、词句提取、写作检查等场景。
- 用户自定义 Prompt Preset 应有可复制、可导入导出、可按语种启用的管理方式。
- AI 生成结果需要保留模型、Provider、Prompt Preset、生成时间和用户反馈，方便后续追踪质量。

### 2.3 跟读、TTS、录音和 Shadowing

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| EchoTalk | https://github.com/alisolphp/EchoTalk | 离线 Shadowing；录音；TTS；重复播放；练习历史；IndexedDB；PWA 本地存储。 |

对语迹的启发：

- 跟读不是一个播放按钮，而应包含逐句播放、循环播放、跟读录音、原声对比、练习历史和熟练度记录。
- MVP 可以先做轻量 Shadowing：逐句播放、循环、录音、标记已练习。
- 后续可以再加入发音评分、波形对比、节奏提示和跟读回放。
- 语迹不应变成单纯口语评分工具，跟读功能应始终服务于“自己的生活内容”。

### 2.4 单词本、词典、句子挖掘和复习

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| VocabSieve | https://github.com/FreeLanguageTools/vocabsieve | 查词、句子挖掘、词典导入、发音、频率表、本地优先、阅读摘录转 Anki。 |
| Anki | https://github.com/ankitects/anki | 间隔重复系统；卡片模型；学习历史；同步冲突处理。 |
| Ulangi | https://github.com/subconcept-labs/ulangi | 内置词典、翻译、TTS、图片搜索、间隔重复、写作、quiz；移动端语言学习结构。 |

对语迹的启发：

- 单词本不应只保存单词释义，还应保存来源句、原始生活记录、AI 生成版本、音频、用户笔记和复习状态。
- 句子挖掘比孤立背词更符合语迹定位。
- 词典导入是高级用户会重视的能力，应预留本地词典资源管理。
- 间隔重复可以借鉴成熟模型，但语迹的复习对象应包括词、短语、句型、整句、错误模式和照片相关表达。

### 2.5 阅读型语言学习

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| LinguaCafe | https://github.com/simjanos-dev/LinguaCafe | 自托管语言阅读学习；阅读、查生词、复习；支持多语言；DeepL API 和 Anki API 集成。 |
| Lute v3 | https://github.com/LuteOrg/lute-v3 | Learning Using Texts；Python/Flask 实现；文本阅读、生词标注、学习进度模型。 |
| Readest | https://github.com/readest/readest | 跨平台电子书阅读器；macOS、Windows、Linux、Android、iOS、Web；词典/Wikipedia 查询、翻译、TTS、多端同步。 |

对语迹的启发：

- 语迹不以外部阅读材料为核心，但“逐句阅读 + 点词查询 + 生词状态 + TTS”这套交互可复用到 AI 生成文本上。
- 目标语言内容需要良好的阅读视图：逐句对齐、点词、收藏、朗读、显示/隐藏母语、练习状态。
- Readest 对跨端阅读体验、TTS、翻译和同步的处理值得研究。

### 2.6 课程、练习和记忆系统

| 项目 | GitHub 地址 | 可参考点 |
|---|---|---|
| LibreLingo | https://github.com/kantord/LibreLingo | 开源语言学习平台；互动练习、间隔重复、进度保存、多设备同步；Web App 使用 Svelte + PouchDB。 |
| Anki | https://github.com/ankitects/anki | 间隔重复、卡片模型、复习调度、学习历史、同步冲突处理。 |

对语迹的启发：

- 语迹可以有练习系统，但不宜课程化。
- 练习题应从用户自己的记录、AI 生成文本、收藏词句和错误模式中动态生成。
- 复习调度应服务于长期语言记忆，而不是强迫用户完成平台课程。

## 3. 与语迹核心能力的映射

| 语迹核心能力 | 主要参考项目 | 研究重点 |
|---|---|---|
| 生活记录与时间线 | Memex / Dayflow / Memos | 快速记录、时间线、标签、附件、本地数据、回顾。 |
| 照片/语音/文本碎片组织 | Memex | 多模态输入如何变成可检索、可组织的个人材料。 |
| AI 转目标语言 | OpenKoto / language-learning-prompts | Prompt Preset、翻译、改写、解释、词汇提取、输出结构。 |
| 朗读与跟读 | EchoTalk | TTS、循环播放、录音、Shadowing、练习历史。 |
| 听写与回译 | EchoTalk / LibreLingo | 练习状态、答案检查、训练记录、错题沉淀。 |
| 单词本与词典 | VocabSieve / Ulangi / Anki | 词典导入、查词、例句、发音、频率、复习调度。 |
| 阅读视图与点词 | LinguaCafe / Lute v3 / Readest | 文本分句、词状态、查词、TTS、阅读进度。 |
| 本地优先与自定义 AI | Memex / Dayflow / VocabSieve | 本地存储、BYOK、多 Provider、数据导出。 |
| 多端同步 | Readest / LibreLingo / Anki | 同步数据边界、冲突处理、离线状态、复习历史一致性。 |
| 长期记忆与向量化 | Memex / Dayflow | 个人数据组织、AI 总结、语义搜索、历史召回。 |

## 4. 后续阅读本地源码时的研究清单

阅读每个项目源码时，建议按以下问题记录：

- 许可证：项目使用 MIT、Apache、GPL、AGPL 还是其他许可证？是否适合商业闭源参考？
- 技术栈：桌面端、移动端、Web、PWA、数据库、同步方案分别是什么？
- 数据模型：记录、文本、单词、句子、练习、音频、附件如何建模？
- 本地存储：使用 SQLite、IndexedDB、文件系统、PouchDB、Realm、Core Data 或其他方案？
- AI 配置：是否支持用户自带 API Key？Provider、模型和 prompt 如何配置？
- TTS/音频：音频如何生成、缓存、播放、循环和关联练习记录？
- 复习系统：复习对象、调度算法、学习历史和错题如何处理？
- 多端同步：同步哪些数据？哪些数据本地生成？冲突如何解决？
- 导入导出：是否支持 Markdown、JSON、Anki、EPUB、PDF、词典文件或完整备份？
- UI 交互：哪些流程可以借鉴，哪些流程会偏离语迹定位？
- 可复用思想：哪些是产品结构或交互思想，哪些是不能直接使用的代码实现？

## 5. 商业闭源开发的许可证原则

语迹计划做收费 App，并且强调本地数据和用户自定义配置。商业开发时要特别注意开源许可证：

以下为 2026-05-16 打开 GitHub 页面时的许可证快照。后续真正下载源码、引用代码或引入依赖前，仍应以仓库当时的 `LICENSE` 文件和依赖清单为准。

| 项目 | 当前看到的许可证 | 商业闭源参考建议 |
|---|---|---|
| Memex | GPL-3.0 | 可重点研究产品结构、本地优先和 AI 组织方式；不要复制代码进闭源 App。 |
| OpenKoto | Apache License 2.0 | 许可证相对友好，可研究桌面端架构、Tauri + React + Rust 组合和 AI 材料处理流程。 |
| EchoTalk | MIT | 许可证相对友好，可重点研究 Shadowing、PWA、本地录音和 TTS 练习交互。 |
| VocabSieve | GPL-3.0 | 可研究词典、句子挖掘和 Anki 工作流；闭源实现时应自行重写。 |
| Ulangi | GPL-3.0，仓库已归档 | 可研究移动端语言学习产品结构；闭源实现时不要复制代码。 |
| LinguaCafe | GPL-3.0 | 可研究自托管阅读学习、点词和复习模型；依赖也较多，需单独审查。 |
| Lute v3 | MIT | 可研究轻量文本学习、生词标注和学习进度模型。 |
| Readest | AGPL-3.0 | 可研究跨端阅读、TTS、翻译和同步思路；闭源实现时不要复制代码。 |
| LibreLingo | AGPL-3.0 | 可研究练习系统和课程数据结构；闭源实现时不要复制代码。 |
| Anki | AGPL-3.0 or later，含部分 BSD / MIT / Apache 等组件 | 可研究复习调度、学习历史和同步冲突思路；闭源实现时应避免直接复用核心代码。 |
| Dayflow | MIT | 可研究 Mac 本地优先、时间线、AI Provider 配置和隐私体验。 |
| Memos | MIT | 可研究轻量记录流、时间线、Markdown 数据和自托管部署。 |
| language-learning-prompts | CC0-1.0 | 可作为 prompt 类型灵感来源，但语迹应改写为自己的 Prompt Preset 体系。 |

- GPL / AGPL 项目可以研究产品结构、数据模型、交互方式和技术路线，但不能直接复制代码进闭源商业项目，否则可能触发开源义务。
- MIT / Apache / BSD 等宽松许可证项目相对容易复用，但仍需保留许可证声明并遵守原项目要求。
- 即使许可证允许，也应避免把参考项目变成语迹的直接拼装；语迹的核心差异应是“生活记录驱动的个人语言记忆系统”。
- 对许可证不确定的项目，在实际引用代码、复制配置、使用资源或改造模块前，应单独做许可证审查。

建议原则：

> 优先参考产品结构、交互逻辑、数据模型和技术方案；真正实现时自己重写，或者只使用许可证兼容的库。

## 6. 语迹需要保持的边界

研究开源项目时，必须避免语迹被带偏：

- 不做通用 AI 笔记工具：Memex、Dayflow 可参考本地优先和 AI 组织，但语迹的主闭环是语言学习。
- 不做纯阅读工具：LinguaCafe、Lute、Readest 可参考阅读和点词，但语迹的材料主要来自用户生活。
- 不做纯 Anki 替代品：Anki 的调度和模型值得研究，但语迹的复习应回到生活上下文。
- 不做单一 Shadowing 工具：EchoTalk 的练习模式很重要，但语迹还包含写作、转换、回译、词句积累和长期记忆。
- 不做课程平台：LibreLingo 可参考练习和数据结构，但语迹不应以课程树驱动。

语迹的核心仍应是：

> 用生活记录学习语言。  
> Learn languages from your life.

## 7. 推荐研究顺序

### 7.1 第一批：核心闭环

1. Memex：生活记录、本地优先、AI 组织、多模态片段。
2. OpenKoto：AI 语言学习、桌面端架构、材料转化、词汇提取。
3. EchoTalk：Shadowing、TTS、录音、本地练习。
4. VocabSieve：单词本、词典导入、句子挖掘、本地优先。
5. Ulangi：移动端语言学习、TTS、间隔重复、词典和练习结构。

### 7.2 第二批：阅读、复习和同步

1. LinguaCafe：阅读、点词、生词复习、多语言支持。
2. Lute v3：轻量文本学习模型。
3. Readest：跨端阅读、TTS、翻译和同步。
4. LibreLingo：练习系统、课程数据结构、PouchDB 同步。
5. Anki：间隔重复、卡片模型、学习历史、同步冲突。

### 7.3 第三批：Prompt 设计

1. language-learning-prompts：整理可迁移的 prompt 类型。
2. 将可用 prompt 思路改写成语迹自己的 Prompt Preset。
3. 为每个 Prompt Preset 定义输入、输出结构、适用语种、适用水平和是否进入长期记忆。

## 8. 后续落地建议

后续研究本地源码时，建议不要只看功能列表，而要形成模块级调研笔记：

- 每个项目单独建一份阅读记录。
- 每份记录包含许可证、技术栈、核心数据模型、值得参考的交互、不能复用的部分。
- 对可借鉴内容按语迹模块归档：记录、AI 生成、TTS、练习、词典、复习、同步、向量记忆。
- 每次把调研结论回写到 `docs/product-main-reference.md` 或更细的设计文档中，避免只停留在源码阅读笔记里。
