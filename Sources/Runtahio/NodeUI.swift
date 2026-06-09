import SwiftUI
import RuntahioCore

/// Shared visuals + context menu for a `DiskNode`, reused by the file table and the
/// analysis views so behavior stays consistent.
enum NodeUI {
    static func icon(for node: DiskNode) -> String {
        switch node.type {
        case .directory: return "folder.fill"
        case .package: return "shippingbox.fill"
        case .symlink: return "arrow.up.forward.app"
        case .inaccessible: return "lock.fill"
        case .unknown: return "questionmark.square"
        case .file: return "doc.fill"
        }
    }

    static func iconColor(for node: DiskNode) -> Color {
        switch node.type {
        case .directory, .package: return .accentColor
        case .inaccessible: return .orange
        case .symlink: return .teal
        default: return .secondary
        }
    }
}

/// The standard right-click menu for any node.
struct NodeContextMenu: View {
    let node: DiskNode
    @Environment(AppState.self) private var appState
    @Environment(ScanViewModel.self) private var vm

    var body: some View {
        if node.isContainer {
            Button("Drill Into") { vm.showExplorer(); vm.drill(into: node.id) }
            Divider()
        } else if vm.contentMode != .explorer {
            Button("Reveal in Map") { revealInMap() }
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

    /// Switch to the explorer focused on the node's parent, with the node selected.
    private func revealInMap() {
        vm.showExplorer()
        if let parent = vm.store.parent(of: node) {
            vm.focus(on: parent.id)
        }
        vm.select(node.id)
    }
}
