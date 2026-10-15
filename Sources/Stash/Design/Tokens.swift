import AppKit
import SwiftUI

// Every color, font, size and duration from design.md §3 and §7.
// Views use only these; no literal colors or sizes elsewhere.

// MARK: - Colors

/// A light/dark color pair. Usable as a SwiftUI `ShapeStyle` (`.foregroundStyle(Palette.textPrimary)`)
/// and as a dynamic `NSColor` for AppKit (`Palette.textPrimary.nsColor`).
struct ColorToken: ShapeStyle {
    let dark: NSColor
    let light: NSColor

    var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static let clear = ColorToken(dark: .clear, light: .clear)

    /// As a SwiftUI `Color` that follows the appearance, for APIs that need a `Color` (gradients).
    var color: Color { Color(nsColor: nsColor) }

    /// The same color at full opacity (used for Reduce Transparency).
    var opaque: ColorToken {
        ColorToken(dark: dark.withAlphaComponent(1), light: light.withAlphaComponent(1))
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        Color(nsColor: environment.colorScheme == .dark ? dark : light)
    }
}

enum Palette {
    static let tint = ColorToken(dark: rgba(24, 24, 27, 0.72), light: rgba(250, 250, 250, 0.78))
    static let textPrimary = ColorToken(dark: white(0.92), light: black(0.88))
    static let textSecondary = ColorToken(dark: white(0.55), light: black(0.55))
    static let textTertiary = ColorToken(dark: white(0.35), light: black(0.35))
    static let fillSelected = ColorToken(dark: white(0.08), light: black(0.06))
    static let fillHover = ColorToken(dark: white(0.04), light: black(0.03))
    static let fillKeycap = ColorToken(dark: white(0.08), light: black(0.06))
    static let fillTag = ColorToken(dark: white(0.07), light: black(0.05))
    static let divider = ColorToken(dark: white(0.08), light: black(0.08))
    static let border = ColorToken(dark: white(0.12), light: black(0.10))
    static let accent = ColorToken(dark: hex(0xF5A524), light: hex(0xE09400))
    static let danger = ColorToken(dark: hex(0xFF5F57), light: hex(0xE5484D))
    /// The opaque cards in the shelf's stack.
    static let shelfCard = ColorToken(dark: rgba(46, 46, 50, 1), light: rgba(246, 246, 247, 1))

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    private static func white(_ alpha: CGFloat) -> NSColor { rgba(255, 255, 255, alpha) }
    private static func black(_ alpha: CGFloat) -> NSColor { rgba(0, 0, 0, alpha) }

    private static func hex(_ value: Int) -> NSColor {
        rgba(CGFloat((value >> 16) & 0xFF), CGFloat((value >> 8) & 0xFF), CGFloat(value & 0xFF), 1)
    }
}

// MARK: - Typography

enum Typography {
    static let search = Font.system(size: 20)
    static let searchNS = NSFont.systemFont(ofSize: 20)
    /// The ⌘K menu's own search field.
    static let actionSearchNS = NSFont.systemFont(ofSize: 13)
    static let rowTitle = Font.system(size: 14, weight: .medium)
    static let rowSubtitle = Font.system(size: 13)
    static let section = Font.system(size: 11, weight: .semibold)
    static let detailTitle = Font.system(size: 16, weight: .semibold)
    static let detailBody = Font.system(size: 13)
    static let meta = Font.system(size: 12)
    static let keycap = Font.system(size: 11, weight: .medium, design: .monospaced)
    /// SF Mono draws ↵ ⇥ ⌘ ⌫ tiny, so symbol keycaps use SF Pro at the same size.
    static let keycapSymbol = Font.system(size: 11, weight: .medium)
    static let tag = Font.system(size: 11, weight: .medium)
    static let gridTitle = Font.system(size: 12)
    static let hud = Font.system(size: 13, weight: .medium)
}

// MARK: - Spacing & sizes

enum Metrics {
    static let unit: CGFloat = 4

    // Panel (§2)
    static let panelWidth: CGFloat = 750
    static let libraryHeight: CGFloat = 475
    static let captureHeight: CGFloat = 250
    static let panelCornerRadius: CGFloat = 12
    /// Top edge of the panel, as a fraction of the visible frame's height from the top.
    static let panelTopOffset: CGFloat = 0.22
    static let borderWidth: CGFloat = 1
    /// Panel shadow: `0 20 60 rgba(0,0,0,0.45)` (offset y, blur radius, opacity).
    static let shadowOffsetY: CGFloat = 20
    static let shadowBlur: CGFloat = 60
    static let shadowOpacity: CGFloat = 0.45

