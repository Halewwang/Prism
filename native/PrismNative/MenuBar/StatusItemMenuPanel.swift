import AppKit

/// Presents Prism's existing status menu without AppKit's separate menu-effect windows.
@MainActor
final class StatusItemMenuPanel: NSObject {
    let panel = StatusItemMenuWindow()
    private let menu: NSMenu
    private let cancelSession: @MainActor () -> Void
    private let statusButtonRect: @MainActor () -> NSRect?
    private let orderFront: @MainActor (NSPanel) -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var menuObservers: [NSObjectProtocol] = []
    private var spaceObserver: NSObjectProtocol?
    private var buttons: [ObjectIdentifier: StatusItemMenuButton] = [:]
    private var anchor = NSRect.zero
    private var visibleFrames: [NSRect] = []
    private(set) var isPresented = false
    private(set) var selectedItem: NSMenuItem?

    var activeMonitorCount: Int { (localMonitor == nil ? 0 : 1) + (globalMonitor == nil ? 0 : 1) }
    var activeObserverCount: Int { menuObservers.count + (spaceObserver == nil ? 0 : 1) }

    init(menu: NSMenu, cancelSession: @escaping @MainActor () -> Void,
         statusButtonRect: @escaping @MainActor () -> NSRect? = { nil },
         orderFront: @escaping @MainActor (NSPanel) -> Void = { $0.makeKeyAndOrderFront(nil) }) {
        self.menu = menu
        self.cancelSession = cancelSession
        self.statusButtonRect = statusButtonRect
        self.orderFront = orderFront
        super.init()
        panel.handleKey = { [weak self] in self?.handleKeyEvent($0) ?? false }
        panel.dismissAction = { [weak self] in self?.dismiss() }
    }

    isolated deinit { dismiss() }

    func present(anchor: NSRect, visibleFrames: [NSRect]) {
        self.anchor = anchor
        self.visibleFrames = visibleFrames
        if isPresented { refresh(); return }
        isPresented = true
        menu.update()
        refresh()
        guard isPresented else { return }
        observeMenuAndSpace()
        monitorOutsideClicks()
        orderFront(panel)
        if let selectedItem, let button = buttons[ObjectIdentifier(selectedItem)] {
            panel.makeFirstResponder(button)
        }
    }

    func dismiss(cancelSession shouldCancel: Bool = true) {
        guard isPresented else { return }
        isPresented = false // Clear before orderOut/cancel, both of which can reenter dismissal.
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        for observer in menuObservers { NotificationCenter.default.removeObserver(observer) }
        menuObservers.removeAll()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        panel.orderOut(nil)
        panel.contentView = nil
        buttons.removeAll()
        selectedItem = nil
        if shouldCancel { cancelSession() }
    }

    func button(for item: NSMenuItem) -> NSButton? { buttons[ObjectIdentifier(item)] }

    func moveSelection(by offset: Int) {
        guard isPresented else { return }
        let eligible = menu.items.filter(canPerform)
        guard !eligible.isEmpty else { return }
        let current = selectedItem.flatMap { selected in eligible.firstIndex { $0 === selected } }
        let next = current.map { ($0 + offset % eligible.count + eligible.count) % eligible.count }
            ?? (offset < 0 ? eligible.count - 1 : 0)
        select(eligible[next], focus: true)
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isPresented, event.type == .keyDown, event.window === panel,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return false }
        switch event.keyCode {
        case 126: moveSelection(by: -1)
        case 125: moveSelection(by: 1)
        case 36, 76:
            if let selectedItem { activate(selectedItem) }
        case 53: dismiss()
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
        guard isPresented, window !== panel,
              statusButtonRect()?.contains(point) != true else { return }
        dismiss()
    }

    static func frame(for size: NSSize, anchor: NSRect, visibleFrames: [NSRect]) -> NSRect {
        let center = NSPoint(x: anchor.midX, y: anchor.midY)
        let screen = visibleFrames.first { $0.contains(center) }
            ?? visibleFrames.first { $0.intersects(anchor) }
            ?? visibleFrames.first
            ?? NSRect(x: anchor.minX, y: anchor.minY - size.height, width: size.width, height: size.height)
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        return NSRect(x: min(max(anchor.maxX - width, screen.minX), screen.maxX - width),
                      y: min(max(anchor.minY - 4 - height, screen.minY), screen.maxY - height),
                      width: width, height: height)
    }

    private func canPerform(_ item: NSMenuItem) -> Bool {
        menu.index(of: item) >= 0 && !item.isSeparatorItem && !item.isHidden && item.isEnabled && item.action != nil
    }

    private func activate(_ item: NSMenuItem) {
        guard isPresented, canPerform(item) else { return }
        dismiss()
        // Session cancellation may synchronously mutate the menu. Resolve identity again afterwards.
        guard canPerform(item) else { return }
        menu.performActionForItem(at: menu.index(of: item))
    }

    @objc private func clicked(_ sender: StatusItemMenuButton) { activate(sender.menuItem) }

