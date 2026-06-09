import Foundation
import Observation
import RuntahioCore

/// Non-optional sort keys so SwiftUI `Table` columns (which need `Comparable` key paths)
/// can sort by name/kind/modified without `Optional` Comparable headaches.
extension DiskNode {
    var nameSortKey: String { name.localizedLowercase }
    var kindSortKey: String { type.displayLabel }
    var modifiedSortKey: Date { modifiedDate ?? .distantPast }
}

/// Which view the main content area shows. `.explorer` is the radial map + drill-down
/// table; the rest are whole-scan analysis views.
enum ContentMode: String, CaseIterable, Identifiable, Equatable {
    case explorer, largest, oldest, types, duplicates, inaccessible
    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer: return "Explorer"
        case .largest: return "Largest Files"
        case .oldest: return "Old Files"
        case .types: return "File Types"
        case .duplicates: return "Duplicates"
        case .inaccessible: return "Inaccessible Items"
        }
    }

    var systemImage: String {
        switch self {
        case .explorer: return "circle.hexagongrid"
        case .largest: return "arrow.up.right.square"
        case .oldest: return "calendar.badge.clock"
        case .types: return "chart.pie"
        case .duplicates: return "doc.on.doc"
        case .inaccessible: return "lock"
        }
    }
}

/// Owns one scan's lifecycle, navigation (focus/selection/breadcrumb), and the derived
/// table data. `@MainActor @Observable`; consumes the scanner's `AsyncStream` and only
/// ever touches the immutable tree through `DiskNodeStore`.
@MainActor
@Observable
final class ScanViewModel {
    @ObservationIgnored private let scanner: ScannerService
    @ObservationIgnored let settings: AppSettings
    let store = DiskNodeStore()

    var phase: ScanPhase = .idle
    var progress = ScanProgress()
    var scanRoot: URL?
    var focusNodeID: DiskNode.ID?
    var selectedNodeID: DiskNode.ID?
    var searchText = ""
    var foldersFirst = false
    var contentMode: ContentMode = .explorer
    var sortOrder: [KeyPathComparator<DiskNode>] = [KeyPathComparator(\DiskNode.byteSize, order: .reverse)]
    var lastResult: ScanResult?
    /// Direction of the most recent navigation, used to pick the drill animation.
    var lastNavWasDrillIn = true

    @ObservationIgnored private var scanTask: Task<Void, Never>?

    init(scanner: ScannerService, settings: AppSettings) {
        self.scanner = scanner
        self.settings = settings
    }

    var isScanning: Bool { if case .scanning = phase { return true } else { return false } }
    var useAllocated: Bool { settings.useAllocatedSize }

    // MARK: Lifecycle

    func start(root: URL) {
        cancel()
        store.clear()
        scanRoot = root
        focusNodeID = nil
        selectedNodeID = nil
        searchText = ""
        contentMode = .explorer
        progress = ScanProgress()
        progress.statusText = Microcopy(flavor: settings.flavor).preparingStatus
        phase = .scanning

        let scanner = self.scanner
        let options = settings.scanOptions
        scanTask = Task { [weak self] in
            for await event in await scanner.scan(root: root, options: options) {
                guard let self else { break }
                switch event {
                case .progress(let progress):
                    self.progress = progress
                case .finished(let result):
                    self.store.load(result)
                    self.lastResult = result
                    self.focusNodeID = result.rootNode.id
                    self.phase = .done
                case .failed(let error):
                    self.phase = (error == .cancelled) ? .cancelled : .failed(error)
                }
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning { phase = .cancelled }
    }

    func rescan() {
        if let scanRoot { start(root: scanRoot) }
    }

    // MARK: Navigation

    var rootNode: DiskNode? { store.rootNode }
    var focusNode: DiskNode? { store.node(id: focusNodeID) }
    var selectedNode: DiskNode? { store.node(id: selectedNodeID) }
    var breadcrumb: [DiskNode] { focusNode.map { store.breadcrumb(to: $0) } ?? [] }
    var canGoToParent: Bool { (focusNode.flatMap { store.parent(of: $0) }) != nil }

    func drill(into id: DiskNode.ID) {
        guard let node = store.node(id: id), node.isContainer else { return }
        lastNavWasDrillIn = true
        focusNodeID = id
        selectedNodeID = nil
        searchText = ""
        contentMode = .explorer
    }

    func goToParent() {
        guard let focus = focusNode, let parent = store.parent(of: focus) else { return }
        lastNavWasDrillIn = false
        focusNodeID = parent.id
        selectedNodeID = nil
    }

    func focus(on id: DiskNode.ID) {
        guard let target = store.node(id: id) else { return }
        // Breadcrumb jump: drilling out if the target is an ancestor of the current focus.
        lastNavWasDrillIn = (focusNode?.depth ?? 0) < target.depth
        focusNodeID = id
    }

    func select(_ id: DiskNode.ID?) { selectedNodeID = id }

    // MARK: Sizes

    func displaySize(_ node: DiskNode) -> Int64 { store.effectiveSize(of: node, useAllocated: useAllocated) }

    // MARK: Table data

    var visibleChildren: [DiskNode] {
        guard let focus = focusNode else { return [] }
        var kids = store.effectiveChildren(of: focus)
        if !settings.showHidden { kids = kids.filter { !$0.isHidden } }
        if !searchText.isEmpty {
            kids = kids.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        kids.sort(using: sortOrder)
        if foldersFirst {
            kids = kids.filter { $0.isContainer } + kids.filter { !$0.isContainer }
        }
        return kids
    }

    // MARK: Content mode (explorer vs. whole-scan analysis views)

    func setMode(_ mode: ContentMode) {
        contentMode = mode
        selectedNodeID = nil
    }
    func showExplorer() {
        contentMode = .explorer
        if let root = rootNode { focusNodeID = root.id }
        selectedNodeID = nil
    }
}
