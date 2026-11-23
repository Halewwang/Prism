import AppKit
import Foundation
import Observation
import PrismCore

enum SelectorRulePrefill: Equatable, Sendable {
    case savedRule(id: UUID)
    case domain(host: String, browserID: BrowserID?)
    case source(bundleIdentifier: String, displayName: String, browserID: BrowserID)
}

@MainActor
protocol SelectorNavigationHandling: AnyObject {
    func openBrowserManagement()
    func openRuleEditor(prefill: SelectorRulePrefill)
}

@MainActor
protocol SelectorPendingCountProviding: AnyObject {
    func pendingCountUpdates() async -> AsyncStream<Int>
}

@MainActor
final class RecoveryQueuePendingCountProvider: SelectorPendingCountProviding {
    let queue: LinkRequestQueue

    init(queue: LinkRequestQueue) {
        self.queue = queue
    }

    func pendingCountUpdates() async -> AsyncStream<Int> {
        await queue.pendingCountUpdates()
    }
}

@MainActor
@Observable
final class SelectorViewModel {
    private enum Target {
        case web(any LinkRoutingCoordinating, any SelectorPendingCountProviding)
        case localFile(any BrowserLaunching, onFinish: @MainActor () -> Void)
    }

    let requestID: UUID
    let url: URL
    let source: SourceApplication
    private(set) var presentationContext: SelectorPresentationContext
    var addressText: String {
        didSet { addressError = nil }
    }
    var previewURL: URL? {
        didSet {
            if addressText == (oldValue ?? url).absoluteString {
                addressText = (previewURL ?? url).absoluteString
            }
        }
    }
    private var addressError: String?

    private(set) var browsers: [BrowserDescriptor]
    private(set) var selectedIndex: Int
    private(set) var revealBrowserID: BrowserID?
    private(set) var pendingCount: Int
    private(set) var isLoading: Bool
    private(set) var scanFailureMessage: String?
    private(set) var isPerformingAction: Bool

    let browserCatalog: any BrowserCataloging
    private let target: Target
    private let navigationHandler: any SelectorNavigationHandling
    private let eligibleSourceBundleIDs: Set<String>
    @ObservationIgnored private let browserOrder: @MainActor ([BrowserDescriptor]) -> [BrowserDescriptor]
    @ObservationIgnored private var pendingCountMonitoringTask: Task<Void, Never>?
    @ObservationIgnored private var didFinishLocalFile = false

    convenience init(
        request: LinkRequest,
        context: SelectorPresentationContext,
        browsers: [BrowserDescriptor] = [],
        browserCatalog: any BrowserCataloging,
        routingCoordinator: any LinkRoutingCoordinating,
        pendingCountProvider: any SelectorPendingCountProviding,
        navigationHandler: any SelectorNavigationHandling,
        eligibleSourceBundleIDs: Set<String>,
        browserOrder: @escaping @MainActor ([BrowserDescriptor]) -> [BrowserDescriptor] = { $0 }
    ) {
        self.init(
            requestID: request.id, url: request.launchURL, source: request.source,
            context: context, browsers: browsers, browserCatalog: browserCatalog,
            target: .web(routingCoordinator, pendingCountProvider), navigationHandler: navigationHandler,
            eligibleSourceBundleIDs: eligibleSourceBundleIDs, browserOrder: browserOrder
        )
    }

    convenience init(
        localFileURL: URL,
        requestID: UUID,
        browserCatalog: any BrowserCataloging,
        browserLauncher: any BrowserLaunching,
        navigationHandler: any SelectorNavigationHandling,
        onFinish: @escaping @MainActor () -> Void,
        browsers: [BrowserDescriptor] = []
    ) {
        self.init(
            requestID: requestID, url: localFileURL, source: .unknown,
            context: .normal, browsers: browsers, browserCatalog: browserCatalog,
            target: .localFile(browserLauncher, onFinish: onFinish), navigationHandler: navigationHandler,
            eligibleSourceBundleIDs: [], browserOrder: { $0 }
        )
    }

