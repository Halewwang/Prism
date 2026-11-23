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
    typealias MakeLocalFileSession = @MainActor (URL, UUID, @escaping @MainActor () -> Void) -> SelectorSession

    private struct LocalHTMLDocument {
        let id = UUID()
        let url: URL

        init?(url: URL) {
            let host = url.host(percentEncoded: false)?.lowercased() ?? ""
            guard url.isFileURL, host.isEmpty || host == "localhost",
                  ["html", "htm"].contains(url.pathExtension.lowercased()),
                  !url.hasDirectoryPath,
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
            else { return nil }
            self.url = url
        }
    }

    private let mainWindowOpening: MainWindowOpening
    private let panelController: any SelectorPanelControlling
    private let previewPanelController: any LinkPreviewPanelControlling
    private let previewEnabled: @MainActor () -> Bool
    private var activeIsPreview = false
    private let positioner: SelectorPositioner
    private let pointerLocation: @MainActor () -> CGPoint
    private let visibleFrames: @MainActor () -> [CGRect]
    private let usesSystemScreens: Bool
    let contentProvider: any SelectorContentProviding
    private let makeLocalFileSession: MakeLocalFileSession?
    private var activeSession: SelectorSession?
    private var canPresentLocalDocuments = false
    private var localDocuments: [LocalHTMLDocument] = []
    private var deferredLink: (request: LinkRequest, context: SelectorPresentationContext)?
    private(set) var activeRequestID: UUID?

    var hasPendingLocalDocuments: Bool { !localDocuments.isEmpty }

    init(
        mainWindowOpening: MainWindowOpening,
        panelController: any SelectorPanelControlling = SelectorPanelController(),
        previewPanelController: any LinkPreviewPanelControlling = LinkPreviewPanelController(),
        previewEnabled: @escaping @MainActor () -> Bool = { false },
        positioner: SelectorPositioner = SelectorPositioner(),
        pointerLocation: @escaping @MainActor () -> CGPoint = { NSEvent.mouseLocation },
        visibleFrames: (@MainActor () -> [CGRect])? = nil,
        contentProvider: any SelectorContentProviding,
        makeLocalFileSession: MakeLocalFileSession? = nil
    ) {
        self.mainWindowOpening = mainWindowOpening
        self.panelController = panelController
        self.previewPanelController = previewPanelController
        self.previewEnabled = previewEnabled
        self.positioner = positioner
        self.pointerLocation = pointerLocation
        self.usesSystemScreens = visibleFrames == nil
        self.visibleFrames = visibleFrames ?? { NSScreen.screens.map(\.visibleFrame) }
        self.contentProvider = contentProvider
        self.makeLocalFileSession = makeLocalFileSession
    }

    private func resolvedVisibleFrames(for pointer: CGPoint) -> [CGRect] {
        if usesSystemScreens,
           let matchedScreen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) {
            return [matchedScreen.visibleFrame]
        }
        return visibleFrames()
    }

    func present(_ request: LinkRequest, context: SelectorPresentationContext) {
        if let activeRequestID, localDocuments.first?.id == activeRequestID {
            deferredLink = (request, context)
            return
        }
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
            let pointer = pointerLocation()
            previewPanelController.present(
                content: session.content, pointer: pointer, visibleFrames: resolvedVisibleFrames(for: pointer)
            ) { [weak session] in session?.close() }
            return
        }
        presentCompact(session)
    }

    func dismiss(requestID: UUID) {
        if deferredLink?.request.id == requestID { deferredLink = nil }
        guard activeRequestID == requestID else { return }
        if localDocuments.first?.id == requestID { localDocuments.removeFirst() }
        hideSelector()
        if let deferredLink {
            self.deferredLink = nil
            present(deferredLink.request, context: deferredLink.context)
        } else {
            presentNextLocalDocument()
        }
    }

    func enqueueLocalDocuments(_ urls: [URL]) {
        guard makeLocalFileSession != nil else { return }
        // Local paths only belong to the live selector, never the web recovery queue.
        localDocuments.append(contentsOf: urls.compactMap(LocalHTMLDocument.init(url:)))
        presentNextLocalDocument()
    }

    func startPresentingLocalDocuments() {
        canPresentLocalDocuments = true
        presentNextLocalDocument()
    }

    private func presentNextLocalDocument() {
        guard canPresentLocalDocuments, activeRequestID == nil,
              let makeLocalFileSession, let document = localDocuments.first
        else { return }
        let id = document.id
        let session = makeLocalFileSession(document.url, id) { [weak self] in
            self?.dismiss(requestID: id)
        }
        activeIsPreview = false
        activeSession = session
        activeRequestID = id
        presentCompact(session)
    }

    private func presentCompact(_ session: SelectorSession) {
        let pointer = pointerLocation()
        let origin = positioner.origin(
            panelSize: SelectorPanel.contentSize,
            pointer: pointer,
            visibleFrames: resolvedVisibleFrames(for: pointer)
        )
        panelController.present(content: session.content, at: origin)
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
