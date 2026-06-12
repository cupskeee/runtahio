import SwiftUI
import RuntahioCore

/// Left sidebar: scan sources (choose / startup disk / volumes), recent scans, filters,
/// and branding at the bottom.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecentScansStore.self) private var recentScans

    var body: some View {
        let s = appState.strings
        List {
            Section(s.scan) {
                sidebarButton(s.chooseFolder, systemImage: "folder.badge.plus") {
                    appState.chooseFolderAndScan()
                }
            }

            Section(s.volumes) {
                ForEach(appState.volumes) { volume in
                    volumeRow(volume)
                }
            }

            if !recentScans.entries.isEmpty {
                Section(s.recentScans) {
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
                Section(s.analyze) {
                    ForEach(ContentMode.allCases) { mode in
                        sidebarButton(
                            localizedTitle(mode), systemImage: mode.systemImage, mode: mode)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            branding
        }
    }

    private func sidebarButton(_ title: String, systemImage: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func localizedTitle(_ mode: ContentMode) -> String {
        appState.strings.modeTitle(ContentModeKey(rawValue: mode.rawValue) ?? .explorer)
    }

    /// A view-mode button that shows a checkmark when its mode is active.
    private func sidebarButton(_ title: String, systemImage: String, mode: ContentMode) -> some View
    {
        Button {
            if mode == .explorer {
                appState.scan.showExplorer()
            } else {
                appState.scan.setMode(mode)
            }
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

    private func volumeRow(_ volume: VolumeInfo) -> some View {
        Button {
            appState.startScan(volume.url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: volume.systemImage)
                    .foregroundStyle(volume.isExternal ? .teal : .secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.name).lineLimit(1)
                    Text(volume.capacityDescription)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                if volume.canEject {
                    Button {
                        appState.eject(volume)
                    } label: {
                        Image(systemName: "eject")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Eject \(volume.name)")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Scan") { appState.startScan(volume.url) }
            if volume.canEject {
                Button("Eject") { appState.eject(volume) }
            }
        }
    }
}
