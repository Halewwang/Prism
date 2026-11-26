import Foundation
import PrismCore
import Testing
@testable import PrismNative

@Suite("Selector presentation settings")
@MainActor
struct SelectorPresentationSettingsTests {
    @Test func legacyOrUnknownStoredModeUsesCompactWithoutDroppingOtherSettings() throws {
        var settings = AppSettings.defaults
        settings.historyLimit = 333
        let record = SettingsRecord(settings: settings)
        for storedMode in [nil, "future-mode"] {
            record.selectorPresentationMode = storedMode

            #expect(try record.appSettings() == settings)
        }
    }

    @Test func settingsRecordPreservesPreviewMode() throws {
        var settings = AppSettings.defaults
        settings.selectorPresentationMode = .preview
        settings.linkPreviewPositionMode = .lastClosedPosition

        let record = SettingsRecord(settings: settings)

        #expect(try record.appSettings() == settings)
    }

    @Test func legacyOrUnknownStoredPreviewPositionUsesFollowMouse() throws {
        var settings = AppSettings.defaults
        settings.selectorPresentationMode = .preview
        settings.historyLimit = 333
        let record = SettingsRecord(settings: settings)

        for storedPosition in [nil, "future-mode"] {
            record.linkPreviewPositionMode = storedPosition

            #expect(try record.appSettings() == settings)
        }
    }

    @Test func replacingSettingsRecordPersistsPresentationMode() throws {
        let record = SettingsRecord(settings: .defaults)
        var settings = AppSettings.defaults
        settings.selectorPresentationMode = .preview
        settings.linkPreviewPositionMode = .lastClosedPosition

        record.replace(with: settings)

        #expect(try record.appSettings() == settings)
    }

    @Test func previewPreferencesSurviveReopeningThePersistentStore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "settings.store")
        var settings = AppSettings.defaults
        settings.selectorPresentationMode = .preview
        settings.linkPreviewPositionMode = .lastClosedPosition
        settings.historyLimit = 333
        do {
            let result = try ModelContainerFactory.makeForTesting(inMemory: false, storeURL: storeURL)
            let repository = SwiftDataSettingsRepository(container: result.container)
            try repository.save(.defaults)
            try repository.save(settings)
        }

        let reopened = try ModelContainerFactory.makeForTesting(inMemory: false, storeURL: storeURL)

        #expect(reopened.warning == nil)
        #expect(try SwiftDataSettingsRepository(container: reopened.container).load() == settings)
    }

    @Test func modeMutationPreservesLatestDurableSettingsAndRollsBackFailedSave() throws {
        let repository = PresentationSettingsRepository()
        let environment = AppEnvironment(
            route: .settings,
            unmatchedBehavior: .alwaysAsk,
            updateChecker: DisabledUpdateChecker(),
            ruleRepository: InMemoryRuleRepository(),
            historyRepository: InMemoryHistoryRepository(),
            browserPreferenceRepository: InMemoryBrowserPreferenceRepository(),
            settingsRepository: repository
        )
        repository.settings.historyLimit = 333
        #expect(environment.mutateSettings { $0.selectorPresentationMode = .preview })
        #expect(environment.settings.historyLimit == 333)
        #expect(repository.settings.selectorPresentationMode == .preview)
        repository.failsSave = true

        #expect(!environment.mutateSettings { $0.selectorPresentationMode = .compact })

        #expect(environment.settings.selectorPresentationMode == .preview)
        #expect(repository.settings.selectorPresentationMode == .preview)
        #expect(environment.persistenceWarnings.contains(.settingsNotSaved))
    }

    @Test func wireframePickerOptionsPreserveCompactAndPreviewContract() {
        #expect(SelectorPresentationModeOption.all.map(\.mode) == [.compact, .preview])
        #expect(SelectorPresentationModeOption.all.map(\.title) == [
            "selector.presentation.compact",
            "selector.presentation.preview",
        ])
        #expect(SelectorPresentationModeOption.all.map(\.accessibilityIdentifier) == [
            "settings.selectorPresentationMode.compact",
            "settings.selectorPresentationMode.preview",
        ])
    }
}

@MainActor
private final class PresentationSettingsRepository: SettingsRepository {
    var settings = AppSettings.defaults
    var failsSave = false

    func load() throws -> AppSettings { settings }

    func save(_ settings: AppSettings) throws {
        if failsSave { throw NSError(domain: "SelectorPresentationSettingsTests", code: 1) }
        self.settings = settings
    }
}
