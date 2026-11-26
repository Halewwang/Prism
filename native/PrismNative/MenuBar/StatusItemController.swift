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
            Task { @MainActor [weak self] in
                self?.menuPanel?.dismiss()
            }
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
final class StatusItemController: NSObject, NSMenuDelegate {
    private enum ExternalLinks {
        static let homepage = URL(string: "https://github.com/Halewwang/Prism")!
        static let reportIssue = URL(string: "https://github.com/Halewwang/Prism/issues")!
        static let privacy = URL(string: "https://github.com/Halewwang/Prism#readme")!
    }

    private let host: any StatusItemHosting
    private let mainWindowOpening: MainWindowOpening
    private let environment: AppEnvironment
    private let terminate: @MainActor () -> Void
    private let clipboardURLProvider: @MainActor () -> URL?
    private let openClipboardURLAction: (@MainActor (URL) -> Void)?
    private let openAboutAction: @MainActor () -> Void
    private let openExternalURLAction: @MainActor (URL) -> Void
    private let menu = NSMenu(title: "Prism")
    private let moreSubmenu = NSMenu(title: "More")

    private var automaticRulesItem: NSMenuItem!
    private var openClipboardLinkItem: NSMenuItem!
    private var historyItem: NSMenuItem!
    private var rulesItem: NSMenuItem!
    private var browsersItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var checkForUpdatesItem: NSMenuItem!
    private var moreItem: NSMenuItem!
    private var aboutItem: NSMenuItem!
    private var homepageItem: NSMenuItem!
    private var reportIssueItem: NSMenuItem!
    private var privacyItem: NSMenuItem!
    private var hideDockIconItem: NSMenuItem!
    private var quitPrismItem: NSMenuItem!

    init(
        host: any StatusItemHosting = AppKitStatusItemHost(),
        mainWindowOpening: MainWindowOpening,
        environment: AppEnvironment,
        terminate: @escaping @MainActor () -> Void = { NSApplication.shared.terminate(nil) },
        clipboardURLProvider: @escaping @MainActor () -> URL? = { StatusItemController.clipboardWebURL() },
        openClipboardURL: (@MainActor (URL) -> Void)? = nil,
        openAbout: @escaping @MainActor () -> Void = { PrismAboutWindowController.shared.present() },
        openExternalURL: @escaping @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.host = host
        self.mainWindowOpening = mainWindowOpening
        self.environment = environment
        self.terminate = terminate
        self.clipboardURLProvider = clipboardURLProvider
        self.openClipboardURLAction = openClipboardURL
        self.openAboutAction = openAbout
        self.openExternalURLAction = openExternalURL
        super.init()

        configureMenu()
        synchronizeWithEnvironment()
        observeSettings()
        host.install(menu: menu)
    }

