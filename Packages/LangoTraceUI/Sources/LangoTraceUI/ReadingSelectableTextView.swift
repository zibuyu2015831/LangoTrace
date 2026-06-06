import Foundation
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
struct ReadingSelectableTextView: UIViewRepresentable {
    let blockText: String
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
        if textView.text != blockText {
            textView.text = blockText
        }
        context.coordinator.blockText = blockText
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onSelectionCleared = onSelectionCleared

        applyCommittedHighlight(to: textView)

        // Compute intrinsic height so SwiftUI can size the view correctly
        let proposedWidth = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
        let size = textView.sizeThatFits(CGSize(width: proposedWidth, height: .greatestFiniteMagnitude))
        if abs(size.height - height) > 0.5 {
            DispatchQueue.main.async { self.height = size.height }
        }
    }

    private func applyCommittedHighlight(to textView: UITextView) {
        // Clear any prior highlight attributes
        let fullRange = NSRange(location: 0, length: (textView.text as NSString).length)
        textView.textStorage.removeAttribute(.backgroundColor, range: fullRange)

        if let range = committedHighlightRange {
            let highlightColor = UIColor.systemYellow.withAlphaComponent(0.35)
            textView.textStorage.addAttribute(.backgroundColor, value: highlightColor, range: range)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var blockText: String
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

#elseif canImport(AppKit)
import AppKit

/// A SwiftUI-hosted NSTextView that exposes system text selection events via callbacks.
/// Does NOT wrap in NSScrollView — SwiftUI manages layout and scrolling.
struct ReadingSelectableTextView: NSViewRepresentable {
    let blockText: String
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
        if nsView.string != blockText {
            nsView.string = blockText
        }
        context.coordinator.blockText = blockText
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onSelectionCleared = onSelectionCleared

        applyCommittedHighlight(to: nsView)
    }

    private func applyCommittedHighlight(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)

        if let range = committedHighlightRange {
            storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), range: range)
        }
    }

    final class Coordinator: NSObject {
        var blockText: String
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
            guard let textView = textView else { return }
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
