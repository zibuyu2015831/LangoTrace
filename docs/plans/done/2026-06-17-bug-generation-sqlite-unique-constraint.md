# Bug 修复：生成学习材料失败（SQLite UNIQUE 约束冲突 + 日志 + UI 错误提示）

- **类型**：bugfix
- **日期**：2026-06-17
- **分支**：dev
- **状态**：已完成

---

## 背景

用户在 AI Provider 设置页面完成 OpenRouter 配置，并通过"测试请求"按钮确认 Provider 可用。但点击"生成学习材料"后，仍然失败。由于没有可用日志，无法直接定位原因。

---

## 发现的问题

### 问题 1：无效 SF Symbol 名称导致崩溃告警

**文件**：`Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift`

**现象**：系统日志出现 SwiftUI Fault 告警：

```
No symbol named 'checkmark.lock.fill' found in system symbol set
No symbol named 'xmark.lock.fill' found in system symbol set
```

**修复**：将两个无效 SF Symbol 名称替换为正确名称：

- `"checkmark.lock.fill"` → `"lock.badge.checkmark.fill"`
- `"xmark.lock.fill"` → `"lock.badge.xmark.fill"`

---

### 问题 2：生成失败无日志、UI 错误提示不区分失败原因

**现象**：所有失败状态（网络错误、认证失败、结构化输出错误等）均显示同一条"检查 AI Provider 设置"提示，且控制台无任何有用输出，难以排查。

**修复**：

1. **新增 OSLog 日志**（`LangoTraceApp/AppEnvironment.swift`）：

   - 添加 `import os` 和 module-level `Logger(subsystem: "com.zibuyu.LangoTrace", category: "generation")`
   - 在 `generateMaterial` 和 `analyzeCurrentText` 两个 closure 的所有失败分支中，调用 `generationLogger.error(...)` 输出结构化错误信息
   - OSLog 使用 `privacy: .public` 标注错误类别，确保日志在 Console.app / `log stream` 中可读
   - 采用 `os.Logger` 而非 `print`，日志始终激活，不依赖 `LANGOTRACE_DIAGNOSTICS` 环境变量

2. **细化 UI 错误提示**（`Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift`）：

   - `generationSummaryKey` 按 `display.category` 分支，为 `authenticationFailed`、`networkUnavailable/timeout`、`rateLimited`、`unsupportedModel/invalidStructuredResponse` 返回不同本地化 key
   - `generationStatus` 仅在 `providerNotConfigured`、`credentialMissing`、`unsupportedProvider` 时显示 `.unavailable` badge；其他运行时错误（网络、认证等）显示 `.ready`，不误导用户以为配置有问题

3. **新增本地化字符串**（`Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`）：

   | Key | EN | zh-Hans |
   |-----|----|---------|
   | `entry.rendering.generateLearningMaterial.failedSummary.authFailed` | Authentication failed. Check your credentials in AI Provider settings. | 认证失败。请检查 AI Provider 设置中的密钥配置。 |
   | `entry.rendering.generateLearningMaterial.failedSummary.networkError` | Network error. Check your connection and try again. | 网络错误。请检查网络连接后重试。 |
   | `entry.rendering.generateLearningMaterial.failedSummary.rateLimited` | Rate limited by the provider. Wait a moment and try again. | 请求频率受限。稍等片刻后重试。 |
   | `entry.rendering.generateLearningMaterial.failedSummary.responseError` | The model returned an unsupported response. Make sure your model supports structured JSON output. | 模型返回的格式不受支持。请确认所选模型支持结构化 JSON 输出。 |

---

### 问题 3（根本原因）：SQLite UNIQUE 约束冲突导致第二次生成失败

**文件**：`Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift`

**根本原因**：

AI 服务（`LearningMaterialGenerationService`）对同一 Entry 的每次生成，均产生基于位置的确定性 ID：

```
sentence-0, sentence-1, ...
revision-0, revision-1, ...
memory-0, memory-1, ...
practice-0, practice-1, ...
```

