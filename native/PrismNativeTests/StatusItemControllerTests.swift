import AppKit
import PrismCore
import Testing
@testable import PrismNative

@Suite("Status item")
@MainActor
struct StatusItemControllerTests {
    @Test func installsTheExactMenuInTheRequiredOrder() async throws {
        let fixture = await StatusItemFixture.make(
            route: .history,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )

        _ = fixture.makeController()

        let menu = try #require(fixture.host.menu)
        #expect(menu.items.map(menuLabel) == [
            "Open Prism",
            "Pause Automatic Rules",
            "<separator>",
            "Check for Updates",
            "Quit Prism",
        ])
        #expect(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { $0.image != nil })
        #expect(menu.items[0].image?.isTemplate == true)
        #expect(fixture.host.installCount == 1)
        #expect(fixture.host.isVisible)
    }

    @Test func openPrismPreservesTheCurrentRouteAndUsesTheSingletonWindowAdapter() async throws {
        let fixture = await StatusItemFixture.make(
            route: .rules,
            automaticRulesEnabled: true,
            showMenuBarItem: true
        )
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        try invokeItem(at: 0, in: menu)

        #expect(fixture.windows.routes == [.rules])
        #expect(fixture.windows.openedWindowIDs == ["main"])
        #expect(fixture.windows.openedValues == [.singleton])
        #expect(fixture.environment.route == .rules)
    }

    @Test func pauseAndResumeChangeOnlyTheDurableAutomaticRuleSetting() async throws {
        var settings = AppSettings.defaults
        settings.automaticRulesEnabled = true
        settings.showMenuBarItem = true
        settings.lastUsedBrowserID = "com.example.kept"
        settings.historyLimit = 321
        settings.language = .english
        let fixture = await StatusItemFixture.make(route: .history, settings: settings)
        _ = fixture.makeController()
        let menu = try #require(fixture.host.menu)

        try invokeItem(at: 1, in: menu)

        var expected = settings
        expected.automaticRulesEnabled = false
        #expect(try fixture.settingsRepository.load() == expected)
        #expect(fixture.environment.settings == expected)
        #expect(menu.items[1].title == "Resume Automatic Rules")
        #expect(fixture.termination.count == 0)

        try invokeItem(at: 1, in: menu)

        #expect(try fixture.settingsRepository.load() == settings)
        #expect(fixture.environment.settings == settings)
        #expect(menu.items[1].title == "Pause Automatic Rules")
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

        try invokeItem(at: 1, in: menu)

        #expect(fixture.environment.settings.automaticRulesEnabled)
        #expect(try fixture.settingsRepository.load().automaticRulesEnabled)
        #expect(menu.items[1].title == "Pause Automatic Rules")
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

        try invokeItem(at: 4, in: menu)

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
        let item = try #require(menu.items.first { $0.title == "Check for Updates" })

        #expect(item.isEnabled)
        try invokeItem(at: menu.index(of: item), in: menu)

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
        let item = try #require(menu.items.first { $0.title == "Check for Updates" })
        let panel = StatusItemMenuPanel(menu: menu, cancelSession: {}, orderFront: { _ in })
        defer { panel.dismiss() }

        #expect(!item.isEnabled)
        try invokeItem(at: menu.index(of: item), in: menu)
        #expect(checker.checkCount == 0)

        checker.canCheckForUpdates = true
        panel.present(anchor: NSRect(x: 100, y: 800, width: 24, height: 18),
                      visibleFrames: [NSRect(x: 0, y: 0, width: 1000, height: 800)])
        #expect(item.isEnabled)
        #expect(panel.button(for: item)?.isEnabled == true)
        panel.dismiss()

        checker.canCheckForUpdates = false
        panel.present(anchor: NSRect(x: 100, y: 800, width: 24, height: 18),
                      visibleFrames: [NSRect(x: 0, y: 0, width: 1000, height: 800)])
        #expect(!item.isEnabled)
        #expect(panel.button(for: item)?.isEnabled == false)
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
        await waitUntil { menu.items[1].title == "Resume Automatic Rules" }
        #expect(menu.items[1].title == "Resume Automatic Rules")

        #expect(fixture.environment.mutateSettings { $0.automaticRulesEnabled = true })
        await waitUntil { menu.items[1].title == "Pause Automatic Rules" }
        #expect(menu.items[1].title == "Pause Automatic Rules")

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
        #expect(menu.items[0].title == "打开 Prism")
        #expect(menu.items[1].title == "暂停自动规则")
        #expect(menu.items[3].title == "检查更新")
    }

    private func menuLabel(_ item: NSMenuItem) -> String {
        item.isSeparatorItem ? "<separator>" : item.title
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

    func makeController() -> StatusItemController {
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
            terminate: { [termination] in termination.count += 1 }
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
