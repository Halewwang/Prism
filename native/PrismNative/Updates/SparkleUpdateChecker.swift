import Foundation
#if !PRISM_PUBLIC_TEST
import Sparkle

/// Bridges Prism's small update boundary to Sparkle's maintained standard updater UI.
/// Developer ID builds without a public EdDSA key check GitHub for manual installers.
@MainActor
final class SparkleUpdateChecker: NSObject, UpdateChecking {
    let events: AsyncStream<UpdateEvent>
    private let continuation: AsyncStream<UpdateEvent>.Continuation
    private let delegateBridge: SparkleUpdaterDelegateBridge
    private let controller: SPUStandardUpdaterController

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    override init() {
        let (stream, continuation) = AsyncStream<UpdateEvent>.makeStream()
        events = stream
        self.continuation = continuation
        let bridge = SparkleUpdaterDelegateBridge(continuation: continuation)
        delegateBridge = bridge
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: bridge,
            userDriverDelegate: nil
        )
        super.init()
    }

    init(controller: SPUStandardUpdaterController) {
        let (stream, continuation) = AsyncStream<UpdateEvent>.makeStream()
        events = stream
        self.continuation = continuation
        delegateBridge = SparkleUpdaterDelegateBridge(continuation: continuation)
        self.controller = controller
        super.init()
    }

    func setRelaunchGate(_ canRelaunch: @escaping @MainActor () -> Bool) {
        delegateBridge.canRelaunch = canRelaunch
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            continuation.yield(.failed(.configuration))
            return
        }
        continuation.yield(.checking)
        controller.checkForUpdates(nil)
    }
}

private final class SparkleUpdaterDelegateBridge: NSObject, SPUUpdaterDelegate {
    private let continuation: AsyncStream<UpdateEvent>.Continuation
    @MainActor var canRelaunch: (@MainActor () -> Bool)?

    init(continuation: AsyncStream<UpdateEvent>.Continuation) {
        self.continuation = continuation
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        continuation.yield(.available(version: item.displayVersionString))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        continuation.yield(.current)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error {
            continuation.yield(.failed(.system(error.localizedDescription)))
        }
    }

    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        MainActor.assumeIsolated {
            canRelaunch?() ?? true
        }
    }
}
#endif

@MainActor
enum UpdateCheckerFactory {
    static func makeIfConfigured(bundle: Bundle = .main) -> any UpdateChecking {
#if !PRISM_PUBLIC_TEST
        if SparkleUpdateConfiguration(bundle: bundle).isReady {
            return SparkleUpdateChecker()
        }
#endif
        return GitHubUpdateChecker(
            currentVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        )
    }
}

struct SparkleUpdateConfiguration: Equatable {
    let feedURL: URL?
    let publicEDKey: String?

    init(bundle: Bundle = .main) {
        let feedValue = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        feedURL = feedValue.flatMap(URL.init(string:))
        publicEDKey = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(feedURL: URL?, publicEDKey: String?) {
        self.feedURL = feedURL
        self.publicEDKey = publicEDKey?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isReady: Bool {
        guard feedURL?.scheme?.lowercased() == "https",
              let publicEDKey,
              !publicEDKey.isEmpty
        else { return false }
        return !publicEDKey.hasPrefix("$(")
    }
}
