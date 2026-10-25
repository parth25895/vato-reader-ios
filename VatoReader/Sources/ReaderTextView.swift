import SwiftUI
import UIKit

struct ScrollRequest: Equatable {
    let token = UUID()
    let off: Int
}

/// A read-only UITextView that supports highlight / bookmark actions on selection,
/// reports the character offset at the reading line (30% from the top) and can
/// scroll back to an exact character offset.
struct ReaderTextView: UIViewRepresentable {
    let vatId: String
    let content: NSAttributedString
    let prefixLen: Int
    let contentKey: String
    let scrollRequest: ScrollRequest?
    let palette: Palette
    let topInset: CGFloat
    let bottomInset: CGFloat
    var onOffset: (Int) -> Void
    var onActivity: () -> Void
    var onHighlight: (NSRange, String?) -> Void
    var onBookmark: (Int) -> Void
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView(usingTextLayoutManager: false)
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainer.lineFragmentPadding = 0
        tv.alwaysBounceVertical = true
        tv.showsVerticalScrollIndicator = false
        tv.contentInsetAdjustmentBehavior = .never
        tv.dataDetectorTypes = []
        tv.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        tv.addGestureRecognizer(tap)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let c = context.coordinator
        c.parent = self
        tv.tintColor = palette.accent
        let inset = UIEdgeInsets(top: topInset, left: 24, bottom: bottomInset, right: 24)
        if tv.textContainerInset != inset { tv.textContainerInset = inset }
        if c.lastKey != contentKey {
            let sameVat = c.lastVatId == vatId
            let keep = tv.contentOffset
            tv.attributedText = content
            c.lastKey = contentKey
            c.lastVatId = vatId
            if sameVat {
                tv.layoutIfNeeded()
                tv.setContentOffset(keep, animated: false)
            }
        }
        if let r = scrollRequest, r.token != c.lastScrollToken {
            c.lastScrollToken = r.token
            c.suppress = true
            let off = r.off
            DispatchQueue.main.async {
                c.scroll(to: off, in: tv)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    c.scroll(to: off, in: tv)
                    c.suppress = false
                }
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: ReaderTextView
        var lastKey: String = ""
        var lastVatId: String = ""
        var lastScrollToken: UUID? = nil
        var suppress = false
        private var offsetWork: DispatchWorkItem? = nil
        private var lastActivity: Date = .distantPast

        init(_ p: ReaderTextView) { parent = p }

        // Character offset (in the vat body) at the reading line
        func anchorOffset(_ tv: UITextView) -> Int {
            let lm = tv.layoutManager
            let y = tv.contentOffset.y + tv.bounds.height * 0.3 - tv.textContainerInset.top
            if y <= 0 { return 0 }
            let idx = lm.characterIndex(for: CGPoint(x: 8, y: y), in: tv.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            return max(0, idx - parent.prefixLen)
        }

        func scroll(to off: Int, in tv: UITextView) {
            let lm = tv.layoutManager
            lm.ensureLayout(for: tv.textContainer)
            tv.layoutIfNeeded()
            let len = tv.attributedText.length
            if off <= 0 || len == 0 {
                tv.setContentOffset(.zero, animated: false)
                return
            }
            let ci = min(len - 1, parent.prefixLen + off)
            let gr = lm.glyphRange(forCharacterRange: NSRange(location: ci, length: 1), actualCharacterRange: nil)
            let rect = lm.boundingRect(forGlyphRange: gr, in: tv.textContainer)
            var y = rect.minY + tv.textContainerInset.top - tv.bounds.height * 0.3
            let maxY = max(0, tv.contentSize.height - tv.bounds.height)
            y = min(max(0, y), maxY)
            tv.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !suppress, let tv = scrollView as? UITextView else { return }
            if Date().timeIntervalSince(lastActivity) > 20 {
                lastActivity = Date()
                parent.onActivity()
            }
            offsetWork?.cancel()
            let w = DispatchWorkItem { [weak self, weak tv] in
                guard let self, let tv, !self.suppress else { return }
                self.parent.onOffset(self.anchorOffset(tv))
            }
            offsetWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
        }

        private func bodyRange(_ r: NSRange) -> NSRange {
            let p = parent.prefixLen
            let s = max(r.location, p)
            let e = max(s, r.location + r.length)
            return NSRange(location: s - p, length: e - s)
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            let body = bodyRange(range)
            guard body.length > 0 else { return UIMenu(children: suggestedActions) }
            let pal = parent.palette
            let colors: [(String, String)] = [("Yellow", "y"), ("Green", "g"), ("Pink", "p"), ("Blue", "b")]
            var items: [UIMenuElement] = colors.map { pair in
                let img = UIImage(systemName: "circle.fill")?.withTintColor(pal.hlColor(pair.1), renderingMode: .alwaysOriginal)
                return UIAction(title: pair.0, image: img) { [weak self, weak textView] _ in
                    self?.parent.onHighlight(body, pair.1)
                    textView?.selectedRange = NSRange(location: 0, length: 0)
                }
            }
            items.append(UIAction(title: "Remove", image: UIImage(systemName: "eraser")) { [weak self, weak textView] _ in
                self?.parent.onHighlight(body, nil)
                textView?.selectedRange = NSRange(location: 0, length: 0)
            })
            items.append(UIAction(title: "Bookmark", image: UIImage(systemName: "bookmark")) { [weak self, weak textView] _ in
                self?.parent.onBookmark(body.location)
                textView?.selectedRange = NSRange(location: 0, length: 0)
            })
            let hlMenu = UIMenu(title: "", options: .displayInline, children: items)
            return UIMenu(children: [hlMenu] + suggestedActions)
        }

        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let tv = g.view as? UITextView else { return }
            if tv.selectedRange.length == 0 { parent.onTap() }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
