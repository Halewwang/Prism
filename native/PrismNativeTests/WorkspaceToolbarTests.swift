import AppKit
import SwiftUI
import Testing
@testable import PrismNative

@Suite("Workspace native toolbar")
@MainActor
struct WorkspaceToolbarTests {
    @Test func replacementToolbarKeepsNativeButtonsAndCannotBeClearedByThePreviousOwner() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let nativeParent = try #require(window.standardWindowButton(.closeButton)?.superview)
        let old = WorkspaceToolbar.Coordinator(configuration: WorkspaceToolbar(selection: .constant(.history)))
        let replacement = WorkspaceToolbar.Coordinator(configuration: WorkspaceToolbar(selection: .constant(.settings)))
        old.attach(to: window)
        let originalToolbar = try #require(window.toolbar)

        replacement.attach(to: window)
        let activeToolbar = try #require(window.toolbar)
        #expect(activeToolbar !== originalToolbar)
        #expect(window.standardWindowButton(.closeButton)?.superview === nativeParent)
        #expect(window.standardWindowButton(.miniaturizeButton)?.superview === nativeParent)

        old.attach(to: window)
        #expect(window.toolbar === activeToolbar)
        old.detach()
        #expect(window.toolbar === activeToolbar)

        replacement.detach()
        #expect(window.toolbar == nil)
        #expect(window.toolbarStyle == .automatic)
        #expect(window.standardWindowButton(.zoomButton)?.isEnabled == false)
        #expect(window.standardWindowButton(.closeButton)?.superview === nativeParent)
    }
}
