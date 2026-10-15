// Mac Subsystem for Android - build-time configuration read from Info.plist.
//
// The Subsystem app and every generated Android app launcher carry the same
// MSA* keys, so code shared between them finds the subsystem the same way.
//
// Licensed under the GNU General Public License v3 or later.

import Foundation

enum AppConfig {
    /// Name shown in the menu bar, settings window and notifications.
    static let displayName: String = info("MSADisplayName") ?? "Mac Subsystem for Android"
    /// Bundle identifier of the Subsystem app (also known inside launchers).
    static let subsystemBundleID: String = info("MSASubsystemBundleID") ?? "io.github.harkhowalia1.msa"
    /// URL scheme handled by the Subsystem app: msa://start, msa://open?package=...
    static let urlScheme: String = info("MSAURLScheme") ?? "msa"
    /// Folder name under ~/Library/Application Support and ~/Applications.
    static let supportFolderName: String = info("MSASupportFolder") ?? "Mac Subsystem for Android"
    static let launcherFolderName: String = info("MSALauncherFolder") ?? "Android Apps"
    static let version: String = info("CFBundleShortVersionString") ?? "0"
    static let repository: String = info("MSARepository") ?? "harkhowalia-1/MacSubsystemForAndroid"
    static var repositoryURL: URL { URL(string: "https://github.com/\(repository)")! }
    static let websiteURL = URL(string: info("MSAWebsiteURL") ?? "https://github.com")!
    /// ADB port on 127.0.0.1 (forwarded by QEMU).
    static let adbPort: UInt16 = UInt16(info("MSAADBPort") ?? "") ?? 58526
    /// scrcpy server version bundled in Resources/scrcpy-server.jar. Client and server must match.
    static let scrcpyVersion: String = info("MSAScrcpyVersion") ?? "5.0.1"
    /// Bundle identifier prefix of generated launchers: <prefix>.<sanitized package>
    static var launcherBundlePrefix: String { "\(subsystemBundleID).android" }

    /// A section of the website's guide, e.g. guide("adb").
    static func guide(_ section: String) -> URL {
        URL(string: websiteURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/guide.html#\(section)")!
    }

    private static func info(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }
}
