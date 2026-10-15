import KeyboardShortcuts
import SwiftUI

/// A plain native settings form (design.md §5, "Settings").
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// Shows or hides the menu bar icon right away.
    let onShowMenuBarIconChange: (Bool) -> Void
    /// Starts or stops shake detection right away.
    let onShelfShakeChange: (Bool) -> Void

    @AppStorage(Preferences.Key.fetchMetadata) private var fetchMetadata = true
    @AppStorage(Preferences.Key.clipboardWindow) private var clipboardWindow: Double = 60
    @AppStorage(Preferences.Key.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Preferences.Key.shelfShake) private var shelfShake = true

    var body: some View {
        Form {
            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Capture", name: .capture)
                KeyboardShortcuts.Recorder("Library", name: .library)
            }

            Section {
                LabeledContent("Folder") {
                    HStack {
                        Text(model.libraryPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .help(model.libraryPath)
                        Button("Choose…", action: model.chooseLibraryFolder)
                        Button("Reveal", action: model.revealLibrary)
                    }
                }
                LabeledContent("Index") {
                    HStack {
                        Text(model.referenceCount == 1 ? "1 reference" : "\(model.referenceCount) references")
                            .foregroundStyle(.secondary)
                        Button("Rebuild Index", action: model.rebuildIndex)
                    }
                }
            } header: {
                Text("Library")
            } footer: {
                Text(model.libraryStatus ?? String(localized: "Every reference is a Markdown file in this folder. Put it in iCloud Drive to use your library on several Macs."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle("Fetch titles & thumbnails", isOn: $fetchMetadata)
                Picker("Use what I copied within", selection: $clipboardWindow) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("Off").tag(0.0)
                }
            } header: {
                Text("Capture")
            } footer: {
                Text("Titles, thumbnails and icons come from the site you saved. With this off, Stash makes no network requests at all.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle("Shake to open the shelf", isOn: $shelfShake)
                    .onChange(of: shelfShake) { _, on in onShelfShakeChange(on) }
            } header: {
                Text("Shelf")
            } footer: {
                Text("While dragging anything, shake the mouse to hold it on a shelf until you drag it out. You can also drop things on Stash's menu bar icon.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                if model.loginItemNeedsApproval {
                    LabeledContent("Allow Stash in Login Items") {
                        Button("Open System Settings", action: model.openLoginItemsSettings)
                    }
                }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, show in onShowMenuBarIconChange(show) }
            } header: {
                Text("General")
            } footer: {
                if !showMenuBarIcon {
                    Text("Open Stash again (from Finder or Spotlight) to get back to Settings.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("About") {
                HStack(spacing: Metrics.unit * 3) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: Metrics.aboutIconSize, height: Metrics.aboutIconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                        Text("Stash").font(.headline)
                        Text("Save anything in two keystrokes. Find it again in one.")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Version", value: AppInfo.version)
                LabeledContent("Source code") {
                    Link("GitHub", destination: AppInfo.repositoryURL)
                }
                Text("Your data never leaves your Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        // The accent shows on focus rings, toggles and pickers here (design.md §3).
        .tint(Palette.accent.color)
        .frame(width: Metrics.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: model.refresh)
    }
}
