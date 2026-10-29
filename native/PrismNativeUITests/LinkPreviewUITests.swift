import AppKit
import XCTest

final class LinkPreviewUITests: XCTestCase {
    private var application: XCUIApplication?

    override func tearDown() {
        if let application, application.state != .notRunning { application.terminate() }
        application = nil
        super.tearDown()
    }

    func testRealWebNavigationBackForwardAndTypingStayInsideThePreview() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)
        let input = app.textFields["Preview input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Start the HTTP fixture on 127.0.0.1:18771 before this test")
        input.click()
        input.typeText("123")
        XCTAssertEqual(input.value as? String, "123")
        XCTAssertTrue(panel.exists, "Typing browser shortcut digits into a page must not launch a browser")

        let next = app.links["Go to next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.click()
        XCTAssertTrue(waitUntil { self.urlText(in: panel).hasSuffix("/next") })
        XCTAssertTrue(app.staticTexts["Next fixture page"].waitForExistence(timeout: 5))

        let back = element("linkPreview.back", in: panel)
        XCTAssertTrue(back.isEnabled)
        back.click()
        XCTAssertTrue(waitUntil { self.urlText(in: panel).hasSuffix("/start") })
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        let forward = element("linkPreview.forward", in: panel)
        XCTAssertTrue(forward.isEnabled)
        forward.click()
        XCTAssertTrue(waitUntil { self.urlText(in: panel).hasSuffix("/next") })
        XCTAssertTrue(panel.exists)
        attach(panel, name: "link-preview-real-web-navigation")
    }

    func testBrowserNumberShortcutHandsOffAndClosesThePreview() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)

        panel.typeKey("2", modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists })
    }

    func testBrowserNumberShortcutAfterScanWorksFromWebContent() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "好的界面")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.click()

        panel.typeKey("2", modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists }, "A page body must not swallow the browser shortcut")
    }

    func testEscapeFromWebInputCancelsPreviewAndButtonShowsShortcut() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)
        let cancel = element("linkPreview.cancel", in: panel)
        XCTAssertTrue(cancel.label.lowercased().contains("esc"), "The cancel button must expose its Esc shortcut")
        let input = app.textFields["Preview input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.click()
        input.typeText("123")
        XCTAssertEqual(input.value as? String, "123")
        XCTAssertTrue(panel.exists)

        input.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists }, "Esc must cancel while the page input has focus")
    }

    func testReturnOnNavigationButtonDoesNotHandOffToBrowser() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)
        let input = app.textFields["Preview input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let reload = element("linkPreview.reload", in: panel)
        reload.click()

        reload.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.exists, "Return on Reload must not activate the selected browser")
        XCTAssertTrue(element("linkPreview.browser.2", in: panel).exists)
    }

    func testReturnAfterCompactReloadDoesNotHandOffToBrowser() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)
        let input = app.textFields["Preview input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))

        panel.typeKey(.downArrow, modifierFlags: [])
        _ = element("linkPreview.browserCandidates", in: panel)
        element("linkPreview.reload", in: panel).click()
        panel.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.exists, "Return after clicking Reload must not activate the compact browser selector")
        XCTAssertFalse(panel.descendants(matching: .any).matching(identifier: "linkPreview.browserCandidates").firstMatch.exists)
        XCTAssertTrue(panel.descendants(matching: .any).matching(identifier: "linkPreview.browser.2").firstMatch.exists)
    }

    func testCancelClosesThePreview() {
        let app = launchPreview()
        let panel = previewPanel(in: app)

        element("linkPreview.cancel", in: panel).click()

        XCTAssertTrue(waitUntil { !panel.exists })
    }

    func testBrowserIdentitySurvivesRedirectAndMatchesJavaScript() throws {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        let link = app.links["Check browser identity"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.click()
        XCTAssertTrue(waitUntil { self.urlText(in: panel).hasSuffix("/ua") })
        let version = try XCTUnwrap(Bundle(url: URL(fileURLWithPath: "/Applications/Safari.app"))?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        XCTAssertTrue(app.staticTexts["Safari Version: \(version)"].waitForExistence(timeout: 5))
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "HTTP User-Agent: ")).firstMatch
        let javascript = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Navigator User-Agent: ")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(javascript.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label.replacingOccurrences(of: "HTTP User-Agent: ", with: ""),
            javascript.label.replacingOccurrences(of: "Navigator User-Agent: ", with: ""))
        XCTAssertTrue(panel.exists)
    }

    func testCommandZoomFromPageAndInputPreservesWindowAndText() {
        let app = launchPreview()
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.2", in: panel)
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "好的界面")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let originalFrame = panel.frame
        title.click()
        panel.typeKey("=", modifierFlags: .command)
        assertPageZoom(110, in: panel, application: app)

        let input = app.textFields["Preview input"]
        input.click()
        input.typeText("123")
        input.typeKey("-", modifierFlags: .command)
        assertPageZoom(100, in: panel, application: app)
        input.click()
        input.typeKey("=", modifierFlags: .command)
        input.typeKey("0", modifierFlags: .command)
        assertPageZoom(100, in: panel, application: app)
        XCTAssertEqual(input.value as? String, "123")
        XCTAssertEqual(panel.frame, originalFrame, "Page zoom must not resize the preview window")
    }

    func testNarrowToolbarKeepsCompactBrowserControlsOnOneRow() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        let selected = element("linkPreview.browser.1", in: panel)
        let source = element("linkPreview.source", in: panel)
        let back = element("linkPreview.back", in: panel)
        let reload = element("linkPreview.reload", in: panel)
        let browsers = element("linkPreview.browserGroup", in: panel)
        let previous = element("linkPreview.previousBrowser", in: panel)
        let next = element("linkPreview.nextBrowser", in: panel)
        let cancel = element("linkPreview.cancel", in: panel)

        XCTAssertEqual(panel.frame.width, 360, accuracy: 1)
        XCTAssertEqual(panel.frame.height, 640, accuracy: 1)
        XCTAssertEqual(source.frame.width, 48, accuracy: 1)
        XCTAssertEqual(source.frame.height, 48, accuracy: 1)
        XCTAssertEqual(browsers.frame.width, 70, accuracy: 1)
        XCTAssertEqual(browsers.frame.height, 48, accuracy: 1)
        XCTAssertEqual(cancel.frame.height, 48, accuracy: 1)
        XCTAssertEqual(source.frame.midY, browsers.frame.midY, accuracy: 1)
        XCTAssertEqual(source.frame.midY, cancel.frame.midY, accuracy: 1)
        XCTAssertEqual(back.frame.midY, source.frame.midY, accuracy: 1)
        XCTAssertEqual(reload.frame.midY, source.frame.midY, accuracy: 1)
        XCTAssertEqual(selected.frame.midY, browsers.frame.midY, accuracy: 1)
        XCTAssertEqual(previous.frame.midX, next.frame.midX, accuracy: 1)
        XCTAssertTrue(previous.isEnabled)
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual(panel.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "linkPreview.browser.")).count, 1)
        XCTAssertFalse(panel.descendants(matching: .any).matching(identifier: "linkPreview.browser.2").firstMatch.exists)
        XCTAssertEqual(cancel.frame.minX - browsers.frame.maxX, 6, accuracy: 1)
        XCTAssertLessThanOrEqual(cancel.frame.maxX, panel.frame.maxX - 6)
        XCTAssertEqual(browsers.frame.minX - reload.frame.maxX - 6, back.frame.minX - source.frame.maxX - 6, accuracy: 1)
        attach(panel, name: "link-preview-narrow-toolbar")
    }

    func testCompactBrowserSteppersAndArrowKeysSelectBeforeReturnHandsOff() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)

        panel.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(panel.descendants(matching: .any).matching(identifier: "linkPreview.browser.2").firstMatch.waitForExistence(timeout: 5),
            "Down must select the next browser immediately after presentation, before any pointer interaction")
        _ = element("linkPreview.browserCandidates", in: panel)
        XCTAssertTrue(element("linkPreview.candidate.2", in: panel).label.contains("Selected"))
        panel.typeKey(.upArrow, modifierFlags: [])
        _ = element("linkPreview.browser.1", in: panel)
        XCTAssertTrue(element("linkPreview.candidate.1", in: panel).label.contains("Selected"))

        element("linkPreview.previousBrowser", in: panel).click()
        _ = element("linkPreview.browser.8", in: panel)
        element("linkPreview.nextBrowser", in: panel).click()
        _ = element("linkPreview.browser.1", in: panel)

        panel.typeKey(.downArrow, modifierFlags: [])
        _ = element("linkPreview.browser.2", in: panel)
        XCTAssertTrue(element("linkPreview.candidate.2", in: panel).label.contains("Selected"))
        XCTAssertTrue(panel.exists, "Changing the selected browser must not open it")

        panel.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists })
    }

    func testClickOutsideCompactCandidatesDirectlyFocusesWebInput() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)
        let input = app.textFields["Preview input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        panel.typeKey(.downArrow, modifierFlags: [])
        let candidates = element("linkPreview.browserCandidates", in: panel)

        input.click()
        XCTAssertTrue(waitUntil { !candidates.exists }, "One click in the page must dismiss candidates without swallowing that click")
        input.typeText("123")
        input.typeKey(.upArrow, modifierFlags: [])
        input.typeKey(.downArrow, modifierFlags: [])
        input.typeKey(.return, modifierFlags: [])

        XCTAssertEqual(input.value as? String, "123")
        XCTAssertTrue(panel.exists, "Typing and editing in the page must not hand off to a browser")
        XCTAssertTrue(panel.descendants(matching: .any).matching(identifier: "linkPreview.browser.2").firstMatch.exists,
            "Page input arrow keys must not change the compact browser selection")
    }

    func testNumberShortcutHandsOffWhileCompactCandidatesAreOpen() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)
        panel.typeKey(.downArrow, modifierFlags: [])
        _ = element("linkPreview.browserCandidates", in: panel)

        panel.typeKey("3", modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists })
    }

    func testClickingCompactCandidateHandsOff() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)
        panel.typeKey(.downArrow, modifierFlags: [])

        element("linkPreview.candidate.3", in: panel).click()

        XCTAssertTrue(waitUntil { !panel.exists })
    }

    func testEscapeClosesPreviewWhileCompactCandidatesAreOpen() {
        let app = launchPreview(narrow: true)
        let panel = previewPanel(in: app)
        _ = element("linkPreview.browser.1", in: panel)
        panel.typeKey(.downArrow, modifierFlags: [])
        _ = element("linkPreview.browserCandidates", in: panel)

        panel.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(waitUntil { !panel.exists }, "Esc must close the entire preview, including its candidates")
    }

    private func launchPreview(narrow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-AppleKeyboardUIMode", "3",
            "--ui-testing", "--selector-harness", narrow ? "previewNarrow" : "preview",
            "--selector-appearance", "light",
        ]
        application = app
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
        return app
    }

    private func previewPanel(in app: XCUIApplication) -> XCUIElement {
        let panel = app.descendants(matching: .any).matching(identifier: "linkPreview.panel").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 8))
        return panel
    }

    private func element(_ identifier: String, in panel: XCUIElement) -> XCUIElement {
        let element = panel.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(identifier)")
        return element
    }

    private func urlText(in panel: XCUIElement) -> String {
        let url = panel.descendants(matching: .any).matching(identifier: "linkPreview.url").firstMatch
        return url.value as? String ?? url.label
    }

    private func assertPageZoom(_ percentage: Int, in panel: XCUIElement, application: XCUIApplication) {
        element("linkPreview.url", in: panel).rightClick()
        XCTAssertTrue(application.menuItems["Page zoom: \(percentage)%"].waitForExistence(timeout: 3))
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(panel.exists)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        } while Date() < deadline
        return condition()
    }

    private func attach(_ panel: XCUIElement, name: String) {
        let attachment = XCTAttachment(screenshot: panel.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
