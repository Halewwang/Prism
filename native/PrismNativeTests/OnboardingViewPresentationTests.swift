import Foundation
import PrismCore
import Testing
@testable import PrismNative

@Suite("Onboarding presentation & alerts")
struct OnboardingViewPresentationTests {
    @Test func fiveStepsExposeSequentialNumbersAndRailTitles() {
        #expect(OnboardingStep.allCases == [
            .welcome,
            .presentationStyle,
            .routingRules,
            .linkHandling,
            .testLink,
        ])
        #expect(OnboardingStep.allCases.map(\.stepNumber) == [1, 2, 3, 4, 5])
        #expect(OnboardingStep.allCases.allSatisfy { !$0.railTitleKey.isEmpty })
    }

    @Test(arguments: OnboardingAlert.allCasesForPresentationTests)
    func everyAlertHasANonColorCueAndReadableRecoveryMessage(alert: OnboardingAlert) {
        let presentation = OnboardingAlertPresentation.make(alert)

        #expect(!presentation.iconSystemName.isEmpty)
        #expect(!presentation.title.isEmpty)
        #expect(!presentation.message.isEmpty)
        #expect(presentation.accessibilityIdentifier == "onboarding.alert")
    }
}

@Suite("Onboarding external actions")
@MainActor
struct OnboardingExternalActionTests {
    @Test func systemRoutesRemainInjectedAndDispatchOnlyTheirMatchingClosure() async {
        var received: [OnboardingExternalAction] = []
        let actions = OnboardingViewActions(
            addCustomBrowser: {
                received.append(.addCustomBrowser)
                return .added
            },
            openDefaultAppsSettings: { received.append(.openDefaultAppsSettings) },
            openApplicationsFolder: { received.append(.openApplicationsFolder) }
        )

        #expect(await actions.addCustomBrowser() == .added)
        actions.openSettings()
        actions.openApplications()

        #expect(received == OnboardingExternalAction.allCases)
    }

    @Test func cancelledAndFailedBrowserPickerResultsRemainDistinctFromAddition() async {
        let cancelled = OnboardingViewActions(
            addCustomBrowser: { .cancelled },
            openDefaultAppsSettings: {},
            openApplicationsFolder: {}
        )
        let failed = OnboardingViewActions(
            addCustomBrowser: { .failed },
            openDefaultAppsSettings: {},
            openApplicationsFolder: {}
        )

        #expect(await cancelled.addCustomBrowser() == .cancelled)
        #expect(await failed.addCustomBrowser() == .failed)
    }
}

private extension OnboardingAlert {
    static let allCasesForPresentationTests: [OnboardingAlert] = [
        .defaultHandlerIncomplete,
        .defaultHandlerUnavailable,
        .noUsableBrowser,
        .browserScanFailed,
        .customBrowserFailed,
        .settingsNotSaved,
        .testLinkFailed,
        .testLinkCancellationFailed,
    ]
}
