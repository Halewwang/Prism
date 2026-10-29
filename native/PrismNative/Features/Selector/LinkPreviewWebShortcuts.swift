import WebKit

enum LinkPreviewWebShortcuts {
    static let handlerName = "prismPreviewBrowserShortcut"
    @MainActor static let world = WKContentWorld.world(name: "Prism.LinkPreview.Shortcuts")

    static let source = #"""
    (() => {
        let browserCount = 0;
        const documentID = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const lifecycle = type => window.webkit.messageHandlers.prismPreviewBrowserShortcut.postMessage({type, documentID});
        globalThis.prismSetBrowserShortcutCount = count => { browserCount = Math.max(0, Math.min(9, count)); };
        const editing = node => node instanceof Element && (
            node.isContentEditable || node.closest('input, textarea, select, [role="textbox"], [role="combobox"], [role="spinbutton"], [role="slider"]')
        );
        const editingFocus = () => {
            let active = document.activeElement;
            while (active?.shadowRoot?.activeElement) active = active.shadowRoot.activeElement;
            return editing(active) || (active instanceof Element && active.localName?.includes('-'));
        };
        document.addEventListener('keydown', event => {
            if (!event.isTrusted || event.defaultPrevented || event.isComposing || event.repeat ||
                event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || !/^[1-9]$/.test(event.key) || Number(event.key) > browserCount) return;
            if (document.designMode === 'on' || editingFocus() || event.composedPath().some(editing)) return;
            event.preventDefault();
            event.stopImmediatePropagation();
            window.webkit.messageHandlers.prismPreviewBrowserShortcut.postMessage(event.key);
        }, true);
        window.addEventListener('pagehide', event => { if (event.isTrusted) lifecycle('gone'); });
        window.addEventListener('pageshow', event => { if (event.isTrusted && event.persisted) lifecycle('ready'); });
        lifecycle('ready');
    })();
    """#
}

@MainActor
final class LinkPreviewShortcutMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: LinkPreviewWebModel?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let owner, message.webView === owner.webView else { return }
        if let lifecycle = message.body as? [String: String],
           let documentID = lifecycle["documentID"], !documentID.isEmpty, documentID.count <= 128 {
            switch lifecycle["type"] {
            case "ready": owner.registerShortcutFrame(message.frameInfo, documentID: documentID)
            case "gone": owner.unregisterShortcutFrame(documentID: documentID)
            default: break
            }
            return
        }
        guard let key = message.body as? String, owner.navigationEnabled,
              owner.webView.window?.isVisible == true, owner.webView.window?.isKeyWindow == true,
              owner.webView.window?.attachedSheet == nil, key.count == 1,
              let number = Int(key), (1 ... 9).contains(number) else { return }
        owner.browserShortcutAction?(number)
    }
}
