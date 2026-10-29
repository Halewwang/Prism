import AppKit
import PrismCore
import SwiftUI

@MainActor
final class MainWindowOpening {
    typealias OpenWindow = @MainActor (_ id: String, _ value: MainWindowIdentity) -> Void

    private let updateRoute: @MainActor (AppRoute) -> Void
    private var openWindow: OpenWindow?

    init(updateRoute: @escaping @MainActor (AppRoute) -> Void) {
        self.updateRoute = updateRoute
    }

    func register(openWindow: @escaping OpenWindow) {
        self.openWindow = openWindow
    }

    func open(route: AppRoute) {
        updateRoute(route)
        openWindow?("main", .singleton)
    }
}

@MainActor
final class WindowCoordinator: LinkSelectionPresenting {
    private let mainWindowOpening: MainWindowOpening
    private let panelController: any SelectorPanelControlling
    private let previewPanelController: any LinkPreviewPanelControlling
    private let previewEnabled: @MainActor () -> Bool
    private var activeIsPreview = false
    private let positioner: SelectorPositioner
    private let pointerLocation: @MainActor () -> CGPoint
    private let visibleFrames: @MainActor () -> [CGRect]
    let contentProvider: any SelectorContentProviding
    private var activeSession: SelectorSession?
    private(set) var activeRequestID: UUID?

    init(
        mainWindowOpening: MainWindowOpening,
        panelController: any SelectorPanelControlling = SelectorPanelController(),
        previewPanelController: any LinkPreviewPanelControlling = LinkPreviewPanelController(),
        previewEnabled: @escaping @MainActor () -> Bool = { false },
        positioner: SelectorPositioner = SelectorPositioner(),
        pointerLocation: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
        visibleFrames: @escaping @MainActor () -> [CGRect] = { NSScreen.screens.map(\.visibleFrame) },
        contentProvider: any SelectorContentProviding
    ) {
        self.mainWindowOpening = mainWindowOpening
        self.panelController = panelController
        self.previewPanelController = previewPanelController
        self.previewEnabled = previewEnabled
        self.positioner = positioner
        self.pointerLocation = pointerLocation
        self.visibleFrames = visibleFrames
        self.contentProvider = contentProvider
    }

    func present(_ request: LinkRequest, context: SelectorPresentationContext) {
        let isPreview = previewEnabled()
        if activeRequestID == request.id, isPreview == activeIsPreview, let activeSession {
            activeSession.update(context: context)
            return
        }
        activeSession?.cancel()
        if activeRequestID != nil, activeIsPreview != isPreview {
            if activeIsPreview { previewPanelController.hide() } else { panelController.hide() }
        }
        activeIsPreview = isPreview
        let session = isPreview
            ? contentProvider.makePreviewSession(request: request, context: context)
            : contentProvider.makeSession(request: request, context: context)
        activeSession = session
        activeRequestID = session.requestID
        if isPreview {
            previewPanelController.present(content: session.content, pointer: pointerLocation(), visibleFrames: visibleFrames()) { [weak session] in session?.close() }
            return
        }
        let origin = positioner.origin(
            panelSize: SelectorPanel.contentSize,
            pointer: pointerLocation(),
            visibleFrames: visibleFrames()
        )
        panelController.present(content: session.content, at: origin)
    }

    func dismiss(requestID: UUID) {
        guard activeRequestID == requestID else { return }
        hideSelector()
    }

    func hideSelector() {
        activeSession?.cancel()
        activeSession = nil
        activeRequestID = nil
        if activeIsPreview { previewPanelController.hide() } else { panelController.hide() }
    }

    func showMainWindow(route: AppRoute) {
        mainWindowOpening.open(route: route)
    }
}
