import AppKit
import PrismCore
import SwiftUI
import Testing
import WebKit
@testable import PrismNative

@Suite("Link preview")
@MainActor
struct LinkPreviewTests {
    @Test func navigationPolicyAcceptsOnlyWebLinksForHandoff() {
        #expect(LinkPreviewNavigationPolicy.canOpen(URL(string: "https://example.com/path")!))
        #expect(LinkPreviewNavigationPolicy.canOpen(URL(string: "http://localhost:8123")!))
        for raw in ["file:///tmp/private", "javascript:alert(1)", "about:blank", "mailto:a@example.com", "https:/path"] {
            #expect(!LinkPreviewNavigationPolicy.canOpen(URL(string: raw)!))
        }
    }

    @Test func recommendationUsesSuccessfulHistoryAndKeepsUnavailableChoicesOut() {
        let browsers = [browser("a", order: 0), browser("b", order: 1), browser("c", order: 2)]
        let ordered = LinkPreviewRecommendation.ordered(
            browsers,
            successfulBrowserIDs: ["b", "missing", "b", "a"],
            fallback: "c"
        )
        #expect(ordered.map(\.id) == ["b", "a", "c"])
        #expect(LinkPreviewRecommendation.ordered(browsers, successfulBrowserIDs: [], fallback: "c").map(\.id) == ["c", "a", "b"])
        #expect(LinkPreviewRecommendation.ordered([], successfulBrowserIDs: ["b"], fallback: nil).isEmpty)
    }

    @Test func toolbarKeepsHalfOfTheFourthScrollingBrowserVisible() {
        let width = LinkPreviewMetrics.browserWidth
        #expect(LinkPreviewMetrics.scrollingWidth(count: 4) == 3.5 * width + 3 * LinkPreviewMetrics.browserGap)
        #expect(LinkPreviewMetrics.scrollingWidth(count: 1) == width)
        #expect(LinkPreviewMetrics.innerRadius + LinkPreviewMetrics.browserInset == LinkPreviewMetrics.fieldRadius)
        #expect(LinkPreviewMetrics.browserHeight + 2 * LinkPreviewMetrics.browserInset == LinkPreviewMetrics.toolbarHeight)
    }

    @Test func widerToolbarSharesSpaceWithBrowserChoicesAndStopsAtLastBrowser() {
        let normal = LinkPreviewMetrics.scrollingWidth(count: 8, windowWidth: 600)
        let wider = LinkPreviewMetrics.scrollingWidth(count: 8, windowWidth: 800)
        #expect(wider == normal + 100)
        let allBrowsersWidth: CGFloat = 8 * 42 + 7 * 4
        #expect(LinkPreviewMetrics.scrollingWidth(count: 8, windowWidth: 1600) == allBrowsersWidth)
        #expect(LinkPreviewMetrics.scrollingWidth(count: 1, windowWidth: 1600) == 42)
        #expect(LinkPreviewMetrics.scrollingWidth(count: 0, windowWidth: 1600) == 0)
    }

    @Test func toolbarPreservesAddressSpaceAcrossCompactAndFullModes() {
        for width: CGFloat in [560, 600, 800, 1200] {
            let scrolling = LinkPreviewMetrics.scrollingWidth(count: 20, windowWidth: width)
            let group = 42 + 12 + 0.5 + 6 + scrolling
            let fixed: CGFloat = 14 + 75 + 64 + 15 + 120
            #expect(scrolling >= 0)
            #expect(group + fixed <= width)
        }
        for width: CGFloat in [360, 440, 559] {
            let address = LinkPreviewMetrics.compactAddressWidth(windowWidth: width)
            #expect(address >= 94)
            #expect(address + 14 + 48 + LinkPreviewMetrics.compactBrowserWidth + 64 + 18 == width)
        }
    }

    @Test func browserCandidatesStayBelowTheirControlInsideTheWindow() {
        for size in [CGSize(width: 280, height: 400), CGSize(width: 360, height: 480), CGSize(width: 559, height: 640)] {
            let frame = LinkPreviewMetrics.candidateFrame(windowSize: size, count: 20)
            #expect(CGRect(origin: .zero, size: size).contains(frame))
            #expect(frame.minY == 61)
            #expect(frame.height == 6 * LinkPreviewMetrics.candidateRowHeight + 5 * LinkPreviewMetrics.candidateRowSpacing + 6)
            #expect(frame.width == LinkPreviewMetrics.browserWidth + 2 * LinkPreviewMetrics.browserInset)
            if size.width >= 360 { #expect(frame.minX == size.width - 147) }
        }
        let one = LinkPreviewMetrics.candidateFrame(windowSize: CGSize(width: 360, height: 480), count: 1)
        #expect(one.height == LinkPreviewMetrics.candidateRowHeight + 6)
        #expect(LinkPreviewMetrics.candidateFrame(windowSize: CGSize(width: 360, height: 480), count: 0) == .zero)
        let short = LinkPreviewMetrics.candidateFrame(windowSize: CGSize(width: 360, height: 180), count: 20)
        #expect(short.maxY <= CGFloat(173))
    }

    @Test func previewWebViewUsesNativeNavigationAndReleasesDelegatesOnStop() {
        let model = LinkPreviewWebModel(url: URL(string: "https://example.com")!)
        #expect(model.currentURL == URL(string: "https://example.com"))
        #expect(model.webView.allowsBackForwardNavigationGestures)
        #expect(model.webView.navigationDelegate === model)
        model.stop()
        #expect(model.webView.navigationDelegate == nil)
        #expect(model.webView.uiDelegate == nil)
    }

    private func browser(_ id: BrowserID, order: Int) -> BrowserDescriptor {
        BrowserDescriptor(id: id, bundleIdentifier: id.rawValue, displayName: id.rawValue,
            applicationURL: URL(fileURLWithPath: "/Applications/\(id.rawValue).app"),
            securityScopedBookmark: nil, origin: .system, availability: .available, selectorOrder: order)
    }
}
