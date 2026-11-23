import Foundation
import Testing
@testable import PrismCore

@Test func routingRuleRoundTripsWithoutLosingPriority() throws {
    let rule = RoutingRule(
        id: UUID(uuidString: "2A50BE99-7BA5-4F41-9B8C-1849D704B631")!,
        isEnabled: true,
        matcher: .hostAndSubdomains("company.com"),
        targetBrowserID: BrowserID("com.apple.Safari"),
        priority: 3,
        label: "Company links",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2)
    )

    let data = try JSONEncoder().encode(rule)
    let decoded = try JSONDecoder().decode(RoutingRule.self, from: data)

    #expect(decoded == rule)
    #expect(decoded.priority == 3)
}

@Test func routingRuleDefaultsValidationStateToValid() {
    let rule = RoutingRule(
        id: .test(1),
        isEnabled: true,
        matcher: .exactHost("example.com"),
        targetBrowserID: "com.apple.Safari",
        priority: 1,
        label: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2)
    )

    #expect(rule.validationState == .valid)
}

@Test func linkRequestDefaultsToQueuedWithoutStoredSelectionOrHistoryReference() {
    let request = LinkRequest(
        id: .test(1),
        url: URL(string: "https://example.com")!,
        receivedAt: Date(timeIntervalSince1970: 1),
        source: .unknown
    )

    #expect(request.state == .queued)
    #expect(request.attemptCount == 0)
    #expect(request.lastAttemptedBrowserID == nil)
    #expect(request.reopenedFromHistoryEntryID == nil)
}

@Test func appSettingsDefaultsMatchTheApprovedPlan() {
    let settings = AppSettings.defaults

    #expect(settings.language == .system)
    #expect(settings.unmatchedBehavior == .alwaysAsk)
    #expect(settings.preferredBrowserID == nil)
    #expect(settings.lastUsedBrowserID == nil)
    #expect(settings.historyEnabled)
    #expect(settings.historyLimit == 100)
    #expect(settings.historyRetentionDays == 30)
    #expect(settings.automaticRulesEnabled)
    #expect(settings.showMenuBarItem)
    #expect(!settings.hideDockIcon)
    #expect(!settings.onboardingCompleted)
    #expect(settings.schemaVersion == 1)
}

@Test func processingHistoryEntryCopiesStableRequestContext() {
    let request = LinkRequest(
        id: .test(1),
        url: URL(string: "https://example.com/original")!,
        receivedAt: Date(timeIntervalSince1970: 7),
        source: SourceApplication(
            bundleIdentifier: "com.example.Source",
            displayName: "Source App",
            confidence: .confirmed
        ),
        attemptCount: 2
    )
    let sanitizedURL = URL(string: "https://example.com/sanitized")!

    let entry = HistoryEntry.processing(request: request, sanitizedURL: sanitizedURL)

    #expect(entry.requestID == request.id)
    #expect(entry.sanitizedURL == sanitizedURL)
    #expect(entry.sourceBundleIdentifier == "com.example.Source")
    #expect(entry.sourceDisplayName == "Source App")
    #expect(entry.createdAt == request.receivedAt)
    #expect(entry.attemptCount == 2)
    #expect(entry.result == .processing)
    #expect(entry.targetBrowserID == nil)
    #expect(entry.method == nil)
    #expect(entry.matchingRuleID == nil)
    #expect(entry.failureReason == nil)
    #expect(entry.completedAt == nil)
}

@Test func browserDescriptorRoundTripsThroughCodable() throws {
    let descriptor = BrowserDescriptor(
        id: "com.apple.Safari",
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari",
        applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
        securityScopedBookmark: Data([0, 1, 2]),
        origin: .system,
        availability: .available,
        selectorOrder: 1
    )

    let data = try JSONEncoder().encode(descriptor)
    let decoded = try JSONDecoder().decode(BrowserDescriptor.self, from: data)

    #expect(decoded == descriptor)
}

@Test func linkRequestAndSnapshotRoundTripThroughCodable() throws {
    let request = LinkRequest(
        id: .test(1),
        url: URL(string: "https://example.com/work")!,
        receivedAt: Date(timeIntervalSince1970: 3),
        source: SourceApplication(
            bundleIdentifier: "com.example.Source",
            displayName: "Source App",
            confidence: .confirmed
        ),
        state: .launching,
        attemptCount: 2,
        lastAttemptedBrowserID: "com.apple.Safari",
        reopenedFromHistoryEntryID: .test(4)
    )
    let terminalRecord = TerminalRequestRecord(
        requestID: .test(5),
        outcome: .cancelled,
        historyEntry: .cancelledFixture,
        completedAt: Date(timeIntervalSince1970: 6)
    )
    let snapshot = PendingRequestSnapshot(
        pendingRequests: [request],
        terminalRecords: [terminalRecord]
    )

    let requestData = try JSONEncoder().encode(request)
    let decodedRequest = try JSONDecoder().decode(LinkRequest.self, from: requestData)
    let snapshotData = try JSONEncoder().encode(snapshot)
    let decodedSnapshot = try JSONDecoder().decode(PendingRequestSnapshot.self, from: snapshotData)

    #expect(decodedRequest == request)
    #expect(decodedSnapshot == snapshot)
}

