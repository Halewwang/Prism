import AppKit

/// Presents Prism's existing status menu without AppKit's separate menu-effect windows.
@MainActor
final class StatusItemMenuPanel: NSObject {
    private enum Metrics {
        static let minWidth: CGFloat = 160
        static let horizontalInset: CGFloat = 5
        static let verticalPadding: CGFloat = 6
        static let rowHeight: CGFloat = 28
        static let separatorHeight: CGFloat = 9
        static let separatorHorizontalInset: CGFloat = 12
        static let cornerRadius: CGFloat = 12
        static let selectionCornerRadius: CGFloat = 7
        static let iconLeading: CGFloat = 9
        static let iconSize: CGFloat = 14
        static let iconTitleGap: CGFloat = 8
        static let trailingPadding: CGFloat = 9
        static let badgeLeadingGap: CGFloat = 6
        static let trailingAccessoryGap: CGFloat = 14
        static let submenuHorizontalGap: CGFloat = 4
        static let submenuIconWidth: CGFloat = 12
    }

    let panel = StatusItemMenuWindow()
    private let menu: NSMenu
    private let cancelSession: @MainActor () -> Void
    private let statusButtonRect: @MainActor () -> NSRect?
    private let customOrderFront: (@MainActor (NSPanel) -> Void)?
    private let isSubmenu: Bool
    private weak var parentPanel: StatusItemMenuPanel?
    private var activeSubmenuPanel: StatusItemMenuPanel?
    private var activeSubmenuParentItem: NSMenuItem?
    private var submenuDismissTask: Task<Void, Never>?
    private var pendingHoverItem: NSMenuItem?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var menuObservers: [NSObjectProtocol] = []
    private var spaceObserver: NSObjectProtocol?
    private var buttons: [ObjectIdentifier: StatusItemMenuButton] = [:]
    private var anchor = NSRect.zero
    private var visibleFrames: [NSRect] = []
    private(set) var isPresented = false
    private(set) var selectedItem: NSMenuItem?
    private(set) var isPointerInside = false
    private var isKeyboardActive = false
    var onPointerPresenceChanged: (@MainActor (Bool) -> Void)?

    var activeMonitorCount: Int {
        (localMonitor == nil ? 0 : 1) + (globalMonitor == nil ? 0 : 1) + (activeSubmenuPanel?.activeMonitorCount ?? 0)
    }

    var activeObserverCount: Int {
        menuObservers.count + (spaceObserver == nil ? 0 : 1) + (activeSubmenuPanel?.activeObserverCount ?? 0)
    }

    var presentedSubmenuPanel: StatusItemMenuPanel? { activeSubmenuPanel }

    init(
        menu: NSMenu,
        cancelSession: @escaping @MainActor () -> Void,
        statusButtonRect: @escaping @MainActor () -> NSRect? = { nil },
        orderFront: (@MainActor (NSPanel) -> Void)? = nil,
        isSubmenu: Bool = false,
        parentPanel: StatusItemMenuPanel? = nil
    ) {
        self.menu = menu
        self.cancelSession = cancelSession
        self.statusButtonRect = statusButtonRect
        self.customOrderFront = orderFront
        self.isSubmenu = isSubmenu
        self.parentPanel = parentPanel
        super.init()
        panel.handleKey = { [weak self] in self?.handleKeyEvent($0) ?? false }
        panel.dismissAction = { [weak self] in self?.dismissHierarchy() }
        panel.shouldDismissOnResignKey = { [weak self] in
            guard let self else { return true }
            if self.isSubmenu {
                return false
            }
            if let keyWindow = NSApp.keyWindow, self.rootPanel.contains(window: keyWindow) {
                return false
            }
            return true
        }
    }

    isolated deinit { dismiss() }

    private var rootPanel: StatusItemMenuPanel {
        parentPanel?.rootPanel ?? self
    }

