import XCTest

final class AppShellUITests: PrismUITestCase {
    func testFloatingNavigationKeepsPagesSelectedAndRulesUseTheWindowWidth() throws {
        let application = launchFixture("workspace", appearance: .light)
        let window = requireMainWindow(in: application)
        XCTAssertEqual(window.frame.width, 800, accuracy: 1)
        let history = requireElement("appShell.sidebar.history", in: application)
        let rules = requireElement("appShell.sidebar.rules", in: application)
        let settings = requireElement("appShell.sidebar.settings", in: application)
        let brand = requireElement("appShell.sidebar.brand", in: application)

        XCTAssertEqual(history.frame.midY, rules.frame.midY, accuracy: 2)
        XCTAssertEqual(rules.frame.midY, settings.frame.midY, accuracy: 2)
        XCTAssertLessThan(brand.frame.maxX, history.frame.minX)
        XCTAssertEqual(brand.frame.minX, window.frame.minX + 10, accuracy: 1)
        XCTAssertEqual(
            min(brand.frame.minY - window.frame.minY, window.frame.maxY - brand.frame.maxY),
            10,
            accuracy: 1
        )
        XCTAssertEqual(window.buttons["_XCUI:CloseWindow"].frame.midY, brand.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(window.buttons["_XCUI:CloseWindow"].frame.minX, brand.frame.minX)
        XCTAssertLessThan(window.buttons["_XCUI:CloseWindow"].frame.maxX, brand.frame.maxX)

        rules.click()
        let list = requireElement("rules.list", in: application)
        XCTAssertTrue(window.buttons["_XCUI:CloseWindow"].isHittable)
        XCTAssertTrue(window.buttons["_XCUI:MinimizeWindow"].isHittable)
        XCTAssertTrue(rules.isSelected)
        XCTAssertFalse(history.isSelected)
        XCTAssertEqual(list.frame.minX, window.frame.minX + 16, accuracy: 2)
        XCTAssertGreaterThan(list.frame.width, window.frame.width - 40)
        XCTAssertFalse(application.staticTexts["appShell.page.rules.heading"].exists)

        settings.click()
        _ = requireElement("appShell.page.settings.content", in: application)
        XCTAssertTrue(window.buttons["_XCUI:CloseWindow"].isHittable)
        XCTAssertTrue(window.buttons["_XCUI:MinimizeWindow"].isHittable)
        XCTAssertFalse(window.buttons["_XCUI:ZoomWindow"].isEnabled)
        XCTAssertTrue(settings.isSelected)
        XCTAssertFalse(rules.isSelected)
        XCTAssertTrue(requireElement("settings.automaticRules", in: application).isHittable)
        try attachWindowScreenshot("floating-navigation-settings", application: application, appearance: .light)

        window.buttons["_XCUI:CloseWindow"].click()
        XCTAssertTrue(waitUntil(timeout: 3) { application.windows.count == 0 })
    }

    func testSourceRuleEditorKeepsFooterVisibleAndPickerRestoresKeyboardFocus() throws {
        let application = launchFixture("workspace", appearance: .light)
        let window = requireMainWindow(in: application)
        requireElement("appShell.sidebar.rules", in: application).click()
        let actions = requireElement("rules.rule.00000000-0000-0000-0000-000000000303.actions", in: application)
        XCTAssertTrue(actions.debugDescription.contains("Actions for rule Messages"))
        actions.click()
        let edit = application.menuItems["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.click()
        requireButton("rules.editor.condition", in: application).click()
        let sourceSearch = requireElement("workspace.picker.search.Source application", in: application)
        sourceSearch.typeKey(.escape, modifierFlags: [])
        let save = requireButton("rules.editor.save", in: application)
        let match = requireButton("rules.editor.match", in: application)
        XCTAssertEqual(match.value as? String, "Source application")
        match.click()
        let exactDomain = application.buttons["Exact domain"].firstMatch
        XCTAssertTrue(exactDomain.waitForExistence(timeout: 3))
        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitUntil(timeout: 3) { !exactDomain.exists })
        XCTAssertTrue(save.exists && match.exists, "Escape must close only the picker, keeping the editor available")
        XCTAssertEqual(match.value as? String, "Source application")
        window.typeKey(.space, modifierFlags: [])
        guard exactDomain.waitForExistence(timeout: 3) else {
            XCTFail("Closing the picker must restore keyboard focus to its trigger")
            return
        }
        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(save.exists && match.exists)
        XCTAssertTrue(save.isHittable, "The footer must remain available for the taller source-application form")
        try attachWindowScreenshot("review-source-rule-editor", application: application, appearance: .light)
        application.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(waitUntil(timeout: 3) { !save.exists })
    }

    func testBrowserManagementOpensFromApplicationMenu() throws {
        let application = launchFixture("workspace", appearance: .light)
        requireElement("appShell.sidebar.settings", in: application).click()
        application.menuBars.menuBarItems["Prism"].click()
        application.menuItems["Manage Browsers"].click()
        _ = requireButton("browsers.rescan", in: application)
        _ = requireButton("browsers.add", in: application)
        try attachWindowScreenshot("review-browser-management", application: application, appearance: .light)
        requireButton("browsers.done", in: application).click()
    }

    func testShellExposesRealRulesBrowsersAndSettingsPages() throws {
        let application = launchFixture("history", appearance: .light)

        _ = requireElement("appShell.page.history.content", in: application)
        _ = requireElement("appShell.sidebar.brand", in: application)
        XCTAssertFalse(application.buttons["appShell.openSettings"].exists)

        requireElement("appShell.sidebar.rules", in: application).click()
        _ = requireElement("appShell.page.rules.content", in: application)
        _ = requirePageStateTitle("Start with your first rule", kind: "empty", in: application)
        _ = requireButton("rules.emptyCreate", in: application)
        _ = requireButton("rules.create", in: application)
        try attachWindowScreenshot(
            "rules-management",
            application: application,
            appearance: .light
        )

        requireElement("appShell.sidebar.settings", in: application).click()
        _ = requireElement("appShell.page.settings.content", in: application)
        _ = requireElement("settings.showMenuBarItem", in: application)
        _ = requireElement("settings.automaticRules", in: application)
        _ = requireElement("settings.historyEnabled", in: application)
        _ = requireElement("settings.setDefaultHandler", in: application)
        _ = requireElement("settings.launchAtLogin", in: application)
        let automaticUpdateChecks = requireElement("settings.automaticUpdateChecks", in: application)
        XCTAssertFalse(automaticUpdateChecks.isEnabled)
        XCTAssertTrue(application.buttons["settings.checkForUpdates"].exists)
        XCTAssertFalse(application.buttons["settings.checkForUpdates"].isEnabled)
        try attachWindowScreenshot(
            "settings-management",
            application: application,
            appearance: .light
        )
        XCTAssertEqual(application.windows.count, 1)
    }

    func testWorkspaceRulesKeepPriorityActionable() throws {
        let application = launchFixture("workspace", appearance: .dark)

        requireElement("appShell.sidebar.rules", in: application).click()
        _ = requireElement("appShell.page.rules.content", in: application)
        let list = requireElement("rules.list", in: application)
        let ruleActions = list.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "rules.rule.", ".actions")
        )
        XCTAssertEqual(ruleActions.count, 3, "URL and application rules must share one list")
        XCTAssertTrue(accessibilityText(of: requireElement("rules.rule.00000000-0000-0000-0000-000000000301.description", in: application)).contains("URL"))
        XCTAssertTrue(accessibilityText(of: requireElement("rules.rule.00000000-0000-0000-0000-000000000303.description", in: application)).contains("Application"))
        let sourceActions = requireElement("rules.rule.00000000-0000-0000-0000-000000000303.actions", in: application)
        sourceActions.click()
        XCTAssertFalse(requireElement("rules.rule.00000000-0000-0000-0000-000000000303.moveUp", in: application).isEnabled)
        XCTAssertFalse(requireElement("rules.rule.00000000-0000-0000-0000-000000000303.moveDown", in: application).isEnabled)
        application.typeKey(.escape, modifierFlags: [])
        let documentationActions = requireElement(
            "rules.rule.00000000-0000-0000-0000-000000000301.actions",
            in: application
        )
        documentationActions.click()
        let documentationUp = requireElement(
            "rules.rule.00000000-0000-0000-0000-000000000301.moveUp",
            in: application
        )
        let documentationDown = requireElement(
            "rules.rule.00000000-0000-0000-0000-000000000301.moveDown",
            in: application
        )
        XCTAssertFalse(documentationUp.isEnabled)
        XCTAssertTrue(documentationDown.isEnabled)

