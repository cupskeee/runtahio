import Foundation

/// Coarse file category used to color Runtah Map segments (color *by file type*).
/// Hue values are normalized [0,1) and converted to `Color` at draw time in the view,
/// so this stays SwiftUI-free and Sendable.
public enum FileCategory: String, Sendable, CaseIterable {
    case folder
    case image
    case video
    case audio
    case document
    case code
    case archive
    case app
    case other

    /// Base hue (0...1) in a calm, cool "bloom" palette — deliberately NOT a
    /// DaisyDisk-style bright orange ring. The view modulates lightness by depth.
    public var hue: Double {
        switch self {
        case .folder: return 0.55  // teal
        case .image: return 0.45  // seafoam green
        case .video: return 0.62  // periwinkle blue
        case .audio: return 0.78  // soft plum
        case .document: return 0.58  // slate blue
        case .code: return 0.83  // muted magenta
        case .archive: return 0.10  // warm sand (sparingly)
        case .app: return 0.50  // cyan
        case .other: return 0.0  // neutral gray (saturation handled in view)
        }
    }

    /// Whether this category should render with near-zero saturation (neutral gray).
    public var isNeutral: Bool { self == .other }

    public var displayLabel: String {
        switch self {
        case .folder: return "Folders"
        case .image: return "Images"
        case .video: return "Video"
        case .audio: return "Audio"
        case .document: return "Documents"
        case .code: return "Code"
        case .archive: return "Archives"
        case .app: return "Apps"
        case .other: return "Other"
        }
    }

    /// Maps a `DiskNode` to a category for coloring.
    public static func category(for node: DiskNode) -> FileCategory {
        switch node.type {
        case .directory:
            return .folder
        case .package:
            return node.fileExtension == "app" ? .app : .folder
        case .inaccessible, .unknown, .symlink:
            return .other
        case .file:
            return category(forExtension: node.fileExtension)
        }
    }

    /// Maps a lowercased extension (no dot) to a category.
    public static func category(forExtension ext: String?) -> FileCategory {
        guard let ext, !ext.isEmpty else { return .other }
        if imageExts.contains(ext) { return .image }
        if videoExts.contains(ext) { return .video }
        if audioExts.contains(ext) { return .audio }
        if documentExts.contains(ext) { return .document }
        if codeExts.contains(ext) { return .code }
        if archiveExts.contains(ext) { return .archive }
        if appExts.contains(ext) { return .app }
        return .other
    }

    private static let imageExts: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp",
        "raw", "cr2", "nef", "arw", "dng", "psd", "svg", "ico", "icns",
    ]
    private static let videoExts: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mpg", "mpeg",
        "3gp", "prores", "hevc",
    ]
    private static let audioExts: Set<String> = [
        "mp3", "aac", "m4a", "wav", "aiff", "aif", "flac", "ogg", "wma", "alac", "caf",
    ]
    private static let documentExts: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers",
        "key", "txt", "rtf", "md", "csv", "epub", "odt", "ods",
    ]
    private static let codeExts: Set<String> = [
        "swift", "c", "cpp", "h", "hpp", "m", "mm", "java", "kt", "py", "rb", "js",
        "ts", "tsx", "jsx", "go", "rs", "php", "html", "css", "json", "xml", "yaml",
        "yml", "sh", "pl", "sql", "toml", "gradle",
    ]
    private static let archiveExts: Set<String> = [
        "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "pkg", "iso",
        "jar", "war", "cab",
    ]
    private static let appExts: Set<String> = [
        "app", "xpc", "framework", "bundle", "plugin", "kext", "appex",
    ]
}

/// A single drawn arc of the Runtah Map sunburst. Pure value type, Sendable; carries a
/// precomputed `hue` + `category` (not a `Color`) so the layout engine stays UI-free.
public struct RadialSegment: Identifiable, Sendable, Equatable {
    public let id: Int
    /// `nil` for the synthetic "Other" aggregate and the center disk.
    public let nodeID: DiskNode.ID?
    public let parentNodeID: DiskNode.ID?
    /// Angles in radians, 0 at top, increasing clockwise.
    public let startAngle: Double
    public let endAngle: Double
    public let innerRadius: Double
    public let outerRadius: Double
    public let depth: Int
    public let byteSize: Int64
    public let displayName: String
    public let hue: Double
    public let category: FileCategory
    /// True for a synthetic "Other" segment aggregating many tiny siblings.
    public let isOther: Bool
    /// True if the underlying node is drillable (directory/treated-as-folder package).
    public let isDrillable: Bool

    public init(
        id: Int,
        nodeID: DiskNode.ID?,
        parentNodeID: DiskNode.ID?,
        startAngle: Double,
        endAngle: Double,
        innerRadius: Double,
        outerRadius: Double,
        depth: Int,
        byteSize: Int64,
        displayName: String,
        hue: Double,
        category: FileCategory,
        isOther: Bool,
        isDrillable: Bool
    ) {
        self.id = id
        self.nodeID = nodeID
        self.parentNodeID = parentNodeID
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.depth = depth
        self.byteSize = byteSize
        self.displayName = displayName
        self.hue = hue
        self.category = category
        self.isOther = isOther
        self.isDrillable = isDrillable
    }

    public var sweep: Double { endAngle - startAngle }
}

/// Tunables for the radial layout pass.
public struct RadialLayoutOptions: Sendable, Equatable {
    /// How many rings (depth levels) to draw beyond the center disk.
    public var maxRings: Int
    /// Hard cap on total drawn segments (performance backstop).
    public var maxSegments: Int
    /// Collapse tiny siblings into an "Other" wedge.
    public var collapseTiny: Bool
    /// A child whose fraction of its parent is below this is eligible for "Other".
    public var minFraction: Double
    /// A child whose angular sweep (radians) is below this is eligible for "Other".
    public var minSweepRadians: Double
    /// Beyond this rank within a parent, remaining children collapse into "Other".
    public var maxChildrenPerRing: Int
    /// Use allocated size instead of logical size for proportions.
    public var useAllocatedSize: Bool

    public init(
        maxRings: Int = 5,
        maxSegments: Int = 4000,
        collapseTiny: Bool = true,
        minFraction: Double = 0.004,
        minSweepRadians: Double = 1.2 * .pi / 180,
        maxChildrenPerRing: Int = 48,
        useAllocatedSize: Bool = false
    ) {
        self.maxRings = maxRings
        self.maxSegments = maxSegments
        self.collapseTiny = collapseTiny
        self.minFraction = minFraction
        self.minSweepRadians = minSweepRadians
        self.maxChildrenPerRing = maxChildrenPerRing
        self.useAllocatedSize = useAllocatedSize
    }
}
