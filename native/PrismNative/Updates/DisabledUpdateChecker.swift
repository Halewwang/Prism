import Foundation

@MainActor
final class DisabledUpdateChecker: UpdateChecking {
    let events: AsyncStream<UpdateEvent>
    private let continuation: AsyncStream<UpdateEvent>.Continuation

    let canCheckForUpdates = false
    var automaticallyChecksForUpdates = false

    init() {
        let (stream, continuation) = AsyncStream<UpdateEvent>.makeStream()
        events = stream
        self.continuation = continuation
    }

    func checkForUpdates() {
        continuation.yield(.failed(.unavailableInThisBuild))
    }
}
