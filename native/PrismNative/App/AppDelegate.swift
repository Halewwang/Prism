import AppKit
import Carbon
import Observation
import SwiftUI

enum DockIconVisibilityPolicy {
    static func activationPolicy(
        hideDockIcon: Bool,
        hasOpenStandardWindow: Bool
    ) -> NSApplication.ActivationPolicy {
        (hideDockIcon && !hasOpenStandardWindow) ? .accessory : .regular
    }

    @MainActor
    static func isStandardAppWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel),
              window.sheetParent == nil,
              window.level == .normal,
              window.styleMask.contains(.titled)
        else { return false }
        return window.isVisible || window.isMiniaturized
    }

    @MainActor
    static func hasOpenStandardWindow(in windows: [NSWindow], excluding excludedWindow: NSWindow? = nil) -> Bool {
        windows.contains { $0 !== excludedWindow && isStandardAppWindow($0) }
    }
}

private final class MainWindowHostingView: NSHostingView<AnyView> {
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias StatusItemControllerFactory = @MainActor (ProductionAppComposition) -> StatusItemController

    let composition: ProductionAppComposition
    let bootstrapBuffer: BootstrapLinkBuffer
    private let copyCurrentSenderPID: @MainActor () -> Int32?
    private let makeStatusItemController: StatusItemControllerFactory
    private let activateApplication: @MainActor () -> Void
    private let applyActivationPolicy: @MainActor (NSApplication.ActivationPolicy) -> Void
    private var launchTask: Task<Void, Never>?
    private var statusItemController: StatusItemController?
    private var mainWindow: NSWindow?
    private var windowLifecycleObservers: [NSObjectProtocol] = []

    var retainedStatusItemController: StatusItemController? {
        statusItemController
    }

#if DEBUG
    let sourceProbeRecorder: SourceProbeRecorder
    let debugUITestMode: DebugUITestMode
    let debugUITestRecorder: DebugUITestEffectRecorder?
    private var debugSelectorHarness: DebugSelectorHarness?
    private var debugApplicationActivationAnchor: DebugAppFixtureActivationAnchor?
    private var debugUpdateWindow: InAppUpdateWindowController?
#endif

    var environment: AppEnvironment {
        composition.environment
    }

    override init() {
        let buffer = BootstrapLinkBuffer()
#if DEBUG
        let recorder = SourceProbeRecorder.makeDefault()
        sourceProbeRecorder = recorder
        let UItestMode = DebugUITestConfiguration.mode
        debugUITestMode = UItestMode
        if UItestMode.isUITesting {
            let fixture = DebugAppFixture.make(
                bootstrapBuffer: buffer,
                variant: .parse(arguments: ProcessInfo.processInfo.arguments)
            )
            composition = fixture.composition
            debugUITestRecorder = fixture.recorder
        } else {
            composition = ProductionAppComposition.make(
                bootstrapBuffer: buffer,
                diagnosticRecorder: { [weak recorder] diagnostic in
                    recorder?.record(diagnostic)
                }
            )
            debugUITestRecorder = nil
        }
#else
        composition = ProductionAppComposition.make(bootstrapBuffer: buffer)
#endif
        bootstrapBuffer = buffer
        copyCurrentSenderPID = AppleEventSenderReader.copyCurrentSenderPID
        activateApplication = Self.requestApplicationActivation
        applyActivationPolicy = Self.applyApplicationActivationPolicy
        makeStatusItemController = Self.makeProductionStatusItemController
        super.init()
        configureMainWindowOpening()
        configureUpdateInstallation()
        installWindowLifecycleObservers()
        observeDockIconSetting()
#if DEBUG
        if debugUITestMode == .application || debugUITestMode == .malformedSelector {
            activateDebugApplicationFixture()
        }
#endif
    }

