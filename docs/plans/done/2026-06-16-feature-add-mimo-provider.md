# 2026-06-16 Feature: Add MIMO (Xiaomi MiMo) Provider + Python Probe Scripts

## 背景

OpenRouter TTS probe 持续显示"请求被拒"，诊断 NSLog 已恢复以采集下一次构建的 HTTP 状态和 errorBody。  
用户要求：  
1. 新增 MIMO（小米 MiMo）作为 AI Provider，支持文本和 TTS  
2. 为每个 Provider 创建 Python 单测脚本，通过 `.env` 文件传入配置

## MIMO API 事实

- Base URL: `https://api.xiaomimimo.com/v1`  
- Auth: `api-key: KEY`（非 `Authorization: Bearer`）  
- 文本：`POST /chat/completions`，OpenAI 兼容 JSON  
- TTS：`POST /chat/completions`，**非标准**：文本放在 `assistant` role；响应为非流式 JSON，base64 WAV 在 `choices[0].message.audio.data`；`"stream": false`  
- 模型：`mimo-v2.5-pro`（文本）、`mimo-v2.5-tts`（TTS）  
- 声音：Chloe（默认 EN）、茉莉（ZH）等

## 已完成的实现

### Core 包
- `TTSProviderAdapterKind` 新增 `mimoTTS = "mimo_tts"`（`TTSProviderConfiguration.swift`）  
- `AIProviderAdapterKind` 新增 `mimoCompatibleChat = "mimo_compatible_chat"`（`AIProviderConfiguration.swift`）

### AI 包
- `MimoTTSAdapter` struct：POST `/chat/completions`，`api-key` header，assistant role，base64 WAV 解码（`TTSProviderAdapter.swift`）  
- `MimoCompatibleChatTextAdapter` struct：同 OpenAI 兼容，但用 `api-key` header（`AIProviderTextRequestAdapter.swift`）  
- 两个 adapter switch 各自增加 `case .mimoTTS: MimoTTSAdapter()`（`TTSConfigurationProbeService.swift`、`SentenceTTSGenerationService.swift`）

### UI 包
- 本地 `AIProviderAdapterKind` enum 新增 `.mimoCompatibleChat` case 及 title（`AIProviderSettingsModels.swift`）  
- `coreAdapterKind` 转换 switch 新增 `.mimoCompatibleChat`（`AIProviderDraftConfiguration.swift`）  
- `AIProviderAdapterCapabilityPolicy` switch 新增 `.mimoCompatibleChat`  
- `AIProviderPreset.mimo` 完整实现全部 13 个 switch 分支

### 测试
- `TTSAdapterRequestTests.swift`：MIMO adapter 3 个测试（request 结构、audio 解码、格式报告）  
- `TTSProviderSettingsTests.swift`：MIMO defaults 1 个测试  
- `AIProviderSettingsTests.swift`：preset list 更新包含 `"mimo"`

### Python Probe Scripts
- `scripts/probe/.env.example`：三个 Provider 占位符配置  
- `scripts/probe/probe_openai.py`：文本 + audio/speech TTS  
- `scripts/probe/probe_openrouter.py`：文本 + 多模态 TTS（SSE 解码）  
- `scripts/probe/probe_mimo.py`：文本 + MIMO 格式 TTS（api-key header，assistant role）  
- `.gitignore` 已有 `.env.*` 全局忽略规则，`scripts/probe/.env` 自动被忽略

## 验证状态

```
swift test --package-path Packages/LangoTraceAI   # 149/149 通过 ✓
swift test --package-path Packages/LangoTraceUI   # 375/375 通过 ✓
python3 -m py_compile scripts/probe/probe_openai.py     # OK ✓
python3 -m py_compile scripts/probe/probe_openrouter.py # OK ✓
python3 -m py_compile scripts/probe/probe_mimo.py       # OK ✓
```

2026-06-17 归档前复验：

```
swift test --package-path Packages/LangoTraceAI   # 149/149 通过 ✓
swift test --package-path Packages/LangoTraceUI   # 387/387 通过 ✓
python3 -m py_compile scripts/probe/probe_openai.py scripts/probe/probe_openrouter.py scripts/probe/probe_mimo.py # OK ✓
```

## 待后续跟进

- OpenRouter TTS probe "请求被拒"问题：重新构建后采集 `[LT-TTS-Probe]` NSLog 确认根因
- 在模拟器中实际配置 MIMO API Key 并验证文本 + TTS probe 通过
- 如获得真实 MIMO API Key，可运行 `python3 scripts/probe/probe_mimo.py` 独立验证

## UI 简化记录

- 2026-06-17：移除 AI Provider 设置页 TTS 配置面板中格式选择行和语速控制行的次要提示文案。格式行原有提示"试听优先使用 MP3。"（"MP3 is recommended for previews."），语速行原有提示"调整试听朗读快慢。"（"Adjust how fast the preview is read."）。两行提示信息量有限且增加视觉噪音，已删除。`TTSMenuSettingRow.detailKey` 和 `TTSSpeedSettingRow.detailKey` 改为 `String?`（可选），仅在非 nil 时渲染；`speechFormatControl` 和 `speechSpeedControl` 调用点不再传入 `detailKey`；对应本地化 key 已从 `Localizable.xcstrings` 移除。其他有说明文案的行（如朗读风格）不受影响。

## 文档影响

- `docs/spec/011-tts-provider-configuration-and-playback.md` 已补充 MIMO 当前实现边界：`api-key` header、`/chat/completions` 文本与 TTS 请求形态、assistant role TTS 文本、base64 WAV 响应路径、WAV-only 格式和 `voice_design_prompt` provider parameter allowlist。
- `docs/workflows/add-tts-provider.md` 可参考本次实现更新示例
- 本 plan 完成后移入 `docs/plans/done/`

## 归档状态

状态：Verified
归档日期：2026-06-17
归档依据：代码落点、Python probe 脚本、聚焦 package 测试和长期 TTS 规范补写均已完成；OpenRouter TTS 拒绝和真实 MIMO API Key 现场验证保留为后续跟进项，不阻塞本 Provider 接入任务归档。
