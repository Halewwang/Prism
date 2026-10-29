import Foundation
import Testing
@testable import PrismCore

@Test func selectorPresentationDefaultsRemainCompact() throws {
    #expect(try settingsPayload(AppSettings.defaults)["selectorPresentationMode"] as? String == "compact")
}

@Test func legacySettingsDecodeWithCompactSelector() throws {
    var payload = try settingsPayload(AppSettings.defaults)
    payload.removeValue(forKey: "selectorPresentationMode")

    let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: payload))

    #expect(try settingsPayload(settings)["selectorPresentationMode"] as? String == "compact")
    #expect(settings == AppSettings.defaults)
}

@Test func previewSelectorSettingRoundTripsWithoutChangingOtherSettings() throws {
    var original = AppSettings.defaults
    original.historyLimit = 333
    original.lastUsedBrowserID = "com.apple.Safari"
    var payload = try settingsPayload(original)
    payload["selectorPresentationMode"] = "preview"

    let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: payload))

    #expect(try settingsPayload(settings)["selectorPresentationMode"] as? String == "preview")
    #expect(settings.historyLimit == original.historyLimit)
    #expect(settings.lastUsedBrowserID == original.lastUsedBrowserID)
    #expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)) == settings)
}

@Test func unknownSelectorPresentationModeFallsBackToCompact() throws {
    var payload = try settingsPayload(AppSettings.defaults)
    payload["selectorPresentationMode"] = "future-mode"
    payload["historyLimit"] = 333

    let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: payload))

    #expect(try settingsPayload(settings)["selectorPresentationMode"] as? String == "compact")
    #expect(settings.historyLimit == 333)
}

private func settingsPayload(_ settings: AppSettings) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
}
