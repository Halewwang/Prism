import Foundation

public enum BrowserMostRecentOrder {
    /// Most-recent ids first. Ids missing from `existing` are dropped.
    /// Browsers that have never been used keep their relative order after the used ones.
    /// An empty `recentIDs` returns `existing` with duplicates removed.
    public static func orderedIDs(existing: [BrowserID], recentIDs: [BrowserID]) -> [BrowserID] {
        let existingSet = Set(existing)
        var seen = Set<BrowserID>()
        var result: [BrowserID] = []
        result.reserveCapacity(existing.count)
        for id in recentIDs where existingSet.contains(id) && seen.insert(id).inserted {
            result.append(id)
        }
        for id in existing where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }

    /// Moves `id` to the front of the remembered list. Repeats are collapsed.
    public static func remembering(_ id: BrowserID, recentIDs: [BrowserID]) -> [BrowserID] {
        [id] + recentIDs.filter { $0 != id }
    }

    /// Drops uninstalled browsers and duplicate ids while keeping recency order.
    public static func pruned(recentIDs: [BrowserID], installedIDs: [BrowserID]) -> [BrowserID] {
        let installed = Set(installedIDs)
        var seen = Set<BrowserID>()
        return recentIDs.filter { installed.contains($0) && seen.insert($0).inserted }
    }
}