`saveGeneratedMaterial` 会将旧的 material 行标记为 `is_current = 0`，但不删除旧的子行（`learning_material_sentences`、`learning_material_revision_notes`、`memory_candidates`、`practice_candidates`）。第二次生成时，`replaceAnalysisRows` 尝试插入相同 ID 的子行，触发 SQLite UNIQUE 约束冲突（error 19）。

**日志证据**：

```
[com.zibuyu.LangoTrace:generation] generate failed: unknown — SQLite error 19: UNIQUE constraint failed: learning_material_sentences.id
```

**修复**：在 `GRDBLearningContentRepository.replaceAnalysisRows` 中，将所有子行 ID 前缀拼接 `materialID`，确保跨多次生成全局唯一：

```swift
// Before:
let persistedSentenceID = sentence.id  // e.g. "sentence-0"

// After:
let persistedSentenceID = "\(materialID)-\(sentence.id)"  // e.g. "mat-uuid-sentence-0"
```

同步修正 memory candidate 和 practice candidate 中 `sentenceID` 外键引用：

```swift
let persistedSentenceRef = candidate.sentenceID.map { "\(materialID)-\($0)" }
```

`deleteAnalysisRows` 按 `material_id` 列删除，不受影响，向后兼容。

---

## 验证

### TDD 回归测试

在修复前，先在 `GRDBLearningContentRepositoryTests.swift` 中添加会失败的回归测试：

```swift
@Test("Second generation for same entry succeeds without unique constraint violation")
func secondGenerationForSameEntrySucceeds() throws {
    let repository = try makeRepository()
    let entry = try repository.createEntry(sampleDraft(), in: "space-1")
    let first = try repository.saveGeneratedMaterial(
        sampleGenerationResult(entryID: entry.id, spaceID: "space-1"),
        for: entry.id
    )
    let second = try repository.saveGeneratedMaterial(
        sampleGenerationResult(entryID: entry.id, spaceID: "space-1", learningText: "I visited a cafe today."),
        for: entry.id
    )
    #expect(first.id != second.id)
    let current = try repository.currentMaterial(for: entry.id)
    #expect(current?.id == second.id)
    #expect(current?.analysis.sentences.count == 1)
    #expect(current?.analysis.memoryCandidates.count == 1)
    #expect(current?.analysis.practiceCandidates.count == 1)
}
```

- 修复前：测试失败，抛出 SQLite error 19
- 修复后：测试通过

### 全量包测试结果

- `swift test --package-path Packages/LangoTraceData`：144 tests, 0 failed
- `swift test --package-path Packages/LangoTraceUI`：387 tests, 0 failed

---

## 诊断流程回顾

1. 用户反馈"测试请求"通过但生成失败 → 怀疑配置未正确读取
2. 添加 `os.Logger` 日志，重新 build
3. 通过 `scripts/capture-runtime-log --last 15m` 采集日志到 `logs/latest.log`
4. 日志显示 OpenRouter 网络请求成功（约 28s AI 响应），失败发生在持久化阶段
5. 错误信息明确指向 `learning_material_sentences.id` UNIQUE 约束
6. 追溯到 AI 服务使用确定性位置 ID + 旧子行未清理的组合问题
7. 在 Data 层修复（不改 AI 服务），向后兼容

---

## 关联文件

- `LangoTraceApp/AppEnvironment.swift` — 新增 OSLog 日志
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBLearningContentRepository.swift` — ID 前缀修复
- `Packages/LangoTraceData/Tests/LangoTraceDataTests/GRDBLearningContentRepositoryTests.swift` — 回归测试
- `Packages/LangoTraceUI/Sources/LangoTraceUI/AIProviderSettingsView.swift` — SF Symbol 修复
- `Packages/LangoTraceUI/Sources/LangoTraceUI/PhoneMainSupportingViews.swift` — 错误提示细化
- `Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings` — 新增本地化 key
