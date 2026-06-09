import Foundation

/// The kind of filesystem object a `DiskNode` represents.
public enum NodeType: String, Sendable, Codable, CaseIterable {
    case file
    case directory
    case symlink
    case package
    case inaccessible
    case unknown

    /// Whether the Runtah Map / table may drill into this node.
    public var isDrillable: Bool {
        self == .directory
    }

    /// A human-friendly label for the inspector / table "Kind" column.
    public var displayLabel: String {
        switch self {
        case .file: return "File"
        case .directory: return "Folder"
        case .symlink: return "Symbolic Link"
        case .package: return "Package"
        case .inaccessible: return "Inaccessible"
        case .unknown: return "Unknown"
        }
    }
}

/// One node in the scanned filesystem tree.
///
/// ## Concurrency
/// `DiskNode` is a reference type so the tree can be shared cheaply and used as a
/// SwiftUI `Identifiable`. **Every stored property is `let`** — a node is built once,
/// bottom-up, on the scanner's task and is *never mutated afterwards*. That immutability
/// is what makes `@unchecked Sendable` sound: once a finished `ScanResult` crosses to the
/// `@MainActor`, no field can change, so there is no shared-mutable state to race on.
///
/// Post-trash "removal" is **not** modeled by mutating the tree; it lives as an id overlay
/// on `DiskNodeStore` (`removedIDs` + size deltas). The tree stays read-only forever.
///
/// Parent navigation uses `parentID` resolved through `ScanResult.index` / `DiskNodeStore`,
/// so there are no mutable back-pointers.
public final class DiskNode: Identifiable, Hashable, @unchecked Sendable {
    /// Canonical (symlink-resolved, standardized) absolute path. Also the selection /
    /// basket key, stable across rescans.
    public let id: String
    /// Canonical path of the parent, or `nil` for the scan root.
    public let parentID: String?
    /// Display name (last path component).
    public let name: String
    /// The on-disk URL (not symlink-resolved — points at the item as discovered).
    public let url: URL
    public let type: NodeType
    /// Depth from the scan root (root = 0).
    public let depth: Int

    public let isHidden: Bool
    public let isReadable: Bool
    public let isPackage: Bool
    public let isSymlink: Bool
    /// Lowercased file extension without the dot, or `nil`.
    public let fileExtension: String?

    public let modifiedDate: Date?
    public let createdDate: Date?

    /// Logical size in bytes. For containers this is the post-order sum of descendants.
    public let byteSize: Int64
    /// Allocated (on-disk) size in bytes. Aggregated in parallel with `byteSize`.
    public let allocatedSize: Int64

    /// Direct children (empty for leaves and for packages presented as leaves).
    public let children: [DiskNode]

    /// Aggregate counts within this subtree (self excluded).
    public let fileCount: Int
    public let folderCount: Int
    public let inaccessibleCount: Int

    /// Set only for `.inaccessible` nodes.
    public let scanError: ScanError?

    public init(
        id: String,
        parentID: String?,
        name: String,
        url: URL,
        type: NodeType,
        depth: Int,
        isHidden: Bool,
        isReadable: Bool,
        isPackage: Bool,
        isSymlink: Bool,
        fileExtension: String?,
        modifiedDate: Date?,
        createdDate: Date?,
        byteSize: Int64,
        allocatedSize: Int64,
        children: [DiskNode],
        fileCount: Int,
        folderCount: Int,
        inaccessibleCount: Int,
        scanError: ScanError?
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.url = url
        self.type = type
        self.depth = depth
        self.isHidden = isHidden
        self.isReadable = isReadable
        self.isPackage = isPackage
        self.isSymlink = isSymlink
        self.fileExtension = fileExtension
        self.modifiedDate = modifiedDate
        self.createdDate = createdDate
        self.byteSize = byteSize
        self.allocatedSize = allocatedSize
        self.children = children
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.inaccessibleCount = inaccessibleCount
        self.scanError = scanError
    }

    /// The single size accessor used everywhere (aggregation, map, table, basket),
    /// so logical-vs-allocated never drifts between subsystems.
    public func effectiveSize(useAllocated: Bool) -> Int64 {
        useAllocated ? allocatedSize : byteSize
    }

    /// Whether this node is a container the UI can expand/drill (directory, or a
    /// package when packages are treated as folders → it has children).
    public var isContainer: Bool {
        type == .directory || (type == .package && !children.isEmpty)
    }

    /// Total number of items in this subtree, including self.
    public var totalItemCount: Int {
        1 + fileCount + folderCount + inaccessibleCount
    }

    // MARK: Hashable / Identifiable by canonical id.
    public static func == (lhs: DiskNode, rhs: DiskNode) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
