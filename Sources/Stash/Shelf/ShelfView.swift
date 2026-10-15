import AppKit
import SwiftUI

/// What the shelf's view needs from its controller.
struct ShelfActions {
    var writers: ([ShelfItem]) -> [NSPasteboardWriting]
    var dragEnded: ([ShelfItem], NSDragOperation) -> Void
    var toggleExpanded: () -> Void
    var clear: () -> Void
    var remove: (ShelfItem) -> Void
    var fileURL: (ShelfItem) -> URL?
    var isMissing: (ShelfItem) -> Bool
}

/// The view's own state, owned by the controller.
@MainActor
final class ShelfViewState: ObservableObject {
    @Published var expanded = false
    @Published var dropTargeted = false
}

/// The shelf: a fanned stack that drags everything, or a list whose rows drag one item each;
/// a strip on top to move it and a × to clear it.
struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var state: ShelfViewState
    @ObservedObject var thumbnails: ShelfThumbnails
    let actions: ShelfActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.expanded {
                list
            } else {
                stack
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The same tint over the glass as the main panel (design.md §2).
        .background(reduceTransparency ? Palette.tint.opaque : Palette.tint)
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .strokeBorder(state.dropTargeted ? Palette.accent.color : Palette.border.color,
                              lineWidth: state.dropTargeted ? 2 : Metrics.borderWidth)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: Motion.modeSwitch), value: state.dropTargeted)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            ShelfMoveHandle()
            HStack(spacing: Metrics.unit * 2) {
                if state.expanded {
                    Button(action: actions.toggleExpanded) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityLabel("Back to the stack")
                }
                Text(countText)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.textSecondary)
                    .allowsHitTesting(false)
                Spacer()
                Button(action: actions.clear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.textTertiary)
                .accessibilityLabel("Clear the shelf")
            }
            .padding(.horizontal, Metrics.rowPadding)
        }
        .frame(height: Metrics.shelfHeaderHeight)
    }

    private var countText: String {
        store.items.count == 1 ? String(localized: "1 item") : String(localized: "\(store.items.count) items")
    }

    // MARK: Stack

    private var stack: some View {
        VStack(spacing: Metrics.unit * 2) {
            ZStack {
                ForEach(Array(store.items.prefix(3).enumerated().reversed()), id: \.element.id) { offset, item in
                    thumbnail(item, side: Metrics.shelfThumb)
                        .rotationEffect(.degrees([0, -7, 6][offset]))
                        .offset(x: [0, -6, 7][offset], y: [0, 2, 3][offset])
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                }
                ShelfDragSource(
                    writers: { actions.writers(store.items) },
                    image: { store.items.first.flatMap { thumbnails.images[$0.id] } },
                    onClick: actions.toggleExpanded,
                    onEnded: { actions.dragEnded(store.items, $0) }
                )
            }
            .frame(width: Metrics.shelfThumb + 24, height: Metrics.shelfThumb + 20)
            .accessibilityElement()
            .accessibilityLabel("Shelf, \(countText). Drag to take everything, or click to see each item.")

            Text(store.items.first?.name ?? "")
                .font(Typography.gridTitle)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(store.items.first?.isFileLike == true ? .middle : .tail)
                .padding(.horizontal, Metrics.rowPadding)
        }
        .padding(.top, Metrics.unit * 2)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.items) { item in
                    row(item)
                }
            }
            .padding(.horizontal, Metrics.contentInset)
            .padding(.bottom, Metrics.contentInset)
        }
    }

    private func row(_ item: ShelfItem) -> some View {
        let missing = actions.isMissing(item)
        return ZStack {
            HStack(spacing: Metrics.rowIconGap) {
                thumbnail(item, side: Metrics.shelfRowThumb)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(Typography.rowTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        // File names keep their extension; texts and titles read from the start.
                        .truncationMode(item.isFileLike ? .middle : .tail)
                    Text(missing ? String(localized: "Missing") : subtitle(item))
                        .font(Typography.meta)
                        .foregroundStyle(missing ? Palette.danger : Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .opacity(missing ? 0.5 : 1)
            .padding(.horizontal, Metrics.rowPadding)
            if missing {
                HStack {
                    Spacer()
                    Button("Remove") { actions.remove(item) }
                        .buttonStyle(.plain)
                        .font(Typography.meta)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.trailing, Metrics.rowPadding)
                }
            } else {
                ShelfDragSource(
                    writers: { actions.writers([item]) },
                    image: { thumbnails.images[item.id] },
                    onClick: {},
                    onEnded: { actions.dragEnded([item], $0) }
                )
            }
        }
        .frame(height: Metrics.shelfRowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([item.name, missing ? String(localized: "Missing") : subtitle(item)].joined(separator: ", "))
    }

    private func subtitle(_ item: ShelfItem) -> String {
        switch item.kind {
        case .link(let url, _):
            return String(localized: "Link") + " \u{00B7} " + (url.host(percentEncoded: false) ?? url.absoluteString)
        case .stored(_, .text):
            return String(localized: "Text")
        case .stored(_, .image):
            return String(localized: "Image")
        case .stored, .file:
            if item.isFolder { return String(localized: "Folder") }
            guard let url = actions.fileURL(item),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return String(localized: "File") }
            return String(localized: "File") + " \u{00B7} " + ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
    }

    // MARK: Thumbnails

    /// An opaque card with the item's preview inset (photos fill it), so stacked cards never
    /// show through each other and icons of any size line up.
    private func thumbnail(_ item: ShelfItem, side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius(for: side), style: .continuous)
        return ZStack {
            shape.fill(Palette.shelfCard)
            switch item.kind {
            case .link:
                symbol("link", side: side)
            case .stored(_, .text):
                symbol("text.quote", side: side)
            default:
                if let image = thumbnails.images[item.id] {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(side * 0.08)
                } else {
                    symbol(item.isFolder ? "folder" : "doc", side: side)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: Metrics.borderWidth))
    }

    private func symbol(_ name: String, side: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: side * 0.34, weight: .medium))
            .foregroundStyle(Palette.textSecondary)
    }

    private func radius(for side: CGFloat) -> CGFloat {
        side > 40 ? Metrics.gridRadius : Metrics.rowIconRadius
    }
}
