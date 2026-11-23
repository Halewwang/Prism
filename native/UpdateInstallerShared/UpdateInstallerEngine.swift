import Foundation

struct InstallerParentIdentity: Codable, Sendable, Equatable {
    let pid: Int32
    let startTime: String
    let executablePath: String
    let userID: UInt32
}

enum InstallerParentState: Sendable { case running, exited, reused }

struct UpdateInstallationPlan: Codable, Sendable {
    let id: UUID
    var workspaceURL: URL
    var applicationURL: URL
    var targetURL: URL
    let version: String
    let parent: InstallerParentIdentity
    var installerFileURL: URL? = nil
    // Missing in plans from older apps; only explicit true grants this exception.
    var allowUnnotarizedPublicTestUpdate: Bool? = nil
    var controlURL: URL { workspaceURL.appendingPathComponent("installation-\(id.uuidString)") }
    var readyURL: URL { controlURL.appendingPathComponent("ready") }
    var commitURL: URL { controlURL.appendingPathComponent("commit") }
    var cancelURL: URL { controlURL.appendingPathComponent("cancel") }
    var receiptURL: URL { controlURL.appendingPathComponent("receipt.json") }
    var stageURL: URL { targetURL.deletingLastPathComponent().appendingPathComponent(".Prism-update-\(id.uuidString).app") }
    var backupURL: URL { targetURL.deletingLastPathComponent().appendingPathComponent(".Prism-backup-\(id.uuidString).app") }
}

struct UpdateInstallationReceipt: Codable, Sendable {
    enum Status: String, Codable, Sendable { case installed, cancelled, failed, rolledBack, recoveryRequired }
    let status: Status
    let message: String
    let version: String
    let date: Date
}

protocol UpdateInstallerOperations: Sendable {
    func validateApplication(_ url: URL, expectedVersion: String?) throws
    func validateParent(_ expected: InstallerParentIdentity, targetURL: URL) throws
    func applicationFingerprint(_ url: URL) throws -> Data
    func validateUpgrade(_ version: String, currentURL: URL) throws
    func parentState(_ expected: InstallerParentIdentity) -> InstallerParentState
    func copyApplication(from: URL, to: URL) throws
    func moveItem(from: URL, to: URL) throws
    func launch(_ url: URL) async throws
    func signalReady(_ plan: UpdateInstallationPlan) throws
    func isCancelled(_ plan: UpdateInstallationPlan) -> Bool
    func isCommitted(_ plan: UpdateInstallationPlan) -> Bool
    func writeReceipt(_ receipt: UpdateInstallationReceipt, plan: UpdateInstallationPlan) throws
}

enum UpdateInstallationError: Error, LocalizedError {
    case unsafePath, invalidApplication, invalidVersion, parentMismatch, notWritable, helperUnavailable, helperFailed(String), handshakeTimedOut
    var errorDescription: String? {
        switch self {
        case .unsafePath:
            String(localized: "update.install.error.unsafePath", defaultValue: "This application location does not support automatic updates. Move Prism into a writable Applications folder.")
        case .invalidApplication:
            String(localized: "update.install.error.invalidApplication", defaultValue: "The update package's identity, system requirements, or code signature is invalid.")
        case .invalidVersion:
            String(localized: "update.install.error.invalidVersion", defaultValue: "The update package version is not newer than the current version.")
        case .parentMismatch:
            String(localized: "update.install.error.parentMismatch", defaultValue: "The running application does not match the installation target. Update cancelled.")
        case .notWritable:
            String(localized: "update.install.error.notWritable", defaultValue: "Prism does not have write permission for the application folder. Please install manually.")
        case .helperUnavailable:
            String(localized: "update.install.error.helperUnavailable", defaultValue: "The update helper is missing or invalid. Please install manually.")
        case .helperFailed(let message): message
        case .handshakeTimedOut:
            String(localized: "update.install.error.handshakeTimedOut", defaultValue: "Timed out preparing the installation. Prism remains running; please retry or install manually.")
        }
    }
}

