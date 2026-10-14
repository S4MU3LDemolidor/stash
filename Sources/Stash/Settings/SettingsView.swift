import SwiftUI

/// Placeholder. The full settings form (shortcuts, library, capture, general) lands in M6.
struct SettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: version)
                Text("Your data never leaves your Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
