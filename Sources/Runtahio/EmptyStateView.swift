import SwiftUI
import RuntahioCore

/// Shown before any scan: invites the user to choose a folder, with the privacy promise.
struct EmptyStateView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let mc = appState.mc
        VStack(spacing: 18) {
            Image(systemName: "circle.hexagongrid.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text(mc.emptyTitle).font(.title.weight(.semibold))
                Text(mc.emptySubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                appState.chooseFolderAndScan()
            } label: {
                Label(mc.emptyButton, systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            Text(PermissionSupport.privacyNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
