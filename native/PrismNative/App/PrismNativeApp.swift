import SwiftUI

@main
struct PrismNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Prism") { PrismAboutWindowController.shared.present() }
                Divider()
                Button("Check for Updates") {
                    appDelegate.environment.updateChecker.checkForUpdates()
                }
                .disabled(!appDelegate.environment.updateChecker.canCheckForUpdates)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    appDelegate.composition.mainWindowOpening.open(route: .settings)
                }
                .keyboardShortcut(",")
                Button("Manage Browsers") {
                    appDelegate.environment.stageBrowserManagement()
                    appDelegate.composition.mainWindowOpening.open(route: .settings)
                }
            }
            CommandGroup(after: .sidebar) {
                Button("History") {
                    appDelegate.composition.mainWindowOpening.open(route: .history)
                }
                .keyboardShortcut("1")
                Button("Rules") {
                    appDelegate.composition.mainWindowOpening.open(route: .rules)
                }
                .keyboardShortcut("2")
                Button("Settings") {
                    appDelegate.composition.mainWindowOpening.open(route: .settings)
                }
                .keyboardShortcut("3")
            }
        }
    }
}
