import SwiftUI
import RuntahioCore

/// Whole-scan analysis views (largest / old / types / duplicates / inaccessible).
/// Routed by `vm.contentMode`. Each subview computes its data off the main actor.
struct AnalysisView: View {
    @Environment(ScanViewModel.self) private var vm

    var body: some View {
        switch vm.contentMode {
        case .largest:
            AnalysisFileList(mode: .largest)
        case .oldest:
            AnalysisFileList(mode: .oldest)
        case .types:
            CategoryBreakdownView()
        case .duplicates:
            DuplicatesView()
        case .inaccessible:
            InaccessibleListView()
        case .explorer:
            EmptyView()
        }
    }

    nonisolated static let fileLimit = 250
    nonisolated static let duplicateMinSize: Int64 = 4096
}

// MARK: - Largest / Old files

private struct AnalysisFileList: View {
    let mode: ContentMode
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppSettings.self) private var settings
    @State private var files: [DiskNode] = []

    var body: some View {
        @Bindable var vm = vm
        Group {
            if files.isEmpty {
                ContentUnavailableView("Nothing to show", systemImage: "tray",
                                       description: Text("No files matched this view."))
            } else {
                Table(of: DiskNode.self, selection: $vm.selectedNodeID) {
                    TableColumn("Name") { node in
                        HStack(spacing: 6) {
                            Image(systemName: NodeUI.icon(for: node)).foregroundStyle(NodeUI.iconColor(for: node))
                            Text(node.name).lineLimit(1)
                        }
                    }
                    TableColumn("Size") { node in
                        Text(ByteSizeFormatter.string(vm.displaySize(node)))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .width(min: 64, ideal: 88, max: 120)
                    TableColumn("Modified") { node in
                        Text(node.modifiedDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 90, ideal: 130, max: 180)
                    TableColumn("Path") { node in
                        Text(node.url.path(percentEncoded: false))
                            .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                            .help(node.url.path(percentEncoded: false))
                    }
                } rows: {
                    ForEach(files) { TableRow($0) }
                }
                .contextMenu(forSelectionType: DiskNode.ID.self) { ids in
                    if let id = ids.first, let node = vm.store.node(id: id) { NodeContextMenu(node: node) }
                } primaryAction: { ids in
                    if let id = ids.first, let node = vm.store.node(id: id) { FileActions.quickLook(node.url) }
                }
            }
        }
        .task(id: "\(mode.rawValue)|\(vm.focusNodeID ?? "")|\(vm.store.removedIDs.count)|\(settings.useAllocatedSize)") {
            await recompute()
        }
    }

    private func recompute() async {
        guard let root = vm.rootNode else { files = []; return }
        let useAllocated = settings.useAllocatedSize
        let excluding = vm.store.removedIDs
        let mode = self.mode
        let computed = await Task.detached(priority: .userInitiated) {
            switch mode {
            case .oldest:
                return ScanAnalytics.oldestFiles(in: root, limit: AnalysisView.fileLimit,
                                                 useAllocated: useAllocated, excluding: excluding)
            default:
                return ScanAnalytics.largestFiles(in: root, limit: AnalysisView.fileLimit,
                                                  useAllocated: useAllocated, excluding: excluding)
            }
        }.value
        files = computed
    }
}

// MARK: - File type breakdown

private struct CategoryBreakdownView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var stats: [CategoryStat] = []

    private var total: Int64 { stats.reduce(0) { $0 + $1.totalSize } }
    private var maxSize: Int64 { stats.map(\.totalSize).max() ?? 1 }

    var body: some View {
        Group {
            if stats.isEmpty {
                ContentUnavailableView("No files", systemImage: "chart.pie")
            } else {
                List(stats) { stat in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(RuntahPalette.swatch(for: stat.category, colorScheme: colorScheme))
                            .frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(stat.category.displayLabel)
                                Spacer()
                                Text("\(ByteSizeFormatter.string(stat.totalSize)) · \(stat.fileCount.formatted()) files")
                                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.quaternary).frame(height: 6)
                                    Capsule()
                                        .fill(RuntahPalette.swatch(for: stat.category, colorScheme: colorScheme))
                                        .frame(width: geo.size.width * barFraction(stat), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .task(id: "types|\(vm.focusNodeID ?? "")|\(vm.store.removedIDs.count)|\(settings.useAllocatedSize)") {
            await recompute()
        }
    }

    private func barFraction(_ stat: CategoryStat) -> CGFloat {
        maxSize > 0 ? CGFloat(Double(stat.totalSize) / Double(maxSize)) : 0
    }

    private func recompute() async {
        guard let root = vm.rootNode else { stats = []; return }
        let useAllocated = settings.useAllocatedSize
        let excluding = vm.store.removedIDs
        stats = await Task.detached(priority: .userInitiated) {
            ScanAnalytics.categoryBreakdown(in: root, useAllocated: useAllocated, excluding: excluding)
        }.value
    }
}

// MARK: - Duplicates

private struct DuplicatesView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppState.self) private var appState
    @State private var groups: [DuplicateGroup] = []

    private var totalReclaimable: Int64 { groups.reduce(0) { $0 + $1.reclaimable } }

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView("No duplicates found", systemImage: "doc.on.doc",
                                       description: Text("No same-name, same-size files of 4 KB or larger."))
            } else {
                List {
                    Section {
                        Text("\(groups.count) duplicate sets · up to \(ByteSizeFormatter.string(totalReclaimable)) reclaimable")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(groups) { group in
                        DisclosureGroup {
                            ForEach(group.nodes) { node in
                                HStack {
                                    Text(node.url.path(percentEncoded: false))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Button("Add") { appState.addToBasket(node) }
                                        .controlSize(.small)
                                        .disabled(appState.policy.isProtected(node.url, scanRoot: vm.scanRoot).isBlocked)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc").foregroundStyle(.tint)
                                Text(group.name).lineLimit(1)
                                Text("× \(group.count)").foregroundStyle(.secondary)
                                Spacer()
                                Text("\(ByteSizeFormatter.string(group.size)) each · \(ByteSizeFormatter.string(group.reclaimable)) reclaimable")
                                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                                Button("Add extras") { appState.addNodesToBasket(group.extras) }
                                    .controlSize(.small)
                                    .help("Add all but one copy to the Runtah Basket")
                            }
                        }
                    }
                }
            }
        }
        .task(id: "dupes|\(vm.focusNodeID ?? "")|\(vm.store.removedIDs.count)") {
            await recompute()
        }
    }

    private func recompute() async {
        guard let root = vm.rootNode else { groups = []; return }
        let excluding = vm.store.removedIDs
        groups = await Task.detached(priority: .userInitiated) {
            ScanAnalytics.duplicateGroups(in: root, minSize: AnalysisView.duplicateMinSize, excluding: excluding)
        }.value
    }
}

