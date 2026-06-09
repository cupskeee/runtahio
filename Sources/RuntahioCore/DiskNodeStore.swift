import Foundation
import Observation

/// Holds the finished scan tree and a **removal overlay**.
///
/// The `DiskNode` tree is immutable (that's what makes it `Sendable`). Post-trash removal
/// is modeled here, on the `@MainActor`, as a `removedIDs` set plus per-ancestor size
/// deltas — never by mutating the tree. UI reads sizes/children through this store so
/// trashed items disappear and ancestor totals shrink without a rescan.
@MainActor
@Observable
public final class DiskNodeStore {
    public private(set) var result: ScanResult?
    public private(set) var removedIDs: Set<String> = []
    private var logicalDeltas: [String: Int64] = [:]
    private var allocatedDeltas: [String: Int64] = [:]

    public init() {}

    public func load(_ result: ScanResult) {
        self.result = result
        removedIDs = []
        logicalDeltas = [:]
        allocatedDeltas = [:]
    }

    public func clear() {
        result = nil
        removedIDs = []
        logicalDeltas = [:]
        allocatedDeltas = [:]
    }

    public var rootNode: DiskNode? { result?.rootNode }

    public func node(id: String?) -> DiskNode? {
        guard let id else { return nil }
        return result?.index[id]
    }

    public func parent(of node: DiskNode) -> DiskNode? {
        self.node(id: node.parentID)
    }

    /// Path from the scan root down to `node` (inclusive), for breadcrumbs.
    public func breadcrumb(to node: DiskNode) -> [DiskNode] {
        var chain: [DiskNode] = [node]
        var current = node
        while let parent = parent(of: current) {
            chain.append(parent)
            current = parent
        }
        return chain.reversed()
    }

    public func isRemoved(_ id: String) -> Bool { removedIDs.contains(id) }

    /// Direct children with trashed items filtered out.
    public func effectiveChildren(of node: DiskNode) -> [DiskNode] {
        guard !removedIDs.isEmpty else { return node.children }
        return node.children.filter { !removedIDs.contains($0.id) }
    }

    /// Size of `node` adjusted for any trashed descendants.
    public func effectiveSize(of node: DiskNode, useAllocated: Bool) -> Int64 {
        let base = node.effectiveSize(useAllocated: useAllocated)
        let delta = useAllocated ? (allocatedDeltas[node.id] ?? 0) : (logicalDeltas[node.id] ?? 0)
        return max(0, base + delta)
    }

    /// Whole-scan total, adjusted for removals.
    public func effectiveTotalSize(useAllocated: Bool) -> Int64 {
        guard let root = result?.rootNode else { return 0 }
        return effectiveSize(of: root, useAllocated: useAllocated)
    }

    /// Records that the given ids were moved to Trash, subtracting their sizes from every
    /// ancestor so totals stay correct.
    public func markRemoved(ids: [String]) {
        guard let result else { return }
        for id in ids where !removedIDs.contains(id) {
            guard let node = result.index[id] else { continue }
            removedIDs.insert(id)
            var parentID = node.parentID
            while let pid = parentID, let ancestor = result.index[pid] {
                logicalDeltas[pid, default: 0] -= node.byteSize
                allocatedDeltas[pid, default: 0] -= node.allocatedSize
                parentID = ancestor.parentID
            }
        }
    }
}
