# Contributing to Stash

Thanks for helping. Stash is small on purpose; these notes keep it that way.

## Principles

These come from the product itself and aren't up for trade-offs:

- **Fully local.** No accounts, servers, analytics, telemetry or crash reporting, ever. The only
  network requests are link metadata (titles, thumbnails, icons), and they stop when the setting
  is off.
- **Plain files are the truth.** The Markdown files in the library are the data; the SQLite index
  is a cache that can be deleted and rebuilt. Never store something only in the index unless it
  can be derived again from the files (like the text read from PDFs and images).
- **Seconds to save.** Shortcut → Enter must stay the whole flow. Anything extra is optional.
- **Keyboard first.** Everything works without the mouse; every action shows its key.
- **Native and quiet.** Follow `design.md`: greys do the work, one amber accent, no spinners.

## Getting started

Requirements and commands are in the [README](README.md#build-from-source). In short:

```sh
scripts/run.sh   # build and launch build/Stash.app
swift test       # all tests (Swift Testing)
```

Hold `⌥` on the menu bar icon for debug commands; *Generate 200 Sample References* gives you a
realistic library to work with (tagged `#sample`, removable from the same menu).

## How the code is organized

```
Sources/Stash/
  App/          entry point, AppDelegate, menu bar, debug commands and hooks
  Panel/        the floating panel (NSPanel), its controller, keyboard map, root view
  Capture/      what Capture saves: browser tab (AppleScript), clipboard, paste/drop, saving, duplicates
  Library/      search, list, detail pane, grid, ⌘K actions
  Components/   shared views: search bar, action bar, keycaps, pills, HUD, glass, shimmer
  Model/        Reference, tags, slugs, ULIDs
  Storage/      Markdown codec, library folder, sync, file watching, search index (GRDB + FTS5),
                text inside files and images (Vision)
  Enrichment/   YouTube URLs, link metadata, background enrichment
  Settings/     preferences and the Settings window
  Shelf/        the shake-to-open shelf: shake detection, storage, window
  Design/       Tokens.swift (every color, font, size and duration) and StashMark.swift (the logo mark)
Tests/StashTests/
Support/Localization/   one Localizable.strings per language (keys are the English text)
```

## Conventions

- **Design tokens only.** Colors, fonts, sizes and durations come from `Design/Tokens.swift`,
  which mirrors `design.md`. Add a token rather than a literal.
- **Small files.** Aim for under ~300 lines; split by responsibility when a file grows.
- **Match the surrounding code**: naming, comment density (explain *why*, not *what*), `// MARK:`
  sections.
- **No new dependencies** without discussing it in an issue first. Today there are two:
  [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and
  [GRDB.swift](https://github.com/groue/GRDB.swift).
- **Every UI string is translatable.** SwiftUI literals (`Text("…")`, `Button("…")`) are already;
  strings built in code use `String(localized: "…")`. Then run `scripts/check-strings.sh sync-en`
  and add the new keys to each language (`scripts/check-strings.sh missing pt-BR`). If you can't
  translate a language, say so in the pull request and we'll help.
- **Accessibility:** VoiceOver labels on new rows and controls; respect Reduce Motion (drop
  scale and slide, keep fades) and Reduce Transparency.
- **Tests** for logic (parsing, storage, search, saving) with Swift Testing. Tests never touch the
  network, the real clipboard or the user's library: use a temporary folder, an in-memory
  `SearchIndex(path: nil)`, a named `NSPasteboard`, and a fake `Enricher.fetch`.
- **macOS surprises** (APIs that behave differently than documented) get a comment explaining
  the behavior and why the code does what it does.

## Pull requests

1. Open an issue first for anything bigger than a fix, so we agree on the approach.
2. Keep changes focused; one topic per pull request.
3. `swift build` with no warnings, `swift test` and `scripts/check-strings.sh` passing.
4. Describe what you tried by hand (the panel, focus and permissions can't all be unit tested).
5. Write commit messages that say what changed and why.

## Reporting bugs

Include your macOS version, browser (for Capture issues), what you did, what you expected and
what happened. Please don't attach your library files unless they contain nothing private.
