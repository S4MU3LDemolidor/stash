# Homebrew tap for Stash

[Stash](https://github.com/S4MU3LDemolidor/stash) saves anything in two keystrokes and finds it
again in one: a free, open source, fully local macOS menu bar app for references.

```sh
brew install --cask s4mu3ldemolidor/tap/stash-references
```

The cask is called `stash-references` because Homebrew's own `stash` cask is a different app.
Update with `brew upgrade`. Uninstalling keeps your library; `brew uninstall --zap` also removes
Stash's index and settings (still never the library folder).

Stash isn't notarized by Apple yet, so the first launch needs **System Settings › Privacy &
Security › Open Anyway**.

The cask follows Stash's latest release automatically (a daily workflow in this repo). Its source
lives in the main repo under [`packaging/homebrew-tap`](https://github.com/S4MU3LDemolidor/stash/tree/main/packaging/homebrew-tap).

---

**Português:** `brew install --cask s4mu3ldemolidor/tap/stash-references` · **Español:** mismo
comando · **Français :** même commande.