        documentationDown.click()
        documentationActions.click()
        let updatedDocumentationUp = requireElement(
            "rules.rule.00000000-0000-0000-0000-000000000301.moveUp",
            in: application
        )
        let updatedDocumentationDown = requireElement(
            "rules.rule.00000000-0000-0000-0000-000000000301.moveDown",
            in: application
        )
        XCTAssertTrue(updatedDocumentationUp.isEnabled)
        XCTAssertFalse(updatedDocumentationDown.isEnabled)
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(application.windows.count, 1)
    }

    func testRuleEditorValidatesConditionAndCancellationDoesNotCreateRule() {
        let application = launchFixture("workspace", appearance: .light)
        requireElement("appShell.sidebar.rules", in: application).click()
        _ = requireElement("appShell.page.rules.content", in: application)
        _ = requireElement("rules.rule.00000000-0000-0000-0000-000000000301.actions", in: application)
        let ruleActions = application.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "rules.rule.", ".actions")
        )
        let originalRuleCount = ruleActions.count
        XCTAssertEqual(originalRuleCount, 3)

        requireButton("rules.create", in: application).click()
        let save = requireElement("rules.editor.save", in: application)
        XCTAssertFalse(save.isEnabled, "A rule requires a matching condition before it can be saved")
        let condition = requireElement("rules.editor.condition", in: application)
        condition.click()
        condition.typeText("cancelled-rule.example.com")
        XCTAssertTrue(waitUntil(timeout: 3) { save.isEnabled })

        let cancel = application.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.click()
        XCTAssertTrue(waitUntil(timeout: 3) { !save.exists })
        XCTAssertEqual(ruleActions.count, originalRuleCount, "Cancelling must preserve the saved rule list")
        XCTAssertFalse(application.staticTexts["cancelled-rule.example.com"].exists)
    }

    func testRepeatedActivationPreservesRouteAndNeverDuplicatesTheMainWindow() {
        let application = launchFixture("history", appearance: .light)
        requireElement("appShell.sidebar.settings", in: application).click()
        _ = requireElement("appShell.page.settings.content", in: application)

        application.activate()
        application.activate()
        XCTAssertTrue(waitUntil(timeout: 3) { application.state == .runningForeground })
        _ = requireElement("appShell.page.settings.content", in: application)
        XCTAssertEqual(application.windows.count, 1)

        requireElement("appShell.sidebar.history", in: application).click()
        _ = requireElement("appShell.page.history.content", in: application)
        let window = requireMainWindow(in: application)
        requireElement("history.search", in: application).click()
        application.activate()
        application.activate()
        XCTAssertTrue(waitUntil(timeout: 3) { application.state == .runningForeground })
        _ = requireElement("appShell.page.history.content", in: application)
        XCTAssertEqual(application.windows.count, 1)

        window.typeText("/cancelled")
        let count = requireElement("history.recordCount", in: application)
        XCTAssertTrue(waitUntil(timeout: 3) { self.accessibilityText(of: count) == "1 records" })
        application.typeKey(",", modifierFlags: .command)
        _ = requireElement("appShell.page.settings.content", in: application)
        XCTAssertEqual(application.windows.count, 1, "Application commands must reuse the existing window")
    }

    func testSharedSettingsControlsUpdateTheirRealValues() {
        let application = launchFixture("workspace", appearance: .light)
        let window = requireMainWindow(in: application)
        requireElement("appShell.sidebar.settings", in: application).click()
        let automaticRules = requireElement("settings.automaticRules", in: application)
        let originalValue = String(describing: automaticRules.value ?? "")
        XCTAssertFalse(originalValue.isEmpty)
        automaticRules.click()
        XCTAssertTrue(waitUntil(timeout: 3) { String(describing: automaticRules.value ?? "") != originalValue })
        automaticRules.click()
        XCTAssertTrue(waitUntil(timeout: 3) { String(describing: automaticRules.value ?? "") == originalValue })

        let unmatched = requireElement("settings.unmatchedBehavior", in: application)
        unmatched.click()
        let preferred = application.buttons["Preferred browser"].firstMatch
        XCTAssertTrue(preferred.waitForExistence(timeout: 3))
        preferred.click()
        _ = requireElement("settings.preferredBrowser", in: application)
        XCTAssertEqual(unmatched.value as? String, "Preferred browser")

        unmatched.click()
        XCTAssertTrue(application.buttons["Last used"].firstMatch.waitForExistence(timeout: 3))
        window.typeKey(.downArrow, modifierFlags: [])
        window.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(waitUntil(timeout: 3) { unmatched.value as? String == "Last used" })

        requireElement("appShell.sidebar.history", in: application).click()
        requireElement("appShell.sidebar.settings", in: application).click()
        XCTAssertEqual(requireElement("settings.unmatchedBehavior", in: application).value as? String, "Last used")
    }
}

