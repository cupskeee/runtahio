import SwiftUI
import RuntahioCore

/// Right-hand inspector showing every detail of the selected node, plus item actions.
struct InspectorView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppState.self) private var appState

    var body: some View {
        if let node = vm.selectedNode {
            detail(for: node)
        } else {
            ContentUnavailableView {
                Label("No selection", systemImage: "sidebar.squares.right")
            } description: {
                Text("Select an item in the \(appState.mc.mapName) or the list to inspect it.")
            }
        }
    }

    @ViewBuilder
    private func detail(for node: DiskNode) -> some View {
        let verdict = appState.policy.isProtected(node.url, scanRoot: vm.scanRoot)
        Form {
            Section("Item") {
                LabeledContent("Name", value: node.name)
                LabeledContent("Kind", value: node.type.displayLabel)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Path").font(.caption).foregroundStyle(.secondary)
                    Text(node.url.path(percentEncoded: false))
                        .font(.callout)
                        .textSelection(.enabled)
                        .lineLimit(4)
                        .truncationMode(.middle)
                }
            }

            Section("Size") {
                LabeledContent("Size", value: ByteSizeFormatter.string(vm.displaySize(node)))
                LabeledContent("Logical", value: ByteSizeFormatter.string(node.byteSize))
                LabeledContent("Allocated", value: ByteSizeFormatter.string(node.allocatedSize))
            }

            Section("Attributes") {
                HStack(spacing: 6) {
                    chip(node.type.displayLabel, color: .accentColor)
                    if node.isHidden { chip("Hidden", color: .gray) }
                    chip(node.isReadable ? "Readable" : "Not readable", color: node.isReadable ? .green : .orange)
                }
                if node.isContainer {
                    LabeledContent("Contains",
                        value: "\(node.fileCount) files · \(node.folderCount) folders")
                }
                LabeledContent("Depth", value: "\(node.depth)")
            }

            Section("Dates") {
                LabeledContent("Modified", value: dateString(node.modifiedDate))
                LabeledContent("Created", value: dateString(node.createdDate))
            }

            if let error = node.scanError {
                Section("Scan Error") {
                    Label(error.humanMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section("Actions") {
                Button { FileActions.revealInFinder(node.url) } label: {
                    Label("Reveal in Finder", systemImage: "magnifyingglass")
                }
                Button { FileActions.open(node.url) } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                Button { FileActions.quickLook(node.url) } label: {
                    Label("Quick Look", systemImage: "eye")
                }
                Button { FileActions.copyPath(node.url) } label: {
                    Label("Copy Path", systemImage: "doc.on.clipboard")
                }
                Divider()
                Button {
                    appState.addToBasket(node)
                } label: {
                    Label("Add to \(appState.mc.basketName)", systemImage: "trash.circle")
                }
                .disabled(verdict.isBlocked)
                if verdict.isBlocked {
                    Text(verdict.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