    private init(
        requestID: UUID,
        url: URL,
        source: SourceApplication,
        context: SelectorPresentationContext,
        browsers: [BrowserDescriptor],
        browserCatalog: any BrowserCataloging,
        target: Target,
        navigationHandler: any SelectorNavigationHandling,
        eligibleSourceBundleIDs: Set<String>,
        browserOrder: @escaping @MainActor ([BrowserDescriptor]) -> [BrowserDescriptor]
    ) {
        self.requestID = requestID
        self.url = url
        self.source = source
        self.target = target
        if case .localFile = target {
            addressText = url.lastPathComponent
        } else {
            addressText = url.absoluteString
        }
        presentationContext = context
        let orderedBrowsers = browserOrder(Self.availableAndOrdered(browsers))
        self.browsers = orderedBrowsers
        self.browserCatalog = browserCatalog
        self.navigationHandler = navigationHandler
        self.eligibleSourceBundleIDs = eligibleSourceBundleIDs
        self.browserOrder = browserOrder
        pendingCount = 0
        isLoading = false
        scanFailureMessage = nil
        isPerformingAction = false

        if let preferredID = context.preferredBrowserID,
           let index = orderedBrowsers.firstIndex(where: { $0.id == preferredID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
    }

    var localFileName: String? {
        guard case .localFile = target else { return nil }
        return url.lastPathComponent
    }

    private var routingCoordinator: (any LinkRoutingCoordinating)? {
        guard case let .web(coordinator, _) = target else { return nil }
        return coordinator
    }

    var selectedBrowser: BrowserDescriptor? {
        guard browsers.indices.contains(selectedIndex) else { return nil }
        return browsers[selectedIndex]
    }

    var failedBrowserID: BrowserID? {
        guard case let .launchFailed(browserID, _) = presentationContext else { return nil }
        return browserID
    }

    var accessibleFailureMessage: String? {
        if let addressError { return addressError }
        return switch presentationContext {
        case let .launchFailed(_, message):
            message
        case .outcomeUnknown:
            String(
                localized: "selector.failure.outcomeUnknown",
                defaultValue: "Prism could not confirm whether the browser opened the link."
            )
        case .storageUnavailable:
            String(
                localized: "selector.failure.storageUnavailable",
                defaultValue: "Prism could not save recovery information. The link is still waiting."
            )
        case let .ruleSkipped(reason):
            SelectorReasonCopy.message(reason)
        case .normal, .noAvailableBrowsers:
            scanFailureMessage
        }
    }

    var isFailurePresentation: Bool {
        if addressError != nil { return true }
        if case let .ruleSkipped(reason) = presentationContext {
            switch reason {
            case .noMatchingRule, .rulesPaused, .sourceNotConfirmed: return false
            case .targetUnavailable, .preferredBrowserUnavailable: return true
            }
        }
        return accessibleFailureMessage != nil
    }

    var sourceDisplayName: String {
        source == .unknown || source.displayName == "Unknown"
            ? String(localized: "selector.source.unknown", defaultValue: "Unknown source")
            : source.displayName
    }

    var sourceHelp: String {
        let confidence: String
        switch source.confidence {
        case .confirmed: confidence = String(localized: "selector.source.confirmed", defaultValue: "Confirmed sender")
        case .low: confidence = String(localized: "selector.source.low", defaultValue: "Possible source; not confirmed")
        case .unknown: confidence = String(localized: "selector.source.unconfirmed", defaultValue: "The sending application could not be confirmed")
        }
        return [sourceDisplayName, source.bundleIdentifier, confidence, sourceRuleSupportMessage].compactMap { $0 }.joined(separator: "\n")
    }

    var pendingBadgeText: String? {
        pendingCount >= 2 ? String(pendingCount) : nil
    }

    var pendingAccessibilityValue: String? {
        guard pendingCount >= 2 else { return nil }
        return String(
            localized: "selector.pending.accessibility",
            defaultValue: "\(pendingCount) links waiting"
        )
    }

    var canRescan: Bool { !isLoading }
    var canOpenBrowserManagement: Bool { true }
    var canMarkCompleted: Bool {
        if case .outcomeUnknown = presentationContext { return true }
        return false
    }

    var previewRequiresRecovery: Bool {
        switch presentationContext {
        case .outcomeUnknown, .storageUnavailable: true
        case .normal, .noAvailableBrowsers, .ruleSkipped, .launchFailed: false
        }
    }

    var requiresExplicitRecoveryBrowser: Bool {
        switch presentationContext {
        case let .outcomeUnknown(browserID):
            guard let browserID else { return true }
            return !browsers.contains(where: { $0.id == browserID })
        case .storageUnavailable:
            return presentationContext.preferredBrowserID == nil
        case .normal, .launchFailed, .noAvailableBrowsers, .ruleSkipped:
            return false
        }
    }

    var canCreateDomainRule: Bool {
        guard let host = parsedAddressURL?.host(percentEncoded: false) else { return false }
        return !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canCreateSourceRule: Bool {
        guard source.confidence == .confirmed,
              let bundleIdentifier = source.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty
        else { return false }
        return true
    }

    var sourceRuleSupportStatus: SourceRuleSupportStatus? {
        guard canCreateSourceRule, let bundleIdentifier = source.bundleIdentifier else { return nil }
        return SourceRuleSupportStatus(
            bundleIdentifier: bundleIdentifier,
            verifiedBundleIDs: eligibleSourceBundleIDs
        )
    }

    var sourceRuleSupportMessage: String? {
        sourceRuleSupportStatus?.message
    }

    func shortcut(forBrowserAt index: Int) -> Int? {
        guard (0 ..< min(browsers.count, 9)).contains(index) else { return nil }
        return index + 1
    }

    func selectPrevious() {
        guard !browsers.isEmpty else { return }
        selectedIndex = selectedIndex == 0 ? browsers.count - 1 : selectedIndex - 1
        revealBrowserID = browsers[selectedIndex].id
    }

    func selectNext() {
        guard !browsers.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % browsers.count
        revealBrowserID = browsers[selectedIndex].id
    }

    func selectShortcut(_ number: Int) {
        let index = number - 1
        guard number >= 1, number <= 9, browsers.indices.contains(index) else { return }
        selectedIndex = index
        revealBrowserID = browsers[index].id
    }

    func canActivateShortcut(_ number: Int) -> Bool {
        !isPerformingAction && browserID(forShortcut: number) != nil
    }

    func activateShortcut(_ number: Int) async {
        guard let browserID = browserID(forShortcut: number) else { return }
        await activateBrowser(id: browserID)
    }

    func selectBrowser(id: BrowserID) {
        guard let index = browsers.firstIndex(where: { $0.id == id }) else { return }
        selectedIndex = index
        revealBrowserID = id
    }

    func prepareForPresentation() async {
        if browsers.isEmpty {
            await rescan()
        }
    }

    func updatePresentationContext(_ context: SelectorPresentationContext) {
        presentationContext = context
        if case .noAvailableBrowsers = context {
            Task { [weak self] in await self?.rescan() }
        }
    }

    @discardableResult
    func startPendingCountMonitoring() -> Task<Void, Never> {
        stopPendingCountMonitoring()
        guard case let .web(_, pendingCountProvider) = target else { return Task {} }
        let task = Task { @MainActor [weak self] in
            let updates = await pendingCountProvider.pendingCountUpdates()
            for await count in updates {
                guard !Task.isCancelled, let self else { return }
                pendingCount = max(0, count)
            }
        }
        pendingCountMonitoringTask = task
        return task
    }

    func stopPendingCountMonitoring() {
        pendingCountMonitoringTask?.cancel()
        pendingCountMonitoringTask = nil
    }

    deinit {
        pendingCountMonitoringTask?.cancel()
    }

    func rescan() async {
        guard !isLoading else { return }
        isLoading = true
        scanFailureMessage = nil
        defer { isLoading = false }
        do {
            let scanned = try await browserCatalog.scanForSelector()
            browsers = browserOrder(Self.availableAndOrdered(scanned))
            if browsers.isEmpty {
                selectedIndex = 0
                revealBrowserID = nil
            } else {
                selectedIndex = min(selectedIndex, browsers.count - 1)
                revealBrowserID = browsers[selectedIndex].id
            }
        } catch {
            browsers = []
            selectedIndex = 0
            revealBrowserID = nil
            scanFailureMessage = String(
                localized: "selector.browserScan.failed",
                defaultValue: "Prism could not scan for browsers. Try again."
            )
        }
    }

    func activateSelected() async {
        guard let selectedBrowser else { return }
        await activateBrowser(id: selectedBrowser.id)
    }

    private var parsedAddressURL: URL? {
        guard case .web = target else { return nil }
        let text = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace),
              let candidate = URL(string: text),
              let address = candidate.scheme == nil ? URL(string: "https://" + text) : candidate,
              LinkPreviewNavigationPolicy.canOpen(address)
        else { return nil }
        return address
    }

    func validatedAddressURL() -> URL? {
        guard let address = parsedAddressURL else {
            addressError = String(localized: "selector.url.invalid", defaultValue: "Enter a valid HTTP or HTTPS address.")
            return nil
        }
        addressError = nil
        return address
    }

    func activateBrowser(id: BrowserID) async {
        guard let browser = browsers.first(where: { $0.id == id }), !isPerformingAction else { return }
        if case let .localFile(launcher, onFinish) = target {
            await handOffLocalFile(with: browser, launcher: launcher, onFinish: onFinish)
            return
        }
        guard let routingCoordinator, let address = validatedAddressURL() else { return }
        selectBrowser(id: id)
        isPerformingAction = true
        defer { isPerformingAction = false }
        if address != (previewURL ?? url) {
            if previewRequiresRecovery {
                await routingCoordinator.retry(browserID: id, for: requestID, handoffURL: address)
            } else {
                await routingCoordinator.select(browserID: id, for: requestID, handoffURL: address)
            }
            return
        }
        if let previewURL {
            switch presentationContext {
            case .normal, .noAvailableBrowsers, .ruleSkipped, .launchFailed:
                await routingCoordinator.select(browserID: id, for: requestID, handoffURL: previewURL)
                return
            case .outcomeUnknown, .storageUnavailable:
                break
            }
        }
        switch presentationContext {
        case .normal, .noAvailableBrowsers, .ruleSkipped:
            await routingCoordinator.select(browserID: id, for: requestID)
        case let .launchFailed(failedBrowserID, _):
            if id == failedBrowserID {
                await routingCoordinator.retry(browserID: id, for: requestID)
            } else {
                await routingCoordinator.select(browserID: id, for: requestID)
            }
        case .outcomeUnknown, .storageUnavailable:
            await routingCoordinator.retry(browserID: id, for: requestID)
        }
    }

    private func handOffLocalFile(
        with browser: BrowserDescriptor,
        launcher: any BrowserLaunching,
        onFinish: @MainActor () -> Void
    ) async {
        guard !didFinishLocalFile else { return }
        selectBrowser(id: browser.id)
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            _ = try await launcher.open(url, with: browser)
            didFinishLocalFile = true
            onFinish()
        } catch {
            presentationContext = .launchFailed(
                browserID: browser.id,
                message: String(localized: "selector.localFile.openFailed", defaultValue: "Couldn’t open the file. Try another browser.")
            )
        }
    }

    func retryRecovery(browserID: BrowserID? = nil) async {
        let candidate = browserID ?? presentationContext.preferredBrowserID
        guard let routingCoordinator, let candidate, browsers.contains(where: { $0.id == candidate }), !isPerformingAction,
              let address = validatedAddressURL() else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        if address != (previewURL ?? url) {
            await routingCoordinator.retry(browserID: candidate, for: requestID, handoffURL: address)
        } else {
            await routingCoordinator.retry(browserID: candidate, for: requestID)
        }
    }

    func markCompleted() async {
        guard let routingCoordinator, canMarkCompleted, !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        await routingCoordinator.markUncertainAttemptCompleted(requestID: requestID)
    }

    func cancel() async {
        guard !isPerformingAction else { return }
        switch target {
        case let .web(coordinator, _):
            isPerformingAction = true
            defer { isPerformingAction = false }
            await coordinator.cancel(requestID: requestID)
        case let .localFile(_, onFinish):
            guard !didFinishLocalFile else { return }
            didFinishLocalFile = true
            onFinish()
        }
    }

    func openBrowserManagement() {
        navigationHandler.openBrowserManagement()
    }

    func openDomainRule(browserID: BrowserID) {
        guard canCreateDomainRule, let host = parsedAddressURL?.host(percentEncoded: false) else { return }
        navigationHandler.openRuleEditor(prefill: .domain(host: host, browserID: browserID))
    }

    func openSourceRule(browserID: BrowserID) {
        guard canCreateSourceRule,
              let bundleIdentifier = source.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        navigationHandler.openRuleEditor(prefill: .source(
            bundleIdentifier: bundleIdentifier,
            displayName: source.displayName,
            browserID: browserID
        ))
    }

    func browserAccessibilityLabel(at index: Int) -> String {
        guard browsers.indices.contains(index) else { return "" }
        let browser = browsers[index]
        var parts = [browser.displayName]
        if let shortcut = shortcut(forBrowserAt: index) {
            parts.append(String(
                localized: "selector.browser.shortcut",
                defaultValue: "Shortcut \(shortcut)"
            ))
        }
        if index == selectedIndex {
            parts.append(String(localized: "selector.browser.selected", defaultValue: "Selected"))
        }
        if browser.id == failedBrowserID {
            parts.append(String(localized: "selector.browser.failed", defaultValue: "Failed to open"))
        }
        return parts.joined(separator: ", ")
    }

    private static func availableAndOrdered(_ browsers: [BrowserDescriptor]) -> [BrowserDescriptor] {
        browsers
            .filter { $0.availability == .available }
            .sorted {
                if $0.selectorOrder != $1.selectorOrder { return $0.selectorOrder < $1.selectorOrder }
                if $0.displayName != $1.displayName {
                    return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                }
                return $0.id.rawValue < $1.id.rawValue
            }
    }

    private func browserID(forShortcut number: Int) -> BrowserID? {
        guard number >= 1, number <= 9 else { return nil }
        return browsers.indices.contains(number - 1) ? browsers[number - 1].id : nil
    }
}

private extension SelectorPresentationContext {
    var preferredBrowserID: BrowserID? {
        switch self {
        case let .launchFailed(browserID, _):
            browserID
        case let .outcomeUnknown(browserID):
            browserID
        case .normal, .noAvailableBrowsers, .storageUnavailable, .ruleSkipped:
            nil
        }
    }
}
