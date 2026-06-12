import SwiftUI
import RuntahioCore

/// First-run onboarding: what Runtahio does, the privacy promise, and how cleanup is safe.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "circle.hexagongrid.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text(appState.strings.welcome).font(.title.bold())
                Text(appState.mc.brandingSubtitle).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                row(
                    "magnifyingglass", "See what's using space",
                    "Scan a folder or disk and explore it with the Runtah Map and analysis views.")
                row("hand.raised", "Private by design", PermissionSupport.privacyNote)
                row(
                    "trash", "Safe cleanup",
                    "Items go to the Trash only after you confirm — they're never permanently deleted, and system folders are protected."
                )
                row(
                    "lock.shield", "Full Disk Access",
                    "Some system locations need Full Disk Access, granted to the Runtahio app in System Settings."
                )
            }
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button {
                    onDismiss()
                    appState.chooseFolderAndScan()
                } label: {
                    Label(appState.strings.chooseFolder, systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(appState.strings.getStarted) { onDismiss() }
                    .controlSize(.large)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 540)
    }

    private func row(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