/// The only replacement transaction. All destructive operations occur after the
/// exact original parent exits; a reused PID is cancellation, never permission.
struct UpdateInstallerEngine: Sendable {
    let operations: any UpdateInstallerOperations
    var waitTimeout: TimeInterval = 60
    var pollInterval: TimeInterval = 0.1

    func run(_ plan: UpdateInstallationPlan) async -> UpdateInstallationReceipt {
        let files = FileManager.default
        var backupMade = false
        var replacementMade = false
        var stageOwned = false
        var receipt: UpdateInstallationReceipt
        do {
            try validatePaths(plan)
            let targetFingerprint = try operations.applicationFingerprint(plan.targetURL)
            try operations.validateParent(plan.parent, targetURL: plan.targetURL)
            guard try operations.applicationFingerprint(plan.targetURL) == targetFingerprint else { throw UpdateInstallationError.invalidApplication }
            try operations.validateUpgrade(plan.version, currentURL: plan.targetURL)
            let targetIdentity = try directoryIdentity(plan.targetURL)
            try operations.validateApplication(plan.targetURL, expectedVersion: nil)
            try operations.validateApplication(plan.applicationURL, expectedVersion: plan.version)
            guard !operations.isCancelled(plan) else { throw InstallerCancellation() }
            guard !files.fileExists(atPath: plan.stageURL.path), !files.fileExists(atPath: plan.backupURL.path) else { throw UpdateInstallationError.unsafePath }
            stageOwned = true
            try operations.copyApplication(from: plan.applicationURL, to: plan.stageURL)
            try operations.validateApplication(plan.stageURL, expectedVersion: plan.version)
            try validatePaths(plan)
            try operations.signalReady(plan)

            let deadline = Date().addingTimeInterval(waitTimeout)
            while true {
                if operations.isCancelled(plan) { throw InstallerCancellation() }
                switch operations.parentState(plan.parent) {
                case .exited: break
                case .reused: throw InstallerCancellation()
                case .running:
                    guard Date() < deadline else { throw InstallerCancellation() }
                    try await Task.sleep(for: .seconds(pollInterval))
                    continue
                }
                break
            }
            guard operations.isCommitted(plan) else { throw InstallerCancellation() }
            guard try directoryIdentity(plan.targetURL) == targetIdentity else { throw UpdateInstallationError.unsafePath }
            // Recheck after waiting so a changed target or symlink cannot reuse
            // earlier validation to redirect the replacement.
            try validatePaths(plan)
            try operations.validateApplication(plan.targetURL, expectedVersion: nil)
            try operations.validateApplication(plan.stageURL, expectedVersion: plan.version)
            guard try operations.applicationFingerprint(plan.targetURL) == targetFingerprint else { throw UpdateInstallationError.invalidApplication }
            try operations.validateUpgrade(plan.version, currentURL: plan.targetURL)
            guard !operations.isCancelled(plan) else { throw InstallerCancellation() }
            if plan.allowUnnotarizedPublicTestUpdate == true {
                // The helper has independently verified the signed archive and
                // this staged app. The exception applies only to this replacement.
                _ = try InstallerSystem.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", plan.stageURL.path])
            }
            try operations.moveItem(from: plan.targetURL, to: plan.backupURL)
            backupMade = true
            try operations.moveItem(from: plan.stageURL, to: plan.targetURL)
            replacementMade = true
            try await operations.launch(plan.targetURL)
            // A successful LaunchServices request is not a functional health check.
            try? files.removeItem(at: plan.backupURL)
            backupMade = false
            receipt = result(
                .installed,
                String(localized: "update.install.receipt.installed", defaultValue: "The new version has launched."),
                plan
            )
        } catch {
            if backupMade {
                do {
                    if replacementMade { try files.removeItem(at: plan.targetURL) }
                    try operations.moveItem(from: plan.backupURL, to: plan.targetURL)
                    backupMade = false
                    try? await operations.launch(plan.targetURL)
                    receipt = result(
                        .rolledBack,
                        String(
                            format: String(localized: "update.install.receipt.rolledBack", defaultValue: "Update failed and the previous version was restored: %@"),
                            error.localizedDescription
                        ),
                        plan
                    )
                } catch {
                    // Preserve the backup if recovery itself fails. Never delete
                    // the user's last valid copy during error cleanup.
                    receipt = result(
                        .recoveryRequired,
                        String(
                            format: String(localized: "update.install.receipt.recoveryRequired", defaultValue: "Update failed. The previous app is preserved at %@ for manual recovery: %@"),
                            plan.backupURL.path,
                            error.localizedDescription
                        ),
                        plan
                    )
                }
            } else if error is InstallerCancellation || error is CancellationError {
                receipt = result(
                    .cancelled,
                    String(localized: "update.install.receipt.cancelled", defaultValue: "Update cancelled. The current application remains unchanged."),
                    plan
                )
            } else {
                receipt = result(.failed, error.localizedDescription, plan)
            }
        }
        if stageOwned { try? files.removeItem(at: plan.stageURL) }
        try? operations.writeReceipt(receipt, plan: plan)
        return receipt
    }

