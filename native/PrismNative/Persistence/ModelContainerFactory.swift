import Foundation
import PrismCore
import SwiftData

struct ModelContainerResult {
    let container: ModelContainer
    let warning: PersistenceWarning?
}

@MainActor
enum ModelContainerFactory {
    static func make(inMemory: Bool) throws -> ModelContainerResult {
        try make(inMemory: inMemory, storeURL: nil, simulatedOpenFailures: 0)
    }

    static func makeForTesting(
        inMemory: Bool,
        storeURL: URL
    ) throws -> ModelContainerResult {
        try make(
            inMemory: inMemory,
            storeURL: storeURL,
            simulatedOpenFailures: 0
        )
    }

    static func makeForTesting(
        inMemory: Bool,
        storeURL: URL,
        simulatedOpenFailures: Int
    ) throws -> ModelContainerResult {
        try make(
            inMemory: inMemory,
            storeURL: storeURL,
            simulatedOpenFailures: simulatedOpenFailures
        )
    }

    private static func make(
        inMemory: Bool,
        storeURL: URL?,
        simulatedOpenFailures: Int
    ) throws -> ModelContainerResult {
        let resolvedStoreURL = inMemory ? nil : try storeURL ?? persistentStoreURL()
        var remainingSimulatedOpenFailures = simulatedOpenFailures
        let openContainer = {
            if remainingSimulatedOpenFailures > 0 {
                remainingSimulatedOpenFailures -= 1
                throw ModelContainerFactoryError.simulatedOpenFailure
            }
            return try newContainer(inMemory: inMemory, storeURL: resolvedStoreURL)
        }

        do {
            return ModelContainerResult(
                container: try openContainer(),
                warning: nil
            )
        } catch {
            guard !inMemory, let resolvedStoreURL, shouldRecoverByBackingUpStore(after: error) else {
                throw error
            }

            let backupDirectory = try backupStoreArtifacts(at: resolvedStoreURL)
            let container = try openContainer()
            try seedSafeSettings(in: container)
            return ModelContainerResult(
                container: container,
                warning: .corruptStoreRecovered(backupLocation: backupDirectory.path)
            )
        }
    }

    private static func newContainer(inMemory: Bool, storeURL: URL?) throws -> ModelContainer {
        let schema = Schema([
            RuleRecord.self,
            HistoryRecord.self,
            CustomBrowserRecord.self,
            BrowserOrderRecord.self,
            SettingsRecord.self
        ])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL {
            configuration = ModelConfiguration("PrismNative", schema: schema, url: storeURL)
        } else {
            throw ModelContainerFactoryError.missingStoreURL
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func seedSafeSettings(in container: ModelContainer) throws {
        var settings = AppSettings.defaults
        settings.automaticRulesEnabled = false
        settings.unmatchedBehavior = .alwaysAsk
        settings.schemaVersion = 1
        let context = ModelContext(container)
        context.insert(SettingsRecord(settings: settings))
        try context.save()
    }

    private static func persistentStoreURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let prismDirectory = directory.appending(path: "Prism")
        try FileManager.default.createDirectory(at: prismDirectory, withIntermediateDirectories: true)
        return prismDirectory.appending(path: "PrismNative.store")
    }

    private static let maxRetainedBackups = 5

    private static func shouldRecoverByBackingUpStore(after error: Error) -> Bool {
        if let factoryError = error as? ModelContainerFactoryError {
            return factoryError == .simulatedOpenFailure
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let nonCorruptionCodes: Set<Int> = [
                NSFileReadNoPermissionError,
                NSFileWriteNoPermissionError,
                NSFileWriteOutOfSpaceError,
                NSFileWriteVolumeReadOnlyError,
            ]
            if nonCorruptionCodes.contains(nsError.code) {
                return false
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            let nonCorruptionPOSIX: Set<Int> = [
                Int(EACCES),
                Int(EPERM),
                Int(ENOSPC),
                Int(EROFS),
                Int(EMFILE),
                Int(ENFILE),
            ]
            if nonCorruptionPOSIX.contains(nsError.code) {
                return false
            }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           !shouldRecoverByBackingUpStore(after: underlying) {
            return false
        }
        return true
    }

    private static func backupStoreArtifacts(at storeURL: URL) throws -> URL {
        let backupRoot = storeURL.deletingLastPathComponent()
            .appending(path: "CorruptDataBackup")
        let backupDirectory = backupRoot.appending(path: uniqueBackupFolderName())
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let artifacts = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for artifact in artifacts where fileManager.fileExists(atPath: artifact.path) {
            try fileManager.moveItem(at: artifact, to: backupDirectory.appending(path: artifact.lastPathComponent))
        }
        pruneOldBackups(in: backupRoot, keepingMostRecent: maxRetainedBackups)
        return backupDirectory
    }

    private static func pruneOldBackups(in backupRoot: URL, keepingMostRecent limit: Int) {
        guard limit > 0,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: backupRoot,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              )
        else { return }
        let sorted = entries.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in sorted.dropFirst(limit) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private static func uniqueBackupFolderName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = String(UUID().uuidString.prefix(8))
        return "\(formatter.string(from: Date()))-\(suffix)"
    }
}

private enum ModelContainerFactoryError: Error {
    case missingStoreURL
    case simulatedOpenFailure
}
