import AppKit
import PrismCore
import SwiftUI

struct LinkPreviewDisplay {
    let id: String
    let frame: CGRect
    let visibleFrame: CGRect

    @MainActor static var current: [Self] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return Self(id: CFUUIDCreateString(nil, uuid) as String, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }
}

@MainActor
protocol LinkPreviewPanelControlling: AnyObject {
    func present(content: AnyView, pointer: CGPoint, visibleFrames: [CGRect], onClose: @escaping @MainActor () -> Void)
    func hide()
}

@MainActor
private final class LinkPreviewHostingView: NSHostingView<AnyView> {
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

@MainActor
final class LinkPreviewPanelController: NSObject, LinkPreviewPanelControlling, NSWindowDelegate {
    typealias OrderFront = @MainActor (LinkPreviewPanel) -> Void

    let panel: LinkPreviewPanel
    private var hostingView: NSHostingView<AnyView>?
    private let defaults: UserDefaults
    private let positionMode: @MainActor () -> LinkPreviewPositionMode
    private let displays: @MainActor () -> [LinkPreviewDisplay]
    private let orderFront: OrderFront
    private static let sizeKey = "linkPreview.windowSize"
    private static let positionKey = "linkPreview.windowPosition"
    private var isPresented = false

    init(
        panel: LinkPreviewPanel = LinkPreviewPanel(),
        defaults: UserDefaults = .standard,
        positionMode: @escaping @MainActor () -> LinkPreviewPositionMode = { .followMouse },
        displays: @escaping @MainActor () -> [LinkPreviewDisplay] = { LinkPreviewDisplay.current },
        orderFront: @escaping OrderFront = { $0.makeKeyAndOrderFront(nil) }
    ) {
        self.panel = panel
        self.defaults = defaults
        self.positionMode = positionMode
        self.displays = displays
        self.orderFront = orderFront
        super.init()
        panel.delegate = self
    }

    func present(content: AnyView, pointer: CGPoint, visibleFrames: [CGRect], onClose: @escaping @MainActor () -> Void) {
        panel.closeAction = onClose
        if !isPresented {
            let placement = restoredPlacement()
            let availableFrames = placement.map { [$0.visibleFrame] } ?? visibleFrames
            let frame = LinkPreviewWindowGeometry.frame(
                preferredSize: rememberedSize,
                pointer: pointer,
                visibleFrames: availableFrames,
                restoredOrigin: placement?.origin
            )
            updateSizeLimits(visibleFrame: LinkPreviewWindowGeometry.selectedFrame(for: pointer, from: availableFrames))
            panel.setFrame(frame, display: false)
        }
        let hostingView: NSHostingView<AnyView>
        if let existing = self.hostingView {
            existing.rootView = content
            hostingView = existing
        } else {
            hostingView = LinkPreviewHostingView(rootView: content)
            hostingView.safeAreaRegions = []
            hostingView.frame = CGRect(origin: .zero, size: panel.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            self.hostingView = hostingView
            panel.contentView = hostingView
        }
        hostingView.layoutSubtreeIfNeeded()
        if !isPresented {
            panel.initialFirstResponder = hostingView
            panel.makeFirstResponder(hostingView)
        }
        isPresented = true
        WindowPresentationAnimation.show(panel) { orderFront(panel) }
    }

    func hide() {
        if isPresented, positionMode() == .lastClosedPosition {
            rememberPosition()
        }
        panel.clearBrowserShortcutAction()
        WindowPresentationAnimation.reset(panel)
        panel.orderOut(nil)
        // EmptyView alone keeps SwiftUI focus/hover callbacks and their old web models alive.
        panel.makeFirstResponder(nil)
        panel.initialFirstResponder = nil
        panel.contentView = nil
        hostingView = nil
        panel.closeAction = nil
        isPresented = false
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        let size = panel.frame.size
        guard LinkPreviewWindowGeometry.isValid(size) else { return }
        defaults.set([Double(size.width), Double(size.height)], forKey: Self.sizeKey)
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        updateSizeLimits(visibleFrame: panel.screen?.visibleFrame)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.closeAction?()
        return false
    }

    private var rememberedSize: CGSize? {
        guard let values = defaults.array(forKey: Self.sizeKey) as? [Double], values.count == 2 else { return nil }
        let size = CGSize(width: values[0], height: values[1])
        return LinkPreviewWindowGeometry.isValid(size) ? size : nil
    }

    private func restoredPlacement() -> (origin: CGPoint, visibleFrame: CGRect)? {
        guard positionMode() == .lastClosedPosition,
              let position = defaults.dictionary(forKey: Self.positionKey),
              let id = position["display"] as? String,
              let x = position["x"] as? Double, x.isFinite,
              let y = position["y"] as? Double, y.isFinite,
              let display = displays().first(where: { $0.id == id }) else { return nil }
        let visibleFrame = display.visibleFrame
        return (CGPoint(x: visibleFrame.minX + x, y: visibleFrame.minY + y), visibleFrame)
    }

    private func rememberPosition() {
        let frame = panel.frame
        let overlap = displays().compactMap { display -> (display: LinkPreviewDisplay, area: CGFloat)? in
            let intersection = display.frame.intersection(frame)
            guard !intersection.isEmpty else { return nil }
            return (display, intersection.width * intersection.height)
        }
        guard let display = overlap.max(by: { $0.area < $1.area })?.display else { return }
        defaults.set([
            "display": display.id,
            "x": Double(frame.minX - display.visibleFrame.minX),
            "y": Double(frame.minY - display.visibleFrame.minY),
        ], forKey: Self.positionKey)
    }

    private func updateSizeLimits(visibleFrame: CGRect?) {
        let minimum = LinkPreviewWindowGeometry.minimumSize
        panel.minSize = visibleFrame.map {
            CGSize(width: min(minimum.width, $0.width), height: min(minimum.height, $0.height))
        } ?? minimum
        panel.maxSize = visibleFrame?.size ?? CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }
}
