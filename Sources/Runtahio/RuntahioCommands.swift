import SwiftUI
import RuntahioCore

/// Menu bar commands and keyboard shortcuts, wired to `AppState`.
struct RuntahioCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Choose Folder…") { appState.chooseFolderAndScan() }
                .keyboardShortcut("o", modifiers: .command)
            Divider()
            Button("Export Report as JSON…") { appState.exportReport(asJSON: true) }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!appState.canExport)
            Button("Export Report as CSV…") { appState.exportReport(asJSON: false) }
                .disabled(!appState.canExport)
        }

        CommandMenu("Views") {
            modeButton(.explorer, key: "1")
            modeButton(.largest, key: "2")
            modeButton(.oldest, key: "3")
            modeButton(.types, key: "4")
            modeButton(.duplicates, key: "5")
            modeButton(.inaccessible, key: "6")
            Divider()
            Button(appState.settings.visualization == .treemap ? "Show Runtah Map" : "Show Treemap")
            {
                appState.settings.visualization =
                    appState.settings.visualization == .treemap ? .radial : .treemap
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(appState.scan.rootNode == nil)
        }

        CommandMenu("Scan") {
            Button("Rescan") { appState.rescan() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.scan.scanRoot == nil)

            Button("Cancel Scan") { appState.cancelScan() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!appState.scan.isScanning)

            Divider()

            Button("Go to Parent Folder") { appState.scan.goToParent() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!appState.scan.canGoToParent)

            Button("Preview Selected") { appState.previewSelected() }
                .disabled(appState.scan.selectedNode == nil)
        }

        CommandMenu("Runtah Basket") {
            Button("Add Selected to Runtah Basket") { appState.addSelectedToBasket() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(appState.scan.selectedNode == nil)

            Button("Move Runtah Basket to Trash…") { appState.requestTrash() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(appState.basket.isEmpty)

            Divider()

            Button("Toggle Inspector") { appState.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    @ViewBuilder
    private func modeButton(_ mode: ContentMode, key: KeyEquivalent) -> some View {
        Button(mode == .explorer ? "Explorer (Map)" : mode.title) {
            if mode == .explorer {
                appState.scan.showExplorer()
            } else {
                appState.scan.setMode(mode)
            }
        }
        .keyboardShortcut(key, modifiers: .command)
        .disabled(appState.scan.rootNode == nil)
    }
}
