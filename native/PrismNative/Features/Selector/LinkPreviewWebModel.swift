import AppKit
import Observation
import SwiftUI
import WebKit

enum LinkPreviewNavigationPolicy {
    static func canOpen(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty
    }
}

struct LinkPreviewDownloadFallback {
    let url: URL
    let documentURL: URL?

    func remainsValid(for documentURL: URL?) -> Bool { self.documentURL == documentURL }
}

@MainActor
@Observable
final class LinkPreviewWebModel: NSObject, WKNavigationDelegate, WKUIDelegate {
    private(set) var currentURL: URL
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0
    private(set) var errorMessage: String?
    private(set) var pageScale: CGFloat = 1
    var navigationEnabled = true
    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var hasStopped = false
    @ObservationIgnored private var downloadFallback: LinkPreviewDownloadFallback?
    @ObservationIgnored var browserShortcutAction: (@MainActor (Int) -> Void)?
    @ObservationIgnored private var browserShortcutCount = 0
    @ObservationIgnored private var shortcutFrames: [String: WKFrameInfo] = [:]
    @ObservationIgnored private var scriptDialogs: [UUID: (alert: NSAlert, completion: @MainActor (NSApplication.ModalResponse) -> Void)] = [:]

    init(url: URL, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        currentURL = url
        if configuration.applicationNameForUserAgent == nil {
            configuration.applicationNameForUserAgent = LinkPreviewBrowserIdentity.systemApplicationName
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        // Isolate the bridge from website scripts; only trusted key events request handoff.
        let keyboardHandler = LinkPreviewShortcutMessageHandler()
        keyboardHandler.owner = self
        configuration.userContentController.add(keyboardHandler, contentWorld: LinkPreviewWebShortcuts.world, name: LinkPreviewWebShortcuts.handlerName)
        configuration.userContentController.addUserScript(WKUserScript(
            source: LinkPreviewWebShortcuts.source, injectionTime: .atDocumentStart,
            forMainFrameOnly: false, in: LinkPreviewWebShortcuts.world
        ))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.setAccessibilityIdentifier("linkPreview.webView")
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.pageZoom, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
            webView.observe(\.magnification, options: [.new]) { [weak self] _, _ in self?.scheduleUpdate() },
        ]
    }

    nonisolated private func scheduleUpdate() {
        Task { @MainActor [weak self] in self?.update() }
    }

    var handoffURL: URL {
        if let downloadFallback, downloadFallback.remainsValid(for: webView.backForwardList.currentItem?.url) {
            return downloadFallback.url
        }
        if let url = webView.url, LinkPreviewNavigationPolicy.canOpen(url) { return url }
        return currentURL
    }

    func start() {
        guard !hasStarted, !hasStopped else { return }
        hasStarted = true
        load(currentURL)
    }

    func load(_ url: URL) {
        guard !hasStopped, navigationEnabled, LinkPreviewNavigationPolicy.canOpen(url) else { return }
        errorMessage = nil
        currentURL = url
        webView.load(URLRequest(url: url))
    }

    func goBack() { errorMessage = nil; webView.goBack() }
    func goForward() { errorMessage = nil; webView.goForward() }
    func reload() {
        errorMessage = nil
        if downloadFallback != nil || webView.url == nil { load(currentURL) } else { webView.reload() }
    }

    var zoomPercentage: Int { Int((pageScale * 100).rounded()) }

    func zoom(_ action: LinkPreviewZoomAction) {
        let scale = LinkPreviewPageZoom.scale(after: action, current: webView.pageZoom * webView.magnification)
        webView.magnification = 1
        webView.pageZoom = scale
        pageScale = scale
    }