@Test func historyEntryRoundTripsThroughCodable() throws {
    let entry = HistoryEntry(
        id: .test(1),
        requestID: .test(2),
        sanitizedURL: URL(string: "https://example.com/history")!,
        sourceBundleIdentifier: "com.example.Source",
        sourceDisplayName: "Source App",
        targetBrowserID: "com.apple.Safari",
        targetDisplayName: "Safari",
        method: .urlRule,
        result: .success,
        matchingRuleID: .test(3),
        failureReason: nil,
        attemptCount: 1,
        createdAt: Date(timeIntervalSince1970: 4),
        completedAt: Date(timeIntervalSince1970: 5)
    )

    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)

    #expect(decoded == entry)
}

@Test func appSettingsRoundTripsThroughCodable() throws {
    let settings = AppSettings(
        language: .simplifiedChinese,
        unmatchedBehavior: .preferredBrowser,
        preferredBrowserID: "com.apple.Safari",
        lastUsedBrowserID: "com.google.Chrome",
        historyEnabled: false,
        historyLimit: 50,
        historyRetentionDays: 14,
        automaticRulesEnabled: false,
        showMenuBarItem: false,
        onboardingCompleted: true,
        schemaVersion: 2
    )

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(decoded == settings)
}

@Test func browserDescriptorPreservesProfileMetadataAndLegacyTargets() throws {
    let legacy = BrowserDescriptor(
        id: "com.google.Chrome", bundleIdentifier: "com.google.Chrome", displayName: "Chrome",
        applicationURL: URL(fileURLWithPath: "/Applications/Chrome.app"), securityScopedBookmark: nil,
        origin: .system, availability: .available, selectorOrder: 0
    )
    let legacyData = try JSONEncoder().encode(legacy)
    #expect(try JSONDecoder().decode(BrowserDescriptor.self, from: legacyData) == legacy)
    var payload = try #require(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
    payload["profile"] = [
        "directoryName": "Profile 1", "displayName": "工作",
        "userDataDirectory": "file:///tmp/prism-profile-fixture/"
    ]
    let profiled = try JSONDecoder().decode(BrowserDescriptor.self, from: JSONSerialization.data(withJSONObject: payload))
    let roundTrip = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(profiled)) as? [String: Any])
    let profile = try #require(roundTrip["profile"] as? [String: Any])
    #expect(profile["directoryName"] as? String == "Profile 1")
    #expect(profile["displayName"] as? String == "工作")
}

@Test func browserDescriptorSupportsAlternateNamesAndLegacyJSON() throws {
    let base = BrowserDescriptor(
        id: "com.google.Chrome",
        bundleIdentifier: "com.google.Chrome",
        displayName: "Google Chrome",
        applicationURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
        securityScopedBookmark: nil,
        origin: .system,
        availability: .available,
        selectorOrder: 0
    )
    #expect(base.displayName == "Google Chrome")
    #expect(base.originalDisplayName == "Google Chrome")
    #expect(base.alternateName == nil)
    #expect(!base.hasAlternateName)
    #expect(base.tooltipDisplayName == "Google Chrome")

    let renamed = base.withAlternateName("  Work\nAccount  ")
    #expect(renamed.displayName == "Work Account")
    #expect(renamed.originalDisplayName == "Google Chrome")
    #expect(renamed.alternateName == "Work Account")
    #expect(renamed.hasAlternateName)
    #expect(renamed.tooltipDisplayName == "Work Account (Google Chrome)")

    let roundTripped = try JSONDecoder().decode(BrowserDescriptor.self, from: JSONEncoder().encode(renamed))
    #expect(roundTripped == renamed)

    let cleared = renamed.withAlternateName("   ")
    #expect(cleared.displayName == "Google Chrome")
    #expect(cleared.originalDisplayName == "Google Chrome")
    #expect(cleared.alternateName == nil)
    #expect(!cleared.hasAlternateName)

    let truncated = base.withAlternateName(String(repeating: "A", count: 80))
    #expect(truncated.alternateName?.count == BrowserDescriptor.maxAlternateNameLength)

    let legacyJSON = Data("""
    {
      "id": "com.apple.Safari",
      "bundleIdentifier": "com.apple.Safari",
      "displayName": "Safari",
      "applicationURL": "file:///Applications/Safari.app",
      "origin": "system",
      "availability": "available",
      "selectorOrder": 1
    }
    """.utf8)
    let legacyDecoded = try JSONDecoder().decode(BrowserDescriptor.self, from: legacyJSON)
    #expect(legacyDecoded.displayName == "Safari")
    #expect(legacyDecoded.originalDisplayName == "Safari")
    #expect(legacyDecoded.alternateName == nil)
}

@Test func appSettingsRoundTripsHideDockIconAndDefaultsLegacyJSONToFalse() throws {
    var settings = AppSettings.defaults
    settings.hideDockIcon = true
    let encoded = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)
    #expect(decoded.hideDockIcon == true)

    var payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    payload.removeValue(forKey: "hideDockIcon")
    let legacyDecoded = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: payload))
    #expect(legacyDecoded.hideDockIcon == false)
}
