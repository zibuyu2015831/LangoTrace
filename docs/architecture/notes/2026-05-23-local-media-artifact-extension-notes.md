# 本地媒体派生资产扩展备忘录

状态：Accepted
创建日期：2026-05-23

## 适用范围

本备忘录适用于后续本地媒体文件、派生音频、录音、导出产物、音频同步和附件化设计。当前触发任务是逐句分析直接播放 TTS 音频方案，但本备忘录不是该任务的完成记录，也不替代正式 spec、ADR 或 active plan。

## 目的

逐句 TTS 播放讨论确认：LangoTrace 仍处于早期开发阶段，基础设施首次落地时应采用长期可扩展方案，不应为了单个播放按钮引入临时文件缓存、UI 私有状态或不可索引文件名规则。

因此，TTS 音频应作为第一类“本地媒体派生资产”落地，并为后续全文朗读、跟读录音、听写录音、音频同步、导出和附件体系保留统一边界。

## 已有设计留下的扩展点

- `docs/plans/active/2026-05-23-feature-direct-sentence-tts-playback.md` 已采纳 `LocalMediaArtifactStore` 方向：TTS 音频不是临时 UI 缓存，而是本地优先、隐私敏感、可重建的派生媒体资产。
- 第一阶段推荐将媒体文件放在 App 管理的 `Application Support/LangoTrace/MediaArtifacts/` 或等价目录，并默认排除系统备份。
- 文件名和目录名不得包含原文、Entry 标题、用户输入短语、Provider secret、完整 Keychain account 或其他可读敏感信息。
- 媒体文件必须通过 GRDB / SQLite metadata 引用，不允许 SwiftUI View 拼接真实文件路径。
- Metadata 应预留 `sync_policy`、`backup_policy` 和 `export_policy`，即使第一阶段默认 local only、excluded from backup、excluded by default from export。
- TTS artifact key 必须绑定句子来源、文本 hash、目标语言、provider profile、endpoint、adapter kind / version、model、voice、format、speed / style / provider parameters 和 configuration fingerprint。

## 后续任务必须重新决策的问题

- 是否将 `media_artifacts` 设计为通用主表，并为 TTS、录音、导出产物设置扩展表或 typed metadata。
- 全文朗读音频是否复用逐句 TTS artifact，还是生成独立 paragraph / document level artifact。
- 用户跟读录音和听写录音是用户主资产、练习结果附件，还是可删除的练习派生媒体。
- 音频文件是否进入普通导出、可恢复备份、iCloud / WebDAV / S3 / R2 同步；若进入，必须定义 manifest、加密、冲突处理、删除传播和恢复策略。
- 多设备复用 TTS 音频时，是同步音频文件，还是只同步 metadata 后由各设备按需重新生成。
- 批量预生成音频是否需要费用提示、队列、取消、失败恢复、速率限制和磁盘预算。
- 后台播放、锁屏控制、系统音频中断和远程控制中心是否进入 `LangoTraceSpeech` 的长期能力范围。
- 清理策略是否按全局容量、语言空间、artifact type、last accessed at、delete after 或用户手动策略组合执行。

## 不应在当前阶段提前实现的内容

- 不实现跨设备音频同步。
- 不实现批量预生成全文音频。
- 不实现后台播放、锁屏控制或远程控制中心。
- 不实现录音、跟读评分、听写识别或 ASR。
- 不把 TTS 音频纳入默认导出或可恢复备份。
- 不引入全局跨 Entry 文本音频去重；若后续需要，应先评估隐私和删除语义。

## 提升条件

以下任一情况出现时，应将本备忘录中的相关内容提升为正式 spec、architecture 文档或 ADR：

- 新增 `media_artifacts` 数据表、文件目录或附件 manifest。
- TTS 音频进入同步、导出、备份或用户可见资产管理。
- 用户录音、跟读录音或听写录音进入真实持久化。
- 后台音频播放成为产品承诺。
- 引入官方托管 TTS、官方同步音频或跨设备音频复用服务。
