import AppKit
import PrismCore
import SwiftUI
import Testing
import WebKit
@testable import PrismNative

@Suite("Link preview presentation routing")
@MainActor
struct LinkPreviewCoordinatorTests {
    @Test func modesReuseSameRequestAndDuplicatePresentationKeepsSession() {
        let compact = PreviewCompactSpy()
        let preview = PreviewPanelSpy()
        let provider = PreviewContentSpy()
        var enabled = true
        let coordinator = WindowCoordinator(
            mainWindowOpening: MainWindowOpening(updateRoute: { _ in }),
            panelController: compact, previewPanelController: preview,
            previewEnabled: { enabled }, contentProvider: provider
        )
        let request = LinkRequest.fixture(url: "https://one.example")
        coordinator.present(request, context: .normal)
        coordinator.present(request, context: .storageUnavailable)
        #expect(preview.presentCount == 1)
        #expect(provider.makeCount == 1)
        #expect(provider.updatedContexts == [.storageUnavailable])
        enabled = false
        coordinator.present(request, context: .normal)
        #expect(preview.hideCount == 1)
        #expect(compact.presentCount == 1)
        #expect(coordinator.activeRequestID == request.id)
        #expect(provider.cancelCount == 1)
        coordinator.dismiss(requestID: UUID())
        #expect(coordinator.activeRequestID == request.id)
        coordinator.dismiss(requestID: request.id)
        #expect(compact.hideCount == 1)
        #expect(provider.cancelCount == 2)
    }
}

@MainActor private final class PreviewCompactSpy: SelectorPanelControlling {
    var presentCount = 0
    var hideCount = 0
    func present(content: AnyView, at origin: CGPoint) { presentCount += 1 }
    func hide() { hideCount += 1 }
}
@MainActor private final class PreviewPanelSpy: LinkPreviewPanelControlling {
    var presentCount = 0
    var hideCount = 0
    func present(content: AnyView, pointer: CGPoint, visibleFrames: [CGRect], onClose: @escaping @MainActor () -> Void) { presentCount += 1 }
    func hide() { hideCount += 1 }
}
@MainActor private final class PreviewContentSpy: SelectorContentProviding {
    var makeCount = 0
    var cancelCount = 0
    var updatedContexts: [SelectorPresentationContext] = []
    func makeSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession {
        makeCount += 1
        return SelectorSession(requestID: request.id, content: AnyView(EmptyView()),
            cancelAction: { [weak self] in self?.cancelCount += 1 },
            updateAction: { [weak self] in self?.updatedContexts.append($0) })
    }
}


@Suite("Link preview release", .serialized)
@MainActor
struct LinkPreviewReleaseTests {
    @Test func closedPreviewReleasesItsHostingGraphAndCanReopen() async throws {
        let provider = ReleasePreviewProvider()
        let suite = "LinkPreviewReleaseTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let panel = LinkPreviewPanelController(defaults: defaults, orderFront: { $0.orderFront(nil) })
        let coordinator = WindowCoordinator(
            mainWindowOpening: MainWindowOpening(updateRoute: { _ in }),
            previewPanelController: panel, previewEnabled: { true },
            pointerLocation: { CGPoint(x: 100, y: 100) },
            visibleFrames: { [CGRect(x: 0, y: 0, width: 1200, height: 1000)] },
            contentProvider: provider
        )
        defer { coordinator.hideSelector() }

        for _ in 0..<4 {
            let request = LinkRequest.fixture(url: "http://127.0.0.1:1/preview-release-test")
            coordinator.present(request, context: .normal)
            weak var host = panel.panel.contentView
            #expect(host != nil)
            #expect(panel.panel.firstResponder === host)
            try await Task.sleep(for: .milliseconds(100))
            coordinator.hideSelector()
            for _ in 0..<40 {
                if host == nil && provider.references.allSatisfy { $0.released } { break }
                try await Task.sleep(for: .milliseconds(25))
            }
            #expect(panel.panel.contentView == nil)
            #expect(panel.panel.initialFirstResponder == nil)
            #expect(host == nil)
            #expect(provider.references.allSatisfy { $0.released })
        }
    }
}

@MainActor
private final class ReleasedPreviewReferences {
    weak var model: SelectorViewModel?
    weak var web: LinkPreviewWebModel?
    weak var webView: WKWebView?
    weak var session: SelectorSession?

    init(model: SelectorViewModel, web: LinkPreviewWebModel, session: SelectorSession) {
        self.model = model
        self.web = web
        webView = web.webView
        self.session = session
    }

    var released: Bool { model == nil && web == nil && webView == nil && session == nil }
}

@MainActor
private final class ReleasePreviewDependencies: BrowserCataloging, LinkRoutingCoordinating,
    SelectorPendingCountProviding, SelectorNavigationHandling, ApplicationIconProviding {
    func scan() async throws -> [BrowserDescriptor] { [] }
    func processNext(while shouldContinue: @escaping @MainActor () -> Bool) async -> LinkRoutingPassDisposition { .drained }
    func select(browserID: BrowserID, for requestID: UUID) async {}
    func retry(browserID: BrowserID, for requestID: UUID) async {}
    func markUncertainAttemptCompleted(requestID: UUID) async {}
    func cancel(requestID: UUID) async {}
    func pendingCountUpdates() async -> AsyncStream<Int> { AsyncStream { $0.yield(1) } }
    func openBrowserManagement() {}
    func openRuleEditor(prefill: SelectorRulePrefill) {}
    func icon(for applicationURL: URL) -> NSImage { NSImage(size: NSSize(width: 22, height: 22)) }
    func icon(bundleIdentifier: String) -> NSImage? { nil }
}

@MainActor
private final class ReleasePreviewProvider: SelectorContentProviding {
    private let dependencies = ReleasePreviewDependencies()
    private(set) var references: [ReleasedPreviewReferences] = []

    func makeSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession {
        let model = SelectorViewModel(
            request: request, context: context, browserCatalog: dependencies,
            routingCoordinator: dependencies, pendingCountProvider: dependencies,
            navigationHandler: dependencies, eligibleSourceBundleIDs: []
        )
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = LinkPreviewWebModel(url: request.launchURL, configuration: configuration)
        let session = SelectorSession(
            requestID: request.id,
            content: AnyView(LinkPreviewView(model: model, web: web, iconProvider: dependencies).id(request.id)),
            monitoringTask: model.startPendingCountMonitoring(),
            cancelAction: { [weak model, weak web] in model?.stopPendingCountMonitoring(); web?.stop() }
        )
        references.append(ReleasedPreviewReferences(model: model, web: web, session: session))
        return session
    }
}
