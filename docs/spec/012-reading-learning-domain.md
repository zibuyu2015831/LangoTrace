# 012: Reading Learning Domain

适用阶段：阅读资料库、阅读导入、Markdown 阅读、阅读选区 AI 解释、reading sentence TTS、词典 lookup 和后续阅读 MVP。

## 1. Domain Position

Reading is a first-class learning scene in LangoTrace, alongside entries, practice and memory. It keeps the product north star `用生活记录学习语言 / Learn languages from your life` unchanged while allowing user-supplied reading materials to become local-first learning inputs.

The first implementation slice supports pasted text, `.txt` and `.md` documents. EPUB, PDF, HTML clip, web article import, dictionary import UI, sync, export, full-document AI summary, full-document translation and batch TTS are future capabilities.

Current implementation entry points are `ReadingLibraryStore`, `ReadingDocumentStore`, `ReadingLibraryView`, `GRDBReadingLibraryRepository`, `ReadingSelectionExplanationService` and `SentenceAudioPlaybackActions` mapping to `readingDocumentSentence`. The current slice supports paste import, `.txt` / `.md` file import, collection / tag assignment and local filtering, title/body editing through a controlled editor sheet, soft delete / restore, explicit selection explanation and explicit reading sentence TTS.

## 2. Reading Documents

`ReadingDocument` is primary local data scoped by `language_space_id`. It must have a stable document id, title, source format, source kind, adapter id/version, body storage kind, body hash, content revision, structure version, target language code, timestamps, import status and soft-delete state.

Document body and library organization are separate concerns. Library summaries may expose title, source format, import status, active/deleted state, tags, collections and last opened time, but must not carry full document text.

`ReadingDocument` is user-owned primary data under the lifecycle rules in `007-data-storage-migration-export-and-attachments.md`. That means pasted text and imported files must not stop at import-only or read-only flows. The feature and page design must default to:

- create or import
- list, search, filter, open and inspect
- update body or metadata through an explicit editing path, or record why that path is deferred
- delete semantics with confirmation, soft delete or restore, and documented downstream effects

The current slice already supports import, library read paths, collection / tag assignment, title/body editing and soft delete / restore. Soft-deleted documents must be restored before editing. If broader batch management is not implemented in a given phase, the active plan must state that explicitly rather than treating the imported document as maintenance-free content.

## 3. Import Boundary

Reading import is adapter-based. The active vertical slice enables only:

- pasted text via `pasted-text.v1`
- plain text file via `plain-text-file.v1`
- Markdown file via `markdown-file.v1`

Future descriptors may exist for EPUB, PDF and HTML clip, but disabled descriptors must not create ready documents. File import must evaluate file type and byte metadata before reading the full body. The app must not persist external absolute paths, security-scoped URLs or user directory structure.

## 4. Markdown Rendering

Markdown import produces LangoTrace-owned structure: blocks, inline runs, source ranges and plain text. The initial renderer contract covers headings, paragraphs, block quotes, ordered and unordered lists, code blocks, horizontal rules, links, emphasis, strong and inline code.

Markdown presentation is controlled by `ReadingAppearanceProfile`. Style is a presentation preference and must not affect body hash, content revision, structure version, source anchor inputs or TTS source keys.

## 5. Selection And Source Anchor

Text selection uses native platform text selection: `UITextView` (iOS/iPadOS) and `NSTextView` (macOS) per Markdown block. Each block is rendered as a continuous, selectable text view — not as a list of sentence buttons. System-native gestures (double-tap = word, long-press + drag = arbitrary fragment, triple-tap = sentence) drive selection.

Sentence data produced by `ReadingTextSegmenter.segmentSentences()` is **retained** as a data-layer and AI-context resource. It is no longer a visual rendering unit. `makeFragmentSelectionContext()` uses pre-computed sentences to identify the `containingSentence`, `previousSentence`, and `nextSentence` for any arbitrary character-range selection.

The supported reading-learning selection scopes are:

- `selection_scope = sentence`
- `selection_scope = text_fragment`

