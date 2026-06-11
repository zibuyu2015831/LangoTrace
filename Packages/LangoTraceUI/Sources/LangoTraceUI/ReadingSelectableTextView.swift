import Foundation
import LangoTraceCore
import SwiftUI

// MARK: - Selection filter

/// Returns true when the selected text contains at least `minimumNonWhitespaceLength`
/// non-whitespace characters. Used to suppress the learning panel for accidental
/// cursor-placement or whitespace-only selections.
func shouldTriggerPanel(for selectedText: String, minimumNonWhitespaceLength: Int = 2) -> Bool {
    selectedText.count(where: { !$0.isWhitespace }) >= minimumNonWhitespaceLength
}

// MARK: - NSRange → Swift character-offset safe conversion

/// Converts an NSRange from UITextView/NSTextView into (characterOffset, characterLength)
/// using Swift String's multi-byte-safe distance calculations.
/// Returns nil when the NSRange cannot be mapped into the string (malformed range).
func characterRange(from nsRange: NSRange, in text: String) -> (offset: Int, length: Int)? {
    guard let range = Range(nsRange, in: text) else { return nil }
    let offset = text.distance(from: text.startIndex, to: range.lowerBound)
    let length = text.distance(from: range.lowerBound, to: range.upperBound)
    return (offset, length)
}

// MARK: - Platform implementations

