import Foundation
import PrismCore

actor AtomicPendingRequestStore: PendingRequestStore, PersistenceWarningSource {
    private static let filename = "pending-requests-v1.json"
    private static let schemaVersion = 1

    private let directory: URL
    private var warnings: [PersistenceWarning] = []

    init(directory: URL) {
        self.directory = directory
    }

    static func makeDefault() throws -> AtomicPendingRequestStore {
        try AtomicPendingRequestStore(directory: defaultDirectory())
    }

    static func makeForTesting(
        resolvingDefaultDirectoryWith resolver: () throws -> URL
    ) throws -> AtomicPendingRequestStore {
        try AtomicPendingRequestStore(directory: resolver())
    }

    func load() async throws -> PendingRequestSnapshot {
        let fileURL = recoveryFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PendingRequestSnapshot(pendingRequests: [], terminalRecords: [])
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let envelope = try JSONDecoder().decode(RecoveryEnvelope.self, from: data)
            guard envelope.schemaVersion == Self.schemaVersion else {
                throw RecoveryStoreError.unsupportedSchema
            }
            return envelope.snapshot
        } catch {
            guard Self.shouldRecoverByBackingUpFile(after: error) else {
                throw error
            }
            let backupLocation = try preserveCorruptRecoveryFile(at: fileURL)
            let empty = PendingRequestSnapshot(pendingRequests: [], terminalRecords: [])
            try write(empty)
            warnings.append(.corruptStoreRecovered(backupLocation: backupLocation.path))
            return empty
        }
    }

    func save(_ snapshot: PendingRequestSnapshot) async throws {
        try write(snapshot)
    }

    func drainPersistenceWarnings() async -> [PersistenceWarning] {
        defer { warnings.removeAll() }
        return warnings
    }

    private var recoveryFileURL: URL {
        directory.appending(path: Self.filename)
    }

    private func write(_ snapshot: PendingRequestSnapshot) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = recoveryFileURL
        let temporary = directory.appending(path: ".\(Self.filename).\(UUID().uuidString).tmp")
        let data = try JSONEncoder().encode(RecoveryEnvelope(schemaVersion: Self.schemaVersion, snapshot: snapshot))
        guard fileManager.createFile(atPath: temporary.path, contents: data) else {
            throw RecoveryStoreError.temporaryFileCreationFailed
        }

        do {
            let handle = try FileHandle(forWritingTo: temporary)
            try handle.synchronize()
            try handle.close()

            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    private static let maxRetainedBackups = 5

    private static func shouldRecoverByBackingUpFile(after error: Error) -> Bool {
        if error is DecodingError {
            return true
        }
        if let storeError = error as? RecoveryStoreError {
            return storeError == .unsupportedSchema
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
           !shouldRecoverByBackingUpFile(after: underlying) {
            return false
        }
        return true
    }

    private func preserveCorruptRecoveryFile(at fileURL: URL) throws -> URL {
        let backupRoot = directory.appending(path: "CorruptRecoveryBackup")
        let backupDirectory = backupRoot.appending(path: Self.uniqueBackupFolderName())
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: fileURL, to: backupDirectory.appending(path: Self.filename))
        Self.pruneOldBackups(in: backupRoot, keepingMostRecent: Self.maxRetainedBackups)
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

    private static func defaultDirectory() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appending(path: "Prism")
            .appending(path: "Recovery")
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

private struct RecoveryEnvelope: Codable {
    let schemaVersion: Int
    let snapshot: PendingRequestSnapshot
}

private enum RecoveryStoreError: Error {
    case unsupportedSchema
    case temporaryFileCreationFailed
}