    private func orderPanelFront() {
        if let customOrderFront {
            customOrderFront(panel)
            return
        }
        if isSubmenu {
            if let parentWindow = parentPanel?.panel, parentWindow.isVisible {
                panel.order(.above, relativeTo: parentWindow.windowNumber)
            } else {
                panel.orderFront(nil)
            }
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func contains(window: NSWindow?) -> Bool {
        guard let window else { return false }
        if window === panel { return true }
        return activeSubmenuPanel?.contains(window: window) ?? false
    }

    func present(anchor: NSRect, visibleFrames: [NSRect], selectInitialItem: Bool = true) {
        self.anchor = anchor
        self.visibleFrames = visibleFrames
        if isPresented { refresh(selectInitialItem: selectInitialItem); return }
        isPresented = true
        isPointerInside = false
        isKeyboardActive = selectInitialItem
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
        refresh(selectInitialItem: selectInitialItem)
        guard isPresented else { return }
        observeMenuAndSpace()
        if !isSubmenu {
            monitorOutsideClicks()
        }
        orderPanelFront()
        if selectInitialItem, !isSubmenu, let selectedItem, let button = buttons[ObjectIdentifier(selectedItem)] {
            panel.makeFirstResponder(button)
        }
    }

    func dismiss(cancelSession shouldCancel: Bool = true) {
        guard isPresented else { return }
        isPresented = false // Clear before orderOut/cancel, both of which can reenter dismissal.
        cancelPendingSubmenuDismiss()
        isPointerInside = false
        isKeyboardActive = false
        dismissSubmenu()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        for observer in menuObservers { NotificationCenter.default.removeObserver(observer) }
        menuObservers.removeAll()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        // Clear shadow and opacity before ordering out so macOS 27's compositor never leaves an empty shadow silhouette.
        panel.hasShadow = false
        panel.alphaValue = 0
        panel.invalidateShadow()
        panel.orderOut(nil)
        if isSubmenu {
            panel.close()
        }
        panel.contentView = nil
        buttons.removeAll()
        selectedItem = nil
        if shouldCancel && !isSubmenu { cancelSession() }
    }

    private func dismissHierarchy() {
        rootPanel.dismiss(cancelSession: true)
    }

    private func cancelPendingSubmenuDismiss() {
        submenuDismissTask?.cancel()
        submenuDismissTask = nil
        pendingHoverItem = nil
    }

    private func scheduleSubmenuDismiss(selecting item: NSMenuItem?) {
        cancelPendingSubmenuDismiss()
        pendingHoverItem = item
        submenuDismissTask = Task { @MainActor [weak self, weak item] in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, let self, self.isPresented else { return }
            if self.activeSubmenuPanel?.isPointerInside == true {
                self.pendingHoverItem = nil
                return
            }
            self.submenuDismissTask = nil
            self.pendingHoverItem = nil
            self.dismissSubmenu()
            self.select(item)
        }
    }

    func simulateSubmenuPointerPresence(_ inside: Bool) {
        isPointerInside = inside
        onPointerPresenceChanged?(inside)
    }

    private func dismissSubmenu() {
        cancelPendingSubmenuDismiss()
        guard let child = activeSubmenuPanel else { return }
        activeSubmenuPanel = nil
        activeSubmenuParentItem = nil
        child.onPointerPresenceChanged = nil
        child.dismiss(cancelSession: false)
    }

    func button(for item: NSMenuItem) -> NSButton? { buttons[ObjectIdentifier(item)] }

    func moveSelection(by offset: Int) {
        guard isPresented else { return }
        let eligible = menu.items.filter(canSelect)
        guard !eligible.isEmpty else { return }
        let current = selectedItem.flatMap { selected in eligible.firstIndex { $0 === selected } }
        let next = current.map { ($0 + offset % eligible.count + eligible.count) % eligible.count }
            ?? (offset < 0 ? eligible.count - 1 : 0)
        dismissSubmenu()
        select(eligible[next], focus: !isSubmenu)
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isPresented, event.type == .keyDown else { return false }
        if !isSubmenu,
           event.window === panel,
           let child = activeSubmenuPanel,
           child.isPresented,
           child.isKeyboardActive,
           child.processKeyEvent(event) {
            return true
        }
        guard event.window === panel else { return false }
        return processKeyEvent(event)
    }

    private func processKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if !modifiers.isEmpty {
            if let shortcutItem = matchingShortcutItem(for: event, modifiers: modifiers) {
                activate(shortcutItem)
                return true
            }
            return false
        }
        switch event.keyCode {
        case 126: moveSelection(by: -1)
        case 125: moveSelection(by: 1)
        case 124:
            if let selectedItem, canOpenSubmenu(selectedItem) {
                openSubmenu(for: selectedItem, focusFirstItem: true)
            } else {
                return false
            }
        case 123:
            guard isSubmenu, let parent = parentPanel else { return false }
            let trigger = parent.activeSubmenuParentItem
            parent.dismissSubmenu()
            if let trigger {
                parent.select(trigger, focus: true)
            }
        case 36, 76:
            if let selectedItem {
                if canOpenSubmenu(selectedItem) {
                    openSubmenu(for: selectedItem, focusFirstItem: true)
                } else {
                    activate(selectedItem)
                }
            }
        case 53: dismissHierarchy()
        default: return false
        }
        return true
    }

    func handleLocalPointerEvent(_ event: NSEvent) -> NSEvent {
        let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        handlePointerDown(at: point, in: event.window)
        return event
    }

    func handlePointerDown(at point: NSPoint, in window: NSWindow?) {
        guard isPresented, !contains(window: window),
              statusButtonRect()?.contains(point) != true else { return }
        dismissHierarchy()
    }

    static func frame(for size: NSSize, anchor: NSRect, visibleFrames: [NSRect]) -> NSRect {
        let screen = screenFrame(for: anchor, visibleFrames: visibleFrames, fallbackSize: size)
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        return NSRect(
            x: min(max(anchor.minX, screen.minX), screen.maxX - width),
            y: min(max(anchor.minY - 4 - height, screen.minY), screen.maxY - height),
            width: width,
            height: height
        )
    }

    static func submenuFrame(for size: NSSize, anchor: NSRect, visibleFrames: [NSRect]) -> NSRect {
        let screen = screenFrame(for: anchor, visibleFrames: visibleFrames, fallbackSize: size)
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        let preferredRightX = anchor.maxX + Metrics.submenuHorizontalGap
        let preferredLeftX = anchor.minX - Metrics.submenuHorizontalGap - width
        let x: CGFloat
        if preferredRightX + width <= screen.maxX {
            x = preferredRightX
        } else if preferredLeftX >= screen.minX {
            x = preferredLeftX
        } else {
            x = min(max(preferredRightX, screen.minX), screen.maxX - width)
        }
        let alignedTopY = anchor.maxY + Metrics.verticalPadding - height
        let y = min(max(alignedTopY, screen.minY), screen.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func screenFrame(for anchor: NSRect, visibleFrames: [NSRect], fallbackSize: NSSize) -> NSRect {
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        return visibleFrames.first { $0.contains(center) }
            ?? visibleFrames.first { $0.intersects(anchor) }
            ?? visibleFrames.first
            ?? NSRect(x: anchor.minX, y: anchor.minY - fallbackSize.height, width: fallbackSize.width, height: fallbackSize.height)
    }

    private func canPerform(_ item: NSMenuItem) -> Bool {
        menu.index(of: item) >= 0 && !item.isSeparatorItem && !item.isHidden && item.isEnabled && item.action != nil
    }

    private func canOpenSubmenu(_ item: NSMenuItem) -> Bool {
        menu.index(of: item) >= 0 && !item.isSeparatorItem && !item.isHidden && item.isEnabled && item.hasSubmenu && item.submenu != nil
    }

    private func canSelect(_ item: NSMenuItem) -> Bool {
        canPerform(item) || canOpenSubmenu(item)
    }

    private func matchingShortcutItem(for event: NSEvent, modifiers: NSEvent.ModifierFlags) -> NSMenuItem? {
        guard let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty else { return nil }
        return menu.items.first { item in
            guard canPerform(item), !item.keyEquivalent.isEmpty else { return false }
            let expectedModifiers = item.keyEquivalentModifierMask.intersection([.command, .control, .option, .shift])
            return item.keyEquivalent.lowercased() == chars && expectedModifiers == modifiers
        }
    }

    private func activate(_ item: NSMenuItem) {
        if canOpenSubmenu(item) {
            openSubmenu(for: item, focusFirstItem: true)
            return
        }
        guard isPresented, canPerform(item) else { return }
        let targetMenu = menu
        dismissHierarchy()
        // Session cancellation may synchronously mutate the menu. Resolve identity again afterwards.
        guard targetMenu.index(of: item) >= 0,
              !item.isSeparatorItem, !item.isHidden, item.isEnabled, item.action != nil
        else { return }
        targetMenu.performActionForItem(at: targetMenu.index(of: item))
    }

    func openSubmenu(for item: NSMenuItem, focusFirstItem: Bool = false) {
        guard isPresented, canOpenSubmenu(item), let submenu = item.submenu else { return }
        cancelPendingSubmenuDismiss()
        if activeSubmenuParentItem === item, let existing = activeSubmenuPanel, existing.isPresented {
            if focusFirstItem {
                existing.isKeyboardActive = true
                if let first = submenu.items.first(where: { existing.canSelect($0) }) {
                    existing.select(first, focus: false)
                }
            }
            return
        }
        dismissSubmenu()
        select(item, focus: false)
        let rowAnchor: NSRect
        if let button = buttons[ObjectIdentifier(item)] {
            let rectInWindow = button.convert(button.bounds, to: nil)
            let screenRect = panel.convertToScreen(rectInWindow)
            rowAnchor = NSRect(x: panel.frame.minX, y: screenRect.minY, width: panel.frame.width, height: screenRect.height)
        } else {
            rowAnchor = panel.frame
        }
        let child = StatusItemMenuPanel(
            menu: submenu,
            cancelSession: {},
            statusButtonRect: statusButtonRect,
            orderFront: customOrderFront,
            isSubmenu: true,
            parentPanel: self
        )
        child.onPointerPresenceChanged = { [weak self, weak item] inside in
            guard let self else { return }
            if inside {
                self.cancelPendingSubmenuDismiss()
                if let item {
                    self.select(item, focus: false)
                }
            }
        }
        activeSubmenuPanel = child
        activeSubmenuParentItem = item
        child.present(anchor: rowAnchor, visibleFrames: visibleFrames, selectInitialItem: focusFirstItem)
        child.isKeyboardActive = focusFirstItem
    }

    @objc private func clicked(_ sender: StatusItemMenuButton) { activate(sender.menuItem) }

    private func select(_ item: NSMenuItem?, focus: Bool = false) {
        selectedItem = item.flatMap { canSelect($0) ? $0 : nil }
        for button in buttons.values { button.setSelected(button.menuItem === selectedItem) }
        if focus, let selectedItem, let button = buttons[ObjectIdentifier(selectedItem)], panel.firstResponder !== button {
            panel.makeFirstResponder(button)
        }
    }

    private func refresh(selectInitialItem: Bool = true) {
        guard isPresented else { return }
        let hadButtonFocus = buttons.values.contains { panel.firstResponder === $0 }
        var items: [NSMenuItem] = []
        for item in menu.items where !item.isHidden {
            if item.isSeparatorItem && (items.isEmpty || items.last?.isSeparatorItem == true) { continue }
            items.append(item)
        }
        if items.last?.isSeparatorItem == true { items.removeLast() }
        guard items.contains(where: { !$0.isSeparatorItem }) else { dismiss(); return }

        let width = requiredWidth(for: items)
        let height = items.reduce(Metrics.verticalPadding * 2) {
            $0 + ($1.isSeparatorItem ? Metrics.separatorHeight : Metrics.rowHeight)
        }
        let size = NSSize(width: width, height: height)
        let frame = isSubmenu
            ? Self.submenuFrame(for: size, anchor: anchor, visibleFrames: visibleFrames)
            : Self.frame(for: size, anchor: anchor, visibleFrames: visibleFrames)

        let background = StatusItemMenuBackground(frame: NSRect(origin: .zero, size: frame.size))
        background.onPointerPresenceChanged = { [weak self] inside in
            guard let self else { return }
            self.isPointerInside = inside
            self.onPointerPresenceChanged?(inside)
        }
        buttons.removeAll()
        var y: CGFloat = Metrics.verticalPadding
        for item in items {
            if item.isSeparatorItem {
                let separator = NSBox(frame: NSRect(
                    x: Metrics.separatorHorizontalInset,
                    y: y + floor(Metrics.separatorHeight / 2),
                    width: frame.width - Metrics.separatorHorizontalInset * 2,
                    height: 1
                ))
                separator.boxType = .separator
                background.addSubview(separator)
                y += Metrics.separatorHeight
                continue
            }
            let button = StatusItemMenuButton(item: item)
            button.frame = NSRect(
                x: Metrics.horizontalInset,
                y: y,
                width: frame.width - Metrics.horizontalInset * 2,
                height: Metrics.rowHeight
            )
            button.target = self
            button.action = #selector(clicked(_:))
            button.hover = { [weak self, weak item] entered in
                guard let self else { return }
                if entered {
                    if self.isSubmenu {
                        self.parentPanel?.cancelPendingSubmenuDismiss()
                        self.isKeyboardActive = true
                        self.select(item)
                    } else if let item, self.canOpenSubmenu(item) {
                        self.cancelPendingSubmenuDismiss()
                        self.select(item)
                        self.openSubmenu(for: item, focusFirstItem: false)
                    } else if self.activeSubmenuPanel != nil && self.activeSubmenuParentItem !== item {
                        self.scheduleSubmenuDismiss(selecting: item)
                    } else {
                        self.select(item)
                    }
                } else {
                    if self.pendingHoverItem === item {
                        self.cancelPendingSubmenuDismiss()
                    }
                    if self.selectedItem === item && self.activeSubmenuParentItem !== item {
                        self.select(nil)
                    }
                }
            }
            button.focus = { [weak self, weak item] in self?.select(item) }
            buttons[ObjectIdentifier(item)] = button
            background.addSubview(button)
            y += Metrics.rowHeight
        }
        panel.contentView = background
        panel.setFrame(frame, display: true)
        panel.alphaValue = 1
        panel.hasShadow = true
        panel.invalidateShadow()
        let current = selectedItem.flatMap { canSelect($0) ? $0 : nil }
        if selectInitialItem {
            select(current ?? items.first(where: canSelect), focus: hadButtonFocus)
        } else {
            select(current, focus: false)
        }
    }

    private func requiredWidth(for items: [NSMenuItem]) -> CGFloat {
        let titleFont = NSFont.menuFont(ofSize: 13)
        let badgeFont = NSFont.systemFont(ofSize: 11.5, weight: .regular)
        let shortcutFont = NSFont.menuFont(ofSize: 12)
        let widest = items.filter { !$0.isSeparatorItem }.map { item -> CGFloat in
            let leading: CGFloat = item.image == nil
                ? Metrics.iconLeading
                : Metrics.iconLeading + Metrics.iconSize + Metrics.iconTitleGap
            let titleWidth = ceil((item.title as NSString).size(withAttributes: [.font: titleFont]).width)
            let badgeWidth: CGFloat
            if let badgeText = item.badge?.stringValue, !badgeText.isEmpty {
                badgeWidth = Metrics.badgeLeadingGap
                    + ceil((badgeText as NSString).size(withAttributes: [.font: badgeFont]).width)
            } else {
                badgeWidth = 0
            }
            let trailingWidth: CGFloat
            if item.hasSubmenu || item.state == .on {
                trailingWidth = Metrics.trailingAccessoryGap + Metrics.submenuIconWidth
            } else {
                let shortcut = StatusItemMenuFormatting.shortcutText(for: item)
                if !shortcut.isEmpty {
                    trailingWidth = Metrics.trailingAccessoryGap
                        + ceil((shortcut as NSString).size(withAttributes: [.font: shortcutFont]).width)
                } else {
                    trailingWidth = 0
                }
            }
            return Metrics.horizontalInset * 2 + leading + titleWidth + badgeWidth + trailingWidth + Metrics.trailingPadding
        }.max() ?? Metrics.minWidth
        return max(Metrics.minWidth, widest)
    }

    private func observeMenuAndSpace() {
        for name in [NSMenu.didAddItemNotification, NSMenu.didRemoveItemNotification, NSMenu.didChangeItemNotification] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: menu, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        if !isSubmenu {
            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismissHierarchy() }
            }
        }
    }

    private func monitorOutsideClicks() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleLocalPointerEvent(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePointerDown(at: NSEvent.mouseLocation, in: nil) }
        }
    }
}

