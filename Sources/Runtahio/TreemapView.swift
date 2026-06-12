import SwiftUI
import RuntahioCore

/// A squarified treemap visualization — an alternative to the radial Runtah Map. Nested
/// rectangles sized by usage and colored by file type; hover highlights, click selects,
/// double-click drills into folders (and into the area around tiles drills back up).
struct TreemapView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var tiles: [TreemapTile] = []
    @State private var canvasSize: CGSize = .zero
    @State private var hoveredTileID: Int?
    @State private var hoverLocation: CGPoint = .zero

    private static let inset: CGFloat = 8

    private var hoveredTile: TreemapTile? {
        guard let id = hoveredTileID else { return nil }
        return tiles.first { $0.id == id }
    }

    /// Node ids that have children drawn inside them (folder "header" tiles).
    private var parentTileIDs: Set<DiskNode.ID> {
        Set(tiles.compactMap(\.parentNodeID))
    }

    private var layoutSignature: String {
        "\(vm.focusNodeID ?? "")|\(Int(canvasSize.width))x\(Int(canvasSize.height))|"
            + "\(settings.collapseTinySegments)|\(settings.useAllocatedSize)|\(vm.store.removedIDs.count)"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in draw(context: context, size: size) }
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverLocation = location
                            hoveredTileID = TreemapLayoutEngine.hitTest(tiles, at: location)?.id
                        case .ended:
                            hoveredTileID = nil
                        }
                    }
                    .gesture(SpatialTapGesture(count: 1).onEnded { handleTap($0.location) })
                    .highPriorityGesture(
                        SpatialTapGesture(count: 2).onEnded { handleDoubleTap($0.location) })

                if let tile = hoveredTile {
                    tooltip(for: tile)
                        .position(tooltipPosition(in: geo.size))
                        .allowsHitTesting(false)
                }
                if tiles.isEmpty {
                    Text("Empty folder").font(.callout).foregroundStyle(.secondary)
                }
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newValue in canvasSize = newValue }
            .task(id: layoutSignature) { await recompute() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Treemap of \(vm.focusNode?.name ?? "scan")")
    }

    private func layoutRect(_ size: CGSize) -> CGRect {
        CGRect(
            x: Self.inset, y: Self.inset,
            width: max(0, size.width - 2 * Self.inset),
            height: max(0, size.height - 2 * Self.inset))
    }

    private func recompute() async {
        guard canvasSize.width > 2, canvasSize.height > 2, let focus = vm.focusNode else {
            tiles = []; return
        }
        let options = TreemapLayoutOptions(
            collapseTiny: settings.collapseTinySegments,
            minFraction: max(0.001, settings.minSegmentFraction),
            useAllocatedSize: settings.useAllocatedSize)
        let rect = layoutRect(canvasSize)
        let excluding = vm.store.removedIDs
        tiles = await Task.detached(priority: .userInitiated) {
            TreemapLayoutEngine.layout(
                focus: focus, rect: rect, options: options, excludingIDs: excluding)
        }.value
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let selected = vm.selectedNodeID
        let parents = parentTileIDs
        for tile in tiles {
            let isSelected = tile.nodeID != nil && tile.nodeID == selected
            let isHovered = tile.id == hoveredTileID
            let isParent = tile.nodeID.map { parents.contains($0) } ?? false
            let rounded = Path(roundedRect: tile.rect, cornerRadius: 2)
            var color = RuntahPalette.color(
                for: tile, colorScheme: colorScheme,
                isSelected: isSelected, isHovered: isHovered)
            // Folder tiles that contain children render dimmer (children sit on top).
            if isParent && !isSelected { color = color.opacity(0.55) }
            context.fill(rounded, with: .color(color))
            context.stroke(
                rounded, with: .color(RuntahPalette.stroke(colorScheme: colorScheme)),
                lineWidth: isParent ? 1 : 0.5)
            if isSelected {
                context.stroke(rounded, with: .color(.primary), lineWidth: 2)
            }
            drawLabel(context: context, tile: tile, isParent: isParent)
        }
    }

    private func drawLabel(context: GraphicsContext, tile: TreemapTile, isParent: Bool) {
        let r = tile.rect
        if isParent {
            guard r.width > 46 else { return }
            let text = Text(tile.displayName).font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
            context.draw(text, at: CGPoint(x: r.minX + 6, y: r.minY + 9), anchor: .leading)
        } else {
            guard r.width > 52, r.height > 24 else { return }
            let name = Text(tile.displayName).font(.system(size: 10))
            let sizeText = Text(ByteSizeFormatter.string(tile.byteSize)).font(.system(size: 9))
                .foregroundStyle(.secondary)
            context.draw(name, at: CGPoint(x: r.midX, y: r.midY - 6))
            context.draw(sizeText, at: CGPoint(x: r.midX, y: r.midY + 7))
        }
    }

    private func handleTap(_ location: CGPoint) {
        if let tile = TreemapLayoutEngine.hitTest(tiles, at: location), let id = tile.nodeID {
            vm.select(id)
        } else {
            vm.select(vm.focusNodeID)
        }
    }

    private func handleDoubleTap(_ location: CGPoint) {
        if let tile = TreemapLayoutEngine.hitTest(tiles, at: location) {
            if tile.isDrillable, let id = tile.nodeID { vm.drill(into: id) }
        } else {
            vm.goToParent()  // double-click empty margin → go up
        }
    }

    @ViewBuilder
    private func tooltip(for tile: TreemapTile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tile.displayName).font(.caption).bold()
            Text("\(ByteSizeFormatter.string(tile.byteSize)) · \(tile.category.displayLabel)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        .shadow(radius: 4, y: 1)
    }

    private func tooltipPosition(in size: CGSize) -> CGPoint {
        let x = min(max(hoverLocation.x, 110), size.width - 110)
        let y = min(max(hoverLocation.y - 34, 24), size.height - 24)
        return CGPoint(x: x, y: y)
    }
}
