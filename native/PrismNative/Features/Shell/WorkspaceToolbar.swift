import AppKit
import SwiftUI

struct WorkspaceToolbar: NSViewRepresentable {
    @Binding var selection: AppRoute
    @Environment(\.locale) private var sourceLocale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeCoordinator() -> Coordinator { Coordinator(configuration: self) }

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        context.coordinator.update(configuration: self)
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class AnchorView: NSView {
        weak var coordinator: Coordinator?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow !== window { coordinator?.detach() }
            super.viewWillMove(toWindow: newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSToolbarDelegate {
        private static let brandID = NSToolbarItem.Identifier("PrismWorkspaceBrand")
        private static let navigationID = NSToolbarItem.Identifier("PrismWorkspaceNavigation")
        private let toolbar = NSToolbar(identifier: "PrismWorkspace")
        private let brandHost = NSHostingView(rootView: AnyView(EmptyView()))
        private let navigationHost = NSHostingView(rootView: AnyView(EmptyView()))
        private weak var window: NSWindow?

        init(configuration: WorkspaceToolbar) {
            super.init()
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            brandHost.sizingOptions = .intrinsicContentSize
            brandHost.clipsToBounds = false
            navigationHost.sizingOptions = .intrinsicContentSize
            update(configuration: configuration)
        }

        func update(configuration: WorkspaceToolbar) {
            brandHost.rootView = AnyView(
                WorkspaceBrandView(reduceTransparency: configuration.reduceTransparency)
                    .environment(\.locale, configuration.sourceLocale)
                    .environment(\.colorScheme, configuration.colorScheme)
            )
            navigationHost.rootView = AnyView(
                WorkspaceNavigationView(
                    selection: configuration.$selection,
                    reduceTransparency: configuration.reduceTransparency
                )
                .padding(.trailing, 6)
                .environment(\.locale, configuration.sourceLocale)
                .environment(\.colorScheme, configuration.colorScheme)
            )
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            detach()
            self.window = window
            window.toolbarStyle = .unified
            window.toolbar = toolbar
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }

        func detach() {
            if let window, window.toolbar === toolbar {
                window.toolbar = nil
                window.toolbarStyle = .automatic
                window.standardWindowButton(.zoomButton)?.isEnabled = false
            }
            window = nil
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [Self.brandID, .flexibleSpace, Self.navigationID]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            toolbarDefaultItemIdentifiers(toolbar)
        }

        func toolbar(
            _ toolbar: NSToolbar,
            itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            let host: NSView
            switch itemIdentifier {
            case Self.brandID: host = brandHost
            case Self.navigationID: host = navigationHost
            default: return nil
            }
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = host
            item.isBordered = false
            return item
        }
    }
}
