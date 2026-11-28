import SwiftUI
import UIKit

/// Where each visible row sits on screen, by song id. Held in a plain object rather than in view
/// state: it changes on every frame of a scroll, and nothing should redraw because of it.
final class RowFrameBox {
    var frames: [String: CGRect] = [:]
}

private struct RowFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Reports this row's frame (global space) under `id`, for ``TwoFingerSelect``.
    func reportsRowFrame(id: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: RowFramesKey.self, value: [id: proxy.frame(in: .global)])
        })
    }

    /// Keeps `box` current with the frames the rows below report.
    func trackingRowFrames(in box: RowFrameBox) -> some View {
        onPreferenceChange(RowFramesKey.self) { box.frames = $0 }
    }
}

/// Select by dragging two fingers down (or up) the list, as in the Files app: the row under the
/// fingers when they land decides whether the drag selects or deselects, and every row the fingers
/// pass over follows. One finger still scrolls; the list is held still only while two are down.
struct TwoFingerSelect: UIViewRepresentable {
    let frames: RowFrameBox
    /// The ids of the rows in the order shown.
    let ids: () -> [String]
    let current: () -> Set<String>
    let apply: (Set<String>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onWindow = { [weak coordinator = context.coordinator] view in coordinator?.attach(near: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.frames = frames
        coordinator.ids = ids
        coordinator.current = current
        coordinator.apply = apply
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class AnchorView: UIView {
        var onWindow: ((UIView) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { DispatchQueue.main.async { [weak self] in if let self { self.onWindow?(self) } } }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var frames = RowFrameBox()
        var ids: () -> [String] = { [] }
        var current: () -> Set<String> = { [] }
        var apply: (Set<String>) -> Void = { _ in }

        private weak var scrollView: UIScrollView?
        private var recognizer: UIPanGestureRecognizer?
        private var base: Set<String> = []
        private var anchor: Int?
        private var selecting = true
        private var last: Set<String> = []

        func attach(near view: UIView) {
            guard recognizer == nil, let scroll = Self.nearestScrollView(from: view) else { return }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.cancelsTouchesInView = false
            pan.delegate = self
            scroll.addGestureRecognizer(pan)
            scrollView = scroll
            recognizer = pan
        }

        func detach() {
            if let recognizer { scrollView?.removeGestureRecognizer(recognizer) }
            scrollView?.isScrollEnabled = true
            recognizer = nil
        }

        deinit { detach() }

        /// The scroll view that holds the list: the first one found going outwards from `view`.
        private static func nearestScrollView(from view: UIView) -> UIScrollView? {
            var ancestor = view.superview
            while let container = ancestor {
                var queue: [UIView] = [container]
                while !queue.isEmpty {
                    let next = queue.removeFirst()
                    if let scroll = next as? UIScrollView, scroll.bounds.height > 100 { return scroll }
                    queue.append(contentsOf: next.subviews)
                }
                ancestor = container.superview
            }
            return nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc private func pan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                // Two fingers are down: the list stays where it is while they pick rows.
                scrollView?.isScrollEnabled = false
                base = current()
                last = base
                anchor = nil
                update(at: gesture.location(in: nil), start: true)
            case .changed:
                update(at: gesture.location(in: nil), start: false)
            case .ended, .cancelled, .failed:
                scrollView?.isScrollEnabled = true
                anchor = nil
            default:
                break
            }
        }

        private func index(at point: CGPoint, in ids: [String]) -> Int? {
            for (offset, id) in ids.enumerated() {
                if let frame = frames.frames[id], point.y >= frame.minY, point.y < frame.maxY { return offset }
            }
            return nil
        }

        private func update(at point: CGPoint, start: Bool) {
            let ids = ids()
            guard let hit = index(at: point, in: ids) else { return }
            if anchor == nil {
                anchor = hit
                // The first row decides the mode: a drag that starts on a selected row clears.
                selecting = !base.contains(ids[hit])
            }
            guard let anchor else { return }
            let range = Set(ids[min(anchor, hit)...max(anchor, hit)])
            let result = selecting ? base.union(range) : base.subtracting(range)
            guard result != last else { return }
            last = result
            Haptics.shared.play(.select)
            apply(result)
        }
    }
}
