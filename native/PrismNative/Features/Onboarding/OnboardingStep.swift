enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case presentationStyle
    case routingRules
    case linkHandling
    case testLink

    var stepNumber: Int { rawValue + 1 }

    var railTitleKey: String {
        switch self {
        case .welcome: "onboarding.rail.welcome"
        case .presentationStyle: "onboarding.rail.style"
        case .routingRules: "onboarding.rail.rules"
        case .linkHandling: "onboarding.rail.setup"
        case .testLink: "onboarding.rail.ready"
        }
    }
}

enum OnboardingAlert: Equatable {
    case defaultHandlerIncomplete
    case defaultHandlerUnavailable
    case noUsableBrowser
    case browserScanFailed
    case customBrowserFailed
    case settingsNotSaved
    case testLinkFailed
    case testLinkCancellationFailed
}
