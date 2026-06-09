import AppKit
import Quartz
import RuntahioCore

/// Drives a Quick Look preview for a single URL.
///
/// `QLPreviewPanelDataSource` is a `nonisolated` protocol but `NSObject`/AppKit work is
/// main-actor; under Swift 6 the conformance must be `@MainActor ... @preconcurrency`.
/// If the shared panel is unavailable for any reason, we fall back to opening the file —
/// so Space always does *something* useful.
@MainActor
final class QuickLookPreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewController()

    private var items: [URL] = []

    /// Previews `url` in the shared Quick Look panel, or opens it if Quick Look is unavailable.
    func preview(_ url: URL) {
        items = [url]
        guard let panel = QLPreviewPanel.shared() else {
            NSWorkspace.shared.open(url)
            return
        }
        panel.dataSource = self
        panel.delegate = self
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Toggles the panel — shows it for `url`, or hides it if already showing.
    func toggle(_ url: URL) {
        if QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            preview(url)
        }
    }

    // MARK: QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int { items.count }

    func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> any QLPreviewItem {
        items[index] as NSURL
    }
}
