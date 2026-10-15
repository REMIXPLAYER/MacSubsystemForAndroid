// Mac Android Subsystem - keeps the Mac's list of Android apps in step with Android.
//
// Asks the bridge app for every launchable app (apps.json) and its icon, stores
// them in Application Support, and makes, refreshes or removes the launchers in
// ~/Applications/Android Apps. Runs after boot, after installs, and every few
// seconds while Android runs (so apps installed from F-Droid inside Android appear
// on the Mac too).
//
// Licensed under the GNU General Public License v3 or later.

import AppKit
import Foundation

enum AppCatalog {
    struct Result {
        let apps: [AndroidApp]
        let added: [AndroidApp]
        let removed: [AndroidApp]
    }

    /// Every app Android's own app drawer shows (everything with a launcher icon,
    /// built-in apps such as Browser, Camera and Settings included) gets a Mac app.
    static func sync(_ adb: ADBConnection) throws -> Result {
        let data = try AndroidBridge.read("apps.json", from: adb)
        let reported = try JSONDecoder().decode([AndroidApp].self, from: data)
        let visible = reported
            .filter { $0.package != AndroidBridge.package }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }

        let previous = Dictionary(AppStore.load().map { ($0.package, $0) }, uniquingKeysWith: { a, _ in a })
        let launchers = LauncherGenerator.existing()

        for app in visible {
            let iconURL = SubsystemPaths.icon(for: app.package)
            let old = previous[app.package]
            if old?.updated != app.updated || !FileManager.default.fileExists(atPath: iconURL.path) {
                if let png = try? AndroidBridge.read("icon/\(app.package)", from: adb, timeout: 15),
                   png.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                    try? png.write(to: iconURL, options: .atomic)
                }
            }
            if let bundle = launchers[app.package], !LauncherGenerator.needsUpdate(bundle, for: app) { continue }
            _ = try? LauncherGenerator.create(for: app, iconPNG: FileManager.default.fileExists(atPath: iconURL.path) ? iconURL : nil)
        }

        let current = Set(visible.map(\.package))
        let removed = previous.values.filter { !current.contains($0.package) }
        for package in launchers.keys where !current.contains(package) {
            LauncherGenerator.remove(package: package)
            try? FileManager.default.removeItem(at: SubsystemPaths.icon(for: package))
        }
        let added = previous.isEmpty ? [] : visible.filter { previous[$0.package] == nil }

        AppStore.save(visible)
        return Result(apps: visible, added: added, removed: removed)
    }

    /// Open an Android app in its own window by launching its Mac launcher.
    @MainActor
    static func open(package: String) {
        guard let launcher = LauncherGenerator.existing()[package] else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: launcher, configuration: configuration)
    }
}
