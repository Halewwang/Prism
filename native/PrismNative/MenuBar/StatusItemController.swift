import AppKit
import Observation

enum StatusItemVisuals {
    static func prismMark() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = (NSImage(named: "PrismMenuBar")?.copy() as? NSImage)
            ?? NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Prism")
            ?? NSImage(size: size)
        image.size = size
        image.isTemplate = true
        image.accessibilityDescription = "Prism"
        return image
    }

    static func menuSymbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}

@MainActor
protocol StatusItemHosting: AnyObject {
    func install(menu: NSMenu)
    func setVisible(_ isVisible: Bool)
}

@MainActor
final class AppKitStatusItemHost: NSObject, StatusItemHosting {
    private let statusItem: NSStatusItem
    private var menuPanel: StatusItemMenuPanel?
    private var visibilityObservation: NSKeyValueObservation?

    init(statusBar: NSStatusBar = .system) {
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            button.image = StatusItemVisuals.prismMark()
            button.toolTip = "Prism"
        }
        visibilityObservation = statusItem.observe(\.isVisible, options: [.new]) { [weak self] _, change in
            guard change.newValue == false else { return }
            MainActor.assumeIsolated { self?.menuPanel?.dismiss() }
        }
    }

    isolated deinit {
        visibilityObservation?.invalidate()
        menuPanel?.dismiss()
        if #available(macOS 27.0, *) {
            statusItem.expandedInterfaceSession?.cancel()
            statusItem.expandedInterfaceDelegate = nil
        }
        statusItem.statusBar?.removeStatusItem(statusItem)
    }

    func install(menu: NSMenu) {
        menuPanel?.dismiss()
        if #available(macOS 27.0, *) {
            // Keep the exact NSMenu model; only its presentation changes on affected systems.
            statusItem.menu = nil
            menuPanel = StatusItemMenuPanel(menu: menu, cancelSession: { [weak self] in
                self?.statusItem.expandedInterfaceSession?.cancel()
            }, statusButtonRect: { [weak self] in self?.buttonScreenRect() })
            statusItem.expandedInterfaceDelegate = self
        } else {
            statusItem.menu = menu
        }
    }

    func setVisible(_ isVisible: Bool) {
        if !isVisible { menuPanel?.dismiss() }
        statusItem.isVisible = isVisible
    }

    private func buttonScreenRect() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
}

@available(macOS 27.0, *)
extension AppKitStatusItemHost: @preconcurrency NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin session: NSStatusItemExpandedInterfaceSession) {
        guard statusItem.isVisible, let anchor = buttonScreenRect() else { session.cancel(); return }
        // The button lies in the menu bar, outside visibleFrame. Locate its full display first.
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? statusItem.button?.window?.screen ?? NSScreen.main
        menuPanel?.present(anchor: anchor, visibleFrames: screen.map { [$0.visibleFrame] } ?? [])
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        menuPanel?.dismiss(cancelSession: false)
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let host: any StatusItemHosting
    private let mainWindowOpening: MainWindowOpening
    private let environment: AppEnvironment
    private let terminate: @MainActor () -> Void
    private let menu = NSMenu(title: "Prism")
    private var automaticRulesItem: NSMenuItem!

    init(
        host: any StatusItemHosting = AppKitStatusItemHost(),
        mainWindowOpening: MainWindowOpening,
        environment: AppEnvironment,
        terminate: @escaping @MainActor () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.host = host
        self.mainWindowOpening = mainWindowOpening
        self.environment = environment
        self.terminate = terminate
        super.init()

        configureMenu()
        synchronizeWithEnvironment()
        observeSettings()
        host.install(menu: menu)
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.autoenablesItems = false
        menu.addItem(makeItem(title: localized("status.openPrism", "Open Prism"), action: #selector(openPrism), symbol: "rectangle.on.rectangle"))

        automaticRulesItem = makeItem(title: "", action: #selector(toggleAutomaticRules), symbol: "pause.circle")
        menu.addItem(automaticRulesItem)

        menu.addItem(.separator())
        menu.addItem(makeItem(title: localized("status.quit", "Quit Prism"), action: #selector(quitPrism), symbol: "power"))
    }

    private func makeItem(title: String, action: Selector, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = StatusItemVisuals.menuSymbol(symbol)
        item.isEnabled = true
        return item
    }

    private func synchronizeWithEnvironment() {
        automaticRulesItem.title = environment.settings.automaticRulesEnabled
            ? localized("status.pauseRules", "Pause Automatic Rules")
            : localized("status.resumeRules", "Resume Automatic Rules")
        automaticRulesItem.image = StatusItemVisuals.menuSymbol(
            environment.settings.automaticRulesEnabled ? "pause.circle" : "play.circle"
        )
        host.setVisible(environment.settings.showMenuBarItem)
    }

    private func observeSettings() {
        withObservationTracking {
            _ = environment.settings.automaticRulesEnabled
            _ = environment.settings.showMenuBarItem
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.synchronizeWithEnvironment()
                self.observeSettings()
            }
        }
    }

    private func localized(_ key: String, _ defaultValue: String) -> String {
        guard let code = environment.settings.language.interfaceLocalizationCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
        }
        return bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    @objc private func openPrism() {
        mainWindowOpening.open(route: environment.route)
    }

    @objc private func toggleAutomaticRules() {
        let nextValue = !environment.settings.automaticRulesEnabled
        guard environment.mutateSettings({ $0.automaticRulesEnabled = nextValue }) else {
            return
        }
        synchronizeWithEnvironment()
    }

    @objc private func quitPrism() {
        terminate()
    }
}
