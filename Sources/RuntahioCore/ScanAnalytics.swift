import Foundation

/// Per-category rollup for the File Types breakdown.
public struct CategoryStat: Identifiable, Sendable, Equatable {
    public var id: FileCategory { category }
    public let category: FileCategory
    public let totalSize: Int64
    public let fileCount: Int

    public init(category: FileCategory, totalSize: Int64, fileCount: Int) {
        self.category = category
        self.totalSize = totalSize
        self.fileCount = fileCount
    }
}

/// A set of file-like leaves that share a name and size — likely duplicates.
public struct DuplicateGroup: Identifiable, Sendable {
    /// Stable key: `"<size>|<lowercased name>"`.
    public let id: String
    public let name: String
    /// Per-file logical size (all members share it).
    public let size: Int64
    public let nodes: [DiskNode]

    public init(id: String, name: String, size: Int64, nodes: [DiskNode]) {
        self.id = id
        self.name = name
        self.size = size
        self.nodes = nodes
    }

    public var count: Int { nodes.count }
    /// Bytes reclaimable if all but one copy are removed.
    public var reclaimable: Int64 { Int64(max(0, count - 1)) * size }
    /// All members except the first (kept) copy — handy for "trash the extras".
    public var extras: [DiskNode] { Array(nodes.dropFirst()) }
}

/// Pure, whole-tree analytics for the post-MVP views (largest / oldest / types /
/// duplicates). All functions are side-effect free and accept an `excluding` set so
/// already-trashed items disappear without a rescan.
public enum ScanAnalytics {

    /// Every file-like leaf in the subtree (files, symlinks, packages, unknown — never
    /// directories or inaccessible nodes), excluding removed ids.
    public static func leaves(in root: DiskNode, excluding: Set<String> = []) -> [DiskNode] {
        var result: [DiskNode] = []
        var stack: [DiskNode] = [root]
        while let node = stack.popLast() {
            if excluding.contains(node.id) { continue }
            if node.isContainer {
                stack.append(contentsOf: node.children)
            } else if node.type != .inaccessible {
                result.append(node)
            }
        }
        return result
    }

    /// Every inaccessible node in the subtree (for the "Inaccessible Items" view).
    public static func inaccessibleNodes(in root: DiskNode, excluding: Set<String> = []) -> [DiskNode] {
        var result: [DiskNode] = []
        var stack: [DiskNode] = [root]
        while let node = stack.popLast() {
            if excluding.contains(node.id) { continue }
            if node.type == .inaccessible { result.append(node) }
            stack.append(contentsOf: node.children)
        }
        return result.sorted { $0.url.path < $1.url.path }
    }

    public static func largestFiles(
        in root: DiskNode, limit: Int, useAllocated: Bool, excluding: Set<String> = []
    ) -> [DiskNode] {
        leaves(in: root, excluding: excluding)
            .sorted { $0.effectiveSize(useAllocated: useAllocated) > $1.effectiveSize(useAllocated: useAllocated) }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public static func oldestFiles(
        in root: DiskNode, limit: Int, minSize: Int64 = 0, useAllocated: Bool, excluding: Set<String> = []
    ) -> [DiskNode] {
        leaves(in: root, excluding: excluding)
            .filter { $0.modifiedDate != nil && $0.effectiveSize(useAllocated: useAllocated) >= minSize }
            .sorted { ($0.modifiedDate ?? .distantFuture) < ($1.modifiedDate ?? .distantFuture) }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public static func categoryBreakdown(
        in root: DiskNode, useAllocated: Bool, excluding: Set<String> = []
    ) -> [CategoryStat] {
        var sizes: [FileCategory: Int64] = [:]
        var counts: [FileCategory: Int] = [:]
        for leaf in leaves(in: root, excluding: excluding) {
            let category = FileCategory.category(for: leaf)
            sizes[category, default: 0] += leaf.effectiveSize(useAllocated: useAllocated)
            counts[category, default: 0] += 1
        }
        return sizes.keys
            .map { CategoryStat(category: $0, totalSize: sizes[$0] ?? 0, fileCount: counts[$0] ?? 0) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    /// Groups leaves by (logical size, lowercased name); returns groups with 2+ members
    /// whose per-file size is at least `minSize`, sorted by reclaimable bytes descending.
    public static func duplicateGroups(
        in root: DiskNode, minSize: Int64 = 0, excluding: Set<String> = []
    ) -> [DuplicateGroup] {
        var buckets: [String: [DiskNode]] = [:]
        for leaf in leaves(in: root, excluding: excluding) where leaf.byteSize >= minSize && leaf.byteSize > 0 {
            let key = "\(leaf.byteSize)|\(leaf.name.lowercased())"
            buckets[key, default: []].append(leaf)
        }
        return buckets
            .filter { $0.value.count > 1 }
            .map { key, nodes in
                DuplicateGroup(id: key, name: nodes[0].name, size: nodes[0].byteSize, nodes: nodes)
            }
            .sorted { $0.reclaimable > $1.reclaimable }
    }
}