    // Search bar
    static let searchBarHeight: CGFloat = 56
    static let searchBarPadding: CGFloat = 16
    static let searchIconSize: CGFloat = 18
    static let searchIconGap: CGFloat = 12

    // Lists
    static let contentInset: CGFloat = 8
    static let rowHeight: CGFloat = 40
    static let rowPadding: CGFloat = 12
    static let rowRadius: CGFloat = 8
    static let rowIconSize: CGFloat = 20
    static let rowIconRadius: CGFloat = 5
    static let rowIconGap: CGFloat = 10
    /// Favicons sit a little inside the 20 pt icon square.
    static let rowIconInset: CGFloat = 2
    static let sectionHeaderHeight: CGFloat = 28
    static let sectionHeaderPadding: CGFloat = 12

    // Action bar
    static let actionBarHeight: CGFloat = 40
    static let actionBarPadding: CGFloat = 12
    static let actionBarDividerHeight: CGFloat = 16
    static let glyphSize: CGFloat = 16
    /// The Stash mark in the menu bar (Apple's guideline: about 16 pt in a 22 pt bar).
    static let menuBarIconHeight: CGFloat = 16
    static let aboutIconSize: CGFloat = 64
    static let glyphRadius: CGFloat = 4

    // Keycaps & tags
    static let keycapHeight: CGFloat = 18
    static let keycapMinWidth: CGFloat = 18
    static let keycapPadding: CGFloat = 5
    static let keycapRadius: CGFloat = 4
    static let keycapGap: CGFloat = 3
    static let tagHeight: CGFloat = 18
    static let tagPadding: CGFloat = 6
    static let tagRadius: CGFloat = 9

    // Grid & detail
    static let gridThumb = CGSize(width: 160, height: 120)
    static let gridRadius: CGFloat = 8
    static let gridGap: CGFloat = 8
    static let detailWidthFraction: CGFloat = 0.45
    static let detailPadding: CGFloat = 16

    // Capture card & empty states
    static let previewCardRadius: CGFloat = 10
    static let previewThumb = CGSize(width: 96, height: 54)
    static let dashPattern: [CGFloat] = [4, 3]
    static let tagSuggestionsWidth: CGFloat = 240
    static let actionMenuWidth: CGFloat = 300
    static let actionRowHeight: CGFloat = 32
    static let actionSearchHeight: CGFloat = 40
    static let detailMediaMaxHeight: CGFloat = 200
    /// Lines of an image's text shown before "…" (⌘K copies all of it).
    static let detailImageTextLines = 12
    static let detailFileIconSize: CGFloat = 64
    static let selectionRingWidth: CGFloat = 2
    static let selectionRingOpacity: CGFloat = 0.2
    static let popoverShadowRadius: CGFloat = 12
    static let popoverShadowOffsetY: CGFloat = 6
    static let popoverShadowOpacity: CGFloat = 0.25

    // Saved HUD
    static let hudHeight: CGFloat = 36
    static let hudPadding: CGFloat = 14
    /// Distance of the HUD from the bottom of the visible screen area.
    static let hudBottomOffset: CGFloat = 96

    // Settings window
    static let settingsWidth: CGFloat = 480
    static let emptyIconSize: CGFloat = 32

    // Shelf
    static let shelfWidth: CGFloat = 176
    static let shelfCollapsedHeight: CGFloat = 214
    static let shelfExpandedWidth: CGFloat = 300
    static let shelfHeaderHeight: CGFloat = 30
    static let shelfThumb: CGFloat = 100
    static let shelfRowHeight: CGFloat = 44
    static let shelfRowThumb: CGFloat = 28
    static let shelfMaxVisibleRows = 6
}

// MARK: - Motion (§7)

enum Motion {
    static let panelOpen: TimeInterval = 0.12
    static let panelOpenScale: CGFloat = 0.98
    static let panelClose: TimeInterval = 0.08
    static let modeSwitch: TimeInterval = 0.15
    static let actionMenu: TimeInterval = 0.10
    static let actionMenuSlide: CGFloat = 4
    static let hudFadeIn: TimeInterval = 0.12
    static let hudHold: TimeInterval = 1.2
    static let hudFadeOut: TimeInterval = 0.2
    static let thumbnailFade: TimeInterval = 0.15
    /// One sweep of the loading shimmer.
    static let shimmer: TimeInterval = 1.2
    /// The first-launch hint stays up longer than the Saved HUD.
    static let welcomeHold: TimeInterval = 4
    static let shelfAppear: TimeInterval = 0.16
    /// After a drag ends, how long an empty shelf waits (for the drop to land) before fading.
    static let shelfEmptyGrace: TimeInterval = 0.6
}
