import XCTest

@MainActor final class UpdateUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--update-harness"]
        app.launch()
    }
    override func tearDown() { app.terminate() }
    func testDownloadVerifiesBeforeOfferingInstallAndPendingLinksKeepAppOpen() {
        let download = app.buttons["update.download"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["update.install"].exists)
        download.click()
        XCTAssertTrue(app.buttons["update.cancel"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["update.ready"].waitForExistence(timeout: 8))
        let install = app.buttons["update.install"]
        XCTAssertTrue(install.isEnabled)
        install.click()
        XCTAssertTrue(app.staticTexts["update.message"].waitForExistence(timeout: 3))
        XCTAssertTrue(install.isEnabled)
        XCTAssertEqual(app.state, .runningForeground)
    }
    func testCancellationAllowsFreshDownload() {
        app.buttons["update.download"].click()
        let cancel = app.buttons["update.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        cancel.click()
        XCTAssertTrue(app.buttons["update.download"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["update.install"].exists)
    }
    func testUpdateWindowUsesOneContentInsetAndKeepsActionsStationaryInBothLanguages() {
        for language in ["en", "zh-Hans"] {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--update-harness", "-AppleLanguages", "(\(language))"]
            app.launch()
            let download = app.buttons["update.download"]
            XCTAssertTrue(download.waitForExistence(timeout: 5))
            let window = app.windows.firstMatch
            let initialFrame = window.frame
            let actionBottom = download.frame.maxY
            let notes = app.scrollViews["update.releaseNotes"]
            XCTAssertTrue(notes.exists)
            XCTAssertEqual(app.staticTexts["update.title"].frame.minX, initialFrame.minX + 40, accuracy: 2)
            XCTAssertEqual(notes.frame.minX, initialFrame.minX + 40, accuracy: 2)
            XCTAssertEqual(notes.frame.maxX, initialFrame.maxX - 40, accuracy: 2)
            XCTAssertEqual(download.frame.maxX, initialFrame.maxX - 40, accuracy: 2)
            XCTAssertEqual(actionBottom, initialFrame.maxY - 40, accuracy: 2)
            XCTAssertGreaterThan(notes.frame.height, 100)

            download.click()
            let consent = app.checkBoxes["update.allowUnnotarizedPublicTestUpdate"]
            XCTAssertTrue(consent.waitForExistence(timeout: 8))
            XCTAssertTrue(consent.isHittable)
            XCTAssertEqual(window.frame, initialFrame)
            XCTAssertGreaterThan(notes.frame.height, 80)
            let install = app.buttons["update.install"]
            XCTAssertEqual(install.frame.maxY, actionBottom, accuracy: 2)
            XCTAssertEqual(install.frame.maxX, initialFrame.maxX - 40, accuracy: 2)
            XCTAssertEqual(consent.frame.minX, initialFrame.minX + 40, accuracy: 2)
            XCTAssertTrue(install.isHittable)

            install.click()
            XCTAssertTrue(app.staticTexts["update.message"].waitForExistence(timeout: 3))
            XCTAssertEqual(window.frame, initialFrame)
            XCTAssertEqual(install.frame.maxY, actionBottom, accuracy: 2)
            XCTAssertTrue(consent.isHittable)
            XCTAssertTrue(install.isHittable)
        }
    }
    func testUnnotarizedPublicTestConsentStartsOffAndCanBeEnabled() {
        for (language, label) in [
            ("en", "Allow this unnotarized public-test update"),
            ("zh-Hans", "允许安装此次未公证公测更新")
        ] {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--update-harness", "-AppleLanguages", "(\(language))"]
            app.launch()
            XCTAssertFalse(app.checkBoxes["update.allowUnnotarizedPublicTestUpdate"].exists)
            app.buttons["update.download"].click()
            let consent = app.checkBoxes["update.allowUnnotarizedPublicTestUpdate"]
            XCTAssertTrue(consent.waitForExistence(timeout: 8))
            XCTAssertEqual(consent.label, label)
            XCTAssertEqual(consent.value as? NSNumber, NSNumber(value: false))
            consent.click()
            XCTAssertEqual(consent.value as? NSNumber, NSNumber(value: true))
            XCTAssertTrue(app.buttons["update.install"].isEnabled)
            XCTAssertTrue(app.buttons["update.install"].isHittable)
        }
    }
}
