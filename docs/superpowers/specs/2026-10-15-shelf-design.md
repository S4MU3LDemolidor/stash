# Shelf — design

Date: 2026-10-15 · Status: approved in conversation, section by section

## What it is

A temporary holding place for anything you're dragging. While dragging a file, an image, text
or a link from any app, shake the mouse and a small shelf appears under the cursor; drop the
thing on it, go wherever you need, and drag it back out later. It is a pause button in the
middle of a drag.

Decisions (from the user):

- **Fully separate from the library.** Nothing on the shelf is saved to Stash, and the shelf
  has no "save to library" action.
- **Accepts anything draggable:** Finder files and folders, images, text and links from any
  app, and file promises (Photos, Mail).
- **Appears next to the cursor** where you shook.
- **Items leave when dragged out**; holding ⌥ while dropping keeps them. The shelf closes when
  empty and survives restarts while it holds anything.
- **Approach A:** files are held by reference (a bookmark to the original, no copy); things
  with no file of their own are written to a private shelf folder.

## Architecture

New folder `Sources/Stash/Shelf/`. It shares only the glass and shadow styling, the design
tokens and the existing pasteboard parsing with the rest of the app.

| Unit | Responsibility | Depends on |
|---|---|---|
| `ShakeDetector` | Pure logic: from (point, time) samples, decides when a shake happened. | — |
| `DragMonitor` | Global `leftMouseDragged` / `leftMouseUp` monitors plus the system drag pasteboard (`NSPasteboard(name: .drag)`) change count, so it only reacts while something is being dragged. Feeds `ShakeDetector`; reports "shake at point". | AppKit |
| `ShelfItem`, `ShelfStore` | Model and persistence: add, remove, clear, resolve bookmarks, Missing, cleanup. | Foundation |
| `ShelfPasteboard` | Drop → items (several files and folders, file promises, or one image, link or text); items → drag writers. | `ClipboardReader` |
| `ShelfPanel`, `ShelfController` | Non-activating floating window (like `StashPanel`): show at a point, keep on screen, hide when empty, remember position, animations. | `ShelfStore` |
| `ShelfView` | SwiftUI contents: the stack, the expanded list, drop highlight, ×, move strip. | tokens |

`AppDelegate` wires them. Settings gains one toggle, **Shake to open the shelf** (on by
default, `Preferences.Key.shelfShake`). As a safety net, **dropping onto the menu bar icon**
also opens the shelf with the dropped items, so the feature works even if shake detection
misbehaves on some setup.

## Interaction

- **Open:** during any drag, three or more quick horizontal direction reversals (each leg at
  least ~30 pt, all within ~0.6 s, horizontal movement dominant) open the shelf centered under
  the cursor. One trigger per drag; reset on mouse-up. Shaking while the shelf is open moves it
  to the cursor. If the drag ends elsewhere and the shelf is still empty, it fades out.
- **Drop:** an amber highlight while hovering; drops accumulate, newest on top. Unreadable
  drops are refused (no highlight).
- **Look:** a ~160×180 pt dark glass card with a slightly fanned stack of thumbnails (Quick
  Look thumbnails for files and images, tiles for links and text), a count ("3 items"), the top
  item's name, × on hover, and a slim top strip to move the shelf.
- **Drag out:** dragging the stack takes everything; clicking the stack expands a list (name,
  kind, size) whose rows drag one item each. A successful drop removes the item unless ⌥ was
  held; a cancelled drag keeps it. The shelf closes when empty.
- **Clear:** × empties the shelf. Originals are never touched; if any item exists only on the
  shelf, it asks first.
- **System:** all Spaces and full-screen apps; a non-empty shelf reappears at its last position
  after a restart (clamped to a visible screen); unresolvable originals show **Missing** and can
  be removed; the setting off stops shake detection only; VoiceOver labels; Reduce Motion fades
  instead of popping.

Not in v1: multiple shelves, Quick Look on Space, saving to the library.

## Data and persistence

`~/Library/Application Support/Stash/Shelf/`: `shelf.json` (atomic writes) and `Items/` for
private copies. Never inside the library folder.

| Item | Stored as | Dragged out as |
|---|---|---|
| File or folder | bookmark data + name + last known path + is-directory | the original file URL |
| Image | PNG/JPG in `Items/` | file URL + image data |
| Text | `.txt` in `Items/` (+ a short preview) | string + file URL |
| Link | URL + optional title | URL + string (Finder makes a `.webloc`) |
| File promise | received into `Items/` at drop time | file URL |

- The dragging-source operation mask is copy, move, link and generic, not delete: the target decides (Finder: same
  volume moves, other volume copies, ⌥ copies). Stash never moves or deletes originals itself;
  the Trash refuses shelf items.
- After a successful drop without ⌥, the item leaves the shelf and its private copy (if any)
  is deleted — or is already gone because Finder moved it.
- Bookmarks follow renames and moves; stale ones are refreshed; unresolvable → Missing.
- At launch, files in `Items/` not referenced by `shelf.json` are deleted.
- Position is stored in preferences.
- No network. Concealed/password-manager pasteboard types are refused
  (`ClipboardReader.privateTypes`). No new permissions: global monitoring of mouse events does
  not need Accessibility (to be confirmed in the user's final test).

## Errors

- Shake events never arrive during another app's drag → the menu bar drop still works; tell
  the user and discuss a screen-edge drop zone before changing direction.
- Writing a private copy fails → nothing is added; HUD: "Couldn't add to the shelf".
- `shelf.json` unreadable → renamed `shelf.json.broken`, empty shelf, and that launch skips the
  `Items/` cleanup so nothing is deleted by mistake.
- A drop target refuses an item → it stays.

## Testing

Swift Testing, no screen, network or real clipboard:

- `ShakeDetector`: synthetic paths — a real shake fires once; slow wiggles, jitter and vertical
  movement don't; reset on mouse-up.
- `ShelfStore`: temporary folder — add/remove/clear, reload, Missing, orphan cleanup, broken
  manifest, private copies deleted on removal.
- `ShelfPasteboard`: named pasteboards — several files and folders, images, links, text in;
  private types refused; items out with the expected types.

Manual (the user): Finder file + shake; browser image; text; drag out on the same disk,
another disk and with ⌥; drop on the menu bar icon; restart with items; deleted original.
Debug hooks gain a way to open the shelf with sample items for screenshots.

## Build order

Run straight through, one commit per step, nothing pushed until the user has tested the final
build:

1. `ShakeDetector` + `DragMonitor` (+ tests).
2. `ShelfStore` + `ShelfPasteboard` (+ tests).
3. Shelf window: appear at the cursor, accept drops, stack, list, ×, menu bar drop.
4. Dragging out: ⌥ rule, Trash refused, Missing.
5. Settings toggle, persistence across restarts, VoiceOver, Reduce Motion, debug hooks,
   README/CONTRIBUTING notes.
