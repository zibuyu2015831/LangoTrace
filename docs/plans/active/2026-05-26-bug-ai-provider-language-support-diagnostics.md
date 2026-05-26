# AI Provider language support diagnostics

状态：In Progress
类型：bug
创建日期：2026-05-26
最后更新日期：2026-05-26

## User Confirmation

- 2026-05-26: User asked to inspect iPad, iOS, and Mac validation logic for the AI Provider language support failure, add logs where necessary, then continue diagnosis from the latest logs after manual testing.

## Bug Description

During AI Provider testing, the language support row can fail on iPad even though network requests return HTTP 200. Current runtime logs do not expose enough non-sensitive detail to distinguish JSON parsing failure, sample length failure, script mismatch, NaturalLanguage mismatch, or unsupported language context.

## Reproduction

1. Open AI Provider settings on iPad, iPhone, or macOS.
2. Run the AI Provider test request with a configured text endpoint and current language space.
3. Observe whether the language support row fails.
4. Capture runtime logs with `scripts/capture-runtime-log --last 30m`.

## Expected Behavior

The three platforms use the same validation service, and when language support fails, logs identify the non-sensitive local validation stage that failed.

## Actual Behavior

The shared service returns `language_support` as failed, but normal runtime logs only show network activity and high-level probe status. The failing validation stage is not visible.

## Root Cause Analysis

Confidence: 85%

The three platforms already share the same settings view, action seam, configuration service, and language support validator. The missing piece is diagnostics: current validator output collapses all language support validation failures to `invalid_response`, and console / repository diagnostics are gated behind environment variables. This prevents manual iPad testing from producing enough evidence in latest logs.

## Evidence

- `SettingsCapabilityDetailView` constructs `AIProviderSettingsView` with `AIProviderProbeLanguageContext(languageCode: languageSpace.targetLanguageCode)`.
- iPhone `PhoneMainView`, iPad `PadMainSections`, and macOS `MacWorkspaceContentView` all route through `SettingsCapabilityDetailView`.
- `AIProviderConfigurationProbeService` validates language support through `AIProviderLanguageSupportValidator`.
- `AIProviderConfigurationService` excludes language support from persisted profile validation summaries by design, so `ai_provider_validation_events` cannot diagnose the language support row.

## Scope

- Add non-sensitive language support failure reasons to diagnostic attributes.
- Ensure warning/error diagnostics are available in normal runtime logs for manual testing.
- Add regression tests for the diagnostic reason and shared platform seam.

## Out Of Scope

- Do not log model response text or `sample`.
- Do not change probe pass/fail semantics.
- Do not change Provider credentials, request bodies, or privacy boundaries.

## Code Paths

- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderLanguageSupportValidator.swift`
- `Packages/LangoTraceAI/Sources/LangoTraceAI/AIProviderConfigurationProbeService.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticEvent.swift`
- `Packages/LangoTraceCore/Sources/LangoTraceCore/DiagnosticLogger.swift`
- `Packages/LangoTraceData/Sources/LangoTraceData/GRDBDiagnosticEventRepository.swift`
- `LangoTraceApp/AppEnvironment.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderConfigurationProbeServiceTests.swift`
- `Packages/LangoTraceAI/Tests/LangoTraceAITests/AIProviderLanguageSupportValidatorTests.swift`
- `Packages/LangoTraceUI/Tests/LangoTraceUITests/AIProvider/AIProviderSettingsTests.swift`

## Verification

Focused:

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceData
swift test --package-path Packages/LangoTraceAI --filter AIProviderLanguageSupportValidatorTests
swift test --package-path Packages/LangoTraceAI --filter AIProviderConfigurationProbeServiceTests
swift test --package-path Packages/LangoTraceUI --filter AIProviderSettingsTests
```

Full:

```bash
scripts/verify.sh
```

## Implementation Log

- 2026-05-26: Created plan after confirming the issue is diagnostic visibility, not a platform-specific validation fork.
- 2026-05-26: Added non-sensitive `language_support_failure_reason` diagnostics. Current failure reasons are `unsupported_language_code`, `missing_sample_json`, `sample_too_short`, `script_mismatch`, and `natural_language_mismatch`.
- 2026-05-26: Updated normal app diagnostics so warning/error events are written to system logs without requiring `LANGOTRACE_DIAGNOSTICS=1`; setting the environment variable still allows lower log levels.
- 2026-05-26: Verified shared iPhone/iPad/macOS settings seam through `AIProviderSettingsTests`; all three platforms still route through `SettingsCapabilityDetailView -> AIProviderSettingsView`.
- 2026-05-26: Installed and relaunched the updated iPad simulator build for manual retesting. New process PID: `55492`.

## Done Criteria

- Three-platform settings seam remains shared.
- Language support failures include a non-sensitive failure reason in diagnostic attributes.
- Normal runtime logs can show warning/error probe diagnostics without requiring a launch environment override.
- Focused tests pass.

## Remaining Risk

The exact provider response sample still cannot be reconstructed from logs by design. If the new failure reason is ambiguous, a privacy-reviewed temporary local-only capture mechanism would need a separate plan.
