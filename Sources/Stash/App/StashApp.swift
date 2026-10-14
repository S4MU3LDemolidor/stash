import AppKit

/// Entry point. Stash is a menu bar app driven by AppKit; SwiftUI is only used for views.
@main
@MainActor
enum StashApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // `NSApplication.delegate` is weak, so keep ours alive for the app's lifetime.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
