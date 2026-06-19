# 练习录音同步、导出与可恢复备份备忘录

状态：Accepted
创建日期：2026-05-26
适用范围：practice recording、media artifact、sync manifest、export、backup、privacy label。

## 1. 目的

单句跟读录音第一阶段只实现本地录音、metadata 持久化和完成态引用。该能力虽然不做同步、默认导出或可恢复备份，但 schema、media artifact policy 和删除语义会直接影响后续 Sync Engine、导出包、对象存储和隐私标签设计。

本备忘录保存后续设计必须重新检查的边界，避免把第一阶段 local-only 策略误读成长期同步 / 导出决策。

## 2. 当前已落地边界

- `practice_sessions` 保存单句练习内容快照、exercise type、status 和 completed recording reference。
- `practice_recordings` 保存 attempt metadata；完成态只允许引用 ready recording。
- `media_artifacts` 是通用主表，`practice_recording_artifacts` 是练习录音 typed extension metadata。
- completed practice recording 是用户练习证据，不是普通可重建 cache；普通 TTS cache cleanup 或容量 LRU 不得静默删除它。
- 用户录音默认 local-only、excluded from system backup、excluded from default export、不同步。
- 文件缺失或 hash mismatch 时，session 仍保持 completed，录音 source 应进入 unavailable / missing 状态。
- **采纳（E4，2026-06-18）**：听写 / 回译文本作答 `practice_text_attempts`（v23）与练习录音同等对待——同为用户练习证据、本地主数据，不是可重建 cache，默认 local-only、不同步、不默认导出、不入诊断 / 日志、不参与 TTS cache 清理 / LRU。下文第 3 节的导出、可恢复备份、隐私标签、删除与对象存储重新决策范围同样覆盖 attempt 文本；attempt 文本体量虽小，但属于用户真实作答内容，隐私定位与录音一致，不得因“只是文本”而降级处理。

## 3. 后续任务必须重新决策的问题

- 导出：用户是否可以显式导出练习录音；导出包是否包含原始音频、转码音频、metadata、hash、duration 和 session snapshot；默认导出是否仍排除录音。
- 可恢复备份：如果提供完整本机备份，练习录音是否纳入；是否需要端到端加密、manifest、增量校验和恢复后 hash revalidation。
- 同步：Sync Engine 如何表达大文件 media artifact、typed metadata、completed recording reference、缺文件 completed session、tombstone 和删除传播。
- 对象存储：如果使用 S3 / R2 / WebDAV 存储音频对象，object key、content hash、encryption key、upload state、retry、partial upload cleanup 和跨设备恢复策略必须先定义。
- 删除：用户删除 session、删除 recording、删除 Entry、删除 LanguageSpace、清理本地存储和远端删除传播的优先级必须在事务与文件 cleanup 补偿中统一。
- 隐私标签：用户音频一旦进入同步、备份、导出或外部 Provider，App Store privacy labels、隐私政策、权限说明和 App 内披露都必须更新。
- AI / ASR / 评分：后续发音评分或转写若发送录音或转写给 Provider，不能复用当前 TTS 低摩擦边界；必须走新的请求预览和日志边界。

## 4. 当前阶段不应提前实现

- 不把 practice recording 纳入默认同步 manifest。
- 不把 practice recording 纳入默认导出包或可恢复备份。
- 不为未来对象存储预生成远端 object key。
- 不在 UI 中承诺跨设备恢复录音。
- 不把录音转写、评分、波形、音色分析或情绪分析写成已完成能力。

## 5. 提升条件

创建以下任务前必须读取本备忘录，并说明采纳、暂不采纳或提升为正式 spec / architecture / ADR 的处理方式：

- 真实导出或可恢复备份。
- Sync Engine / Adapter / 对象存储。
- 存储管理或清理 UI。
- 发音评分、ASR、听写或语伴语音对话。
- App Store 隐私标签和发布材料收口。