    init(
        composition: ProductionAppComposition,
        copyCurrentSenderPID: @escaping @MainActor () -> Int32?,
        makeStatusItemController: @escaping StatusItemControllerFactory = { composition in
            AppDelegate.makeProductionStatusItemController(composition: composition)
        },
        activateApplication: @escaping @MainActor () -> Void = AppDelegate.requestApplicationActivation,
        applyActivationPolicy: @escaping @MainActor (NSApplication.ActivationPolicy) -> Void = AppDelegate.applyApplicationActivationPolicy
    ) {
        self.composition = composition
        bootstrapBuffer = composition.bootstrapBuffer
        self.copyCurrentSenderPID = copyCurrentSenderPID
        self.makeStatusItemController = makeStatusItemController
        self.activateApplication = activateApplication
        self.applyActivationPolicy = applyActivationPolicy
#if DEBUG
        sourceProbeRecorder = SourceProbeRecorder.makeDefault()
        debugUITestMode = .disabled
        debugUITestRecorder = nil
#endif
        super.init()
        configureUpdateInstallation()
        installWindowLifecycleObservers()
        observeDockIconSetting()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        installGetURLHandler()
    }

    private func installGetURLHandler() {
#if DEBUG
        guard !debugUITestMode.isUITesting else { return }
#endif
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
#if DEBUG
        guard !debugUITestMode.isUITesting else { return }
#endif
        let senderPID = AppleEventSenderReader.copySenderPID(from: event)
        // The registered handler owns this event; AppKit does not also deliver it
        // to application(_:open:). Each event is a separate click, even for one URL.
        for url in GetURLEvent.urls(in: event) where BootstrapLinkBuffer.accepts(url) {
            composition.linkIntakeService.capture(url: url, senderPID: senderPID)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
#if DEBUG
        guard !debugUITestMode.isUITesting else { return }
#endif
        let senderPID = copyCurrentSenderPID()
        for url in urls where BootstrapLinkBuffer.accepts(url) {
            composition.linkIntakeService.capture(url: url, senderPID: senderPID)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        if DebugUITestConfiguration.isEnabled, ProcessInfo.processInfo.arguments.contains("--update-harness") {
            debugUpdateWindow = DebugUpdateHarness.make()
            debugUpdateWindow?.present()
            return
        }
        switch debugUITestMode {
        case .selector:
            presentDebugSelectorHarness()
            return
        case .malformedSelector:
            activateDebugApplicationFixture()
            showMainWindow()
            return
        case .application:
            activateDebugApplicationFixture()
            showMainWindow()
        case .disabled:
            if ProcessInfo.processInfo.arguments.contains("--source-probe") {
                showMainWindow()
            }
        }
#endif
        if statusItemController == nil {
#if DEBUG
            if debugUITestMode == .application {
                statusItemController = makeDebugStatusItemController()
            } else {
                statusItemController = makeStatusItemController(composition)
            }
#else
            statusItemController = makeStatusItemController(composition)
#endif
        }
        guard launchTask == nil else {
            installGetURLHandler()
            return
        }
        let composition = composition
        launchTask = Task { @MainActor [weak self] in
            await composition.finishLaunchingOnce()
            self?.presentMainWindowIfStartupRequiresAttention()
            self?.synchronizeDockIconVisibility()
        }
        installGetURLHandler()
    }

    private func presentMainWindowIfStartupRequiresAttention() {
#if DEBUG
        guard !debugUITestMode.isUITesting else { return }
#endif
        let requiresAttention = environment.startupPhase == .onboarding
            || environment.startupPhase == .recovery
            || environment.runtimeLinkRecoveryState == .persistenceRetryRequired
        guard requiresAttention else { return }
        composition.mainWindowOpening.open(route: environment.route)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
#if DEBUG
        if debugUITestMode == .application || debugUITestMode == .malformedSelector {
            activateDebugApplicationFixture()
        }
#endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let checker = environment.updateChecker as? GitHubUpdateChecker,
           checker.hasPreparedInstallation {
            // This synchronous check closes the await-to-terminate gap. GetURL events
            // received during preparation stay captured and make this exit fail closed.
            guard hasSafeUpdatePersistenceState, composition.linkIntakeService.canTerminateForUpdate else {
                checker.cancelPreparedInstallation(
                    message: String(
                        localized: "update.termination.blocked",
                        defaultValue: "A new link arrived or saving is still in progress before updating. Please handle it and try again."
                    )
                )
                return .terminateCancel
            }
            do { try checker.commitPreparedInstallation() }
            catch {
                checker.cancelPreparedInstallation(message: error.localizedDescription)
                return .terminateCancel
            }
            return .terminateNow
        }

        guard composition.linkIntakeService.hasPendingBootstrapPersistence else {
            return .terminateNow
        }
        let intake = composition.linkIntakeService
        var didReply = false
        let replyOnce: @MainActor () -> Void = {
            guard !didReply else { return }
            didReply = true
            sender.reply(toApplicationShouldTerminate: true)
        }
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            replyOnce()
        }
        Task { @MainActor in
            await intake.waitForPersistence()
            timeoutTask.cancel()
            replyOnce()
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        for observer in windowLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowLifecycleObservers.removeAll()
        composition.activationTracker.stop()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !flag else { return true }
        composition.mainWindowOpening.open(route: environment.route)
        return true
    }

    private static func makeProductionStatusItemController(
        composition: ProductionAppComposition
    ) -> StatusItemController {
        StatusItemController(
            mainWindowOpening: composition.mainWindowOpening,
            environment: composition.environment
        )
    }

    private var hasSafeUpdatePersistenceState: Bool {
        environment.startupPhase != .loading
            && environment.startupPhase != .recovery
            && environment.runtimeLinkRecoveryState == .none
            && !environment.hasPendingTerminalHistoryReconciliation
            && composition.selectorPresentationRelay.activeRequest == nil
            && !environment.persistenceWarnings.contains { warning in
                switch warning {
                case .historyNotSaved, .recoveryStoreUnavailable, .settingsNotSaved: true
                case .corruptStoreRecovered: false
                }
            }
    }

    private func configureUpdateInstallation() {
#if !PRISM_PUBLIC_TEST
        if let sparkle = environment.updateChecker as? SparkleUpdateChecker {
            sparkle.setRelaunchGate { [weak self] in
                guard let self else { return false }
                return self.hasSafeUpdatePersistenceState
                    && !self.composition.linkIntakeService.hasPendingBootstrapPersistence
                    && self.composition.linkRoutingCoordinator.hasInFlightOperations == false
            }
            return
        }
#endif
        guard let checker = environment.updateChecker as? GitHubUpdateChecker else { return }
        checker.setInstallationPreparation(
            prepare: { [weak self] in
                guard let self, self.hasSafeUpdatePersistenceState else {
                    throw LinkIntakeService.UpdateTerminationError.persistenceUnavailable
                }
                try await self.composition.linkIntakeService.beginUpdateTermination()
            },
            cancel: { [weak self] in
                self?.composition.linkIntakeService.cancelUpdateTermination()
            }
        )
    }

    private func configureMainWindowOpening() {
        composition.mainWindowOpening.register { [weak self] _, _ in
            self?.showMainWindow()
        }
    }

    private static func requestApplicationActivation() {
        NSApplication.shared.activate()
    }

    private static func applyApplicationActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        guard NSApplication.shared.activationPolicy() != policy else { return }
        _ = NSApplication.shared.setActivationPolicy(policy)
    }

    private func installWindowLifecycleObservers() {
        let center = NotificationCenter.default
        windowLifecycleObservers.append(
            center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
                let closingWindow = notification.object as? NSWindow
                MainActor.assumeIsolated {
                    self?.synchronizeDockIconVisibility(excluding: closingWindow)
                }
            }
        )
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            windowLifecycleObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.synchronizeDockIconVisibility()
                    }
                }
            )
        }
    }

    private func observeDockIconSetting() {
        withObservationTracking {
            _ = environment.settings.hideDockIcon
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.synchronizeDockIconVisibility()
                self.observeDockIconSetting()
            }
        }
    }

    func synchronizeDockIconVisibility(
        excluding closingWindow: NSWindow? = nil,
        assumingOpenWindow: Bool = false
    ) {
#if DEBUG
        guard !debugUITestMode.isUITesting else { return }
#endif
        let hasOpenWindow = assumingOpenWindow
            || DockIconVisibilityPolicy.hasOpenStandardWindow(in: NSApp.windows, excluding: closingWindow)
        let targetPolicy = DockIconVisibilityPolicy.activationPolicy(
            hideDockIcon: environment.settings.hideDockIcon,
            hasOpenStandardWindow: hasOpenWindow
        )
        applyActivationPolicy(targetPolicy)
    }

    func showMainWindow() {
        synchronizeDockIconVisibility(assumingOpenWindow: true)
        // Explicit workspace opens request focus; macOS controls whether activation is granted.
        if let mainWindow {
            activateApplication()
            WindowPresentationAnimation.show(mainWindow) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            return
        }

        let lockedWidth: CGFloat = 668
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: lockedWidth, height: 554),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Prism"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .windowBackgroundColor
        window.toolbar = nil
        window.collectionBehavior = [.fullScreenNone]
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.contentMinSize = NSSize(width: lockedWidth, height: 554)
        window.contentMaxSize = window.contentMinSize
        window.isReleasedWhenClosed = false
        let hostingView = MainWindowHostingView(rootView: mainWindowRoot())
        hostingView.sizingOptions = []
        window.contentView = hostingView
        PrismAboutWindowController.centerOnActiveScreen(window)
        mainWindow = window
        activateApplication()
        WindowPresentationAnimation.show(window) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func mainWindowRoot() -> AnyView {
#if DEBUG
        switch debugUITestMode {
        case .application:
            return AnyView(
                AppRootView(composition: composition, systemActions: .inert)
                    .preferredColorScheme(DebugApplicationFixtureAppearance.current()?.colorScheme)
                    .onAppear { [weak self] in
                        self?.finishDebugApplicationFixtureActivation()
                    }
            )
        case .malformedSelector:
            return AnyView(
                Text("Invalid UI test configuration")
                    .frame(minWidth: 760, minHeight: 520)
                    .accessibilityIdentifier("uiTest.configurationError")
            )
        case .disabled where ProcessInfo.processInfo.arguments.contains("--source-probe"):
            return AnyView(
                SourceProbeView(recorder: sourceProbeRecorder)
                    .environment(environment)
            )
        case .selector, .disabled:
            break
        }
#endif
        return AnyView(AppRootView(composition: composition))
    }

