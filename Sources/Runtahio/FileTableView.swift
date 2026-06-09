import SwiftUI
import RuntahioCore

/// Sortable, searchable table of the current focus node's children. Selection is shared
/// with the Runtah Map and the inspector; double-clicking a folder drills in.
struct FileTableView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var vm = vm
        Table(of: DiskNode.self, selection: $vm.selectedNodeID, sortOrder: $vm.sortOrder) {
            TableColumn("Name", value: \.nameSortKey) { node in
                nameCell(node)
            }
            TableColumn("Size", value: \.byteSize) { node in
                Text(ByteSizeFormatter.string(vm.displaySize(node)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 64, ideal: 88, max: 120)

            TableColumn("Kind", value: \.kindSortKey) { node in
                Text(node.type.displayLabel).foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 110, max: 150)

            TableColumn("Modified", value: \.modifiedSortKey) { node in
                Text(modifiedString(node)).foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 130, max: 180)

            TableColumn("Path") { node in
                Text(node.url.path(percentEncoded: false))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(node.url.path(percentEncoded: false))
            }
        } rows: {
            ForEach(vm.visibleChildren) { node in
                TableRow(node)
            }
        }
        .contextMenu(forSelectionType: DiskNode.ID.self) { ids in
            if let id = ids.first, let node = vm.store.node(id: id) {
                rowMenu(node)
            }
        } primaryAction: { ids in
            if let id = ids.first, let node = vm.store.node(id: id) {
                if node.isContainer { vm.drill(into: id) }
                else { FileActions.quickLook(node.url) }
            }
        }
        .overlay {
            if vm.visibleChildren.isEmpty {
                ContentUnavailableView {
                    Label(emptyLabel, systemImage: "tray")
                } description: {
                    Text(emptyHint)
                }
            }
        }
    }

    // MARK: Cells

    @ViewBuilder
    private func nameCell(_ node: DiskNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon(for: node))
                .foregroundStyle(iconColor(for: node))
                .frame(width: 16)
            Text(node.name).lineLimit(1)
            if node.isHidden {
                Image(systemName: "eye.slash").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            if node.isContainer {
                Button {
                    vm.drill(into: node.id)
                } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Drill into folder")
            }
        }
    }

    @ViewBuilder
    private func rowMenu(_ node: DiskNode) -> some View {
        if node.isContainer {
            Button("Drill Into") { vm.drill(into: node.id) }
            Divider()
        }
        Button("Reveal in Finder") { FileActions.revealInFinder(node.url) }
        Button("Open") { FileActions.open(node.url) }
        Button("Preview") { FileActions.quickLook(node.url) }
        Divider()
        Button("Add to \(appState.mc.basketName)") { appState.addToBasket(node) }
            .disabled(appState.policy.isProtected(node.url, scanRoot: vm.scanRoot).isBlocked)
        Button("Copy Path") { FileActions.copyPath(node.url) }
    }

    // MARK: Helpers

    private func icon(for node: DiskNode) -> String {
        switch node.type {
        case .directory: return "folder.fill"
        case .package: return "shippingbox.fill"
        case .symlink: return "arrow.up.forward.app"
        case .inaccessible: return "lock.fill"
        case .unknown: return "questionmark.square"
        case .file: return "doc.fill"
        }
    }

    private func iconColor(for node: DiskNode) -> Color {
        switch node.type {
        case .directory, .package: return .accentColor
        case .inaccessible: return .orange
        case .symlink: return .teal
        default: return .secondary
        }
    }

    private func modifiedString(_ node: DiskNode) -> String {
        guard let date = node.modifiedDate else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var emptyLabel: String {
        switch vm.listFilter {
        case .hiddenOnly: return "No hidden items here"
        case .inaccessibleOnly: return "No inaccessible items"
        case .none: return vm.searchText.isEmpty ? "Empty folder" : "No matches"
        }
    }

    private var emptyHint: String {
        vm.searchText.isEmpty ? "Nothing to list at this level." : "Try a different search."
    }
}
