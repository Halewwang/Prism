import AppKit
import Testing
@testable import PrismNative

@Suite("Status item menu panel")
@MainActor
struct StatusItemMenuPanelTests {
    @Test func nativeMenuMaterialKeepsCompactButtonAndImageGeometry() throws {
        let fixture = Fixture()
        let item = fixture.add("Open")
        item.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        defer { adapter.dismiss() }
        let material = try #require(adapter.panel.contentView as? NSVisualEffectView)
        #expect(material.material == .menu)
        #expect(material.blendingMode == .behindWindow)
        #expect(material.state == .active)
        #expect(material.maskImage != nil)
        #expect(adapter.panel.frame.width >= 160)
        let button = try #require(adapter.button(for: item))
        let cell = try #require(button.cell as? NSButtonCell)
        #expect(button.frame.minX == 5)
        #expect(button.frame.minY == 6)
        #expect(button.frame.height == 28)
        #expect(button.focusRingType == .none)
        #expect(button.font?.pointSize == 13)
        let image = cell.imageRect(forBounds: button.bounds)
        let title = cell.titleRect(forBounds: button.bounds)
        #expect(image == NSRect(x: 9, y: 7, width: 14, height: 14))
        #expect(title.minX - image.maxX == 8)
        #expect(button.bounds.maxX - title.maxX == 9)
    }