#if canImport(UIKit)
    import UIKit

    /// UITextView subclass that blocks all responder actions, preventing the system
    /// edit menu (Copy / Translate / Look Up) from being constructed or animated.
    /// `canPerformAction` is queried before the menu is built; returning false here
    /// stops it at the source rather than dismissing it after the animation starts.
    private final class ReadingNonMenuTextView: UITextView {
        override func canPerformAction(_: Selector, withSender _: Any?) -> Bool {
            false
        }
    }

    /// A SwiftUI-hosted UITextView that exposes system text selection events via callbacks.
    /// One instance is created per Markdown block. `isEditable = false`, `isSelectable = true`.
    /// Uses NSAttributedString for block-kind-aware typography (headings, body, blockquote, code)
    /// and inline styling (bold, italic, code spans).
    struct ReadingSelectableTextView: UIViewRepresentable {
        let blockText: String
        let blockKind: ReadingMarkdownBlockKind
        let inlineRuns: [ReadingInlinePresentation]
        let lineSpacing: Double
        let committedHighlightRange: NSRange?
        var explainedSentenceRanges: [NSRange] = []
        var onSelectionChange: (String, Int, Int) -> Void
        var onSelectionCleared: () -> Void
        @Binding var height: CGFloat

        func makeCoordinator() -> Coordinator {
            Coordinator(
                onSelectionChange: onSelectionChange,
                onSelectionCleared: onSelectionCleared
            )
        }

        func makeUIView(context: Context) -> UITextView {
            let textView = ReadingNonMenuTextView(frame: .zero)
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = false
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.delegate = context.coordinator
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return textView
        }

        func updateUIView(_ textView: UITextView, context: Context) {
            context.coordinator.onSelectionChange = onSelectionChange
            context.coordinator.onSelectionCleared = onSelectionCleared

            let needsRebuild =
                context.coordinator.lastRenderedText != blockText
                    || context.coordinator.lastRenderedKind != blockKind
            if needsRebuild {
                let attrStr = Self.makeAttributedString(
                    text: blockText,
                    kind: blockKind,
                    inlineRuns: inlineRuns,
                    lineSpacing: lineSpacing
                )
                textView.attributedText = attrStr
                context.coordinator.lastRenderedText = blockText
                context.coordinator.lastRenderedKind = blockKind
            }
            context.coordinator.blockText = blockText

            let rangesChanged = context.coordinator.lastExplainedRanges != explainedSentenceRanges
            if needsRebuild || rangesChanged {
                applyExplainedUnderlines(to: textView, ranges: explainedSentenceRanges)
                context.coordinator.lastExplainedRanges = explainedSentenceRanges
            }

            context.coordinator.isApplyingCommittedHighlight = true
            applyCommittedHighlight(to: textView)
            if committedHighlightRange != nil {
                // Remove the blue iOS selection handles once the teal highlight is committed.
                // Setting selectedRange triggers textViewDidChangeSelection, which is suppressed
                // by isApplyingCommittedHighlight above. The teal background color is stored in
                // textStorage attributes and is unaffected by this selectedRange assignment.
                textView.selectedRange = NSRange(location: NSNotFound, length: 0)
            }
            context.coordinator.isApplyingCommittedHighlight = false

            let proposedWidth = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
            let size = textView.sizeThatFits(CGSize(width: proposedWidth, height: .greatestFiniteMagnitude))
            if abs(size.height - height) > 0.5 {
                DispatchQueue.main.async { height = size.height }
            }
        }

        private func applyCommittedHighlight(to textView: UITextView) {
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.backgroundColor, range: fullRange)

            if let range = committedHighlightRange {
                let highlight = LangoTraceDesign.PlatformColorToken.accentHighlight(
                    lightAlpha: 0.15,
                    darkAlpha: 0.22
                )
                storage.addAttribute(.backgroundColor, value: highlight, range: range)
            }
        }

        private func applyExplainedUnderlines(to textView: UITextView, ranges: [NSRange]) {
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.underlineStyle, range: fullRange)
            storage.removeAttribute(.underlineColor, range: fullRange)
            guard !ranges.isEmpty else { return }
            let underlineColor = LangoTraceDesign.PlatformColorToken.accentHighlight(
                lightAlpha: 0.55,
                darkAlpha: 0.55
            )
            for range in ranges {
                let clampedLoc = min(range.location, storage.length)
                let safeRange = NSRange(location: clampedLoc, length: min(range.length, storage.length - clampedLoc))
                guard safeRange.length > 0 else { continue }
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue, range: safeRange)
                storage.addAttribute(.underlineColor, value: underlineColor, range: safeRange)
            }
        }

        // MARK: - Attributed string construction

        static func makeAttributedString(
            text: String,
            kind: ReadingMarkdownBlockKind,
            inlineRuns: [ReadingInlinePresentation],
            lineSpacing: Double
        ) -> NSAttributedString {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = CGFloat(lineSpacing)

            let baseFont = blockFont(for: kind)
            let baseColor: UIColor = kind == .blockquote ? .secondaryLabel : .label

            let runsText = inlineRuns.map(\.text).joined()
            if !inlineRuns.isEmpty, runsText == text {
                let result = NSMutableAttributedString()
                for run in inlineRuns {
                    let font = inlineFont(role: run.role, base: baseFont)
                    let color = run.role == .link ? UIColor.link : baseColor
                    var attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraphStyle,
                    ]
                    if run.role == .inlineCode {
                        attrs[.backgroundColor] = UIColor.systemGray6
                    }
                    result.append(NSAttributedString(string: run.text, attributes: attrs))
                }
                return result
            }

            return NSAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle,
            ])
        }

        private static func blockFont(for kind: ReadingMarkdownBlockKind) -> UIFont {
            switch kind {
            case let .heading(level):
                switch level {
                case 1:
                    UIFont.preferredFont(forTextStyle: .title2).withSymbolicTraits(.traitBold)
                case 2:
                    UIFont.preferredFont(forTextStyle: .title3).withSymbolicTraits(.traitBold)
                default:
                    UIFont.preferredFont(forTextStyle: .headline)
                }
            case .blockquote:
                UIFont.preferredFont(forTextStyle: .body).withSymbolicTraits(.traitItalic)
            case .codeBlock:
                UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize - 1,
                    weight: .regular
                )
            default:
                UIFont.preferredFont(forTextStyle: .body)
            }
        }

        private static func inlineFont(role: ReadingInlineRole, base: UIFont) -> UIFont {
            switch role {
            case .plain, .link:
                base
            case .emphasis:
                base.withSymbolicTraits(.traitItalic)
            case .strong:
                base.withSymbolicTraits(.traitBold)
            case .inlineCode:
                UIFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular)
            }
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            var blockText: String
            var lastRenderedText: String = ""
            var lastRenderedKind: ReadingMarkdownBlockKind = .paragraph
            var lastExplainedRanges: [NSRange] = []
            var onSelectionChange: (String, Int, Int) -> Void
            var onSelectionCleared: () -> Void
            /// Guards against re-entrant textViewDidChangeSelection calls triggered by
            /// clearing selectedRange inside applyCommittedHighlight. All paths run on
            /// DispatchQueue.main so there is no cross-thread race.
            var isApplyingCommittedHighlight = false
            private var debounceWork: DispatchWorkItem?

            init(
                onSelectionChange: @escaping (String, Int, Int) -> Void,
                onSelectionCleared: @escaping () -> Void
            ) {
                blockText = ""
                self.onSelectionChange = onSelectionChange
                self.onSelectionCleared = onSelectionCleared
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                guard !isApplyingCommittedHighlight else { return }
                debounceWork?.cancel()
                let nsRange = textView.selectedRange
                guard nsRange.length > 0 else {
                    onSelectionCleared()
                    return
                }
                let text = blockText
                let selChange = onSelectionChange
                let item = DispatchWorkItem { [weak self] in
                    guard self != nil else { return }
                    guard let (offset, length) = characterRange(from: nsRange, in: text) else { return }
                    let selectedText = String((text as NSString).substring(with: nsRange))
                    guard shouldTriggerPanel(for: selectedText) else { return }
                    selChange(selectedText, offset, length)
                }
                debounceWork = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
            }
        }
    }

    private extension UIFont {
        func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
            let descriptor = fontDescriptor.withSymbolicTraits(traits) ?? fontDescriptor
            return UIFont(descriptor: descriptor, size: pointSize)
        }
    }

