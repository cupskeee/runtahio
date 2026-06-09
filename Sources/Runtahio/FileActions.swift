import AppKit
import RuntahioCore

/// Thin wrappers around Finder/Workspace integrations. All main-actor; no network.
@MainActor
enum FileActions {
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path(percentEncoded: false), forType: .string)
    }

    static func quickLook(_ url: URL) {
        QuickLookPreviewController.shared.toggle(url)
    }

    /// Opens System Settings → Privacy & Security → Full Disk Access (local IPC URL).
    static func openFullDiskAccessSettings() {
        if let url = PermissionSupport.fullDiskAccessSettingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}
