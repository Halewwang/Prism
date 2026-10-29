import Foundation
import WebKit

enum LinkPreviewBrowserIdentity {
    @MainActor static var systemApplicationName: String? {
        let paths = ["/Applications/Safari.app", "/System/Cryptexes/App/System/Applications/Safari.app"]
        guard let safari = paths.compactMap({ Bundle(url: URL(fileURLWithPath: $0)) }).first else { return nil }
        return applicationName(
            safariVersion: safari.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            safariBuild: safari.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            webKitBuild: Bundle(for: WKWebView.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func applicationName(safariVersion: String?, safariBuild: String?, webKitBuild: String?) -> String? {
        guard let safariVersion, let safariBuild, !safariBuild.isEmpty, safariBuild == webKitBuild,
              !safariVersion.isEmpty,
              safariVersion.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ part in
                  !part.isEmpty && part.utf8.allSatisfy { (48 ... 57).contains($0) }
              }) else { return nil }
        // WebKit freezes this UA token; advertise a Safari version only for the same system build.
        return "Version/\(safariVersion) Safari/605.1.15"
    }
}
