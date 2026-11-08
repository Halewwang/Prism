import AppKit
import Foundation
import PrismCore

@MainActor
protocol ApplicationIconProviding: AnyObject {
    func icon(for applicationURL: URL) -> NSImage
    func icon(bundleIdentifier: String) -> NSImage?
}

extension ApplicationIconProviding {
    func icon(for browserID: BrowserID) -> NSImage? {
        icon(bundleIdentifier: browserID.rawValue.components(separatedBy: "::profile::")[0])
    }
}

@MainActor
final class ApplicationIconProvider: ApplicationIconProviding {
    private let workspace: any WorkspaceClient
    private let applicationURL: (String) -> URL?
    // shortcut: Icons refresh when this provider is recreated; add workspace invalidation for live installation changes.
    private var icons: [URL: NSImage] = [:]
    private var applicationURLs: [String: URL] = [:]
    private var missingBundleIdentifiers: Set<String> = []

    init(
        workspace: any WorkspaceClient = SystemWorkspaceClient(),
        applicationURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    ) {
        self.workspace = workspace
        self.applicationURL = applicationURL
    }

    func icon(for applicationURL: URL) -> NSImage {
        if let image = icons[applicationURL] { return image }
        let image = workspace.icon(for: applicationURL)
        icons[applicationURL] = image
        return image
    }

    func icon(bundleIdentifier: String) -> NSImage? {
        guard !missingBundleIdentifiers.contains(bundleIdentifier) else { return nil }
        guard let url = applicationURLs[bundleIdentifier] ?? applicationURL(bundleIdentifier) else {
            missingBundleIdentifiers.insert(bundleIdentifier)
            return nil
        }
        applicationURLs[bundleIdentifier] = url
        return icon(for: url)
    }
}
