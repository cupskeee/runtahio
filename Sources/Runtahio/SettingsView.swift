import SwiftUI
import RuntahioCore

/// The Settings (Cmd-,) scene. Mostly English; the language toggle only affects playful
/// status microcopy. Persists via `AppSettings` (UserDefaults-backed).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(RecentScansStore.self) private var recentScans

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Scanning") {
                Toggle("Show hidden files", isOn: $settings.showHidden)
                Toggle("Treat packages as folders", isOn: $settings.treatPackagesAsFolders)
                Toggle("Use allocated size when available", isOn: $settings.useAllocatedSize)
            }

            Section("Runtah Map") {
                Toggle("Collapse tiny segments into “Other”", isOn: $settings.collapseTinySegments)
                VStack(alignment: .leading) {
                    Text("Minimum segment size: \(percentString(settings.minSegmentFraction))")
                        .font(.callout)
                    Slider(value: $settings.minSegmentFraction, in: 0.0005...0.05)
                }
                .disabled(!settings.collapseTinySegments)
                Toggle("Enable animations", isOn: $settings.animationsEnabled)
            }

            Section("Safety") {
                Toggle("Confirm before moving to Trash", isOn: $settings.confirmBeforeTrash)
                Text("Runtahio always shows a confirmation before moving items to Trash. Files are moved to Trash — never permanently deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recent Scans") {
                Stepper("Keep \(settings.recentScansLimit) recent scans",
                        value: $settings.recentScansLimit, in: 0...50)
                    .onChange(of: settings.recentScansLimit) { _, newValue in
                        recentScans.trim(to: newValue)
                    }
                Button("Clear Recent Scans") { recentScans.clear() }
                    .disabled(recentScans.entries.isEmpty)
            }

            Section("Language") {
                Picker("Tone", selection: $settings.languageFlavor) {
                    ForEach(LanguageFlavor.allCases, id: \.self) { flavor in
                        Text(flavor.displayName).tag(flavor)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("The interface stays mostly English. This only changes playful status microcopy and the branding line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Runtahio", value: "Find the clutter. Free your Mac.")
                Text(PermissionSupport.privacyNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Runtahio is an original macOS storage visualizer and is not affiliated with DaisyDisk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 600)
    }

    private func percentString(_ fraction: Double) -> String {
        String(format: "%.2f%%", fraction * 100)
    }
}
