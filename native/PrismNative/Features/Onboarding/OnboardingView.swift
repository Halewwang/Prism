import AppKit
import PrismCore
import SwiftUI

enum OnboardingActionID: String, CaseIterable, Equatable, Hashable {
    case continueFromWelcome
    case setAsDefault
    case refreshHandlers
    case openDefaultAppsSettings
    case finishLinkHandlingLater
    case rescanBrowsers
    case addCustomBrowser
    case openApplicationsFolder
    case startTestLink
    case retryTestLink
    case retryCompletionSave
    case finishSetup
    case finishTestLater
}

enum OnboardingActionEmphasis: Equatable {
    case primary
    case secondary
    case quiet
}

struct OnboardingActionPresentation: Equatable, Identifiable {
    let id: OnboardingActionID
    let title: String
    let accessibilityIdentifier: String
    let accessibilityHint: String
    let emphasis: OnboardingActionEmphasis
    let isEnabled: Bool
}

struct OnboardingStatusRowPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let statusText: String
    let iconSystemName: String
    let accessibilityIdentifier: String

    var accessibilityLabel: String {
        "\(title): \(statusText)"
    }
}

struct OnboardingBrowserRowPresentation: Equatable, Identifiable {
    let id: String
    let name: String
    let location: String
    let statusText: String
    let accessibilityIdentifier: String

    var accessibilityLabel: String {
        "\(name), \(statusText), \(location)"
    }
}

struct OnboardingAlertPresentation: Equatable {
    let iconSystemName: String
    let title: String
    let message: String
    let accessibilityIdentifier: String
}

struct OnboardingViewPresentation: Equatable {
    let step: OnboardingStep
    let progressText: String
    let progressValue: Double
    let accessibilityIdentifier: String
    let title: String
    let message: String
    let statusRows: [OnboardingStatusRowPresentation]
    let browserRows: [OnboardingBrowserRowPresentation]
    let alert: OnboardingAlertPresentation?
    let activityText: String?
    let actions: [OnboardingActionPresentation]

    var preferredFocusedActionID: OnboardingActionID? {
        actions.first(where: \.isEnabled)?.id
    }

    init(
        step: OnboardingStep,
        alert: OnboardingAlert?,
        httpHandlerIsActive: Bool,
        httpsHandlerIsActive: Bool,
        usableBrowsers: [BrowserDescriptor],
        isTestLinkInProgress: Bool,
        isTestLinkPreparing: Bool = false,
        isRefreshingHandler: Bool = false,
        isScanningBrowsers: Bool = false,
        handlerStatusIsKnown: Bool = true,
        isCheckingHandlers: Bool = false,
        testLinkWasAccepted: Bool = false,
        completionSaveIsPending: Bool = false
    ) {
        self.step = step
        progressText = "Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)"
        progressValue = Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count)
        self.alert = alert.map(Self.alertPresentation)

