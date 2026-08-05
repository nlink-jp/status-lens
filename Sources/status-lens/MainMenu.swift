import AppKit

/// Minimal main menu. An LSUIElement app never shows a menu bar, but without
/// a main menu the standard key equivalents (⌘C/⌘V/⌘A in the settings
/// window's text fields, ⌘W to close it) go nowhere.
@MainActor
func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem(title: "status-lens", action: nil, keyEquivalent: "")
    let appMenu = NSMenu(title: "status-lens")
    appMenu.addItem(NSMenuItem(
        title: "Quit status-lens",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    appItem.submenu = appMenu
    main.addItem(appItem)

    let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(.separator())
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = edit
    main.addItem(editItem)

    let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
    let window = NSMenu(title: "Window")
    window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    windowItem.submenu = window
    main.addItem(windowItem)

    return main
}
