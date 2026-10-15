// Mac Android Subsystem - tidying up after the app was renamed (it was "Mac
// Subsystem for Android").
//
// The support folder moves by itself (SubsystemPaths.support) and Android's disks
// are repointed at their new location (AndroidImage.runtimeDisks). This removes
// the old copy of the app, which has the same bundle identifier and URL scheme,
// so launchers and msa:// links can't open it by mistake, and renews the login
// item for the new app.
//
// Licensed under the GNU General Public License v3 or later.

import AppKit
import ServiceManagement

@MainActor
enum RenameMigration {
    static func run() {
        let current = Bundle.main.bundleURL.standardizedFileURL
        let legacyNames = Set(AppConfig.legacySupportFolderNames.map { "\($0).app" })
        let copies = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: AppConfig.subsystemBundleID)
        let old = copies.filter {
            $0.standardizedFileURL != current && legacyNames.contains($0.lastPathComponent)
        }
        guard !old.isEmpty else { return }
        NSWorkspace.shared.recycle(old) { _, error in
            if let error { NSLog("Couldn't move the old app to the Trash: \(error.localizedDescription)") }
        }
        if SubsystemSettings.shared.startAtLogin {
            try? SMAppService.mainApp.register()
        }
        _ = LSRegisterURL(current as CFURL, true)
    }
}
