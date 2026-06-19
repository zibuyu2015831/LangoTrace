# 02 iOS / iPad / macOS 三端同步审查

状态：Verified

## 1. 审查目标

建立三端功能矩阵，明确每项能力在 iOS、iPadOS 和 macOS 的状态：`Implemented`、`Partially Implemented`、`Mock Only`、`Unavailable UI`、`Not Wired`、`Doc Drift` 或 `Unknown`。

## 2. 三端能力矩阵

| 能力 | iPhone | iPad | macOS | 证据 | 审查备注 |
| --- | --- | --- | --- | --- | --- |
| Welcome / Onboarding / language space recovery | Implemented | Implemented | Implemented | `docs/platform-page-inventory.md:30-36`、`LangoTraceRootView.swift`、`AppEnvironment.swift` | 后续仍需动态字体、无障碍和失败恢复人工验证。 |
| 语言空间新增、切换、重命名、删除 | Implemented | Implemented | Implemented | `docs/platform-page-inventory.md:59-60`、`docs/platform-page-inventory.md:84`、`docs/platform-page-inventory.md:109`、`LanguageSpaceManagementView.swift` | 共享 App lifecycle actions；App 层失败反馈还需继续审查。 |
| 记录创建、记录详情、学习材料生成、取消、编辑 derived text | Implemented | Implemented | Implemented | `docs/platform-page-inventory.md:44-49`、`docs/platform-page-inventory.md:74-78`、`docs/platform-page-inventory.md:99-102`、`EntryDetailView`、`LearningContentStore` | 文档声明为三端共享真实 action seam；仍需平台人工验收大屏布局和创建失败恢复。 |
| 逐句 `听` TTS 生成 / 缓存 / 播放 | Implemented / TTS Playback | Implemented / TTS Playback | Implemented / TTS Playback | `docs/platform-page-inventory.md:50`、`docs/platform-page-inventory.md:79`、`docs/platform-page-inventory.md:128`、`SentenceAudioPlaybackActions` | 自动化覆盖 coordinator / store；未执行本轮截图或真实 Provider 人工播放。 |
| 练习会话、跟读、听写、评分 | Mock Only | Mock Only | Mock Only | `docs/platform-page-inventory.md:52`、`docs/platform-page-inventory.md:79`、`docs/platform-page-inventory.md:104` | UI step 存在；真实录音、Speech、评分未接入。 |
| AI Provider 设置保存和合成 probe | Implemented | Implemented | Implemented | `docs/platform-page-inventory.md:56`、`docs/platform-page-inventory.md:81`、`docs/platform-page-inventory.md:108` | 三端共享表单和 action seam；真网人工复核依赖可控 Provider / API Key。 |
| 同步设置 | Mock Only | Mock Only | Mock Only | `docs/platform-page-inventory.md:57`、`docs/platform-page-inventory.md:81`、`docs/platform-page-inventory.md:108`、`SyncSettingsView.swift` | Sync package 只有 disabled boundary；见 AUDIT-ARCH-001。 |
| 导入导出 | Unavailable UI | Unavailable UI | Unavailable UI | `docs/platform-page-inventory.md:57-58`、`docs/platform-page-inventory.md:83`、`docs/platform-page-inventory.md:107` | 不打开文件、不导入、不导出。 |
| StoreKit / 购买恢复 | Not Wired | Not Wired | Not Wired | `rg` 未发现 StoreKit / Product / Transaction 实现入口；`docs/release/README.md:1-5` 只有发布目录说明；`docs/README.md` 将 StoreKit 配置列为未完成。 | 买断制仍是核心决策和 release 文档职责，不是当前代码能力。 |
| Photos / Camera / OCR | Local Mock / Not Wired | Not Wired | Not Wired | `PhonePhotoWritingPreviewView`、`LearningContentStore.createMockPhotoWritingEntry()`；`rg` 未发现 PhotosPicker / Vision / Camera 实现入口；`docs/platform-page-inventory.md:45` | iPhone 有照片写作预览但不读照片、不 OCR、不调用 AI；iPad / macOS 没有真实照片导入能力。 |
| 录音 / Speech Recognition | Not Wired | Not Wired | Not Wired | `rg` 未发现 SFSpeech / Microphone / recording 实现入口；`Packages/LangoTraceSpeech` 当前承接 TTS audio validation / playback，不是录音或 ASR。 | 练习跟读、听写和评分仍是 mock；后续需权限方案。 |

## 3. 问题清单

已记录：

- AUDIT-ARCH-003：语言空间切换后 `LearningContentStore` 可能保持旧 `spaceID`，影响 iPhone / iPad / macOS 三端共享主流程。

暂未从第一批矩阵发现三端核心路径“单端已真实完成、其他平台未接线”的 P0 / P1 问题；但同步、导入导出、照片 / OCR、练习语音、StoreKit 均仍是 Mock / Unavailable / Not Wired，不能在产品状态中写成真实能力。