#elseif canImport(AppKit)
    import AppKit

    /// A SwiftUI-hosted NSTextView that exposes system text selection events via callbacks.
    /// Does NOT wrap in NSScrollView — SwiftUI manages layout and scrolling.
    /// Uses NSAttributedString for block-kind-aware typography and inline styling.
    struct ReadingSelectableTextView: NSViewRepresentable {
        let blockText: String
        let blockKind: ReadingMarkdownBlockKind
        let inlineRuns: [ReadingInlinePresentation]
        let lineSpacing: Double
        let committedHighlightRange: NSRange?
        var explainedSentenceRanges: [NSRange] = []
        var onSelectionChange: (String, Int, Int) -> Void
        var onSelectionCleared: () -> Void
        @Binding var height: CGFloat

        func makeCoordinator() -> Coordinator {
            Coordinator(
                onSelectionChange: onSelectionChange,
                onSelectionCleared: onSelectionCleared
            )
        }

        func makeNSView(context: Context) -> NSTextView {
            let textView = NSTextView(frame: .zero)
            textView.isEditable = false
            textView.isSelectable = true
            textView.backgroundColor = .clear
            textView.drawsBackground = false
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false

            NotificationCenter.default.addObserver(
                context.coordinator,
                selector: #selector(Coordinator.selectionDidChange(_:)),
                name: NSTextView.didChangeSelectionNotification,
                object: textView
            )
            context.coordinator.textView = textView
            return textView
        }

        func updateNSView(_ nsView: NSTextView, context: Context) {
            context.coordinator.onSelectionChange = onSelectionChange
            context.coordinator.onSelectionCleared = onSelectionCleared

            let needsRebuild =
                context.coordinator.lastRenderedText != blockText
                    || context.coordinator.lastRenderedKind != blockKind
            if needsRebuild {
                let attrStr = Self.makeAttributedString(
                    text: blockText,
                    kind: blockKind,
                    inlineRuns: inlineRuns,
                    lineSpacing: lineSpacing
                )
                nsView.textStorage?.setAttributedString(attrStr)
                context.coordinator.lastRenderedText = blockText
                context.coordinator.lastRenderedKind = blockKind
            }
            context.coordinator.blockText = blockText

            let rangesChanged = context.coordinator.lastExplainedRanges != explainedSentenceRanges
            if needsRebuild || rangesChanged {
                applyExplainedUnderlines(to: nsView, ranges: explainedSentenceRanges)
                context.coordinator.lastExplainedRanges = explainedSentenceRanges
            }

            applyCommittedHighlight(to: nsView)

            if let layoutManager = nsView.layoutManager, let textContainer = nsView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let usedHeight = layoutManager.usedRect(for: textContainer).height
                if abs(usedHeight - height) > 0.5 {
                    DispatchQueue.main.async { height = usedHeight }
                }
            }
        }

        private func applyCommittedHighlight(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.backgroundColor, range: fullRange)

            if let range = committedHighlightRange {
                let highlight = LangoTraceDesign.PlatformColorToken.accentHighlight(
                    lightAlpha: 0.15,
                    darkAlpha: 0.22
                )
                storage.addAttribute(.backgroundColor, value: highlight, range: range)
            }
        }

        private func applyExplainedUnderlines(to textView: NSTextView, ranges: [NSRange]) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.underlineStyle, range: fullRange)
            storage.removeAttribute(.underlineColor, range: fullRange)
            guard !ranges.isEmpty else { return }
            let underlineColor = LangoTraceDesign.PlatformColorToken.accentHighlight(
                lightAlpha: 0.55,
                darkAlpha: 0.55
            )
            for range in ranges {
                let clampedLoc = min(range.location, storage.length)
                let safeRange = NSRange(location: clampedLoc, length: min(range.length, storage.length - clampedLoc))
                guard safeRange.length > 0 else { continue }
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.rawValue, range: safeRange)
                storage.addAttribute(.underlineColor, value: underlineColor, range: safeRange)
            }
        }

        // MARK: - Attributed string construction

        static func makeAttributedString(
            text: String,
            kind: ReadingMarkdownBlockKind,
            inlineRuns: [ReadingInlinePresentation],
            lineSpacing: Double
        ) -> NSAttributedString {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = CGFloat(lineSpacing)

            let baseFont = blockFont(for: kind)
            let baseColor: NSColor = kind == .blockquote ? .secondaryLabelColor : .labelColor

            let runsText = inlineRuns.map(\.text).joined()
            if !inlineRuns.isEmpty, runsText == text {
                let result = NSMutableAttributedString()
                for run in inlineRuns {
                    let font = inlineFont(role: run.role, base: baseFont)
                    let color = run.role == .link ? NSColor.linkColor : baseColor
                    var attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraphStyle,
                    ]
                    if run.role == .inlineCode {
                        attrs[.backgroundColor] = NSColor.windowBackgroundColor
                    }
                    result.append(NSAttributedString(string: run.text, attributes: attrs))
                }
                return result
            }

            return NSAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraphStyle,
            ])
        }

        private static func blockFont(for kind: ReadingMarkdownBlockKind) -> NSFont {
            let bodySize = NSFont.systemFontSize
            switch kind {
            case let .heading(level):
                switch level {
                case 1: return NSFont.boldSystemFont(ofSize: bodySize + 6)
                case 2: return NSFont.boldSystemFont(ofSize: bodySize + 3)
                default: return NSFont.boldSystemFont(ofSize: bodySize + 1)
                }
            case .blockquote:
                let base = NSFont.systemFont(ofSize: bodySize)
                return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
            case .codeBlock:
                return NSFont.monospacedSystemFont(ofSize: bodySize - 1, weight: .regular)
            default:
                return NSFont.systemFont(ofSize: bodySize)
            }
        }

        private static func inlineFont(role: ReadingInlineRole, base: NSFont) -> NSFont {
            switch role {
            case .plain, .link:
                base
            case .emphasis:
                NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
            case .strong:
                NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            case .inlineCode:
                NSFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular)
            }
        }

        final class Coordinator: NSObject {
            var blockText: String
            var lastRenderedText: String = ""
            var lastRenderedKind: ReadingMarkdownBlockKind = .paragraph
            var lastExplainedRanges: [NSRange] = []
            var onSelectionChange: (String, Int, Int) -> Void
            var onSelectionCleared: () -> Void
            weak var textView: NSTextView?
            private var debounceWork: DispatchWorkItem?

            init(
                onSelectionChange: @escaping (String, Int, Int) -> Void,
                onSelectionCleared: @escaping () -> Void
            ) {
                blockText = ""
                self.onSelectionChange = onSelectionChange
                self.onSelectionCleared = onSelectionCleared
            }

            @MainActor @objc func selectionDidChange(_: Notification) {
                debounceWork?.cancel()
                guard let textView else { return }
                let nsRange = textView.selectedRange()
                guard nsRange.length > 0 else {
                    onSelectionCleared()
                    return
                }
                let text = blockText
                let selChange = onSelectionChange
                let item = DispatchWorkItem { [weak self] in
                    guard self != nil else { return }
                    guard let (offset, length) = characterRange(from: nsRange, in: text) else { return }
                    let selectedText = String((text as NSString).substring(with: nsRange))
                    guard shouldTriggerPanel(for: selectedText) else { return }
                    selChange(selectedText, offset, length)
                }
                debounceWork = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
            }

            deinit {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
#endif
