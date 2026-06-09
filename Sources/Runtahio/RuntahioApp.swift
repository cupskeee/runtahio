import SwiftUI
import AppKit
import RuntahioCore

/// Runtahio — an original macOS disk-usage visualizer and safe (Trash-only) cleanup tool.
@main
struct RuntahioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appState.scan)
                .environment(appState.settings)
                .environment(appState.basket)
                .environment(appState.recentScans)
                .frame(minWidth: 940, minHeight: 620)
        }
        .commands {
            RuntahioCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environment(appState.settings)
                .environment(appState.recentScans)
        }
    }
}

/// Promotes the SPM executable from a background process to a real foreground app with a
/// menu bar and a frontmost window — without this it launches as `BackgroundOnly`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