    private func select(_ item: NSMenuItem?, focus: Bool = false) {
        selectedItem = item.flatMap { canPerform($0) ? $0 : nil }
        for button in buttons.values { button.setSelected(button.menuItem === selectedItem) }
        if focus, let selectedItem, let button = buttons[ObjectIdentifier(selectedItem)], panel.firstResponder !== button {
            panel.makeFirstResponder(button)
        }
    }

    private func refresh() {
        guard isPresented else { return }
        let hadButtonFocus = buttons.values.contains { panel.firstResponder === $0 }
        var items: [NSMenuItem] = []
        for item in menu.items where !item.isHidden {
            if item.isSeparatorItem && (items.isEmpty || items.last?.isSeparatorItem == true) { continue }
            items.append(item)
        }
        if items.last?.isSeparatorItem == true { items.removeLast() }
        guard items.contains(where: { !$0.isSeparatorItem }) else { dismiss(); return }
        let font = NSFont.menuFont(ofSize: 13)
        let width = max(160, items.filter { !$0.isSeparatorItem }.map {
            ($0.title as NSString).size(withAttributes: [.font: font]).width + 54
        }.max() ?? 160)
        let height = items.reduce(CGFloat(8)) { $0 + ($1.isSeparatorItem ? 9 : 26) }
        let frame = Self.frame(for: NSSize(width: width, height: height), anchor: anchor, visibleFrames: visibleFrames)
        let background = StatusItemMenuBackground(frame: NSRect(origin: .zero, size: frame.size))
        buttons.removeAll()
        var y: CGFloat = 4
        for item in items {
            if item.isSeparatorItem {
                let separator = NSBox(frame: NSRect(x: 16, y: y + 4, width: frame.width - 32, height: 1))
                separator.boxType = .separator
                background.addSubview(separator)
                y += 9
                continue
            }
            let button = StatusItemMenuButton(item: item)
            button.frame = NSRect(x: 4, y: y, width: frame.width - 8, height: 26)
            button.target = self
            button.action = #selector(clicked(_:))
            button.hover = { [weak self, weak item] entered in
                guard let self else { return }
                if entered { self.select(item) }
                else if self.selectedItem === item { self.select(nil) }
            }
            button.focus = { [weak self, weak item] in self?.select(item) }
            buttons[ObjectIdentifier(item)] = button
            background.addSubview(button)
            y += 26
        }
        panel.setFrame(frame, display: false)
        panel.contentView = background
        let current = selectedItem.flatMap { canPerform($0) ? $0 : nil }
        select(current ?? items.first(where: canPerform), focus: hadButtonFocus)
    }

    private func observeMenuAndSpace() {
        for name in [NSMenu.didAddItemNotification, NSMenu.didRemoveItemNotification, NSMenu.didChangeItemNotification] {
            menuObservers.append(NotificationCenter.default.addObserver(forName: name, object: menu, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
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

@MainActor
final class StatusItemMenuWindow: NSPanel {
    var handleKey: (@MainActor (NSEvent) -> Bool)?
    var dismissAction: (@MainActor () -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 220, height: 105), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        setAccessibilityTitle("Prism")
    }

    override func sendEvent(_ event: NSEvent) {
        if handleKey?(event) == true { return }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) { dismissAction?() }
    override func resignKey() { super.resignKey(); dismissAction?() }
}

@MainActor
private final class StatusItemMenuBackground: NSVisualEffectView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .menu
        blendingMode = .behindWindow
        state = .active
        // Public material mask also gives the existing window shadow its rounded outline.
        let mask = NSImage(size: NSSize(width: 21, height: 21), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        mask.resizingMode = .stretch
        maskImage = mask
    }

    required init?(coder: NSCoder) { nil }
}

/// Keep native cell drawing and accessibility while giving icon and title explicit menu spacing.
@MainActor
private final class StatusItemMenuButtonCell: NSButtonCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect { rect }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        guard image != nil else { return .zero }
        return NSRect(x: rect.minX + 12, y: rect.midY - 7, width: 14, height: 14)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        let leading: CGFloat = image == nil ? 12 : 34
        let height = min(ceil(attributedTitle.size().height), rect.height)
        return NSRect(x: rect.minX + leading, y: rect.midY - height / 2,
                      width: max(0, rect.width - leading - 12), height: height)
    }
}

@MainActor
private final class StatusItemMenuButton: NSButton {
    let menuItem: NSMenuItem
    var hover: (@MainActor (Bool) -> Void)?
    var focus: (@MainActor () -> Void)?
    private var selected = false
    private var tracking: NSTrackingArea?
    override var acceptsFirstResponder: Bool { isEnabled }

    init(item: NSMenuItem) {
        menuItem = item
        super.init(frame: .zero)
        cell = StatusItemMenuButtonCell(textCell: item.title)
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
        let color: NSColor = !isEnabled ? .disabledControlTextColor : selected ? .selectedMenuItemTextColor : .labelColor
        attributedTitle = NSAttributedString(string: title, attributes: [.font: font ?? NSFont.menuFont(ofSize: 13), .foregroundColor: color])
        contentTintColor = color
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
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
