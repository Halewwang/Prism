#if DEBUG
import Foundation
import Testing
@testable import PrismNative

@Suite("Unit test host isolation")
struct UnitTestHostIsolationTests {
    @Test func runningHostUsesTheIsolatedApplicationFixture() throws {
        try #require(
            ProcessInfo.processInfo.arguments.contains("--ui-testing"),
            "Run native unit tests with the PrismNative-Unit scheme so the host cannot open production storage."
        )

        let mode = DebugUITestConfiguration.mode
        #expect(mode == .application)
        #expect(mode.isUITesting)
        #expect(!mode.mayInstallSystemStatusItem)
        #expect(!mode.mayUseSystemServices)
    }
}
#endif
