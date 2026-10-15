cask "stash-references" do
  version "0.2.0"
  sha256 "22348739fa9e10c1e2db2c2c578f73b7d260a714c72b4cb9078e3ec53c0a315f"

  url "https://github.com/S4MU3LDemolidor/stash/releases/download/v#{version}/Stash-#{version}.dmg"
  name "Stash"
  desc "Menu bar app for saving references as Markdown files"
  homepage "https://s4mu3ldemolidor.github.io/stash/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Stash.app"

  # Never the library itself (~/Stash or wherever it was moved): that's the user's data.
  zap trash: [
    "~/Library/Application Support/Stash",
    "~/Library/Caches/dev.stash.app",
    "~/Library/HTTPStorages/dev.stash.app",
    "~/Library/Preferences/dev.stash.app.plist",
  ]

  caveats <<~EOS
    Stash isn't notarized by Apple yet. The first time you open it, macOS stops it:
    open System Settings › Privacy & Security, scroll down and click Open Anyway.

    Stash lives in the menu bar. Press ⌥⇧S to capture, ⌥⇧L to find.
  EOS
end
