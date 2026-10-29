import AppKit
import SwiftUI
import Testing
import WebKit
@testable import PrismNative

@Suite("Link preview keyboard")
@MainActor
struct LinkPreviewKeyboardTests {
    @Test func escapeClosesWithoutDependingOnSwiftUIFocus() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var closes = 0
        panel.closeAction = { closes += 1 }

        panel.sendEvent(try key("\u{1b}", code: 53, in: panel))

        #expect(closes == 1)
    }

    @Test func nativeNumbersAreConsumedOnlyWhenTheCurrentHandlerAcceptsThem() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var received: [Int] = []
        panel.browserShortcutAction = { number in received.append(number); return number == 2 }

        #expect(panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("3", code: 20, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("0", code: 29, in: panel)))
        #expect(received == [2, 3])
    }

    @Test func initialHostingFocusHandlesCompactBrowserNavigation() throws {
        _ = NSApplication.shared
        let controller = LinkPreviewPanelController(orderFront: { $0.orderFront(nil) })
        controller.present(content: AnyView(Color.clear), pointer: .zero,
                           visibleFrames: [CGRect(x: 0, y: 0, width: 1200, height: 1000)], onClose: {})
        defer { controller.hide() }
        let panel = controller.panel
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint - 1, height: 800))
        #expect(panel.firstResponder === panel.contentView)
        var actions: [LinkPreviewBrowserNavigationAction] = []
        panel.installBrowserShortcutAction({ _ in false }, onInitialNavigation: {
            actions.append($0)
            return true
        }, owner: UUID())

        for (text, code): (String, UInt16) in [("\u{f700}", 126), ("\u{f701}", 125), ("\r", 36), ("\u{3}", 76)] {
            #expect(panel.handleKeyboardEvent(try key(text, code: code, in: panel)))
        }
        #expect(actions == [.previous, .next, .activate, .activate])
        #expect(!panel.handleKeyboardEvent(try key("\u{f700}", code: 126, modifiers: .command, in: panel)))
        panel.initialBrowserNavigationAction = { _ in false }
        #expect(!panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
    }

    @Test func initialNavigationLeavesWideWindowsNativeControlsAndWebContentAlone() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let root = KeyboardFocusView(frame: CGRect(origin: .zero, size: panel.frame.size))
        panel.contentView = root
        #expect(panel.makeFirstResponder(root))
        var handled = 0
        panel.initialBrowserNavigationAction = { _ in handled += 1; return true }
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint, height: 800))
        #expect(!panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint - 1, height: 800))

        let button = KeyboardFocusButton(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        root.addSubview(button)
        #expect(panel.makeFirstResponder(button))
        for (text, code): (String, UInt16) in [("\u{f700}", 126), ("\u{f701}", 125), ("\r", 36)] {
            #expect(!panel.handleKeyboardEvent(try key(text, code: code, in: panel)))
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: root.bounds, configuration: configuration)
        let content = KeyboardFocusView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        web.addSubview(content)
        root.addSubview(web)
        #expect(panel.makeFirstResponder(content))
        #expect(!panel.handleKeyboardEvent(try key("\u{f700}", code: 126, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
        // Even a web view installed as the content view must retain its own navigation keys.
        panel.contentView = web
        #expect(panel.makeFirstResponder(web))
        #expect(!panel.handleKeyboardEvent(try key("\u{f701}", code: 125, in: panel)))
        #expect(handled == 0)
    }

    @Test func commandZoomShortcutsDoNotBecomeBrowserChoices() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var actions: [LinkPreviewZoomAction] = []
        var browserActions = 0
        panel.pageZoomAction = { actions.append($0) }
        panel.browserShortcutAction = { _ in browserActions += 1; return true }

        for (text, code, modifiers): (String, UInt16, NSEvent.ModifierFlags) in [
            ("=", 24, .command), ("+", 24, .command),
            ("=", 24, [.command, .shift]), ("+", 24, [.command, .shift]),
            ("-", 27, .command), ("0", 29, .command)
        ] {
            #expect(panel.handleKeyboardEvent(try key(text, code: code, modifiers: modifiers, in: panel)))
        }

        #expect(actions == [.zoomIn, .zoomIn, .zoomIn, .zoomIn, .zoomOut, .reset])
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, modifiers: .command, in: panel)))
        #expect(browserActions == 0)
    }

    @Test func commandEquivalentsDispatchZoomOnceBeforeResponderFallback() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var actions: [LinkPreviewZoomAction] = []
        var closes = 0
        panel.pageZoomAction = { actions.append($0) }
        panel.closeAction = { closes += 1 }

        for (text, code, action): (String, UInt16, LinkPreviewZoomAction) in [
            ("=", 24, .zoomIn), ("-", 27, .zoomOut), ("0", 29, .reset)
        ] {
            let event = try key(text, code: code, modifiers: .command, in: panel)
            let previous = actions
            let consumed = panel.performKeyEquivalent(with: event)
            #expect(consumed)
            if !consumed { panel.sendEvent(event) }
            #expect(actions == previous + [action])
        }
        #expect(panel.performKeyEquivalent(with: try key("w", code: 13, modifiers: .command, in: panel)))
        #expect(closes == 1)
        #expect(actions == [.zoomIn, .zoomOut, .reset])
    }

    @Test func zoomWorksWhileNativeInputOrAWebViewDescendantHasFocus() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var actions: [LinkPreviewZoomAction] = []
        panel.pageZoomAction = { actions.append($0) }
        let input = NSTextView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        input.isEditable = true
        panel.contentView = input
        #expect(panel.makeFirstResponder(input))
        #expect(panel.handleKeyboardEvent(try key("=", code: 24, modifiers: .command, in: panel)))

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: panel.frame, configuration: configuration)
        let content = KeyboardFocusView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        web.addSubview(content)
        panel.contentView = web
        #expect(panel.makeFirstResponder(content))
        #expect(panel.handleKeyboardEvent(try key("-", code: 27, modifiers: .command, in: panel)))
        #expect(actions == [.zoomIn, .zoomOut])
    }

    @Test func zoomLeavesOtherModifierCombinationsAndForeignWindowsAlone() throws {
        let panel = makePanel()
        let other = makePanel()
        defer { panel.orderOut(nil); other.orderOut(nil) }
        #expect(!panel.handleKeyboardEvent(try key("=", code: 24, modifiers: .command, in: panel)))
        var handled = 0
        panel.pageZoomAction = { _ in handled += 1 }

        for modifiers: NSEvent.ModifierFlags in [[.command, .control], [.command, .option], [.command, .function], .shift, []] {
            #expect(!panel.handleKeyboardEvent(try key("=", code: 24, modifiers: modifiers, in: panel)))
            _ = panel.performKeyEquivalent(with: try key("=", code: 24, modifiers: modifiers, in: panel))
        }
        #expect(!panel.handleKeyboardEvent(try key("-", code: 27, modifiers: [.command, .shift], in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("0", code: 29, modifiers: [.command, .shift], in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("=", code: 24, modifiers: .command, in: other)))
        _ = panel.performKeyEquivalent(with: try key("=", code: 24, modifiers: .command, in: other))
        #expect(handled == 0)
    }

    @Test func modifiedForeignAndNonKeyDownEventsStayInTheResponderChain() throws {
        let panel = makePanel()
        let other = makePanel()
        defer { panel.orderOut(nil); other.orderOut(nil) }
        var handled = 0
        panel.browserShortcutAction = { _ in handled += 1; return true }
        panel.closeAction = { handled += 1 }

        for modifier: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            #expect(!panel.handleKeyboardEvent(try key("2", code: 19, modifiers: modifier, in: panel)))
            #expect(!panel.handleKeyboardEvent(try key("\u{1b}", code: 53, modifiers: modifier, in: panel)))
        }
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, in: other)))
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, type: .keyUp, in: panel)))
        #expect(handled == 0)
    }

    @Test func nativeEditingAndEveryWebViewDescendantKeepTheirNumberKeys() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var handled = 0
        panel.browserShortcutAction = { _ in handled += 1; return true }
        let input = NSTextView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        input.isEditable = true
        panel.contentView = input
        #expect(panel.makeFirstResponder(input))
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: panel.frame, configuration: configuration)
        let content = KeyboardFocusView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        web.addSubview(content)
        panel.contentView = web
        #expect(panel.makeFirstResponder(content))
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(handled == 0)
    }

    @Test func anAttachedSheetKeepsEscapeAndDigits() throws {
        let panel = makePanel()
        let sheet = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 150, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        defer { panel.endSheet(sheet); sheet.orderOut(nil); panel.orderOut(nil) }
        let root = KeyboardFocusView(frame: CGRect(origin: .zero, size: panel.frame.size))
        panel.contentView = root
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint - 1, height: 800))
        #expect(panel.makeFirstResponder(root))
        var handled = 0
        panel.browserShortcutAction = { _ in handled += 1; return true }
        panel.pageZoomAction = { _ in handled += 1 }
        panel.initialBrowserNavigationAction = { _ in handled += 1; return true }
        panel.closeAction = { handled += 1 }
        panel.beginSheet(sheet)
        #expect(panel.attachedSheet === sheet)

        #expect(!panel.handleKeyboardEvent(try key("\u{1b}", code: 53, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
        #expect(!panel.handleKeyboardEvent(try key("=", code: 24, modifiers: .command, in: panel)))
        _ = panel.performKeyEquivalent(with: try key("=", code: 24, modifiers: .command, in: panel))
        #expect(handled == 0)
    }

    @Test func removingAnOldOwnerCannotClearTheReplacementHandler() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let oldOwner = UUID()
        let newOwner = UUID()
        var received: [String] = []
        panel.installBrowserShortcutAction({ _ in received.append("old"); return true }, onZoom: { _ in received.append("old zoom") }, owner: oldOwner)
        panel.installBrowserShortcutAction({ _ in received.append("new"); return true }, onZoom: { _ in received.append("new zoom") }, owner: newOwner)

        panel.removeBrowserShortcutAction(owner: oldOwner)

        #expect(panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(panel.handleKeyboardEvent(try key("0", code: 29, modifiers: .command, in: panel)))
        #expect(received == ["new", "new zoom"])
        panel.removeBrowserShortcutAction(owner: newOwner)
        #expect(!panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(panel.pageZoomAction == nil)
    }

    @Test func initialNavigationUsesTheSameOwnerLifetimeAsOtherShortcuts() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let root = KeyboardFocusView(frame: CGRect(origin: .zero, size: panel.frame.size))
        panel.contentView = root
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint - 1, height: 800))
        #expect(panel.makeFirstResponder(root))
        let oldOwner = UUID()
        let newOwner = UUID()
        var received: [String] = []
        panel.installBrowserShortcutAction({ _ in false }, onInitialNavigation: { _ in received.append("old"); return true }, owner: oldOwner)
        panel.installBrowserShortcutAction({ _ in false }, onInitialNavigation: { _ in received.append("new"); return true }, owner: newOwner)

        panel.removeBrowserShortcutAction(owner: oldOwner)
        #expect(panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
        #expect(received == ["new"])
        panel.removeBrowserShortcutAction(owner: newOwner)
        #expect(panel.initialBrowserNavigationAction == nil)
        #expect(!panel.handleKeyboardEvent(try key("\r", code: 36, in: panel)))
    }

    @Test func pointerDownNotifiesWithoutConsumingTheNativeMouseEvent() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let target = KeyboardMouseView(frame: CGRect(origin: .zero, size: panel.frame.size))
        panel.contentView = target
        var points: [CGPoint] = []
        panel.pointerDownAction = { points.append($0) }

        for type: NSEvent.EventType in [.leftMouseDown, .rightMouseDown, .otherMouseDown] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: CGPoint(x: 100, y: 120), modifierFlags: [], timestamp: 0,
                                                       windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            panel.sendEvent(event)
            #expect(target.receivedEvent === event)
        }
        #expect(points == Array(repeating: CGPoint(x: 100, y: 120), count: 3))
    }

    @Test func bridgeNormalizesPointerPointsAndKeepsLifecycleCallbacksCurrent() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let root = NSView(frame: CGRect(origin: .zero, size: panel.frame.size))
        panel.contentView = root
        var points: [CGPoint] = []
        var resignations = 0
        let view = LinkPreviewKeyboardBridge.KeyboardView(onPointerDown: { points.append($0) }, onResignKey: { resignations += 1 }) { _ in false }
        view.frame = CGRect(x: 40, y: 30, width: 100, height: 80)
        view.bounds.origin = CGPoint(x: 5, y: 7)
        root.addSubview(view)
        let pointer = try #require(panel.pointerDownAction)
        pointer(CGPoint(x: 50, y: 90))
        #expect(points == [CGPoint(x: 10, y: 20)])
        view.onPointerDown = { points.append(CGPoint(x: $0.x * 2, y: $0.y * 2)) }
        pointer(CGPoint(x: 50, y: 90))
        #expect(points.last == CGPoint(x: 20, y: 40))
        panel.resignKey()
        #expect(resignations == 1)
        view.onResignKey = { resignations += 10 }
        panel.resignKey()
        #expect(resignations == 11)
        view.removeFromSuperview()
        #expect(panel.pointerDownAction == nil)
        #expect(panel.resignKeyAction == nil)
    }

    @Test func pointerAndResignCallbacksFollowShortcutOwnership() {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        let oldOwner = UUID()
        let newOwner = UUID()
        var received: [String] = []
        panel.installBrowserShortcutAction({ _ in false }, onPointerDown: { _ in received.append("old pointer") }, onResignKey: { received.append("old resign") }, owner: oldOwner)
        panel.installBrowserShortcutAction({ _ in false }, onPointerDown: { _ in received.append("new pointer") }, onResignKey: { received.append("new resign") }, owner: newOwner)
        panel.removeBrowserShortcutAction(owner: oldOwner)
        panel.pointerDownAction?(.zero)
        panel.resignKey()
        #expect(received == ["new pointer", "new resign"])
        panel.removeBrowserShortcutAction(owner: newOwner)
        #expect(panel.pointerDownAction == nil)
        #expect(panel.resignKeyAction == nil)
    }

    @Test func bridgeRegistersOnlyWhileAttachedAndHideClearsTheAction() throws {
        let panel = makePanel()
        defer { panel.orderOut(nil) }
        var received: [Int] = []
        var zooms: [LinkPreviewZoomAction] = []
        var navigation: [LinkPreviewBrowserNavigationAction] = []
        let view = LinkPreviewKeyboardBridge.KeyboardView(onZoom: { zooms.append($0) }, onInitialNavigation: {
            navigation.append($0)
            return true
        }) { received.append($0); return true }
        panel.contentView = view
        panel.setContentSize(CGSize(width: LinkPreviewMetrics.compactBreakpoint - 1, height: 800))
        #expect(panel.handleKeyboardEvent(try key("2", code: 19, in: panel)))
        #expect(received == [2])
        #expect(panel.handleKeyboardEvent(try key("0", code: 29, modifiers: .command, in: panel)))
        #expect(zooms == [.reset])
        let initialNavigation = try #require(panel.initialBrowserNavigationAction)
        #expect(initialNavigation(.next))
        #expect(navigation == [.next])

        view.removeFromSuperview()

        #expect(panel.browserShortcutAction == nil)
        #expect(panel.pageZoomAction == nil)
        #expect(panel.initialBrowserNavigationAction == nil)
        let controller = LinkPreviewPanelController(orderFront: { _ in })
        controller.panel.browserShortcutAction = { _ in true }
        controller.panel.pageZoomAction = { _ in }
        controller.panel.initialBrowserNavigationAction = { _ in true }
        controller.panel.pointerDownAction = { _ in }
        controller.panel.resignKeyAction = {}
        controller.hide()
        #expect(controller.panel.browserShortcutAction == nil)
        #expect(controller.panel.pageZoomAction == nil)
        #expect(controller.panel.initialBrowserNavigationAction == nil)
        #expect(controller.panel.pointerDownAction == nil)
        #expect(controller.panel.resignKeyAction == nil)
    }

    private func makePanel() -> LinkPreviewPanel {
        _ = NSApplication.shared
        let panel = LinkPreviewPanel()
        panel.orderFront(nil)
        panel.alphaValue = 0
        return panel
    }

    private func key(_ text: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [], type: NSEvent.EventType = .keyDown, in panel: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
                                     windowNumber: panel.windowNumber, context: nil, characters: text,
                                     charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
}

@MainActor
private final class KeyboardFocusView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
private final class KeyboardFocusButton: NSButton {
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
private final class KeyboardMouseView: NSView {
    private(set) var receivedEvent: NSEvent?
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { receivedEvent = event }
    override func rightMouseDown(with event: NSEvent) { receivedEvent = event }
    override func otherMouseDown(with event: NSEvent) { receivedEvent = event }
}