    static func clipboardWebURL(from pasteboard: NSPasteboard = .general) -> URL? {
        let candidates = [
            pasteboard.string(forType: .URL),
            pasteboard.string(forType: .string)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        for candidate in candidates where !candidate.isEmpty {
            guard let components = URLComponents(string: candidate),
                  let url = components.url,
                  BootstrapLinkBuffer.accepts(url),
                  let host = url.host,
                  !host.isEmpty
            else { continue }
            return url
        }
        return nil
    }

    private func configureMenu() {
        menu.removeAllItems()
        menu.autoenablesItems = false
        menu.delegate = self

        moreSubmenu.removeAllItems()
        moreSubmenu.autoenablesItems = false
        moreSubmenu.delegate = self

        // Group 1: Core routing controls & quick actions
        automaticRulesItem = makeItem(
            title: "",
            action: #selector(toggleAutomaticRules),
            symbol: "pause.circle"
        )
        menu.addItem(automaticRulesItem)

        openClipboardLinkItem = makeItem(
            title: localized("status.openClipboardLink", "Open Clipboard Link"),
            action: #selector(openClipboardLink),
            symbol: "doc.on.clipboard"
        )
        menu.addItem(openClipboardLinkItem)

        // Group 2: Workspace navigation
        menu.addItem(.separator())
        historyItem = makeItem(
            title: localized("status.history", "History"),
            action: #selector(openHistory),
            symbol: "clock",
            keyEquivalent: "1"
        )
        menu.addItem(historyItem)

        rulesItem = makeItem(
            title: localized("status.rules", "Routing Rules"),
            action: #selector(openRules),
            symbol: "arrow.triangle.branch",
            keyEquivalent: "2"
        )
        menu.addItem(rulesItem)

        browsersItem = makeItem(
            title: localized("status.browsers", "Manage Browsers"),
            action: #selector(openBrowsers),
            symbol: "globe"
        )
        menu.addItem(browsersItem)

        // Group 3: Preferences
        menu.addItem(.separator())
        settingsItem = makeItem(
            title: localized("status.settings", "Settings"),
            action: #selector(openSettings),
            symbol: "gearshape",
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)

        // Group 4: Updates & More
        menu.addItem(.separator())
        checkForUpdatesItem = makeItem(
            title: localized("status.checkForUpdates", "Check for Updates"),
            action: #selector(checkForUpdates),
            symbol: "arrow.triangle.2.circlepath"
        )
        menu.addItem(checkForUpdatesItem)

        configureMoreSubmenu()
        moreItem = NSMenuItem(
            title: localized("status.more", "More"),
            action: nil,
            keyEquivalent: ""
        )
        moreItem.image = StatusItemVisuals.menuSymbol("ellipsis.circle")
        moreItem.isEnabled = true
        moreItem.submenu = moreSubmenu
        menu.addItem(moreItem)

        // Group 5: Quit
        menu.addItem(.separator())
        quitPrismItem = makeItem(
            title: localized("status.quit", "Quit"),
            action: #selector(quitPrism),
            symbol: "power",
            keyEquivalent: "q"
        )
        menu.addItem(quitPrismItem)
    }

    private func configureMoreSubmenu() {
        aboutItem = makeItem(
            title: localized("status.about", "About Prism"),
            action: #selector(openAbout),
            symbol: "info.circle"
        )
        moreSubmenu.addItem(aboutItem)

        homepageItem = makeItem(
            title: localized("status.homepage", "Project Homepage"),
            action: #selector(openHomepage),
            symbol: "safari"
        )
        moreSubmenu.addItem(homepageItem)

        reportIssueItem = makeItem(
            title: localized("status.reportIssue", "Report an Issue"),
            action: #selector(openReportIssue),
            symbol: "exclamationmark.bubble"
        )
        moreSubmenu.addItem(reportIssueItem)

        privacyItem = makeItem(
            title: localized("status.privacy", "Privacy & Local-First"),
            action: #selector(openPrivacy),
            symbol: "lock.shield"
        )
        moreSubmenu.addItem(privacyItem)

        moreSubmenu.addItem(.separator())
        hideDockIconItem = makeItem(
            title: localized("status.hideDockIcon", "Hide Dock Icon"),
            action: #selector(toggleHideDockIcon),
            symbol: "dock.rectangle"
        )
        moreSubmenu.addItem(hideDockIconItem)
    }

    private func makeItem(
        title: String,
        action: Selector,
        symbol: String,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifiers
        }
        item.target = self
        item.image = StatusItemVisuals.menuSymbol(symbol)
        item.isEnabled = true
        return item
    }

