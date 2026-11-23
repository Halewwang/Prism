import Foundation

public struct BrowserID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public enum BrowserOrigin: String, Codable, Equatable, Sendable {
    case system
    case custom
}

public enum BrowserAvailability: String, Codable, Equatable, Sendable {
    case available
    case unavailable
}

public struct ChromiumProfileDescriptor: Codable, Equatable, Sendable {
    public let directoryName: String
    public let displayName: String
    public let userDataDirectory: URL

    public init(directoryName: String, displayName: String, userDataDirectory: URL) {
        self.directoryName = directoryName
        self.displayName = displayName
        self.userDataDirectory = userDataDirectory
    }

    public func browserID(bundleIdentifier: String) -> BrowserID {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._")
        let directory = directoryName.addingPercentEncoding(withAllowedCharacters: allowed) ?? directoryName
        return BrowserID("\(bundleIdentifier)::profile::\(directory)")
    }
}

public struct BrowserDescriptor: Codable, Equatable, Sendable {
    public static let maxAlternateNameLength = 40

    public let id: BrowserID
    public let bundleIdentifier: String
    public let displayName: String
    public let originalDisplayName: String
    public let alternateName: String?
    public let applicationURL: URL
    public let securityScopedBookmark: Data?
    public let origin: BrowserOrigin
    public let availability: BrowserAvailability
    public let selectorOrder: Int
    public let profile: ChromiumProfileDescriptor?

    public init(
        id: BrowserID,
        bundleIdentifier: String,
        displayName: String,
        originalDisplayName: String? = nil,
        alternateName: String? = nil,
        applicationURL: URL,
        securityScopedBookmark: Data?,
        origin: BrowserOrigin,
        availability: BrowserAvailability,
        selectorOrder: Int,
        profile: ChromiumProfileDescriptor? = nil
    ) {
        let baseName = originalDisplayName ?? displayName
        let normalizedAlternate = Self.normalizedAlternateName(alternateName)
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.originalDisplayName = baseName
        self.alternateName = normalizedAlternate
        self.displayName = normalizedAlternate ?? displayName
        self.applicationURL = applicationURL
        self.securityScopedBookmark = securityScopedBookmark
        self.origin = origin
        self.availability = availability
        self.selectorOrder = selectorOrder
        self.profile = profile
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, displayName, originalDisplayName, alternateName
        case applicationURL, securityScopedBookmark, origin, availability, selectorOrder, profile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let originalDisplayName = try container.decodeIfPresent(String.self, forKey: .originalDisplayName)
        let alternateName = try container.decodeIfPresent(String.self, forKey: .alternateName)
        self.init(
            id: try container.decode(BrowserID.self, forKey: .id),
            bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier),
            displayName: displayName,
            originalDisplayName: originalDisplayName,
            alternateName: alternateName,
            applicationURL: try container.decode(URL.self, forKey: .applicationURL),
            securityScopedBookmark: try container.decodeIfPresent(Data.self, forKey: .securityScopedBookmark),
            origin: try container.decode(BrowserOrigin.self, forKey: .origin),
            availability: try container.decode(BrowserAvailability.self, forKey: .availability),
            selectorOrder: try container.decode(Int.self, forKey: .selectorOrder),
            profile: try container.decodeIfPresent(ChromiumProfileDescriptor.self, forKey: .profile)
        )
    }

    public var hasAlternateName: Bool {
        alternateName != nil
    }

    public var tooltipDisplayName: String {
        guard let alternateName, alternateName != originalDisplayName else {
            return displayName
        }
        return "\(alternateName) (\(originalDisplayName))"
    }

    public func withAlternateName(_ alternateName: String?) -> BrowserDescriptor {
        BrowserDescriptor(
            id: id,
            bundleIdentifier: bundleIdentifier,
            displayName: originalDisplayName,
            originalDisplayName: originalDisplayName,
            alternateName: alternateName,
            applicationURL: applicationURL,
            securityScopedBookmark: securityScopedBookmark,
            origin: origin,
            availability: availability,
            selectorOrder: selectorOrder,
            profile: profile
        )
    }

    public func withSelectorOrder(_ selectorOrder: Int) -> BrowserDescriptor {
        BrowserDescriptor(
            id: id,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            originalDisplayName: originalDisplayName,
            alternateName: alternateName,
            applicationURL: applicationURL,
            securityScopedBookmark: securityScopedBookmark,
            origin: origin,
            availability: availability,
            selectorOrder: selectorOrder,
            profile: profile
        )
    }

    public static func normalizedAlternateName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let singleLine = raw
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else { return nil }
        return String(singleLine.prefix(maxAlternateNameLength))
    }
}
