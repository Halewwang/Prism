import Foundation
import Observation
import PrismCore

@MainActor
@Observable
final class OnboardingViewModel {
    private let environment: AppEnvironment
    private let defaultBrowserService: DefaultBrowserService
    private let browserCatalog: any BrowserCataloging
    private let testLinkRouter: OnboardingTestLinkRouter
    private let openMainWindow: @MainActor (AppRoute) -> Void
    private let resumeRouting: @MainActor () async -> Void
    private var testLinkSession: OnboardingTestLinkSession?
    private var testLinkGeneration: UUID?
    private var finishLaterCancellationRequestID: UUID?

    private(set) var step: OnboardingStep = .welcome
    private(set) var alert: OnboardingAlert?
    private(set) var httpHandlerIsActive = false
    private(set) var httpsHandlerIsActive = false
    private(set) var handlerStatusIsKnown = false
    private(set) var isCheckingHandlers = false
    private(set) var isScanningBrowsers = false
    private(set) var usableBrowsers: [BrowserDescriptor] = []
    private(set) var loginItemState: LoginItemState?
    private(set) var isUpdatingLoginItem = false
    private(set) var testLinkWasAccepted = false
    private(set) var completionSaveIsPending = false

    var selectedPresentationMode: SelectorPresentationMode {
        environment.settings.selectorPresentationMode
    }

    var currentLanguage: AppLanguage {
        environment.settings.language
    }

    var hasLoginItemService: Bool {
        environment.loginItemService != nil
    }

    var isDefaultHandlerActive: Bool {
        handlerStatusIsKnown && httpHandlerIsActive && httpsHandlerIsActive
    }

    var isTestLinkInProgress: Bool {
        testLinkGeneration != nil || testLinkSession != nil
    }

    var isTestLinkPreparing: Bool {
        testLinkGeneration != nil && testLinkSession == nil
    }

    var canNavigateSteps: Bool {
        !isTestLinkInProgress && !completionSaveIsPending
    }

    init(
        environment: AppEnvironment,
        defaultBrowserService: DefaultBrowserService,
        browserCatalog: any BrowserCataloging,
        testLinkRouter: OnboardingTestLinkRouter,
        openMainWindow: @escaping @MainActor (AppRoute) -> Void,
        resumeRouting: @escaping @MainActor () async -> Void
    ) {
        self.environment = environment
        self.defaultBrowserService = defaultBrowserService
        self.browserCatalog = browserCatalog
        self.testLinkRouter = testLinkRouter
        self.openMainWindow = openMainWindow
        self.resumeRouting = resumeRouting
    }

    // MARK: - Navigation

    func goBack() {
        guard canNavigateSteps,
              let index = OnboardingStep.allCases.firstIndex(of: step),
              index > 0
        else { return }
        alert = nil
        step = OnboardingStep.allCases[index - 1]
    }

    func jumpTo(_ target: OnboardingStep) async {
        guard canNavigateSteps, target != step else { return }
        alert = nil
        step = target
        if target == .linkHandling {
            await loadSystemReadiness()
        }
    }

    func advanceFromWelcome() async {
        guard step == .welcome, canNavigateSteps else { return }
        alert = nil
        step = .presentationStyle
    }

    func advanceFromPresentationStyle() {
        guard step == .presentationStyle, canNavigateSteps else { return }
        alert = nil
        step = .routingRules
    }

    func advanceFromRoutingRules() async {
        guard step == .routingRules, canNavigateSteps else { return }
        alert = nil
        step = .linkHandling
        await loadSystemReadiness()
    }

    func advanceFromLinkHandling() async {
        guard step == .linkHandling, canNavigateSteps else { return }
        alert = nil
        if !usableBrowsers.isEmpty {
            guard environment.mutateSettings({ $0.unmatchedBehavior = .alwaysAsk }) else {
                alert = .settingsNotSaved
                return
            }
        }
        step = .testLink
    }

