import Foundation
import Testing
@testable import PrismCore

@Test func firstRunLeavesBrowserOrderUnchanged() {
    let existing: [BrowserID] = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox"]
    #expect(BrowserMostRecentOrder.orderedIDs(existing: existing, recentIDs: []) == existing)
}

@Test func mostRecentChoiceLeadsAndUnusedBrowsersKeepRelativeOrder() {
    let existing: [BrowserID] = ["com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac"]
    let afterChrome = BrowserMostRecentOrder.remembering("com.google.Chrome", recentIDs: [])
    #expect(
        BrowserMostRecentOrder.orderedIDs(existing: existing, recentIDs: afterChrome)
            == ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac"]
    )

    let afterFirefox = BrowserMostRecentOrder.remembering("org.mozilla.firefox", recentIDs: afterChrome)
    #expect(
        BrowserMostRecentOrder.orderedIDs(existing: existing, recentIDs: afterFirefox)
            == ["org.mozilla.firefox", "com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac"]
    )
}

@Test func removedBrowsersDropOutAndNewBrowsersAppend() {
    let recent = BrowserMostRecentOrder.remembering(
        "com.google.Chrome",
        recentIDs: ["com.microsoft.edgemac", "com.google.Chrome"]
    )
    let installed: [BrowserID] = ["com.apple.Safari", "org.mozilla.firefox", "com.google.Chrome", "com.brave.Browser"]
    let pruned = BrowserMostRecentOrder.pruned(recentIDs: recent, installedIDs: installed)

    #expect(pruned == ["com.google.Chrome"])
    #expect(
        BrowserMostRecentOrder.orderedIDs(existing: installed, recentIDs: pruned)
            == ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.brave.Browser"]
    )
}

@Test func duplicateRecentIDsDoNotRepeatBrowsers() {
    let existing: [BrowserID] = ["com.apple.Safari", "com.google.Chrome"]
    #expect(
        BrowserMostRecentOrder.orderedIDs(
            existing: existing,
            recentIDs: ["com.google.Chrome", "com.google.Chrome", "com.example.missing"]
        ) == ["com.google.Chrome", "com.apple.Safari"]
    )
}