enum StatusItemMenuFormatting {
    static func shortcutText(for item: NSMenuItem) -> String {
        guard !item.keyEquivalent.isEmpty else { return "" }
        let modifiers = item.keyEquivalentModifierMask
        var prefix = ""
        if modifiers.contains(.control) { prefix += "⌃" }
        if modifiers.contains(.option) { prefix += "⌥" }
        if modifiers.contains(.shift) { prefix += "⇧" }
        if modifiers.contains(.command) { prefix += "⌘" }
        let key: String
        switch item.keyEquivalent {
        case "\r": key = "↩"
        case "\u{1B}": key = "⎋"
        case "\t": key = "⇥"
        case " ": key = "Space"
        default: key = item.keyEquivalent.uppercased()
        }
        return prefix + key
    }
}

@MainActor
final class StatusItemMenuWindow: NSPanel {
    var handleKey: (@MainActor (NSEvent) -> Bool)?
    var dismissAction: (@MainActor () -> Void)?
    var shouldDismissOnResignKey: (@MainActor () -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 220, height: 105), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        alphaValue = 0
        hasShadow = false
        setAccessibilityTitle("Prism")
    }

    override func sendEvent(_ event: NSEvent) {
        if handleKey?(event) == true { return }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) { dismissAction?() }
    override func resignKey() {
        super.resignKey()
        if shouldDismissOnResignKey?() ?? true {
            dismissAction?()
        }
    }
}