    private func result(_ status: UpdateInstallationReceipt.Status, _ message: String, _ plan: UpdateInstallationPlan) -> UpdateInstallationReceipt {
        .init(status: status, message: message, version: plan.version, date: Date())
    }

    private func validatePaths(_ plan: UpdateInstallationPlan) throws {
        let files = FileManager.default
        for url in [plan.workspaceURL, plan.applicationURL, plan.targetURL] {
            guard url.isFileURL, url.path == url.standardizedFileURL.path,
                  !url.pathComponents.contains("AppTranslocation"),
                  !url.pathComponents.contains("Volumes") else { throw UpdateInstallationError.unsafePath }
            // /tmp and /var are system aliases; callers must pass resolved URLs.
            guard url.path == url.resolvingSymlinksInPath().path else { throw UpdateInstallationError.unsafePath }
        }
        let workspacePrefix = plan.workspaceURL.path + "/"
        guard plan.applicationURL.path.hasPrefix(workspacePrefix),
              plan.targetURL.lastPathComponent == "Prism.app",
              !plan.targetURL.path.hasPrefix(workspacePrefix),
              files.fileExists(atPath: plan.targetURL.path),
              files.fileExists(atPath: plan.applicationURL.path) else { throw UpdateInstallationError.unsafePath }
        let parent = plan.targetURL.deletingLastPathComponent()
        let values = try parent.resourceValues(forKeys: [.volumeIsReadOnlyKey, .isDirectoryKey])
        guard values.isDirectory == true, values.volumeIsReadOnly != true,
              files.isWritableFile(atPath: parent.path), files.isWritableFile(atPath: plan.targetURL.path) else { throw UpdateInstallationError.notWritable }
        try validateContainedLinks(in: plan.applicationURL)
        try validateContainedLinks(in: plan.targetURL)
        if files.fileExists(atPath: plan.stageURL.path) { try validateContainedLinks(in: plan.stageURL) }
    }

    private func directoryIdentity(_ url: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return "\(attributes[.systemNumber] ?? ""):\(attributes[.systemFileNumber] ?? "")"
    }

    private func validateContainedLinks(in root: URL) throws {
        let standardizedRoot = root.standardizedFileURL
        let rootValues = try standardizedRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true,
              let enumerator = FileManager.default.enumerator(at: standardizedRoot, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [])
        else { throw UpdateInstallationError.unsafePath }
        let canonicalRoot = standardizedRoot.resolvingSymlinksInPath().path + "/"
        for case let entry as URL in enumerator {
            if try entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                guard entry.resolvingSymlinksInPath().path.hasPrefix(canonicalRoot) else {
                    throw UpdateInstallationError.unsafePath
                }
            }
        }
    }
}

private struct InstallerCancellation: Error { }