// MARK: - Inaccessible items

private struct InaccessibleListView: View {
    @Environment(ScanViewModel.self) private var vm
    @State private var nodes: [DiskNode] = []

    var body: some View {
        Group {
            if nodes.isEmpty {
                ContentUnavailableView("Nothing inaccessible", systemImage: "checkmark.shield",
                                       description: Text("Runtahio could read everything in this scan."))
            } else {
                List {
                    Section {
                        PermissionGuideView(error: nodes.first?.scanError)
                            .listRowInsets(EdgeInsets())
                    }
                    Section("\(nodes.count) inaccessible items") {
                        ForEach(nodes) { node in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.url.path(percentEncoded: false)).lineLimit(1).truncationMode(.middle)
                                if let error = node.scanError {
                                    Text(error.humanMessage).font(.caption).foregroundStyle(.orange)
                                }
                            }
                            .contextMenu { NodeContextMenu(node: node) }
                        }
                    }
                }
            }
        }
        .task(id: "inaccessible|\(vm.focusNodeID ?? "")|\(vm.store.removedIDs.count)") {
            await recompute()
        }
    }

    private func recompute() async {
        guard let root = vm.rootNode else { nodes = []; return }
        let excluding = vm.store.removedIDs
        nodes = await Task.detached(priority: .userInitiated) {
            ScanAnalytics.inaccessibleNodes(in: root, excluding: excluding)
        }.value
    }
}
