import AppKit
import PrismCore
import SwiftUI

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

struct OnboardingAlertPresentation: Equatable {
    let iconSystemName: String
    let title: String
    let message: String
    let accessibilityIdentifier: String

    static func make(_ alert: OnboardingAlert) -> Self {
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
            message = "Retry the test, or start using Prism right away."
        case .testLinkCancellationFailed:
            iconSystemName = "externaldrive.badge.exclamationmark"
            title = "The test link could not be cancelled"
            message = "Prism kept the current test link so it is not duplicated. Try again."
        }
        return Self(
            iconSystemName: iconSystemName,
            title: title,
            message: message,
            accessibilityIdentifier: "onboarding.alert"
        )
    }
}

@MainActor
struct OnboardingView: View {
    static let windowContentWidth: CGFloat = 720
    static let windowContentHeight: CGFloat = 468

    @State private var model: OnboardingViewModel
    let actions: OnboardingViewActions

    @State private var simulatedBrowser: String = "Arc"
    @State private var demoRuleGithubEnabled = true
    @State private var demoRuleSourceEnabled = false
    @State private var activeLocaleOverride: Locale?
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

    private var effectiveLocale: Locale {
        if let activeLocaleOverride { return activeLocaleOverride }
        if let code = model.currentLanguage.interfaceLocalizationCode {
            return Locale(identifier: code)
        }
        return .current
    }

