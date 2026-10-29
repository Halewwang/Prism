import Foundation

public enum UnmatchedBehavior: String, Codable, Equatable, Sendable {
    case alwaysAsk
    case preferredBrowser
    case lastUsedBrowser
}

public enum AppLanguage: String, Codable, Equatable, Sendable {
    case system
    case english
    case simplifiedChinese
}

public enum SelectorPresentationMode: String, Codable, Equatable, Sendable {
    case compact
    case preview
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var language: AppLanguage
    public var unmatchedBehavior: UnmatchedBehavior
    public var selectorPresentationMode: SelectorPresentationMode
    public var preferredBrowserID: BrowserID?
    public var lastUsedBrowserID: BrowserID?
    public var historyEnabled: Bool
    public var historyLimit: Int
    public var historyRetentionDays: Int
    public var automaticRulesEnabled: Bool
    public var showMenuBarItem: Bool
    public var onboardingCompleted: Bool
    public var schemaVersion: Int

    public init(
        language: AppLanguage,
        unmatchedBehavior: UnmatchedBehavior,
        preferredBrowserID: BrowserID?,
        lastUsedBrowserID: BrowserID?,
        historyEnabled: Bool,
        historyLimit: Int,
        historyRetentionDays: Int,
        automaticRulesEnabled: Bool,
        showMenuBarItem: Bool,
        onboardingCompleted: Bool,
        schemaVersion: Int,
        selectorPresentationMode: SelectorPresentationMode = .compact
    ) {
        self.language = language
        self.unmatchedBehavior = unmatchedBehavior
        self.selectorPresentationMode = selectorPresentationMode
        self.preferredBrowserID = preferredBrowserID
        self.lastUsedBrowserID = lastUsedBrowserID
        self.historyEnabled = historyEnabled
        self.historyLimit = historyLimit
        self.historyRetentionDays = historyRetentionDays
        self.automaticRulesEnabled = automaticRulesEnabled
        self.showMenuBarItem = showMenuBarItem
        self.onboardingCompleted = onboardingCompleted
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case language, unmatchedBehavior, selectorPresentationMode
        case preferredBrowserID, lastUsedBrowserID
        case historyEnabled, historyLimit, historyRetentionDays
        case automaticRulesEnabled, showMenuBarItem, onboardingCompleted, schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try values.decodeIfPresent(String.self, forKey: .selectorPresentationMode)
        self.init(
            language: try values.decode(AppLanguage.self, forKey: .language),
            unmatchedBehavior: try values.decode(UnmatchedBehavior.self, forKey: .unmatchedBehavior),
            preferredBrowserID: try values.decodeIfPresent(BrowserID.self, forKey: .preferredBrowserID),
            lastUsedBrowserID: try values.decodeIfPresent(BrowserID.self, forKey: .lastUsedBrowserID),
            historyEnabled: try values.decode(Bool.self, forKey: .historyEnabled),
            historyLimit: try values.decode(Int.self, forKey: .historyLimit),
            historyRetentionDays: try values.decode(Int.self, forKey: .historyRetentionDays),
            automaticRulesEnabled: try values.decode(Bool.self, forKey: .automaticRulesEnabled),
            showMenuBarItem: try values.decode(Bool.self, forKey: .showMenuBarItem),
            onboardingCompleted: try values.decode(Bool.self, forKey: .onboardingCompleted),
            schemaVersion: try values.decode(Int.self, forKey: .schemaVersion),
            selectorPresentationMode: mode.flatMap(SelectorPresentationMode.init(rawValue:)) ?? .compact
        )
    }

    public static let defaults = AppSettings(
        language: .system,
        unmatchedBehavior: .alwaysAsk,
        preferredBrowserID: nil,
        lastUsedBrowserID: nil,
        historyEnabled: true,
        historyLimit: 100,
        historyRetentionDays: 30,
        automaticRulesEnabled: true,
        showMenuBarItem: true,
        onboardingCompleted: false,
        schemaVersion: 1
    )
}
