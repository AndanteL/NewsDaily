import SwiftUI
import AppKit

struct SelectableTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let onSelection: (String, NSRect) -> Void

    func makeNSView(context: Context) -> SelectableNSTextView {
        let view = SelectableNSTextView()
        view.onSelection = onSelection
        view.updateText(attributedText)
        return view
    }

    func updateNSView(_ nsView: SelectableNSTextView, context: Context) {
        nsView.updateText(attributedText)
        nsView.onSelection = onSelection
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {}
}

final class SelectableNSTextView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    var onSelection: ((String, NSRect) -> Void)?
    private var lastSelectedRange: NSRange = .init(location: 0, length: 0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textColor = NSColor.labelColor
        textView.delegate = self
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    func updateText(_ attributed: NSAttributedString) {
        let current = textView.textStorage?.string
        if current != attributed.string {
            textView.textStorage?.setAttributedString(attributed)
        }
    }
}

extension SelectableNSTextView: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        let range = textView.selectedRange()
        guard range.length > 0, range.location != NSNotFound, range != lastSelectedRange else {
            lastSelectedRange = range
            return
        }
        lastSelectedRange = range
        let selected = (textView.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, selected.count <= 400 else { return }

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let containerOrigin = textView.textContainerOrigin
        let viewRect = NSRect(
            x: rect.origin.x + containerOrigin.x,
            y: rect.origin.y + containerOrigin.y,
            width: rect.width,
            height: rect.height
        )
        let windowRect = convert(viewRect, to: nil)
        DispatchQueue.main.async {
            self.onSelection?(selected, windowRect)
        }
    }
}
