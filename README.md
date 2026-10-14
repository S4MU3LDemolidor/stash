# Stash

**Save anything in two keystrokes. Find it again in one.**

Stash is a free, open source, fully local macOS menu bar app for saving references:
links (with the YouTube timestamp you were at), text, images and files. Press a shortcut,
a Raycast-style panel shows what you're looking at, press Enter, done.

Every reference is a plain Markdown file in `~/Stash`. No account, no server, no analytics.

> Status: early development. Not ready for daily use yet.

## Build and run

Requires macOS 14+ and Swift 5.9+ (Xcode or the Command Line Tools).

```sh
scripts/run.sh
```

This builds `build/Stash.app`, quits any running copy and opens the new one.
Stash lives in the menu bar; it has no Dock icon.

To only build the app bundle: `scripts/build-app.sh`.

To open the panel right at launch (handy while working on its UI):

```sh
open build/Stash.app --args -StashShowPanel capture   # or: library
```

Debug builds (`swift build`, then run `.build/debug/Stash`) can be driven from scripts with
distributed notifications, without activating Stash or needing accessibility permissions:
`dev.stash.debug.toggle` (object `"capture"` or `"library"`) works like the shortcut, and
`dev.stash.debug.keys` (object like `"text:hooks down cmd+k esc"`) presses keys in the panel.
See `Sources/Stash/App/DebugHooks.swift`.

## License

MIT. See [LICENSE](LICENSE).
