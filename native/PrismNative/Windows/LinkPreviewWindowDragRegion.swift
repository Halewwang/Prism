import AppKit
import SwiftUI

struct LinkPreviewWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        let view = DragView(frame: .zero)
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {}

    @MainActor
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            guard event.type == .leftMouseDown, let window, event.window === window,
                  window.attachedSheet == nil,
                  bounds.contains(convert(event.locationInWindow, from: nil))
            else { return }
            window.performDrag(with: event)
        }
    }
}
