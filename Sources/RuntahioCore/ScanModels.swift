import Foundation

/// Language flavor for status microcopy. Brand nouns ("Runtah Basket", "Runtah Map")
/// stay constant regardless of flavor.
public enum LanguageFlavor: String, Sendable, Codable, CaseIterable {
    case standardEnglish
    case lightIndonesian

    public var displayName: String {
        switch self {
        case .standardEnglish: return "Standard English"
        case .lightIndonesian: return "Light Indonesian flavor"
        }
    }
}

/// Knobs that control a single scan. Sendable so it can cross into the scanner actor.
public struct ScanOptions: Sendable, Equatable {
    /// Whether hidden items are *shown*. They are always *counted* regardless.
    public var showHidden: Bool
    /// Treat packages (.app, .photoslibrary, …) as drillable folders.
    public var treatPackagesAsFolders: Bool
    /// Feed allocated (on-disk) size into aggregation / display instead of logical size.
    public var useAllocatedSizeWhenAvailable: Bool
    /// Optional safety cap on direct children kept per directory (pathological dirs).
    public var maxChildrenPerDir: Int?
    /// Entry names skipped entirely during a scan (not descended, not counted).
    /// Defaults to `.nofollow` — a special macOS root directory that mirrors the whole
    /// filesystem without following firmlinks, which would otherwise double-count almost
    /// the entire disk when scanning `/`.
    public var excludedNames: Set<String>
    /// Emit a progress snapshot at least this often (item-count based).
    public var emitEveryNItems: Int
    /// Emit a progress snapshot at least this often (time based), in milliseconds.
    public var emitIntervalMilliseconds: Int

    /// Names excluded from every scan by default.
    public static let defaultExcludedNames: Set<String> = [".nofollow"]

    public init(
        showHidden: Bool = true,
        treatPackagesAsFolders: Bool = false,
        useAllocatedSizeWhenAvailable: Bool = false,
        maxChildrenPerDir: Int? = nil,
        excludedNames: Set<String> = ScanOptions.defaultExcludedNames,
        emitEveryNItems: Int = 256,
        emitIntervalMilliseconds: Int = 180
    ) {
        self.showHidden = showHidden
        self.treatPackagesAsFolders = treatPackagesAsFolders
        self.useAllocatedSizeWhenAvailable = useAllocatedSizeWhenAvailable
        self.maxChildrenPerDir = maxChildrenPerDir
        self.excludedNames = excludedNames
        self.emitEveryNItems = emitEveryNItems
        self.emitIntervalMilliseconds = emitIntervalMilliseconds
    }
}

/// A throttled snapshot of scan progress. Pure value type, Sendable.
public struct ScanProgress: Sendable, Equatable {
    public var scannedItemCount: Int = 0
    public var scannedFileCount: Int = 0
    public var scannedFolderCount: Int = 0
    public var inaccessibleCount: Int = 0
    public var discoveredSize: Int64 = 0
    public var currentPath: String = ""
    public var currentDisplayName: String = ""
    public var statusText: String = ""
    public var isCancelled: Bool = false

    public init() {}
}

/// The lifecycle of the current scan, owned by the view model.
public enum ScanPhase: Sendable, Equatable {
    case idle
    case scanning
    case done
    case failed(ScanError)
    case cancelled
}

/// The finished result of a scan. Sendable: `rootNode` is an immutable `DiskNode` tree.
public struct ScanResult: Sendable {
    public let rootNode: DiskNode
    public let totalSize: Int64
    public let allocatedTotal: Int64
    public let fileCount: Int
    public let folderCount: Int
    public let inaccessibleCount: Int
    public let scanStartedAt: Date
    public let scanFinishedAt: Date
    public let warnings: [String]
    /// O(1) id → node lookup over the whole tree (selection, basket, parent resolution).
    public let index: [String: DiskNode]

    public init(
        rootNode: DiskNode,
        totalSize: Int64,
        allocatedTotal: Int64,
        fileCount: Int,
        folderCount: Int,
        inaccessibleCount: Int,
        scanStartedAt: Date,
        scanFinishedAt: Date,
        warnings: [String],
        index: [String: DiskNode]
    ) {
        self.rootNode = rootNode
        self.totalSize = totalSize
        self.allocatedTotal = allocatedTotal
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.inaccessibleCount = inaccessibleCount
        self.scanStartedAt = scanStartedAt
        self.scanFinishedAt = scanFinishedAt
        self.warnings = warnings
        self.index = index
    }

    public var duration: TimeInterval { scanFinishedAt.timeIntervalSince(scanStartedAt) }
}

/// The single ordered channel of events emitted by `ScannerService.scan`.
/// Exactly one terminal event (`finished` or `failed`) is emitted last.
public enum ScanEvent: Sendable {
    case progress(ScanProgress)
    case finished(ScanResult)
    case failed(ScanError)
}