    func skipCurrentStep() async {
        guard canNavigateSteps else { return }
        switch step {
        case .welcome:
            await advanceFromWelcome()
        case .presentationStyle:
            advanceFromPresentationStyle()
        case .routingRules:
            await advanceFromRoutingRules()
        case .linkHandling:
            alert = nil
            step = .testLink
        case .testLink:
            await finishSetup()
        }
    }

    // MARK: - Configuration Actions

    func selectPresentationMode(_ mode: SelectorPresentationMode) {
        guard environment.settings.selectorPresentationMode != mode else { return }
        guard environment.mutateSettings({ $0.selectorPresentationMode = mode }) else {
            alert = .settingsNotSaved
            return
        }
        if alert == .settingsNotSaved {
            alert = nil
        }
    }

    @discardableResult
    func selectLanguage(_ language: AppLanguage) -> Bool {
        guard environment.mutateSettings({ $0.language = language }) else {
            alert = .settingsNotSaved
            return false
        }
        updateAppLanguagePreference(language)
        if alert == .settingsNotSaved {
            alert = nil
        }
        return true
    }

    // MARK: - Step 4: System Readiness (Handlers + Browsers + Login Item)

    func loadSystemReadiness() async {
        loginItemState = environment.loginItemService?.status()
        await queryCurrentHandler(reportAlertOnIncomplete: false)
        await scanBrowsers(reportEmptyAlert: false)
    }

    func refreshHandlerStatusSilently() async {
        guard step == .linkHandling, !isCheckingHandlers else { return }
        loginItemState = environment.loginItemService?.status()
        await queryCurrentHandler(reportAlertOnIncomplete: false)
    }

    func setPrismAsDefault() async {
        guard step == .linkHandling, !isCheckingHandlers else { return }
        isCheckingHandlers = true
        defer { isCheckingHandlers = false }
        do {
            _ = try await defaultBrowserService.setAsDefaultAfterUserConfirmation()
        } catch {
            // Always query the real handler state below instead of trusting the request.
        }
        await queryCurrentHandler(reportAlertOnIncomplete: true)
    }

    func refreshHandlers() async {
        guard step == .linkHandling, !isCheckingHandlers else { return }
        await queryCurrentHandler(reportAlertOnIncomplete: true)
    }

    func scanBrowsers(reportEmptyAlert: Bool = true) async {
        guard !isScanningBrowsers, !isTestLinkInProgress, !completionSaveIsPending else { return }
        isScanningBrowsers = true
        defer { isScanningBrowsers = false }
        do {
            let scanned = try await browserCatalog.scan()
            usableBrowsers = scanned.filter { $0.availability == .available }
            if usableBrowsers.isEmpty {
                if reportEmptyAlert {
                    alert = .noUsableBrowser
                }
            } else if alert == .noUsableBrowser || alert == .browserScanFailed || alert == .customBrowserFailed {
                alert = nil
            }
        } catch {
            usableBrowsers = []
            alert = .browserScanFailed
        }
    }

    func advanceFromBrowserScan() async {
        await scanBrowsers(reportEmptyAlert: true)
    }

    func reportCustomBrowserFailure() {
        guard !isTestLinkInProgress, !completionSaveIsPending else { return }
        alert = .customBrowserFailed
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard let loginItemService = environment.loginItemService, !isUpdatingLoginItem else { return }
        isUpdatingLoginItem = true
        defer { isUpdatingLoginItem = false }
        do {
            if enabled {
                try loginItemService.registerAfterUserAction()
            } else {
                try loginItemService.unregisterAfterUserAction()
            }
        } catch {
            // Re-read real service status below.
        }
        loginItemState = loginItemService.status()
    }

    // MARK: - Step 5: Real Test Link & Completion

