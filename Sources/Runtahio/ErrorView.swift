import SwiftUI
import RuntahioCore

/// Shown when a scan fails (e.g. permission denied), with recovery actions.
struct ErrorView: View {
    let error: ScanError
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)

                Text(error.humanMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if PermissionSupport.suggestsFullDiskAccess(error) {
                    PermissionGuideView(error: error)
                }

                HStack {
                    Button("Choose Folder…") { appState.chooseFolderAndScan() }
                        .buttonStyle(.borderedProminent)
                    if appState.scan.scanRoot != nil {
                        Button("Try Again") { appState.rescan() }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}
