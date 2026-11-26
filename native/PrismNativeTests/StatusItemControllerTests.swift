import AppKit
import PrismCore
import Testing
@testable import PrismNative

@Suite("Status item")
@MainActor
struct StatusItemControllerTests {
    @Test func installsTheExactMenuInTheRequiredOrderWithIconsAndShortcuts() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )

        _ = fixture.makeController()

        let menu = try #require(fixture.host.menu)
        #expect(menu.items.map(menuLabel) == [
            "Pause Auto Routing",
            "Open Clipboard Link",
            "<separator>",
            "History",
            "Routing Rules",
            "Manage Browsers",
            "<separator>",
            "Settings",
            "Check for Updates",
            "<separator>",
            "Quit",
        ])
        #expect(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { $0.image != nil })
        #expect(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { $0.image?.isTemplate == true })

        let historyItem = try #require(item(titled: "History", in: menu))
        #expect(historyItem.keyEquivalent == "1")
        #expect(historyItem.keyEquivalentModifierMask == [.command])

        let rulesItem = try #require(item(titled: "Routing Rules", in: menu))
        #expect(rulesItem.keyEquivalent == "2")
        #expect(rulesItem.keyEquivalentModifierMask == [.command])

        let settingsItem = try #require(item(titled: "Settings", in: menu))
        #expect(settingsItem.keyEquivalent == ",")
        #expect(settingsItem.keyEquivalentModifierMask == [.command])

        let quitItem = try #require(item(titled: "Quit", in: menu))
        #expect(quitItem.keyEquivalent == "q")
        #expect(quitItem.keyEquivalentModifierMask == [.command])

        #expect(item(titled: "More", in: menu) == nil)
        #expect(fixture.host.installCount == 1)
        #expect(fixture.host.isVisible)
    }

    @Test func workspaceNavigationItemsOpenTheExpectedRoutesAndBrowserSheet() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        try invokeItem(titled: "Routing Rules", in: menu)
        #expect(fixture.windows.routes == [.rules])
        #expect(fixture.environment.route == .rules)

        try invokeItem(titled: "History", in: menu)
        #expect(fixture.windows.routes == [.rules, .history])
        #expect(fixture.environment.route == .history)

        try invokeItem(titled: "Manage Browsers", in: menu)
        #expect(fixture.windows.routes == [.rules, .history, .settings])
        #expect(fixture.environment.pendingBrowserManagement)
        #expect(fixture.environment.consumeBrowserManagement())

        try invokeItem(titled: "Settings", in: menu)
        #expect(fixture.windows.routes == [.rules, .history, .settings, .settings])
        #expect(!fixture.environment.pendingBrowserManagement)
        #expect(fixture.windows.openedWindowIDs.allSatisfy { $0 == "main" })
        #expect(fixture.windows.openedValues.allSatisfy { $0 == .singleton })
    }

    @Test func openClipboardLinkTracksAvailabilityAndDispatchesValidURL() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        let url = try #require(URL(string: "https://example.com/docs"))
        var clipboardURL: URL? = nil
        var openedURLs: [URL] = []
        let controller = fixture.makeController(
            clipboardURLProvider: { clipboardURL },
            openClipboardURL: { openedURLs.append($0) }
        )
        let menu = try #require(fixture.host.menu)
        let clipboardItem = try #require(item(titled: "Open Clipboard Link", in: menu))

        #expect(!clipboardItem.isEnabled)

        clipboardURL = url
        controller.menuNeedsUpdate(menu)
        #expect(clipboardItem.isEnabled)

        try invokeItem(titled: "Open Clipboard Link", in: menu)
        #expect(openedURLs == [url])

        clipboardURL = nil
        controller.menuNeedsUpdate(menu)
        #expect(!clipboardItem.isEnabled)
    }

    @Test func clipboardWebURLParserAcceptsHttpAndHttpsAndRejectsInvalidText() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        pasteboard.clearContents()
        pasteboard.setString("  https://github.com/Halewwang/Prism \n", forType: .string)
        #expect(StatusItemController.clipboardWebURL(from: pasteboard)?.absoluteString == "https://github.com/Halewwang/Prism")

        pasteboard.clearContents()
        pasteboard.setString("http://localhost:3000/test", forType: .string)
        #expect(StatusItemController.clipboardWebURL(from: pasteboard)?.absoluteString == "http://localhost:3000/test")

        pasteboard.clearContents()
        pasteboard.setString("not a url", forType: .string)
        #expect(StatusItemController.clipboardWebURL(from: pasteboard) == nil)

        pasteboard.clearContents()
        pasteboard.setString("https://", forType: .string)
        #expect(StatusItemController.clipboardWebURL(from: pasteboard) == nil)

        pasteboard.clearContents()
        pasteboard.setString("file:///tmp/demo.html", forType: .string)
        #expect(StatusItemController.clipboardWebURL(from: pasteboard) == nil)
    }

    @Test func pauseAndResumeChangeOnlyTheDurableAutomaticRuleSettingAndBadge() async throws {
        var settings = AppSettings.defaults
        settings.automaticRulesEnabled = true
        settings.showMenuBarItem = true
        settings.lastUsedBrowserID = "com.example.kept"
        settings.historyLimit = 321
        settings.language = .english
        let fixture = await StatusItemFixture.make(route: .history, settings: settings)
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        #expect(menu.items[0].badge == nil)
        try invokeItem(at: 0, in: menu)

        var expected = settings
        expected.automaticRulesEnabled = false
        #expect(try fixture.settingsRepository.load() == expected)
        #expect(fixture.environment.settings == expected)
        #expect(menu.items[0].title == "Resume Auto Routing")
        #expect(menu.items[0].badge?.stringValue == "Paused")
        #expect(fixture.termination.count == 0)

        try invokeItem(at: 0, in: menu)

        #expect(try fixture.settingsRepository.load() == settings)
        #expect(fixture.environment.settings == settings)
        #expect(menu.items[0].title == "Pause Auto Routing")
        #expect(menu.items[0].badge == nil)
    }

    @Test func failedPauseSaveDoesNotFlipStateOrMenuLabel() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)
        fixture.settingsRepository.shouldFailSave = true

        try invokeItem(at: 0, in: menu)

        #expect(fixture.environment.settings.automaticRulesEnabled)
        #expect(try fixture.settingsRepository.load().automaticRulesEnabled)
        #expect(menu.items[0].title == "Pause Auto Routing")
        #expect(fixture.environment.persistenceWarnings.contains(.settingsNotSaved))
    }

    @Test func quitUsesOnlyTheInjectedTerminationAction() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        try invokeItem(titled: "Quit", in: menu)

        #expect(fixture.termination.count == 1)
        #expect(fixture.windows.routes.isEmpty)
    }

    @Test func visibilityTracksTheSharedMenuBarSetting() async {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        let controller = fixture.makeController()
        #expect(fixture.host.isVisible)

        #expect(fixture.environment.mutateSettings { $0.showMenuBarItem = false })
        await waitUntil { !fixture.host.isVisible }
        #expect(!fixture.host.isVisible)

        #expect(fixture.environment.mutateSettings { $0.showMenuBarItem = true })
        await waitUntil { fixture.host.isVisible }
        #expect(fixture.host.isVisible)

        _ = controller
    }

    @Test func checkForUpdatesUsesTheSharedCheckerWithoutOpeningTheMainWindow() async throws {
        let checker = RecordingStatusItemUpdateChecker()
        var settings = AppSettings.defaults
        settings.language = .english
        let fixture = await StatusItemFixture.make(route: .history, settings: settings, updateChecker: checker)
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)
        let updateItem = try #require(item(titled: "Check for Updates", in: menu))

        #expect(updateItem.isEnabled)
        try invokeItem(at: menu.index(of: updateItem), in: menu)

        #expect(checker.checkCount == 1)
        #expect(fixture.windows.routes.isEmpty)
        #expect(fixture.environment.route == .history)
    }

    @Test func updateAvailabilityRefreshesBeforeTheMenuPanelOpens() async throws {
        let checker = RecordingStatusItemUpdateChecker()
        checker.canCheckForUpdates = false
        var settings = AppSettings.defaults
        settings.language = .english
        let fixture = await StatusItemFixture.make(route: .history, settings: settings, updateChecker: checker)
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)
        let updateItem = try #require(item(titled: "Check for Updates", in: menu))
        let panel = StatusItemMenuPanel(menu: menu, cancelSession: {}, orderFront: { _ in })
        defer { panel.dismiss() }

        #expect(!updateItem.isEnabled)
        try invokeItem(at: menu.index(of: updateItem), in: menu)
        #expect(checker.checkCount == 0)

        checker.canCheckForUpdates = true
        panel.present(anchor: NSRect(x: 100, y: 800, width: 24, height: 18),
                      visibleFrames: [NSRect(x: 0, y: 0, width: 1000, height: 800)])
        #expect(updateItem.isEnabled)
        #expect(panel.button(for: updateItem)?.isEnabled == true)
        panel.dismiss()

        checker.canCheckForUpdates = false
        panel.present(anchor: NSRect(x: 100, y: 800, width: 24, height: 18),
                      visibleFrames: [NSRect(x: 0, y: 0, width: 1000, height: 800)])
        #expect(!updateItem.isEnabled)
        #expect(panel.button(for: updateItem)?.isEnabled == false)
    }

    @Test func automaticRulesLabelTracksChangesFromTheMainWindow() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        let controller = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        #expect(fixture.environment.mutateSettings { $0.automaticRulesEnabled = false })
        await waitUntil { menu.items[0].title == "Resume Auto Routing" }
        #expect(menu.items[0].title == "Resume Auto Routing")
        #expect(menu.items[0].badge?.stringValue == "Paused")

        #expect(fixture.environment.mutateSettings { $0.automaticRulesEnabled = true })
        await waitUntil { menu.items[0].title == "Pause Auto Routing" }
        #expect(menu.items[0].title == "Pause Auto Routing")
        #expect(menu.items[0].badge == nil)

        _ = controller
    }

    @Test func prismMenuBarMarkIsAnAccessibleTemplateImage() {
        let image = StatusItemVisuals.prismMark()

        #expect(image.size == NSSize(width: 18, height: 18))
        #expect(image.isTemplate)
        #expect(image.accessibilityDescription == "Prism")
    }

    @Test func menuUsesTheSelectedAppLanguage() async throws {
        var settings = AppSettings.defaults
        settings.language = .simplifiedChinese
        settings.automaticRulesEnabled = true
        settings.showMenuBarItem = true
        let fixture = await StatusItemFixture.make(route: .history, settings: settings)

        _ = fixture.makeController()

        let menu = try #require(fixture.host.menu)
        #expect(menu.items.map(menuLabel) == [
            "暂停自动分流",
            "打开剪贴板链接",
            "<separator>",
            "历史记录",
            "分流规则",
            "浏览器管理",
            "<separator>",
            "偏好设置",
            "检查更新",
            "<separator>",
            "退出",
        ])
    }

    private func menuLabel(_ item: NSMenuItem) -> String {
        item.isSeparatorItem ? "<separator>" : item.title
    }

    private func item(titled title: String, in menu: NSMenu) -> NSMenuItem? {
        menu.items.first { !$0.isSeparatorItem && $0.title == title }
    }

    private func invokeItem(titled title: String, in menu: NSMenu) throws {
        let target = try #require(item(titled: title, in: menu))
        try invokeItem(at: menu.index(of: target), in: menu)
    }

    private func invokeItem(at index: Int, in menu: NSMenu) throws {
        try #require(menu.items.indices.contains(index))
        let item = menu.items[index]
        let action = try #require(item.action)
        #expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}

@MainActor
private final class StatusItemFixture {
    let environment: AppEnvironment
    let settingsRepository: StatusItemSettingsRepository
    let host = RecordingStatusItemHost()
    let windows = RecordingMainWindowOpening()
    let termination = TerminationRecorder()
    private var retainedController: StatusItemController?

    private init(
        environment: AppEnvironment,
        settingsRepository: StatusItemSettingsRepository
    ) {
        self.environment = environment
        self.settingsRepository = settingsRepository
    }

    static func make(
        route: AppRoute,
        automaticRulesEnabled: Bool,
        showMenuBarItem: Bool
    ) async -> StatusItemFixture {
        var settings = AppSettings.defaults
        settings.automaticRulesEnabled = automaticRulesEnabled
        settings.showMenuBarItem = showMenuBarItem
        settings.language = .english
        return await make(route: route, settings: settings)
    }

    static func make(
        route: AppRoute,
        settings: AppSettings,
        updateChecker: (any UpdateChecking)? = nil
    ) async -> StatusItemFixture {
        let repository = StatusItemSettingsRepository(settings: settings)
        let environment = AppEnvironment(
            route: route,
            unmatchedBehavior: settings.unmatchedBehavior,
            updateChecker: updateChecker ?? DisabledUpdateChecker(),
            ruleRepository: InMemoryRuleRepository(),
            historyRepository: InMemoryHistoryRepository(),
            browserPreferenceRepository: InMemoryBrowserPreferenceRepository(),
            settingsRepository: repository
        )
        let queue = LinkRequestQueue(store: InMemoryPendingRequestStore())
        let restored = await environment.restoreAndReconcile(queue: queue, warningSource: nil)
        precondition(restored)
        return StatusItemFixture(environment: environment, settingsRepository: repository)
    }

    func makeController(
        clipboardURLProvider: @escaping @MainActor () -> URL? = { nil },
        openClipboardURL: (@MainActor (URL) -> Void)? = nil
    ) -> StatusItemController {
        let opening = MainWindowOpening { [environment, windows] route in
            environment.updateRoute(route)
            windows.routes.append(route)
        }
        opening.register { [windows] id, value in
            windows.openedWindowIDs.append(id)
            windows.openedValues.append(value)
        }
        let controller = StatusItemController(
            host: host,
            mainWindowOpening: opening,
            environment: environment,
            terminate: { [termination] in termination.count += 1 },
            clipboardURLProvider: clipboardURLProvider,
            openClipboardURL: openClipboardURL
        )
        retainedController = controller
        return controller
    }
}

@MainActor
private final class RecordingStatusItemUpdateChecker: UpdateChecking {
    let events = AsyncStream<UpdateEvent> { $0.finish() }
    var canCheckForUpdates = true
    var automaticallyChecksForUpdates = false
    private(set) var checkCount = 0

    func checkForUpdates() { checkCount += 1 }
}

@MainActor
private final class RecordingStatusItemHost: StatusItemHosting {
    private(set) var menu: NSMenu?
    private(set) var installCount = 0
    private(set) var isVisible = false

    func install(menu: NSMenu) {
        self.menu = menu
        installCount += 1
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
    }
}

@MainActor
private final class RecordingMainWindowOpening {
    var routes: [AppRoute] = []
    var openedWindowIDs: [String] = []
    var openedValues: [MainWindowIdentity] = []
}

@MainActor
private final class TerminationRecorder {
    var count = 0
}

@MainActor
private final class StatusItemSettingsRepository: SettingsRepository {
    private enum Failure: Error {
        case save
    }

    private var settings: AppSettings
    var shouldFailSave = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        if shouldFailSave {
            throw Failure.save
        }
        self.settings = settings
    }
}
