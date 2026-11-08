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
    private let loadInstalledApplications: () -> [InstalledApplication]
    private var installedApplications: [InstalledApplication]?
    // shortcut: Icons refresh when this provider is recreated; add workspace invalidation for live installation changes.
    private var icons: [URL: NSImage] = [:]
    private var applicationURLs: [String: URL] = [:]
    private var missingBundleIdentifiers: Set<String> = []

    init(
        workspace: any WorkspaceClient = SystemWorkspaceClient(),
        applicationURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        installedApplications: @escaping () -> [InstalledApplication] = InstalledApplicationCatalog.load
    ) {
        self.workspace = workspace
        self.applicationURL = applicationURL
        loadInstalledApplications = installedApplications
    }

    func icon(for applicationURL: URL) -> NSImage {
        if let image = icons[applicationURL] { return image }
        let image = workspace.icon(for: applicationURL)
        icons[applicationURL] = image
        return image
    }

    func icon(bundleIdentifier: String) -> NSImage? {
        guard !missingBundleIdentifiers.contains(bundleIdentifier) else { return nil }
        guard let url = applicationURLs[bundleIdentifier] ?? applicationURL(bundleIdentifier)
            ?? installedApplicationURL(matching: bundleIdentifier)
        else {
            missingBundleIdentifiers.insert(bundleIdentifier)
            return nil
        }
        applicationURLs[bundleIdentifier] = url
        return icon(for: url)
    }

    private func installedApplicationURL(matching bundleIdentifier: String) -> URL? {
        let applications = installedApplications ?? loadInstalledApplications()
        installedApplications = applications
        let matches = applications.filter {
            !SourceBundleIdentity.isHelper($0.bundleIdentifier)
                && SourceBundleIdentity.matches(bundleIdentifier, $0.bundleIdentifier)
        }
        return matches.count == 1 ? matches[0].applicationURL : nil
    }
}
