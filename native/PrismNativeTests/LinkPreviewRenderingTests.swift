import AppKit
import Testing
import WebKit
@testable import PrismNative

@Suite("Preview browser identity and scaling")
@MainActor
struct LinkPreviewRenderingTests {
    @Test func previewAllowsNativePinchMagnification() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let model = LinkPreviewWebModel(url: URL(string: "https://example.com")!, configuration: configuration)
        defer { model.stop() }
        #expect(model.webView.allowsMagnification)
    }

    @Test func matchingSystemSafariVersionIsAdvertisedBeforeLoading() throws {
        let safari = try #require(Bundle(url: URL(fileURLWithPath: "/Applications/Safari.app")))
        let version = try #require(safari.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let safariBuild = try #require(safari.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let webKitBuild = try #require(Bundle(for: WKWebView.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        guard safariBuild == webKitBuild else { return }
        let model = LinkPreviewWebModel(url: URL(string: "https://example.com")!)
        defer { model.stop() }
        #expect(model.webView.configuration.applicationNameForUserAgent == "Version/\(version) Safari/605.1.15")
        #expect((model.webView.customUserAgent ?? "").isEmpty)
    }

    @Test func browserIdentityFallsBackForMissingMismatchedOrInvalidMetadata() {
        #expect(LinkPreviewBrowserIdentity.applicationName(safariVersion: "27.2", safariBuild: "same", webKitBuild: "same") == "Version/27.2 Safari/605.1.15")
        #expect(LinkPreviewBrowserIdentity.applicationName(safariVersion: nil, safariBuild: "same", webKitBuild: "same") == nil)
        #expect(LinkPreviewBrowserIdentity.applicationName(safariVersion: "27.2", safariBuild: "new", webKitBuild: "old") == nil)
        for version in ["", "27..2", "27.2 Chrome/999", "27.2\nSafari/999"] {
            #expect(LinkPreviewBrowserIdentity.applicationName(safariVersion: version, safariBuild: "same", webKitBuild: "same") == nil)
        }
    }

    @Test func pageZoomUsesBoundedBrowserStepsAndAlwaysResetsToActualSize() {
        #expect(LinkPreviewPageZoom.scale(after: .zoomIn, current: 1) == 1.1)
        #expect(LinkPreviewPageZoom.scale(after: .zoomOut, current: 1) == 0.9)
        #expect(LinkPreviewPageZoom.scale(after: .zoomIn, current: 3) == 3)
        #expect(LinkPreviewPageZoom.scale(after: .zoomOut, current: 0.5) == 0.5)
        #expect(LinkPreviewPageZoom.scale(after: .reset, current: 2.5) == 1)
        #expect(LinkPreviewPageZoom.scale(after: .zoomIn, current: .nan) == 1.1)
        #expect(LinkPreviewPageZoom.scale(after: .zoomIn, current: 4) == 4)
        #expect(LinkPreviewPageZoom.scale(after: .zoomOut, current: 0.4) == 0.4)
    }

    @Test func zoomChangesOnlyWebContentAndResetAlsoClearsPinchMagnification() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let model = LinkPreviewWebModel(url: URL(string: "https://example.com")!, configuration: configuration)
        defer { model.stop() }
        model.webView.frame = CGRect(x: 0, y: 0, width: 600, height: 700)
        let frame = model.webView.frame
        model.zoom(.zoomIn)
        #expect(model.webView.pageZoom == 1.1)
        #expect(model.zoomPercentage == 110)
        #expect(model.webView.frame == frame)
        model.webView.magnification = 1.5
        model.zoom(.reset)
        #expect(model.webView.pageZoom == 1)
        #expect(model.webView.magnification == 1)
        #expect(model.zoomPercentage == 100)
    }
}
