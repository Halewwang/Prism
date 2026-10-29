import AppKit
import PrismCore
import SwiftUI

struct LinkPreviewView: View {
    @State var model: SelectorViewModel
    @State var web: LinkPreviewWebModel
    let iconProvider: any ApplicationIconProviding
    @FocusState private var browsersFocused: Bool
    @State private var initialBrowserNavigationEnabled = true
    @State private var browserCandidatesVisible = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geometry in
            let candidatesFrame = LinkPreviewMetrics.candidateFrame(windowSize: geometry.size, count: model.browsers.count)
            VStack(spacing: 8) {
                toolbar(width: geometry.size.width)
                if let message = model.accessibleFailureMessage, model.isFailurePresentation || model.previewRequiresRecovery {
                    HStack(spacing: 8) {
                        Text(message).font(.caption).lineLimit(2)
                        Spacer(minLength: 0)
                        if model.canMarkCompleted {
                            Button(String(localized: "selector.markCompleted", defaultValue: "Mark Completed")) {
                                Task { await model.markCompleted() }
                            }
                        }
                    }
                    .foregroundStyle(model.isFailurePresentation ? SelectorPalette.error : SelectorPalette.secondaryText)
                    .accessibilityIdentifier("linkPreview.routingStatus")
                }
                if model.previewRequiresRecovery {
                    ContentUnavailableView {
                        Label(String(localized: "preview.recoveryTitle", defaultValue: "Link waiting for recovery"), systemImage: "arrow.trianglehead.clockwise")
                    } description: {
                        Text(String(localized: "preview.recoveryDetail", defaultValue: "Choose a browser to retry this address, or cancel the link."))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { webContent }
            }
            .padding(7)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(SelectorPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(alignment: .topLeading) {
                if browserCandidatesVisible, geometry.size.width < LinkPreviewMetrics.compactBreakpoint {
                    browserCandidates
                        .frame(width: candidatesFrame.width, height: candidatesFrame.height)
                        .background(SelectorPalette.field, in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(contrast == .increased ? SelectorPalette.highContrastBorder : SelectorPalette.border, lineWidth: contrast == .increased ? 1 : 0.5) }
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                        .offset(x: candidatesFrame.minX, y: candidatesFrame.minY)
                }
            }
            .background(LinkPreviewKeyboardBridge(
                onShortcut: handleBrowserShortcut, onZoom: web.zoom,
                onInitialNavigation: handleInitialBrowserNavigation,
                onPointerDown: { point in
                    if browserCandidatesVisible, !candidatesFrame.contains(point) {
                        browserCandidatesVisible = false
                        browsersFocused = false
                        initialBrowserNavigationEnabled = false
                    }
                },
                onResignKey: { browserCandidatesVisible = false; browsersFocused = false }
            ))
            .onChange(of: geometry.size.width) { _, width in
                if width >= LinkPreviewMetrics.compactBreakpoint { browserCandidatesVisible = false }
            }
        }
        .onAppear {
            web.navigationEnabled = !model.previewRequiresRecovery
            web.updateBrowserShortcuts(count: model.browsers.count)
            web.browserShortcutAction = { [weak model, weak web] number in
                guard let model, let web, model.canActivateShortcut(number) else { return }
                model.previewURL = web.handoffURL
                Task { await model.activateShortcut(number) }
            }
        }
        .onExitCommand { Task { await model.cancel() } }
        .task { await model.prepareForPresentation() }
        .onChange(of: web.currentURL) { _, url in model.previewURL = url }
        .onChange(of: model.browsers.count) { _, count in
            web.updateBrowserShortcuts(count: count)
            if count == 0 { browserCandidatesVisible = false }
        }
        .onChange(of: model.isPerformingAction) { _, performing in
            if performing { browserCandidatesVisible = false }
        }
        .onChange(of: browsersFocused) { _, focused in
            if !focused { browserCandidatesVisible = false }
        }
        .onChange(of: model.previewRequiresRecovery) { _, recovery in
            web.navigationEnabled = !recovery
            if recovery { web.webView.stopLoading() }
        }
    }

    @ViewBuilder
    private func toolbar(width: CGFloat) -> some View {
        let compact = width < LinkPreviewMetrics.compactBreakpoint
        HStack(spacing: compact ? 6 : 5) {
            sourceField(narrow: compact).frame(width: compact ? 48 : 75)
            addressField
                .frame(width: compact ? LinkPreviewMetrics.compactAddressWidth(windowWidth: width) : nil)
                .frame(minWidth: compact ? nil : 120)
            browserControls(width: width)
            cancelButton.frame(width: 64)
        }
    }

    private func sourceField(narrow: Bool) -> some View {
        HStack(spacing: 7) {
            Image(nsImage: sourceIcon).resizable().scaledToFit()
                .frame(width: narrow ? 22 : 19, height: narrow ? 22 : 19)
                .accessibilityHidden(true)
            if !narrow {
                Text(model.sourceDisplayName).font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(.horizontal, narrow ? 0 : 9)
        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
        .background(LinkPreviewWindowDragRegion())
        .previewField(contrast: contrast)
        .overlay(alignment: .topTrailing) {
            if let text = model.pendingBadgeText {
                Text(text).font(.caption2.monospacedDigit())
                    .foregroundStyle(SelectorPalette.badgeForeground)
                    .padding(3).background(SelectorPalette.badgeBackground, in: Circle())
                    .accessibilityLabel(model.pendingAccessibilityValue ?? "")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.sourceHelp)
        .help(model.sourceHelp)
        .accessibilityIdentifier("linkPreview.source")
    }

    private var addressField: some View {
        HStack(spacing: 4) {
            navigationButton("chevron.left", label: String(localized: "preview.back", defaultValue: "Back"), enabled: web.canGoBack && !model.previewRequiresRecovery, id: "back", action: web.goBack)
            navigationButton("chevron.right", label: String(localized: "preview.forward", defaultValue: "Forward"), enabled: web.canGoForward && !model.previewRequiresRecovery, id: "forward", action: web.goForward)
            Text(web.currentURL.absoluteString)
                .font(.system(size: 12)).foregroundStyle(SelectorPalette.secondaryText)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .background(LinkPreviewWindowDragRegion())
                .help(web.currentURL.absoluteString + "\n" + String(localized: "preview.zoomHelp", defaultValue: "Page zoom: ⌘+ / ⌘− / ⌘0; pinch to zoom"))
                .accessibilityIdentifier("linkPreview.url")
            navigationButton("arrow.clockwise", label: String(localized: "preview.reload", defaultValue: "Reload"), enabled: !model.previewRequiresRecovery, id: "reload", action: web.reload)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .previewField(contrast: contrast)
        .contextMenu {
            Text(String(format: String(localized: "preview.zoomLevelFormat", defaultValue: "Page zoom: %ld%%"), web.zoomPercentage))
            Divider()
            Button(String(localized: "preview.zoomIn", defaultValue: "Zoom In (⌘+)")) { web.zoom(.zoomIn) }
            Button(String(localized: "preview.zoomOut", defaultValue: "Zoom Out (⌘−)")) { web.zoom(.zoomOut) }
            Button(String(localized: "preview.zoomReset", defaultValue: "Actual Size (⌘0)")) { web.zoom(.reset) }
        }
    }

    private func browserControls(width: CGFloat) -> some View {
        browserGroup(width: width)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("linkPreview.browserGroup")
            .focusable().focused($browsersFocused).focusEffectDisabled()
            .onKeyPress(.leftArrow) {
                guard browsersFocused else { return .ignored }
                moveBrowserSelection(previous: true, revealCandidates: width < LinkPreviewMetrics.compactBreakpoint); return .handled
            }
            .onKeyPress(.rightArrow) {
                guard browsersFocused else { return .ignored }
                moveBrowserSelection(previous: false, revealCandidates: width < LinkPreviewMetrics.compactBreakpoint); return .handled
            }
            .onKeyPress(.upArrow) {
                guard width < LinkPreviewMetrics.compactBreakpoint, browsersFocused else { return .ignored }
                moveBrowserSelection(previous: true, revealCandidates: true); return .handled
            }
            .onKeyPress(.downArrow) {
                guard width < LinkPreviewMetrics.compactBreakpoint, browsersFocused else { return .ignored }
                moveBrowserSelection(previous: false, revealCandidates: true); return .handled
            }
            .onKeyPress(.return) {
                guard browsersFocused else { return .ignored }
                activateSelected(); return .handled
            }
    }

    private func navigationButton(_ icon: String, label: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            initialBrowserNavigationEnabled = false
            browserCandidatesVisible = false
            browsersFocused = false
            action()
        } label: {
            Image(systemName: icon).font(.system(size: 13))
                .frame(width: 22, height: 32).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled)
        .foregroundStyle(enabled ? SelectorPalette.secondaryText : SelectorPalette.secondaryText.opacity(0.3))
        .accessibilityLabel(label).help(label)
        .accessibilityIdentifier("linkPreview.\(id)")
    }

    private var cancelButton: some View {
        Button { Task { await model.cancel() } } label: {
            HStack(spacing: 5) {
                Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(SelectorPalette.secondaryText)
                Text("esc")
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain).previewField(contrast: contrast)
        .disabled(model.isPerformingAction)
        .accessibilityLabel(String(localized: "preview.closeEsc", defaultValue: "Close preview (Esc)"))
        .accessibilityIdentifier("linkPreview.cancel")
    }

    @ViewBuilder private func browserGroup(width: CGFloat) -> some View {
        if width < LinkPreviewMetrics.compactBreakpoint, let selected = model.selectedBrowser {
            HStack(spacing: 6) {
                choice(selected, index: model.selectedIndex)
                VStack(spacing: 2) {
                    browserStepButton(previous: true)
                    browserStepButton(previous: false)
                }
            }
            .padding(3)
            .frame(width: LinkPreviewMetrics.compactBrowserWidth, height: 48)
            .previewField(contrast: contrast)
        } else if let first = model.browsers.first {
            HStack(spacing: 6) {
                choice(first, index: 0)
                if model.browsers.count > 1 {
                    Rectangle().fill(SelectorPalette.border).frame(width: 0.5, height: 42)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            HStack(spacing: LinkPreviewMetrics.browserGap) {
                                ForEach(Array(model.browsers.dropFirst().enumerated()), id: \.element.id) { offset, browser in
                                    choice(browser, index: offset + 1).id(browser.id)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .frame(width: LinkPreviewMetrics.scrollingWidth(count: model.browsers.count - 1, windowWidth: width), height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .onChange(of: model.revealBrowserID) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
                    }
                }
            }
            .padding(3)
            .frame(height: 48)
            .previewField(contrast: contrast)
        } else {
            HStack(spacing: 8) {
                Button { Task { await model.rescan() } } label: {
                    Group {
                        if model.isLoading { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.clockwise") }
                    }.frame(width: 16, height: 16)
                }
                    .disabled(!model.canRescan)
                    .accessibilityLabel(String(localized: "selector.rescan", defaultValue: "Rescan browsers"))
                    .help(String(localized: "selector.rescan", defaultValue: "Rescan browsers"))
                Button(action: model.openBrowserManagement) { Image(systemName: "globe") }
                    .accessibilityLabel(String(localized: "selector.manageBrowsers", defaultValue: "Manage browsers"))
                    .help(String(localized: "selector.manageBrowsers", defaultValue: "Manage browsers"))
            }
            .buttonStyle(.plain).padding(.horizontal, 12)
            .frame(width: width < LinkPreviewMetrics.compactBreakpoint ? LinkPreviewMetrics.compactBrowserWidth : nil, height: 48)
            .previewField(contrast: contrast)
        }
    }

    private func browserStepButton(previous: Bool) -> some View {
        let label = previous
            ? String(localized: "preview.previousBrowser", defaultValue: "Previous browser (↑)")
            : String(localized: "preview.nextBrowser", defaultValue: "Next browser (↓)")
        return Button {
            moveBrowserSelection(previous: previous, revealCandidates: true)
        } label: {
            Image(systemName: previous ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .frame(width: 16, height: 20)
                .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain).focusable(false)
        .foregroundStyle(SelectorPalette.secondaryText)
        .disabled(model.isPerformingAction || model.browsers.count < 2)
        .accessibilityLabel(label).help(label)
        .accessibilityIdentifier(previous ? "linkPreview.previousBrowser" : "linkPreview.nextBrowser")
    }

    private func choice(_ browser: BrowserDescriptor, index: Int) -> some View {
        LinkPreviewBrowserChoice(
            icon: iconProvider.icon(for: browser.applicationURL),
            shortcut: model.shortcut(forBrowserAt: index),
            selected: model.selectedIndex == index,
            accessibilityLabel: model.browserAccessibilityLabel(at: index),
            action: { activateBrowser(browser.id) }
        )
        .disabled(model.isPerformingAction)
        .help(index == 0
            ? String(format: String(localized: "preview.recommended", defaultValue: "%@ · Recommended"), browser.displayName)
            : browser.displayName)
        .accessibilityIdentifier("linkPreview.browser.\(index + 1)")
    }

    private var webContent: some View {
        LinkPreviewWebView(model: web)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if web.isLoading { ProgressView(value: web.progress).progressViewStyle(.linear).tint(.accentColor) }
            }
            .overlay(alignment: .top) {
                if let error = web.errorMessage {
                    HStack {
                        Text(error).font(.callout).textSelection(.enabled)
                        Spacer(minLength: 8)
                        Button(String(localized: "preview.reload", defaultValue: "Reload"), action: web.reload)
                    }
                    .padding(14).background(SelectorPalette.field)
                    .accessibilityIdentifier("linkPreview.loadError")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(SelectorPalette.border, lineWidth: 0.5) }
    }

    private var browserCandidates: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: LinkPreviewMetrics.candidateRowSpacing) {
                    ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                        LinkPreviewBrowserChoice(
                            icon: iconProvider.icon(for: browser.applicationURL),
                            shortcut: model.shortcut(forBrowserAt: index), selected: model.selectedIndex == index,
                            accessibilityLabel: model.browserAccessibilityLabel(at: index),
                            action: { activateBrowser(browser.id) }
                        )
                        .focusable(false)
                        .help(browser.displayName)
                        .accessibilityAddTraits(model.selectedIndex == index ? .isSelected : [])
                        .disabled(model.isPerformingAction)
                        .id(browser.id)
                        .accessibilityIdentifier("linkPreview.candidate.\(index + 1)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: LinkPreviewMetrics.innerRadius))
            .padding(LinkPreviewMetrics.candidateInset)
            .onAppear { if let id = model.selectedBrowser?.id { proxy.scrollTo(id) } }
            .onChange(of: model.selectedIndex) { _, _ in
                if let id = model.selectedBrowser?.id { proxy.scrollTo(id) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("linkPreview.browserCandidates")
    }

    private func moveBrowserSelection(previous: Bool, revealCandidates: Bool) {
        guard !model.isPerformingAction, !model.browsers.isEmpty else { return }
        if previous { model.selectPrevious() } else { model.selectNext() }
        if revealCandidates {
            browserCandidatesVisible = true
            browsersFocused = true
        }
    }
    private func activateBrowser(_ id: BrowserID) {
        browserCandidatesVisible = false
        model.previewURL = web.handoffURL
        Task { await model.activateBrowser(id: id) }
    }
    private func activateSelected() {
        browserCandidatesVisible = false
        model.previewURL = web.handoffURL
        Task { await model.activateSelected() }
    }
    private func handleInitialBrowserNavigation(_ action: LinkPreviewBrowserNavigationAction) -> Bool {
        guard initialBrowserNavigationEnabled, !model.isPerformingAction, model.selectedBrowser != nil else { return false }
        switch action {
        case .previous: moveBrowserSelection(previous: true, revealCandidates: true)
        case .next: moveBrowserSelection(previous: false, revealCandidates: true)
        case .activate: activateSelected()
        }
        return true
    }
    private func handleBrowserShortcut(_ number: Int) -> Bool {
        guard model.canActivateShortcut(number) else { return false }
        browserCandidatesVisible = false
        model.previewURL = web.handoffURL
        Task { await model.activateShortcut(number) }
        return true
    }
    private var sourceIcon: NSImage {
        model.source.bundleIdentifier.flatMap { iconProvider.icon(bundleIdentifier: $0) }
            ?? NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
    }
}

private struct LinkPreviewBrowserChoice: View {
    let icon: NSImage
    let shortcut: Int?
    let selected: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(nsImage: icon).resizable().scaledToFit().frame(width: 22, height: 22)
                if let shortcut {
                    Text(String(shortcut)).font(.system(size: 8).monospacedDigit())
                        .foregroundStyle(SelectorPalette.secondaryText).frame(width: 14, height: 14)
                        .background(SelectorPalette.shortcutBackground, in: RoundedRectangle(cornerRadius: 4))
                        .overlay { RoundedRectangle(cornerRadius: 4).stroke(SelectorPalette.border, lineWidth: 0.5) }
                } else { Color.clear.frame(width: 14, height: 14) }
            }
            .frame(width: 42, height: 42)
            .background(selected || hovered ? SelectorPalette.selected : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension View {
    func previewField(contrast: ColorSchemeContrast) -> some View {
        background(SelectorPalette.field, in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(contrast == .increased ? SelectorPalette.highContrastBorder : SelectorPalette.border, lineWidth: contrast == .increased ? 1 : 0.5) }
    }
}