Both scopes produce a fully-populated `ReadingSelectionContext` with `characterOffset`, `characterLength`, `blockID`, `sentenceID` (the containing sentence), and context fields. `makeFragmentSelectionContext(precomputedSentences:)` accepts a pre-computed sentence array to avoid re-running the NLTokenizer on every selection change.

Manual selection records selected text, limited context, character offset and character length, and must not depend on English whitespace tokenization. CJK, Japanese, accented Latin text and RTL snippets are valid inputs. A minimum of 2 non-whitespace characters is required to trigger the learning panel.

`ReadingSourceAnchor` must include document id, content revision, structure version, block id, selected text hash and character range. If content revision, structure version, block id, selected text hash or range no longer matches the current document structure, the anchor is stale and must not silently point at another text.

When sentence selection is used as the default UI path, the sentence identity must still be document-version-bound. A stable selection identity must include document id, content revision, structure version, block id, sentence id or sentence index, selected text hash, character offset and character length. Editing save, document switch, language space switch or structure change must stale the prior anchor and invalidate old explanation or TTS completions.

## 6. AI Explanation

Reading AI explanation is a user-explicit action. The request may contain:

- `selected_text`
- `selection_scope`
- `source_anchor_id`
- `containing_sentence`
- `previous_sentence`
- `next_sentence`
- `containing_paragraph`
- `context_mode`
- `context_text`
- native language, target language, prompt id/version and provider/model metadata

It must not automatically send a full document on import, open, scroll or TTS playback. Selection alone is not enough reason to send a request.

Dynamic context strategy:

- short reading text may use `context_mode = full_document`
- longer reading text may use `context_mode = adjacent_paragraphs`
- if the surrounding window grows too large, fall back to `context_mode = current_paragraph` while still carrying sentence-level context fields

On iPhone / compact, explanation result is no longer carried by a blocking modal sheet. The current implementation uses a non-modal bottom learning panel with explicit `Explain / Listen / More` actions; the compact panel must distinguish `hidden / collapsed / loading / content / failed` so a fresh sentence selection does not immediately expand stale result content. iPad and macOS keep a persistent side inspector while reusing the same selection and request contract.

The UI may show the sending scope near the action or progress state. It must not require a second preview-confirm step for this slice.

## 7. TTS Source

Reading sentence TTS uses `TTSSentenceSource.readingDocumentSentence(documentID:sentenceID:)`. Its canonical key must not collide with entry, learning material or temporary sentence sources. Opening a reading document must not trigger TTS; only an explicit sentence play action may call the playback coordinator.

## 8. Dictionary Extension Boundary

This slice may include an in-memory exact lookup index for synthetic fixtures. Future production dictionary import should use `DictionaryImportAdapter`, dictionary import batches, normalized lookup index, language-specific normalization strategy and lexeme state scoped to learning workflows. LangoTrace must not become a standalone dictionary product and must not ship copyrighted dictionary data without a separate plan.

## 9. Async State Boundary

Reading library and document stores must guard asynchronous import, load, update, AI and TTS operations with request tokens or an equivalent generation counter. Space switch, document switch, selection change, detail close, content revision change after edit save, soft delete of the current document or repeated action must cancel or invalidate in-flight work. Stale completions must not write into current library, document, selection, explanation or audio state.

## Change Log

- 2026-06-03: Clarified that `ReadingDocument` is user-owned primary data and must default to a full lifecycle design rather than import-only behavior.
- 2026-06-03: Updated the current slice facts after landing ReadingDocument title/body editing, controlled editor entry and revision-based stale invalidation.
- 2026-06-03: Updated the selection and presentation contract to sentence-first reading actions, dynamic context modes and non-modal compact learning panel delivery.
- 2026-06-01: Created Reading learning domain spec for the reading AI/TTS vertical slice.
- 2026-06-01: Updated implementation facts after landing the vertical slice. Reading is now a top-level route on iPhone / iPad / macOS with GRDB library actions, paste and file import, collection / tag filters, selection explanation operation summaries and reading sentence TTS wired through AppEnvironment.
