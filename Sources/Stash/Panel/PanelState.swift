import Foundation

enum PanelMode {
    case capture
    case library

    var height: CGFloat {
        switch self {
        case .capture: Metrics.captureHeight
        case .library: Metrics.libraryHeight
        }
    }
}

/// Keys the search field forwards to the panel instead of handling itself.
enum PanelKeyCommand {
    case cancel
    case submit
    case tab
    case moveUp
    case moveDown
}

/// State shared between `PanelController` (AppKit) and the SwiftUI views.
@MainActor
final class PanelState: ObservableObject {
    @Published var mode: PanelMode = .capture
    @Published var query = ""
    /// Incremented each time the panel opens, so the search field takes focus again.
    @Published private(set) var focusToken = 0

    func prepareForShow(mode: PanelMode) {
        self.mode = mode
        query = ""
        focusToken += 1
    }
}