final class HistoryUITests: PrismUITestCase {
    func testClearHistoryConfirmationClearsRowsAndCancellationPreservesThem() {
        let application = launchFixture("history", appearance: .light)
        requireButton("history.clear", in: application).click()
        let cancel = application.sheets.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        cancel.click()
        XCTAssertEqual(accessibilityText(of: requireElement("history.recordCount", in: application)), "2 records")

        requireButton("history.clear", in: application).click()
        let confirm = application.sheets.buttons["Clear History"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.click()

        let emptyTitle = requireElement("pageState.empty.title", in: application)
        XCTAssertTrue(accessibilityText(of: emptyTitle).hasPrefix("Handled links will appear here"))
        XCTAssertFalse(application.descendants(matching: .any)["history.recordCount"].exists)
    }

    func testHistoryContentUsesUniqueRowActionsInLightAndDarkAppearance() throws {
        let light = try verifyHistoryContent(appearance: .light)
        terminateFixture(light)
        _ = try verifyHistoryContent(appearance: .dark)
    }

    func testHistoryLoadFailureAndNoURLRowsRemainExplicitlyRecoverable() throws {
        let failed = launchFixture("history-load-failure", appearance: .light)
        _ = requirePageStateTitle(
            "History could not be loaded",
            kind: "failed",
            in: failed
        )
        _ = requireButton("history.retryLoad", in: failed)
        terminateFixture(failed)

        let noURL = launchFixture("history-no-url", appearance: .dark)
        _ = requireElement("appShell.page.history.content", in: noURL)
        requireElement("history.row.00000000-0000-0000-0000-000000000203.more", in: noURL).click()
        let reopen = requireElement(
            "history.row.00000000-0000-0000-0000-000000000203.reopen",
            in: noURL
        )
        XCTAssertFalse(reopen.isEnabled)
        noURL.typeKey(.escape, modifierFlags: [])
        let url = requireElement(
            "history.row.00000000-0000-0000-0000-000000000203.url",
            in: noURL
        )
        XCTAssertTrue(accessibilityText(of: url).hasPrefix("Saved URL: URL not saved. Source: Fixture Source."))
        XCTAssertTrue(accessibilityText(of: url).contains("Result: Cancelled. Time: "))
        try attachWindowScreenshot(
            "history-no-url",
            application: noURL,
            appearance: .dark,
            verifiesAppearance: true
        )
    }

    func testQueueOwnedFailedHistoryRowDisablesClearAndKeepsTheRecoveryActionVisible() {
        let application = launchFixture("history-actions", appearance: .light)
        _ = requireElement("appShell.page.history.content", in: application)
        let clear = requireElement("history.clear", in: application)
        XCTAssertFalse(clear.isEnabled, "Clear must remain disabled while any History row is queue-owned")

        let more = requireElement(
            "history.row.00000000-0000-0000-0000-000000000204.more",
            in: application
        )
        more.click()
        let retry = requireElement("history.row.00000000-0000-0000-0000-000000000204.retry", in: application)
        XCTAssertTrue(retry.isEnabled, "A queue-owned failure must keep its recovery action available")
        let delete = requireElement(
            "history.row.00000000-0000-0000-0000-000000000204.delete",
            in: application
        )
        XCTAssertFalse(delete.isEnabled, "Delete must remain disabled while that History row is queue-owned")
    }

    func testUnsafeLegacyURLNeverAppearsInHistoryOrMoreActionsAndCannotReopen() {
        let application = launchFixture("history-unsafe-url", appearance: .dark)
        _ = requireElement("appShell.page.history.content", in: application)
        let safeURL = requireElement(
            "history.row.00000000-0000-0000-0000-000000000206.url",
            in: application
        )
        XCTAssertTrue(accessibilityText(of: safeURL).hasPrefix("Saved URL: https://history.example/private?safe=visible. Source: Fixture Source."))
        XCTAssertTrue(accessibilityText(of: safeURL).contains("Result: Cancelled. Time: "))

        let more = requireElement(
            "history.row.00000000-0000-0000-0000-000000000206.more",
            in: application
        )
        more.click()
        let reopen = requireElement("history.row.00000000-0000-0000-0000-000000000206.reopen", in: application)
        XCTAssertFalse(reopen.isEnabled, "Only an originally safe stored URL may be reopened")
        _ = requireElement(
            "history.row.00000000-0000-0000-0000-000000000206.delete",
            in: application
        )

        let accessibilityHierarchy = application.debugDescription
        for unsafeURLPart in [
            "username:password@",
            "token=secret",
            "password=redacted",
            "api_key=redacted",
            "client_secret=redacted",
            "refresh_token=redacted",
            "#fragment",
        ] {
            XCTAssertFalse(
                accessibilityHierarchy.localizedCaseInsensitiveContains(unsafeURLPart),
                "History accessibility must not expose \(unsafeURLPart) from the legacy URL"
            )
        }
    }

    func testAllResultFilterRestoresEveryRowWithoutOpeningAMenu() {
        let application = launchFixture("history", appearance: .light)
        let count = requireElement("history.recordCount", in: application)
        let all = requireElement("history.resultFilter.all", in: application)
        let openedRow = requireElement("history.row.00000000-0000-0000-0000-000000000201.url", in: application)
        let cancelledRow = requireElement("history.row.00000000-0000-0000-0000-000000000202.url", in: application)
        XCTAssertEqual(accessibilityText(of: count), "2 records")

        for (filter, matchingRow, otherRow) in [
            ("opened", openedRow, cancelledRow),
            ("cancelled", cancelledRow, openedRow),
        ] {
            let selectedFilter = requireButton("history.resultFilter.\(filter)", in: application)
            selectedFilter.click()
            XCTAssertTrue(waitUntil(timeout: 3) { self.accessibilityText(of: count) == "1 records" })
            XCTAssertTrue(matchingRow.exists)
            XCTAssertFalse(otherRow.exists)

            all.click()

            XCTAssertTrue(waitUntil(timeout: 3) { self.accessibilityText(of: count) == "2 records" })
            XCTAssertTrue(openedRow.exists)
            XCTAssertTrue(cancelledRow.exists)
            XCTAssertTrue(all.isSelected)
            XCTAssertFalse(selectedFilter.isSelected)
            XCTAssertFalse(application.descendants(matching: .any)["history.resultFilter.failed"].exists)
            XCTAssertFalse(application.descendants(matching: .any)["history.resultFilter.processing"].exists)
        }
    }

    func testSearchFiltersRecordCountAndDetailsShowsSafeURL() {
        let application = launchFixture("history", appearance: .light)
        let count = requireElement("history.recordCount", in: application)
        XCTAssertEqual(accessibilityText(of: count), "2 records")
        let search = requireElement("history.search", in: application)
        search.click()
        search.typeText("/cancelled")
        XCTAssertTrue(waitUntil(timeout: 3) { self.accessibilityText(of: count) == "1 records" })
        XCTAssertFalse(application.descendants(matching: .any)["history.row.00000000-0000-0000-0000-000000000201.url"].exists)
        requireElement("history.row.00000000-0000-0000-0000-000000000202.url", in: application).click()
        let detailURL = requireElement("history.row.00000000-0000-0000-0000-000000000202.details.url", in: application)
        XCTAssertEqual(accessibilityText(of: detailURL), "https://history.example/cancelled?safe=visible")
        XCTAssertTrue(requireButton("history.row.00000000-0000-0000-0000-000000000202.reopen", in: application).isEnabled)
        requireButton("history.row.00000000-0000-0000-0000-000000000202.details.close", in: application).click()
        XCTAssertTrue(waitUntil(timeout: 3) { !detailURL.exists })
        XCTAssertEqual(accessibilityText(of: count), "1 records")
    }

    private func verifyHistoryContent(appearance: PrismUITestAppearance) throws -> XCUIApplication {
        let application = launchFixture("history", appearance: appearance)
        _ = requireElement("appShell.page.history.content", in: application)
        _ = requireElement(
            "history.row.00000000-0000-0000-0000-000000000201.more",
            in: application
        )
        _ = requireElement(
            "history.row.00000000-0000-0000-0000-000000000202.more",
            in: application
        )
        requireElement("history.row.00000000-0000-0000-0000-000000000202.more", in: application).click()
        _ = requireElement(
            "history.row.00000000-0000-0000-0000-000000000202.reopen",
            in: application
        )
        application.typeKey(.escape, modifierFlags: [])
        _ = requireButton("history.clear", in: application)
        try attachWindowScreenshot(
            "history-content",
            application: application,
            appearance: appearance,
            verifiesAppearance: true
        )
        return application
    }
}
