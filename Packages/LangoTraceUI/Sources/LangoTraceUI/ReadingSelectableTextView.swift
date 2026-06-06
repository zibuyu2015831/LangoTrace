import Foundation
import LangoTraceCore
import SwiftUI

// MARK: - Selection filter

/// Returns true when the selected text contains at least `minimumNonWhitespaceLength`
/// non-whitespace characters. Used to suppress the learning panel for accidental
/// cursor-placement or whitespace-only selections.
func shouldTriggerPanel(for selectedText: String, minimumNonWhitespaceLength: Int = 2) -> Bool {
    selectedText.filter { !$0.isWhitespace }.count >= minimumNonWhitespaceLength
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
        let textView = UITextView(frame: .zero)
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

        applyCommittedHighlight(to: textView)

        let proposedWidth = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
        let size = textView.sizeThatFits(CGSize(width: proposedWidth, height: .greatestFiniteMagnitude))
        if abs(size.height - height) > 0.5 {
            DispatchQueue.main.async { self.height = size.height }
        }
    }

    private func applyCommittedHighlight(to textView: UITextView) {
        let storage = textView.textStorage
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)

        if let range = committedHighlightRange {
            let highlight = UIColor.systemYellow.withAlphaComponent(0.35)
            storage.addAttribute(.backgroundColor, value: highlight, range: range)
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
                return UIFont.preferredFont(forTextStyle: .title2).withSymbolicTraits(.traitBold)
            case 2:
                return UIFont.preferredFont(forTextStyle: .title3).withSymbolicTraits(.traitBold)
            default:
                return UIFont.preferredFont(forTextStyle: .headline)
            }
        case .blockquote:
            return UIFont.preferredFont(forTextStyle: .body).withSymbolicTraits(.traitItalic)
        case .codeBlock:
            return UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize - 1,
                weight: .regular
            )
        default:
            return UIFont.preferredFont(forTextStyle: .body)
        }
    }

    private static func inlineFont(role: ReadingInlineRole, base: UIFont) -> UIFont {
        switch role {
        case .plain, .link:
            return base
        case .emphasis:
            return base.withSymbolicTraits(.traitItalic)
        case .strong:
            return base.withSymbolicTraits(.traitBold)
        case .inlineCode:
            return UIFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var blockText: String
        var lastRenderedText: String = ""
        var lastRenderedKind: ReadingMarkdownBlockKind = .paragraph
        var onSelectionChange: (String, Int, Int) -> Void
        var onSelectionCleared: () -> Void
        private var debounceWork: DispatchWorkItem?

        init(
            onSelectionChange: @escaping (String, Int, Int) -> Void,
            onSelectionCleared: @escaping () -> Void
        ) {
            self.blockText = ""
            self.onSelectionChange = onSelectionChange
            self.onSelectionCleared = onSelectionCleared
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
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

        applyCommittedHighlight(to: nsView)
    }

    private func applyCommittedHighlight(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)

        if let range = committedHighlightRange {
            storage.addAttribute(
                .backgroundColor,
                value: NSColor.systemYellow.withAlphaComponent(0.35),
                range: range
            )
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
            return base
        case .emphasis:
            return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        case .strong:
            return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        case .inlineCode:
            return NSFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular)
        }
    }

    final class Coordinator: NSObject {
        var blockText: String
        var lastRenderedText: String = ""
        var lastRenderedKind: ReadingMarkdownBlockKind = .paragraph
        var onSelectionChange: (String, Int, Int) -> Void
        var onSelectionCleared: () -> Void
        weak var textView: NSTextView?
        private var debounceWork: DispatchWorkItem?

        init(
            onSelectionChange: @escaping (String, Int, Int) -> Void,
            onSelectionCleared: @escaping () -> Void
        ) {
            self.blockText = ""
            self.onSelectionChange = onSelectionChange
            self.onSelectionCleared = onSelectionCleared
        }

        @objc func selectionDidChange(_ notification: Notification) {
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