        switch step {
        case .welcome:
            accessibilityIdentifier = "onboarding.step.welcome"
            title = "Your links, in the right browser"
            message = "Prism sends each web link to the browser you choose. Your rules and history stay on this Mac."
            statusRows = []
            browserRows = []
            activityText = nil
            actions = [
                Self.action(
                    .continueFromWelcome,
                    title: "Continue",
                    identifier: "onboarding.welcome.continue",
                    hint: "Continue to link handling",
                    emphasis: .primary
                ),
            ]

        case .linkHandling:
            let handlerIsChecking = isRefreshingHandler || isCheckingHandlers
            accessibilityIdentifier = "onboarding.step.linkHandling"
            title = "Let Prism handle web links"
            message = "macOS manages HTTP and HTTPS separately. Prism checks both before continuing."
            statusRows = [
                Self.handlerStatus(
                    id: "http",
                    title: "HTTP links",
                    isActive: httpHandlerIsActive,
                    isKnown: handlerStatusIsKnown,
                    isChecking: handlerIsChecking
                ),
                Self.handlerStatus(
                    id: "https",
                    title: "HTTPS links",
                    isActive: httpsHandlerIsActive,
                    isKnown: handlerStatusIsKnown,
                    isChecking: handlerIsChecking
                ),
            ]
            browserRows = []
            activityText = handlerIsChecking ? "Checking HTTP and HTTPS handlers…" : nil
            var linkActions = [
                Self.action(
                    .setAsDefault,
                    title: "Set as Default",
                    identifier: "onboarding.linkHandling.setDefault",
                    hint: "Ask macOS to use Prism for HTTP and HTTPS links",
                    emphasis: .primary,
                    isEnabled: !handlerIsChecking
                ),
                Self.action(
                    .refreshHandlers,
                    title: "Refresh",
                    identifier: "onboarding.linkHandling.refresh",
                    hint: "Check the current HTTP and HTTPS handlers again",
                    emphasis: .secondary,
                    isEnabled: !handlerIsChecking
                ),
            ]
            if alert == .defaultHandlerIncomplete || alert == .defaultHandlerUnavailable {
                linkActions.append(
                    Self.action(
                        .openDefaultAppsSettings,
                        title: "Open System Settings",
                        identifier: "onboarding.linkHandling.openSettings",
                        hint: "Open the macOS settings for default applications",
                        emphasis: .secondary,
                        isEnabled: !handlerIsChecking
                    )
                )
            }
            linkActions.append(
                Self.action(
                    .finishLinkHandlingLater,
                    title: "Finish Later",
                    identifier: "onboarding.linkHandling.finishLater",
                    hint: "Continue setup without changing the link handler",
                    emphasis: .quiet,
                    isEnabled: !handlerIsChecking
                )
            )
            actions = linkActions

        case .browsers:
            accessibilityIdentifier = "onboarding.step.browsers"
            title = "Choose available browsers"
            message = "Prism needs at least one usable browser before you can test a link."
            statusRows = []
            browserRows = usableBrowsers
                .filter { $0.availability == .available }
                .map {
                    OnboardingBrowserRowPresentation(
                        id: $0.id.rawValue,
                        name: $0.displayName,
                        location: $0.applicationURL.path,
                        statusText: "Ready",
                        accessibilityIdentifier: "onboarding.browsers.browser.\($0.id.rawValue)"
                    )
                }
            activityText = isScanningBrowsers ? "Looking for installed browsers…" : nil
            if browserRows.isEmpty {
                actions = [
                    Self.action(
                        .rescanBrowsers,
                        title: "Rescan",
                        identifier: "onboarding.browsers.rescan",
                        hint: "Look for installed browsers again",
                        emphasis: .primary,
                        isEnabled: !isScanningBrowsers
                    ),
                    Self.action(
                        .addCustomBrowser,
                        title: "Add Custom Browser",
                        identifier: "onboarding.browsers.addCustomBrowser",
                        hint: "Choose another browser application",
                        emphasis: .secondary,
                        isEnabled: !isScanningBrowsers
                    ),
                    Self.action(
                        .openApplicationsFolder,
                        title: "Open Applications Folder",
                        identifier: "onboarding.browsers.openApplicationsFolder",
                        hint: "Show installed applications in Finder",
                        emphasis: .secondary,
                        isEnabled: !isScanningBrowsers
                    ),
                ]
            } else if alert == .settingsNotSaved {
                actions = [
                    Self.action(
                        .rescanBrowsers,
                        title: "Retry Saving Setup",
                        identifier: "onboarding.browsers.retrySave",
                        hint: "Retry saving the browser setup without changing the selected browsers",
                        emphasis: .primary,
                        isEnabled: !isScanningBrowsers
                    ),
                ]
            } else {
                actions = []
            }

        case .testLink:
            accessibilityIdentifier = "onboarding.step.testLink"
            title = "Try Prism with a test link"
            message = "Prism will send a test link through the real selector and confirm that a browser accepts it."
            statusRows = []
            browserRows = []
            if isScanningBrowsers {
                activityText = "Looking for installed browsers…"
            } else if isTestLinkPreparing {
                activityText = "Preparing the test link…"
            } else if isTestLinkInProgress {
                activityText = "Waiting for the browser to accept the test link…"
            } else {
                activityText = nil
            }
            if completionSaveIsPending || (testLinkWasAccepted && alert == .settingsNotSaved) {
                actions = [
                    Self.action(
                        .retryCompletionSave,
                        title: "Retry Saving Setup",
                        identifier: "onboarding.testLink.retryCompletionSave",
                        hint: "Save the completed setup without opening another test link",
                        emphasis: .primary
                    ),
                ]
            } else if testLinkWasAccepted {
                actions = [
                    Self.action(
                        .finishSetup, title: "Start Using Prism",
                        identifier: "onboarding.testLink.finish",
                        hint: "Save the completed setup and open History",
                        emphasis: .primary
                    ),
                    Self.action(
                        .retryTestLink, title: "Test Again",
                        identifier: "onboarding.testLink.retest",
                        hint: "Open another test link in the real browser selector",
                        emphasis: .quiet
                    ),
                ]
            } else if isTestLinkInProgress {
                actions = [
                    Self.action(
                        .finishTestLater,
                        title: "Finish Later",
                        identifier: "onboarding.testLink.finishLater",
                        hint: "Cancel the current test and finish setup without confirming it",
                        emphasis: .quiet,
                        isEnabled: !isTestLinkPreparing
                    ),
                ]
            } else {
                let retry = alert == .testLinkFailed
                let primary = Self.action(
                    retry ? .retryTestLink : .startTestLink,
                    title: retry ? "Retry Test Link" : "Test Link",
                    identifier: retry ? "onboarding.testLink.retry" : "onboarding.testLink.start",
                    hint: "Open the real browser selector for a test link",
                    emphasis: .primary,
                    isEnabled: !isScanningBrowsers
                )
                if alert != nil {
                    actions = [primary, Self.action(
                        .finishTestLater, title: "Finish Later",
                        identifier: "onboarding.testLink.finishLater",
                        hint: "Finish setup without confirming the test link",
                        emphasis: .quiet,
                        isEnabled: !isScanningBrowsers
                    )]
                } else {
                    actions = [primary,
                        Self.action(
                            .rescanBrowsers, title: "Rescan",
                            identifier: "onboarding.browsers.rescan",
                            hint: "Look for installed browsers again",
                            emphasis: .quiet, isEnabled: !isScanningBrowsers
                        ),
                        Self.action(
                            .addCustomBrowser, title: "Add Custom Browser",
                            identifier: "onboarding.browsers.addCustomBrowser",
                            hint: "Choose another browser application",
                            emphasis: .quiet, isEnabled: !isScanningBrowsers
                        ),
                    ]
                }
            }
        }
    }

    var visibleText: [String] {
        [progressText, title, message, activityText]
            .compactMap { $0 }
            + statusRows.flatMap { [$0.title, $0.statusText] }
            + browserRows.flatMap { [$0.name, $0.location, $0.statusText] }
            + [alert?.title, alert?.message].compactMap { $0 }
            + actions.map(\.title)
    }

    private static func action(
        _ id: OnboardingActionID,
        title: String,
        identifier: String,
        hint: String,
        emphasis: OnboardingActionEmphasis,
        isEnabled: Bool = true
    ) -> OnboardingActionPresentation {
        OnboardingActionPresentation(
            id: id,
            title: title,
            accessibilityIdentifier: identifier,
            accessibilityHint: hint,
            emphasis: emphasis,
            isEnabled: isEnabled
        )
    }

    private static func handlerStatus(
        id: String,
        title: String,
        isActive: Bool,
        isKnown: Bool,
        isChecking: Bool
    ) -> OnboardingStatusRowPresentation {
        let statusText: String
        let iconSystemName: String
        if isChecking {
            statusText = "Checking…"
            iconSystemName = "arrow.triangle.2.circlepath.circle.fill"
        } else if !isKnown {
            statusText = "Unavailable"
            iconSystemName = "questionmark.circle.fill"
        } else if isActive {
            statusText = "Prism is active"
            iconSystemName = "checkmark.circle.fill"
        } else {
            statusText = "Needs attention"
            iconSystemName = "exclamationmark.circle.fill"
        }
        return OnboardingStatusRowPresentation(
            id: id,
            title: title,
            statusText: statusText,
            iconSystemName: iconSystemName,
            accessibilityIdentifier: "onboarding.linkHandling.\(id)Status"
        )
    }

    private static func alertPresentation(_ alert: OnboardingAlert) -> OnboardingAlertPresentation {
        let iconSystemName: String
        let title: String
        let message: String
        switch alert {
        case .defaultHandlerIncomplete:
            iconSystemName = "exclamationmark.triangle.fill"
            title = "Prism is not handling every web link"
            message = "HTTP and HTTPS must both use Prism. Try again or review the default application in System Settings."
        case .defaultHandlerUnavailable:
            iconSystemName = "questionmark.circle.fill"
            title = "Link handling could not be checked"
            message = "Refresh the status, or open System Settings and confirm the default application manually."
        case .noUsableBrowser:
            iconSystemName = "safari.fill"
            title = "No usable browsers were found"
            message = "Install a browser, add one manually, or rescan after moving it into Applications."
        case .browserScanFailed:
            iconSystemName = "exclamationmark.triangle.fill"
            title = "Browsers could not be scanned"
            message = "Prism could not read the installed applications. Try the scan again."
        case .customBrowserFailed:
            iconSystemName = "exclamationmark.triangle.fill"
            title = "The browser could not be added"
            message = "Choose a valid browser application, or use Rescan to look for installed browsers."
        case .settingsNotSaved:
            iconSystemName = "externaldrive.badge.exclamationmark"
            title = "Your changes could not be saved"
            message = "Keep Prism open and try again. Setup is not complete until the change is saved."
        case .testLinkFailed:
            iconSystemName = "arrow.clockwise.circle.fill"
            title = "The test link did not finish"
            message = "Retry the test, or choose Finish Later to complete setup without a confirmed browser handoff."
        case .testLinkCancellationFailed:
            iconSystemName = "externaldrive.badge.exclamationmark"
            title = "The test link could not be cancelled"
            message = "Prism kept the current test link so it is not duplicated. Try Finish Later again."
        }
        return OnboardingAlertPresentation(
            iconSystemName: iconSystemName,
            title: title,
            message: message,
            accessibilityIdentifier: "onboarding.alert"
        )
    }
}