@MainActor
private final class StatusItemMenuBackground: NSVisualEffectView {
    var onPointerPresenceChanged: (@MainActor (Bool) -> Void)?
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .menu
        blendingMode = .behindWindow
        state = .active
        // Public material mask also gives the existing window shadow its rounded outline.
        let radius: CGFloat = 12
        let side = radius * 2 + 1
        let mask = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        mask.resizingMode = .stretch
        maskImage = mask
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        tracking = area
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onPointerPresenceChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onPointerPresenceChanged?(false)
    }
}

/// Keep native cell drawing and accessibility while giving icon, title, badge, and trailing hints explicit menu spacing.
@MainActor
private final class StatusItemMenuButtonCell: NSButtonCell {
    var trailingAccessoryWidth: CGFloat = 0

    override func drawingRect(forBounds rect: NSRect) -> NSRect { rect }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        guard image != nil else { return .zero }
        return NSRect(x: rect.minX + 9, y: rect.midY - 7, width: 14, height: 14)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let leading: CGFloat = image == nil ? 9 : 31
        let trailing = 9 + (trailingAccessoryWidth > 0 ? trailingAccessoryWidth + 8 : 0)
        let height = min(ceil(attributedTitle.size().height), rect.height)
        return NSRect(
            x: rect.minX + leading,
            y: rect.midY - height / 2,
            width: max(0, rect.width - leading - trailing),
            height: height
        )
    }
}