    private var isChineseInterface: Bool {
        effectiveLocale.identifier.lowercased().hasPrefix("zh")
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            hairline
            mainGrid
            hairline
            footerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(
            minWidth: fillsMinimumWindowSize ? Self.windowContentWidth : nil,
            minHeight: fillsMinimumWindowSize ? Self.windowContentHeight : nil
        )
        .background(SettingsPalette.canvas)
        .tint(SettingsPalette.action)
        .environment(\.locale, effectiveLocale)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.content")
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshHandlerStatusSilently() }
        }
    }

    // MARK: - Persistent Header (Dock Icon + 5-Step Rail + Language Toggle)

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.jumpTo(.welcome) }
            } label: {
                HStack(spacing: 7) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .accessibilityHidden(true)
                    Text("Prism")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(SettingsPalette.primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.canNavigateSteps)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    stepRailButton(for: step)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Setup progress")
            .accessibilityValue(String(format: NSLocalizedString("Step %d of %d", comment: "Onboarding progress"), model.step.stepNumber, OnboardingStep.allCases.count))
            .accessibilityIdentifier("onboarding.progress")

            Spacer(minLength: 8)

            Button {
                let next: AppLanguage = isChineseInterface ? .english : .simplifiedChinese
                if model.selectLanguage(next), let code = next.interfaceLocalizationCode {
                    activeLocaleOverride = Locale(identifier: code)
                }
            } label: {
                Text(isChineseInterface ? "EN" : "中文")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(SettingsPalette.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.languageToggle")
        }
        .padding(.horizontal, 24)
        .frame(height: 50)
    }

    private func stepRailButton(for step: OnboardingStep) -> some View {
        let isActive = model.step == step
        let isVisited = step.rawValue < model.step.rawValue
        return Button {
            Task { await model.jumpTo(step) }
        } label: {
            HStack(spacing: 5.5) {
                Circle()
                    .fill(isActive ? OnboardingPalette.brandLime : (isVisited ? SettingsPalette.primary.opacity(0.6) : SettingsPalette.borderStrong))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isActive ? 1.2 : 1)
                Text(LocalizedStringKey(step.railTitleKey))
                    .font(.system(size: 11.5, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? SettingsPalette.primary : SettingsPalette.muted)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canNavigateSteps)
        .accessibilityIdentifier("onboarding.rail.\(step.stepNumber)")
    }

    // MARK: - Unified 2-Column Grid Body (Identical Anchor Across All 5 Steps)

    private var mainGrid: some View {
        HStack(alignment: .top, spacing: 26) {
            leftColumn
                .frame(width: 226, alignment: .topLeading)
            rightStage
                .frame(maxWidth: .infinity)
                .frame(height: 300)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%02d / %02d", model.step.stepNumber, OnboardingStep.allCases.count))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(SettingsPalette.muted)
                .padding(.bottom, 10)
                .accessibilityIdentifier("onboarding.progress.label")

            Text(LocalizedStringKey(stepTitleKey))
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.4)
                .lineSpacing(3)
                .foregroundStyle(SettingsPalette.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(stepAccessibilityIdentifier)

            Text(LocalizedStringKey(stepSubtitleKey))
                .font(.system(size: 12.5))
                .lineSpacing(4)
                .foregroundStyle(SettingsPalette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)
                .accessibilityIdentifier("onboarding.message")

            leftStepControls

            if let alert = model.alert {
                compactAlertNotice(OnboardingAlertPresentation.make(alert))
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var stepAccessibilityIdentifier: String {
        switch model.step {
        case .welcome: "onboarding.step.welcome"
        case .presentationStyle: "onboarding.step.presentationStyle"
        case .routingRules: "onboarding.step.routingRules"
        case .linkHandling: "onboarding.step.linkHandling"
        case .testLink: "onboarding.step.testLink"
        }
    }

    private var stepTitleKey: String {
        switch model.step {
        case .welcome: "onboarding.v3.welcome.title"
        case .presentationStyle: "onboarding.v3.style.title"
        case .routingRules: "onboarding.v3.rules.title"
        case .linkHandling: "onboarding.v3.setup.title"
        case .testLink: "onboarding.v3.ready.title"
        }
    }

    private var stepSubtitleKey: String {
        switch model.step {
        case .welcome: "onboarding.v3.welcome.subtitle"
        case .presentationStyle: "onboarding.v3.style.subtitle"
        case .routingRules: "onboarding.v3.rules.subtitle"
        case .linkHandling: "onboarding.v3.setup.subtitle"
        case .testLink: "onboarding.v3.ready.subtitle"
        }
    }

    @ViewBuilder
    private var leftStepControls: some View {
        switch model.step {
        case .welcome:
            VStack(alignment: .leading, spacing: 12) {
                leftNoteRow(
                    titleKey: "onboarding.v3.welcome.note1.title",
                    detailKey: "onboarding.v3.welcome.note1.detail"
                )
                leftNoteRow(
                    titleKey: "onboarding.v3.welcome.note2.title",
                    detailKey: "onboarding.v3.welcome.note2.detail"
                )
            }

        case .presentationStyle:
            VStack(alignment: .leading, spacing: 8) {
                modeChoiceRow(
                    mode: .compact,
                    titleKey: "onboarding.v3.style.compact.title",
                    detailKey: "onboarding.v3.style.compact.detail",
                    identifier: "onboarding.style.compact"
                )
                modeChoiceRow(
                    mode: .preview,
                    titleKey: "onboarding.v3.style.preview.title",
                    detailKey: "onboarding.v3.style.preview.detail",
                    identifier: "onboarding.style.preview"
                )
            }

        case .routingRules:
            VStack(alignment: .leading, spacing: 8) {
                ruleDemoRow(
                    title: "*.github.com → Arc",
                    detailKey: "onboarding.v3.rules.urlRule.detail",
                    isOn: $demoRuleGithubEnabled,
                    identifier: "onboarding.rules.demoURL"
                )
                ruleDemoRow(
                    title: NSLocalizedString("onboarding.v3.rules.sourceRule.title", comment: "Demo source rule"),
                    detailKey: "onboarding.v3.rules.sourceRule.detail",
                    isOn: $demoRuleSourceEnabled,
                    identifier: "onboarding.rules.demoSource"
                )
            }

        case .linkHandling:
            VStack(alignment: .leading, spacing: 12) {
                leftNoteRow(
                    titleKey: "onboarding.v3.setup.note1.title",
                    detailKey: "onboarding.v3.setup.note1.detail"
                )
                leftNoteRow(
                    titleKey: "onboarding.v3.setup.note2.title",
                    detailKey: "onboarding.v3.setup.note2.detail"
                )
                if model.alert == .defaultHandlerIncomplete || model.alert == .defaultHandlerUnavailable {
                    Button(LocalizedStringKey("Open System Settings")) {
                        actions.openSettings()
                    }
                    .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 28, horizontalPadding: 11, fontSize: 11.5))
                    .accessibilityIdentifier("onboarding.linkHandling.openSettings")
                }
            }

        case .testLink:
            VStack(alignment: .leading, spacing: 12) {
                leftNoteRow(
                    titleKey: "onboarding.v3.ready.selectedStyle.title",
                    detailKey: model.selectedPresentationMode == .compact
                        ? "onboarding.v3.ready.selectedStyle.compact"
                        : "onboarding.v3.ready.selectedStyle.preview"
                )
                if model.isTestLinkInProgress {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(LocalizedStringKey(model.isTestLinkPreparing ? "Preparing the test link…" : "Waiting for the browser to accept the test link…"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(SettingsPalette.muted)
                    }
                    .accessibilityIdentifier("onboarding.activity")
                } else {
                    Button {
                        Task { await model.beginTestLink() }
                    } label: {
                        Text(LocalizedStringKey(model.testLinkWasAccepted ? "Test Again" : "onboarding.v3.ready.testLink"))
                    }
                    .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 29, horizontalPadding: 12, fontSize: 11.5))
                    .disabled(model.completionSaveIsPending)
                    .accessibilityIdentifier(model.testLinkWasAccepted ? "onboarding.testLink.retest" : "onboarding.testLink.start")
                }
            }
        }
    }

    private func leftNoteRow(titleKey: String, detailKey: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SettingsPalette.primary)
            Text(LocalizedStringKey(detailKey))
                .font(.system(size: 11))
                .lineSpacing(2.5)
                .foregroundStyle(SettingsPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 11)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SettingsPalette.borderStrong)
                .frame(width: 1.5)
        }
    }

    private func modeChoiceRow(
        mode: SelectorPresentationMode,
        titleKey: String,
        detailKey: String,
        identifier: String
    ) -> some View {
        let isSelected = model.selectedPresentationMode == mode
        return Button {
            model.selectPresentationMode(mode)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(titleKey))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(SettingsPalette.primary)
                    Text(LocalizedStringKey(detailKey))
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .stroke(isSelected ? SettingsPalette.primary : SettingsPalette.borderStrong, lineWidth: 1.4)
                    if isSelected {
                        Circle()
                            .fill(SettingsPalette.primary)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? SettingsPalette.group : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? SettingsPalette.borderStrong : SettingsPalette.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func ruleDemoRow(
        title: String,
        detailKey: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SettingsPalette.primary)
                        .lineLimit(1)
                    Text(LocalizedStringKey(detailKey))
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(WorkspaceToggleStyle())
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn.wrappedValue ? SettingsPalette.group : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isOn.wrappedValue ? SettingsPalette.borderStrong : SettingsPalette.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func compactAlertNotice(_ alert: OnboardingAlertPresentation) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: alert.iconSystemName)
                .font(.system(size: 11))
                .foregroundStyle(SettingsPalette.danger)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(alert.title))
                .font(.system(size: 11.5))
                .foregroundStyle(SettingsPalette.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.title). \(alert.message)")
        .accessibilityIdentifier(alert.accessibilityIdentifier)
    }

    // MARK: - Unified Right Stage (Fixed 300pt Frame Across All 5 Steps)

    private var rightStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingPalette.stageBackground)

            OnboardingDotGrid()
                .allowsHitTesting(false)

            if model.step == .welcome {
                RadialGradient(
                    colors: [OnboardingPalette.brandLime.opacity(0.11), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: 140
                )
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                stageBody
                    .padding(.horizontal, 20)
                Spacer(minLength: 0)
                Text(stageCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SettingsPalette.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var stageBody: some View {
        switch model.step {
        case .welcome:
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
                .accessibilityHidden(true)

        case .presentationStyle:
            if model.selectedPresentationMode == .compact {
                compactSelectorStageCard
            } else {
                linkPreviewStageCard
            }

        case .routingRules:
            routingRulesStageCard

        case .linkHandling:
            systemReadinessStageCard

        case .testLink:
            completionShortcutsStageCard
        }
    }

    private var stageCaption: String {
        switch model.step {
        case .welcome:
            NSLocalizedString("onboarding.v3.welcome.caption", comment: "Welcome stage caption")
        case .presentationStyle:
            if model.selectedPresentationMode == .compact {
                String(format: NSLocalizedString("onboarding.v3.style.compact.caption", comment: "Compact caption"), simulatedBrowser)
            } else {
                String(format: NSLocalizedString("onboarding.v3.style.preview.caption", comment: "Preview caption"), simulatedBrowser)
            }
        case .routingRules:
            NSLocalizedString("onboarding.v3.rules.caption", comment: "Rules stage caption")
        case .linkHandling:
            NSLocalizedString("onboarding.v3.setup.caption", comment: "Setup stage caption")
        case .testLink:
            model.testLinkWasAccepted
                ? NSLocalizedString("onboarding.v3.ready.captionVerified", comment: "Verified caption")
                : NSLocalizedString("onboarding.v3.ready.caption", comment: "Ready caption")
        }
    }

    // MARK: - Stage 2: Interactive Compact / Link Preview Cards

    private var compactSelectorStageCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                stagePill(NSLocalizedString("onboarding.v3.stage.sourceApp", comment: "Source app"))
                stageURLPill("github.com/Halewwang/Prism")
                stagePill("Esc")
            }
            HStack(spacing: 6) {
                stageBrowserTile(name: "Arc", initial: "A", color: Color(red: 0.23, green: 0.51, blue: 0.96), key: "1")
                stageBrowserTile(name: "Chrome", initial: "C", color: Color(red: 0.85, green: 0.47, blue: 0.02), key: "2")
                stageBrowserTile(name: "Safari", initial: "S", color: Color(red: 0.01, green: 0.52, blue: 0.78), key: "3")
            }
        }
        .padding(9)
        .frame(maxWidth: 336)
        .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(SettingsPalette.borderStrong, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func stageBrowserTile(name: String, initial: String, color: Color, key: String) -> some View {
        let isSelected = simulatedBrowser == name
        return Button {
            simulatedBrowser = name
        } label: {
            VStack(spacing: 6) {
                Text(initial)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsPalette.primary)
                stageKeycap(key)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? SettingsPalette.surfacePressed.opacity(0.65) : OnboardingPalette.subtleFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? SettingsPalette.borderStrong : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var linkPreviewStageCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                stagePill("‹ ›")
                stageURLPill("github.com/Halewwang/Prism")
                HStack(spacing: 4) {
                    previewMiniBrowserDot("Arc", color: Color(red: 0.23, green: 0.51, blue: 0.96))
                    previewMiniBrowserDot("Chrome", color: Color(red: 0.85, green: 0.47, blue: 0.02))
                    previewMiniBrowserDot("Safari", color: Color(red: 0.01, green: 0.52, blue: 0.78))
                }
                .padding(.horizontal, 6)
                .frame(height: 24)
                .background(OnboardingPalette.subtleFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(SettingsPalette.border, lineWidth: 1)
                }
                stagePill("Esc")
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SettingsPalette.borderStrong)
                        .frame(width: 110, height: 6)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(SettingsPalette.border)
                        .frame(width: 185, height: 5)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OnboardingPalette.subtleHover, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 3).fill(SettingsPalette.borderStrong).frame(width: 90, height: 6)
                        RoundedRectangle(cornerRadius: 2.5).fill(SettingsPalette.border).frame(maxWidth: .infinity).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2.5).fill(SettingsPalette.border).frame(width: 132, height: 5)
                        RoundedRectangle(cornerRadius: 2.5).fill(SettingsPalette.border).frame(width: 98, height: 5)
                    }
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(OnboardingPalette.subtleHover)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(SettingsPalette.border, lineWidth: 1)
                        }
                        .frame(width: 82, height: 54)
                }
            }
            .padding(12)
            .background(OnboardingPalette.subtleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SettingsPalette.border, lineWidth: 1)
            }
        }
        .padding(9)
        .frame(maxWidth: 340)
        .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(SettingsPalette.borderStrong, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func previewMiniBrowserDot(_ name: String, color: Color) -> some View {
        let isSelected = simulatedBrowser == name
        return Button {
            simulatedBrowser = name
        } label: {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(color)
                .opacity(isSelected ? 1 : 0.6)
                .frame(width: 11, height: 11)
        }
        .buttonStyle(.plain)
        .help(name)
    }

    private func stagePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(SettingsPalette.secondary)
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(OnboardingPalette.subtleFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(SettingsPalette.border, lineWidth: 1)
            }
            .fixedSize()
    }

    private func stageURLPill(_ url: String) -> some View {
        Text(url)
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(SettingsPalette.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
            .background(OnboardingPalette.subtleFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(SettingsPalette.border, lineWidth: 1)
            }
    }

    // MARK: - Stage 3: Smart Routing Flow Card

    private var routingRulesStageCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("github.com/Halewwang/Prism")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(SettingsPalette.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(LocalizedStringKey("onboarding.v3.stage.sourceApp"))
                    .font(.system(size: 11))
                    .foregroundStyle(SettingsPalette.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(SettingsPalette.borderStrong, lineWidth: 1)
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsPalette.muted)
                .accessibilityHidden(true)

            let matched = demoRuleGithubEnabled || demoRuleSourceEnabled
            let destinationKey = demoRuleGithubEnabled
                ? "onboarding.v3.rules.dest.arc"
                : demoRuleSourceEnabled
                    ? "onboarding.v3.rules.dest.chrome"
                    : "onboarding.v3.rules.dest.selector"
            let reasonKey = demoRuleGithubEnabled
                ? "onboarding.v3.rules.reason.url"
                : demoRuleSourceEnabled
                    ? "onboarding.v3.rules.reason.source"
                    : "onboarding.v3.rules.reason.none"

            HStack(spacing: 8) {
                Text(LocalizedStringKey(destinationKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primary)
                Spacer(minLength: 8)
                Text(LocalizedStringKey(reasonKey))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(matched ? Color.green : SettingsPalette.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(matched ? SettingsPalette.primary.opacity(0.45) : SettingsPalette.borderStrong, lineWidth: 1)
            }
        }
        .frame(maxWidth: 320)
    }

    // MARK: - Stage 4: System Readiness Grouped Card

    private var systemReadinessStageCard: some View {
        VStack(spacing: 0) {
            // Row 1: Default HTTP & HTTPS handler
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("onboarding.v3.setup.handler.title"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(SettingsPalette.primary)
                    Text(handlerDetailSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if model.isCheckingHandlers {
                    ProgressView().controlSize(.small)
                } else if model.isDefaultHandlerActive {
                    Text(LocalizedStringKey("onboarding.v3.setup.active"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .accessibilityIdentifier("onboarding.linkHandling.active")
                } else {
                    Button(LocalizedStringKey("Set as Default")) {
                        Task { await model.setPrismAsDefault() }
                    }
                    .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 28, horizontalPadding: 11, fontSize: 11.5))
                    .accessibilityIdentifier("onboarding.linkHandling.setDefault")
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.linkHandling.status")

            hairline

            // Row 2: Installed browsers
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("onboarding.v3.setup.browsers.title"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(SettingsPalette.primary)
                    Text(browsersSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                if model.isScanningBrowsers {
                    ProgressView().controlSize(.small)
                } else if model.usableBrowsers.isEmpty {
                    HStack(spacing: 6) {
                        Button(LocalizedStringKey("Rescan")) {
                            Task { await model.scanBrowsers(reportEmptyAlert: true) }
                        }
                        .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 26, horizontalPadding: 9, fontSize: 11))
                        .accessibilityIdentifier("onboarding.browsers.rescan")

                        Button(LocalizedStringKey("Add Browser")) {
                            Task { await OnboardingViewInteractions(model: model, actions: actions).addCustomBrowser() }
                        }
                        .buttonStyle(WorkspaceButtonStyle(kind: .secondary, height: 26, horizontalPadding: 9, fontSize: 11))
                        .accessibilityIdentifier("onboarding.browsers.addCustomBrowser")
                    }
                } else {
                    Text(String(format: NSLocalizedString("overview.browserCount", comment: "Browser ready count"), Int64(model.usableBrowsers.count)))
                        .font(.system(size: 11.5))
                        .foregroundStyle(SettingsPalette.muted)
                        .accessibilityIdentifier("onboarding.browsers.readyCount")
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)

            hairline

            // Row 3: Launch at Login
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Open Prism at login"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(SettingsPalette.primary)
                    Text(LocalizedStringKey("onboarding.v3.setup.login.detail"))
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Toggle("Open Prism at login", isOn: Binding(
                    get: { model.loginItemState == .enabled },
                    set: { enabled in Task { await model.setLaunchAtLogin(enabled) } }
                ))
                .labelsHidden()
                .toggleStyle(WorkspaceToggleStyle())
                .disabled(!model.hasLoginItemService || model.isUpdatingLoginItem)
                .accessibilityIdentifier("onboarding.setup.launchAtLogin")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
        }
        .frame(maxWidth: 344)
        .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SettingsPalette.borderStrong, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
    }

    private var handlerDetailSummary: String {
        if model.isCheckingHandlers {
            return NSLocalizedString("Checking…", comment: "Checking handler")
        }
        if model.isDefaultHandlerActive {
            return NSLocalizedString("HTTP + HTTPS active", comment: "Both active")
        }
        if !model.handlerStatusIsKnown {
            return NSLocalizedString("onboarding.v3.setup.handler.required", comment: "Required handler")
        }
        let missing = [model.httpHandlerIsActive ? nil : "HTTP", model.httpsHandlerIsActive ? nil : "HTTPS"].compactMap { $0 }
        return String(format: NSLocalizedString("onboarding.v3.setup.handler.pending", comment: "Pending schemes"), missing.joined(separator: " & "))
    }

    private var browsersSubtitle: String {
        if model.usableBrowsers.isEmpty {
            return NSLocalizedString("No browsers are ready yet", comment: "No browsers")
        }
        let names = model.usableBrowsers.prefix(4).map(\.displayName)
        return names.joined(separator: " · ")
    }

    // MARK: - Stage 5: Completion & Shortcuts Card

    private var completionShortcutsStageCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Prism")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(SettingsPalette.primary)
                    Text(LocalizedStringKey("onboarding.v3.ready.shortcutsSubtitle"))
                        .font(.system(size: 11))
                        .foregroundStyle(SettingsPalette.muted)
                }
                Spacer(minLength: 8)
                Text(LocalizedStringKey(model.testLinkWasAccepted ? "onboarding.v3.ready.badgeVerified" : "Ready"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.green)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)

            hairline
            shortcutRow(labelKey: "onboarding.v3.ready.shortcut.pick", key: "1–9")
            hairline
            shortcutRow(labelKey: "onboarding.v3.ready.shortcut.dismiss", key: "Esc")
            hairline
            shortcutRow(labelKey: "onboarding.v3.ready.shortcut.settings", key: "⌘,")
        }
        .frame(maxWidth: 344)
        .background(SettingsPalette.group, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SettingsPalette.borderStrong, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
    }

    private func shortcutRow(labelKey: String, key: String) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey))
                .font(.system(size: 12))
                .foregroundStyle(SettingsPalette.secondary)
            Spacer(minLength: 8)
            stageKeycap(key)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private func stageKeycap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(SettingsPalette.muted)
            .padding(.horizontal, 5.5)
            .padding(.vertical, 2)
            .background(OnboardingPalette.subtleFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(SettingsPalette.borderStrong, lineWidth: 1)
            }
    }

    // MARK: - Persistent Footer

    private var footerBar: some View {
        HStack(spacing: 12) {
            if model.step != .welcome {
                Button {
                    model.goBack()
                } label: {
                    Text(LocalizedStringKey("onboarding.v3.back"))
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 32, horizontalPadding: 4, fontSize: 12.5))
                .disabled(!model.canNavigateSteps)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("onboarding.back")
            }

            Spacer(minLength: 8)

            if model.step != .welcome && model.step != .testLink {
                Button {
                    Task { await model.skipCurrentStep() }
                } label: {
                    Text(LocalizedStringKey("onboarding.v3.skip"))
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet, height: 32, horizontalPadding: 6, fontSize: 12.5))
                .disabled(!model.canNavigateSteps)
                .accessibilityIdentifier("onboarding.skip")
            }

            Button {
                performPrimaryAction()
            } label: {
                Text(LocalizedStringKey(primaryActionTitleKey))
                    .frame(minWidth: 76)
            }
            .buttonStyle(WorkspaceButtonStyle(kind: .primary, height: 32, horizontalPadding: 16, fontSize: 12.5))
            .disabled(model.isTestLinkPreparing)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(primaryActionAccessibilityIdentifier)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
    }

    private var primaryActionTitleKey: String {
        switch model.step {
        case .welcome: "Start Setup"
        case .presentationStyle, .routingRules, .linkHandling: "Continue"
        case .testLink: model.completionSaveIsPending ? "Retry Saving Setup" : "Start Using Prism"
        }
    }

    private var primaryActionAccessibilityIdentifier: String {
        switch model.step {
        case .welcome: "onboarding.welcome.continue"
        case .presentationStyle: "onboarding.style.continue"
        case .routingRules: "onboarding.rules.continue"
        case .linkHandling: "onboarding.linkHandling.continue"
        case .testLink: model.completionSaveIsPending ? "onboarding.testLink.retryCompletionSave" : "onboarding.testLink.finish"
        }
    }

    private func performPrimaryAction() {
        Task {
            switch model.step {
            case .welcome:
                await model.advanceFromWelcome()
            case .presentationStyle:
                model.advanceFromPresentationStyle()
            case .routingRules:
                await model.advanceFromRoutingRules()
            case .linkHandling:
                await model.advanceFromLinkHandling()
            case .testLink:
                await model.finishSetup()
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(SettingsPalette.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct OnboardingDotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            let dotColor = SettingsPalette.borderStrong.opacity(0.28)
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    let rect = CGRect(x: x - 0.65, y: y - 0.65, width: 1.3, height: 1.3)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += step
                }
                y += step
            }
        }
    }
}

private enum OnboardingPalette {
    static let brandLime = adaptive(light: 0x5DB800, dark: 0x84F700)
    static let stageBackground = adaptive(light: 0xF4F4F6, dark: 0x1E1E21)
    static let subtleFill = adaptive(light: 0xF7F7F9, dark: 0x262629)
    static let subtleHover = adaptive(light: 0xEFEFF2, dark: 0x2E2E32)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }))
    }
}