    private func synchronizeWithEnvironment() {
        let rulesEnabled = environment.settings.automaticRulesEnabled
        automaticRulesItem.title = rulesEnabled
            ? localized("status.pauseRules", "Pause Auto Routing")
            : localized("status.resumeRules", "Resume Auto Routing")
        automaticRulesItem.image = StatusItemVisuals.menuSymbol(
            rulesEnabled ? "pause.circle" : "play.circle"
        )
        automaticRulesItem.badge = rulesEnabled
            ? nil
            : NSMenuItemBadge(string: localized("status.pausedBadge", "Paused"))

        openClipboardLinkItem.title = localized("status.openClipboardLink", "Open Clipboard Link")
        refreshDynamicItemAvailability()

        historyItem.title = localized("status.history", "History")
        rulesItem.title = localized("status.rules", "Routing Rules")
        browsersItem.title = localized("status.browsers", "Manage Browsers")
        settingsItem.title = localized("status.settings", "Settings")

        checkForUpdatesItem.title = localized("status.checkForUpdates", "Check for Updates")

        moreItem.title = localized("status.more", "More")
        moreSubmenu.title = moreItem.title
        aboutItem.title = localized("status.about", "About Prism")
        homepageItem.title = localized("status.homepage", "Project Homepage")
        reportIssueItem.title = localized("status.reportIssue", "Report an Issue")
        privacyItem.title = localized("status.privacy", "Privacy & Local-First")
        hideDockIconItem.title = localized("status.hideDockIcon", "Hide Dock Icon")
        hideDockIconItem.state = environment.settings.hideDockIcon ? .on : .off

        quitPrismItem.title = localized("status.quit", "Quit")
        host.setVisible(environment.settings.showMenuBarItem || environment.startupPhase == .recovery)
    }

    private func refreshDynamicItemAvailability(for targetMenu: NSMenu? = nil) {
        if targetMenu == nil || targetMenu === menu {
            let canCheckUpdates = environment.updateChecker.canCheckForUpdates
            if checkForUpdatesItem.isEnabled != canCheckUpdates {
                checkForUpdatesItem.isEnabled = canCheckUpdates
            }
            let hasClipboardHandler = openClipboardURLAction != nil || environment.linkIntakeService != nil
            let canOpenClipboard = hasClipboardHandler && clipboardURLProvider() != nil
            if openClipboardLinkItem.isEnabled != canOpenClipboard {
                openClipboardLinkItem.isEnabled = canOpenClipboard
            }
        }
        if targetMenu == nil || targetMenu === moreSubmenu {
            let desiredState: NSControl.StateValue = environment.settings.hideDockIcon ? .on : .off
            if hideDockIconItem.state != desiredState {
                hideDockIconItem.state = desiredState
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshDynamicItemAvailability(for: menu)
    }

    private func observeSettings() {
        withObservationTracking {
            _ = environment.settings.automaticRulesEnabled
            _ = environment.settings.showMenuBarItem
            _ = environment.settings.hideDockIcon
            _ = environment.settings.language
            _ = environment.startupPhase
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

    @objc private func toggleAutomaticRules() {
        let nextValue = !environment.settings.automaticRulesEnabled
        guard environment.mutateSettings({ $0.automaticRulesEnabled = nextValue }) else {
            return
        }
        synchronizeWithEnvironment()
    }

    @objc private func openClipboardLink() {
        guard let url = clipboardURLProvider() else {
            refreshDynamicItemAvailability()
            return
        }
        if let openClipboardURLAction {
            openClipboardURLAction(url)
        } else {
            _ = environment.linkIntakeService?.capture(url: url, senderPID: nil)
        }
    }

    @objc private func openHistory() {
        mainWindowOpening.open(route: .history)
    }

    @objc private func openRules() {
        mainWindowOpening.open(route: .rules)
    }

    @objc private func openBrowsers() {
        environment.stageBrowserManagement()
        mainWindowOpening.open(route: .settings)
    }

    @objc private func openSettings() {
        mainWindowOpening.open(route: .settings)
    }

    @objc private func checkForUpdates() {
        guard environment.updateChecker.canCheckForUpdates else { return }
        environment.updateChecker.checkForUpdates()
    }

    @objc private func openAbout() {
        openAboutAction()
    }

    @objc private func openHomepage() {
        openExternalURLAction(ExternalLinks.homepage)
    }

    @objc private func openReportIssue() {
        openExternalURLAction(ExternalLinks.reportIssue)
    }

    @objc private func openPrivacy() {
        openExternalURLAction(ExternalLinks.privacy)
    }

    @objc private func toggleHideDockIcon() {
        let nextValue = !environment.settings.hideDockIcon
        guard environment.mutateSettings({ $0.hideDockIcon = nextValue }) else {
            return
        }
        synchronizeWithEnvironment()
    }

    @objc private func quitPrism() {
        terminate()
    }
}
