// Mac Subsystem for Android - entry point of the app window host (AndroidAppHost).
//
// This executable is copied into every launcher bundle the Subsystem creates in
// ~/Applications/Android Apps. The bundle's Info.plist says which Android app it
// opens (MSAPackageName) and carries the Subsystem's MSA* settings.
//
// Licensed under the GNU General Public License v3 or later.

import AppKit

@MainActor
final class AppHostDelegate: NSObject, NSApplicationDelegate {
    private var controller: AndroidWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let package = info["MSAPackageName"] as? String else {
            let alert = NSAlert()
            alert.messageText = "This launcher is incomplete."
            alert.informativeText = "Open \(AppConfig.displayName) to recreate your Android app launchers."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let label = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? package
        let activity = (info["MSAActivity"] as? String) ?? package
        let app = AndroidApp(package: package, activity: activity, label: label)
        let icon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
        if let icon { NSApp.applicationIconImage = icon }

        buildMenus(appName: label)
        let controller = AndroidWindowController(app: app, icon: icon)
        self.controller = controller
        controller.showWindow(nil)
        NSApp.activate()
        controller.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showWindow(nil)
        return true
    }

    private func buildMenus(appName: String) {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Open \(AppConfig.displayName) Settings…", action: #selector(openSubsystem(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(AndroidWindowController.undo(_:)), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(AndroidWindowController.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(AndroidWindowController.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(AndroidWindowController.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(AndroidWindowController.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Back", action: #selector(AndroidWindowController.goBack(_:)), keyEquivalent: "[")
        viewMenu.addItem(withTitle: "Restart \(appName)", action: #selector(AndroidWindowController.restartApp(_:)), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        let fullScreen = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }

    @objc private func openSubsystem(_ sender: Any?) {
        guard let url = URL(string: "\(AppConfig.urlScheme)://settings") else { return }
        NSWorkspace.shared.open(url)
    }
}

@main
enum AppHostApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppHostDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
