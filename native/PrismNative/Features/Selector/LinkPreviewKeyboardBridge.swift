import AppKit
import SwiftUI

struct LinkPreviewKeyboardBridge: NSViewRepresentable {
    let onShortcut: @MainActor (Int) -> Bool
    var onZoom: @MainActor (LinkPreviewZoomAction) -> Void = { _ in }
    var onInitialNavigation: @MainActor (LinkPreviewBrowserNavigationAction) -> Bool = { _ in false }
    var onPointerDown: @MainActor (CGPoint) -> Void = { _ in }
    var onResignKey: @MainActor () -> Void = {}

    func makeNSView(context: Context) -> KeyboardView {
        KeyboardView(onZoom: onZoom, onInitialNavigation: onInitialNavigation, onPointerDown: onPointerDown, onResignKey: onResignKey, onShortcut: onShortcut)
    }

    func updateNSView(_ view: KeyboardView, context: Context) {
        view.onShortcut = onShortcut
        view.onZoom = onZoom
        view.onInitialNavigation = onInitialNavigation
        view.onPointerDown = onPointerDown
        view.onResignKey = onResignKey
    }

    static func dismantleNSView(_ view: KeyboardView, coordinator: ()) {
        view.detach()
    }

    @MainActor
    final class KeyboardView: NSView {
        var onShortcut: @MainActor (Int) -> Bool
        var onZoom: @MainActor (LinkPreviewZoomAction) -> Void
        var onInitialNavigation: @MainActor (LinkPreviewBrowserNavigationAction) -> Bool
        var onPointerDown: @MainActor (CGPoint) -> Void
        var onResignKey: @MainActor () -> Void
        private let owner = UUID()
        private weak var installedPanel: LinkPreviewPanel?

        init(
            onZoom: @escaping @MainActor (LinkPreviewZoomAction) -> Void = { _ in },
            onInitialNavigation: @escaping @MainActor (LinkPreviewBrowserNavigationAction) -> Bool = { _ in false },
            onPointerDown: @escaping @MainActor (CGPoint) -> Void = { _ in },
            onResignKey: @escaping @MainActor () -> Void = {},
            onShortcut: @escaping @MainActor (Int) -> Bool
        ) {
            self.onShortcut = onShortcut
            self.onZoom = onZoom
            self.onInitialNavigation = onInitialNavigation
            self.onPointerDown = onPointerDown
            self.onResignKey = onResignKey
            super.init(frame: .zero)
            setAccessibilityElement(false)
        }

        required init?(coder: NSCoder) { nil }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard let panel = window as? LinkPreviewPanel else { return }
            installedPanel = panel
            panel.installBrowserShortcutAction({ [weak self] number in
                self?.onShortcut(number) ?? false
            }, onZoom: { [weak self] action in
                self?.onZoom(action)
            }, onInitialNavigation: { [weak self] action in
                self?.onInitialNavigation(action) ?? false
            }, onPointerDown: { [weak self] point in
                guard let self else { return }
                let local = self.convert(point, from: nil)
                self.onPointerDown(CGPoint(x: local.x - self.bounds.minX,
                                          y: self.isFlipped ? local.y - self.bounds.minY : self.bounds.maxY - local.y))
            }, onResignKey: { [weak self] in
                self?.onResignKey()
            }, owner: owner)
        }

        func detach() {
            installedPanel?.removeBrowserShortcutAction(owner: owner)
            installedPanel = nil
        }
    }
}
