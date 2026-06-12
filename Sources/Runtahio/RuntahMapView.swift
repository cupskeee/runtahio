import SwiftUI
import RuntahioCore

/// The Runtah Map: an original radial "bloom" sunburst drawn with SwiftUI `Canvas`.
/// Hover highlights, single-click selects, double-click drills into folders, and the
/// center disk drills back up. Layout runs off the main actor via `.task(id:)`.
struct RuntahMapView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var segments: [RadialSegment] = []
    @State private var canvasSize: CGSize = .zero
    @State private var hoveredSegmentID: Int?
    @State private var hoverLocation: CGPoint = .zero

    private var hoveredSegment: RadialSegment? {
        guard let id = hoveredSegmentID else { return nil }
        return segments.first { $0.id == id }
    }

    private var layoutSignature: String {
        "\(vm.focusNodeID ?? "")|\(Int(canvasSize.width))x\(Int(canvasSize.height))|"
            + "\(settings.collapseTinySegments)|\(settings.minSegmentFraction)|"
            + "\(settings.useAllocatedSize)|\(vm.store.removedIDs.count)"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    drawMap(context: context, size: size)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoverLocation = location
                        hoveredSegmentID =
                            RadialLayoutEngine.hitTest(
                                segments, at: location, geometry: canvasSize)?.id
                    case .ended:
                        hoveredSegmentID = nil
                    }
                }
                .gesture(SpatialTapGesture(count: 1).onEnded { handleTap($0.location) })
                .highPriorityGesture(
                    SpatialTapGesture(count: 2).onEnded { handleDoubleTap($0.location) })

                if let segment = hoveredSegment {
                    tooltip(for: segment)
                        .position(tooltipPosition(in: geo.size))
                        .allowsHitTesting(false)
                }

                if segments.isEmpty {
                    Text(
                        vm.focusNode?.isContainer == true ? "Empty folder" : "Nothing to visualize"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newValue in canvasSize = newValue }
            .task(id: layoutSignature) { await recompute() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: Layout

    private func recompute() async {
        guard canvasSize.width > 1, canvasSize.height > 1, let focus = vm.focusNode else {
            segments = []
            return
        }
        let options = settings.radialLayoutOptions
        let excluding = vm.store.removedIDs
        let size = canvasSize
        let computed = await Task.detached(priority: .userInitiated) {
            RadialLayoutEngine.layout(
                focus: focus, geometry: size, options: options, excludingIDs: excluding)
        }.value
        segments = computed
    }

    // MARK: Drawing

    private func drawMap(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let selected = vm.selectedNodeID

        for segment in segments {
            let path = sectorPath(segment, size: size)
            let isSelected = segment.nodeID != nil && segment.nodeID == selected
            let isHovered = segment.id == hoveredSegmentID
            let color = RuntahPalette.color(
                for: segment, colorScheme: colorScheme,
                isSelected: isSelected, isHovered: isHovered)
            context.fill(path, with: .color(color))
            context.stroke(
                path, with: .color(RuntahPalette.stroke(colorScheme: colorScheme)), lineWidth: 0.75)
            if isSelected {
                context.stroke(path, with: .color(.primary), lineWidth: 1.8)
            }
        }

        // Center focus disk + label.
        let geo = RadialLayoutEngine.geometry(for: size, options: settings.radialLayoutOptions)
        let radius = geo.centerDiskRadius
        let diskRect = CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Circle().path(in: diskRect),
            with: .color(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06)))
        context.stroke(
            Circle().path(in: diskRect), with: .color(.secondary.opacity(0.4)), lineWidth: 1)

        if let focus = vm.focusNode, radius > 22 {
            let name = focus.name.isEmpty ? "/" : focus.name
            let sizeText = ByteSizeFormatter.string(vm.displaySize(focus))
            context.draw(
                Text(name).font(.caption).bold().foregroundStyle(.primary),
                at: CGPoint(x: center.x, y: center.y - 8))
            context.draw(
                Text(sizeText).font(.caption2).foregroundStyle(.secondary),
                at: CGPoint(x: center.x, y: center.y + 9))
            if vm.canGoToParent {
                context.draw(
                    Text("↑ up").font(.system(size: 9)).foregroundStyle(.tertiary),
                    at: CGPoint(x: center.x, y: center.y + 24))
            }
        }
    }

    private func sectorPath(_ segment: RadialSegment, size: CGSize) -> Path {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func point(_ theta: Double, _ r: Double) -> CGPoint {
            CGPoint(x: center.x + r * sin(theta), y: center.y - r * cos(theta))
        }
        let sweep = segment.endAngle - segment.startAngle
        let steps = max(1, Int(ceil(sweep / (.pi / 90))))  // ~2° resolution
        var path = Path()
        for i in 0...steps {
            let t = segment.startAngle + sweep * Double(i) / Double(steps)
            let p = point(t, segment.outerRadius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        for i in 0...steps {
            let t = segment.endAngle - sweep * Double(i) / Double(steps)
            path.addLine(to: point(t, segment.innerRadius))
        }
        path.closeSubpath()
        return path
    }

    // MARK: Interaction

    private func handleTap(_ location: CGPoint) {
        if let segment = RadialLayoutEngine.hitTest(segments, at: location, geometry: canvasSize) {
            if let id = segment.nodeID { vm.select(id) }
        } else if RadialLayoutEngine.isInCenterDisk(
            location, geometry: canvasSize, options: settings.radialLayoutOptions)
        {
            vm.select(vm.focusNodeID)
        }
    }

    private func handleDoubleTap(_ location: CGPoint) {
        if let segment = RadialLayoutEngine.hitTest(segments, at: location, geometry: canvasSize) {
            if segment.isDrillable, let id = segment.nodeID { vm.drill(into: id) }
        } else if RadialLayoutEngine.isInCenterDisk(
            location, geometry: canvasSize, options: settings.radialLayoutOptions)
        {
            vm.goToParent()
        }
    }

    // MARK: Tooltip

    @ViewBuilder
    private func tooltip(for segment: RadialSegment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(segment.displayName).font(.caption).bold()
            Text("\(ByteSizeFormatter.string(segment.byteSize)) · \(segment.category.displayLabel)")
                .font(.caption2).foregroundStyle(.secondary)
            if let id = segment.nodeID, let node = vm.store.node(id: id) {
                Text(node.url.path(percentEncoded: false))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        .shadow(radius: 4, y: 1)
    }

    private func tooltipPosition(in size: CGSize) -> CGPoint {
        let x = min(max(hoverLocation.x, 130), size.width - 130)
        let y = min(max(hoverLocation.y - 44, 30), size.height - 30)
        return CGPoint(x: x, y: y)
    }

    private var accessibilityDescription: String {
        guard let focus = vm.focusNode else { return "Runtah Map. No scan loaded." }
        let topNames =
            segments
            .filter { $0.depth == 1 && !$0.isOther }
            .prefix(5)
            .map { "\($0.displayName), \(ByteSizeFormatter.string($0.byteSize))" }
            .joined(separator: "; ")
        return
            "Runtah Map for \(focus.name), total \(ByteSizeFormatter.string(vm.displaySize(focus))). Largest items: \(topNames)."
    }
}