    func stop() {
        guard !hasStopped else { return }
        hasStopped = true
        let dialogs = scriptDialogs
        scriptDialogs.removeAll()
        for dialog in dialogs.values {
            if let parent = dialog.alert.window.sheetParent {
                parent.endSheet(dialog.alert.window, returnCode: .cancel)
            }
            dialog.completion(.cancel)
        }
        webView.stopLoading()
        observations.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        browserShortcutAction = nil
        shortcutFrames.removeAll()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: LinkPreviewWebShortcuts.handlerName, contentWorld: LinkPreviewWebShortcuts.world)
    }

    isolated deinit { stop() }

    func updateBrowserShortcuts(count: Int) {
        browserShortcutCount = min(max(0, count), 9)
        for (documentID, frame) in shortcutFrames { updateShortcutFrame(frame, documentID: documentID) }
    }

    func registerShortcutFrame(_ frame: WKFrameInfo, documentID: String) {
        guard !hasStopped else { return }
        shortcutFrames[documentID] = frame
        updateShortcutFrame(frame, documentID: documentID)
    }

    func unregisterShortcutFrame(documentID: String) {
        shortcutFrames[documentID] = nil
    }

    private func updateShortcutFrame(_ frame: WKFrameInfo, documentID: String) {
        webView.evaluateJavaScript("globalThis.prismSetBrowserShortcutCount(\(browserShortcutCount))", in: frame, in: LinkPreviewWebShortcuts.world) { [weak self] result in
            if case let .failure(error) = result, (error as? WKError)?.code == .javaScriptInvalidFrameTarget,
               self?.shortcutFrames[documentID] === frame {
                self?.shortcutFrames[documentID] = nil
            }
        }
    }

    private func update() {
        if let downloadFallback, !downloadFallback.remainsValid(for: webView.backForwardList.currentItem?.url) {
            self.downloadFallback = nil
            errorMessage = nil
        }
        if let url = downloadFallback?.url ?? webView.url, LinkPreviewNavigationPolicy.canOpen(url) { currentURL = url }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
        pageScale = webView.pageZoom * webView.magnification
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard navigationEnabled else { decisionHandler(.cancel); return }
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        // Embedded frames need local documents; only HTTP(S) can become the top-level page.
        if action.targetFrame?.isMainFrame == false, ["about", "blob", "data"].contains(url.scheme ?? "") {
            decisionHandler(.allow)
        } else if LinkPreviewNavigationPolicy.canOpen(url) {
            if action.targetFrame == nil {
                webView.load(action.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            if action.targetFrame?.isMainFrame != false {
                errorMessage = String(localized: "preview.unsupportedLink", defaultValue: "This link cannot open in the preview. Continue in a browser.")
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        if !response.canShowMIMEType, response.isForMainFrame {
            if let url = response.response.url, LinkPreviewNavigationPolicy.canOpen(url) {
                downloadFallback = LinkPreviewDownloadFallback(url: url, documentURL: webView.backForwardList.currentItem?.url)
                currentURL = url
            }
            errorMessage = String(localized: "preview.download", defaultValue: "Open this link in a browser to download the file.")
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        downloadFallback = nil; errorMessage = nil; update()
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { failed(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        shortcutFrames.removeAll()
        errorMessage = String(localized: "preview.processStopped", defaultValue: "The preview stopped. Reload to continue.")
        update()
    }

    private func failed(_ error: any Error) {
        guard downloadFallback == nil, (error as NSError).code != NSURLErrorCancelled else { return }
        errorMessage = error.localizedDescription
        update()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, LinkPreviewNavigationPolicy.canOpen(url) { webView.load(action.request) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = message
        guard let window = webView.window else { completionHandler(); return }
        presentJavaScriptDialog(alert, in: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = message
        alert.addButton(withTitle: String(localized: "preview.ok", defaultValue: "OK"))
        alert.addButton(withTitle: String(localized: "selector.cancel", defaultValue: "Cancel"))
        guard let window = webView.window else { completionHandler(false); return }
        presentJavaScriptDialog(alert, in: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping @MainActor (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = prompt
        let input = NSTextField(string: defaultText ?? "")
        input.frame = CGRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: String(localized: "preview.ok", defaultValue: "OK"))
        alert.addButton(withTitle: String(localized: "selector.cancel", defaultValue: "Cancel"))
        guard let window = webView.window else { completionHandler(nil); return }
        presentJavaScriptDialog(alert, in: window) { completionHandler($0 == .alertFirstButtonReturn ? input.stringValue : nil) }
    }

    func presentJavaScriptDialog(
        _ alert: NSAlert, in window: NSWindow,
        completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void
    ) {
        guard !hasStopped else { completion(.cancel); return }
        let id = UUID()
        scriptDialogs[id] = (alert, completion)
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let dialog = self?.scriptDialogs.removeValue(forKey: id) else { return }
            dialog.completion(response)
        }
    }
}

struct LinkPreviewWebView: NSViewRepresentable {
    let model: LinkPreviewWebModel
    func makeNSView(context: Context) -> WKWebView { model.start(); return model.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
