import JavaScriptCore
import Testing
@testable import PrismNative

@Suite("Preview web keyboard filtering")
struct LinkPreviewWebShortcutTests {
    @Test func realDigitsOnPageBodyRequestBrowserAndConsumeTheKey() throws {
        let context = try makeContext()
        #expect(context.evaluateScript("press({})")?.toString() == "2:true")
        #expect(context.evaluateScript("press({key:'9'})")?.toString() == "9:true")
    }

    @Test func editingAndCompositionKeepNumbersInsideThePage() throws {
        let context = try makeContext()
        #expect(context.evaluateScript("press({}, [new Element(true, false)])")?.toString() == "none:false")
        #expect(context.evaluateScript("press({}, [new Element(false, true)])")?.toString() == "none:false")
        #expect(context.evaluateScript("document.activeElement=new Element(true,false); press({})")?.toString() == "none:false")
        #expect(context.evaluateScript("document.activeElement=null; press({isComposing:true})")?.toString() == "none:false")
        #expect(context.evaluateScript("document.designMode='on'; press({})")?.toString() == "none:false")
    }

    @Test func syntheticEventsModifiersRepeatsAndOtherKeysCannotRequestHandoff() throws {
        let context = try makeContext()
        for value in ["{isTrusted:false}", "{metaKey:true}", "{ctrlKey:true}", "{altKey:true}", "{shiftKey:true}", "{repeat:true}", "{key:'0'}", "{key:'Enter'}", "{key:'ArrowLeft'}"] {
            #expect(context.evaluateScript("press(\(value))")?.toString() == "none:false")
        }
    }

    @Test func unavailableNumbersAndShadowEditorsKeepNativePageInput() throws {
        let context = try makeContext()
        #expect(context.evaluateScript("prismSetBrowserShortcutCount(2); press({key:'9'})")?.toString() == "none:false")
        #expect(context.evaluateScript("document.activeElement=Object.assign(new Element(false,false),{localName:'custom-editor'}); press({})")?.toString() == "none:false")
        #expect(context.evaluateScript("document.activeElement=Object.assign(new Element(false,false),{shadowRoot:{activeElement:new Element(true,false)}}); press({})")?.toString() == "none:false")
    }

    @Test func documentLifecycleUnregistersRemovedFramesAndRestoresCachedPages() throws {
        let context = try makeContext()
        #expect(context.evaluateScript("received.type + ':' + received.documentID")?.toString() == "ready:audit-document")
        #expect(context.evaluateScript("lifecycle.pagehide({isTrusted:true}); received.type")?.toString() == "gone")
        #expect(context.evaluateScript("lifecycle.pageshow({isTrusted:true,persisted:true}); received.type")?.toString() == "ready")
        #expect(context.evaluateScript("received='untouched'; lifecycle.pagehide({isTrusted:false}); received")?.toString() == "untouched")
        #expect(context.evaluateScript("lifecycle.pageshow({isTrusted:true,persisted:false}); received")?.toString() == "untouched")
    }

    private func makeContext() throws -> JSContext {
        let context = try #require(JSContext())
        context.evaluateScript("""
        let listener, received, prevented;
        const lifecycle = {};
        globalThis.crypto={randomUUID:()=> 'audit-document'};
        class Element {
            constructor(editable, field) { this.isContentEditable=editable; this.field=field; this.localName='div'; }
            closest() { return this.field ? this : null; }
        }
        globalThis.document={designMode:'off', activeElement:null, addEventListener:(_, callback)=>listener=callback};
        globalThis.window={addEventListener:(name, callback)=>lifecycle[name]=callback,
            webkit:{messageHandlers:{prismPreviewBrowserShortcut:{postMessage:n=>received=n}}}};
        function press(options, path=[]) {
            received='none'; prevented=false;
            const event=Object.assign({key:'2', isTrusted:true, isComposing:false, repeat:false,
                metaKey:false, ctrlKey:false, altKey:false, shiftKey:false, defaultPrevented:false,
                composedPath:()=>path, preventDefault:()=>prevented=true, stopImmediatePropagation:()=>{}}, options);
            listener(event);
            return received+':'+prevented;
        }
        """)
        context.evaluateScript(LinkPreviewWebShortcuts.source)
        context.evaluateScript("prismSetBrowserShortcutCount(9)")
        #expect(context.exception == nil)
        return context
    }
}
