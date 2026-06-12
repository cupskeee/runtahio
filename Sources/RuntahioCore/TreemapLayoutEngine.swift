import Foundation
import CoreGraphics

/// Pure squarified treemap layout (Bruls, Huizing & van Wijk), with nesting.
///
/// Children of a node tile the node's rectangle with area proportional to size; folder
/// tiles are recursed into (inset, with a header strip for the label) up to `maxDepth`.
/// Parent tiles are emitted before their children, so drawing in order paints children
/// on top.
public enum TreemapLayoutEngine {

    public static func layout(
        focus: DiskNode,
        rect: CGRect,
        options: TreemapLayoutOptions,
        excludingIDs: Set<DiskNode.ID> = []
    ) -> [TreemapTile] {
        guard rect.width > 1, rect.height > 1 else { return [] }
        var tiles: [TreemapTile] = []
        var nextID = 0
        func makeID() -> Int { defer { nextID += 1 }; return nextID }

        func place(parent: DiskNode, rect: CGRect, depth: Int) {
            guard depth <= options.maxDepth, tiles.count < options.maxTiles else { return }
            guard rect.width > 1, rect.height > 1 else { return }

            let useAllocated = options.useAllocatedSize
            let children = parent.children
                .filter {
                    !excludingIDs.contains($0.id)
                        && $0.effectiveSize(useAllocated: useAllocated) > 0
                }
                .sorted {
                    $0.effectiveSize(useAllocated: useAllocated)
                        > $1.effectiveSize(useAllocated: useAllocated)
                }
            guard !children.isEmpty else { return }

            let drawnTotal = children.reduce(0.0) {
                $0 + Double($1.effectiveSize(useAllocated: useAllocated))
            }
            guard drawnTotal > 0 else { return }

            // Partition tiny children into an aggregated "Other".
            var visible: [DiskNode] = []
            var otherSize: Double = 0
            for child in children {
                let fraction = Double(child.effectiveSize(useAllocated: useAllocated)) / drawnTotal
                if options.collapseTiny && fraction < options.minFraction {
                    otherSize += Double(child.effectiveSize(useAllocated: useAllocated))
                } else {
                    visible.append(child)
                }
            }

            // Build the area list (sizes, scaled to the rect's area).
            var sizes = visible.map { Double($0.effectiveSize(useAllocated: useAllocated)) }
            if otherSize > 0 { sizes.append(otherSize) }
            let rectArea = Double(rect.width) * Double(rect.height)
            let scale = rectArea / sizes.reduce(0, +)
            let areas = sizes.map { $0 * scale }
            let rects = squarify(areas: areas, in: rect)

            for (index, frame) in rects.enumerated() {
                guard tiles.count < options.maxTiles else { return }
                let isOther = otherSize > 0 && index == visible.count
                if isOther {
                    tiles.append(
                        TreemapTile(
                            id: makeID(), nodeID: nil, parentNodeID: parent.id, rect: frame,
                            depth: depth,
                            byteSize: Int64(otherSize), displayName: "Other",
                            hue: FileCategory.other.hue,
                            category: .other, isOther: true, isDrillable: false))
                    continue
                }
                let child = visible[index]
                let category = FileCategory.category(for: child)
                tiles.append(
                    TreemapTile(
                        id: makeID(), nodeID: child.id, parentNodeID: parent.id, rect: frame,
                        depth: depth,
                        byteSize: child.effectiveSize(useAllocated: useAllocated),
                        displayName: child.name,
                        hue: category.hue, category: category, isOther: false,
                        isDrillable: child.isContainer))

                // Recurse into folder tiles that are big enough, reserving a header strip.
                if child.isContainer, depth < options.maxDepth,
                    frame.width >= options.minRecurseSide, frame.height >= options.minRecurseSide
                {
                    let inner = CGRect(
                        x: frame.minX + options.padding,
                        y: frame.minY + options.headerHeight,
                        width: frame.width - 2 * options.padding,
                        height: frame.height - options.headerHeight - options.padding)
                    if inner.width > 1, inner.height > 1 {
                        place(parent: child, rect: inner, depth: depth + 1)
                    }
                }
            }
        }

        place(parent: focus, rect: rect, depth: 1)
        return tiles
    }

    /// Returns the deepest (most specific) tile containing `point`.
    public static func hitTest(_ tiles: [TreemapTile], at point: CGPoint) -> TreemapTile? {
        var best: TreemapTile?
        for tile in tiles where tile.rect.contains(point) {
            if best == nil || tile.depth >= best!.depth { best = tile }
        }
        return best
    }

    // MARK: Squarify

    /// Lays out `areas` (summing to `rect`'s area) into rectangles with good aspect ratios,
    /// preserving input order. Each input area maps 1:1 to an output rect.
    static func squarify(areas: [Double], in rect: CGRect) -> [CGRect] {
        var result = [CGRect](repeating: .zero, count: areas.count)
        var free = rect
        var i = 0
        let n = areas.count

        while i < n {
            let shortSide = Double(min(free.width, free.height))
            guard shortSide > 0 else { break }

            // Grow the current row while it improves the worst aspect ratio.
            var rowCount = 1
            var rowSum = areas[i]
            while i + rowCount < n {
                let nextSum = rowSum + areas[i + rowCount]
                let currentWorst = worst(
                    rowSum: rowSum, maxArea: maxIn(areas, i, rowCount),
                    minArea: minIn(areas, i, rowCount), side: shortSide)
                let nextWorst = worst(
                    rowSum: nextSum, maxArea: maxIn(areas, i, rowCount + 1),
                    minArea: minIn(areas, i, rowCount + 1), side: shortSide)
                if nextWorst <= currentWorst {
                    rowCount += 1
                    rowSum = nextSum
                } else {
                    break
                }
            }

            // Lay the row along the short side; thickness runs along the long side.
            let thickness = rowSum / shortSide
            if free.width >= free.height {
                var y = Double(free.minY)
                for k in 0..<rowCount {
                    let h = areas[i + k] / thickness
                    result[i + k] = CGRect(x: free.minX, y: y, width: thickness, height: h)
                    y += h
                }
                free = CGRect(
                    x: Double(free.minX) + thickness, y: Double(free.minY),
                    width: Double(free.width) - thickness, height: Double(free.height))
            } else {
                var x = Double(free.minX)
                for k in 0..<rowCount {
                    let w = areas[i + k] / thickness
                    result[i + k] = CGRect(x: x, y: free.minY, width: w, height: thickness)
                    x += w
                }
                free = CGRect(
                    x: Double(free.minX), y: Double(free.minY) + thickness,
                    width: Double(free.width), height: Double(free.height) - thickness)
            }
            i += rowCount
        }
        return result
    }

    private static func worst(rowSum: Double, maxArea: Double, minArea: Double, side: Double)
        -> Double
    {
        guard rowSum > 0, side > 0, minArea > 0 else { return .infinity }
        let s2 = rowSum * rowSum
        let w2 = side * side
        return Swift.max((w2 * maxArea) / s2, s2 / (w2 * minArea))
    }
    private static func maxIn(_ a: [Double], _ start: Int, _ count: Int) -> Double {
        var m = a[start]; for k in 1..<count { m = Swift.max(m, a[start + k]) }; return m
    }
    private static func minIn(_ a: [Double], _ start: Int, _ count: Int) -> Double {
        var m = a[start]; for k in 1..<count { m = Swift.min(m, a[start + k]) }; return m
    }
}
