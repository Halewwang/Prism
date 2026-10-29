import AppKit
import Testing
import WebKit
@testable import PrismNative

@Suite("Preview web lifecycle")
@MainActor
struct LinkPreviewWebLifecycleTests {
    @Test func downloadFallbackExpiresWhenTheDisplayedHistoryEntryChanges() {
        let page = URL(string: "https://example.com/start")!
        let download = URL(string: "https://example.com/file.bin")!
        let fallback = LinkPreviewDownloadFallback(url: download, documentURL: page)
        #expect(fallback.remainsValid(for: page))
        #expect(!fallback.remainsValid(for: URL(string: "https://example.com/start#section")))
        #expect(!fallback.remainsValid(for: URL(string: "https://example.com/spa?step=2")))
        // A direct download has no committed page and must keep its browser handoff.
        let direct = LinkPreviewDownloadFallback(url: download, documentURL: nil)
        #expect(direct.remainsValid(for: nil))
        #expect(!direct.remainsValid(for: page))
    }

    @Test func removedChildDocumentsUnregisterWithoutDroppingLiveFrames() async throws {
        _ = NSApplication.shared
        let model = makeModel()
        defer { model.stop() }
        // The generated HTML bootstraps without an HTTP request; real child navigation then uses the normal policy.
        model.webView.navigationDelegate = nil
        model.webView.loadHTMLString("<!doctype html><p>Owned frame lifecycle fixture</p>", baseURL: URL(string: "https://audit.invalid/"))
        let mainRegistered = try await waitUntil { registeredFrameCount(model) == 1 }
        let loaded = try await waitForJavaScript(model.webView, "document.readyState === 'complete' ? 1 : 0", expected: 1)
        #expect(mainRegistered)
        #expect(loaded)
        model.webView.navigationDelegate = model
        _ = await evaluateInt(model.webView, "window.loaded=0; for(let i=0;i<8;i++){let f=document.createElement('iframe');f.onload=()=>window.loaded++;f.srcdoc='<p>Owned child</p>';document.body.append(f);} 1")
        let childrenLoaded = try await waitForJavaScript(model.webView, "window.loaded", expected: 8)
        #expect(childrenLoaded)
        let liveFramesRegistered = try await waitUntil { registeredFrameCount(model) == 9 }
        #expect(liveFramesRegistered)
        _ = await evaluateInt(model.webView, "document.querySelectorAll('iframe').forEach(frame=>frame.remove()); 1")
        let childrenReleased = try await waitUntil { registeredFrameCount(model) == 1 }
        #expect(childrenReleased)
    }

    @Test func stoppingEndsOwnedScriptSheetsAndCompletesEachDialogOnce() async throws {
        _ = NSApplication.shared
        let model = makeModel()
        let window = makeWindow()
        defer { window.orderOut(nil) }
        var responses: [NSApplication.ModalResponse] = []
        let alert = NSAlert()
        model.presentJavaScriptDialog(alert, in: window) { responses.append($0) }
        #expect(window.attachedSheet === alert.window)

        model.stop()
        model.stop()
        let ended = try await waitUntil { window.attachedSheet == nil }

        #expect(ended)
        #expect(responses == [.cancel])
    }

    @Test func normalScriptCompletionIsNotRepeatedByStop() async throws {
        _ = NSApplication.shared
        let model = makeModel()
        let window = makeWindow()
        defer { window.orderOut(nil) }
        var responses: [NSApplication.ModalResponse] = []
        let alert = NSAlert()
        model.presentJavaScriptDialog(alert, in: window) { responses.append($0) }
        window.endSheet(alert.window, returnCode: .alertFirstButtonReturn)
        let completed = try await waitUntil { !responses.isEmpty }
        model.stop()
        #expect(completed)
        #expect(responses == [.alertFirstButtonReturn])
    }

    @Test func releasingTheModelAlsoCancelsItsScriptSheet() async throws {
        _ = NSApplication.shared
        var model: LinkPreviewWebModel? = makeModel()
        weak var releasedModel = model
        let window = makeWindow()
        defer { window.orderOut(nil) }
        var completions = 0
        model?.presentJavaScriptDialog(NSAlert(), in: window) { _ in completions += 1 }
        model = nil
        let ended = try await waitUntil { window.attachedSheet == nil }
        #expect(ended)
        #expect(releasedModel == nil)
        #expect(completions == 1)
    }

    @Test func stopLeavesOtherSheetsAloneAndRejectsLateScriptDialogs() {
        _ = NSApplication.shared
        let model = makeModel()
        let window = makeWindow()
        let unrelated = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.beginSheet(unrelated)
        defer { window.endSheet(unrelated); unrelated.orderOut(nil); window.orderOut(nil) }
        model.stop()
        #expect(window.attachedSheet === unrelated)
        var responses: [NSApplication.ModalResponse] = []
        model.presentJavaScriptDialog(NSAlert(), in: window) { responses.append($0) }
        #expect(window.attachedSheet === unrelated)
        #expect(responses == [.cancel])
    }

    private func makeModel() -> LinkPreviewWebModel {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return LinkPreviewWebModel(url: URL(string: "https://example.com")!, configuration: configuration)
    }

    private func waitUntil(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return condition()
    }

    private func registeredFrameCount(_ model: LinkPreviewWebModel) -> Int {
        Mirror(reflecting: model).children.first { $0.label == "shortcutFrames" }
            .flatMap { ($0.value as? [String: WKFrameInfo])?.count } ?? -1
    }

    private func evaluateInt(_ web: WKWebView, _ script: String) async -> Int {
        await withCheckedContinuation { continuation in
            web.evaluateJavaScript(script) { value, _ in
                continuation.resume(returning: (value as? NSNumber)?.intValue ?? -1)
            }
        }
    }

    private func waitForJavaScript(_ web: WKWebView, _ script: String, expected: Int) async throws -> Bool {
        for _ in 0..<100 {
            if await evaluateInt(web, script) == expected { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.orderFront(nil)
        return window
    }
}
