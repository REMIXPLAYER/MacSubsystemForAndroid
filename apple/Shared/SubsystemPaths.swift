// Mac Subsystem for Android - where everything lives on disk.
//
//   ~/Library/Application Support/Mac Subsystem for Android/
//       adbkey                 RSA key the Mac uses to talk to Android (shared by all launchers)
//       status.json            written by the Subsystem app, read by launchers
//       apps.json, icons/      installed Android apps, synced from the bridge app
//       rom/<name>/            the Android image as downloaded (read only once installed)
//       vm/                    copy-on-write disks, EFI variables, logs, sockets
//   ~/Applications/Android Apps/<App>.app   one launcher per Android app
//
// Licensed under the GNU General Public License v3 or later.

import Foundation

enum SubsystemPaths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ensure(base.appendingPathComponent(AppConfig.supportFolderName, isDirectory: true))
    }

    static var adbKey: URL { support.appendingPathComponent("adbkey") }
    static var status: URL { support.appendingPathComponent("status.json") }
    static var apps: URL { support.appendingPathComponent("apps.json") }
    static var icons: URL { ensure(support.appendingPathComponent("icons", isDirectory: true)) }
    static var rom: URL { ensure(support.appendingPathComponent("rom", isDirectory: true)) }
    static var vm: URL { ensure(support.appendingPathComponent("vm", isDirectory: true)) }
    static var downloads: URL { ensure(support.appendingPathComponent("downloads", isDirectory: true)) }
    /// Short path for QEMU's sockets (Unix socket paths are limited to 104 bytes).
    static var runtime: URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return ensure(tmp.appendingPathComponent("msa", isDirectory: true))
    }

    /// Copies of app icons attached to notifications (the system moves attachments).
    static var notificationAttachments: URL { ensure(runtime.appendingPathComponent("attachments", isDirectory: true)) }

    static var launchers: URL {
        let applications = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)[0]
        return ensure(applications.appendingPathComponent(AppConfig.launcherFolderName, isDirectory: true))
    }

    static func icon(for package: String) -> URL {
        icons.appendingPathComponent("\(package).png")
    }

    @discardableResult
    static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
