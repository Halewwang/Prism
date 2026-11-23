import Foundation
import PrismCore
import SwiftData

@MainActor
protocol RuleRepository {
    func all() throws -> [RoutingRule]
    func upsert(_ rule: RoutingRule) throws
    func updatePriorities(_ rules: [RoutingRule]) throws
    func delete(id: UUID) throws
}

extension RuleRepository {
    /// Test-only and simple in-memory conformers can use the existing upsert path.
    /// The production repository overrides this with one transactional save.
    func updatePriorities(_ rules: [RoutingRule]) throws {
        for rule in rules {
            try upsert(rule)
        }
    }
}

enum RuleRepositoryError: Error, Equatable {
    case missingRule(UUID)
}

@MainActor
protocol HistoryRepository {
    func upsert(_ entry: HistoryEntry) throws
    func upsertAndEnforceRetention(_ entry: HistoryEntry, limit: Int, cutoff: Date) throws
    func recent(limit: Int, newerThan: Date) throws -> [HistoryEntry]
    func entry(forRequestID requestID: UUID) throws -> HistoryEntry?
    func delete(id: UUID) throws
    func clear() throws
    func enforceRetention(limit: Int, cutoff: Date) throws
}

extension HistoryRepository {
    func entry(forRequestID requestID: UUID) throws -> HistoryEntry? {
        try recent(limit: 10_000, newerThan: .distantPast)
            .first(where: { $0.requestID == requestID })
    }
}

@MainActor
protocol BrowserPreferenceRepository {
    func orderedBrowserIDs() throws -> [BrowserID]
    func saveOrder(_ ids: [BrowserID]) throws
    func hiddenBrowserIDs() throws -> [BrowserID]
    func saveHiddenBrowserIDs(_ ids: [BrowserID]) throws
    func recentBrowserIDs() throws -> [BrowserID]
    func saveRecentBrowserIDs(_ ids: [BrowserID]) throws
    func browserAlternateNames() throws -> [BrowserID: String]
    func saveBrowserAlternateNames(_ names: [BrowserID: String]) throws
    func customBrowsers() throws -> [BrowserDescriptor]
    func upsertCustomBrowser(_ browser: BrowserDescriptor) throws
    func deleteCustomBrowser(id: BrowserID) throws
}

@MainActor
protocol SettingsRepository {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}

@MainActor
final class SwiftDataRuleRepository: RuleRepository {
    private let context: ModelContext
    private let commit: (ModelContext) throws -> Void

    init(container: ModelContainer, commit: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        context = ModelContext(container)
        self.commit = commit
    }

    func all() throws -> [RoutingRule] {
        try context.fetch(FetchDescriptor<RuleRecord>())
            .map { try $0.routingRule() }
            .sorted(by: RoutingRuleOrdering.isOrderedBefore)
    }

    func upsert(_ rule: RoutingRule) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<RuleRecord>()).first(where: { $0.id == rule.id }) {
                try record.replace(with: rule)
            } else {
                context.insert(try RuleRecord(rule: rule))
            }
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    func updatePriorities(_ rules: [RoutingRule]) throws {
        do {
            let records = try context.fetch(FetchDescriptor<RuleRecord>())
            for rule in rules {
                guard let record = records.first(where: { $0.id == rule.id }) else {
                    throw RuleRepositoryError.missingRule(rule.id)
                }
                try record.replace(with: rule)
            }
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<RuleRecord>()).first(where: { $0.id == id }) {
                context.delete(record)
                try commit(context)
            }
        } catch {
            context.rollback()
            throw error
        }
    }

}

