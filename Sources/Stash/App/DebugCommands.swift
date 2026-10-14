import AppKit

/// Developer commands, shown in the menu bar menu while ⌥ is held.
extension AppDelegate {
    @objc func createSampleReference(_ sender: Any?) {
        guard let library else { return }
        do {
            let saved = try library.create(SampleReferences.next())
            if let path = saved.markdownPath {
                NSWorkspace.shared.activateFileViewerSelecting([library.url(for: path)])
            }
        } catch {
            presentError(error)
        }
    }

    @objc func generateSampleLibrary(_ sender: Any?) {
        guard let library else { return }
        do {
            try SampleLibrary.generate(into: library)
            HUDController.shared.show(.saved)
        } catch {
            presentError(error)
        }
    }

    /// Moves every reference tagged `sample` to the Trash.
    @objc func removeSampleLibrary(_ sender: Any?) {
        guard let library else { return }
        do {
            try SampleLibrary.removeAll(from: library)
        } catch {
            presentError(error)
        }
    }
}

/// Realistic references for trying the app out. Each call returns the next one in turn.
@MainActor
enum SampleReferences {
    private static var counter = 0

    static func next() -> Reference {
        defer { counter += 1 }
        switch counter % 3 {
        case 0:
            let url = URL(string: "https://youtu.be/dQw4w9WgXcQ?t=272")!
            return Reference(
                type: .link,
                url: YouTube.normalize(url),
                title: "How I Write Hooks That Stop the Scroll",
                site: "youtube.com",
                timestamp: YouTube.timestamp(in: url),
                tags: ["hooks", "thumbnails"],
                note: "great hook in the first 3s"
            )
        case 1:
            return Reference(
                type: .text,
                tags: ["copy"],
                note: "from a running shoe ad",
                text: "Stop selling. Start telling."
            )
        default:
            return Reference(
                type: .link,
                url: URL(string: "https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/"),
                title: "F-Shaped Pattern of Reading on the Web",
                site: "nngroup.com",
                tags: ["ux", "reading"]
            )
        }
    }
}
