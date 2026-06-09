import SwiftUI
import RuntahioCore

/// The central area: breadcrumb + totals + scan status, then the Runtah Map over the
/// file table. Switches between empty / scanning / error / results states.
struct MainContentView: View {
    @Environment(ScanViewModel.self) private var vm
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if vm.isScanning {
                scanningView
            } else if case .failed(let error) = vm.phase {
                ErrorView(error: error)
            } else if vm.rootNode != nil {
                resultsView
            } else {
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Scanning

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(scanStatusText)
                .font(.headline)
            Text(appState.mc.analyzingStatus(itemCount: vm.progress.scannedItemCount))
                .foregroundStyle(.secondary)
            Text("\(ByteSizeFormatter.string(vm.progress.discoveredSize)) discovered · \(vm.progress.inaccessibleCount) inaccessible")
                .font(.callout)
                .foregroundStyle(.tertiary)
            if !vm.progress.currentPath.isEmpty {
                Text(vm.progress.currentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 460)
            }
            Button("Cancel Scan", role: .cancel) { appState.cancelScan() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(40)
    }

    private var scanStatusText: String {
        appState.mc.scanningStatus(displayName: vm.progress.currentDisplayName)
    }

    // MARK: Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            BreadcrumbBar()
            Divider()
            TotalsHeader()
            Divider()
            VSplitView {
                RuntahMapView()
                    .frame(minHeight: 220, idealHeight: 320)
                tableSection
                    .frame(minHeight: 160)
            }
        }
    }

    private var tableSection: some View {
        @Bindable var vm = vm
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter this folder…", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Toggle("Folders first", isOn: $vm.foldersFirst)
                    .toggleStyle(.checkbox)
                Spacer()
                if vm.listFilter != .none {
                    Button {
                        vm.listFilter = .none
                    } label: {
                        Label("Clear filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            FileTableView()
        }
    }
}

/// Clickable breadcrumb from the scan root to the current focus node.
struct BreadcrumbBar: View {
    @Environment(ScanViewModel.self) private var vm

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    vm.goToParent()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(!vm.canGoToParent)
                .help("Go to parent folder")
                .keyboardShortcut(.upArrow, modifiers: .command)

                ForEach(Array(vm.breadcrumb.enumerated()), id: \.element.id) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        vm.focus(on: node.id)
                    } label: {
                        Text(node.name.isEmpty ? "/" : node.name)
                            .fontWeight(index == vm.breadcrumb.count - 1 ? .semibold : .regular)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// Summary statistics for the current scan.
struct TotalsHeader: View {
    @Environment(ScanViewModel.self) private var vm

    var body: some View {
        HStack(spacing: 18) {
            stat("Total", value: ByteSizeFormatter.string(vm.store.effectiveTotalSize(useAllocated: vm.useAllocated)), emphasis: true)
            if let result = vm.lastResult {
                stat("Files", value: result.fileCount.formatted())
                stat("Folders", value: result.folderCount.formatted())
                if result.inaccessibleCount > 0 {
                    stat("Inaccessible", value: result.inaccessibleCount.formatted(), color: .orange)
                }
            }
            Spacer()
            if case .cancelled = vm.phase {
                Label("Scan cancelled", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let result = vm.lastResult {
                Label("Scanned in \(result.duration, format: .number.precision(.fractionLength(1)))s",
                      systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func stat(_ label: String, value: String, emphasis: Bool = false, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(emphasis ? .headline : .callout)
                .foregroundStyle(color ?? .primary)
                .monospacedDigit()
        }
    }
}