#if DEBUG
    private func makeDebugStatusItemController() -> StatusItemController? {
        guard let debugUITestRecorder else { return nil }
        return StatusItemController(
            host: DebugNoopStatusItemHost(recorder: debugUITestRecorder),
            mainWindowOpening: composition.mainWindowOpening,
            environment: composition.environment,
            terminate: {}
        )
    }

    func presentDebugSelectorHarness() {
        guard let variant = DebugUITestConfiguration.selectorVariant,
              let appearance = DebugUITestConfiguration.selectorAppearance
        else { return }
        if debugSelectorHarness == nil {
            debugSelectorHarness = DebugSelectorHarness(variant: variant, appearance: appearance)
        }
        debugSelectorHarness?.present()
    }

    func activateDebugApplicationFixture() {
        guard mainWindow == nil else { return }
        if debugApplicationActivationAnchor == nil {
            debugApplicationActivationAnchor = DebugAppFixtureActivationAnchor()
        }
        debugApplicationActivationAnchor?.activate()
    }

    func finishDebugApplicationFixtureActivation() {
        debugApplicationActivationAnchor?.deactivate()
        debugApplicationActivationAnchor = nil
        _ = NSRunningApplication.current.activate(
            options: DebugAppFixtureActivationAnchor.foregroundActivationOptions
        )
    }
#endif
}
