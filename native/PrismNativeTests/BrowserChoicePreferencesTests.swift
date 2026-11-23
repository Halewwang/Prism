import AppKit
import Foundation
import PrismCore
import SwiftData
import Testing
@testable import PrismNative

@Suite("Browser choice preferences")
@MainActor
struct BrowserChoicePreferencesTests {
    @Test func managementRowsDistinguishProfilesAndStaleCustomPaths() {
        let system = BrowserDescriptor(id: "browser", bundleIdentifier: "browser", displayName: "Browser", applicationURL: URL(fileURLWithPath: "/Applications/Browser.app"), securityScopedBookmark: nil, origin: .system, availability: .available, selectorOrder: 0)
        let stale = BrowserDescriptor(id: system.id, bundleIdentifier: system.bundleIdentifier, displayName: system.displayName, applicationURL: URL(fileURLWithPath: "/Old/Browser.app"), securityScopedBookmark: nil, origin: .custom, availability: .unavailable, selectorOrder: 0)
        let profile = ChromiumProfileDescriptor(directoryName: "Profile 1", displayName: "Work", userDataDirectory: URL(fileURLWithPath: "/tmp/test"))
        let profileRow = BrowserDescriptor(id: profile.browserID(bundleIdentifier: system.bundleIdentifier), bundleIdentifier: system.bundleIdentifier, displayName: "Browser · Work", applicationURL: system.applicationURL, securityScopedBookmark: nil, origin: .system, availability: .available, selectorOrder: 1, profile: profile)
        #expect(Set([system, stale, profileRow].map(\.managementRowIdentity)).count == 3)
    }
    @Test func legacyOrderPayloadDefaultsToVisibleAndVisibilityPreservesOrder() throws {
        let record = try BrowserOrderRecord(ids: ["a", "b"])
        record.orderedIDsPayload = Data(#"{"version":1,"ids":["a","b"]}"#.utf8)
        #expect(try record.hiddenBrowserIDs().isEmpty)
        #expect(try record.recentBrowserIDs().isEmpty)
        try record.replaceHiddenBrowserIDs(with: ["b"])
        #expect(try record.browserIDs() == ["a", "b"])
        try record.replace(with: ["b", "a"])
        #expect(try record.hiddenBrowserIDs() == ["b"])
        try record.replaceRecentBrowserIDs(with: ["b", "a"])
        try record.replaceHiddenBrowserIDs(with: [])
        #expect(try record.browserIDs() == ["b", "a"])
        #expect(try record.recentBrowserIDs() == ["b", "a"])
    }

    @Test func preferencesSurviveSeparateRepositoryReadsAndIndependentUpdates() throws {
        let container = try ModelContainerFactory.make(inMemory: true).container
        let repository = SwiftDataBrowserPreferenceRepository(container: container)
        try repository.saveOrder(["a", "b"])
        try repository.saveHiddenBrowserIDs(["b"])
        try repository.saveRecentBrowserIDs(["b", "a"])
        let second = SwiftDataBrowserPreferenceRepository(container: container)
        #expect(try second.orderedBrowserIDs() == ["a", "b"])
        #expect(try second.hiddenBrowserIDs() == ["b"])
        #expect(try second.recentBrowserIDs() == ["b", "a"])
        try second.saveOrder(["b", "a"])
        let third = SwiftDataBrowserPreferenceRepository(container: container)
        #expect(try third.hiddenBrowserIDs() == ["b"])
        #expect(try third.recentBrowserIDs() == ["b", "a"])
        try third.saveHiddenBrowserIDs([])
        #expect(try third.orderedBrowserIDs() == ["b", "a"])
        #expect(try third.recentBrowserIDs() == ["b", "a"])
    }

    @Test func hiddenProfileIsAbsentFromChooserButAvailableToRulesAndFallback() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appending(path: "Chrome.app")
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.google.Chrome", "CFBundleName": "Chrome"], format: .xml, options: 0)
        try plist.write(to: contents.appending(path: "Info.plist"))
        let dataRoot = root.appending(path: "User Data")
        let directory = dataRoot.appending(path: "Profile 1")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"profile":{"info_cache":{"Profile 1":{"name":"工作"}}}}"#.utf8).write(to: dataRoot.appending(path: "Local State"))
        let preferences = InMemoryBrowserPreferenceRepository()
        let catalog = BrowserCatalogService(workspace: ChoiceWorkspace(applicationURL: app), browserPreferences: preferences, profileDiscovery: ChromiumProfileDiscovery(userDataDirectories: ["com.google.Chrome": dataRoot]))
        let all = try await catalog.scan()
        let profile = try #require(all.first { $0.profile != nil })
        try preferences.saveOrder([profile.id, "com.google.Chrome"])
        try preferences.saveHiddenBrowserIDs([profile.id])
        #expect(try await catalog.scanForSelector().map(\.id) == ["com.google.Chrome"])
        let available = Set(try await catalog.scan().map(\.id))
        let request = LinkRequest(id: UUID(), url: URL(string: "https://example.com")!, receivedAt: Date(), source: .unknown)
        let rule = RoutingRule(id: UUID(), isEnabled: true, matcher: .exactHost("example.com"), targetBrowserID: profile.id, priority: 0, label: nil, createdAt: Date(), updatedAt: Date())
        #expect(RuleEngine().decide(request: request, rules: [rule], availableBrowserIDs: available, eligibleSourceBundleIDs: [], settings: .defaults) == .open(browserID: profile.id, method: .urlRule, ruleID: rule.id))
        var settings = AppSettings.defaults
        settings.unmatchedBehavior = .preferredBrowser
        settings.preferredBrowserID = profile.id
        #expect(RuleEngine().decide(request: request, rules: [], availableBrowserIDs: available, eligibleSourceBundleIDs: [], settings: settings) == .open(browserID: profile.id, method: .preferredBrowser, ruleID: nil))
        try FileManager.default.removeItem(at: directory)
        let afterRemoval = Set(try await catalog.scan().map(\.id))
        #expect(RuleEngine().decide(request: request, rules: [rule], availableBrowserIDs: afterRemoval, eligibleSourceBundleIDs: [], settings: settings) == .ask(reason: .targetUnavailable(profile.id)))
    }

    @Test func chooserManagementOpensInternalSettingsAndConsumesRequestOnce() {
        let environment = AppEnvironment(route: .rules, unmatchedBehavior: .alwaysAsk, updateChecker: DisabledUpdateChecker(), ruleRepository: InMemoryRuleRepository(), historyRepository: InMemoryHistoryRepository(), browserPreferenceRepository: InMemoryBrowserPreferenceRepository(), settingsRepository: InMemorySettingsRepository())
        let opening = MainWindowOpening(updateRoute: environment.updateRoute)
        let navigation = AppSelectorNavigationHandler(environment: environment, mainWindowOpening: opening)
        navigation.openBrowserManagement()
        #expect(environment.route == .settings)
        #expect(environment.consumeBrowserManagement())
        #expect(!environment.consumeBrowserManagement())
    }

    @Test func alternateNamesSurviveOrderHiddenAndRecentUpdates() throws {
        let container = try ModelContainerFactory.make(inMemory: true).container
        let repository = SwiftDataBrowserPreferenceRepository(container: container)
        try repository.saveOrder(["a", "b"])
        try repository.saveHiddenBrowserIDs(["b"])
        try repository.saveRecentBrowserIDs(["b", "a"])
        try repository.saveBrowserAlternateNames([
            "a": "  Work Browser  ",
            "b": "   ",
        ])

        let second = SwiftDataBrowserPreferenceRepository(container: container)
        #expect(try second.browserAlternateNames() == ["a": "Work Browser"])
        try second.saveOrder(["b", "a"])
        try second.saveHiddenBrowserIDs([])
        try second.saveRecentBrowserIDs(["a"])

        let third = SwiftDataBrowserPreferenceRepository(container: container)
        #expect(try third.browserAlternateNames() == ["a": "Work Browser"])
        #expect(try third.orderedBrowserIDs() == ["b", "a"])
        #expect(try third.hiddenBrowserIDs().isEmpty)
        #expect(try third.recentBrowserIDs() == ["a"])

        try third.saveBrowserAlternateNames([:])
        #expect(try SwiftDataBrowserPreferenceRepository(container: container).browserAlternateNames().isEmpty)
    }

    @Test func catalogAppliesAlternateNamesGloballyIncludingProfilesAndPreservesOriginalNames() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appending(path: "Chrome.app")
        let contents = app.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": "com.google.Chrome", "CFBundleName": "Chrome"],
            format: .xml,
            options: 0
        )
        try plist.write(to: contents.appending(path: "Info.plist"))
        let dataRoot = root.appending(path: "User Data")
        let directory = dataRoot.appending(path: "Profile 1")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"profile":{"info_cache":{"Profile 1":{"name":"工作"}}}}"#.utf8).write(to: dataRoot.appending(path: "Local State"))

        let preferences = InMemoryBrowserPreferenceRepository()
        let catalog = BrowserCatalogService(
            workspace: ChoiceWorkspace(applicationURL: app),
            browserPreferences: preferences,
            profileDiscovery: ChromiumProfileDiscovery(userDataDirectories: ["com.google.Chrome": dataRoot])
        )
        let initial = try await catalog.scan()
        let profile = try #require(initial.first { $0.profile != nil })

        try preferences.saveBrowserAlternateNames([
            "com.google.Chrome": "Main Chrome",
            profile.id: "Work ID 01",
        ])

        let scanned = try await catalog.scan()
        let renamedMain = try #require(scanned.first { $0.id == "com.google.Chrome" })
        let renamedProfile = try #require(scanned.first { $0.id == profile.id })
        #expect(renamedMain.displayName == "Main Chrome")
        #expect(renamedMain.originalDisplayName == "Chrome")
        #expect(renamedMain.tooltipDisplayName == "Main Chrome (Chrome)")
        #expect(renamedProfile.displayName == "Work ID 01")
        #expect(renamedProfile.originalDisplayName == "Chrome · 工作")
        #expect(renamedProfile.tooltipDisplayName == "Work ID 01 (Chrome · 工作)")

        let forSelector = try await catalog.scanForSelector()
        #expect(forSelector.first { $0.id == profile.id }?.displayName == "Work ID 01")

        let managed = BrowserManagementPresentation.browsers(
            discovered: scanned,
            custom: [],
            alternateNames: [:]
        )
        #expect(managed.first { $0.id == "com.google.Chrome" }?.displayName == "Chrome")
        #expect(managed.first { $0.id == profile.id }?.displayName == "Chrome · 工作")
    }

    @Test func dockIconVisibilityPolicyAndSettingsPersistence() throws {
        #expect(DockIconVisibilityPolicy.activationPolicy(hideDockIcon: false, hasOpenStandardWindow: false) == .regular)
        #expect(DockIconVisibilityPolicy.activationPolicy(hideDockIcon: false, hasOpenStandardWindow: true) == .regular)
        #expect(DockIconVisibilityPolicy.activationPolicy(hideDockIcon: true, hasOpenStandardWindow: true) == .regular)
        #expect(DockIconVisibilityPolicy.activationPolicy(hideDockIcon: true, hasOpenStandardWindow: false) == .accessory)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        #expect(!DockIconVisibilityPolicy.isStandardAppWindow(panel))

        let container = try ModelContainerFactory.make(inMemory: true).container
        let settingsRepo = SwiftDataSettingsRepository(container: container)
        var settings = AppSettings.defaults
        #expect(!settings.hideDockIcon)
        settings.hideDockIcon = true
        try settingsRepo.save(settings)

        let reloaded = try SwiftDataSettingsRepository(container: container).load()
        #expect(reloaded.hideDockIcon)
    }
}

@MainActor
private struct ChoiceWorkspace: WorkspaceClient {
    let applicationURL: URL
    func applicationURLs(toOpen _: URL) -> [URL] { [applicationURL] }
    func open(_: URL, with _: URL) async throws { Issue.record("Preview tests must never launch an application") }
    func openApplication(at _: URL, arguments _: [String]) async throws { Issue.record("Preference tests must never launch a profile") }
    func icon(for _: URL) -> NSImage { NSImage() }
}
