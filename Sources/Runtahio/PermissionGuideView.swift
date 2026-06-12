import SwiftUI
import RuntahioCore

/// Step-by-step guidance to grant Full Disk Access, with an honest note that ad-hoc
/// rebuilds reset the grant.
struct PermissionGuideView: View {
    var error: ScanError?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Full Disk Access may be needed", systemImage: "lock.shield")
                .font(.headline)

            if let error {
                Text(error.humanMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(PermissionSupport.fullDiskAccessSteps.enumerated()), id: \.offset) {
                    index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                        Text(step)
                    }
                }
            }
            .font(.callout)

            Text(PermissionSupport.fullDiskAccessRebuildCaveat)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                FileActions.openFullDiskAccessSettings()
            } label: {
                Label("Open Privacy Settings", systemImage: "gearshape")
            }

            Divider()
            Text(PermissionSupport.privacyNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: 480, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
