# Task Plan: Reading Panel Redesign and Markdown Rendering Fix

**Date**: 2026-06-06  
**Type**: bug-fix + ui-redesign  
**Status**: in-progress

## Background

iOS testing revealed three problems in the UITextView-based reading implementation:

1. **Markdown rendering quality**: `ReadingSelectableTextView` renders unstyled plain text. Headings look identical to body text; bold/italic/code inline runs are computed but never applied to the UITextView. A separate bug: `ReadingMarkdownBlockRenderer.inlinePresentation` maps `.plain` inline run kind to `.emphasis` role.
2. **"听" button silent**: `playSelectionSentence` always plays `containingSentence` regardless of selection scope. For a text fragment selection (a word or phrase), users expect to hear that word/phrase pronounced. Playing the full containing sentence is unexpected and may be inaudible to users who expect word-level TTS.
3. **Learning panel button semantics**: "解释" already returns `meaningInNativeLanguage` (= translation) and `usageNote` (≈ grammar). The "More" menu with disabled "翻译" and "语法分析" buttons is dead UI that creates false affordance.

## Decision

1. Apply `NSAttributedString` styling to `ReadingSelectableTextView` based on block kind and inline runs — heading fonts (title2/title3/headline), body, italic blockquote, monospaced code block, bold/italic/code inline formatting.
2. Fix `playSelectionSentence`: `.textFragment` scope plays `selectedText`; `.sentence` scope plays `containingSentence`. Use a fragment-specific cache key.
3. Extend `ReadingSelectionExplanationResult` with `grammaticalNote: String?`. Remove the "More" menu. Redesign the result area to show all structured fields.

## Scope

**Core** (`LangoTraceCore`):
- `ReadingAppearance.swift`: Add `.plain` to `ReadingInlineRole`
- `ReadingAIExplanation.swift`: Add `grammaticalNote: String?`; bump schema version to `reading_selection_explanation.v2`

**UI** (`LangoTraceUI`):
- `ReadingMarkdownBlockRenderer.swift`: Fix `.plain` → `.plain` inline role mapping
- `ReadingSelectableTextView.swift`: Accept `blockKind`, `inlineRuns`, `lineSpacing`; build `NSAttributedString`
- `ReadingDocumentStore.swift`: Fix `playSelectionSentence` for fragment scope
- `ReadingViewComponents.swift`: Remove "More" menu; redesign result area; add new localization strings
- `ReadingViews.swift`: Pass new parameters to `ReadingSelectableTextView`
- `Localizable.xcstrings`: Add result label strings

**Tests**:
- Update `.sample()` helpers in AI/TTS and selection test files for new schema fields

## TDD Touchpoints

- No new unit test required for attributed string rendering (UIKit layout, can't auto-verify). Existing rendering tests already cover the selection path.
- `ReadingDocumentStore` TTS change is behavior on the store, covered by existing test infrastructure.
- Schema extension: update existing `.sample()` helpers; existing tests verify `explanationResult` fields are populated.

## Verification

```bash
swift test --package-path Packages/LangoTraceCore --filter ReadingTextSegmentation
swift test --package-path Packages/LangoTraceUI --filter ReadingDocumentStore
swift test --package-path Packages/LangoTraceUI --filter ReadingSelection
```

Manual: Build iOS simulator, open reading document, verify heading font vs body font difference, verify bold/italic inline styling, verify 听 plays selected word, verify panel shows translation + grammar.

## Risks

- `NSAttributedString` rendering with `UITextView.attributedText` resets selection state; mitigated by only rebuilding when text or block kind changes (Coordinator tracks `lastRenderedText` + `lastRenderedKind`).
- Adding `grammaticalNote` as optional means AI responses that don't populate it will show no grammar section — acceptable fallback.
- Early stage: no migration needed for persisted data (schema version bump is for AI response identification only, not DB schema).
