import Foundation
import PrismCore
import SwiftData

@Model
final class SettingsRecord {
    @Attribute(.unique) var key: String
    var language: String
    var unmatchedBehavior: String
    var selectorPresentationMode: String? = nil
    var linkPreviewPositionMode: String? = nil
    var preferredBrowserID: String?
    var lastUsedBrowserID: String?
    var historyEnabled: Bool
    var historyLimit: Int
    var historyRetentionDays: Int
    var automaticRulesEnabled: Bool
    var showMenuBarItem: Bool
    var hideDockIcon: Bool? = nil
    var onboardingCompleted: Bool
    var schemaVersion: Int

    init(settings: AppSettings) {
        key = "current"
        language = settings.language.rawValue
        unmatchedBehavior = settings.unmatchedBehavior.rawValue
        selectorPresentationMode = settings.selectorPresentationMode.rawValue
        linkPreviewPositionMode = settings.linkPreviewPositionMode.rawValue
        preferredBrowserID = settings.preferredBrowserID?.rawValue
        lastUsedBrowserID = settings.lastUsedBrowserID?.rawValue
        historyEnabled = settings.historyEnabled
        historyLimit = settings.historyLimit
        historyRetentionDays = settings.historyRetentionDays
        automaticRulesEnabled = settings.automaticRulesEnabled
        showMenuBarItem = settings.showMenuBarItem
        hideDockIcon = settings.hideDockIcon
        onboardingCompleted = settings.onboardingCompleted
        schemaVersion = 1
    }

    func appSettings() throws -> AppSettings {
        guard schemaVersion == 1,
              let language = AppLanguage(rawValue: language),
              let unmatchedBehavior = UnmatchedBehavior(rawValue: unmatchedBehavior) else {
            throw PersistenceRecordError.invalidPayload
        }

        return AppSettings(
            language: language,
            unmatchedBehavior: unmatchedBehavior,
            preferredBrowserID: preferredBrowserID.map(BrowserID.init(rawValue:)),
            lastUsedBrowserID: lastUsedBrowserID.map(BrowserID.init(rawValue:)),
            historyEnabled: historyEnabled,
            historyLimit: historyLimit,
            historyRetentionDays: historyRetentionDays,
            automaticRulesEnabled: automaticRulesEnabled,
            showMenuBarItem: showMenuBarItem,
            onboardingCompleted: onboardingCompleted,
            schemaVersion: 1,
            selectorPresentationMode: selectorPresentationMode.flatMap(SelectorPresentationMode.init(rawValue:)) ?? .compact,
            linkPreviewPositionMode: linkPreviewPositionMode.flatMap(LinkPreviewPositionMode.init(rawValue:)) ?? .followMouse,
            hideDockIcon: hideDockIcon ?? false
        )
    }

    func replace(with settings: AppSettings) {
        language = settings.language.rawValue
        unmatchedBehavior = settings.unmatchedBehavior.rawValue
        selectorPresentationMode = settings.selectorPresentationMode.rawValue
        linkPreviewPositionMode = settings.linkPreviewPositionMode.rawValue
        preferredBrowserID = settings.preferredBrowserID?.rawValue
        lastUsedBrowserID = settings.lastUsedBrowserID?.rawValue
        historyEnabled = settings.historyEnabled
        historyLimit = settings.historyLimit
        historyRetentionDays = settings.historyRetentionDays
        automaticRulesEnabled = settings.automaticRulesEnabled
        showMenuBarItem = settings.showMenuBarItem
        hideDockIcon = settings.hideDockIcon
        onboardingCompleted = settings.onboardingCompleted
        schemaVersion = 1
    }
}