    func beginTestLink() async {
        guard step == .testLink,
              testLinkGeneration == nil,
              testLinkSession == nil,
              !completionSaveIsPending
        else {
            return
        }
        if usableBrowsers.isEmpty {
            await scanBrowsers(reportEmptyAlert: true)
            guard !usableBrowsers.isEmpty else { return }
        }
        let generation = UUID()
        testLinkGeneration = generation
        testLinkWasAccepted = false
        alert = nil

        let session = await testLinkRouter.start(
            url: URL(string: "https://example.com/prism-onboarding-test")!,
            onPrepared: { [weak self] session in
                guard let self,
                      self.testLinkGeneration == generation,
                      !self.environment.settings.onboardingCompleted
                else {
                    return false
                }
                self.testLinkSession = session
                return true
            }
        ) { [weak self] outcome in
            guard let self else { return false }
            return await self.receiveTestLinkOutcome(outcome)
        }

        guard testLinkGeneration == generation,
              !environment.settings.onboardingCompleted
        else {
            if let session {
                _ = await session.cancel()
            }
            return
        }
        testLinkGeneration = nil
        guard let session else {
            testLinkSession = nil
            alert = .testLinkFailed
            return
        }
        if testLinkSession?.requestID != session.requestID {
            testLinkSession = session
        }
    }

    func finishTestLater() async {
        guard step == .testLink, testLinkGeneration == nil else { return }
        if completionSaveIsPending {
            await retryCompletionSave()
            return
        }
        if let session = testLinkSession {
            finishLaterCancellationRequestID = session.requestID
            let cancellationResult = await session.cancel()
            finishLaterCancellationRequestID = nil
            guard cancellationResult == .cancelled else {
                alert = .testLinkCancellationFailed
                return
            }
            testLinkSession = nil
        }
        completionSaveIsPending = true
        await completeOnboarding()
    }

    func retryCompletionSave() async {
        guard step == .testLink,
              completionSaveIsPending,
              testLinkGeneration == nil,
              testLinkSession == nil
        else { return }
        await completeOnboarding()
    }

    func finishSetup() async {
        guard step == .testLink,
              !environment.settings.onboardingCompleted
        else { return }
        if isTestLinkInProgress {
            await finishTestLater()
            return
        }
        if completionSaveIsPending {
            await retryCompletionSave()
            return
        }
        completionSaveIsPending = true
        await completeOnboarding()
    }

    // MARK: - Internals

    private func queryCurrentHandler(reportAlertOnIncomplete: Bool) async {
        isCheckingHandlers = true
        defer { isCheckingHandlers = false }
        do {
            let state = try await defaultBrowserService.status()
            updateHandlerState(state)
            handlerStatusIsKnown = true
            if state == .active {
                if alert == .defaultHandlerIncomplete || alert == .defaultHandlerUnavailable {
                    alert = nil
                }
            } else if reportAlertOnIncomplete {
                alert = .defaultHandlerIncomplete
            }
        } catch {
            handlerStatusIsKnown = false
            if reportAlertOnIncomplete {
                alert = .defaultHandlerUnavailable
            }
        }
    }

    private func updateHandlerState(_ state: DefaultHandlerState) {
        switch state {
        case .active:
            httpHandlerIsActive = true
            httpsHandlerIsActive = true
        case let .inactive(http, https):
            httpHandlerIsActive = http
            httpsHandlerIsActive = https
        }
    }

    private func receiveTestLinkOutcome(_ outcome: LinkRoutingOutcome) async -> Bool {
        guard testLinkSession?.requestID == outcome.requestID else { return false }

        switch outcome.kind {
        case .handoffAccepted:
            testLinkGeneration = nil
            testLinkSession = nil
            testLinkWasAccepted = true
            alert = nil
            return false
        case .cancelled where finishLaterCancellationRequestID == outcome.requestID:
            return false
        case .cancelled, .completedWithoutConfirmedHandoff:
            testLinkGeneration = nil
            testLinkSession = nil
            alert = .testLinkFailed
            return false
        case .handoffFailed, .outcomeUnknown, .unavailable, .storageUnavailable:
            alert = .testLinkFailed
            return true
        }
    }

    @discardableResult
    private func completeOnboarding() async -> Bool {
        guard environment.mutateSettings({
            $0.unmatchedBehavior = .alwaysAsk
            $0.onboardingCompleted = true
        }) else {
            alert = .settingsNotSaved
            return false
        }
        alert = nil
        testLinkWasAccepted = false
        completionSaveIsPending = false
        openMainWindow(.history)
        await resumeRouting()
        return true
    }
}
