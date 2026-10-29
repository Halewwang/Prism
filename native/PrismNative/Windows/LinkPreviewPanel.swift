import AppKit
import WebKit

enum LinkPreviewBrowserNavigationAction: Equatable, Sendable {
    case previous, next, activate
}

@MainActor
final class LinkPreviewPanel: NSPanel {
    var closeAction: (@MainActor () -> Void)?
    var browserShortcutAction: (@MainActor (Int) -> Bool)?
    var pageZoomAction: (@MainActor (LinkPreviewZoomAction) -> Void)?
    var initialBrowserNavigationAction: (@MainActor (LinkPreviewBrowserNavigationAction) -> Bool)?
    var pointerDownAction: (@MainActor (CGPoint) -> Void)?
    var resignKeyAction: (@MainActor () -> Void)?
    private var browserShortcutOwner: UUID?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: CGRect = CGRect(origin: .zero, size: LinkPreviewWindowGeometry.defaultSize)) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = LinkPreviewWindowGeometry.minimumSize
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        setAccessibilityIdentifier("linkPreview.panel")
        setAccessibilityTitle(String(localized: "linkPreview.panel.title", defaultValue: "Link preview"))
    }

    override func performClose(_ sender: Any?) {
        closeAction?()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.window === self, attachedSheet == nil {
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                pointerDownAction?(event.locationInWindow)
            default: break
            }
        }
        if handleKeyboardEvent(event) { return }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        resignKeyAction?()
    }

    func handleKeyboardEvent(_ event: NSEvent) -> Bool {
        if handlePageZoomEvent(event) { return true }
        guard event.type == .keyDown, event.window === self, attachedSheet == nil,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
        else { return false }
        if event.keyCode == 53 {
            closeAction?()
            return true
        }
        if let input = firstResponder as? NSTextView, input.isEditable { return false }
        var view = firstResponder as? NSView
        while let current = view {
            if current is WKWebView { return false }
            view = current.superview
        }
        if frame.width < LinkPreviewMetrics.compactBreakpoint, firstResponder === contentView {
            let navigation: LinkPreviewBrowserNavigationAction?
            switch event.keyCode {
            case 126: navigation = .previous
            case 125: navigation = .next
            case 36, 76: navigation = .activate
            default: navigation = nil
            }
            if let navigation { return initialBrowserNavigationAction?(navigation) ?? false }
        }
        guard let text = event.charactersIgnoringModifiers, text.count == 1,
              let number = Int(text), (1 ... 9).contains(number)
        else { return false }
        return browserShortcutAction?(number) ?? false
    }

    private func handlePageZoomEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.window === self, attachedSheet == nil,
              let pageZoomAction else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift, .function])
        guard modifiers == .command || modifiers == [.command, .shift] else { return false }
        let zoom: LinkPreviewZoomAction
        switch event.charactersIgnoringModifiers ?? "" {
        case "=", "+": zoom = .zoomIn
        case "-" where modifiers == .command: zoom = .zoomOut
        case "0" where modifiers == .command: zoom = .reset
        default: return false
        }
        pageZoomAction(zoom)
        return true
    }

    func installBrowserShortcutAction(
        _ action: @escaping @MainActor (Int) -> Bool,
        onZoom: @escaping @MainActor (LinkPreviewZoomAction) -> Void = { _ in },
        onInitialNavigation: @escaping @MainActor (LinkPreviewBrowserNavigationAction) -> Bool = { _ in false },
        onPointerDown: @escaping @MainActor (CGPoint) -> Void = { _ in },
        onResignKey: @escaping @MainActor () -> Void = {},
        owner: UUID
    ) {
        browserShortcutOwner = owner
        browserShortcutAction = action
        pageZoomAction = onZoom
        initialBrowserNavigationAction = onInitialNavigation
        pointerDownAction = onPointerDown
        resignKeyAction = onResignKey
    }

    func removeBrowserShortcutAction(owner: UUID) {
        guard browserShortcutOwner == owner else { return }
        clearBrowserShortcutAction()
    }

    func clearBrowserShortcutAction() {
        browserShortcutAction = nil
        pageZoomAction = nil
        initialBrowserNavigationAction = nil
        pointerDownAction = nil
        resignKeyAction = nil
        browserShortcutOwner = nil
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handlePageZoomEvent(event) { return true }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
