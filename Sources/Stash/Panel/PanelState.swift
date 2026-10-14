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
    case moveLeft
    case moveRight
    case deleteBackward
}

/// State shared between `PanelController` (AppKit) and the SwiftUI views.
@MainActor
final class PanelState: ObservableObject {
    @Published var mode: PanelMode = .capture
    /// The note typed in Capture (with inline #tags). Library's search lives in `LibraryController`.
    @Published var note = "" {
        // Called on every change, synchronously: SwiftUI's .onChange can merge a burst of
        // keystrokes and miss the last one, leaving tag suggestions out of date.
        didSet { if note != oldValue { onNoteChange?(note) } }
    }
    var onNoteChange: ((String) -> Void)?
    /// Incremented to give the main text field keyboard focus again.
    @Published private(set) var focusToken = 0

    func prepareForShow(mode: PanelMode) {
        self.mode = mode
        note = ""
        refocus()
    }

    func refocus() {
        focusToken += 1
    }
}
