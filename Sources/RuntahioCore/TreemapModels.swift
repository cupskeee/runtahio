import Foundation
import CoreGraphics

/// Which visualization the explorer shows.
public enum VisualizationStyle: String, Sendable, Codable, CaseIterable, Identifiable {
    case radial
    case treemap
    public var id: String { rawValue }

    public var displayLabel: String {
        switch self {
        case .radial: return "Runtah Map"
        case .treemap: return "Treemap"
        }
    }
    public var systemImage: String {
        switch self {
        case .radial: return "circle.hexagongrid"
        case .treemap: return "rectangle.split.3x3"
        }
    }
}

/// A single rectangle in the treemap. Pure value type, Sendable; carries a precomputed
/// `hue` + `category` (not a `Color`) so the engine stays UI-free.
public struct TreemapTile: Identifiable, Sendable, Equatable {
    public let id: Int
    public let nodeID: DiskNode.ID?
    public let parentNodeID: DiskNode.ID?
    /// Layout-space rectangle (origin top-left, y increases downward).
    public let rect: CGRect
    public let depth: Int
    public let byteSize: Int64
    public let displayName: String
    public let hue: Double
    public let category: FileCategory
    public let isOther: Bool
    public let isDrillable: Bool

    public init(
        id: Int, nodeID: DiskNode.ID?, parentNodeID: DiskNode.ID?, rect: CGRect, depth: Int,
        byteSize: Int64, displayName: String, hue: Double, category: FileCategory,
        isOther: Bool, isDrillable: Bool
    ) {
        self.id = id; self.nodeID = nodeID; self.parentNodeID = parentNodeID; self.rect = rect
        self.depth = depth; self.byteSize = byteSize; self.displayName = displayName
        self.hue = hue; self.category = category; self.isOther = isOther;
        self.isDrillable = isDrillable
    }
}

/// Tunables for the treemap layout.
public struct TreemapLayoutOptions: Sendable, Equatable {
    public var maxDepth: Int
    public var maxTiles: Int
    public var padding: Double
    public var headerHeight: Double
    /// Don't recurse into a tile smaller than this (points, per side).
    public var minRecurseSide: Double
    public var collapseTiny: Bool
    public var minFraction: Double
    public var useAllocatedSize: Bool

    public init(
        maxDepth: Int = 3, maxTiles: Int = 3000, padding: Double = 2, headerHeight: Double = 16,
        minRecurseSide: Double = 44, collapseTiny: Bool = true, minFraction: Double = 0.006,
        useAllocatedSize: Bool = false
    ) {
        self.maxDepth = maxDepth; self.maxTiles = maxTiles; self.padding = padding
        self.headerHeight = headerHeight; self.minRecurseSide = minRecurseSide
        self.collapseTiny = collapseTiny; self.minFraction = minFraction
        self.useAllocatedSize = useAllocatedSize
    }
}