    @Test func shortcutFormattingAndKeyboardDispatchExecuteMatchingMenuItem() throws {
        let fixture = Fixture()
        let settings = fixture.add("Settings")
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = [.command]
        let quit = fixture.add("Quit")
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = [.command]
        #expect(StatusItemMenuFormatting.shortcutText(for: settings) == "⌘,")
        #expect(StatusItemMenuFormatting.shortcutText(for: quit) == "⌘Q")

        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: adapter.panel.windowNumber,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        ))
        #expect(adapter.handleKeyEvent(event))
        #expect(!adapter.isPresented)
        #expect(fixture.events == ["dismiss", "Settings"])
        #expect(fixture.lastSender === settings)
    }

    @Test func submenuOpensOnRightArrowExecutesAndDismissesWholeHierarchy() throws {
        let fixture = Fixture()
        _ = fixture.add("First")
        let submenu = NSMenu(title: "More")
        submenu.autoenablesItems = false
        let subAction = NSMenuItem(title: "About Prism", action: #selector(Fixture.command(_:)), keyEquivalent: "")
        subAction.target = fixture
        subAction.isEnabled = true
        submenu.addItem(subAction)

        let more = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        more.isEnabled = true
        more.submenu = submenu
        fixture.menu.addItem(more)

        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        defer { adapter.dismiss() }

        adapter.moveSelection(by: 1)
        #expect(adapter.selectedItem === more)

        // Right arrow opens submenu and focuses its first enabled item.
        #expect(adapter.handleKeyEvent(try key(124, in: adapter.panel)))
        let child = try #require(adapter.presentedSubmenuPanel)
        #expect(child.isPresented)
        #expect(child.selectedItem === subAction)
        #expect(adapter.contains(window: child.panel))

        // Left arrow closes child submenu without cancelling the root session.
        #expect(child.handleKeyEvent(try key(123, in: child.panel)))
        #expect(adapter.presentedSubmenuPanel == nil)
        #expect(adapter.isPresented)
        #expect(adapter.selectedItem === more)
        #expect(fixture.dismissals == 0)

        // Reopen submenu and activate the child item with Return.
        #expect(adapter.handleKeyEvent(try key(124, in: adapter.panel)))
        let reopenedChild = try #require(adapter.presentedSubmenuPanel)
        #expect(reopenedChild.handleKeyEvent(try key(36, in: reopenedChild.panel)))
        #expect(!reopenedChild.isPresented)
        #expect(!adapter.isPresented)
        #expect(fixture.events == ["dismiss", "About Prism"])
        #expect(fixture.lastSender === subAction)
        #expect(adapter.activeMonitorCount == 0)
        #expect(adapter.activeObserverCount == 0)
    }

    @Test func submenuFrameFlipsToLeftWhenNearRightEdgeOfScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rightEdgeAnchor = NSRect(x: 1220, y: 600, width: 210, height: 28)
        let flipped = StatusItemMenuPanel.submenuFrame(
            for: NSSize(width: 190, height: 150),
            anchor: rightEdgeAnchor,
            visibleFrames: [screen]
        )
        #expect(screen.contains(flipped))
        #expect(flipped.maxX == rightEdgeAnchor.minX - 4)

        let leftAnchor = NSRect(x: 100, y: 600, width: 210, height: 28)
        let rightPlaced = StatusItemMenuPanel.submenuFrame(
            for: NSSize(width: 190, height: 150),
            anchor: leftAnchor,
            visibleFrames: [screen]
        )
        #expect(screen.contains(rightPlaced))
        #expect(rightPlaced.minX == leftAnchor.maxX + 4)
    }

    @Test func navigationSkipsSeparatorsHiddenAndDisabledItems() {
        let fixture = Fixture()
        let disabled = fixture.add("Disabled", enabled: false)
        fixture.menu.addItem(.separator())
        let hidden = fixture.add("Hidden")
        hidden.isHidden = true
        let first = fixture.add("First")
        let last = fixture.add("Last")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        defer { adapter.dismiss() }

        #expect(adapter.selectedItem === first)
        #expect(adapter.button(for: hidden) == nil)
        #expect(adapter.button(for: disabled)?.isEnabled == false)
        adapter.moveSelection(by: 1)
        #expect(adapter.selectedItem === last)
        adapter.moveSelection(by: 1)
        #expect(adapter.selectedItem === first)
        adapter.moveSelection(by: -1)
        #expect(adapter.selectedItem === last)
    }

    @Test func visibleItemsRefreshTheirNativeButtonsAndSelection() throws {
        let fixture = Fixture()
        let first = fixture.add("Pause")
        let second = fixture.add("Quit")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        defer { adapter.dismiss() }
        let image = NSImage(size: NSSize(width: 16, height: 16))

        first.title = "Resume"
        first.image = image
        #expect(adapter.button(for: first)?.title == "Resume")
        #expect(adapter.button(for: first)?.image != nil)
        first.isEnabled = false
        #expect(adapter.button(for: first)?.isEnabled == false)
        #expect(adapter.selectedItem === second)
        first.isHidden = true
        #expect(adapter.button(for: first) == nil)
        fixture.menu.removeItem(second)
        #expect(!adapter.isPresented)
        #expect(fixture.dismissals == 1)
    }

    @Test func refreshRestoresNativeFocusToTheReplacementEnabledButton() throws {
        let fixture = Fixture()
        let first = fixture.add("Pause")
        let second = fixture.add("Quit")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        defer { adapter.dismiss() }
        let old = try #require(adapter.button(for: first))
        #expect(adapter.panel.makeFirstResponder(old))
        first.title = "Resume"
        let replacement = try #require(adapter.button(for: first))
        #expect(replacement !== old)
        #expect(adapter.panel.firstResponder === replacement)
        first.isEnabled = false
        #expect(adapter.selectedItem === second)
        #expect(adapter.panel.firstResponder === adapter.button(for: second))
    }

    @Test func returnDismissesBeforeExecutingTheCurrentMenuItemExactlyOnce() throws {
        let fixture = Fixture()
        let item = fixture.add("Open")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        // Inserting before the selected row must not make its old index dispatch another command.
        fixture.menu.insertItem(NSMenuItem(title: "Disabled", action: nil, keyEquivalent: ""), at: 0)
        #expect(adapter.handleKeyEvent(try key(36, in: adapter.panel)))
        #expect(!adapter.handleKeyEvent(try key(36, in: adapter.panel)))
        #expect(fixture.events == ["dismiss", "Open"])
        #expect(fixture.lastSender === item)
        #expect(adapter.activeMonitorCount == 0)
        #expect(adapter.activeObserverCount == 0)
    }

    @Test func aCommandRemovedDuringSessionCancellationIsNotDispatched() throws {
        let fixture = Fixture()
        let item = fixture.add("Open")
        let adapter = StatusItemMenuPanel(menu: fixture.menu, cancelSession: {
            fixture.dismissals += 1
            fixture.menu.removeItem(item)
        }, orderFront: { _ in })
        fixture.present(adapter)
        #expect(adapter.handleKeyEvent(try key(36, in: adapter.panel)))
        #expect(fixture.dismissals == 1)
        #expect(fixture.lastSender == nil)
    }

    @Test func nativeAXPressUsesTheSameGuardedCommandPath() throws {
        let fixture = Fixture()
        let item = fixture.add("Open")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        let button = try #require(adapter.button(for: item))
        #expect(button.accessibilityLabel() == "Open")
        #expect(button.isAccessibilityEnabled())
        // AppKit exposes single-cell buttons through the unignored cell's legacy AX bridge.
        // Direct NSButton protocol getters/Press return values do not describe that external element.
        let accessible = try #require(NSAccessibility.unignoredDescendant(of: button) as? NSObject)
        let role = accessible.accessibilityAttributeValue(.role) as? String
        let actions = accessible.accessibilityActionNames()
        #expect(role == NSAccessibility.Role.button.rawValue)
        #expect(actions.contains(.press))
        for _ in 0..<2 { accessible.accessibilityPerformAction(.press) }
        #expect(fixture.events == ["dismiss", "Open"])
        #expect(fixture.lastSender === item)
    }

    @Test func escapeAndRepeatedCleanupCancelOnlyOnce() throws {
        let fixture = Fixture()
        _ = fixture.add("Open")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        #expect(adapter.handleKeyEvent(try key(53, in: adapter.panel)))
        adapter.dismiss()
        adapter.dismiss(cancelSession: false)
        #expect(!adapter.handleKeyEvent(try key(53, in: adapter.panel)))
        #expect(fixture.events == ["dismiss"])
        #expect(adapter.activeMonitorCount == 0)
        #expect(adapter.activeObserverCount == 0)
    }

    @Test func sessionEndDoesNotRecancelAndOutsideClickPreservesTheEvent() throws {
        let fixture = Fixture()
        _ = fixture.add("Open")
        let anchor = NSRect(x: 100, y: 900, width: 24, height: 24)
        let adapter = fixture.makeAdapter(statusButtonRect: { anchor })
        fixture.present(adapter)
        adapter.handlePointerDown(at: NSPoint(x: 110, y: 910), in: nil)
        #expect(adapter.isPresented)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: adapter.panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        #expect(adapter.handleLocalPointerEvent(event) === event)
        #expect(adapter.isPresented)
        adapter.handlePointerDown(at: NSPoint(x: 1000, y: 100), in: nil)
        #expect(!adapter.isPresented)
        #expect(fixture.dismissals == 1)
        fixture.present(adapter)
        adapter.dismiss(cancelSession: false)
        #expect(fixture.dismissals == 1)
    }

    @Test func spaceChangeAndResignKeyCleanUpTheCurrentPresentation() {
        let fixture = Fixture()
        _ = fixture.add("Open")
        let adapter = fixture.makeAdapter()
        fixture.present(adapter)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        #expect(!adapter.isPresented)
        fixture.present(adapter)
        adapter.panel.resignKey()
        #expect(!adapter.isPresented)
        #expect(fixture.dismissals == 2)
    }

    @Test func repeatedPresentDismissReleasesEveryObserverAndMonitor() {
        let fixture = Fixture()
        _ = fixture.add("Open")
        var adapter: StatusItemMenuPanel? = fixture.makeAdapter()
        weak let weakAdapter = adapter
        for _ in 0..<100 {
            fixture.present(adapter!)
            #expect(adapter!.activeObserverCount > 0)
            adapter!.dismiss()
            #expect(adapter!.activeMonitorCount == 0)
            #expect(adapter!.activeObserverCount == 0)
        }
        fixture.present(adapter!)
        adapter = nil
        #expect(weakAdapter == nil)
        #expect(fixture.dismissals == 101)
    }

    @Test func aMenuBarAnchorAboveTheSelectedDisplaysVisibleFrameStaysOnThatDisplay() {
        // Host selects this screen using NSScreen.frame, rather than the menu-bar-excluding visibleFrame.
        let selectedVisibleFrame = NSRect(x: -1200, y: 0, width: 1200, height: 875)
        let menuBarAnchor = NSRect(x: -600, y: 875, width: 24, height: 25)
        let result = StatusItemMenuPanel.frame(for: NSSize(width: 220, height: 105), anchor: menuBarAnchor, visibleFrames: [selectedVisibleFrame])
        #expect(selectedVisibleFrame.contains(result))
        #expect(result.maxY <= menuBarAnchor.minY)
        #expect(result.minX == menuBarAnchor.minX)
    }

    @Test func frameClampsToTheAnchorDisplayIncludingNegativeOrigins() {
        let left = NSRect(x: -1200, y: 0, width: 1200, height: 900)
        let right = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        let leftClamped = StatusItemMenuPanel.frame(for: NSSize(width: 260, height: 140), anchor: NSRect(x: -1210, y: 880, width: 24, height: 20), visibleFrames: [right, left])
        #expect(left.contains(leftClamped))
        #expect(leftClamped.minX == left.minX)
        let rightClamped = StatusItemMenuPanel.frame(for: NSSize(width: 260, height: 140), anchor: NSRect(x: -100, y: 880, width: 24, height: 20), visibleFrames: [right, left])
        #expect(left.contains(rightClamped))
        #expect(rightClamped.maxX == left.maxX)
        let oversized = StatusItemMenuPanel.frame(for: NSSize(width: 500, height: 500), anchor: NSRect(x: 20, y: 70, width: 20, height: 20), visibleFrames: [NSRect(x: 0, y: 0, width: 100, height: 100)])
        #expect(oversized == NSRect(x: 0, y: 0, width: 100, height: 100))
    }

    private func key(_ code: UInt16, in panel: NSPanel) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
    }
}

@MainActor
private final class Fixture: NSObject {
    let menu = NSMenu(title: "Prism")
    var events: [String] = []
    var dismissals = 0
    var lastSender: NSMenuItem?

    override init() {
        _ = NSApplication.shared
        super.init()
        menu.autoenablesItems = false
    }

    func add(_ title: String, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(command(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
        return item
    }

    func makeAdapter(statusButtonRect: @escaping @MainActor @Sendable () -> NSRect? = { nil }) -> StatusItemMenuPanel {
        StatusItemMenuPanel(menu: menu, cancelSession: { [self] in
            dismissals += 1
            events.append("dismiss")
        }, statusButtonRect: statusButtonRect, orderFront: { _ in })
    }

    func present(_ adapter: StatusItemMenuPanel) {
        adapter.present(anchor: NSRect(x: 100, y: 900, width: 24, height: 24), visibleFrames: [NSRect(x: 0, y: 0, width: 1440, height: 900)])
    }

    @objc func command(_ sender: NSMenuItem) {
        lastSender = sender
        events.append(sender.title)
    }
}
