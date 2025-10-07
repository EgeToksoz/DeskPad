import Cocoa
import ReSwift

enum AppDelegateAction: Action {
    case didFinishLaunching
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var alwaysOnTopMenuItem: NSMenuItem!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_: Notification) {
        let viewController = ScreenViewController()
        window = NSWindow(contentViewController: viewController)
        window.bind(NSBindingName.title, to: viewController, withKeyPath: "title")
        window.level = .normal
        window.delegate = viewController
        // window.title = "DeskPad"
        window.makeKeyAndOrderFront(nil)
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        // window.titleVisibility = .hidden
        window.backgroundColor = .white
        window.contentMinSize = CGSize(width: 400, height: 300)
        window.contentMaxSize = CGSize(width: 5120, height: 2160)
        window.styleMask.insert(.resizable)
        window.collectionBehavior.insert(.fullScreenNone)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🖥️"
            button.toolTip = "DeskPad Menu"
        }

        let mainMenu = NSMenu()
        let mainMenuItem = NSMenuItem()
        let subMenu = NSMenu(title: "MainMenu")
        let newMenuItem = NSMenuItem(
            title: "Create New Screen",
            action: #selector(spawnNewInstance),
            keyEquivalent: "n"
        )
        subMenu.addItem(newMenuItem)
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApp.terminate),
            keyEquivalent: "q"
        )
        let alwaysOnTopItem = NSMenuItem(
            title: "Always on Top",
            action: #selector(toggleAlwaysOnTop),
            keyEquivalent: "t"
        )
        alwaysOnTopItem.target = self
        alwaysOnTopItem.state = .off
        subMenu.addItem(alwaysOnTopItem)
        alwaysOnTopMenuItem = alwaysOnTopItem

        subMenu.addItem(NSMenuItem(title: "Toggle window", action: #selector(toggleWindow(_:)), keyEquivalent: "p"))

        subMenu.addItem(quitMenuItem)
        statusItem.menu = subMenu

        mainMenuItem.submenu = subMenu
        mainMenu.items = [mainMenuItem]
        NSApplication.shared.mainMenu = mainMenu

        store.dispatch(AppDelegateAction.didFinishLaunching)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_: Notification) {
        guard let vc = window.delegate as? ScreenViewController else { return }
        vc.stopDisplayStream()
    }

    @objc func spawnNewInstance() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
    }

    @objc func toggleWindow(_: Any?) {
        guard let window = window else { return }

        if window.isVisible {
            window.orderOut(nil)
            // NSApp.setActivationPolicy(.accessory)
        } else {
            // NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc func toggleAlwaysOnTop() {
        guard let window = window else { return }
        if window.level == .floating {
            window.level = .normal
            alwaysOnTopMenuItem.state = .off
        } else {
            window.level = .floating
            alwaysOnTopMenuItem.state = .on
        }
    }
}