@MainActor
final class SwiftDataHistoryRepository: HistoryRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func upsert(_ entry: HistoryEntry) throws {
        do {
            try upsertInContext(entry)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func upsertAndEnforceRetention(_ entry: HistoryEntry, limit: Int, cutoff: Date) throws {
        do {
            try upsertInContext(entry)
            try enforceRetentionInContext(limit: limit, cutoff: cutoff)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func recent(limit: Int, newerThan: Date) throws -> [HistoryEntry] {
        guard limit > 0 else { return [] }
        let descriptor = FetchDescriptor<HistoryRecord>(
            predicate: #Predicate { $0.createdAt >= newerThan },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        var migratedLegacyURL = false
        do {
            let entries = try records.map { record -> HistoryEntry in
                let entry = try record.historyEntry()
                let safeURLString = entry.sanitizedURL?.absoluteString
                if record.sanitizedURLString != safeURLString {
                    record.sanitizedURLString = safeURLString
                    migratedLegacyURL = true
                }
                return entry
            }
            if migratedLegacyURL {
                try context.save()
            }
            return entries.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
            .prefix(limit)
            .map { $0 }
        } catch {
            context.rollback()
            throw error
        }
    }

    func entry(forRequestID requestID: UUID) throws -> HistoryEntry? {
        let descriptor = FetchDescriptor<HistoryRecord>(
            predicate: #Predicate { $0.requestID == requestID }
        )
        let records = try context.fetch(descriptor)
        guard let record = records.sorted(by: Self.stableCanonicalRecordFirst).first else {
            return nil
        }
        return try record.historyEntry()
    }

    func delete(id: UUID) throws {
        do {
            let descriptor = FetchDescriptor<HistoryRecord>(
                predicate: #Predicate { $0.id == id }
            )
            if let record = try context.fetch(descriptor).first {
                context.delete(record)
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    func clear() throws {
        do {
            for record in try context.fetch(FetchDescriptor<HistoryRecord>()) {
                context.delete(record)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func enforceRetention(limit: Int, cutoff: Date) throws {
        do {
            try enforceRetentionInContext(limit: limit, cutoff: cutoff)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func newestRecordFirst(_ lhs: HistoryRecord, _ rhs: HistoryRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func stableCanonicalRecordFirst(_ lhs: HistoryRecord, _ rhs: HistoryRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func upsertInContext(_ entry: HistoryEntry) throws {
        let entryRequestID = entry.requestID
        let entryID = entry.id
        let descriptor = FetchDescriptor<HistoryRecord>(
            predicate: #Predicate { $0.requestID == entryRequestID || $0.id == entryID }
        )
        let matchingRecords = try context.fetch(descriptor)
        let requestRecords = matchingRecords
            .filter { $0.requestID == entryRequestID }
            .sorted(by: Self.stableCanonicalRecordFirst)
        if let record = requestRecords.first
            ?? matchingRecords.first(where: { $0.id == entryID }) {
            record.replace(with: entry)
            for duplicate in requestRecords where duplicate !== record {
                context.delete(duplicate)
            }
        } else {
            context.insert(HistoryRecord(entry: entry))
        }
    }

    private func enforceRetentionInContext(limit: Int, cutoff: Date) throws {
        let records = try context.fetch(FetchDescriptor<HistoryRecord>())
        var retainedByAge: [HistoryRecord] = []
        retainedByAge.reserveCapacity(records.count)
        for record in records {
            if record.createdAt < cutoff {
                context.delete(record)
            } else {
                retainedByAge.append(record)
            }
        }

        let groupedByRequestID = Dictionary(grouping: retainedByAge, by: \.requestID)
        var canonicalRecords: [HistoryRecord] = []
        canonicalRecords.reserveCapacity(groupedByRequestID.count)

        for group in groupedByRequestID.values {
            let sortedCanonical = group.sorted(by: Self.stableCanonicalRecordFirst)
            guard let canonical = sortedCanonical.first else { continue }
            if group.count > 1 {
                if let latest = group.sorted(by: Self.latestPayloadRecordFirst).first,
                   latest !== canonical {
                    canonical.replace(with: try latest.historyEntry())
                }
                for duplicate in sortedCanonical.dropFirst() {
                    context.delete(duplicate)
                }
            }
            canonicalRecords.append(canonical)
        }

        let remaining = canonicalRecords.sorted(by: Self.newestRecordFirst)
        for record in remaining.dropFirst(max(limit, 0)) {
            context.delete(record)
        }
    }

    private static func latestPayloadRecordFirst(_ lhs: HistoryRecord, _ rhs: HistoryRecord) -> Bool {
        if lhs.attemptCount != rhs.attemptCount { return lhs.attemptCount > rhs.attemptCount }
        let lhsCompletedAt = lhs.completedAt ?? .distantPast
        let rhsCompletedAt = rhs.completedAt ?? .distantPast
        if lhsCompletedAt != rhsCompletedAt { return lhsCompletedAt > rhsCompletedAt }
        let resultRank: [String: Int] = [
            HistoryResult.success.rawValue: 3,
            HistoryResult.failure.rawValue: 2,
            HistoryResult.cancelled.rawValue: 1,
            HistoryResult.processing.rawValue: 0,
        ]
        if resultRank[lhs.result, default: -1] != resultRank[rhs.result, default: -1] {
            return resultRank[lhs.result, default: -1] > resultRank[rhs.result, default: -1]
        }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}

@MainActor
final class SwiftDataBrowserPreferenceRepository: BrowserPreferenceRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func orderedBrowserIDs() throws -> [BrowserID] {
        guard let record = try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" }) else {
            return []
        }
        return try record.browserIDs()
    }

    func saveOrder(_ ids: [BrowserID]) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" }) {
                try record.replace(with: ids)
            } else {
                context.insert(try BrowserOrderRecord(ids: ids))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func hiddenBrowserIDs() throws -> [BrowserID] {
        try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" })?.hiddenBrowserIDs() ?? []
    }

    func saveHiddenBrowserIDs(_ ids: [BrowserID]) throws {
        try updatePrimaryOrderRecord { try $0.replaceHiddenBrowserIDs(with: ids) }
    }

    func recentBrowserIDs() throws -> [BrowserID] {
        try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" })?.recentBrowserIDs() ?? []
    }

    func saveRecentBrowserIDs(_ ids: [BrowserID]) throws {
        try updatePrimaryOrderRecord { try $0.replaceRecentBrowserIDs(with: ids) }
    }

    func browserAlternateNames() throws -> [BrowserID: String] {
        try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" })?.alternateNames() ?? [:]
    }

    func saveBrowserAlternateNames(_ names: [BrowserID: String]) throws {
        try updatePrimaryOrderRecord { try $0.replaceAlternateNames(with: names) }
    }

    private func updatePrimaryOrderRecord(_ update: (BrowserOrderRecord) throws -> Void) throws {
        do {
            let record: BrowserOrderRecord
            if let existing = try context.fetch(FetchDescriptor<BrowserOrderRecord>()).first(where: { $0.key == "primary" }) {
                record = existing
            } else {
                record = try BrowserOrderRecord(ids: [])
                context.insert(record)
            }
            try update(record)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func customBrowsers() throws -> [BrowserDescriptor] {
        try context.fetch(FetchDescriptor<CustomBrowserRecord>())
            .map { try $0.browserDescriptor() }
            .sorted {
                if $0.selectorOrder != $1.selectorOrder {
                    return $0.selectorOrder < $1.selectorOrder
                }
                return $0.id.rawValue < $1.id.rawValue
            }
    }

    func upsertCustomBrowser(_ browser: BrowserDescriptor) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<CustomBrowserRecord>()).first(where: { $0.id == browser.id.rawValue }) {
                record.replace(with: browser)
            } else {
                context.insert(CustomBrowserRecord(browser: browser))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteCustomBrowser(id: BrowserID) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<CustomBrowserRecord>()).first(where: { $0.id == id.rawValue }) {
                context.delete(record)
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class SwiftDataSettingsRepository: SettingsRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func load() throws -> AppSettings {
        guard let record = try context.fetch(FetchDescriptor<SettingsRecord>()).first(where: { $0.key == "current" }) else {
            return .defaults
        }
        return try record.appSettings()
    }

    func save(_ settings: AppSettings) throws {
        do {
            if let record = try context.fetch(FetchDescriptor<SettingsRecord>()).first(where: { $0.key == "current" }) {
                record.replace(with: settings)
            } else {
                context.insert(SettingsRecord(settings: settings))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class InMemoryRuleRepository: RuleRepository {
    private var rules: [UUID: RoutingRule] = [:]

    func all() throws -> [RoutingRule] {
        RoutingRuleOrdering.sorted(Array(rules.values))
    }

    func upsert(_ rule: RoutingRule) throws {
        rules[rule.id] = rule
    }

    func updatePriorities(_ updatedRules: [RoutingRule]) throws {
        var nextRules = rules
        for rule in updatedRules {
            guard nextRules[rule.id] != nil else {
                throw RuleRepositoryError.missingRule(rule.id)
            }
            nextRules[rule.id] = rule
        }
        rules = nextRules
    }

    func delete(id: UUID) throws {
        rules.removeValue(forKey: id)
    }
}

@MainActor
final class InMemoryHistoryRepository: HistoryRepository {
    private var entriesByRequestID: [UUID: HistoryEntry] = [:]

    func upsert(_ entry: HistoryEntry) throws {
        if let existing = entriesByRequestID[entry.requestID] {
            entriesByRequestID[entry.requestID] = entry.preservingHistoryID(existing.id)
        } else {
            entriesByRequestID[entry.requestID] = entry
        }
    }

    func upsertAndEnforceRetention(_ entry: HistoryEntry, limit: Int, cutoff: Date) throws {
        let previous = entriesByRequestID
        do {
            try upsert(entry)
            try enforceRetention(limit: limit, cutoff: cutoff)
        } catch {
            entriesByRequestID = previous
            throw error
        }
    }

    func recent(limit: Int, newerThan: Date) throws -> [HistoryEntry] {
        guard limit > 0 else { return [] }
        return entriesByRequestID.values
            .filter { $0.createdAt >= newerThan }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func entry(forRequestID requestID: UUID) throws -> HistoryEntry? {
        entriesByRequestID[requestID]
    }

    func delete(id: UUID) throws {
        guard let requestID = entriesByRequestID.first(where: { $0.value.id == id })?.key else { return }
        entriesByRequestID.removeValue(forKey: requestID)
    }

    func clear() throws {
        entriesByRequestID.removeAll()
    }

    func enforceRetention(limit: Int, cutoff: Date) throws {
        entriesByRequestID = entriesByRequestID.filter { $0.value.createdAt >= cutoff }
        let retained = try recent(limit: max(limit, 0), newerThan: .distantPast)
        entriesByRequestID = Dictionary(uniqueKeysWithValues: retained.map { ($0.requestID, $0) })
    }
}

private extension HistoryEntry {
    func preservingHistoryID(_ id: UUID) -> HistoryEntry {
        HistoryEntry(
            id: id,
            requestID: requestID,
            sanitizedURL: sanitizedURL,
            sourceBundleIdentifier: sourceBundleIdentifier,
            sourceDisplayName: sourceDisplayName,
            targetBrowserID: targetBrowserID,
            targetDisplayName: targetDisplayName,
            method: method,
            result: result,
            matchingRuleID: matchingRuleID,
            failureReason: failureReason,
            attemptCount: attemptCount,
            createdAt: createdAt,
            completedAt: completedAt
        )
    }
}

@MainActor
final class InMemoryBrowserPreferenceRepository: BrowserPreferenceRepository {
    private var orderedIDs: [BrowserID] = []
    private var hiddenIDs: [BrowserID] = []
    private var recentIDs: [BrowserID] = []
    private var alternateNames: [BrowserID: String] = [:]
    private var browsers: [BrowserID: BrowserDescriptor] = [:]

    func orderedBrowserIDs() throws -> [BrowserID] {
        orderedIDs
    }

    func saveOrder(_ ids: [BrowserID]) throws {
        orderedIDs = ids
    }

    func hiddenBrowserIDs() throws -> [BrowserID] { hiddenIDs }

    func saveHiddenBrowserIDs(_ ids: [BrowserID]) throws { hiddenIDs = ids }

    func recentBrowserIDs() throws -> [BrowserID] { recentIDs }

    func saveRecentBrowserIDs(_ ids: [BrowserID]) throws { recentIDs = ids }

    func browserAlternateNames() throws -> [BrowserID: String] { alternateNames }

    func saveBrowserAlternateNames(_ names: [BrowserID: String]) throws {
        var normalized: [BrowserID: String] = [:]
        for (id, rawName) in names {
            if let value = BrowserDescriptor.normalizedAlternateName(rawName) {
                normalized[id] = value
            }
        }
        alternateNames = normalized
    }

    func customBrowsers() throws -> [BrowserDescriptor] {
        browsers.values.sorted { $0.selectorOrder < $1.selectorOrder }
    }

    func upsertCustomBrowser(_ browser: BrowserDescriptor) throws {
        browsers[browser.id] = browser
    }

    func deleteCustomBrowser(id: BrowserID) throws {
        browsers.removeValue(forKey: id)
    }
}

@MainActor
final class InMemorySettingsRepository: SettingsRepository {
    private var settings: AppSettings

    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        self.settings = settings
    }
}
