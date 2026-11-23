import AppKit
import CoreServices
import Foundation

@MainActor
protocol WorkspaceClient {
    func applicationURLs(toOpen url: URL) -> [URL]
    func open(_ url: URL, with applicationURL: URL) async throws
    func openApplication(at applicationURL: URL, arguments: [String]) async throws
    func icon(for applicationURL: URL) -> NSImage
}

enum WorkspaceClientError: Error {
    case applicationUnavailable
    case rejected
    case timedOut
    case system(Error)
}

enum WorkspaceOpenCompletion {
    case accepted
    case failure(WorkspaceClientError)
}

protocol WorkspaceOpenCompletionAdapting: Sendable {
    func resolve(didLaunchApplication: Bool, error: NSError?) -> WorkspaceOpenCompletion
}

struct WorkspaceOpenCompletionAdapter: WorkspaceOpenCompletionAdapting {
    func resolve(didLaunchApplication: Bool, error: NSError?) -> WorkspaceOpenCompletion {
        if let error {
            return .failure(classify(error))
        }
        return didLaunchApplication ? .accepted : .failure(.rejected)
    }

    private func classify(_ error: NSError) -> WorkspaceClientError {
        let errors = errorChain(startingAt: error)
        if errors.contains(where: isRejection) {
            return .rejected
        }
        if errors.contains(where: isApplicationUnavailable) {
            return .applicationUnavailable
        }
        return .system(error)
    }

    private func errorChain(startingAt error: NSError) -> [NSError] {
        var errors = [error]
        var index = 0
        while index < errors.count {
            let current = errors[index]
            if let underlyingError = current.userInfo[NSUnderlyingErrorKey] as? NSError,
               !errors.contains(where: {
                   $0.domain == underlyingError.domain && $0.code == underlyingError.code
               }) {
                errors.append(underlyingError)
            }
            index += 1
        }
        return errors
    }

    private func isRejection(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain, error.code == NSUserCancelledError {
            return true
        }
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
            return true
        }
        if error.domain == NSPOSIXErrorDomain,
           error.code == Int(POSIXErrorCode.ECANCELED.rawValue) {
            return true
        }
        guard error.domain == NSOSStatusErrorDomain else { return false }
        return error.code == Int(kLSNoLaunchPermissionErr)
            || error.code == Int(kLSAppDoesNotClaimTypeErr)
    }

    private func isApplicationUnavailable(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain {
            return [
                NSFileNoSuchFileError,
                NSFileReadNoPermissionError,
                NSFileReadInvalidFileNameError,
                NSFileReadCorruptFileError,
                NSFileReadNoSuchFileError,
                NSExecutableNotLoadableError,
                NSExecutableArchitectureMismatchError,
                NSExecutableRuntimeMismatchError,
                NSExecutableLoadError,
                NSExecutableLinkError
            ].contains(error.code)
        }
        if error.domain == NSPOSIXErrorDomain {
            return [
                Int(POSIXErrorCode.ENOENT.rawValue),
                Int(POSIXErrorCode.EACCES.rawValue),
                Int(POSIXErrorCode.EPERM.rawValue),
                Int(POSIXErrorCode.ENOTDIR.rawValue),
                Int(POSIXErrorCode.ENOEXEC.rawValue)
            ].contains(error.code)
        }
        guard error.domain == NSOSStatusErrorDomain else { return false }
        return [
            Int(kLSNo32BitEnvironmentErr),
            Int(kLSAppInTrashErr),
            Int(kLSExecutableIncorrectFormat),
            Int(kLSIncompatibleApplicationVersionErr),
            Int(kLSNoRosettaEnvironmentErr),
            Int(kLSGarbageCollectionUnsupportedErr),
            Int(kLSNotAnApplicationErr),
            Int(kLSApplicationNotFoundErr),
            Int(kLSNoRegistrationInfoErr),
            Int(kLSIncompatibleSystemVersionErr),
            Int(kLSNoExecutableErr),
            Int(kLSNoClassicEnvironmentErr)
        ].contains(error.code)
    }
}

@MainActor
final class SystemWorkspaceClient: WorkspaceClient {
    private let completionAdapter: any WorkspaceOpenCompletionAdapting
    private let launchTimeout: Duration

    init(
        completionAdapter: any WorkspaceOpenCompletionAdapting = WorkspaceOpenCompletionAdapter(),
        launchTimeout: Duration = .seconds(25)
    ) {
        self.completionAdapter = completionAdapter
        self.launchTimeout = launchTimeout
    }

    func applicationURLs(toOpen url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: url)
    }

    func open(_ url: URL, with applicationURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw WorkspaceClientError.applicationUnavailable
        }

        let completionAdapter = completionAdapter
        try await awaitWithTimeout { complete in
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { application, error in
                switch completionAdapter.resolve(
                    didLaunchApplication: application != nil,
                    error: error as NSError?
                ) {
                case .accepted:
                    complete(.success(()))
                case let .failure(error):
                    complete(.failure(error))
                }
            }
        }
    }

    func icon(for applicationURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: applicationURL.path)
    }

    func openApplication(at applicationURL: URL, arguments: [String]) async throws {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw WorkspaceClientError.applicationUnavailable
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = true
        let completionAdapter = completionAdapter
        try await awaitWithTimeout { complete in
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { application, error in
                switch completionAdapter.resolve(didLaunchApplication: application != nil, error: error as NSError?) {
                case .accepted: complete(.success(()))
                case let .failure(error): complete(.failure(error))
                }
            }
        }
    }

    private func awaitWithTimeout(
        _ start: @MainActor (@escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    ) async throws {
        let timeout = launchTimeout
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = OnceContinuationGate(continuation)
            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                gate.resume(with: .failure(WorkspaceClientError.timedOut))
            }
            start { result in
                timeoutTask.cancel()
                gate.resume(with: result)
            }
        }
    }
}

private final class OnceContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Void, Error>) {
        let pending: CheckedContinuation<Void, Error>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}
