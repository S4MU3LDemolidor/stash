import AppKit

/// The app's main menu. It's never visible (Stash has no Dock icon or menu bar of its own),
/// but AppKit routes key equivalents through it, so it's what makes ⌘C / ⌘V / ⌘A / ⌘Z
/// work in text fields, plus ⌘, and ⌘Q while a Stash window is key.
@MainActor
enum MainMenu {
    static func make(target: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu(target: target)))
        mainMenu.addItem(submenuItem(editMenu()))
        return mainMenu
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func appMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu(title: "Stash")

        let settings = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings(_:)), keyEquivalent: ",")
        settings.target = target
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Hide Stash", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))

        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        return menu
    }
}
