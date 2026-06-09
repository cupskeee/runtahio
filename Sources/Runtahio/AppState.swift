import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers
import RuntahioCore

/// App-wide state and coordination: services, settings, recent scans, the basket, the
/// current scan view model, and transient UI/dialog state. `@MainActor @Observable`.
@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    let recentScans: RecentScansStore
    let basket: RuntahBasket
    let scan: ScanViewModel

    @ObservationIgnored let scanner = ScannerService()
    @ObservationIgnored let cleanup = CleanupService()
    @ObservationIgnored let policy = ProtectedPathPolicy()

    // UI state
    var showInspector = true
    var basketExpanded = false

    // Transient feedback / dialogs
    var banner: String?
    var pendingScanRootConfirm: DiskNode?
    var showTrashConfirmation = false
    var lastTrashSummary: TrashSummary?
    var isTrashing = false

    // "Lapang Mode" — cumulative space freed to Trash this session.
    var sessionFreedBytes: Int64 = 0

    // Mounted local volumes for the sidebar.
    var volumes: [VolumeInfo] = []

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.recentScans = RecentScansStore()
        let basket = RuntahBasket()
        basket.useAllocatedForReclaimable = settings.useAllocatedSize
        self.basket = basket
        self.scan = ScanViewModel(scanner: scanner, settings: settings)
        self.volumes = VolumeScanner.currentVolumes()
    }

    var mc: Microcopy { Microcopy(flavor: settings.flavor) }
    var strings: Strings { settings.strings }

    // MARK: Volumes

    func refreshVolumes() {
        volumes = VolumeScanner.currentVolumes()
    }

    func eject(_ volume: VolumeInfo) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
            refreshVolumes()
            flash("Ejected \(volume.name).")
        } catch {
            flash("Couldn't eject \(volume.name): \(error.localizedDescription)")
        }
    }

    // MARK: Scanning

    func chooseFolderAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder or volume to analyze with Runtahio"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            startScan(url)
        }
    }

    func startScan(_ url: URL) {
        let name = url.lastPathComponent.isEmpty ? url.path(percentEncoded: false) : url.lastPathComponent
        recentScans.record(url, name: name, limit: settings.recentScansLimit)
        scan.start(root: url)
    }

    func rescan() { scan.rescan() }
    func cancelScan() { scan.cancel() }

    /// Escape: cancel an active scan, else clear selection, else clear the search filter.
    func escape() {
        if scan.isScanning {
            scan.cancel()
        } else if scan.selectedNodeID != nil {
            scan.select(nil)
        } else if !scan.searchText.isEmpty {
            scan.searchText = ""
        }
    }

    // MARK: Basket

    func addToBasket(_ node: DiskNode) {
        switch basket.add(node, policy: policy, scanRoot: scan.scanRoot) {
        case .added, .absorbedDescendants:
            flash("Added to \(mc.basketName).")
        case .duplicateIgnored:
            flash("Already in the \(mc.basketName).")
        case .nestedUnderExisting:
            flash("Already covered by a folder in the \(mc.basketName).")
        case .rejectedProtected(let reason):
            flash(reason.explanation)
        case .needsConfirm:
            pendingScanRootConfirm = node
        }
    }

    func addSelectedToBasket() {
        if let node = scan.selectedNode { addToBasket(node) }
    }

    /// Adds many nodes at once (e.g. duplicate extras), reporting a one-line summary.
    func addNodesToBasket(_ nodes: [DiskNode]) {
        var added = 0, duplicate = 0, blocked = 0
        for node in nodes {
            switch basket.add(node, policy: policy, scanRoot: scan.scanRoot) {
            case .added, .absorbedDescendants: added += 1
            case .duplicateIgnored, .nestedUnderExisting: duplicate += 1
            case .rejectedProtected, .needsConfirm: blocked += 1
            }
        }
        var parts = ["Added \(added) to \(mc.basketName)"]
        if duplicate > 0 { parts.append("\(duplicate) already there") }
        if blocked > 0 { parts.append("\(blocked) protected/skipped") }
        flash(parts.joined(separator: " · ") + ".")
    }

    func confirmAddScanRoot() {
        guard let node = pendingScanRootConfirm else { return }
        basket.add(node, policy: policy, scanRoot: scan.scanRoot, confirmedScanRoot: true)
        pendingScanRootConfirm = nil
        flash("Added to \(mc.basketName).")
    }

    func previewSelected() {
        if let url = scan.selectedNode?.url { FileActions.quickLook(url) }
    }

    // MARK: Trash

    func requestTrash() {
        if !basket.isEmpty { showTrashConfirmation = true }
    }

    func performTrash() async {
        guard !basket.isEmpty else { return }
        isTrashing = true
        let items = basket.maximalItems()
        let summary = await cleanup.moveToTrash(items)
        scan.store.markRemoved(ids: summary.succeededIDs)
        for id in summary.succeededIDs { basket.remove(id: id) }
        // Clear selection if the inspected item was just trashed.
        if let selected = scan.selectedNodeID, summary.succeededIDs.contains(selected) {
            scan.select(nil)
        }
        sessionFreedBytes += summary.reclaimedBytes(useAllocated: settings.useAllocatedSize)
        lastTrashSummary = summary
        isTrashing = false
    }

    /// "Lapang Mode" summary string of space freed this session.
    var lapangSummary: String {
        "You've freed \(ByteSizeFormatter.string(sessionFreedBytes)) this session. Lebih lapang!"
    }

    // MARK: Export

    var canExport: Bool { scan.lastResult != nil }

    func exportReport(asJSON: Bool) {
        guard let result = scan.lastResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [asJSON ? UTType.json : UTType.commaSeparatedText]
        let base = scan.rootNode?.name.isEmpty == false ? scan.rootNode!.name : "runtahio-report"
        panel.nameFieldStringValue = "\(base)-runtahio.\(asJSON ? "json" : "csv")"
        panel.message = "Export Runtahio scan report (local only)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let excluding = scan.store.removedIDs
        let data: Data = asJSON
            ? ScanReportExporter.json(result, useAllocated: settings.useAllocatedSize, excluding: excluding)
            : Data(ScanReportExporter.csv(result, useAllocated: settings.useAllocatedSize, excluding: excluding).utf8)
        do {
            try data.write(to: url)
            flash("Exported report to \(url.lastPathComponent).")
        } catch {
            flash("Export failed: \(error.localizedDescription)")
        }
    }

    /// Keeps basket reclaimable units in sync with the allocated-size setting.
    func syncDerivedSettings() {
        basket.useAllocatedForReclaimable = settings.useAllocatedSize
    }

    private func flash(_ message: String) {
        banner = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            if self?.banner == message { self?.banner = nil }
        }
    }
}
