import AppKit
import SwiftUI
import Testing
@testable import PrismNative

@Suite("Link preview window geometry")
struct LinkPreviewWindowGeometryTests {
    @Test func firstPresentationUsesPortraitThreeByFour() {
        let frame = LinkPreviewWindowGeometry.frame(
            preferredSize: nil,
            pointer: CGPoint(x: 400, y: 850),
            visibleFrames: [CGRect(x: 0, y: 24, width: 1440, height: 876)]
        )
        #expect(frame.size == CGSize(width: 600, height: 800))
        #expect(frame.origin == CGPoint(x: 412, y: 38))
    }

    @Test func savedFreeformSizeFitsNearestDisplayWithoutGoingOffscreen() {
        let display = CGRect(x: -800, y: 20, width: 800, height: 600)
        let frame = LinkPreviewWindowGeometry.frame(
            preferredSize: CGSize(width: 1000, height: 700),
            pointer: CGPoint(x: -900, y: 200),
            visibleFrames: [display, CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )
        #expect(frame.size == CGSize(width: 800, height: 560))
        #expect(display.contains(frame))
    }

    @Test func tinyDisplayCanFitBelowNormalMinimumAndInvalidSizesFallBack() {
        let display = CGRect(x: 0, y: 0, width: 280, height: 400)
        for size in [CGSize(width: CGFloat.nan, height: 800), CGSize(width: -1, height: 600)] {
            let frame = LinkPreviewWindowGeometry.frame(
                preferredSize: size,
                pointer: CGPoint(x: 200, y: 100),
                visibleFrames: [display]
            )
            #expect(frame.width == 280)
            #expect(abs(frame.height - 280 * 4 / 3) < 0.001)
            #expect(display.contains(frame))
        }
    }
}

@Suite("Link preview panel")
@MainActor
struct LinkPreviewWindowTests {
    @Test func userSizeSurvivesNewControllerButScreenFittingDoesNotOverwriteIt() throws {
        let suite = "LinkPreviewWindowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = LinkPreviewPanelController(defaults: defaults, orderFront: { _ in })
        controller.present(
            content: AnyView(Color.clear), pointer: .zero,
            visibleFrames: [CGRect(x: 0, y: 0, width: 1800, height: 1200)], onClose: {}
        )
        controller.panel.setContentSize(CGSize(width: 900, height: 700))
        controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: controller.panel))
        controller.hide()

        let restored = LinkPreviewPanelController(defaults: defaults, orderFront: { _ in })
        restored.present(
            content: AnyView(Color.clear), pointer: .zero,
            visibleFrames: [CGRect(x: 0, y: 0, width: 600, height: 500)], onClose: {}
        )
        #expect(restored.panel.frame.width == 600)
        restored.hide()
        restored.present(
            content: AnyView(Color.clear), pointer: .zero,
            visibleFrames: [CGRect(x: 0, y: 0, width: 1800, height: 1200)], onClose: {}
        )
        #expect(restored.panel.frame.size == CGSize(width: 900, height: 700))
        restored.hide()
    }

    @Test func panelSupportsResizeAdaptiveContentAndCloseAction() throws {
        let controller = LinkPreviewPanelController(orderFront: { _ in })
        var closeCount = 0
        controller.present(
            content: AnyView(Color.clear), pointer: CGPoint(x: 300, y: 700),
            visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)], onClose: { closeCount += 1 }
        )
        let panel = controller.panel
        #expect(panel.styleMask.contains(.resizable))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.titled))
        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.titleVisibility == .hidden)
        #expect(panel.titlebarAppearsTransparent)
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.contentView?.autoresizingMask.contains([.width, .height]) == true)
        #expect(!panel.isMovableByWindowBackground)
        panel.performClose(nil)
        #expect(closeCount == 1)
        controller.hide()
    }

    @Test func nativeFrameOwnsResizeCornersWithoutAddingSwiftUISafeArea() throws {
        let suite = "LinkPreviewWindowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = LinkPreviewPanelController(defaults: defaults, orderFront: { _ in })
        controller.present(content: AnyView(Color.clear), pointer: .zero,
                           visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 1000)], onClose: {})
        defer { controller.hide() }
        let panel = controller.panel
        let hosting = try #require(panel.contentView as? NSHostingView<AnyView>)
        let frameView = try #require(hosting.superview)

        #expect(panel.frame.size == CGSize(width: 600, height: 800))
        #expect(hosting.frame.size == panel.frame.size)
        #expect(hosting.safeAreaRegions == [])
        #expect(!hosting.mouseDownCanMoveWindow)
        for point in [CGPoint(x: 6, y: 6), CGPoint(x: 594, y: 6), CGPoint(x: 594, y: 794)] {
            let hit = try #require(frameView.hitTest(point))
            #expect(hit !== hosting)
            #expect(!hit.isDescendant(of: hosting))
        }
    }

    @Test func dragRegionOnlyHitsItsOwnBoundsAndForwardsTheOriginalEvent() throws {
        _ = NSApplication.shared
        let window = DragRecordingWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.orderFront(nil)
        window.alphaValue = 0
        defer { window.orderOut(nil) }
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let drag = LinkPreviewWindowDragRegion.DragView(frame: CGRect(x: 50, y: 240, width: 120, height: 40))
        root.addSubview(drag)
        window.contentView = root
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x: 80, y: 260), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))

        #expect(root.hitTest(CGPoint(x: 80, y: 260)) === drag)
        #expect(root.hitTest(CGPoint(x: 80, y: 150)) !== drag)
        #expect(!drag.acceptsFirstResponder)
        #expect(!drag.mouseDownCanMoveWindow)
        drag.mouseDown(with: event)

        #expect(window.dragEvent === event)
    }

    @Test func repeatedPresentationKeepsUserGeometry() {
        let controller = LinkPreviewPanelController(orderFront: { _ in })
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        controller.present(
            content: AnyView(Color.clear), pointer: CGPoint(x: 300, y: 700),
            visibleFrames: [display], onClose: {}
        )
        let resizedFrame = CGRect(x: 180, y: 100, width: 900, height: 700)
        controller.panel.setFrame(resizedFrame, display: false)

        controller.present(
            content: AnyView(Color.clear), pointer: CGPoint(x: 10, y: 10),
            visibleFrames: [display], onClose: {}
        )

        #expect(controller.panel.frame == resizedFrame)
        controller.hide()
    }
}

@MainActor
private final class DragRecordingWindow: NSWindow {
    private(set) var dragEvent: NSEvent?
    override func performDrag(with event: NSEvent) { dragEvent = event }
}
