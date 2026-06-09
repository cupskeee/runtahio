import SwiftUI
import RuntahioCore

/// The 3-pane shell: sidebar | main content (+ bottom Runtah Basket) | inspector.
/// Hosts the app's confirmation dialogs, the trash-result alert, and the transient banner.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 300)
        } detail: {
            MainContentView()
                .safeAreaInset(edge: .bottom, spacing: 0) { BasketBar() }
                .inspector(isPresented: $appState.showInspector) {
                    InspectorView()
                        .inspectorColumnWidth(min: 260, ideal: 312, max: 440)
                }
        }
        .navigationTitle("Runtahio")
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .onExitCommand { appState.escape() }
        .onChange(of: appState.settings.useAllocatedSize) { _, _ in appState.syncDerivedSettings() }
        .overlay(alignment: .bottom) { bannerView }
        .confirmationDialog("Move to Trash", isPresented: $appState.showTrashConfirmation, titleVisibility: .visible) {
            Button("Move \(appState.basket.count) to Trash", role: .destructive) {
                Task { await appState.performTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(trashMessage)
        }
        .confirmationDialog("Add the scanned folder itself?", isPresented: scanRootConfirmBinding, titleVisibility: .visible) {
            Button("Add Scanned Folder", role: .destructive) { appState.confirmAddScanRoot() }
            Button("Cancel", role: .cancel) { appState.pendingScanRootConfirm = nil }
        } message: {
            Text(ConfirmReason.scanRootItself.explanation)
        }
        .alert("Cleanup Complete", isPresented: trashSummaryBinding, presenting: appState.lastTrashSummary) { _ in
            Button("OK") { appState.lastTrashSummary = nil }
        } message: { summary in
            Text(summaryMessage(summary))
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView {
                appState.settings.hasSeenOnboarding = true
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { appState.chooseFolderAndScan() } label: {
                Label("Choose Folder", systemImage: "folder.badge.plus")
            }
            .help("Choose a folder or volume to scan (⌘O)")

            if appState.scan.isScanning {
                Button(role: .cancel) { appState.cancelScan() } label: {
                    Label("Cancel", systemImage: "stop.circle")
                }
                .help("Cancel the current scan")
            } else {
                Button { appState.rescan() } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .help("Rescan the current folder (⌘R)")
                .disabled(appState.scan.scanRoot == nil)
            }

            Menu {
                Button("Export as JSON…") { appState.exportReport(asJSON: true) }
                Button("Export as CSV…") { appState.exportReport(asJSON: false) }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export a scan report (local only)")
            .disabled(!appState.canExport)

            Button { appState.showInspector.toggle() } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle the inspector")
        }
    }

    // MARK: Derived content

    private var subtitle: String {
        if let focus = appState.scan.focusNode {
            return focus.url.path(percentEncoded: false)
        }
        if let root = appState.scan.scanRoot {
            return root.path(percentEncoded: false)
        }
        return appState.mc.tagline
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = appState.banner {
            Text(banner)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.quaternary))
                .shadow(radius: 5, y: 2)
                .padding(.bottom, 78)
                .transition(.opacity)
        }
    }

    // MARK: Dialog bindings & messages

    private var scanRootConfirmBinding: Binding<Bool> {
        Binding(
            get: { appState.pendingScanRootConfirm != nil },
            set: { if !$0 { appState.pendingScanRootConfirm = nil } }
        )
    }

    private var trashSummaryBinding: Binding<Bool> {
        Binding(
            get: { appState.lastTrashSummary != nil },
            set: { if !$0 { appState.lastTrashSummary = nil } }
        )
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !appState.settings.hasSeenOnboarding },
            set: { if !$0 { appState.settings.hasSeenOnboarding = true } }
        )
    }

    private var trashMessage: String {
        let basket = appState.basket
        let total = ByteSizeFormatter.string(basket.totalReclaimable)
        let largest = basket.largestItems(limit: 4)
            .map { "• \($0.url.path(percentEncoded: false))" }
            .joined(separator: "\n")
        var message = appState.mc.trashConfirmationMessage(count: basket.count, totalSize: total)
        if !largest.isEmpty { message += "\n\nLargest items:\n\(largest)" }
        return message
    }

    private func summaryMessage(_ summary: TrashSummary) -> String {
        var lines = ["Moved \(summary.movedCount) to Trash (recoverable)."]
        if summary.failedCount > 0 {
            lines.append("\(summary.failedCount) could not be moved:")
            for outcome in summary.failed.prefix(4) {
                lines.append("• \(outcome.item.name): \(outcome.errorMessage ?? "unknown error")")
            }
            lines.append("Tip: Rescan to refresh totals.")
        }
        if summary.movedCount > 0 {
            lines.append("")
            lines.append(appState.lapangSummary)
        }
        return lines.joined(separator: "\n")
    }
}
