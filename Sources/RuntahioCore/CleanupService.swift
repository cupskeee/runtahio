import Foundation

/// The result of trying to move one item to Trash.
public struct TrashOutcome: Sendable, Equatable {
    public let item: BasketItem
    public let success: Bool
    /// Where the item landed in Trash (when the OS reports it).
    public let resultingURL: URL?
    /// Human-readable failure reason, when `success == false`.
    public let errorMessage: String?
}

/// Summary returned after a cleanup pass.
public struct TrashSummary: Sendable {
    public let outcomes: [TrashOutcome]

    public var succeeded: [TrashOutcome] { outcomes.filter(\.success) }
    public var failed: [TrashOutcome] { outcomes.filter { !$0.success } }
    public var movedCount: Int { succeeded.count }
    public var failedCount: Int { failed.count }
    public var allSucceeded: Bool { failed.isEmpty }
    public var succeededIDs: [String] { succeeded.map(\.item.id) }

    public func reclaimedBytes(useAllocated: Bool) -> Int64 {
        succeeded.reduce(0) { $0 + $1.item.effectiveSize(useAllocated: useAllocated) }
    }
}

/// Moves staged items to the Trash — **never permanently deletes**.
///
/// Uses `FileManager.trashItem(at:resultingItemURL:)` per item, isolating failures so a
/// single un-trashable item never aborts the rest. There is intentionally no call to
/// `removeItem` anywhere in Runtahio.
public actor CleanupService {
    public init() {}

    /// Moves each item to Trash, deepest-path-first. Returns a per-item summary.
    public func moveToTrash(_ items: [BasketItem]) async -> TrashSummary {
        let fileManager = FileManager.default
        // Deepest paths first — harmless since callers pass non-overlapping (maximal)
        // items, but it keeps behavior intuitive if that ever changes.
        let ordered = items.sorted {
            $0.url.pathComponents.count > $1.url.pathComponents.count
        }

        var outcomes: [TrashOutcome] = []
        outcomes.reserveCapacity(ordered.count)

        for item in ordered {
            do {
                var resulting: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &resulting)
                outcomes.append(TrashOutcome(
                    item: item, success: true,
                    resultingURL: resulting as URL?, errorMessage: nil))
            } catch {
                outcomes.append(TrashOutcome(
                    item: item, success: false, resultingURL: nil,
                    errorMessage: (error as NSError).localizedDescription))
            }
        }

        return TrashSummary(outcomes: outcomes)
    }
}
