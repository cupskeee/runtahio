import Foundation
import CoreGraphics

/// Pure geometry for the Runtah Map sunburst.
///
/// Conventions (used identically by layout, hit-testing, and the view):
/// - Angles are radians, **0 at top, increasing clockwise**.
/// - Forward map for a point at angle θ, radius r about center (cx,cy) in screen
///   coordinates (y down):  `x = cx + r·sin θ`,  `y = cy − r·cos θ`.
/// - Inverse (hit-test): `θ = atan2(dx, −dy)` normalized to `[0, 2π)`.
///
/// Children of a node fill the parent's arc with angle **proportional to size**; the
/// last drawn child absorbs the floating-point remainder so a ring's sweeps sum to the
/// parent arc *exactly* (the angle-sum invariant the tests assert).
public enum RadialLayoutEngine {

    /// Fraction of the available radius reserved for the center "focus" disk.
    public static let centerDiskFraction: Double = 0.22
    /// Outer margin (points) kept clear inside the geometry.
    public static let outerMargin: Double = 8

    /// Resolved ring geometry for a given canvas size.
    public struct Geometry: Sendable, Equatable {
        public let center: CGPoint
        public let centerDiskRadius: Double
        public let ringWidth: Double
        public let availableRadius: Double

        public func innerRadius(forDepth depth: Int) -> Double {
            centerDiskRadius + Double(depth - 1) * ringWidth
        }
        public func outerRadius(forDepth depth: Int) -> Double {
            centerDiskRadius + Double(depth) * ringWidth
        }
    }

    public static func geometry(for size: CGSize, options: RadialLayoutOptions) -> Geometry {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let available = max(0, min(size.width, size.height) / 2 - outerMargin)
        let disk = available * centerDiskFraction
        let rings = max(1, options.maxRings)
        let ringWidth = max(0, (available - disk) / Double(rings))
        return Geometry(center: center, centerDiskRadius: disk, ringWidth: ringWidth, availableRadius: available)
    }

    /// Lays out the sunburst for `focus` and its descendants.
    ///
    /// - Parameters:
    ///   - excludingIDs: node ids to omit (e.g. items just moved to Trash). Omitted
    ///     children have their angle redistributed among remaining siblings.
    public static func layout(
        focus: DiskNode,
        geometry size: CGSize,
        options: RadialLayoutOptions,
        excludingIDs: Set<DiskNode.ID> = []
    ) -> [RadialSegment] {
        let geo = geometry(for: size, options: options)
        guard geo.ringWidth > 0 else { return [] }

        var segments: [RadialSegment] = []
        var nextID = 0
        func makeID() -> Int { defer { nextID += 1 }; return nextID }

        // Depth-first recursion. `depth` is the ring number (1 = direct children of focus).
        func place(parent: DiskNode, start: Double, end: Double, depth: Int) {
            guard depth <= options.maxRings else { return }
            guard segments.count < options.maxSegments else { return }
            let arc = end - start
            guard arc > 0 else { return }

            let useAllocated = options.useAllocatedSize
            let children = parent.children
                .filter { !excludingIDs.contains($0.id) && $0.effectiveSize(useAllocated: useAllocated) > 0 }
                .sorted { $0.effectiveSize(useAllocated: useAllocated) > $1.effectiveSize(useAllocated: useAllocated) }
            guard !children.isEmpty else { return }

            // drawnTotal is the sum over *included* children (so removals rescale cleanly).
            let drawnTotal = children.reduce(0.0) { $0 + Double($1.effectiveSize(useAllocated: useAllocated)) }
            guard drawnTotal > 0 else { return }

            // Partition into visible children and an aggregated "Other".
            var visible: [DiskNode] = []
            var otherSize: Double = 0
            for (rank, child) in children.enumerated() {
                let size = Double(child.effectiveSize(useAllocated: useAllocated))
                let fraction = size / drawnTotal
                let sweep = fraction * arc
                let demote = options.collapseTiny &&
                    (rank >= options.maxChildrenPerRing ||
                     fraction < options.minFraction ||
                     sweep < options.minSweepRadians)
                if demote {
                    otherSize += size
                } else {
                    visible.append(child)
                }
            }

            // Assemble the draw order: visible (already size-desc) then Other last.
            let inner = geo.innerRadius(forDepth: depth)
            let outer = geo.outerRadius(forDepth: depth)
            var cursor = start
            let lastIndex = visible.count - 1 + (otherSize > 0 ? 1 : 0)
            var drawIndex = 0

            for child in visible {
                guard segments.count < options.maxSegments else { return }
                let size = Double(child.effectiveSize(useAllocated: useAllocated))
                let isLast = (drawIndex == lastIndex)
                let segEnd = isLast ? end : cursor + (size / drawnTotal) * arc
                let category = FileCategory.category(for: child)
                segments.append(RadialSegment(
                    id: makeID(),
                    nodeID: child.id,
                    parentNodeID: parent.id,
                    startAngle: cursor,
                    endAngle: segEnd,
                    innerRadius: inner,
                    outerRadius: outer,
                    depth: depth,
                    byteSize: child.effectiveSize(useAllocated: useAllocated),
                    displayName: child.name,
                    hue: category.hue,
                    category: category,
                    isOther: false,
                    isDrillable: child.isContainer
                ))
                // Recurse into drillable children within their own sub-arc.
                if child.isContainer {
                    place(parent: child, start: cursor, end: segEnd, depth: depth + 1)
                }
                cursor = segEnd
                drawIndex += 1
            }

            if otherSize > 0, segments.count < options.maxSegments {
                segments.append(RadialSegment(
                    id: makeID(),
                    nodeID: nil,
                    parentNodeID: parent.id,
                    startAngle: cursor,
                    endAngle: end, // Other always closes the parent arc exactly.
                    innerRadius: inner,
                    outerRadius: outer,
                    depth: depth,
                    byteSize: Int64(otherSize),
                    displayName: "Other",
                    hue: FileCategory.other.hue,
                    category: .other,
                    isOther: true,
                    isDrillable: false
                ))
            }
        }

        place(parent: focus, start: 0, end: 2 * .pi, depth: 1)
        return segments
    }

    /// Returns the segment under `point`, or `nil` if the point is outside all rings.
    /// A point inside the center disk returns `nil` (the view treats that as "drill up").
    public static func hitTest(
        _ segments: [RadialSegment],
        at point: CGPoint,
        geometry size: CGSize
    ) -> RadialSegment? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let r = (dx * dx + dy * dy).squareRoot()
        var theta = atan2(dx, -dy)            // 0 at top, clockwise
        if theta < 0 { theta += 2 * .pi }     // normalize to [0, 2π)

        for seg in segments {
            if r >= seg.innerRadius, r < seg.outerRadius,
               theta >= seg.startAngle, theta < seg.endAngle {
                return seg
            }
        }
        return nil
    }

    /// Whether a point falls inside the central focus disk (used for "drill up").
    public static func isInCenterDisk(
        _ point: CGPoint,
        geometry size: CGSize,
        options: RadialLayoutOptions
    ) -> Bool {
        let geo = geometry(for: size, options: options)
        let dx = Double(point.x - geo.center.x)
        let dy = Double(point.y - geo.center.y)
        return (dx * dx + dy * dy).squareRoot() < geo.centerDiskRadius
    }
}
