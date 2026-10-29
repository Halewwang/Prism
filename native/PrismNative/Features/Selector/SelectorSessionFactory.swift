import AppKit
import PrismCore
import SwiftUI

@MainActor
final class AppSelectorNavigationHandler: SelectorNavigationHandling {
    private weak var environment: AppEnvironment?
    private let mainWindowOpening: MainWindowOpening

    init(environment: AppEnvironment, mainWindowOpening: MainWindowOpening) {
        self.environment = environment
        self.mainWindowOpening = mainWindowOpening
    }

    func openBrowserManagement() {
        environment?.stageBrowserManagement()
        mainWindowOpening.open(route: .settings)
    }

    func openRuleEditor(prefill: SelectorRulePrefill) {
        environment?.stageSelectorRulePrefill(prefill)
        mainWindowOpening.open(route: .rules)
    }
}

@MainActor
final class SelectorSession {
    let requestID: UUID
    let content: AnyView
    private var monitoringTask: Task<Void, Never>?
    private var cancelAction: (@MainActor () -> Void)?
    private let updateAction: @MainActor (SelectorPresentationContext) -> Void
    private let closeAction: @MainActor () -> Void

    init(
        requestID: UUID,
        content: AnyView,
        monitoringTask: Task<Void, Never>? = nil,
        cancelAction: @escaping @MainActor () -> Void = {},
        updateAction: @escaping @MainActor (SelectorPresentationContext) -> Void = { _ in },
        closeAction: @escaping @MainActor () -> Void = {}
    ) {
        self.requestID = requestID
        self.content = content
        self.monitoringTask = monitoringTask
        self.cancelAction = cancelAction
        self.updateAction = updateAction
        self.closeAction = closeAction
    }

    func update(context: SelectorPresentationContext) { updateAction(context) }
    func close() { closeAction() }

    func cancel() {
        monitoringTask?.cancel()
        monitoringTask = nil
        cancelAction?()
        cancelAction = nil
    }

    deinit {
        monitoringTask?.cancel()
        if let cancelAction {
            Task { @MainActor in
                cancelAction()
            }
        }
    }
}

@MainActor
protocol SelectorContentProviding: AnyObject {
    func makeSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession
    func makePreviewSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession
}

extension SelectorContentProviding {
    func makePreviewSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession {
        makeSession(request: request, context: context)
    }
}

@MainActor
final class SelectorSessionFactory: SelectorContentProviding {
    let browserCatalog: any BrowserCataloging
    let routingCoordinator: any LinkRoutingCoordinating
    let pendingCountProvider: RecoveryQueuePendingCountProvider
    let sourceManifest: SourceSupportManifest
    let operatingSystemVersion: OperatingSystemVersion

    private let navigationHandler: any SelectorNavigationHandling
    private let iconProvider: any ApplicationIconProviding
    private let previewBrowserOrder: @MainActor ([BrowserDescriptor]) -> [BrowserDescriptor]

    init(
        browserCatalog: any BrowserCataloging,
        routingCoordinator: any LinkRoutingCoordinating,
        pendingCountProvider: RecoveryQueuePendingCountProvider,
        navigationHandler: any SelectorNavigationHandling,
        iconProvider: any ApplicationIconProviding,
        sourceManifest: SourceSupportManifest,
        operatingSystemVersion: OperatingSystemVersion,
        previewBrowserOrder: @escaping @MainActor ([BrowserDescriptor]) -> [BrowserDescriptor] = { $0 }
    ) {
        self.browserCatalog = browserCatalog
        self.routingCoordinator = routingCoordinator
        self.pendingCountProvider = pendingCountProvider
        self.navigationHandler = navigationHandler
        self.iconProvider = iconProvider
        self.sourceManifest = sourceManifest
        self.operatingSystemVersion = operatingSystemVersion
        self.previewBrowserOrder = previewBrowserOrder
    }

    func makeSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession {
        let model = SelectorViewModel(
            request: request,
            context: context,
            browserCatalog: browserCatalog,
            routingCoordinator: routingCoordinator,
            pendingCountProvider: pendingCountProvider,
            navigationHandler: navigationHandler,
            eligibleSourceBundleIDs: sourceManifest.eligibleBundleIDs(for: operatingSystemVersion)
        )
        let monitoringTask = model.startPendingCountMonitoring()
        return SelectorSession(
            requestID: request.id,
            content: AnyView(SelectorView(model: model, iconProvider: iconProvider)),
            monitoringTask: monitoringTask,
            cancelAction: { [weak model] in
                model?.stopPendingCountMonitoring()
            },
            updateAction: { [weak model] in model?.updatePresentationContext($0) },
            closeAction: { [weak model] in Task { await model?.cancel() } }
        )
    }

    func makePreviewSession(request: LinkRequest, context: SelectorPresentationContext) -> SelectorSession {
        let model = SelectorViewModel(
            request: request, context: context, browserCatalog: browserCatalog,
            routingCoordinator: routingCoordinator, pendingCountProvider: pendingCountProvider,
            navigationHandler: navigationHandler,
            eligibleSourceBundleIDs: sourceManifest.eligibleBundleIDs(for: operatingSystemVersion),
            browserOrder: previewBrowserOrder
        )
        let web = LinkPreviewWebModel(url: request.launchURL)
        model.previewURL = request.launchURL
        return SelectorSession(
            requestID: request.id,
            content: AnyView(LinkPreviewView(model: model, web: web, iconProvider: iconProvider).id(request.id)),
            monitoringTask: model.startPendingCountMonitoring(),
            cancelAction: { [weak model, weak web] in model?.stopPendingCountMonitoring(); web?.stop() },
            updateAction: { [weak model] in model?.updatePresentationContext($0) },
            closeAction: { [weak model] in Task { await model?.cancel() } }
        )
    }
}