enum OnboardingExternalAction: String, CaseIterable, Equatable {
    case addCustomBrowser
    case openDefaultAppsSettings
    case openApplicationsFolder
}

enum OnboardingCustomBrowserResult: Equatable, Sendable {
    case added
    case cancelled
    case failed
}

@MainActor
struct OnboardingViewActions {
    private let addCustomBrowserAction: @MainActor () async -> OnboardingCustomBrowserResult
    private let openDefaultAppsSettings: () -> Void
    private let openApplicationsFolder: () -> Void

    init(
        addCustomBrowser: @escaping @MainActor () async -> OnboardingCustomBrowserResult,
        openDefaultAppsSettings: @escaping () -> Void,
        openApplicationsFolder: @escaping () -> Void
    ) {
        addCustomBrowserAction = addCustomBrowser
        self.openDefaultAppsSettings = openDefaultAppsSettings
        self.openApplicationsFolder = openApplicationsFolder
    }

    func addCustomBrowser() async -> OnboardingCustomBrowserResult {
        await addCustomBrowserAction()
    }

    func openSettings() {
        openDefaultAppsSettings()
    }

    func openApplications() {
        openApplicationsFolder()
    }
}

@MainActor
struct OnboardingViewInteractions {
    let model: OnboardingViewModel
    let actions: OnboardingViewActions

