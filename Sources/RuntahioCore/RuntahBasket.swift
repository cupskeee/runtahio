import Foundation
import Observation

/// One item staged for cleanup. Value type captured from a `DiskNode` so it survives
/// rescans and tree changes.
public struct BasketItem: Identifiable, Sendable, Equatable, Hashable {
    /// Canonical id (same as the source `DiskNode.id`).
    public let id: String
    public let name: String
    public let url: URL
    public let byteSize: Int64
    public let allocatedSize: Int64
    public let type: NodeType

    public init(id: String, name: String, url: URL, byteSize: Int64, allocatedSize: Int64, type: NodeType) {
        self.id = id
        self.name = name
        self.url = url
        self.byteSize = byteSize
        self.allocatedSize = allocatedSize
        self.type = type
    }

    public init(node: DiskNode) {
        self.init(id: node.id, name: node.name, url: node.url,
                  byteSize: node.byteSize, allocatedSize: node.allocatedSize, type: node.type)
    }

    /// Size used for reclaimable totals. Allocated size reflects what Trash actually frees.
    public func effectiveSize(useAllocated: Bool) -> Int64 {
        useAllocated ? (allocatedSize > 0 ? allocatedSize : byteSize) : byteSize
    }
}

/// The outcome of attempting to add an item to the basket.
public enum BasketAddResult: Equatable, Sendable {
    case added
    case duplicateIgnored
    case nestedUnderExisting
    case absorbedDescendants(Int)
    case rejectedProtected(BlockReason)
    case needsConfirm(ConfirmReason)

    public var didAdd: Bool {
        switch self {
        case .added, .absorbedDescendants: return true
        default: return false
        }
    }
}

/// The Runtah Basket: items staged to be moved to Trash.
///
/// Keeps items deduplicated and **overlap-safe**: if a folder is added, any already-staged
/// descendants are absorbed; a descendant of an already-staged folder is rejected. The
/// reclaimable total only ever sums *maximal* items, so nested paths can't double-count
/// regardless of insertion order.
@MainActor
@Observable
public final class RuntahBasket {
    public private(set) var items: [BasketItem] = []
    /// When true, reclaimable totals use allocated size. Driven by app settings.
    public var useAllocatedForReclaimable: Bool = false

    public init() {}

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    public func contains(_ id: String) -> Bool { items.contains { $0.id == id } }

    /// Attempts to add `node`, enforcing protection rules and de-duplication.
    @discardableResult
    public func add(
        _ node: DiskNode,
        policy: ProtectedPathPolicy,
        scanRoot: URL?,
        confirmedScanRoot: Bool = false
    ) -> BasketAddResult {
        switch policy.isProtected(node.url, scanRoot: scanRoot) {
        case .blocked(let reason):
            return .rejectedProtected(reason)
        case .needsExplicitConfirm(let reason):
            if !confirmedScanRoot { return .needsConfirm(reason) }
        case .allowed:
            break
        }

        let id = node.id
        if contains(id) { return .duplicateIgnored }
        if items.contains(where: { Self.isDescendant(id, ofAncestorID: $0.id) }) {
            return .nestedUnderExisting
        }

        let absorbed = items.filter { Self.isDescendant($0.id, ofAncestorID: id) }
        if !absorbed.isEmpty {
            let absorbedIDs = Set(absorbed.map(\.id))
            items.removeAll { absorbedIDs.contains($0.id) }
        }
        items.append(BasketItem(node: node))
        return absorbed.isEmpty ? .added : .absorbedDescendants(absorbed.count)
    }

    public func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    public func clear() {
        items.removeAll()
    }

    /// Items with no ancestor also present — the set that would actually be trashed.
    public func maximalItems() -> [BasketItem] {
        items.filter { item in
            !items.contains { other in Self.isDescendant(item.id, ofAncestorID: other.id) }
        }
    }

    /// Overlap-safe total of reclaimable bytes.
    public var totalReclaimable: Int64 {
        maximalItems().reduce(0) { $0 + $1.effectiveSize(useAllocated: useAllocatedForReclaimable) }
    }

    /// The largest few items, for the confirmation dialog.
    public func largestItems(limit: Int) -> [BasketItem] {
        maximalItems()
            .sorted { $0.effectiveSize(useAllocated: useAllocatedForReclaimable) > $1.effectiveSize(useAllocated: useAllocatedForReclaimable) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Path-component helpers (ids are canonical absolute paths).
    static func components(ofID id: String) -> [String] {
        id.split(separator: "/").map(String.init)
    }

    static func isDescendant(_ childID: String, ofAncestorID ancestorID: String) -> Bool {
        guard childID != ancestorID else { return false }
        let ancestor = components(ofID: ancestorID)
        let child = components(ofID: childID)
        guard child.count > ancestor.count, !ancestor.isEmpty else { return false }
        return Array(child.prefix(ancestor.count)) == ancestor
    }
}
