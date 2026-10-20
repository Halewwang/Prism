import Foundation
import PrismCore
import SwiftData

@Model
final class CustomBrowserRecord {
    @Attribute(.unique) var id: String
    var bundleIdentifier: String
    var displayName: String
    var applicationURLString: String
    var securityScopedBookmark: Data?
    var selectorOrder: Int

    init(browser: BrowserDescriptor) {
        id = browser.id.rawValue
        bundleIdentifier = browser.bundleIdentifier
        displayName = browser.displayName
        applicationURLString = browser.applicationURL.absoluteString
        securityScopedBookmark = browser.securityScopedBookmark
        selectorOrder = browser.selectorOrder
    }

    func browserDescriptor() throws -> BrowserDescriptor {
        guard let applicationURL = URL(string: applicationURLString) else {
            throw PersistenceRecordError.invalidPayload
        }

        return BrowserDescriptor(
            id: BrowserID(rawValue: id),
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL,
            securityScopedBookmark: securityScopedBookmark,
            origin: .custom,
            availability: .unavailable,
            selectorOrder: selectorOrder
        )
    }

    func replace(with browser: BrowserDescriptor) {
        bundleIdentifier = browser.bundleIdentifier
        displayName = browser.displayName
        applicationURLString = browser.applicationURL.absoluteString
        securityScopedBookmark = browser.securityScopedBookmark
        selectorOrder = browser.selectorOrder
    }
}

@Model
final class BrowserOrderRecord {
    @Attribute(.unique) var key: String
    var orderedIDsPayload: Data

    init(ids: [BrowserID]) throws {
        key = "primary"
        orderedIDsPayload = try JSONEncoder().encode(VersionedBrowserOrder(version: 1, ids: ids.map(\.rawValue)))
    }

    func browserIDs() throws -> [BrowserID] {
        let payload = try JSONDecoder().decode(VersionedBrowserOrder.self, from: orderedIDsPayload)
        guard payload.version == 1 else {
            throw PersistenceRecordError.invalidPayload
        }
        return payload.ids.map(BrowserID.init(rawValue:))
    }

    func replace(with ids: [BrowserID]) throws {
        orderedIDsPayload = try Self.encode(ids: ids, hiddenIDs: try hiddenBrowserIDs(), recentIDs: try recentBrowserIDs())
    }

    func hiddenBrowserIDs() throws -> [BrowserID] {
        let payload = try decodedPayload()
        return (payload.hiddenIDs ?? []).map(BrowserID.init(rawValue:))
    }

    func replaceHiddenBrowserIDs(with ids: [BrowserID]) throws {
        orderedIDsPayload = try Self.encode(ids: try browserIDs(), hiddenIDs: ids, recentIDs: try recentBrowserIDs())
    }

    func recentBrowserIDs() throws -> [BrowserID] {
        let payload = try decodedPayload()
        return (payload.recentIDs ?? []).map(BrowserID.init(rawValue:))
    }

    func replaceRecentBrowserIDs(with ids: [BrowserID]) throws {
        orderedIDsPayload = try Self.encode(ids: try browserIDs(), hiddenIDs: try hiddenBrowserIDs(), recentIDs: ids)
    }

    private func decodedPayload() throws -> VersionedBrowserOrder {
        let payload = try JSONDecoder().decode(VersionedBrowserOrder.self, from: orderedIDsPayload)
        guard payload.version == 1 else { throw PersistenceRecordError.invalidPayload }
        return payload
    }

    private static func encode(ids: [BrowserID], hiddenIDs: [BrowserID], recentIDs: [BrowserID]) throws -> Data {
        try JSONEncoder().encode(VersionedBrowserOrder(
            version: 1,
            ids: ids.map(\.rawValue),
            hiddenIDs: hiddenIDs.map(\.rawValue),
            recentIDs: recentIDs.map(\.rawValue)
        ))
    }
}

private struct VersionedBrowserOrder: Codable {
    let version: Int
    let ids: [String]
    var hiddenIDs: [String]? = nil
    var recentIDs: [String]? = nil
}