@MainActor
private final class StatusItemMenuButton: NSButton {
    let menuItem: NSMenuItem
    var hover: (@MainActor (Bool) -> Void)?
    var focus: (@MainActor () -> Void)?
    private var selected = false
    private var tracking: NSTrackingArea?
    private let badgeText: String?
    private let shortcutText: String
    private let showsChevron: Bool
    private let showsCheckmark: Bool
    override var acceptsFirstResponder: Bool { isEnabled }

    init(item: NSMenuItem) {
        menuItem = item
        badgeText = item.badge?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        showsChevron = item.hasSubmenu
        showsCheckmark = !item.hasSubmenu && item.state == .on
        shortcutText = (showsChevron || showsCheckmark) ? "" : StatusItemMenuFormatting.shortcutText(for: item)
        super.init(frame: .zero)
        let customCell = StatusItemMenuButtonCell(textCell: item.title)
        if showsChevron || showsCheckmark {
            customCell.trailingAccessoryWidth = 12
        } else if !shortcutText.isEmpty {
            let size = (shortcutText as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 12)])
            customCell.trailingAccessoryWidth = ceil(size.width)
        }
        cell = customCell
        title = item.title
        font = .menuFont(ofSize: 13)
        isBordered = false
        alignment = .left
        imagePosition = .imageLeading
        imageScaling = .scaleProportionallyDown
        if let source = item.image {
            image = source.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular))
                ?? (source.copy() as? NSImage)
        }
        image?.size = NSSize(width: 14, height: 14)
        isEnabled = item.isEnabled
        cell?.lineBreakMode = .byTruncatingTail
        focusRingType = .none
        cell?.focusRingType = .none
        setAccessibilityLabel(item.title)
        setSelected(false)
    }
    required init?(coder: NSCoder) { nil }

    func setSelected(_ value: Bool) {
        selected = value && isEnabled
        let primaryColor: NSColor = !isEnabled
            ? .disabledControlTextColor
            : selected ? .selectedMenuItemTextColor : .labelColor
        let mutedColor: NSColor = !isEnabled
            ? .disabledControlTextColor
            : selected ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.78) : NSColor.secondaryLabelColor.withAlphaComponent(0.85)

        let combined = NSMutableAttributedString(
            string: title,
            attributes: [.font: font ?? NSFont.menuFont(ofSize: 13), .foregroundColor: primaryColor]
        )
        if let badgeText {
            combined.append(NSAttributedString(
                string: "  \(badgeText)",
                attributes: [.font: NSFont.systemFont(ofSize: 11.5, weight: .regular), .foregroundColor: mutedColor]
            ))
        }
        attributedTitle = combined
        contentTintColor = primaryColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        }
        super.draw(dirtyRect)
        drawTrailingAccessory()
    }

    private func drawTrailingAccessory() {
        let accessoryColor: NSColor = !isEnabled
            ? .disabledControlTextColor
            : selected
                ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.82)
                : NSColor.secondaryLabelColor.withAlphaComponent(0.78)

        if showsChevron {
            drawTrailingSymbol("chevron.right", pointSize: 10, weight: .semibold, color: accessoryColor)
        } else if showsCheckmark {
            drawTrailingSymbol("checkmark", pointSize: 11, weight: .semibold, color: selected ? .selectedMenuItemTextColor : .labelColor)
        } else if !shortcutText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuFont(ofSize: 12),
                .foregroundColor: accessoryColor
            ]
            let size = (shortcutText as NSString).size(withAttributes: attributes)
            let rect = NSRect(
                x: bounds.maxX - 9 - ceil(size.width),
                y: bounds.midY - ceil(size.height) / 2,
                width: ceil(size.width),
                height: ceil(size.height)
            )
            (shortcutText as NSString).draw(in: rect, withAttributes: attributes)
        }
    }

    private func drawTrailingSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return
        }
        let size = symbol.size
        let rect = NSRect(
            x: bounds.maxX - 9 - size.width,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        symbol.draw(in: rect)
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        tracking = area
        addTrackingArea(area)
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { if isEnabled { hover?(true) } }
    override func mouseExited(with event: NSEvent) { hover?(false) }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { focus?() }
        return accepted
    }
}
