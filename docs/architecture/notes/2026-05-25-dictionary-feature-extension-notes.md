# 词典功能扩展备忘录

状态：Accepted
创建日期：2026-05-25

## 适用范围

本备忘录适用于后续词典查询、系统词典集成、第三方词典 App 跳转、用户导入词典、词句收藏、记忆复习、离线索引和导出同步相关设计。

本备忘录是未来设计输入，不是实现方案，也不替代 `docs/product-main-reference.md`、`docs/spec/007-data-storage-migration-export-and-attachments.md`、`docs/spec/008-permissions-local-privacy-and-diagnostics.md` 或后续 active plan。后续任务采纳其中任一提醒时，必须写回对应 active plan、spec、architecture 或 ADR。

## 目的

词典是语迹学习闭环中的基础工具能力。它应帮助用户围绕自己的生活记录和目标语言句子查询词义、例句、发音和用法，并把有价值的词句沉淀到语言记忆，而不是把 App 变成独立词典产品。

本阶段先记录设计边界，避免后续实现时遗漏以下关键问题：

- 系统词典、第三方词典 App 和用户导入词典不是同一种能力，应通过 provider 抽象隔离。
- 词典查询结果可以辅助学习，但不能覆盖 AI 生成材料、用户原文或正式记忆事实。
- 用户导入词典可能涉及版权、格式解析、索引、发音文件、离线存储和导出边界，不能作为轻量 UI 功能处理。
- 第三方词典跳转依赖 URL scheme、平台权限、安装状态和 App Store 审核边界，必须先做 spike 验证。

## 候选能力分层

### 1. 系统词典查询

Apple 平台存在系统词典相关能力，但 iOS、iPadOS 和 macOS 的承载方式不同。后续设计应把系统词典作为一个可用性受平台限制的 provider：

- iOS / iPadOS 可评估 `UIReferenceLibraryViewController` 或系统 Lookup 相关交互。
- macOS 可评估 `DictionaryServices` / `DCSCopyTextDefinition` 和系统 Dictionary App 的打开方式。
- SwiftUI View 不直接调用 UIKit、AppKit 或 CoreServices；平台适配应放在 App Shell 或平台 service 边界。
- 系统词典不可用时，UI 应明确显示不可用原因，并允许用户选择其他查询方式。

### 2. 第三方词典 App 跳转

用户可能希望查询时跳转到欧路词典等专业词典软件。该能力可行性取决于目标 App 是否公开稳定 URL scheme 或通用链接。

后续实现前必须建立 spike：

- 在 iOS / iPadOS 验证目标 URL scheme、参数编码、`canOpenURL`、`LSApplicationQueriesSchemes` 和未安装时的 fallback。
- 在 macOS 验证 `NSWorkspace.open`、自定义 URL scheme、Universal Link 或命令行打开方式。
- 记录每个第三方词典的安装检测、查询参数、返回语义和失败行为。
- 不把单个第三方 App 写成硬依赖；用户应能选择系统词典、外部 App 或内置导入词典。

### 3. 用户导入词典

用户导入词典是长期能力，不适合与第一版查询 UI 同时仓促落地。后续设计必须先明确：

- 支持格式：例如 CSV / TSV、StarDict、MDX / MDD 或其他开放格式。
- 许可边界：导入文件由用户自备，App 不内置受限制词库；导入提示应避免鼓励侵权。
- 存储边界：词典条目、索引、发音文件和源文件的主数据 / 派生数据分类。
- 查询边界：按语言空间隔离目标语言、查询历史、收藏和例句来源。
- 导出同步：默认不把大体积词典源文件纳入普通同步；如支持备份，应单独设计 manifest、hash 和恢复校验。

## 与当前产品模型的关系

- 词典偏好属于语言空间相关学习配置，不应成为全局唯一设置。
- 查询历史、收藏词句和例句引用应能回到原始 Entry、LearningMaterial 或句子。
- 词典解释可以辅助记忆，但不能替代 AI 生成的修改说明、语法分析或用户确认的语言记忆。
- 词典入口应从句子、词句记忆、练习会话和语伴辅助分析中自然出现，不应抢占记录主流程。

## 后续任务必须重新决策的问题

### 1. Provider 抽象

后续应定义类似 `DictionaryLookupProvider` 的能力边界，至少区分：

- 系统词典 provider。
- 外部 App 跳转 provider。
- 用户导入词典 provider。
- 未来 AI 辅助解释 provider。

Provider 结果需要表达 found、not found、not installed、unsupported language、permission / platform unavailable、external app failed 和 malformed imported dictionary 等稳定状态。

### 2. 数据模型

后续需决定以下对象是否进入 GRDB 主路径：

- 词典源配置。
- 查询历史。
- 收藏词条。
- 用户词句记忆引用。
- 导入词典索引 metadata。
- 外部 App 偏好。

如果导入词典涉及真实文件，必须沿用附件 / 媒体资产边界，不允许散落在临时目录。

### 3. 隐私与日志

词典查询通常低敏，但在语迹中查询词可能来自私人日记、会议、照片 OCR 或语伴对话。日志只能记录能力类型、provider 类型、语言代码、长度分桶和失败分类，不记录完整查询词、完整解释、用户原句或外部 App URL 中的隐私内容。

### 4. 三端交互

- iPhone：词典应是短路径弹出或 sheet 查询，避免打断练习。
- iPad：可在右侧学习面板或 split view 中展示查询结果。
- macOS：可支持快捷键、右键菜单和独立 inspector 风格查询。

三端入口应共享同一 provider / repository contract，不复制平台专属词典业务逻辑。

## 不应在当前阶段提前实现的内容

当前阶段不应直接实现：

- 大规模词典导入和全文索引。
- 内置受版权限制的商业词库。
- 把欧路词典或其他第三方词典写成唯一查询后端。
- 查询时自动发送整句或上下文给外部 AI。
- 把词典解释自动写入长期记忆。
- 默认同步导入词典源文件或发音文件。

## 关联文档

- `docs/product-main-reference.md`
- `docs/technical-framework-roadmap.md`
- `docs/spec/007-data-storage-migration-export-and-attachments.md`
- `docs/spec/008-permissions-local-privacy-and-diagnostics.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