    func addCustomBrowser() async {
        switch await actions.addCustomBrowser() {
        case .added:
            await model.advanceFromBrowserScan()
        case .failed:
            model.reportCustomBrowserFailure()
        case .cancelled:
            break
        }
    }
}

@MainActor
struct OnboardingView: View {
    @State private var model: OnboardingViewModel
    let actions: OnboardingViewActions

    @State private var isScanningBrowsers = false
    @State private var isStartingTestLink = false
    @FocusState private var focusedAction: OnboardingActionID?
    private let fillsMinimumWindowSize: Bool

    init(
        model: OnboardingViewModel,
        actions: OnboardingViewActions,
        fillsMinimumWindowSize: Bool = true
    ) {
        _model = State(initialValue: model)
        self.actions = actions
        self.fillsMinimumWindowSize = fillsMinimumWindowSize
    }

    var presentation: OnboardingViewPresentation {
        OnboardingViewPresentation(
            step: model.step,
            alert: model.alert,
            httpHandlerIsActive: model.httpHandlerIsActive,
            httpsHandlerIsActive: model.httpsHandlerIsActive,
            usableBrowsers: model.usableBrowsers,
            isTestLinkInProgress: model.isTestLinkInProgress || isStartingTestLink,
            isTestLinkPreparing: model.isTestLinkPreparing,
            isScanningBrowsers: isScanningBrowsers,
            handlerStatusIsKnown: model.handlerStatusIsKnown,
            isCheckingHandlers: model.isCheckingHandlers,
            testLinkWasAccepted: model.testLinkWasAccepted,
            completionSaveIsPending: model.completionSaveIsPending
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    titleBlock
                    stepContent
                    if let alert = presentation.alert {
                        alertView(alert)
                    }
                    if let activityText = presentation.activityText {
                        activityView(activityText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.content")
        .padding(WorkspaceLayout.dialogContentInset)
        .frame(
            minWidth: fillsMinimumWindowSize ? 668 : nil,
            minHeight: fillsMinimumWindowSize ? 554 : nil
        )
        .background(SettingsPalette.canvas)
        .tint(SettingsPalette.primary)
        .task(id: presentation.preferredFocusedActionID) {
            focusedAction = presentation.preferredFocusedActionID
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d / %02d", displayStepNumber, OnboardingStep.allCases.count))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .tracking(1)
                .foregroundStyle(SettingsPalette.muted)
                .accessibilityIdentifier("onboarding.progress.label")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Setup progress")
        .accessibilityValue(String(format: String(localized: "Step %d of %d"), displayStepNumber, OnboardingStep.allCases.count))
        .accessibilityIdentifier("onboarding.progress")
    }

    private var displayStepNumber: Int {
        presentation.step == .testLink && !model.testLinkWasAccepted ? 3 : presentation.step.rawValue + 1
    }

    private var renderedBrowserRows: [OnboardingBrowserRowPresentation] {
        model.usableBrowsers
            .filter { $0.availability == .available }
            .map {
                OnboardingBrowserRowPresentation(
                    id: $0.id.rawValue,
                    name: $0.displayName,
                    location: $0.applicationURL.path,
                    statusText: "Ready",
                    accessibilityIdentifier: "onboarding.browsers.browser.\($0.id.rawValue)"
                )
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 24) {
            if presentation.step == .welcome {
                Image("PrismBrand")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            } else if model.testLinkWasAccepted {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(SettingsPalette.iconStrong)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: stepSymbol)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(SettingsPalette.iconStrong)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text(LocalizedStringKey(displayTitle))
                    .font(.system(size: 29, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(SettingsPalette.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(presentation.accessibilityIdentifier)
                Text(displayMessage)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .foregroundStyle(SettingsPalette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayTitle: String {
        switch presentation.step {
        case .welcome: "Your links,\nyour way to browse."
        case .linkHandling: "Let Prism take care of links"
        case .browsers: renderedBrowserRows.isEmpty ? "Discover your browsers" : "We found your browsers"
        case .testLink: model.testLinkWasAccepted ? "All set" : "We found your browsers"
        }
    }

    private var displayMessage: String {
        switch presentation.step {
        case .welcome:
            String(localized: "Work in Chrome, unwind in Safari.\nPrism chooses the right browser using sources and rules.")
                + "\n" + String(localized: "Rules and history stay on your Mac")
        case .linkHandling:
            String(localized: "macOS manages HTTP and HTTPS separately.\nPrism handles every web link only when both are enabled.")
        case .browsers:
            renderedBrowserRows.isEmpty
                ? String(localized: "Scan installed applications or add another browser manually.")
                : String(format: String(localized: "Found %d available browsers. You can also add another application manually."), renderedBrowserRows.count)
        case .testLink:
            model.testLinkWasAccepted
                ? String(localized: "The test link opened successfully.\nPrism will appear when you need it the next time you click a link.")
                : String(format: String(localized: "Found %d available browsers. Open a test link to check that everything works."), renderedBrowserRows.count)
        }
    }

    private var stepSymbol: String {
        switch presentation.step {
        case .welcome: "arrow.triangle.branch"
        case .linkHandling: "link"
        case .browsers: "safari"
        case .testLink: "safari"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch presentation.step {
        case .welcome:
            EmptyView()
        case .linkHandling:
            handlerContent
        case .browsers:
            browserContent
        case .testLink:
            testLinkContent
        }
    }

    private var handlerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            onboardingSection {
                VStack(spacing: 17) {
                    ForEach(presentation.statusRows) { row in
                        HStack {
                            Text(LocalizedStringKey(row.title))
                                .font(.system(size: 13))
                                .foregroundStyle(SettingsPalette.tertiary)
                            Spacer()
                            Text(LocalizedStringKey(handlerStatusText(row)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SettingsPalette.primary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.accessibilityLabel)
                        .accessibilityIdentifier(row.accessibilityIdentifier)
                    }
                }
            }
            Text("If setup did not finish, open System Settings and refresh the status.")
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.muted)
        }
    }

    private func handlerStatusText(_ row: OnboardingStatusRowPresentation) -> String {
        switch row.statusText {
        case "Prism is active": "Handled"
        case "Needs attention": "Not handled yet"
        default: row.statusText
        }
    }

    @ViewBuilder
    private var browserContent: some View {
        if renderedBrowserRows.isEmpty {
            onboardingSection {
                VStack(alignment: .leading, spacing: 5) {
                    Text("No browsers are ready yet")
                        .font(.system(size: 13, weight: .medium))
                    Text("Rescan installed applications or add a browser manually.")
                        .font(.system(size: 12))
                        .foregroundStyle(SettingsPalette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("onboarding.browsers.empty")
        } else {
            onboardingSection {
                VStack(spacing: 0) {
                    ForEach(Array(renderedBrowserRows.enumerated()), id: \.element.id) { index, browser in
                        if index > 0 {
                            Rectangle().fill(SettingsPalette.sidebar).frame(height: 1)
                        }
                        HStack(spacing: 10) {
                            ApplicationIconView(bundleIdentifier: browser.id, fallbackSymbol: "safari", side: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(browser.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(SettingsPalette.secondary)
                                Text(browser.location)
                                    .font(.system(size: 11))
                                    .foregroundStyle(SettingsPalette.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .help(browser.location)
                            }
                            Spacer()
                            Text(LocalizedStringKey(browser.statusText == "Ready" ? "browsers.available" : browser.statusText))
                                .font(.system(size: 11))
                                .foregroundStyle(SettingsPalette.primary)
                        }
                        .padding(.vertical, 13)
                        .frame(minHeight: 60)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(browser.accessibilityLabel)
                        .accessibilityIdentifier(browser.accessibilityIdentifier)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var testLinkContent: some View {
        if !model.testLinkWasAccepted {
            VStack(alignment: .leading, spacing: 12) {
                browserContent
                Text("Choose a browser to confirm the handoff.")
                    .font(.system(size: 12))
                    .foregroundStyle(SettingsPalette.secondary)
                    .accessibilityIdentifier("onboarding.testLink.explanation")
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                onboardingSection {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Test link opened")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(SettingsPalette.tertiary)
                            Text("Link handling and browser launch verified")
                                .font(.system(size: 11))
                                .foregroundStyle(SettingsPalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Opened")
                            .font(.system(size: 11))
                            .foregroundStyle(SettingsPalette.primary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("onboarding.testLink.explanation")
                Text("Create your first routing rule next, or start using Prism right away.")
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(SettingsPalette.muted)
            }
        }
    }

    private func onboardingSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
    }

    private func alertView(_ alert: OnboardingAlertPresentation) -> some View {
        onboardingSection {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(alert.title))
                    .font(.system(size: 13, weight: .medium))
                Text(LocalizedStringKey(alert.message))
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(alert.accessibilityIdentifier)
    }

    private func activityView(_ text: String) -> some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text(LocalizedStringKey(text))
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityIdentifier("onboarding.activity")
    }

    private var actionBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(presentation.actions.filter { $0.emphasis == .primary }) { action in
                    actionButton(action)
                }
                if presentation.actions.contains(where: { $0.emphasis != .primary }) {
                    HStack(spacing: 8) {
                        ForEach(presentation.actions.filter { $0.emphasis != .primary }) { action in
                            actionButton(action)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            progressHeader
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionButton(_ action: OnboardingActionPresentation) -> some View {
        if action.emphasis == .primary {
            baseButton(action)
                .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 39))
                .keyboardShortcut(.defaultAction)
        } else {
            baseButton(action)
                .buttonStyle(WorkspaceButtonStyle(
                    kind: action.emphasis == .secondary ? .secondary : .quiet,
                    height: 32,
                    horizontalPadding: 10,
                    fontSize: 12
                ))
        }
    }

    private func baseButton(_ action: OnboardingActionPresentation) -> some View {
        Button {
            perform(action.id)
        } label: {
            Text(LocalizedStringKey(displayActionTitle(action)))
                .frame(minWidth: action.emphasis == .primary ? 100 : nil)
        }
        .disabled(!action.isEnabled)
        .focused($focusedAction, equals: action.id)
        .accessibilityHint(action.accessibilityHint)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    private func displayActionTitle(_ action: OnboardingActionPresentation) -> String {
        switch action.id {
        case .continueFromWelcome: "Start Setup"
        case .setAsDefault: "Set as Default Browser"
        case .finishLinkHandlingLater: "Set Up Later"
        case .startTestLink: "Open Test Link"
        case .retryTestLink: model.testLinkWasAccepted ? "Test Again" : action.title
        case .addCustomBrowser: "Add Browser"
        case .retryCompletionSave: action.title
        default: action.title
        }
    }

    private func perform(_ action: OnboardingActionID) {
        switch action {
        case .continueFromWelcome:
            Task { await model.advanceFromWelcome() }
        case .setAsDefault:
            Task { await model.setPrismAsDefault() }
        case .refreshHandlers:
            Task { await model.advanceFromLinkHandling() }
        case .openDefaultAppsSettings:
            actions.openSettings()
        case .finishLinkHandlingLater:
            model.finishLater()
        case .rescanBrowsers:
            scanBrowsers()
        case .addCustomBrowser:
            addCustomBrowser()
        case .openApplicationsFolder:
            actions.openApplications()
        case .startTestLink, .retryTestLink:
            startTestLink()
        case .retryCompletionSave:
            Task { await model.retryCompletionSave() }
        case .finishSetup:
            Task { await model.finishSetup() }
        case .finishTestLater:
            Task { await model.finishTestLater() }
        }
    }

    private func scanBrowsers() {
        guard !isScanningBrowsers else { return }
        Task { @MainActor in
            isScanningBrowsers = true
            defer { isScanningBrowsers = false }
            await model.advanceFromBrowserScan()
        }
    }

    private func addCustomBrowser() {
        guard !isScanningBrowsers else { return }
        Task { @MainActor in
            isScanningBrowsers = true
            defer { isScanningBrowsers = false }
            await OnboardingViewInteractions(model: model, actions: actions).addCustomBrowser()
        }
    }

    private func startTestLink() {
        guard !isStartingTestLink, !model.isTestLinkInProgress else { return }
        Task { @MainActor in
            isStartingTestLink = true
            defer { isStartingTestLink = false }
            await model.beginTestLink()
        }
    }

}
