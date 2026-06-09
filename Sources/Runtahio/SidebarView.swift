import SwiftUI
import RuntahioCore

/// Left sidebar: scan sources (choose / startup disk / volumes), recent scans, filters,
/// and branding at the bottom.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecentScansStore.self) private var recentScans

    var body: some View {
        List {
            Section("Scan") {
                sidebarButton("Choose Folder…", systemImage: "folder.badge.plus") {
                    appState.chooseFolderAndScan()
                }
                if let disk = appState.startupDisk {
                    sidebarButton("Startup Disk", systemImage: "internaldrive") {
                        appState.startScan(disk)
                    }
                }
                ForEach(appState.localVolumes, id: \.path) { volume in
                    sidebarButton(volumeName(volume), systemImage: "externaldrive") {
                        appState.startScan(volume)
                    }
                }
            }

            if !recentScans.entries.isEmpty {
                Section("Recent Scans") {
                    ForEach(recentScans.entries) { entry in
                        sidebarButton(entry.name, systemImage: "clock.arrow.circlepath") {
                            appState.startScan(entry.url)
                        }
                        .contextMenu {
                            Button("Remove from Recents") { recentScans.remove(path: entry.path) }
                        }
                    }
                }
            }

            if appState.scan.rootNode != nil {
                Section("Analyze") {
                    sidebarButton(ContentMode.explorer.title, systemImage: ContentMode.explorer.systemImage, mode: .explorer)
                    sidebarButton(ContentMode.largest.title, systemImage: ContentMode.largest.systemImage, mode: .largest)
                    sidebarButton(ContentMode.oldest.title, systemImage: ContentMode.oldest.systemImage, mode: .oldest)
                    sidebarButton(ContentMode.types.title, systemImage: ContentMode.types.systemImage, mode: .types)
                    sidebarButton(ContentMode.duplicates.title, systemImage: ContentMode.duplicates.systemImage, mode: .duplicates)
                    sidebarButton(ContentMode.inaccessible.title, systemImage: ContentMode.inaccessible.systemImage, mode: .inaccessible)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            branding
        }
    }

    private func sidebarButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A view-mode button that shows a checkmark when its mode is active.
    private func sidebarButton(_ title: String, systemImage: String, mode: ContentMode) -> some View {
        Button {
            if mode == .explorer { appState.scan.showExplorer() } else { appState.scan.setMode(mode) }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if appState.scan.contentMode == mode {
                    Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var branding: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider().padding(.bottom, 4)
            Text(appState.mc.appName).font(.headline)
            Text(appState.mc.brandingSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.bar)
    }

    private func volumeName(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.volumeNameKey])
        return values?.volumeName ?? (url.lastPathComponent.isEmpty ? url.path(percentEncoded: false) : url.lastPathComponent)
    }
}
